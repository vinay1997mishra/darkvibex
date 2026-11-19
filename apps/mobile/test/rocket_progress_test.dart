import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/utils/rocket_progress.dart';

void main() {
  group('calculateRocketProgress', () {
    test('starts at zero and clamps negative totals', () {
      expect(calculateRocketProgress(0)['completed'], 0);
      expect(calculateRocketProgress(-100)['current_progress'], 0);
      expect(calculateRocketProgress(-100)['percent'], 0.0);
      expect(calculateRocketProgress(11999999)['completed'], 0);
    });

    test('uses cumulative room-gift milestone totals', () {
      final levelOne = calculateRocketProgress(12000000);
      expect(levelOne['completed'], 1);
      expect(levelOne['current_progress'], 12000000);
      expect(levelOne['current_target'], 18000000);

      final levelTwo = calculateRocketProgress(18000000);
      expect(levelTwo['completed'], 2);
      expect(levelTwo['current_progress'], 18000000);
      expect(levelTwo['current_target'], 25000000);
    });

    test('keeps levels 11–18 progressing and marks all stages complete at level 18', () {
      final levelTen = calculateRocketProgress(102000000);
      expect(levelTen['completed'], 10);
      expect(levelTen['current_progress'], 102000000);
      expect(levelTen['current_target'], 117000000);
      expect(levelTen['percent'], closeTo(102000000 / 117000000, 1e-9));

      final levelEleven = calculateRocketProgress(117000000);
      expect(levelEleven['completed'], 11);
      expect(levelEleven['current_progress'], 117000000);
      expect(levelEleven['current_target'], 133000000);

      final levelTwelve = calculateRocketProgress(133000000);
      expect(levelTwelve['completed'], 12);
      expect(levelTwelve['current_progress'], 133000000);
      expect(levelTwelve['current_target'], 150000000);

      final levelSeventeen = calculateRocketProgress(228000000);
      expect(levelSeventeen['completed'], 17);
      expect(levelSeventeen['current_progress'], 228000000);
      expect(levelSeventeen['current_target'], 250000000);

      final completed = calculateRocketProgress(250000000);
      expect(completed['completed'], 18);
      expect(completed['current_progress'], 250000000);
      expect(completed['current_target'], 250000000);
      expect(completed['percent'], 1.0);
      expect(calculateRocketProgress(300000000)['completed'], 18);
    });
  });
}
