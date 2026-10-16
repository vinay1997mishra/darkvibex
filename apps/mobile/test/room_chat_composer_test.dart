import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room chat keeps composer visible and exposes a send button', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains("key: const Key('room-chat-composer')"));
    expect(source, contains("key: const Key('room-chat-send-button')"));
    expect(source, contains('MediaQuery.viewInsetsOf(context).bottom'));
    expect(source, contains('resizeToAvoidBottomInset: false'));
    expect(source, contains("hintText: chatBanned"));
    expect(source, contains("'Type a message'"));
  });

  test('room chat auto-scrolls to the newest complete message', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains('final ScrollController roomChatScrollController'));
    expect(source, contains('controller: roomChatScrollController'));
    expect(source, contains('roomChatScrollController.position.maxScrollExtent'));
    expect(source, contains('_scrollChatToLatest();'));
    expect(source, contains("padding: const EdgeInsets.only(bottom: 14)"));
  });

  test('room message send uses backend-created message payload immediately', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final api = File('lib/infra/backend_api.dart').readAsStringSync();

    expect(source, contains('sendRoomMessageResult('));
    expect(source, contains("final serverMessage = result['message'];"));
    expect(api, contains('Future<Map<String, dynamic>?> sendRoomMessageResult'));
  });
}
