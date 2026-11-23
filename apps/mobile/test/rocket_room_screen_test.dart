import 'dart:io';

import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/rocket_room_screen.dart';
import 'package:darkvibex/utils/rocket_top_rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRocketBackend extends BackendApi {
  const _FakeRocketBackend();

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

/// Same status payload, but the pool can be claimed — and the claim
/// endpoint records its calls (full-app audit 2026-11-20: the page
/// told eligible users "you can claim the pool" with no button).
class _ClaimableRocketBackend extends _FakeRocketBackend {
  int claimCalls = 0;

  @override
  Future<Map<String, dynamic>?> roomRocketRewardStatus({
    required String roomId,
    required int rocketLevel,
  }) async {
    final status = await super.roomRocketRewardStatus(
      roomId: roomId,
      rocketLevel: rocketLevel,
    );
    return <String, dynamic>{...?status, 'can_claim': true};
  }

  @override
  Future<Map<String, dynamic>?> claimRoomRocketReward({
    required String roomId,
    required int rocketLevel,
  }) async {
    claimCalls += 1;
    return <String, dynamic>{
      'ok': true,
      'reward_type': 'coins',
      'coins': 45000,
    };
  }
}

List<Map<String, dynamic>> _ranking() => <Map<String, dynamic>>[
      <String, dynamic>{
        'user_id': 'user-1',
        'display_name': 'NICK',
        'avatar_key': '',
        'sent_coins': 9500000,
      },
      <String, dynamic>{
        'user_id': 'user-2',
        'display_name': 'Aisha',
        'avatar_key': '',
        'sent_coins': 8200000,
      },
      <String, dynamic>{
        'user_id': 'user-3',
        'display_name': 'Priya',
        'avatar_key': '',
        'sent_coins': 7100000,
      },
    ];

List<Map<String, dynamic>> _seats() => <Map<String, dynamic>>[
      for (var i = 0; i < 8; i++)
        <String, dynamic>{
          'user_id': 'seat-$i',
          'display_name': 'Seat $i',
          'avatar_key': '',
        },
    ];

RocketRoomPage _page({
  int lifetimeTotal = 42000000,
  int? dailyTotal,
  List<Map<String, dynamic>>? ranking,
  List<Map<String, dynamic>>? seatMembers,
  String currentUserId = 'user-2',
  BackendApi? backend,
}) {
  return RocketRoomPage(
    roomId: 'room-1',
    roomName: 'Music Room',
    roomNumber: '766793',
    onlineCount: 1200,
    lifetimeTotal: lifetimeTotal,
    dailyTotal: dailyTotal ?? lifetimeTotal,
    ranking: ranking ?? _ranking(),
    seatMembers: seatMembers ?? _seats(),
    currentUserId: currentUserId,
    backend: backend ?? const _FakeRocketBackend(),
  );
}

void main() {
  group('rocketTopRewardsForLevel', () {
    test('Lv.1 gives 5L/3L/2L, VIP 1, 1 day', () {
      final rewards = rocketTopRewardsForLevel(1)!;
      expect(rewards[0].vipLevel, 1);
      expect(rewards[0].vipDays, 1);
      expect(rewards[0].launchCoins, 500000);
      expect(rewards[1].vipDays, 1);
      expect(rewards[1].launchCoins, 300000);
      expect(rewards[2].vipDays, 1);
      expect(rewards[2].launchCoins, 200000);
    });

    test('Lv.6 gives VIP 4 for 10/7/5 days', () {
      final rewards = rocketTopRewardsForLevel(6)!;
      expect(rewards.map((r) => r.vipLevel), everyElement(4));
      expect(rewards[0].vipDays, 10);
      expect(rewards[1].vipDays, 7);
      expect(rewards[2].vipDays, 5);
      expect(rewards[0].launchCoins, 1000000);
      expect(rewards[1].launchCoins, 800000);
      expect(rewards[2].launchCoins, 700000);
    });

    test('Lv.10 gives 14L/10L/8L with VIP capped at 8', () {
      final rewards = rocketTopRewardsForLevel(10)!;
      expect(rewards.map((r) => r.vipLevel), everyElement(8));
      expect(rewards[0].launchCoins, 1400000);
      expect(rewards[1].launchCoins, 1000000);
      expect(rewards[2].launchCoins, 800000);
      expect(rewards[0].vipDays, 18);
      expect(rewards[1].vipDays, 15);
      expect(rewards[2].vipDays, 13);
    });

    test('Lv.18 gives VIP 8 for 30/21/15 days and 22L/10L/8L', () {
      final rewards = rocketTopRewardsForLevel(18)!;
      expect(rewards.map((r) => r.vipLevel), everyElement(8));
      expect(rewards[0].vipDays, 30);
      expect(rewards[1].vipDays, 21);
      expect(rewards[2].vipDays, 15);
      expect(rewards[0].launchCoins, 2200000);
      expect(rewards[1].launchCoins, 1000000);
      expect(rewards[2].launchCoins, 800000);
    });

    test('returns null outside 1-18 and for bad ranks', () {
      expect(rocketTopRewardsForLevel(0), isNull);
      expect(rocketTopRewardsForLevel(19), isNull);
      expect(rocketTopRewardForRank(6, 0), isNull);
      expect(rocketTopRewardForRank(6, 4), isNull);
      expect(rocketTopRewardForRank(6, 2)?.vipDays, 7);
    });
  });

  for (final size in [const Size(360, 640), const Size(412, 892)]) {
    testWidgets('Rocket Room Page renders the v5 layout at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: _page()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header + room total (42.0M lifetime gifts -> current level 6).
      expect(find.byKey(const Key('rocket-room-page')), findsOneWidget);
      expect(find.text('DarkVibeX • Music Room'), findsOneWidget);
      expect(find.text('ID 766793'), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-total')), findsOneWidget);
      // Realistic gold trophy image, same size as the old flat icon.
      expect(
        find.byKey(const Key('rocket-room-total-trophy')),
        findsOneWidget,
      );
      expect(find.text('42.0M'), findsWidgets);

      // Ladder: current level 6 highlighted; all 18 levels reachable by
      // dragging the ladder (only the viewport rows are built).
      expect(find.byKey(const Key('rocket-room-ladder-level-6')), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('rocket-room-ladder')),
        const Offset(0, 900),
      );
      await tester.pump();
      expect(find.byKey(const Key('rocket-room-ladder-level-18')), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('rocket-room-ladder')),
        const Offset(0, -1200),
      );
      await tester.pump();
      expect(find.byKey(const Key('rocket-room-ladder-level-1')), findsOneWidget);

      // Centre rocket + countdown + progress (42M/52M = 80%).
      expect(find.byKey(const Key('rocket-room-rocket-image')), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-countdown')), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-progress')), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      // Top 1/2/3 with sent coins.
      expect(find.byKey(const Key('rocket-room-top-1')), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-top-2')), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-top-3')), findsOneWidget);
      expect(find.text('9.5M'), findsOneWidget);
      expect(find.text('8.2M'), findsOneWidget);

      // Default tab is Top 1: Lv.6 rewards (VIP 4, 10 days, 10 Lakh).
      expect(find.text('VIP 4'), findsOneWidget);
      expect(find.text('10 days · direct VIP'), findsOneWidget);
      expect(find.text('10 Lakh'), findsOneWidget);
      // Live pool tier from the fake status endpoint.
      expect(find.text('30.0K–60.0K'), findsOneWidget);
      expect(find.text('random coins · top 70'), findsOneWidget);

      // Switch to Top 2 and Top 3.
      await tester.ensureVisible(find.byKey(const Key('rocket-room-tab-top-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('rocket-room-tab-top-2')));
      await tester.pump();
      expect(find.text('7 days · direct VIP'), findsOneWidget);
      expect(find.text('8 Lakh'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('rocket-room-tab-top-3')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('rocket-room-tab-top-3')));
      await tester.pump();
      expect(find.text('5 days · direct VIP'), findsOneWidget);
      expect(find.text('7 Lakh'), findsOneWidget);

      // User tab: current user is Aisha, rank 2.
      await tester.ensureVisible(find.byKey(const Key('rocket-room-tab-user')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('rocket-room-tab-user')));
      await tester.pump();
      expect(find.text('You are Rank 2 · sent 8.2M coins'), findsOneWidget);
      expect(find.textContaining('Entry rank: 2'), findsOneWidget);
      expect(find.text('7 days · direct VIP'), findsOneWidget);

      // Help dialog explains the no-frames rule.
      await tester.ensureVisible(
        find.byKey(const Key('rocket-room-help-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('rocket-room-help-button')));
      await tester.pump();
      expect(find.text('How Rocket rewards work'), findsOneWidget);
      expect(find.textContaining('No frames are given to anyone'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pump();

      // Record dialog lists reached levels.
      await tester.ensureVisible(
        find.byKey(const Key('rocket-room-record-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('rocket-room-record-button')));
      await tester.pump();
      expect(find.text('Rocket records'), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-record-level-1')), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-record-level-18')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Rocket Room Page handles empty ranking and seats at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: _page(
            lifetimeTotal: 0,
            ranking: const <Map<String, dynamic>>[],
            seatMembers: const <Map<String, dynamic>>[],
            currentUserId: 'nobody',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Level 1 with 0% progress and empty top slots.
      expect(find.byKey(const Key('rocket-room-ladder-level-1')), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.byKey(const Key('rocket-room-top-1')), findsOneWidget);
      expect(find.text('VIP 1'), findsOneWidget);
      expect(find.text('1 day · direct VIP'), findsOneWidget);
      expect(find.text('5 Lakh'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('rocket-room-tab-user')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('rocket-room-tab-user')));
      await tester.pump();
      expect(
        find.text('You have not gifted in this room yet.'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'claim button appears on the User tab when the pool can be claimed and claims on tap',
      (tester) async {
    final backend = _ClaimableRocketBackend();
    await tester.pumpWidget(MaterialApp(home: _page(backend: backend)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.byKey(const Key('rocket-room-tab-user')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('rocket-room-tab-user')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('rocket-room-claim-pool')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('rocket-room-claim-pool')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rocket-room-claim-pool')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.claimCalls, 1);
    expect(find.textContaining('Coins have been added'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the floating rocket opens the new full page directly — the old panel is gone', () {
    final source =
        File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, isNot(contains('_showRocketPanel')));
    expect(source, isNot(contains('room-rocket-panel')));
    expect(source, isNot(contains('room-rocket-open-full-page')));
    expect(source, isNot(contains('Open Rocket Room')));
    expect(source, contains('onTap: _openRocketRoom,'));
    final start = source.indexOf('Future<void> _openRocketRoom()');
    expect(start, isNot(-1));
    final end = source.indexOf(
      '// Touching the Ranking / total chips opens the room ranking page',
      start,
    );
    final method = source.substring(start, end);
    expect(method, contains('await _loadRoomGiftRanking();'));
    expect(method, contains('RocketRoomPage('));
    expect(method, contains('lifetimeTotal: roomGiftLifetimeTotal,'));
    expect(method, contains('dailyTotal: roomGiftDailyTotal,'));
    expect(method, contains('ranking: roomGiftRanking,'));
  });

  test('rocket progress runs on the daily total and resets to level 1 on the new day', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    // The ranking poll reads the IST-day total and the rocket level
    // runs on it — never on the lifetime total.
    expect(room, contains("int.tryParse(value?['daily_total']?.toString() ?? '') ?? 0;"));
    expect(room, contains('roomGiftDailyTotal = nextDailyTotal;'));
    expect(room, contains("_rocketProgressState(roomGiftDailyTotal)['completed']"));
    expect(room, contains('final dailyReset = nextDailyTotal < roomGiftDailyTotal;'));
    expect(room, contains('_lastObservedRocketCompleted = nextCompleted;'));
    // The full page takes the daily total for its progress; the
    // lifetime total stays only as the display total.
    final page = File('lib/screens/rocket_room_screen.dart').readAsStringSync();
    expect(page, contains('required this.dailyTotal,'));
    expect(page, contains("calculateRocketProgress(widget.dailyTotal)['completed']"));
    expect(page, contains("calculateRocketProgress(widget.dailyTotal)['percent']"));
    expect(page, contains('_compactCoins(widget.lifetimeTotal)'));
  });

  testWidgets('a big lifetime total does not lift the level — today\'s total does',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _page(lifetimeTotal: 42000000, dailyTotal: 5000000),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Level 1 is current (gold border, width 2) even though 42M
    // lifetime would reach level 6.
    await tester.ensureVisible(
      find.byKey(const Key('rocket-room-ladder-level-1')),
    );
    await tester.pump();
    final level1 =
        tester.widget<Container>(find.byKey(const Key('rocket-room-ladder-level-1')));
    final decoration1 = level1.decoration as BoxDecoration;
    expect(decoration1.border?.top.width, 2);
    // Progress runs on today's 5M, not the 42M lifetime: 5M of the
    // 12M level-1 target is 41%, not the 80% the lifetime total
    // would show.
    expect(find.text('41%'), findsOneWidget);
    expect(find.text('80%'), findsNothing);
  });
}
