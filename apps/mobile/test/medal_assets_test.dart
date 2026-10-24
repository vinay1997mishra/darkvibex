import 'package:flutter_test/flutter_test.dart';

import '../lib/widgets/level_medal.dart';

void main() {
  test('all medal levels resolve to separate vector asset files', () {
    for (var level = 1; level <= 18; level++) {
      expect(
        LevelMedal.assetPath(MedalSeries.vip, level),
        'assets/medals/vip_${level.toString().padLeft(2, '0')}.svg',
      );
    }
    for (var level = 1; level <= 12; level++) {
      expect(
        LevelMedal.assetPath(MedalSeries.rocket, level),
        'assets/medals/rocket_${level.toString().padLeft(2, '0')}.svg',
      );
    }
  });

  test('out of range level requests clamp to collection boundaries', () {
    expect(LevelMedal.assetPath(MedalSeries.vip, 0), 'assets/medals/vip_01.svg');
    expect(LevelMedal.assetPath(MedalSeries.vip, 99), 'assets/medals/vip_18.svg');
    expect(LevelMedal.assetPath(MedalSeries.rocket, 0), 'assets/medals/rocket_01.svg');
    expect(LevelMedal.assetPath(MedalSeries.rocket, 99), 'assets/medals/rocket_12.svg');
  });
}
