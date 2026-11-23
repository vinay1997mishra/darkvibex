import 'package:darkvibex/widgets/level_tag.dart';
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
    // Room owner shows a red house icon, never the written tag
    // (Vinay, 2026-11-23).
    expect(find.text('Room Owner'), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.home_rounded)).color,
      Colors.red,
    );
    expect(find.text('V Official · Verified'), findsOneWidget);
    expect(find.text('Gift Sender'), findsOneWidget);
    // ID Level renders as the 3D "Lv.N" pill next to the name (Vinay,
    // 2026-11-23) — the number is parsed from the medal name when the
    // server did not send it. No wealth tag at dollar level 0.
    expect(find.text('ID Level 4'), findsNothing);
    expect(find.text('Lv.4'), findsOneWidget);
    expect(find.byType(IdLevelTag), findsOneWidget);
    expect(find.byType(WealthTag), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wealth tag and ID level pill render from the numeric levels '
      '(Vinay, 2026-11-23)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'Jay',
                tags: [],
                medals: [
                  {'id': 'level', 'name': 'ID Level 7', 'color': '#45AAF2'},
                ],
                vipLevel: 5,
                dollarLevel: 12,
                // The numeric level wins over the medal name's 7.
                idLevel: 9,
              ),
            ),
          ),
        ),
      ),
    );

    // One gold-$ wealth tag (dollar level 12) and one "Lv.9" pill; the
    // written "ID Level 7" never shows.
    expect(find.byType(WealthTag), findsOneWidget);
    expect(find.text('\$'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.byType(IdLevelTag), findsOneWidget);
    expect(find.text('Lv.9'), findsOneWidget);
    expect(find.text('Lv.7'), findsNothing);
    expect(find.text('ID Level 7'), findsNothing);
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

    // Two gold gradients: the VIP18 name glow and the gold "VIP 18" text.
    expect(find.byType(ShaderMask), findsNWidgets(2));
    final text =
        tester.widget<Text>(find.byKey(const Key('room-chat-sender-name')));
    expect(text.style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room admin shows a blue shield, no "Room Admin" text, and '
      'the VIP tag appears once as gold text (Vinay, 2026-11-23)',
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
                    'id': 'room-admin',
                    'name': 'Room Admin',
                    'color': '#73CFFF',
                  },
                  {
                    'id': 'active-vip',
                    'name': 'VIP 9',
                    'color': '#FFD36A',
                  },
                ],
                medals: [
                  {
                    'id': 'vip',
                    'name': 'VIP',
                    'color': '#D09A0A',
                  },
                ],
                vipLevel: 9,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Room Admin'), findsNothing);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.shield_rounded)).color,
      const Color(0xFF73CFFF),
    );
    // Gold "VIP 9" text next to the name only — the "VIP 9" tag and the
    // "VIP" medal are filtered out, so there is no duplicate.
    expect(find.text('VIP 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('charm medal never renders as a written tag '
      '(Vinay, 2026-11-23)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: RoomChatSenderHeader(
                displayName: 'Vinay',
                tags: [],
                medals: [
                  {
                    'id': 'charm',
                    'name': 'Charm',
                    'color': '#FF6B9A',
                  },
                  {
                    'id': 'gifter',
                    'name': 'Gift Sender',
                    'color': '#A55EEA',
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // The written "Charm" tag is removed permanently; only the wealth
    // and dollar tags stay. Other medals still render.
    expect(find.text('Charm'), findsNothing);
    expect(find.text('Gift Sender'), findsOneWidget);
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

  testWidgets('tapping the sender avatar or name fires onAvatarTap',
      (tester) async {
    var taps = 0;
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
                onAvatarTap: () => taps += 1,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.person_rounded));
    expect(taps, 1);
    await tester.tap(find.text('Vinay'));
    expect(taps, 2);
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
