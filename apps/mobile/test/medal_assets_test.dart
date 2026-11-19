import 'package:flutter_test/flutter_test.dart';

import '../lib/vip/vip_visual_assets.dart';
import '../lib/widgets/level_medal.dart';

void main() {
  test('all VIP medal levels resolve to separate vector asset files', () {
    for (var level = 1; level <= 18; level++) {
      expect(
        LevelMedal.assetPath(MedalSeries.vip, level),
        'assets/medals/vip_${level.toString().padLeft(2, '0')}.svg',
      );
    }
  });

  test('rocket medals 1-12 keep their bundled vector fallback files', () {
    for (var level = 1; level <= 12; level++) {
      expect(
        LevelMedal.assetPath(MedalSeries.rocket, level),
        'assets/medals/rocket_${level.toString().padLeft(2, '0')}.svg',
      );
    }
  });

  test('all 18 Rocket medals resolve to direct R2 PNG URLs', () {
    for (var level = 1; level <= 18; level++) {
      expect(
        rocketMedalUrlForLevel(level),
        '$kVipVisualR2PublicBaseUrl/rocket-medals/rocket-medal-lv${level.toString().padLeft(2, '0')}.png',
      );
    }
  });

  test('out of range level requests clamp to collection boundaries', () {
    expect(LevelMedal.assetPath(MedalSeries.vip, 0), 'assets/medals/vip_01.svg');
    expect(LevelMedal.assetPath(MedalSeries.vip, 99), 'assets/medals/vip_18.svg');
    expect(LevelMedal.assetPath(MedalSeries.rocket, 0), 'assets/medals/rocket_01.svg');
    expect(LevelMedal.assetPath(MedalSeries.rocket, 99), 'assets/medals/rocket_12.svg');
    expect(
      rocketMedalUrlForLevel(0),
      '$kVipVisualR2PublicBaseUrl/rocket-medals/rocket-medal-lv01.png',
    );
    expect(
      rocketMedalUrlForLevel(99),
      '$kVipVisualR2PublicBaseUrl/rocket-medals/rocket-medal-lv18.png',
    );
  });
}
