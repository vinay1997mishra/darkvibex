import 'package:darkvibex/widgets/level_medal.dart';
import 'package:darkvibex/widgets/vip_tag_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('VIP 1 medal falls back to the bundled SVG when the R2 '
      'image cannot load', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LevelMedal(
            series: MedalSeries.vip,
            level: 1,
            size: 84,
            animated: false,
          ),
        ),
      ),
    );
    // In tests every network image fails (HTTP 400), so the R2 image
    // errors and the errorBuilder renders the bundled SVG fallback.
    // The Image widget itself stays mounted after the error (it renders
    // the fallback inside itself), so only the SVG is asserted here.
    // The R2 URL itself is proven by the vipMedalUrlForVipLevel tests.
    await tester.pump();
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('VIP 5 medal uses the bundled SVG (no R2 PNG yet)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LevelMedal(
            series: MedalSeries.vip,
            level: 5,
            size: 84,
            animated: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('VIP ID tag renders the R2 tag image next to the ID',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VipTagImage(vipLevel: 1, fontSize: 12),
        ),
      ),
    );
    // Checked on the first frame, before the (failing in tests)
    // network load's error fires and swaps in the empty fallback.
    expect(find.byType(Image), findsOneWidget);
    // Height follows the neighbouring text: fontSize 12 x 1.5 = 18.
    expect(tester.widget<Image>(find.byType(Image)).height, 18);
  });

  testWidgets('VIP ID tag renders nothing for VIP 0 (no VIP, no tag)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VipTagImage(vipLevel: 0, fontSize: 12),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
