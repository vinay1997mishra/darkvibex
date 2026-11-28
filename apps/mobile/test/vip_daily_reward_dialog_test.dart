import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app/app_state.dart';
import '../lib/screens/vip_daily_reward_dialog.dart';

AppState _vip5State({bool claimed = false}) {
  final state = AppState()
    ..vipLevel = 5
    ..vipActiveUntil = DateTime.now().add(const Duration(days: 30))
    ..dailyRewardReady = true
    ..dailyRewardEligible = true
    ..dailyRewardAmount = 28000000
    ..dailyRewardClaimedToday = claimed
    ..dailyRewardClaimedCoins = claimed ? 28000000 : 0;
  return state;
}

void main() {
  testWidgets('daily reward pop-up shows today amount with Claim',
      (tester) async {
    final state = _vip5State();
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showVipDailyRewardDialog(context, state: state),
          child: const Text('open'),
        );
      })),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Reward'), findsOneWidget);
    expect(find.text('28,000,000 coins'), findsOneWidget);
    expect(find.text('Claim'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('daily reward pop-up shows the claimed state after claiming',
      (tester) async {
    final state = _vip5State(claimed: true);
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showVipDailyRewardDialog(context, state: state),
          child: const Text('open'),
        );
      })),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Claimed'), findsOneWidget);
    expect(find.text('+28,000,000 coins added to your wallet.'),
        findsOneWidget);
    expect(find.text('Claim'), findsNothing);
  });

  testWidgets('daily reward pop-up tells VIP1-4 it unlocks at VIP 5',
      (tester) async {
    final state = AppState()
      ..vipLevel = 4
      ..vipActiveUntil = DateTime.now().add(const Duration(days: 30))
      ..dailyRewardReady = true
      ..dailyRewardEligible = false
      ..dailyRewardAmount = 0;
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => showVipDailyRewardDialog(context, state: state),
          child: const Text('open'),
        );
      })),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Unlocks at VIP 5 — claim coins every day.'),
        findsOneWidget);
    expect(find.text('Claim'), findsNothing);
  });
}
