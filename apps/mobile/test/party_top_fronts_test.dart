import 'dart:io';

import 'package:darkvibex/widgets/top_front_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopFrontPill (Vinay, 2026-11-23)', () {
    Widget pill({
      List<String> avatarUrls = const [],
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TopFrontPill(
            label: 'Top Rooms',
            gradientColors: const [Color(0xFFFFE9A8), Color(0xFFD09A0A)],
            textColor: const Color(0xFF3A2A00),
            avatarUrls: avatarUrls,
            avatarHeaders: const {},
            fallbackIcon: Icons.emoji_events_rounded,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    testWidgets('shows the label and the fallback icon with no avatars',
        (tester) async {
      await tester.pumpWidget(pill());
      expect(find.text('Top Rooms'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('tap calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(pill(onTap: () => tapped = true));
      await tester.tap(find.text('Top Rooms'));
      expect(tapped, isTrue);
    });

    testWidgets('shows up to 3 avatars, never more', (tester) async {
      await tester.pumpWidget(pill(avatarUrls: const [
        'https://example.invalid/a.png',
        'https://example.invalid/b.png',
        'https://example.invalid/c.png',
        'https://example.invalid/d.png',
      ]));
      await tester.pump();
      // The images fail to load in tests; errorBuilder shows the fallback,
      // but the Image widgets themselves are still built (max 3).
      expect(find.byType(Image), findsNWidgets(3));
    });
  });

  group('Party page fronts source (Vinay, 2026-11-23)', () {
    test('only Top Rooms + Top Family pills; old card row is gone', () {
      final source = File(
        'lib/screens/home_shell.dart',
      ).readAsStringSync();
      expect(source, contains("Key('party-top-rooms-pill')"));
      expect(source, contains("Key('party-top-family-pill')"));
      expect(source, contains("label: 'Top Rooms'"));
      expect(source, contains("label: 'Top Family'"));
      expect(source, isNot(contains('_QuickCard')));
      expect(source, isNot(contains("label: 'CP Ranking'")));
      // The pills open the same pages the old cards did.
      expect(source, contains('_openRankings(context, initialTab: 0)'));
      expect(source, contains('FamilyRankingScreen(state: state)'));
    });
  });
}
