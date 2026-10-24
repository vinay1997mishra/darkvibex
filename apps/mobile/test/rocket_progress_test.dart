import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/utils/rocket_progress.dart';

void main() {
  group('calculateRocketProgress', () {
    test('starts at zero and clamps negative totals', () {
      expect(calculateRocketProgress(0)['completed'], 0);
      expect(calculateRocketProgress(-100)['current_progress'], 0);
      expect(calculateRocketProgress(-100)['percent'], 0.0);
      expect(calculateRocketProgress(7999999)['completed'], 0);
    });

    test('uses cumulative room-gift milestone totals', () {
      final levelOne = calculateRocketProgress(8000000);
      expect(levelOne['completed'], 1);
      expect(levelOne['current_progress'], 8000000);
      expect(levelOne['current_target'], 15000000);

      final levelTwo = calculateRocketProgress(15000000);
      expect(levelTwo['completed'], 2);
      expect(levelTwo['current_progress'], 15000000);
      expect(levelTwo['current_target'], 30000000);
    });

    test('marks all ten stages complete at the final cumulative target', () {
      final completed = calculateRocketProgress(500000000);
      expect(completed['completed'], 10);
      expect(completed['current_progress'], 500000000);
      expect(completed['current_target'], 500000000);
      expect(completed['percent'], 1.0);

      expect(calculateRocketProgress(900000000)['completed'], 10);
    });
  });
}
