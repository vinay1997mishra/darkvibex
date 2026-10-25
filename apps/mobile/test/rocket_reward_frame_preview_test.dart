import 'package:darkvibex/utils/rocket_reward_frames.dart';
import 'package:darkvibex/widgets/rocket_reward_frame_preview.dart';
import 'package:darkvibex/widgets/vip_animated_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Rocket reward groups map to the matching permanent artwork styles', () {
    expect(rocketRewardFrameForGroup('1-3'), {
      'id': 'rocket_frame_aurora',
      'name': 'Rocket Aurora',
      'style': 'frame_blue_magic_butterfly',
    });
    expect(rocketRewardFrameForGroup('4-6')['style'], 'frame_neon_butterfly');
    expect(rocketRewardFrameForGroup('7-9')['style'], 'frame_golden_butterfly_queen');
    expect(rocketRewardFrameForGroup('10-12')['style'], 'frame_purple_dream_butterfly');
    expect(rocketRewardFrameForGroup('unknown')['id'], 'rocket_frame_aurora');
  });

  testWidgets('Rocket frame preview renders a circular animated avatar frame',
      (tester) async {
    for (final group in <String>['1-3', '4-6', '7-9', '10-12']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RocketRewardFramePreview(rewardGroup: group, size: 58),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(RocketRewardFramePreview), findsOneWidget);
      expect(find.byType(VipAnimatedFrame), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
