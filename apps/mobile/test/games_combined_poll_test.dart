import 'dart:io';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/fruit_party_screen.dart';
import 'package:darkvibex/screens/greedy_girl_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _countdown(WidgetTester tester, Key key) {
  final text = tester.widget<Text>(find.byKey(key));
  return text.data ?? '';
}

Map<String, dynamic> _fruitPartyGame(int now) => <String, dynamic>{
      'round': <String, dynamic>{
        'round_id': 42,
        'phase': 'betting',
        'round_end': now + 30000,
        'cycle_end': now + 40000,
        'betting_open': true,
      },
      'config': <String, dynamic>{
        'bet_amounts': <int>[5000, 25000, 100000, 500000, 2000000],
      },
      'my_bets': <String, dynamic>{},
      'history': <Map<String, dynamic>>[],
      'wallet_balance': 2500000,
      'today_winnings': 0,
    };

Map<String, dynamic> _greedyGirlGame(int now) => <String, dynamic>{
      'round': <String, dynamic>{
        'round_id': 9,
        'phase': 'betting',
        'round_end': now + 30000,
        'cycle_end': now + 35000,
        'betting_open': true,
      },
      'config': <String, dynamic>{
        'bet_amounts': <int>[100, 1000, 10000, 50000, 100000],
        'foods': <Map<String, dynamic>>[
          {'key': 'tomato', 'emoji': '🍅', 'label': 'Tomato', 'multiplier': 5},
          {'key': 'broccoli', 'emoji': '🥦', 'label': 'Broccoli', 'multiplier': 5},
          {'key': 'cucumber', 'emoji': '🥒', 'label': 'Cucumber', 'multiplier': 5},
          {'key': 'carrot', 'emoji': '🥕', 'label': 'Carrot', 'multiplier': 5},
          {'key': 'hotdog', 'emoji': '🌭', 'label': 'Hot dog', 'multiplier': 10},
          {'key': 'corn', 'emoji': '🌽', 'label': 'Corn', 'multiplier': 15},
          {'key': 'lettuce', 'emoji': '🥬', 'label': 'Lettuce', 'multiplier': 25},
          {'key': 'skewer', 'emoji': '🍢', 'label': 'Skewer', 'multiplier': 45},
        ],
      },
      'my_bets': <String, dynamic>{},
      'history': <Map<String, dynamic>>[],
      'wallet_balance': 2500000,
      'today_winnings': 0,
    };

void main() {
  testWidgets(
    'Girls Party timer keeps ticking every second between 3s polls, and a poll corrects it',
    (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFruitParty(context, state),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dynamic screen = tester.state(find.byType(FruitPartyScreen));
      final now = DateTime.now().millisecondsSinceEpoch;
      screen.setState(() {
        screen.game = _fruitPartyGame(now);
        screen.serverTimeAtSync = now;
        screen.localTimeAtSync = now;
        screen.loading = false;
      });
      await tester.pump();
      const countdownKey = Key('fruit-party-countdown-number');
      expect(_countdown(tester, countdownKey), '30');

      // No poll can return here (no backend in tests): the timer must
      // still tick down on the local 250ms clock. tester.pump only
      // advances fake timer time — DateTime.now() is real — so elapsed
      // time is simulated the way the screen measures it: by moving
      // localTimeAtSync back, then letting the 250ms clock rebuild.
      screen.setState(() {
        screen.localTimeAtSync = now - 1000;
      });
      await tester.pump(const Duration(seconds: 1));
      expect(_countdown(tester, countdownKey), '29');
      screen.setState(() {
        screen.localTimeAtSync = now - 2000;
      });
      await tester.pump(const Duration(seconds: 1));
      expect(_countdown(tester, countdownKey), '28');

      // A 3s poll returns: it corrects the timer to server time instead
      // of letting the local estimate drift.
      final correctedNow = DateTime.now().millisecondsSinceEpoch;
      screen.setState(() {
        final next = _fruitPartyGame(correctedNow);
        (next['round'] as Map<String, dynamic>)['round_end'] =
            correctedNow + 25000;
        screen.game = next;
        screen.serverTimeAtSync = correctedNow;
        screen.localTimeAtSync = correctedNow;
      });
      await tester.pump();
      expect(_countdown(tester, countdownKey), '25');

      await tester.tap(find.byTooltip('Close Girls Party'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'Greedy Girl timer keeps ticking every second between 3s polls, and a poll corrects it',
    (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showGreedyGirl(context, state),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dynamic screen = tester.state(find.byType(GreedyGirlScreen));
      final now = DateTime.now().millisecondsSinceEpoch;
      screen.setState(() {
        screen.game = _greedyGirlGame(now);
        screen.serverTimeAtSync = now;
        screen.localTimeAtSync = now;
        screen.loading = false;
      });
      await tester.pump();
      const countdownKey = Key('greedy-girl-countdown-number');
      expect(_countdown(tester, countdownKey), '30');

      // No poll can return here (no backend in tests): the timer must
      // still tick down on the local 250ms clock. tester.pump only
      // advances fake timer time — DateTime.now() is real — so elapsed
      // time is simulated the way the screen measures it: by moving
      // localTimeAtSync back, then letting the 250ms clock rebuild.
      screen.setState(() {
        screen.localTimeAtSync = now - 1000;
      });
      await tester.pump(const Duration(seconds: 1));
      expect(_countdown(tester, countdownKey), '29');
      screen.setState(() {
        screen.localTimeAtSync = now - 2000;
      });
      await tester.pump(const Duration(seconds: 1));
      expect(_countdown(tester, countdownKey), '28');

      // A 3s poll returns: it corrects the timer to server time instead
      // of letting the local estimate drift.
      final correctedNow = DateTime.now().millisecondsSinceEpoch;
      screen.setState(() {
        final next = _greedyGirlGame(correctedNow);
        (next['round'] as Map<String, dynamic>)['round_end'] =
            correctedNow + 25000;
        screen.game = next;
        screen.serverTimeAtSync = correctedNow;
        screen.localTimeAtSync = correctedNow;
      });
      await tester.pump();
      expect(_countdown(tester, countdownKey), '25');

      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  test('each game slice loads on its own — one failing call never blanks the game', () {
    final fruitParty =
        File('lib/screens/fruit_party_screen.dart').readAsStringSync();
    expect(
      fruitParty,
      contains('try {\n      round = await widget.state.backend.fruitPartyRound();'),
    );
    expect(
      fruitParty,
      contains('try {\n      bets = await widget.state.backend.fruitPartyMyBets();'),
    );
    expect(
      fruitParty,
      contains('try {\n      history = await widget.state.backend.fruitPartyHistory();'),
    );
    expect(
      fruitParty,
      isNot(contains('fruitPartyRound();\n      bets = await')),
    );

    final greedyGirl =
        File('lib/screens/greedy_girl_screen.dart').readAsStringSync();
    expect(
      greedyGirl,
      contains('try {\n      round = await widget.state.backend.greedyGirlRound();'),
    );
    expect(
      greedyGirl,
      contains('try {\n      bets = await widget.state.backend.greedyGirlMyBets();'),
    );
    expect(
      greedyGirl,
      contains('try {\n      history = await widget.state.backend.greedyGirlHistory();'),
    );
    expect(
      greedyGirl,
      isNot(contains('greedyGirlRound();\n      bets = await')),
    );
  });

  test('Both games poll separate round / my-bets / history calls every 3s (no combined state call)', () {
    final fruitParty =
        File('lib/screens/fruit_party_screen.dart').readAsStringSync();
    expect(fruitParty, isNot(contains('fruitPartyState(')));
    expect(fruitParty, contains('fruitPartyRound()'));
    expect(fruitParty, contains('fruitPartyMyBets()'));
    expect(fruitParty, contains('fruitPartyHistory()'));
    final fruitTimer = fruitParty.substring(
      fruitParty.indexOf('stateTimer = Timer.periodic'),
    );
    expect(
      fruitTimer.substring(0, 150),
      contains('Duration(seconds: 3)'),
    );
    expect(fruitParty, isNot(contains('Duration(seconds: 5)')));

    final greedyGirl =
        File('lib/screens/greedy_girl_screen.dart').readAsStringSync();
    expect(greedyGirl, isNot(contains('greedyGirlState(')));
    expect(greedyGirl, contains('greedyGirlRound()'));
    expect(greedyGirl, contains('greedyGirlMyBets()'));
    expect(greedyGirl, contains('greedyGirlHistory()'));
    final greedyTimer = greedyGirl.substring(
      greedyGirl.indexOf('refreshTimer = Timer.periodic'),
    );
    expect(
      greedyTimer.substring(0, 150),
      contains('Duration(seconds: 3)'),
    );
    // The only 5s timer left in Greedy Girl is the local kiss-emote
    // video replay — it makes no network call.
    expect('Duration(seconds: 5)'.allMatches(greedyGirl).length, 1);
    expect(
      greedyGirl,
      contains('_kissTimer = Timer.periodic('),
    );

    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, isNot(contains("'/api/games/fruit-party/state'")));
    expect(api, isNot(contains("'/api/games/greedy-girl/state'")));
    expect(api, contains("'/api/games/fruit-party/round'"));
    expect(api, contains("'/api/games/fruit-party/my-bets'"));
    expect(api, contains("'/api/games/fruit-party/history'"));
    expect(api, contains("'/api/games/greedy-girl/round'"));
    expect(api, contains("'/api/games/greedy-girl/my-bets'"));
    expect(api, contains("'/api/games/greedy-girl/history'"));
  });
}
