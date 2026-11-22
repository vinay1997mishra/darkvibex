/// Tracks consecutive failed room member-list fetches to detect when the
/// local user was kicked out of the room.
///
/// The worker answers the members list with 403 `room_membership_required`
/// when the caller's own membership row is gone (kicked), so a failed
/// fetch is the kick signal. The list CONTENTS cannot be used instead:
/// the worker caps the list at 200 rows, so in a big room a member can
/// be missing from a successful response while still in the room.
///
/// One failure is treated as transient (a 500, a blip) and never throws
/// the user out; only consecutive failures act. (Vinay, 2026-11-20 —
/// the kick bug: the kicked user's voice kept transmitting and they
/// stayed in the room, because the client never noticed its own
/// membership row was deleted.)
/// What the room screen should do after a failed members/state fetch,
/// once it has asked the server whether the user was really removed.
/// A failed poll on its own is NEVER a removal: a network drop, a 500
/// or an exhausted free tier all look exactly like a kick to the poll
/// (the worker answers every one of them with null), so the poll alone
/// must not throw the user out of the room (Vinay, 2026-11-22: IDs
/// were leaving rooms on their own).
enum RoomRemovalAction {
  /// Stay in the room: the removal could not be confirmed — the
  /// kick-status check itself failed, the silent re-join failed
  /// transiently, or the re-join succeeded.
  stay,

  /// Exit with the "Removed from room" dialog: a real kick (the kick
  /// marker is set) or a ban (the re-join is refused with
  /// room_blocked — a ban is also a removal by the owner/admin).
  exitRemoved,

  /// Exit silently, no dialog: the room itself is gone.
  exitSilently,
}

/// Decide what a failed room fetch means, from the two confirmations
/// the room screen asks the server for (the same answers the resume
/// path has used since 2026-11-21). [kicked] is the kick-status answer
/// (null = the check itself failed, so nothing is known); [joined] is
/// the silent re-join result (null = the join call itself failed).
RoomRemovalAction decideRoomRemoval({
  required bool? kicked,
  required Map<String, dynamic>? joined,
}) {
  if (kicked == null) return RoomRemovalAction.stay;
  if (kicked) return RoomRemovalAction.exitRemoved;
  if (joined == null) return RoomRemovalAction.stay;
  if (joined['ok'] == true) return RoomRemovalAction.stay;
  final error = joined['error']?.toString() ?? '';
  if (error == 'room_blocked') return RoomRemovalAction.exitRemoved;
  if (error == 'room_not_found') return RoomRemovalAction.exitSilently;
  return RoomRemovalAction.stay;
}

class RoomKickTracker {
  int _failedRefreshes = 0;

  /// Record one member-list fetch. Returns true when [threshold]
  /// consecutive fetches have failed — the local user was removed.
  bool noteFetch({required bool ok, int threshold = 2}) {
    if (ok) {
      _failedRefreshes = 0;
      return false;
    }
    _failedRefreshes += 1;
    if (_failedRefreshes >= threshold) {
      _failedRefreshes = 0;
      return true;
    }
    return false;
  }
}
