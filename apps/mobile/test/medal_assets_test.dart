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

  test('VIP shield medals 1-4 resolve to direct R2 PNG URLs', () {
    for (var level = 1; level <= 4; level++) {
      expect(
        vipMedalUrlForVipLevel(level),
        '$kVipVisualR2PublicBaseUrl/vip-medals/vip$level-medal.png',
      );
    }
  });

  test('VIP shield medals 5-18 have no R2 PNG yet (null)', () {
    for (var level = 5; level <= 18; level++) {
      expect(vipMedalUrlForVipLevel(level), isNull);
    }
    expect(vipMedalUrlForVipLevel(0), isNull);
    expect(vipMedalUrlForVipLevel(99), isNull);
  });

  test('all 18 VIP tags resolve to direct R2 PNG URLs', () {
    for (var level = 1; level <= 18; level++) {
      expect(
        vipTagUrlForVipLevel(level),
        '$kVipVisualR2PublicBaseUrl/vip-tags/vip$level-tag.png',
      );
    }
  });

  test('VIP tags out of range resolve to null', () {
    expect(vipTagUrlForVipLevel(0), isNull);
    expect(vipTagUrlForVipLevel(19), isNull);
    expect(vipTagUrlForVipLevel(99), isNull);
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
