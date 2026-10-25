import 'package:flutter/material.dart';

import '../utils/rocket_reward_frames.dart';
import 'vip_animated_frame.dart';

/// Circular animated frame preview used by the Rocket reward chest.
class RocketRewardFramePreview extends StatelessWidget {
  const RocketRewardFramePreview({
    super.key,
    required this.rewardGroup,
    this.size = 64,
  });

  final String? rewardGroup;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reward = rocketRewardFrameForGroup(rewardGroup);
    return SizedBox.square(
      dimension: size,
      child: VipAnimatedFrame(
        size: size,
        enabled: true,
        level: 12,
        styleId: reward['id'],
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                Color(0xFF253D85),
                Color(0xFF111B48),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.rocket_launch_rounded,
            size: size * .42,
            color: const Color(0xFF50D8FF),
          ),
        ),
      ),
    );
  }
}
