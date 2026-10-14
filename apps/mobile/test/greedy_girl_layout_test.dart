import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/greedy_girl_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(412, 892)]) {
    testWidgets('Greedy Girl in-room overlay keeps room seats visible at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
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
      screen.setState(() {
        screen.game = <String, dynamic>{
          'round': <String, dynamic>{
            'round_id': 9,
            'phase': 'betting',
            'round_end': DateTime.now().millisecondsSinceEpoch + 30000,
            'betting_open': true,
          },
          'config': <String, dynamic>{
            'bet_amounts': <int>[100, 1000, 10000, 50000, 100000],
          },
          'my_bets': <String, int>{},
          'history': <Map<String, dynamic>>[],
          'wallet_balance': 2500000,
          'today_winnings': 0,
        };
        screen.loading = false;
      });
      await tester.pump();

      expect(
        tester.getSize(find.byType(GreedyGirlScreen)).height,
        closeTo(size.height * .69, .1),
      );
      expect(find.text('Greedy Girl'), findsOneWidget);
      expect(find.text('21+'), findsNothing);
      expect(find.byKey(const Key('greedy-girl-room-overlay')), findsOneWidget);
      expect(find.byKey(const Key('greedy-girl-mascot')), findsOneWidget);
      expect(find.byKey(const Key('greedy-girl-countdown')), findsOneWidget);
      expect(
        find.byKey(const Key('greedy-girl-countdown-number')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('greedy-girl-tomato')), findsOneWidget);
      expect(find.byKey(const Key('greedy-girl-skewer')), findsOneWidget);
      expect(tester.takeException(), isNull);

      screen.setState(() {
        screen.game = <String, dynamic>{};
        screen.loading = false;
        screen.loadError = 'Greedy Girl server did not respond. Tap Retry.';
      });
      await tester.pump();
      expect(find.textContaining('server did not respond'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      screen.setState(() {
        screen.game = <String, dynamic>{
          'round': <String, dynamic>{
            'round_id': 9,
            'phase': 'betting',
            'round_end': DateTime.now().millisecondsSinceEpoch + 30000,
            'betting_open': true,
          },
          'config': <String, dynamic>{
            'bet_amounts': <int>[100, 1000, 10000, 50000, 100000],
          },
          'my_bets': <String, int>{},
          'history': <Map<String, dynamic>>[],
          'wallet_balance': 2500000,
          'today_winnings': 0,
        };
        screen.loadError = null;
      });
      await tester.pump();

      await tester.tap(find.byTooltip('Rules'));
      await tester.pump();
      expect(find.textContaining('Each round has 30 seconds'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Back to game'));
      await tester.pump();
      await tester.tap(find.byTooltip('Close Greedy Girl'));
      await tester.pumpAndSettle();
      expect(find.byType(GreedyGirlScreen), findsNothing);

      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
}
