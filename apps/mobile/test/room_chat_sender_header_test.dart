import 'package:darkvibex/widgets/room_chat_sender_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('room chat sender header shows avatar fallback, name, tags and medals',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'Vinay',
                tags: [
                  {
                    'id': 'room-owner',
                    'name': 'Room Owner',
                    'color': '#FFD36A',
                    'background_color': '#49320F',
                  },
                  {
                    'id': 'custom-tag',
                    'name': 'V Official',
                    'designation': 'Verified',
                    'color': '#73CFFF',
                  },
                ],
                medals: [
                  {
                    'id': 'gifter',
                    'name': 'Gift Sender',
                    'color': '#A55EEA',
                  },
                  {
                    'id': 'level',
                    'name': 'ID Level 4',
                    'color': '#45AAF2',
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Vinay'), findsOneWidget);
    expect(find.text('Room Owner'), findsOneWidget);
    expect(find.text('V Official · Verified'), findsOneWidget);
    expect(find.text('Gift Sender'), findsOneWidget);
    expect(find.text('ID Level 4'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sender name shows the VIP level colour (VIP5 gold)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'Vinay',
                tags: [],
                medals: [],
                vipLevel: 5,
              ),
            ),
          ),
        ),
      ),
    );

    final text =
        tester.widget<Text>(find.byKey(const Key('room-chat-sender-name')));
    expect(text.style?.color, const Color(0xFFFFD700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sender name uses the gold-red gradient at VIP18',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'Vinay',
                tags: [],
                medals: [],
                vipLevel: 18,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ShaderMask), findsOneWidget);
    final text =
        tester.widget<Text>(find.byKey(const Key('room-chat-sender-name')));
    expect(text.style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sender name stays white below VIP5', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'Vinay',
                tags: [],
                medals: [],
                vipLevel: 4,
              ),
            ),
          ),
        ),
      ),
    );

    final text =
        tester.widget<Text>(find.byKey(const Key('room-chat-sender-name')));
    expect(text.style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the sender avatar fires onAvatarTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'Vinay',
                tags: const [],
                medals: const [],
                onAvatarTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.person_rounded));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long sender names and multiple profile badges do not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'A very long DarkVibeX member display name',
                tags: List.generate(
                  5,
                  (index) => {
                    'id': 'tag-$index',
                    'name': 'Official Tag $index',
                    'color': '#73CFFF',
                  },
                ),
                medals: List.generate(
                  4,
                  (index) => {
                    'id': 'medal-$index',
                    'name': 'Achievement Medal $index',
                    'color': '#FFD36A',
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('room-chat-sender-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
