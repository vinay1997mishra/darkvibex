import 'dart:io';

import 'package:darkvibex/screens/vip_section_screen.dart';
import 'package:darkvibex/widgets/vip_tag_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, {int level = 8}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VipSectionScreen(
          currentLevel: level,
          active: true,
          vipExpBalance: 300000,
          monthlyPoints: 300000,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('VIP section renders the new screen with real artwork',
      (tester) async {
    await pumpScreen(tester);
    // Sections from the reference SVIP layout.
    expect(find.text('VIP Identity'), findsOneWidget);
    expect(find.text('Exclusive Privileges'), findsOneWidget);
    // Real animal emblem: the R2 frame still is an Image.network; in
    // tests the network image fails and the emoji fallback renders, but
    // the Image widget itself stays mounted (errorBuilder inside it).
    expect(find.byType(Image), findsWidgets);
    // VIP tag image (R2-based, works for all 18 levels).
    expect(find.byType(VipTagImage), findsOneWidget);
    // Animal name for the selected level (VIP8 = Panther).
    expect(find.textContaining('Panther'), findsWidgets);
  });

  testWidgets('Gift Banner is a real reward, not "Coming soon"',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Gift Banner'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);
  });

  testWidgets('Exp 110% Speed up is shown as a real privilege',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Exp 110% Speed up'), findsOneWidget);
    expect(find.text('Not in DarkVibeX'), findsNothing);
    expect(find.text('More Profile Background'), findsNothing);
  });

  testWidgets('Coins Bonus shows the real purchase bonus by level',
      (tester) async {
    // VIP8 -> +5% (VIP5+ tier).
    await pumpScreen(tester, level: 8);
    expect(find.text('Coins Bonus +5%'), findsOneWidget);
    expect(find.text('Coins x800,000'), findsNothing);
  });

  testWidgets('Coins Bonus shows +20% at the top tier', (tester) async {
    // VIP16 -> +20% (top tier).
    await pumpScreen(tester, level: 16);
    expect(find.text('Coins Bonus +20%'), findsOneWidget);
  });

  testWidgets('Frame card shows the animal frame, not a dragon frame',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Dragon frame'), findsNothing);
    expect(find.text('Animal frame'), findsOneWidget);
  });

  testWidgets('VIP Points label shows the user points',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('VIP Points: 300000'), findsOneWidget);
    expect(find.textContaining('Monthly VIP Points'), findsNothing);
  });

  test('VIP win card trophy is the real gold trophy image, never the trophy emoji (Vinay, 2026-11-23)',
      () {
    final source =
        File('lib/screens/vip_section_screen.dart').readAsStringSync();
    expect(source, contains('gold_trophy.png'));
    expect(source, isNot(contains('🏆')));
  });
}
