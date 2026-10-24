import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum MedalSeries { vip, rocket }

/// Reusable, lightweight animated badge for DarkVibeX VIP and Rocket tiers.
/// Each tier uses its own transparent SVG asset.
class LevelMedal extends StatefulWidget {
  const LevelMedal({
    super.key,
    required this.series,
    required this.level,
    this.size = 84,
    this.animated = true,
  });

  final MedalSeries series;
  final int level;
  final double size;
  final bool animated;

  static String assetPath(MedalSeries series, int level) {
    final safeLevel = series == MedalSeries.vip
        ? level.clamp(1, 18).toInt()
        : level.clamp(1, 12).toInt();
    final prefix = series == MedalSeries.vip ? 'vip' : 'rocket';
    return 'assets/medals/${prefix}_${safeLevel.toString().padLeft(2, '0')}.svg';
  }

  @override
  State<LevelMedal> createState() => _LevelMedalState();
}

class _LevelMedalState extends State<LevelMedal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRocket = widget.series == MedalSeries.rocket;
    final asset = LevelMedal.assetPath(widget.series, widget.level);
    final semanticLabel = '${isRocket ? 'Rocket' : 'VIP'} medal level ${widget.level}';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.animated ? _controller.value : .5;
        final pulse = .97 + (.035 * t);
        final rotation = isRocket ? math.sin(t * math.pi * 2) * .035 : 0.0;
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isRocket
                        ? const Color(0xFF69C9FF)
                        : const Color(0xFFB49AFF))
                    .withValues(alpha: .12 + (.13 * t)),
                blurRadius: 7 + (8 * t),
                spreadRadius: 1 + (2 * t),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: widget.animated ? pulse : 1,
              child: SvgPicture.asset(
                asset,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                semanticsLabel: semanticLabel,
              ),
            ),
          ),
        );
      },
    );
  }
}
