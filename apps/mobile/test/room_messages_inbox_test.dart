import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room Msg opens the standalone inbox instead of the embedded tab layout', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final messages = File('lib/screens/messages_screen.dart').readAsStringSync();

    expect(room, contains('standalone: true'));
    expect(messages, contains("key: const Key('room-standalone-messages')"));
    expect(messages, contains("'room-standalone-message-list'"));
    expect(messages, contains("title: const Text(\n          'Messages'"));
  });

  test('newest sender stays first and sender identity is shown', () {
    final appState = File('lib/app/app_state.dart').readAsStringSync();
    final messages = File('lib/screens/messages_screen.dart').readAsStringSync();

    expect(appState, contains("row['created_at']"));
    expect(
      appState,
      contains('..sort((a, b) => b.createdAt.compareTo(a.createdAt))'),
    );
    expect(
      messages,
      contains('..sort((a, b) => b.createdAt.compareTo(a.createdAt))'),
    );
    expect(messages, contains('backgroundImage: item.avatarKey == null'));
    expect(messages, contains('item.name'));
    expect(messages, contains('item.preview'));
    expect(messages, contains('item.unread > 0'));
  });

  test('standalone inbox refreshes while it remains open', () {
    final messages = File('lib/screens/messages_screen.dart').readAsStringSync();

    expect(messages, contains('Timer.periodic'));
    expect(messages, contains('unawaited(_refreshInbox())'));
    expect(messages, contains('await _refreshInbox();'));
  });

  test('activity badge counts only unread items and opening the feed marks them read', () {
    final messages = File('lib/screens/messages_screen.dart').readAsStringSync();
    final api = File('lib/infra/backend_api.dart').readAsStringSync();

    expect(messages, contains('_unreadActivityCount'));
    expect(messages, contains("activity.where((row) => row['is_read'] != true).length"));
    expect(messages, contains('markActivityMessagesRead'));
    expect(messages, contains("'is_read': true"));
    expect(api, contains("'/api/messages/activity/read'"));
    expect(api, contains("'item_ids': itemIds"));
  });
}
