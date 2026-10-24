import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/recharge_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'main wallet Diamonds card opens the exchange page',
    (tester) async {
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(home: RechargeScreen(state: state)),
      );
      await tester.pump();

      final diamondCard = find.byKey(const Key('recharge-diamonds-card'));
      expect(diamondCard, findsOneWidget);
      expect(find.text('Tap to exchange'), findsOneWidget);

      await tester.tap(diamondCard);
      // The screen shows an indeterminate progress bar while wallet history
      // loads, so pump the route transition without waiting for all animations
      // to settle.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byKey(const Key('diamond-exchange-panel')), findsOneWidget);
      expect(find.text('Exchange Diamonds to Coins'), findsOneWidget);
      expect(find.text('Rate: 100 Diamonds = 60 Coins (60%)'), findsOneWidget);
    },
  );
}
