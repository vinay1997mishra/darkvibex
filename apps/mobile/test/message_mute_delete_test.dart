import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/messages_screen.dart';

void main() {
  group('DirectMessage.fromRow', () {
    test('parses unread count and muted flag from the inbox row', () {
      final item = DirectMessage.fromRow(<String, dynamic>{
        'id': 'user-b',
        'name': 'Bob',
        'preview': 'hello',
        'unread': 3,
        'muted': true,
        'avatar_key': null,
        'created_at': 1700000000000,
      });
      expect(item.id, 'user-b');
      expect(item.name, 'Bob');
      expect(item.preview, 'hello');
      expect(item.unread, 3);
      expect(item.muted, true);
      expect(item.createdAt, 1700000000000);
    });

    test('muted accepts 1/0 and string forms, defaults to unmuted', () {
      expect(
        DirectMessage.fromRow(<String, dynamic>{'muted': 1}).muted,
        true,
      );
      expect(
        DirectMessage.fromRow(<String, dynamic>{'muted': 0}).muted,
        false,
      );
      expect(
        DirectMessage.fromRow(<String, dynamic>{'muted': '1'}).muted,
        true,
      );
      expect(
        DirectMessage.fromRow(<String, dynamic>{}).muted,
        false,
      );
    });

    test('unread and created_at fall back to 0, name to User', () {
      final item = DirectMessage.fromRow(<String, dynamic>{'id': 'user-c'});
      expect(item.unread, 0);
      expect(item.createdAt, 0);
      expect(item.name, 'User');
      expect(item.preview, '');
    });
  });

  group('MessagesScreen inbox long-press', () {
    Future<void> pumpInbox(
      WidgetTester tester,
      AppState state,
    ) async {
      // The embedded inbox has no Scaffold of its own — in the real
      // app HomeShell hosts it. The Scaffold here only provides the
      // Material ancestor ListTile needs.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MessagesScreen(state: state))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    AppState stateWithConversations() {
      final state = AppState();
      state.messages.addAll(<DirectMessage>[
        const DirectMessage(
          id: 'user-b',
          name: 'Bob',
          preview: 'hey there',
          unread: 3,
          createdAt: 1700000002000,
        ),
        const DirectMessage(
          id: 'user-c',
          name: 'Carol',
          preview: 'see you',
          unread: 0,
          muted: true,
          createdAt: 1700000001000,
        ),
      ]);
      return state;
    }

    testWidgets('unread badge and muted icon show on the right rows',
        (tester) async {
      final state = stateWithConversations();
      await pumpInbox(tester, state);

      // Bob has 3 unread: the badge shows the count and his name is bold.
      expect(find.text('3'), findsOneWidget);
      // Carol is muted: the volume-off icon shows on her row.
      expect(find.byIcon(Icons.volume_off_rounded), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });

    testWidgets('long-press opens Mute and Delete, Delete asks first',
        (tester) async {
      final state = stateWithConversations();
      await pumpInbox(tester, state);

      await tester.longPress(find.byKey(const Key('message-thread-user-b')));
      await tester.pumpAndSettle();

      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Delete chat'), findsOneWidget);

      await tester.tap(find.byKey(const Key('inbox-action-delete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('message-delete-confirm')), findsOneWidget);
      expect(find.text('Delete chat with Bob?'), findsOneWidget);
      expect(
        find.text('All messages with this person will be deleted for you. '
            'The other person will still see them. '
            'This cannot be undone.'),
        findsOneWidget,
      );

      // Cancel keeps the conversation.
      await tester.tap(find.byKey(const Key('message-delete-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('message-delete-confirm')), findsNothing);
      expect(find.byKey(const Key('message-thread-user-b')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });

    testWidgets('long-press on a muted chat offers Unmute',
        (tester) async {
      final state = stateWithConversations();
      await pumpInbox(tester, state);

      await tester.longPress(find.byKey(const Key('message-thread-user-c')));
      await tester.pumpAndSettle();

      expect(find.text('Unmute'), findsOneWidget);
      expect(find.text('Mute'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });

    testWidgets('mute tap without a server shows the failure message',
        (tester) async {
      // No backend is configured in tests, so the save cannot reach
      // the server — the screen must say so instead of failing silently.
      final state = stateWithConversations();
      await pumpInbox(tester, state);

      await tester.longPress(find.byKey(const Key('message-thread-user-b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inbox-action-mute')));
      await tester.pumpAndSettle();

      expect(
        find.text('Message mute setting could not be saved'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  });
}
