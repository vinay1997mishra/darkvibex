import 'dart:io';

import 'package:darkvibex/screens/vip_section_screen.dart';
import 'package:darkvibex/vip/vip_visual_assets.dart';
import 'package:darkvibex/widgets/transparent_artwork_image.dart';
import 'package:darkvibex/widgets/vip_frame_alpha_video.dart';
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

  testWidgets('VIP section renders the new screen with real artwork', (
    tester,
  ) async {
    await pumpScreen(tester);
    // Sections from the reference SVIP layout.
    expect(find.text('VIP Identity'), findsOneWidget);
    expect(find.text('Exclusive Privileges'), findsOneWidget);
    // Real animal emblem: the R2 animation video is a VipFrameAlphaVideo;
    // in tests the VAP player cannot initialise and the PNG still shows
    // via TransparentArtworkImage (it paints the decoded image itself).
    expect(find.byType(VipFrameAlphaVideo), findsOneWidget);
    expect(find.byType(TransparentArtworkImage), findsOneWidget);
    // VIP tag is gold "VIP N" text (no R2 plaque image), works for all
    // 18 levels (Vinay, 2026-11-23).
    expect(find.byType(VipTagImage), findsOneWidget);
    // Animal name for the selected level (VIP8 = Panther).
    expect(find.textContaining('Panther'), findsWidgets);
  });

  testWidgets('Gift Banner is a real reward, not "Coming soon"', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Gift Banner'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);
  });

  testWidgets('Exp 110% Speed up is shown as a real privilege', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Exp 110% Speed up'), findsOneWidget);
    expect(find.text('Not in DarkVibeX'), findsNothing);
    expect(find.text('More Profile Background'), findsNothing);
  });

  testWidgets('Coins Bonus shows the real purchase bonus by level', (
    tester,
  ) async {
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

  testWidgets('Frame card shows the animal frame, not a dragon frame', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Dragon frame'), findsNothing);
    expect(find.text('Animal frame'), findsOneWidget);
  });

  testWidgets('VIP Points label shows the user points', (tester) async {
    await pumpScreen(tester);
    expect(find.text('VIP Points: 300000'), findsOneWidget);
    expect(find.textContaining('Monthly VIP Points'), findsNothing);
  });

  testWidgets(
    'VIP background is the gold texture pic, cards are black glass (Mr. Wrong, 2026-11-25)',
    (tester) async {
      await pumpScreen(tester);
      // The gold silk texture pic is the screen background (a
      // DecorationImage on the outer Container, not an Image widget).
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).image?.image is AssetImage &&
              ((widget.decoration as BoxDecoration).image!.image as AssetImage)
                      .assetName ==
                  'assets/images/vip_gold_bg.jpg',
        ),
        findsOneWidget,
      );
      // Section titles are dark purple on the gold background.
      final title = tester.widget<Text>(find.text('VIP Identity'));
      expect(title.style?.color, VipSectionColors.onGold);
      // Cards are black glass (translucent black over the gold pic).
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  VipSectionColors.cardGlass,
        ),
        findsWidgets,
      );
      // Unlocked card titles are gold on the black glass.
      final coins = tester.widget<Text>(find.text('Coins Bonus +5%'));
      expect(coins.style?.color, VipSectionColors.gold);
    },
  );

  testWidgets(
    'Emblem plays the R2 animation video, not a still photo (Mr. Wrong, 2026-11-25)',
    (tester) async {
      await pumpScreen(tester);
      // VIP8 = Panther: the VAP mp4 from R2, with the transparent PNG
      // still as the poster/fallback.
      expect(find.byType(VipFrameAlphaVideo), findsOneWidget);
      final video = tester.widget<VipFrameAlphaVideo>(
        find.byType(VipFrameAlphaVideo),
      );
      expect(video.videoUrl, vipFrameVapUrlForVipLevel(8));
      expect(video.videoUrl, contains('vap/vip8-panther.mp4'));
      expect(video.stillUrl, vipFrameStillUrlForVipLevel(8));
      // The still poster is painted by TransparentArtworkImage (it decodes
      // and paints the ui.Image itself — no plain Image widget).
      expect(find.byType(TransparentArtworkImage), findsOneWidget);
    },
  );

  testWidgets('VIP1 emblem has no video — still only, by design', (
    tester,
  ) async {
    await pumpScreen(tester, level: 1);
    expect(find.byType(VipFrameAlphaVideo), findsOneWidget);
    final video = tester.widget<VipFrameAlphaVideo>(
      find.byType(VipFrameAlphaVideo),
    );
    expect(video.videoUrl, isNull);
    expect(video.stillUrl, vipFrameStillUrlForVipLevel(1));
  });

  testWidgets(
    'VIP Identity shows all 8 real items: Frame, Label, Ride and the rest (Mr. Wrong, 2026-11-25)',
    (tester) async {
      await pumpScreen(tester);
      // The real backend-backed items: coins bonus, label (VIP tag),
      // medal, frame, profile card, ride, chat bubble, gift banner.
      for (final label in <String>[
        'Coins Bonus +5%',
        'Label',
        'VIP Medal',
        'Frame',
        'Profile Card',
        'Ride: Panther',
        'Chat Bubble',
        'Gift Banner',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    },
  );

  testWidgets('Locked identity cards still show (dimmed, never hidden)', (
    tester,
  ) async {
    // VIP1: Coins Bonus (minLevel 5) and Ride (minLevel 5) are locked,
    // but they must still be visible on the gold background.
    await pumpScreen(tester, level: 1);
    expect(find.text('Coins Bonus'), findsOneWidget);
    expect(find.textContaining('Ride: '), findsOneWidget);
    // Locked signal is the dimmed title, not a hidden card.
    final coins = tester.widget<Text>(find.text('Coins Bonus'));
    expect(coins.style?.color, VipSectionColors.textDim);
  });

  test(
    'VIP win card trophy is the real gold trophy image, never the trophy emoji (Vinay, 2026-11-23)',
    () {
      final source = File(
        'lib/screens/vip_section_screen.dart',
      ).readAsStringSync();
      expect(source, contains('gold_trophy.png'));
      expect(source, isNot(contains('🏆')));
    },
  );
}
