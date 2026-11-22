import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Dollar level (Vinay, 2026-11-23): a level based on the user's total
// recharge in dollars (L1 $2 ... L10 $250, L100 $11,000, L200 $25,000).
// It shows next to the Wealth level — on the ID (profile) where the
// Wealth level card is, and inside the Wealth level screen.
void main() {
  test('profile shows a Dollar Level card next to the Wealth level card',
      () {
    final screen =
        File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(screen, contains("title: 'Dollar Level',"));
    expect(screen, contains("socialStats['dollar_level']"));
    expect(screen, contains('Icons.attach_money_rounded'));
    // It opens the same Wealth level screen as the Wealth card.
    expect(
      screen,
      contains('builder: (_) => WealthLevelScreen(state: state)'),
    );
  });

  test('wealth level screen shows the dollar level and lifetime recharge',
      () {
    final screen =
        File('lib/screens/mine_social_screens.dart').readAsStringSync();
    expect(screen, contains("stats['dollar_level']"));
    expect(screen, contains("stats['total_recharged_usd_cents']"));
    expect(screen, contains('Lifetime recharge: '));
    expect(screen, contains("title: const Text('Next dollar level')"));
    expect(screen, contains('total recharge required'));
  });
}
