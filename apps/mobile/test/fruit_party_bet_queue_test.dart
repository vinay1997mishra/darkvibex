import 'dart:io';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/fruit_party_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Fruit Party bet queue: no placingBet lock anywhere (Vinay, 2026-11-23)',
    () {
      final source =
          File('lib/screens/fruit_party_screen.dart').readAsStringSync();
      expect(source, isNot(contains('placingBet')));
      expect(source, contains('betQueue'));
      expect(source, contains('drainingBetQueue'));
      expect(source, contains('queuedDebit'));
      expect(source, contains('_drainBetQueue'));
      expect(source, contains('_QueuedFruitBet'));
      // Girl tiles fire on every tap while betting is open — no in-flight lock.
      expect(
        source,
        contains(
          'onTap: _bettingOpen ? () => unawaited(_placeBet(key)) : null,',
        ),
      );
      // Amount chips never lock either, so the amount can change mid-queue.
      expect(
        source,
        contains('onTap: () => setState(() => selectedBet = amount),'),
      );
    },
  );

  testWidgets(
    'Fruit Party rapid taps queue every bet at once, amount chips stay live',
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
        screen.game = <String, dynamic>{
          'round': <String, dynamic>{
            'round_id': 42,
            'phase': 'betting',
            'round_end': now + 30000,
            'cycle_end': now + 40000,
          },
          'config': <String, dynamic>{
            'bet_amounts': <int>[5000, 25000, 100000, 500000, 2000000],
          },
          'my_bets': <String, dynamic>{},
          'history': <Map<String, dynamic>>[],
          'wallet_balance': 2500000,
          'today_winnings': 0,
        };
        screen.serverTimeAtSync = now;
        screen.localTimeAtSync = now;
        screen.loading = false;
      });
      await tester.pump();

      // Tap 1: queues at once and the shown balance drops by the bet amount.
      await tester.tap(find.byKey(const Key('fruit-party-lemon')));
      await tester.pump();
      expect(state.coins, 2495000);

      // The server confirms the first bet, so the next state carries the
      // reduced balance (in production this comes back in the bet response
      // or the next poll). Without it the displayed balance cannot tell a
      // second tap apart from the first.
      screen.setState(() {
        final next = Map<String, dynamic>.from(screen.game);
        next['wallet_balance'] = 2495000;
        screen.game = next;
      });
      await tester.pump();

      // Tap 2: must land too — the old placingBet lock swallowed it.
      await tester.tap(find.byKey(const Key('fruit-party-lemon')));
      await tester.pump();
      expect(state.coins, 2490000);

      // The queue drains on its own (the mocked backend fails in tests)
      // and leaves nothing stuck behind.
      await tester.pump(const Duration(milliseconds: 500));
      expect(screen.betQueue.isEmpty, isTrue);
      expect(screen.queuedDebit, 0);

      // The amount chips stay live while bets are queued.
      await tester.tap(find.byKey(const Key('fruit-party-bet-25K')));
      await tester.pump();
      expect(screen.selectedBet, 25000);

      await tester.tap(find.byTooltip('Close Girls Party'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
