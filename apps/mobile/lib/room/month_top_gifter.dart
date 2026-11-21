/// Monthly top gifter shown in the room header (Vinay, 2026-11-21).
/// The ID shows for the month, but disappears from the header the moment
/// the top gifter exits the room — so it only shows while they are among
/// the room members.
Map<String, dynamic>? monthTopGifterInRoom(
  Map<String, dynamic>? top,
  List<Map<String, dynamic>> members,
) {
  if (top == null) return null;
  final topUserId = top['user_id']?.toString() ?? '';
  if (topUserId.isEmpty) return null;
  final inRoom = members.any((m) => m['user_id']?.toString() == topUserId);
  return inRoom ? top : null;
}
