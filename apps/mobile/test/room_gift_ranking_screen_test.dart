// Room gift ranking page (Vinay, 2026-11-21): opened by touching the
// total gifting amount beside the trophy (rocket page) or the Ranking /
// total chips in the room. Shows THIS room only — who sent how many
// coins here, Day / Week / Month, top 99 — from its own
// /gift-ranking endpoint (the combined room-state poll was removed
// 2026-11-23). A day with no sending shows nobody. The month's top
// gifter gets a gold spotlight at the top (their ID shows for the
// month) on the Monthly tab, and the same ID shows in the room header
// only while they are in the room.
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/room/month_top_gifter.dart';
import 'package:darkvibex/screens/rocket_room_screen.dart';
import 'package:darkvibex/screens/room_gift_ranking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRankingBackend extends BackendApi {
  _FakeRankingBackend({required this.byPeriod});

  final Map<String, List<Map<String, dynamic>>> byPeriod;

  @override
  Future<Map<String, dynamic>?> roomGiftRanking({
    required String roomId,
    String? period,
  }) async {
    final rows = byPeriod[period ?? 'day'] ?? const [];
    return <String, dynamic>{
      'ok': true,
      'lifetime_total': 9500000,
      'month_top': rows.isEmpty ? null : rows.first,
      'period': period ?? 'day',
      'ranking': rows,
    };
  }

  @override
  Future<Map<String, dynamic>?> roomRocketRewardStatus({
    required String roomId,
    required int rocketLevel,
  }) async {
    return <String, dynamic>{
      'ok': true,
      'room_id': roomId,
      'rocket_level': rocketLevel,
      'tier': <String, dynamic>{
        'group': '4-6',
        'label': 'Rocket Levels 4–6',
        'max_winners': 70,
        'frame_winners': 0,
        'coin_min': 30000,
        'coin_max': 60000,
        'frame_days': 0,
      },
      'lifetime_total': 42000000,
      'target_coins': 52000000,
      'reached': false,
      'claimed_count': 3,
      'remaining_winners': 67,
      'entry_rank': 2,
      'claim': null,
      'can_claim': false,
    };
  }
}

List<Map<String, dynamic>> _dayRows() => <Map<String, dynamic>>[
      <String, dynamic>{
        'user_id': 'user-1',
        'public_id': '76679301',
        'display_name': 'NICK',
        'avatar_key': '',
        'sent_coins': 9500000,
        'gift_count': 12,
      },
      <String, dynamic>{
        'user_id': 'user-2',
        'public_id': '76679302',
        'display_name': 'Aisha',
        'avatar_key': '',
        'sent_coins': 8200000,
        'gift_count': 9,
      },
    ];

List<Map<String, dynamic>> _monthRows() => <Map<String, dynamic>>[
      <String, dynamic>{
        'user_id': 'user-1',
        'public_id': '76679301',
        'display_name': 'NICK',
        'avatar_key': '',
        'sent_coins': 45200000,
        'gift_count': 40,
      },
      <String, dynamic>{
        'user_id': 'user-2',
        'public_id': '76679302',
        'display_name': 'Aisha',
        'avatar_key': '',
        'sent_coins': 38100000,
        'gift_count': 33,
      },
    ];

RocketRoomPage _rocketPage(BackendApi backend) {
  return RocketRoomPage(
    roomId: 'room-1',
    roomName: 'Music Room',
    roomNumber: '766793',
    onlineCount: 1200,
    lifetimeTotal: 42000000,
    dailyTotal: 22000000,
    ranking: _dayRows(),
    seatMembers: <Map<String, dynamic>>[
      for (var i = 0; i < 8; i++)
        <String, dynamic>{
          'user_id': 'seat-$i',
          'display_name': 'Seat $i',
          'avatar_key': '',
        },
    ],
    currentUserId: 'user-2',
    backend: backend,
  );
}

void main() {
  testWidgets('room ranking shows day rows with IDs and sent coins',
      (tester) async {
    final backend = _FakeRankingBackend(byPeriod: {
      'day': _dayRows(),
      'week': const [],
      'month': _monthRows(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RoomGiftRankingScreen(
          roomId: 'room-1',
          roomName: 'Music Room',
          backend: backend,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NICK'), findsOneWidget);
    expect(find.text('ID 76679301'), findsOneWidget);
    expect(find.text('9.5M'), findsWidgets);
    expect(find.byKey(const Key('room-ranking-row-0')), findsOneWidget);
    expect(find.byKey(const Key('room-ranking-row-1')), findsOneWidget);
  });

  testWidgets('monthly tab shows the top gifter spotlight with ID',
      (tester) async {
    final backend = _FakeRankingBackend(byPeriod: {
      'day': _dayRows(),
      'week': const [],
      'month': _monthRows(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RoomGiftRankingScreen(
          roomId: 'room-1',
          roomName: 'Music Room',
          backend: backend,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('room-ranking-period-month')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('room-ranking-month-top')), findsOneWidget);
    expect(find.text('Top Gifter of the Month'), findsOneWidget);
    expect(find.text('ID 76679301'), findsWidgets);
    expect(find.text('45.2M'), findsWidgets);
  });

  testWidgets('a day with no sending shows nobody', (tester) async {
    final backend = _FakeRankingBackend(byPeriod: {
      'day': const [],
      'week': const [],
      'month': const [],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RoomGiftRankingScreen(
          roomId: 'room-1',
          roomName: 'Music Room',
          backend: backend,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No gifts sent today'), findsOneWidget);
    expect(find.byKey(const Key('room-ranking-row-0')), findsNothing);
    expect(find.byKey(const Key('room-ranking-month-top')), findsNothing);
  });

  testWidgets('tapping the rocket total opens the room ranking page',
      (tester) async {
    final backend = _FakeRankingBackend(byPeriod: {
      'day': _dayRows(),
      'week': const [],
      'month': _monthRows(),
    });
    await tester.pumpWidget(MaterialApp(home: _rocketPage(backend)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('rocket-room-total-gifts')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RoomGiftRankingScreen), findsOneWidget);
    // NICK also shows on the rocket page underneath (its top-3 list),
    // so the ranking page's copy is the second one.
    expect(find.text('NICK'), findsWidgets);
  });

  test('month top gifter shows only while they are in the room', () {
    const top = <String, dynamic>{
      'user_id': 'user-1',
      'public_id': '76679301',
      'display_name': 'NICK',
    };
    expect(
      monthTopGifterInRoom(top, [
        {'user_id': 'user-1'},
      ]),
      top,
    );
    expect(
      monthTopGifterInRoom(top, [
        {'user_id': 'user-2'},
      ]),
      isNull,
    );
    expect(monthTopGifterInRoom(top, []), isNull);
    expect(
      monthTopGifterInRoom(null, [
        {'user_id': 'user-1'},
      ]),
      isNull,
    );
    expect(
      monthTopGifterInRoom(
        {'user_id': ''},
        [
          {'user_id': ''},
        ],
      ),
      isNull,
    );
  });
}
