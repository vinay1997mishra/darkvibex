// Chat clear (Vinay, 2026-11-20): the option moved out of the room DP
// menu into the 4-Box tools grid, renamed "Chat clear", visible to the
// room owner/admin only. The clear runs on the server — an owner clear
// hides the old chat from everyone, an admin clear from everyone except
// the owner — and the old device-only clear marker is gone.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the room DP menu no longer offers to clear the chat', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, isNot(contains('room-clear-chat-menu')));
    expect(source, isNot(contains('Clear room chat')));
    expect(source, isNot(contains('_confirmClearRoomChat')));
  });

  test('the 4-Box tools grid offers Chat clear to the owner/admin only', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final toolsStart = source.indexOf('Future<void> _showRoomTools');
    final toolsEnd = source.indexOf('Future<void> _openExitMenu', toolsStart);
    final tools = source.substring(toolsStart, toolsEnd);
    expect(tools, contains("'Chat clear',"));
    expect(tools, contains('Icons.delete_sweep_rounded'));
    expect(tools, contains('_clearRoomChat,'));
    expect(
      tools,
      contains("if (tool.\$1 == 'Chat clear') return isRoomAdmin;"),
    );
  });

  test('the clear runs on the server and tells the owner/admin apart', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Future<void> _clearRoomChat()'));
    expect(source, contains('clearRoomChat('));
    expect(source, contains('for everyone except the room owner'));
    expect(source, contains("key: const Key('confirm-clear-room-chat')"));
  });

  test('the old device-only clear marker is gone', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, isNot(contains('_roomChatClearPreferenceKey')));
    expect(source, isNot(contains('_roomChatClearedAtMs')));
    expect(source, isNot(contains('_ensureRoomChatClearMarkerLoaded')));
    expect(source, isNot(contains('Room chat cleared on this device')));
  });

  test('the backend exposes a room chat clear call', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, contains('Future<bool> clearRoomChat('));
    expect(api, contains('/messages/clear'));
  });
}
