import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum MedalSeries { vip, rocket }

/// Reusable animated badge for DarkVibeX VIP and Rocket tiers.
/// Every level maps to its own transparent, scalable SVG asset.
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
    final rocketLevel = widget.level.clamp(1, 12).toInt();
    final asset = LevelMedal.assetPath(widget.series, widget.level);
    final semanticLabel =
        '${isRocket ? 'Rocket' : 'VIP'} medal level ${widget.level}';
    final primaryAura =
        isRocket ? _rocketAura(rocketLevel) : const Color(0xFFB49AFF);
    final secondaryAura = _secondaryRocketAura(rocketLevel);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.animated ? _controller.value : .5;
        final pulse = isRocket
            ? .97 + ((.035 + (rocketLevel / 12 * .02)) * t)
            : .97 + (.035 * t);
        final tilt = isRocket
            ? math.sin(t * math.pi * 2) * (.022 + (rocketLevel / 12 * .028))
            : 0.0;
        final shadows = <BoxShadow>[
          BoxShadow(
            color: primaryAura.withValues(alpha: .13 + (.15 * t)),
            blurRadius: 7 + (8 * t) + (isRocket ? rocketLevel * .35 : 0),
            spreadRadius: 1 + (2 * t) + (isRocket && rocketLevel >= 10 ? 1 : 0),
          ),
          if (isRocket && rocketLevel >= 5)
            BoxShadow(
              color: secondaryAura.withValues(
                alpha: rocketLevel >= 10 ? .23 + (.08 * t) : .12 + (.05 * t),
              ),
              blurRadius: rocketLevel >= 10 ? 14 + (5 * t) : 8 + (4 * t),
              spreadRadius: rocketLevel >= 10 ? 1.5 : .5,
            ),
          if (isRocket && rocketLevel >= 11)
            BoxShadow(
              color: const Color(0xFFFFD778).withValues(alpha: .18 + (.08 * t)),
              blurRadius: 16 + (5 * t),
              spreadRadius: 1,
            ),
        ];

        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: shadows,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Later rocket tiers earn orbit bands and a richer multi-colour aura.
              if (isRocket && rocketLevel >= 9)
                Transform.rotate(
                  angle: widget.animated ? (t * math.pi * 2 * .18) : 0,
                  child: Container(
                    width: widget.size * .96,
                    height: widget.size * .44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.size),
                      border: Border.all(
                        color: primaryAura.withValues(alpha: .74),
                        width: rocketLevel >= 11 ? 1.5 : 1,
                      ),
                    ),
                  ),
                ),
              if (isRocket && rocketLevel >= 11)
                Transform.rotate(
                  angle: widget.animated ? -(t * math.pi * 2 * .15) : -.15,
                  child: Container(
                    width: widget.size * .68,
                    height: widget.size * .92,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.size),
                      border: Border.all(
                        color: secondaryAura.withValues(alpha: .7),
                        width: rocketLevel == 12 ? 1.6 : 1.2,
                      ),
                    ),
                  ),
                ),
              Transform.rotate(
                angle: tilt,
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
            ],
          ),
        );
      },
    );
  }
}

Color _rocketAura(int level) => switch (level) {
      1 => const Color(0xFF69D7FF),
      2 => const Color(0xFF69FFD6),
      3 => const Color(0xFFB98BFF),
      4 => const Color(0xFFFFC365),
      5 => const Color(0xFFFF82E2),
      6 => const Color(0xFFFFD66E),
      7 => const Color(0xFF65BFFF),
      8 => const Color(0xFFFF83C7),
      9 => const Color(0xFF9385FF),
      10 => const Color(0xFFFF654D),
      11 => const Color(0xFF8CEBFF),
      _ => const Color(0xFFFFD778),
    };

Color _secondaryRocketAura(int level) => switch (level) {
      1 => const Color(0xFFB9F7FF),
      2 => const Color(0xFFB4FFE7),
      3 => const Color(0xFFE1B9FF),
      4 => const Color(0xFFFFF0A4),
      5 => const Color(0xFFFFB3EF),
      6 => const Color(0xFFFFF0B2),
      7 => const Color(0xFFB2E4FF),
      8 => const Color(0xFFFFC3E7),
      9 => const Color(0xFFB8F9FF),
      10 => const Color(0xFFFFB477),
      11 => const Color(0xFFFF9FEA),
      _ => const Color(0xFF8CFCFF),
    };
