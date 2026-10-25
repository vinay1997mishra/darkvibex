import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('21 free animated store frames use a two second loop', () {
    final frameSource =
        File('lib/widgets/vip_animated_frame.dart').readAsStringSync();
    final shopSource =
        File('lib/screens/cosmetics_shop_screen.dart').readAsStringSync();

    const ids = <String>[
      'frame_golden_crown',
      'frame_pink_heart',
      'frame_blue_butterfly',
      'frame_red_rose',
      'frame_purple_star',
      'frame_golden_flower',
      'frame_pink_blossom',
      'frame_blue_angel_crown',
      'frame_red_black_royal_wings',
      'frame_purple_butterfly',
      'frame_royal_love',
      'frame_green_nature',
      'frame_blue_magic_butterfly',
      'frame_golden_butterfly_queen',
      'frame_purple_dream_butterfly',
      'frame_neon_butterfly',
      'frame_crystal_aurora',
      'frame_neon_comet',
      'frame_rose_galaxy',
      'frame_solar_empress',
      'frame_emerald_dragon',
    ];

    for (final id in ids) {
      expect(frameSource, contains("'$id'"));
    }
    expect(frameSource, contains('_freeAnimatedFrameIds.contains(styleId) ||'));
    expect(frameSource, contains('_rocketFrameStyleAliases.containsKey(styleId)'));
    expect(frameSource, contains('? 2000'));
    expect(frameSource, contains(': 3200'));
    expect(shopSource, contains("price <= 0 ? 'FREE'"));
    expect(shopSource, contains("price <= 0 ? 'Get Free' : 'Buy'"));
    expect(shopSource, contains("durationDays <= 0 ? 'Permanent'"));
    expect(shopSource, contains("'frame_crystal_aurora'"));
    expect(shopSource, contains("'frame_neon_comet'"));
    expect(shopSource, contains("'frame_rose_galaxy'"));
    expect(shopSource, contains("'frame_solar_empress'"));
    expect(shopSource, contains("'frame_emerald_dragon'"));
    expect(shopSource, contains("'0 COINS'"));
    expect(shopSource, contains("zeroCoinBuy"));
    expect(frameSource, contains('_PremiumVectorFramePainter'));
    expect(frameSource, contains('PathFillType.evenOdd'));
    expect(frameSource, contains('_paintRingRivets'));
    expect(frameSource, contains('final outerRadius = radius + side * .045'));
    expect(frameSource, contains('final leftFacet = Path()'));
    expect(frameSource, contains('RadialGradient'));
    expect(frameSource, contains('Veins catch the light'));
    expect(frameSource, contains('A moving specular highlight'));
    expect(frameSource, contains('A softly glowing fan'));
    expect(frameSource, contains('cycle / 8 + i * math.pi / 4'));
    expect(frameSource, contains('cycle / 6 + i * math.pi / 3'));
    expect(frameSource, contains('cycle / 4 + i * math.pi / 2'));
    expect(frameSource, contains('_ButterflyFrameBasePainter'));
    expect(frameSource, contains('_ButterflyFlightPainter'));
    expect(frameSource, contains('final flyAngle = -math.pi / 2 + cycle'));
    expect(frameSource, contains('canvas.scale(direction * flap, 1)'));
    expect(frameSource, contains("'frame_neon_butterfly'"));
    expect(frameSource, contains('scale: 1.42'));
    expect(frameSource, isNot(contains('Padding(padding: const EdgeInsets.all(8), child: widget.child)')));
  });
}
