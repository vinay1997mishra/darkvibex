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
