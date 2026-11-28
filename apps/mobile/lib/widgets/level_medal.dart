import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../vip/vip_visual_assets.dart';

enum MedalSeries {
  vip,
  rocket,
  wealth,
  fanclub,
  achievement,
  family,
  charm,
  noble,
  room,
  event,
}

/// Reusable, lightweight animated badge for DarkVibeX medal tiers.
/// VIP tiers 1-4 use the premium shield medal PNGs on R2
/// (vip-medals/, VIP1-4), with the bundled VIP SVG as the fallback
/// (VIP5-18 have no R2 medal PNG yet, and offline/load errors fall
/// back to the SVG too). Rocket tiers use the premium medal PNGs on
/// R2 (rocket-medals/, Rocket 1-18), with the bundled rocket_01-12.svg
/// assets only as an offline fallback. The new medal series (Wealth /
/// Fan Club / Achievement / Family / Charm / Noble / Room / Event)
/// also load their PNGs directly from R2 (medals/), falling back to a
/// themed icon — never a black box.
class LevelMedal extends StatefulWidget {
  const LevelMedal({
    super.key,
    required this.series,
    required this.level,
    this.size = 84,
    this.animated = true,
    this.achievement,
  });

  final MedalSeries series;
  final int level;
  final double size;
  final bool animated;

  /// Achievement slug for the achievement series (active/wealth/live/
  /// livestar/topgifter/fanpower). Ignored for other series.
  final String? achievement;

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
    final isVip = widget.series == MedalSeries.vip;
    final isR2Medal = !isVip && !isRocket;
    final semanticLabel = '${_seriesLabel(widget.series)} medal level ${widget.level}';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.animated ? _controller.value : .5;
        final pulse = .97 + (.035 * t);
        final rotation =
            (isRocket || isR2Medal) ? math.sin(t * math.pi * 2) * .035 : 0.0;
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _glowColor(widget.series)
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
              child: isVip
                  ? _vipMedalImage(semanticLabel)
                  : isRocket
                      ? _rocketMedalImage(semanticLabel)
                      : _medalTypeImage(semanticLabel),
            ),
          ),
        );
      },
    );
  }

  static String _seriesLabel(MedalSeries series) => switch (series) {
        MedalSeries.vip => 'VIP',
        MedalSeries.rocket => 'Rocket',
        MedalSeries.wealth => 'Wealth',
        MedalSeries.fanclub => 'Fan Club',
        MedalSeries.achievement => 'Achievement',
        MedalSeries.family => 'Family',
        MedalSeries.charm => 'Charm',
        MedalSeries.noble => 'Noble',
        MedalSeries.room => 'Room',
        MedalSeries.event => 'Event',
      };

  static Color _glowColor(MedalSeries series) => switch (series) {
        MedalSeries.vip => const Color(0xFFB49AFF),
        MedalSeries.rocket => const Color(0xFF69C9FF),
        MedalSeries.wealth => const Color(0xFFFFD34D),
        MedalSeries.fanclub => const Color(0xFFFF7EB6),
        MedalSeries.achievement => const Color(0xFFFFC94D),
        MedalSeries.family => const Color(0xFF7EA8FF),
        MedalSeries.charm => const Color(0xFFFF9ECF),
        MedalSeries.noble => const Color(0xFFB678FF),
        MedalSeries.room => const Color(0xFFFFD34D),
        MedalSeries.event => const Color(0xFF7CFFB2),
      };

  static IconData _fallbackIcon(MedalSeries series) => switch (series) {
        MedalSeries.vip => Icons.workspace_premium_rounded,
        MedalSeries.rocket => Icons.rocket_launch_rounded,
        MedalSeries.wealth => Icons.diamond_rounded,
        MedalSeries.fanclub => Icons.favorite_rounded,
        MedalSeries.achievement => Icons.emoji_events_rounded,
        MedalSeries.family => Icons.shield_rounded,
        MedalSeries.charm => Icons.mic_rounded,
        MedalSeries.noble => Icons.military_tech_rounded,
        MedalSeries.room => Icons.home_rounded,
        MedalSeries.event => Icons.celebration_rounded,
      };

  /// VIP shield medal PNG from R2 (vip-medals/, VIP1-4 only). Falls
  /// back to the bundled VIP SVG for VIP5-18 (no R2 medal PNG yet)
  /// and when the network image fails. Never a black box.
  Widget _vipMedalImage(String semanticLabel) {
    final int level = widget.level.clamp(1, 18).toInt();
    final String? url = vipMedalUrlForVipLevel(level);
    if (url == null) {
      return _bundledVipSvg(semanticLabel);
    }
    return Image.network(
      url,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => _bundledVipSvg(semanticLabel),
    );
  }

  Widget _bundledVipSvg(String semanticLabel) {
    return SvgPicture.asset(
      LevelMedal.assetPath(MedalSeries.vip, widget.level),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
    );
  }

  /// Rocket medal PNG from R2. Falls back to the bundled rocket SVG for
  /// levels 1-12 when the network image fails; levels 13-18 have no
  /// bundled SVG, so they fall back to a rocket icon. Never a black box.
  Widget _rocketMedalImage(String semanticLabel) {
    final int level = widget.level.clamp(1, 18).toInt();
    return Image.network(
      rocketMedalUrlForLevel(level),
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) {
        if (level <= 12) {
          return SvgPicture.asset(
            LevelMedal.assetPath(MedalSeries.rocket, level),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            semanticsLabel: semanticLabel,
          );
        }
        return Icon(
          Icons.rocket_launch_rounded,
          size: widget.size * .7,
          color: const Color(0xFF78D9FF),
          semanticLabel: semanticLabel,
        );
      },
    );
  }

  /// New-series medal PNG from R2 (medals/). Falls back to a themed
  /// icon when the network image fails. Never a black box.
  Widget _medalTypeImage(String semanticLabel) {
    final String type = widget.series.name;
    final String? url = medalTypeUrlForLevel(
      type,
      widget.level,
      widget.achievement,
    );
    if (url == null) {
      return Icon(
        _fallbackIcon(widget.series),
        size: widget.size * .7,
        color: _glowColor(widget.series),
        semanticLabel: semanticLabel,
      );
    }
    return Image.network(
      url,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => Icon(
        _fallbackIcon(widget.series),
        size: widget.size * .7,
        color: _glowColor(widget.series),
        semanticLabel: semanticLabel,
      ),
    );
  }
}

/// One medal chip for the room profile card: the earned medal shown
/// WITH the user's name (tooltip). Rocket medals (earned by Top 1/2/3
/// on a rocket launch, /api/medals carries series "rocket" + level)
/// render the real R2 medal image; every other medal keeps the
/// generic premium icon, exactly as the profile card showed before.
class ProfileMedalChip extends StatelessWidget {
  const ProfileMedalChip({super.key, required this.medal, this.size = 40});

  /// One medal object from /api/medals: { id, name, color, series?,
  /// level? }.
  final Map<String, dynamic> medal;

  /// Diameter of the chip (the profile card row is 42 high).
  final double size;

  @override
  Widget build(BuildContext context) {
    final String name = medal['name']?.toString() ?? 'Medal';
    final int? level = int.tryParse(medal['level']?.toString() ?? '');
    final bool isRocket = medal['series']?.toString() == 'rocket' &&
        level != null &&
        level >= 1 &&
        level <= 18;
    return Tooltip(
      message: name,
      child: isRocket
          ? LevelMedal(
              series: MedalSeries.rocket,
              level: level,
              size: size,
              animated: false,
            )
          : CircleAvatar(
              radius: size / 2,
              backgroundColor: const Color(0xFF2D2341),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: const Color(0xFF8B7CFF),
                size: size * .625,
              ),
            ),
    );
  }
}
