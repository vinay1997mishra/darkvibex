import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/utils/rocket_frame_catalog.dart';

void main() {
  test('catalog defines 100 unique circular Rocket frame IDs', () {
    final ids = <String>{
      for (final group in <String>['1-3', '4-6', '7-9', '10-12'])
        for (var slot = 1; slot <= 25; slot++)
          rocketFrameIdForSlot(group, slot),
    };
    expect(ids, hasLength(100));
    expect(ids.every(isRocketRewardFrameId), isTrue);
  });

  test('Rocket frame IDs retain reward group, slot, and configured duration', () {
    expect(rocketFrameIdForSlot('1-3', 1), 'rocket_frame_g1_01');
    expect(rocketFrameIdForSlot('4-6', 13), 'rocket_frame_g2_13');
    expect(rocketFrameIdForSlot('7-9', 25), 'rocket_frame_g3_25');
    expect(rocketFrameIdForSlot('10-12', 9), 'rocket_frame_g4_09');
    expect(rocketFrameRewardGroup('rocket_frame_g3_25'), '7-9');
    expect(rocketFrameVariant('rocket_frame_g4_09'), 9);
    expect(rocketFrameDurationDays('rocket_frame_g2_13'), 5);
    expect(rocketFrameDurationDays('rocket_frame_g4_25'), 10);
    expect(isRocketRewardFrameId('rocket_frame_g4_26'), isFalse);
  });

  test('bad frame slots are rejected instead of creating invalid IDs', () {
    expect(() => rocketFrameIdForSlot('unknown', 1), throwsArgumentError);
    expect(() => rocketFrameIdForSlot('1-3', 0), throwsArgumentError);
    expect(() => rocketFrameIdForSlot('1-3', 26), throwsArgumentError);
  });
}
