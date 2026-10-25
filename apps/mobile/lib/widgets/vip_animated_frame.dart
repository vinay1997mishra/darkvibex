import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'frame_artwork_data.dart';

const Map<String, String> _rocketFrameStyleAliases = <String, String>{
  'rocket_frame_aurora': 'frame_blue_magic_butterfly',
  'rocket_frame_neon_wings': 'frame_neon_butterfly',
  'rocket_frame_golden_comet': 'frame_golden_butterfly_queen',
  'rocket_frame_purple_nova': 'frame_purple_dream_butterfly',
};

String? _visualFrameStyleId(String? styleId) =>
    _rocketFrameStyleAliases[styleId] ?? styleId;

final Map<String, MemoryImage> _frameArtworkCache = <String, MemoryImage>{};

MemoryImage? _frameArtwork(String? styleId) {
  final visualStyleId = _visualFrameStyleId(styleId);
  if (visualStyleId == null || visualStyleId.isEmpty) return null;
  final encoded = kFrameArtworkBase64[visualStyleId];
  if (encoded == null || encoded.isEmpty) return null;
  return _frameArtworkCache.putIfAbsent(
    visualStyleId,
    () => MemoryImage(base64Decode(encoded)),
  );
}

const Set<String> _freeAnimatedFrameIds = <String>{
  'frame_golden_crown',
  'frame_pink_heart',
  'frame_blue_butterfly',
  'frame_red_rose',
  'frame_purple_star',
  'frame_golden_flower',
  'frame_pink_blossom',
  'frame_blue_angel_crown',
  'frame_red_black_royal_wings',
  'frame_purple_butterfly',
  'frame_royal_love',
  'frame_green_nature',
  'frame_blue_magic_butterfly',
  'frame_golden_butterfly_queen',
  'frame_purple_dream_butterfly',
  'frame_neon_butterfly',
  'frame_crystal_aurora',
  'frame_neon_comet',
  'frame_rose_galaxy',
  'frame_solar_empress',
  'frame_emerald_dragon',
};

const Set<String> _premiumVectorFrameIds = <String>{
  'frame_crystal_aurora',
  'frame_neon_comet',
  'frame_rose_galaxy',
  'frame_solar_empress',
  'frame_emerald_dragon',
};

const Set<String> _premiumButterflyFrameIds = <String>{
  'frame_blue_magic_butterfly',
  'frame_golden_butterfly_queen',
  'frame_purple_dream_butterfly',
  'frame_neon_butterfly',
};

/// Ornate, animated frame used on room seats and profile avatars.
class VipAnimatedFrame extends StatefulWidget {
  const VipAnimatedFrame({
    super.key,
    required this.size,
    required this.child,
    this.enabled = true,
    this.level = 7,
    this.styleId,
  });

  final double size;
  final Widget child;
  final bool enabled;
  final int level;
  final String? styleId;

  @override
  State<VipAnimatedFrame> createState() => _VipAnimatedFrameState();
}

class _VipAnimatedFrameState extends State<VipAnimatedFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _durationFor(String? styleId) => Duration(
        milliseconds: (_freeAnimatedFrameIds.contains(styleId) ||
                _rocketFrameStyleAliases.containsKey(styleId))
            ? 2000
            : 3200,
      );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.styleId),
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant VipAnimatedFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.styleId != widget.styleId) {
      _controller.duration = _durationFor(widget.styleId);
      if (widget.enabled) {
        _controller
          ..reset()
          ..repeat();
      }
    }
    if (widget.enabled && !oldWidget.enabled) _controller.repeat();
    if (!widget.enabled && oldWidget.enabled) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualStyleId = _visualFrameStyleId(widget.styleId);
    final artwork = widget.enabled ? _frameArtwork(widget.styleId) : null;

    if (widget.enabled && _premiumVectorFrameIds.contains(widget.styleId)) {
      // These five shop frames use native vector artwork so every ornament can
      // animate smoothly without rotating or shrinking the user's avatar.
      return SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            SizedBox.square(dimension: widget.size, child: widget.child),
            IgnorePointer(
              child: Transform.scale(
                scale: 1.42,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => CustomPaint(
                      painter: _PremiumVectorFramePainter(
                        styleId: widget.styleId!,
                        phase: _controller.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.enabled &&
        _premiumButterflyFrameIds.contains(visualStyleId)) {
      // The avatar itself stays at its original size. All ornamental artwork is
      // drawn in a separate layer outside the avatar circle.
      return SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            SizedBox.square(
              dimension: widget.size,
              child: widget.child,
            ),
            IgnorePointer(
              child: Transform.scale(
                scale: 1.42,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: CustomPaint(
                    painter: _ButterflyFrameBasePainter(visualStyleId),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Transform.scale(
                scale: 1.42,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => CustomPaint(
                      painter: _ButterflyFlightPainter(
                        styleId: visualStyleId,
                        phase: _controller.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (artwork != null) {
      // The DP stays full-size beneath the transparent artwork overlay.
      // Only the ornaments animate; the photo and frame body do not move.
      const frameScale = 1.86;

      return SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            SizedBox.square(
              dimension: widget.size,
              child: widget.child,
            ),
            IgnorePointer(
              child: Transform.scale(
                scale: frameScale,
                alignment: Alignment.center,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: ColorFiltered(
                    // Key the opaque near-black matte out of older frame art.
                    // Transparent pixels remain transparent; dark backing pixels
                    // fade away so the galaxy background shows through around DP.
                    colorFilter: const ColorFilter.matrix(<double>[
                      1, 0, 0, 0, 0,
                      0, 1, 0, 0, 0,
                      0, 0, 1, 0, 0,
                      1, 1, 1, 1, -255,
                    ]),
                    child: Image(
                      image: artwork,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Transform.scale(
                scale: frameScale,
                alignment: Alignment.center,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => CustomPaint(
                      painter: _FrameElementPainter(
                        styleId: visualStyleId,
                        phase: _controller.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Preserve the avatar's full diameter (0% shrink). Draw the animated
    // ring in a separate enlarged layer so decoration stays outside the DP.
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          SizedBox.square(dimension: widget.size, child: widget.child),
          if (widget.enabled)
            IgnorePointer(
              child: Transform.scale(
                scale: 1.42,
                child: SizedBox.square(
                  dimension: widget.size,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => CustomPaint(
                      painter: _VipRingPainter(
                        _controller.value,
                        widget.level,
                        visualStyleId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _PremiumVectorPalette {
  const _PremiumVectorPalette({
    required this.light,
    required this.accent,
    required this.deep,
  });

  final Color light;
  final Color accent;
  final Color deep;

  static _PremiumVectorPalette forStyle(String styleId) => switch (styleId) {
        'frame_crystal_aurora' => const _PremiumVectorPalette(
            light: Color(0xFFE3FDFF),
            accent: Color(0xFF5AD7FF),
            deep: Color(0xFF5645F5),
          ),
        'frame_neon_comet' => const _PremiumVectorPalette(
            light: Color(0xFFD7FFFF),
            accent: Color(0xFF00E9FF),
            deep: Color(0xFF1263FF),
          ),
        'frame_rose_galaxy' => const _PremiumVectorPalette(
            light: Color(0xFFFFE0F5),
            accent: Color(0xFFFF54C8),
            deep: Color(0xFF8A35EF),
          ),
        'frame_solar_empress' => const _PremiumVectorPalette(
            light: Color(0xFFFFF7C3),
            accent: Color(0xFFFFC247),
            deep: Color(0xFFE56A11),
          ),
        'frame_emerald_dragon' => const _PremiumVectorPalette(
            light: Color(0xFFD8FFE8),
            accent: Color(0xFF36F39B),
            deep: Color(0xFF087B59),
          ),
        _ => const _PremiumVectorPalette(
            light: Color(0xFFC7F8FF),
            accent: Color(0xFF36B6FF),
            deep: Color(0xFF344CEB),
          ),
      };
}

/// Premium circular vector frames with distinct, seamless 2-second motifs.
class _PremiumVectorFramePainter extends CustomPainter {
  const _PremiumVectorFramePainter({
    required this.styleId,
    required this.phase,
  });

  final String styleId;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final palette = _PremiumVectorPalette.forStyle(styleId);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side * .385;
    final cycle = phase * math.pi * 2;
    final pulse = .88 + .12 * ((math.sin(cycle) + 1) / 2);
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .082
        ..color = palette.accent.withValues(alpha: .18 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .032
        ..shader = SweepGradient(
          startAngle: cycle,
          endAngle: cycle + math.pi * 2,
          colors: <Color>[
            palette.light,
            palette.accent,
            palette.deep,
            palette.light,
          ],
        ).createShader(ringRect),
    );
    canvas.drawCircle(
      center,
      radius - side * .024,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .006
        ..color = palette.light.withValues(alpha: .88),
    );

    // Short glowing arc segments orbit the circular rim; no hard line sweeps
    // across the avatar itself.
    final orbitRect = Rect.fromCircle(center: center, radius: radius * 1.095);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        orbitRect,
        cycle + i * math.pi / 2,
        math.pi * .16,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = side * .016
          ..color = palette.light.withValues(alpha: .38 + .35 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
    }

    switch (styleId) {
      case 'frame_crystal_aurora':
        _paintAuroraCrystals(canvas, center, radius, side, cycle, palette);
        break;
      case 'frame_neon_comet':
        _paintComets(canvas, center, radius, side, cycle, palette);
        break;
      case 'frame_rose_galaxy':
        _paintRoseOrbit(canvas, center, radius, side, cycle, palette);
        break;
      case 'frame_solar_empress':
        _paintSolarCrown(canvas, center, radius, side, cycle, palette);
        break;
      case 'frame_emerald_dragon':
        _paintDragonWings(canvas, center, radius, side, cycle, palette);
        break;
    }

    _paintOrbitingSparkles(canvas, center, radius, side, cycle, palette);
  }

  void _paintAuroraCrystals(
    Canvas canvas,
    Offset center,
    double radius,
    double side,
    double cycle,
    _PremiumVectorPalette palette,
  ) {
    for (var i = 0; i < 8; i++) {
      final angle = cycle * .12 + i * math.pi / 4;
      final point = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 1.105);
      _drawDiamond(canvas, point, side * .030, palette.light, palette.accent);
    }
    _drawDiamond(
      canvas,
      center + Offset(0, -radius * 1.015),
      side * .071,
      palette.light,
      palette.accent,
    );
    _drawDiamond(
      canvas,
      center + Offset(0, radius * 1.015),
      side * .058,
      palette.light,
      palette.deep,
    );
  }

  void _paintComets(
    Canvas canvas,
    Offset center,
    double radius,
    double side,
    double cycle,
    _PremiumVectorPalette palette,
  ) {
    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + cycle + i * math.pi * 2 / 3;
      for (var trail = 4; trail >= 1; trail--) {
        final trailAngle = angle - trail * .075;
        final point = center +
            Offset(math.cos(trailAngle), math.sin(trailAngle)) *
                (radius * 1.12);
        final alpha = .12 + .12 * (5 - trail);
        canvas.drawCircle(
          point,
          side * (.008 + .0018 * (5 - trail)),
          Paint()
            ..color = palette.accent.withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
      }
      final head = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 1.12);
      canvas.drawCircle(
        head,
        side * .027,
        Paint()
          ..color = palette.accent.withValues(alpha: .26)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        head,
        side * .012,
        Paint()..color = Colors.white.withValues(alpha: .96),
      );
    }
  }

  void _paintRoseOrbit(
    Canvas canvas,
    Offset center,
    double radius,
    double side,
    double cycle,
    _PremiumVectorPalette palette,
  ) {
    for (var i = 0; i < 6; i++) {
      final angle = cycle * .16 + i * math.pi / 3;
      final point = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 1.075);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + math.pi / 2);
      final petal = Rect.fromCenter(
        center: Offset.zero,
        width: side * .034,
        height: side * .069,
      );
      canvas.drawOval(
        petal,
        Paint()
          ..color = palette.accent.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawOval(
        petal,
        Paint()..color = palette.accent.withValues(alpha: .78),
      );
      canvas.drawOval(
        petal,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * .004
          ..color = palette.light,
      );
      canvas.restore();
    }
    final bloom = center + Offset(0, -radius * 1.02);
    canvas.drawCircle(
      bloom,
      side * (.026 + .005 * math.sin(cycle).abs()),
      Paint()
        ..color = palette.accent.withValues(alpha: .28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      bloom,
      side * .011,
      Paint()..color = palette.light.withValues(alpha: .96),
    );
  }

  void _paintSolarCrown(
    Canvas canvas,
    Offset center,
    double radius,
    double side,
    double cycle,
    _PremiumVectorPalette palette,
  ) {
    final crownCenter = center + Offset(0, -radius * .935);
    final crown = Path()
      ..moveTo(crownCenter.dx - side * .125, crownCenter.dy + side * .035)
      ..lineTo(crownCenter.dx - side * .105, crownCenter.dy - side * .035)
      ..lineTo(crownCenter.dx - side * .045, crownCenter.dy + side * .005)
      ..lineTo(crownCenter.dx - side * .018, crownCenter.dy - side * .082)
      ..lineTo(crownCenter.dx + side * .025, crownCenter.dy + side * .002)
      ..lineTo(crownCenter.dx + side * .077, crownCenter.dy - side * .040)
      ..lineTo(crownCenter.dx + side * .112, crownCenter.dy + side * .035)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.light, palette.accent, palette.deep],
        ).createShader(crown.getBounds()),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .006
        ..color = palette.light.withValues(alpha: .92),
    );
    for (var i = 0; i < 5; i++) {
      final x = crownCenter.dx + side * (-.09 + i * .045);
      final y = crownCenter.dy + side * (.012 + math.sin(cycle + i) * .006);
      canvas.drawCircle(
        Offset(x, y),
        side * .009,
        Paint()
          ..color = palette.light.withValues(alpha: .4 + .5 * ((math.sin(cycle + i) + 1) / 2)),
      );
    }
  }

  void _paintDragonWings(
    Canvas canvas,
    Offset center,
    double radius,
    double side,
    double cycle,
    _PremiumVectorPalette palette,
  ) {
    void wing(bool left) {
      final anchor = center +
          Offset(left ? -radius * .63 : radius * .63, -radius * .43);
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(left ? -1.0 : 1.0, 1);
      final flap = .90 + .10 * math.sin(cycle * 2);
      canvas.scale(flap, 1);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(side * .045, -side * .080, side * .115, -side * .105, side * .155, -side * .045)
        ..cubicTo(side * .125, -side * .020, side * .115, side * .025, side * .070, side * .030)
        ..cubicTo(side * .045, side * .028, side * .018, side * .012, 0, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = palette.accent.withValues(alpha: .68),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * .006
          ..color = palette.light.withValues(alpha: .92),
      );
      for (var i = 1; i <= 3; i++) {
        canvas.drawCircle(
          Offset(side * (.035 * i), -side * (.015 + .014 * i)),
          side * .0045,
          Paint()..color = palette.light.withValues(alpha: .9),
        );
      }
      canvas.restore();
    }

    wing(true);
    wing(false);
    for (var i = 0; i < 4; i++) {
      final angle = -math.pi / 2 + cycle * .6 + i * math.pi / 2;
      final point = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 1.08);
      canvas.drawCircle(
        point,
        side * .021,
        Paint()
          ..color = palette.accent.withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        point,
        side * .009,
        Paint()..color = palette.light.withValues(alpha: .96),
      );
    }
  }

  void _paintOrbitingSparkles(
    Canvas canvas,
    Offset center,
    double radius,
    double side,
    double cycle,
    _PremiumVectorPalette palette,
  ) {
    for (var i = 0; i < 8; i++) {
      final angle = cycle * .20 + i * math.pi / 4;
      final point = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 1.13);
      final twinkle = .20 + .60 * ((math.sin(cycle * 2 + i) + 1) / 2);
      _drawDiamond(
        canvas,
        point,
        side * (.008 + .004 * twinkle),
        palette.light.withValues(alpha: twinkle),
        palette.accent.withValues(alpha: twinkle),
      );
    }
  }

  void _drawDiamond(
    Canvas canvas,
    Offset center,
    double length,
    Color fill,
    Color edge,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - length)
      ..lineTo(center.dx + length * .62, center.dy)
      ..lineTo(center.dx, center.dy + length)
      ..lineTo(center.dx - length * .62, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = length * .14
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumVectorFramePainter oldDelegate) =>
      oldDelegate.styleId != styleId || oldDelegate.phase != phase;
}

class _FrameElementPainter extends CustomPainter {
  const _FrameElementPainter({
    required this.styleId,
    required this.phase,
  });

  final String? styleId;
  final double phase;

  bool get _butterfly =>
      styleId == 'frame_blue_butterfly' ||
      styleId == 'frame_purple_butterfly' ||
      styleId == 'frame_neon_butterfly';

  bool get _crown =>
      styleId == 'frame_golden_crown' ||
      styleId == 'frame_blue_angel_crown';

  bool get _heart =>
      styleId == 'frame_pink_heart' ||
      styleId == 'frame_royal_love';

  bool get _royalWings => styleId == 'frame_red_black_royal_wings';
  bool get _rose => styleId == 'frame_red_rose';
  bool get _star => styleId == 'frame_purple_star';
  bool get _flower => styleId == 'frame_golden_flower' || styleId == 'frame_pink_blossom';
  bool get _nature => styleId == 'frame_green_nature';

  Color get _accent => switch (styleId) {
        'frame_blue_butterfly' => const Color(0xFF8CEBFF),
        'frame_purple_butterfly' => const Color(0xFFD8A7FF),
        'frame_red_rose' => const Color(0xFFFF8EC9),
        'frame_golden_crown' => const Color(0xFFFFE36A),
        'frame_blue_angel_crown' => const Color(0xFFAAD9FF),
        'frame_pink_heart' => const Color(0xFFFF8EC7),
        'frame_royal_love' => const Color(0xFFFF6C8E),
        'frame_red_black_royal_wings' => const Color(0xFFFF7A55),
        'frame_purple_star' => const Color(0xFFD6A8FF),
        'frame_golden_flower' => const Color(0xFFFFC84A),
        'frame_pink_blossom' => const Color(0xFFFFB6DA),
        'frame_green_nature' => const Color(0xFF8DFFB0),
        'frame_neon_butterfly' => const Color(0xFF56F0FF),
        _ => const Color(0xFFFFD86B),
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (styleId == null || styleId!.isEmpty) return;
    if (_butterfly) {
      _paintButterfly(canvas, size);
      _paintSparkles(canvas, size, count: 5);
      return;
    }
    if (_crown) {
      _paintCrownShine(canvas, size);
      _paintSparkles(canvas, size, count: 4);
      return;
    }
    if (_heart) {
      _paintHeartPulse(canvas, size);
      _paintSparkles(canvas, size, count: 4);
      return;
    }
    if (_royalWings) {
      _paintWingShimmer(canvas, size);
      _paintSparkles(canvas, size, count: 6);
      return;
    }
    if (_rose) {
      _paintRoseBloom(canvas, size);
      _paintSparkles(canvas, size, count: 4);
      return;
    }
    if (_star) {
      _paintStarPulse(canvas, size);
      _paintSparkles(canvas, size, count: 6);
      return;
    }
    if (_flower) {
      _paintFlowerOrbit(canvas, size);
      _paintSparkles(canvas, size, count: 5);
      return;
    }
    if (_nature) {
      _paintNatureGlow(canvas, size);
      _paintSparkles(canvas, size, count: 4);
      return;
    }
    _paintPetalGlow(canvas, size);
    _paintSparkles(canvas, size, count: 5);
  }

  void _paintButterfly(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final flap = .48 + .38 * (math.sin(t * 2).abs());
    final center = Offset(size.width * .50, size.height * .18);
    final wingPaint = Paint()
      ..color = _accent.withValues(alpha: .38)
      ..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .012;

    void wing(bool left) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      final direction = left ? -1.0 : 1.0;
      canvas.scale(direction, 1);
      canvas.rotate((1 - flap) * .42);
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(
          size.width * .045,
          -size.height * .10,
          size.width * .16,
          -size.height * .09,
          size.width * .17,
          size.height * .005,
        )
        ..cubicTo(
          size.width * .15,
          size.height * .10,
          size.width * .055,
          size.height * .115,
          0,
          size.height * .025,
        )
        ..close();
      canvas.drawPath(path, wingPaint);
      canvas.drawPath(path, edgePaint);
      canvas.restore();
    }

    wing(true);
    wing(false);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, size.height * .012),
        width: size.width * .028,
        height: size.height * .11,
      ),
      Paint()..color = _accent.withValues(alpha: .72),
    );
  }

  void _paintCrownShine(Canvas canvas, Size size) {
    // Crown jewels twinkle softly; do not sweep a hard line across the DP.
    final t = phase * math.pi * 2;
    for (var i = 0; i < 5; i++) {
      final bob = math.sin(t + i * 1.4);
      final point = Offset(size.width * (.20 + i * .15),
          size.height * (.095 + bob * .012));
      final radius = size.width * (.018 + .006 * ((bob + 1) / 2));
      canvas.drawCircle(point, radius * 2.4, Paint()
        ..color = _accent.withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      final jewel = Path()
        ..moveTo(point.dx, point.dy - radius * 1.6)
        ..lineTo(point.dx + radius, point.dy)
        ..lineTo(point.dx, point.dy + radius * 1.6)
        ..lineTo(point.dx - radius, point.dy)
        ..close();
      canvas.drawPath(jewel, Paint()
        ..color = Colors.white.withValues(alpha: .4 + .4 * ((bob + 1) / 2)));
    }
  }

  void _paintHeartPulse(Canvas canvas, Size size) {
    final pulse = .86 + .16 * ((math.sin(phase * math.pi * 2) + 1) / 2);
    final center = Offset(size.width * .50, size.height * .16);
    final r = size.width * .055 * pulse;
    final path = Path()
      ..moveTo(center.dx, center.dy + r * .9)
      ..cubicTo(
        center.dx - r * 1.8,
        center.dy - r * .2,
        center.dx - r * .9,
        center.dy - r * 1.3,
        center.dx,
        center.dy - r * .45,
      )
      ..cubicTo(
        center.dx + r * .9,
        center.dy - r * 1.3,
        center.dx + r * 1.8,
        center.dy - r * .2,
        center.dx,
        center.dy + r * .9,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = _accent.withValues(alpha: .32),
    );
  }

  void _paintWingShimmer(Canvas canvas, Size size) {
    // Soft light beads drift along both wings; no straight moving lines.
    final t = phase * math.pi * 2;
    for (var i = 0; i < 4; i++) {
      final progress = (phase + i * .26) % 1.0;
      final drift = math.sin(t + i * 1.7) * .035;
      final y = .22 + .54 * progress;
      for (final point in <Offset>[
        Offset(size.width * (.18 + drift), size.height * y),
        Offset(size.width * (.82 - drift), size.height * (y - .035)),
      ]) {
        canvas.drawCircle(point, size.width * .060, Paint()
          ..color = _accent.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawCircle(point, size.width * .018,
          Paint()..color = Colors.white.withValues(alpha: .52));
      }
    }
  }

  void _paintRoseBloom(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final center = Offset(size.width * .50, size.height * .16);
    for (var i = 0; i < 7; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi * 2 / 7 + math.sin(t) * .08);
      final petal = Rect.fromCenter(center: Offset(0, -size.height * .026),
          width: size.width * .065, height: size.height * .080);
      canvas.drawOval(petal, Paint()..color = _accent.withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawOval(petal, Paint()..color = _accent.withValues(alpha: .64));
      canvas.restore();
    }
    canvas.drawCircle(center, size.width * (.016 + .004 * math.sin(t).abs()),
      Paint()..color = const Color(0xFFFFF1B5).withValues(alpha: .92));
  }

  void _paintStarPulse(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final center = Offset(size.width * .50, size.height * .16);
    for (var i = 0; i < 3; i++) {
      final angle = t * .3 + i * math.pi * 2 / 3;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * size.width * .075;
      final radius = size.width * (.022 + .008 * ((math.sin(t + i) + 1) / 2));
      final star = Path()
        ..moveTo(point.dx, point.dy - radius)
        ..lineTo(point.dx + radius * .35, point.dy - radius * .35)
        ..lineTo(point.dx + radius, point.dy)
        ..lineTo(point.dx + radius * .35, point.dy + radius * .35)
        ..lineTo(point.dx, point.dy + radius)
        ..lineTo(point.dx - radius * .35, point.dy + radius * .35)
        ..lineTo(point.dx - radius, point.dy)
        ..lineTo(point.dx - radius * .35, point.dy - radius * .35)
        ..close();
      canvas.drawCircle(point, radius * 2.4, Paint()
        ..color = _accent.withValues(alpha: .2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: .8));
    }
  }

  void _paintFlowerOrbit(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final center = Offset(size.width * .50, size.height * .16);
    final orbit = size.width * (.06 + .01 * math.sin(t));
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi * 2 / 6 + t * .12;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + math.pi / 2);
      final petal = Rect.fromCenter(center: Offset.zero,
          width: size.width * .024, height: size.height * .048);
      canvas.drawOval(petal, Paint()..color = _accent.withValues(alpha: .2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawOval(petal, Paint()..color = _accent.withValues(alpha: .7));
      canvas.restore();
    }
    canvas.drawCircle(center, size.width * .014,
      Paint()..color = Colors.white.withValues(alpha: .8));
  }

  void _paintNatureGlow(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final center = Offset(size.width * .50, size.height * .18);
    for (var i = 0; i < 4; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final point = center + Offset(side * size.width * (.045 + .012 * (i ~/ 2)),
          math.sin(t + i) * size.height * .018);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(side * (.42 + .1 * math.sin(t + i)));
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(size.width * side * .07, -size.height * .055,
            size.width * side * .105, 0)
        ..quadraticBezierTo(size.width * side * .045, size.height * .045, 0, 0)
        ..close();
      canvas.drawPath(leaf, Paint()..color = _accent.withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawPath(leaf, Paint()..color = _accent.withValues(alpha: .58));
      canvas.restore();
    }
    final dew = center + Offset(0, size.height * .045);
    canvas.drawCircle(dew, size.width * .026, Paint()
      ..color = const Color(0xFFD2FFE1).withValues(alpha: .36)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(dew, size.width * .010,
      Paint()..color = Colors.white.withValues(alpha: .82));
  }

  void _paintPetalGlow(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final center = Offset(size.width * .50, size.height * .17);
    for (var i = 0; i < 5; i++) {
      final a = t * .35 + i * math.pi * 2 / 5;
      final distance = size.width * (.07 + .01 * math.sin(t + i));
      final p = center + Offset(math.cos(a), math.sin(a)) * distance;
      canvas.drawCircle(p, size.width * (.012 + .004 * ((math.sin(t * 2 + i) + 1) / 2)),
        Paint()..color = _accent.withValues(alpha: .34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    }
  }

  void _paintSparkles(Canvas canvas, Size size, {required int count}) {
    final t = phase * math.pi * 2;
    for (var i = 0; i < count; i++) {
      final a = i * 2.399963 + phase * .7;
      final radius = size.width * (.34 + .06 * math.sin(t + i));
      final center = Offset(size.width / 2, size.height / 2);
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      final alpha = (.12 + .38 * ((math.sin(t * 2 + i) + 1) / 2)).clamp(.12, .50).toDouble();
      final r = size.width * (.010 + .006 * ((math.sin(t + i) + 1) / 2));
      canvas.drawCircle(p, r * 2.1, Paint()..color = _accent.withValues(alpha: alpha * .42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      final diamond = Path()
        ..moveTo(p.dx, p.dy - r * 1.6)
        ..lineTo(p.dx + r * .65, p.dy)
        ..lineTo(p.dx, p.dy + r * 1.6)
        ..lineTo(p.dx - r * .65, p.dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = _accent.withValues(alpha: alpha));
      canvas.drawCircle(p, r * .30,
        Paint()..color = Colors.white.withValues(alpha: alpha * .85));
    }
  }

  @override
  bool shouldRepaint(covariant _FrameElementPainter oldDelegate) =>
      oldDelegate.styleId != styleId || oldDelegate.phase != phase;
}

class _ButterflyPalette {
  const _ButterflyPalette({
    required this.light,
    required this.accent,
    required this.deep,
  });

  final Color light;
  final Color accent;
  final Color deep;

  static _ButterflyPalette forStyle(String? styleId) => switch (styleId) {
        'frame_golden_butterfly_queen' => const _ButterflyPalette(
            light: Color(0xFFFFF5BB),
            accent: Color(0xFFFFB52E),
            deep: Color(0xFF9B4C05),
          ),
        'frame_purple_dream_butterfly' => const _ButterflyPalette(
            light: Color(0xFFF8D6FF),
            accent: Color(0xFFC15AFF),
            deep: Color(0xFF5A22C0),
          ),
        _ => const _ButterflyPalette(
            light: Color(0xFFC7F8FF),
            accent: Color(0xFF36B6FF),
            deep: Color(0xFF344CEB),
          ),
      };
}

/// Static jewelry and ring work: separated from the animated motif so the
/// frame body never rotates or shakes while the butterfly wings are moving.
class _ButterflyFrameBasePainter extends CustomPainter {
  const _ButterflyFrameBasePainter(this.styleId);

  final String? styleId;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _ButterflyPalette.forStyle(styleId);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .385;
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .055
        ..color = palette.accent.withValues(alpha: .24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .030
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.light, palette.accent, palette.deep, palette.light],
        ).createShader(ringRect),
    );
    canvas.drawCircle(
      center,
      radius - size.shortestSide * .025,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .007
        ..color = palette.light.withValues(alpha: .88),
    );

    final flourish = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .012
      ..strokeCap = StrokeCap.round
      ..color = palette.accent.withValues(alpha: .9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.10),
      math.pi * 1.05,
      math.pi * .31,
      false,
      flourish,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.10),
      -math.pi * .26,
      math.pi * .31,
      false,
      flourish,
    );

    _drawDiamond(
      canvas,
      Offset(center.dx, center.dy - radius),
      size.shortestSide * .072,
      palette,
    );
    _drawDiamond(
      canvas,
      Offset(center.dx, center.dy + radius),
      size.shortestSide * .072,
      palette,
    );

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final point = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius * 1.045);
      canvas.drawCircle(
        point,
        size.shortestSide * .012,
        Paint()..color = palette.light.withValues(alpha: .88),
      );
    }
  }

  void _drawDiamond(
    Canvas canvas,
    Offset center,
    double length,
    _ButterflyPalette palette,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - length)
      ..lineTo(center.dx + length * .58, center.dy)
      ..lineTo(center.dx, center.dy + length)
      ..lineTo(center.dx - length * .58, center.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[palette.light, palette.accent, palette.deep],
        ).createShader(
          Rect.fromCenter(center: center, width: length * 1.2, height: length * 2),
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = length * .08
        ..color = Colors.white.withValues(alpha: .8),
    );
  }

  @override
  bool shouldRepaint(covariant _ButterflyFrameBasePainter oldDelegate) =>
      oldDelegate.styleId != styleId;
}

/// Only the butterfly wings, the orbiting small butterfly and sparkles animate.
class _ButterflyFlightPainter extends CustomPainter {
  const _ButterflyFlightPainter({
    required this.styleId,
    required this.phase,
  });

  final String? styleId;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _ButterflyPalette.forStyle(styleId);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .385;
    final cycle = phase * math.pi * 2;

    // Large butterfly rests on the upper-left edge; its wings flap twice
    // during the two-second cycle while its body remains close to stationary.
    final mainAnchor = center +
        Offset(
          math.cos(-2.28) * radius * 1.055,
          math.sin(-2.28) * radius * 1.055 +
              math.sin(cycle) * size.shortestSide * .006,
        );
    final flap = .22 + .78 * ((math.sin(cycle * 2) + 1) / 2);
    _drawButterfly(canvas, mainAnchor, size.shortestSide * .205, flap, palette);

    // A smaller butterfly flies a complete circular path around the frame.
    final flyAngle = -math.pi / 2 + cycle;
    final flyingAnchor = center +
        Offset(
          math.cos(flyAngle) * radius * 1.18,
          math.sin(flyAngle) * radius * 1.18,
        );
    final smallFlap = .28 + .72 * ((math.sin(cycle * 2 + .7) + 1) / 2);
    _drawButterfly(
      canvas,
      flyingAnchor,
      size.shortestSide * .075,
      smallFlap,
      palette,
    );

    // Blurred light beads orbit the ring instead of crossing hairline flashes.
    for (var i = 0; i < 6; i++) {
      final angle = cycle * .4 + i * math.pi / 3;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius * 1.13;
      final alpha = .20 + .48 * ((math.sin(cycle * 2 + i) + 1) / 2);
      final glowRadius = size.shortestSide * .018;
      canvas.drawCircle(point, glowRadius * 2.1, Paint()
        ..color = palette.light.withValues(alpha: alpha * .42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      final diamond = Path()
        ..moveTo(point.dx, point.dy - glowRadius)
        ..lineTo(point.dx + glowRadius * .58, point.dy)
        ..lineTo(point.dx, point.dy + glowRadius)
        ..lineTo(point.dx - glowRadius * .58, point.dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = palette.light.withValues(alpha: alpha));
    }
  }

  void _drawButterfly(
    Canvas canvas,
    Offset center,
    double size,
    double flap,
    _ButterflyPalette palette,
  ) {
    final wingFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomRight,
        colors: <Color>[
          palette.light.withValues(alpha: .96),
          palette.accent.withValues(alpha: .91),
          palette.deep.withValues(alpha: .90),
        ],
      ).createShader(
        Rect.fromCenter(
          center: center,
          width: size * 1.45,
          height: size * 1.2,
        ),
      );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * .035
      ..color = Colors.white.withValues(alpha: .72);

    final wingPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(size * .10, -size * .47, size * .63, -size * .42,
          size * .52, -size * .025)
      ..cubicTo(size * .46, size * .24, size * .15, size * .22, 0, size * .09)
      ..close();
    final lowerWingPath = Path()
      ..moveTo(0, size * .045)
      ..cubicTo(size * .18, size * .02, size * .40, size * .24,
          size * .20, size * .34)
      ..cubicTo(size * .08, size * .35, size * .02, size * .20, 0, size * .12)
      ..close();

    for (final direction in <double>[-1, 1]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(direction * (1 - flap) * .48);
      canvas.scale(direction * flap, 1);
      canvas.drawPath(wingPath, wingFill);
      canvas.drawPath(wingPath, outline);
      canvas.drawPath(lowerWingPath, wingFill);
      canvas.drawPath(lowerWingPath, outline);
      canvas.restore();
    }

    final body = Paint()..color = palette.deep;
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, size * .055),
        width: size * .075,
        height: size * .42,
      ),
      body,
    );
    final antenna = Paint()
      ..color = palette.light
      ..strokeWidth = size * .022
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final antennaPath = Path()
      ..moveTo(center.dx, center.dy - size * .12)
      ..quadraticBezierTo(
        center.dx - size * .10,
        center.dy - size * .25,
        center.dx - size * .16,
        center.dy - size * .22,
      )
      ..moveTo(center.dx, center.dy - size * .12)
      ..quadraticBezierTo(
        center.dx + size * .10,
        center.dy - size * .25,
        center.dx + size * .16,
        center.dy - size * .22,
      );
    canvas.drawPath(antennaPath, antenna);
  }

  @override
  bool shouldRepaint(covariant _ButterflyFlightPainter oldDelegate) =>
      oldDelegate.styleId != styleId || oldDelegate.phase != phase;
}

class _FrameTheme {
  const _FrameTheme(this.colors, this.motif);
  final List<Color> colors;
  final String motif;
}

_FrameTheme _themeFor(String? styleId, int level) => switch (styleId) {
      'frame_blue_magic_butterfly' => const _FrameTheme(
          <Color>[Color(0xFFB9F7FF), Color(0xFF27A8FF), Color(0xFF384FEA)],
          'butterfly',
        ),
      'frame_golden_butterfly_queen' => const _FrameTheme(
          <Color>[Color(0xFFFFF3B0), Color(0xFFFFB11B), Color(0xFFBA6509)],
          'butterfly',
        ),
      'frame_purple_dream_butterfly' => const _FrameTheme(
          <Color>[Color(0xFFF7C9FF), Color(0xFFB84DFF), Color(0xFF5520BD)],
          'butterfly',
        ),
      'frame_golden_crown' => const _FrameTheme(
          <Color>[Color(0xFFFFF3B0), Color(0xFFFFB11B), Color(0xFFE46A15)],
          'crown',
        ),
      'frame_pink_heart' => const _FrameTheme(
          <Color>[Color(0xFFFFB7F4), Color(0xFFFF4FA8), Color(0xFF8C48FF)],
          'heart',
        ),
      'frame_blue_butterfly' => const _FrameTheme(
          <Color>[Color(0xFFC8F6FF), Color(0xFF39A7FF), Color(0xFF456BFF)],
          'butterfly',
        ),
      'frame_red_rose' => const _FrameTheme(
          <Color>[Color(0xFFFFC4C4), Color(0xFFFF4E56), Color(0xFF9A1624)],
          'rose',
        ),
      'frame_purple_star' => const _FrameTheme(
          <Color>[Color(0xFFE4C7FF), Color(0xFF9B58FF), Color(0xFF5321B9)],
          'star',
        ),
      'frame_golden_flower' => const _FrameTheme(
          <Color>[Color(0xFFFFF0B4), Color(0xFFFFC34E), Color(0xFFC98118)],
          'flower',
        ),
      'frame_pink_blossom' => const _FrameTheme(
          <Color>[Color(0xFFFFD3E8), Color(0xFFFF7DB6), Color(0xFFFFB7D4)],
          'blossom',
        ),
      'frame_blue_angel_crown' => const _FrameTheme(
          <Color>[Color(0xFFE5FBFF), Color(0xFF72D8FF), Color(0xFF4588FF)],
          'angel',
        ),
      'frame_red_black_royal_wings' => const _FrameTheme(
          <Color>[Color(0xFFFFD36E), Color(0xFFFF3636), Color(0xFF4B1116)],
          'royal_wings',
        ),
      'frame_purple_butterfly' => const _FrameTheme(
          <Color>[Color(0xFFF0D5FF), Color(0xFFB956FF), Color(0xFF6131C6)],
          'butterfly',
        ),
      'frame_royal_love' => const _FrameTheme(
          <Color>[Color(0xFFFFE59A), Color(0xFFFF4B6A), Color(0xFFFF9D2E)],
          'royal_love',
        ),
      'frame_green_nature' => const _FrameTheme(
          <Color>[Color(0xFFFFD37A), Color(0xFFFF5B20), Color(0xFF9E1B18)],
          'royal_wings',
        ),
      'frame_neon_butterfly' => const _FrameTheme(
          <Color>[Color(0xFFB8FFFF), Color(0xFF38DFFF), Color(0xFF873BFF)],
          'butterfly',
        ),
      'frame_royal' => const _FrameTheme(
          <Color>[Color(0xFFFFE49B), Color(0xFFCC542E), Color(0xFFFFC95C)],
          'ring',
        ),
      'frame_sapphire' => const _FrameTheme(
          <Color>[Color(0xFFB8F4FF), Color(0xFF397BFF), Color(0xFF62D9FF)],
          'ring',
        ),
      'frame_phoenix' => const _FrameTheme(
          <Color>[Color(0xFFFFD37A), Color(0xFFE33F65), Color(0xFFFF8B40)],
          'ring',
        ),
      'frame_king' => const _FrameTheme(
          <Color>[Color(0xFFFFF0A6), Color(0xFFFF9F24), Color(0xFFDB62FF)],
          'ring',
        ),
      _ => level >= 18
          ? const _FrameTheme(
              <Color>[Color(0xFFFFF2B0), Color(0xFFFFA52E), Color(0xFFFFE59A)],
              'ring',
            )
          : level >= 12
              ? const _FrameTheme(
                  <Color>[Color(0xFFFFE8A3), Color(0xFFB87333), Color(0xFFFFD36A)],
                  'ring',
                )
              : const _FrameTheme(
                  <Color>[Color(0xFFB8A1FF), Color(0xFF55D9FF), Color(0xFFFFD36A)],
                  'ring',
                ),
    };

class _VipRingPainter extends CustomPainter {
  const _VipRingPainter(this.progress, this.level, this.styleId);
  final double progress;
  final int level;
  final String? styleId;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final theme = _themeFor(styleId, level);
    final colors = theme.colors;
    final phase = progress * math.pi * 2;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = colors.first.withValues(alpha: .22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center, radius - 1, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..shader = SweepGradient(
        transform: GradientRotation(phase),
        colors: <Color>[
          colors.first.withValues(alpha: .2),
          colors.first,
          colors[1],
          colors.last,
          colors.first.withValues(alpha: .2),
        ],
        stops: const <double>[0, .22, .5, .78, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius - 2, ring);

    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = colors.first.withValues(alpha: .85);
    canvas.drawCircle(center, radius - 5, detail);

    _drawMovingSparkles(canvas, center, radius, colors.first, phase);

    switch (theme.motif) {
      case 'crown':
        _drawCrown(canvas, center, radius, colors, phase);
        break;
      case 'heart':
        _drawHearts(canvas, center, radius, colors, phase);
        break;
      case 'butterfly':
        _drawButterflies(canvas, center, radius, colors, phase);
        break;
      case 'rose':
        _drawRoses(canvas, center, radius, colors, phase);
        break;
      case 'star':
        _drawStars(canvas, center, radius, colors, phase);
        break;
      case 'flower':
        _drawFlowers(canvas, center, radius, colors, phase);
        break;
      case 'blossom':
        _drawBlossoms(canvas, center, radius, colors, progress);
        break;
      case 'angel':
        _drawAngel(canvas, center, radius, colors, phase);
        break;
      case 'royal_wings':
        _drawRoyalWings(canvas, center, radius, colors, phase);
        break;
      case 'royal_love':
        _drawRoyalLove(canvas, center, radius, colors, phase);
        break;
      case 'nature':
        _drawNature(canvas, center, radius, colors, phase);
        break;
      default:
        break;
    }
  }

  void _drawMovingSparkles(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double phase,
  ) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 6; i++) {
      final a = phase + i * math.pi / 3;
      final p = Offset(
        center.dx + math.cos(a) * (radius - 2),
        center.dy + math.sin(a) * (radius - 2),
      );
      final pulse = 1.2 + (math.sin(a * 2) + 1) * .7;
      _drawSparkle(canvas, p, pulse, paint);
    }
  }

  void _drawCrown(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    final y = center.dy - radius - 4;
    final w = radius * .9;
    final pulse = 1 + math.sin(phase) * .05;
    canvas.save();
    canvas.translate(center.dx, y);
    canvas.scale(pulse);
    final path = Path()
      ..moveTo(-w / 2, 8)
      ..lineTo(-w * .35, -2)
      ..lineTo(-w * .1, 5)
      ..lineTo(0, -8)
      ..lineTo(w * .1, 5)
      ..lineTo(w * .35, -2)
      ..lineTo(w / 2, 8)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: colors).createShader(
          Rect.fromLTWH(-w / 2, -8, w, 18),
        ),
    );
    canvas.restore();
  }

  void _drawHearts(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 4 + i * math.pi / 2;
      final p = Offset(
        center.dx + math.cos(a) * (radius + 1),
        center.dy + math.sin(a) * (radius + 1),
      );
      final s = 3.5 + (math.sin(phase + i) + 1) * 1.2;
      _drawHeart(canvas, p, s, Paint()..color = colors[1]);
    }
  }

  void _drawButterflies(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    final flap = .55 + .45 * ((math.sin(phase * 2) + 1) / 2);
    for (final a in <double>[-2.45, -.7, .9, 2.4]) {
      final p = Offset(
        center.dx + math.cos(a) * (radius + 1),
        center.dy + math.sin(a) * (radius + 1),
      );
      _drawButterfly(canvas, p, 5.2, flap, colors[1]);
    }
  }

  void _drawRoses(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    for (final a in <double>[-2.4, -.9, .8, 2.25]) {
      final p = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      _drawFlower(canvas, p, 5.3, colors[1], phase + a);
    }
  }

  void _drawStars(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    for (var i = 0; i < 5; i++) {
      final a = phase * .35 + i * math.pi * 2 / 5;
      final p = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      _drawStar(canvas, p, 5.4, colors[i.isEven ? 0 : 1], a);
    }
  }

  void _drawFlowers(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      final p = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      _drawFlower(canvas, p, 5.4, colors[1], phase + a);
    }
  }

  void _drawBlossoms(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double progress,
  ) {
    final paint = Paint()..color = colors[1].withValues(alpha: .9);
    for (var i = 0; i < 7; i++) {
      final t = (progress + i / 7) % 1;
      final x = center.dx - radius + ((i * 17) % 100) / 100 * radius * 2;
      final y = center.dy - radius + t * radius * 2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 2);
      canvas.drawOval(
        const Rect.fromLTWH(-2.8, -1.5, 5.6, 3),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawAngel(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    final flap = 2 + math.sin(phase * 2) * 2;
    _drawWing(canvas, Offset(center.dx - radius * .72, center.dy), -1, flap, colors[1]);
    _drawWing(canvas, Offset(center.dx + radius * .72, center.dy), 1, flap, colors[1]);
    _drawCrown(canvas, center, radius, colors, phase);
  }

  void _drawRoyalWings(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    final flap = 3 + math.sin(phase * 2) * 1.5;
    _drawWing(canvas, Offset(center.dx - radius * .72, center.dy), -1, flap, colors[1]);
    _drawWing(canvas, Offset(center.dx + radius * .72, center.dy), 1, flap, colors[1]);
    final paint = Paint()..color = colors[0];
    _drawSparkle(canvas, Offset(center.dx, center.dy - radius - 2), 3.5, paint);
  }

  void _drawRoyalLove(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    _drawHearts(canvas, center, radius, colors, phase);
    _drawCrown(canvas, center, radius, colors, phase);
  }

  void _drawNature(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
  ) {
    for (var i = 0; i < 7; i++) {
      final a = -2.7 + i * .9 + math.sin(phase + i) * .08;
      final p = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      _drawLeaf(canvas, p, a, colors[1]);
    }
  }

  void _drawSparkle(Canvas canvas, Offset p, double size, Paint paint) {
    final path = Path()
      ..moveTo(p.dx, p.dy - size)
      ..lineTo(p.dx + size * .28, p.dy - size * .28)
      ..lineTo(p.dx + size, p.dy)
      ..lineTo(p.dx + size * .28, p.dy + size * .28)
      ..lineTo(p.dx, p.dy + size)
      ..lineTo(p.dx - size * .28, p.dy + size * .28)
      ..lineTo(p.dx - size, p.dy)
      ..lineTo(p.dx - size * .28, p.dy - size * .28)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Offset p, double size, Paint paint) {
    final path = Path()
      ..moveTo(p.dx, p.dy + size * .8)
      ..cubicTo(
        p.dx - size * 1.4,
        p.dy,
        p.dx - size,
        p.dy - size,
        p.dx,
        p.dy - size * .25,
      )
      ..cubicTo(
        p.dx + size,
        p.dy - size,
        p.dx + size * 1.4,
        p.dy,
        p.dx,
        p.dy + size * .8,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawButterfly(
    Canvas canvas,
    Offset p,
    double size,
    double flap,
    Color color,
  ) {
    final paint = Paint()..color = color.withValues(alpha: .92);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx - size * .45, p.dy),
        width: size * flap,
        height: size,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx + size * .45, p.dy),
        width: size * flap,
        height: size,
      ),
      paint,
    );
    canvas.drawCircle(p, size * .12, Paint()..color = Colors.white70);
  }

  void _drawFlower(
    Canvas canvas,
    Offset p,
    double size,
    Color color,
    double rotation,
  ) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(rotation);
    final petal = Paint()..color = color.withValues(alpha: .9);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / 5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -size * .42),
          width: size * .45,
          height: size * .9,
        ),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, size * .18, Paint()..color = Colors.white70);
    canvas.restore();
  }

  void _drawStar(
    Canvas canvas,
    Offset p,
    double radius,
    Color color,
    double rotation,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * .42;
      final a = rotation - math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        p.dx + math.cos(a) * r,
        p.dy + math.sin(a) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawWing(
    Canvas canvas,
    Offset p,
    double direction,
    double flap,
    Color color,
  ) {
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(
        p.dx + direction * (12 + flap),
        p.dy - 10,
        p.dx + direction * (18 + flap),
        p.dy - 2,
      )
      ..quadraticBezierTo(
        p.dx + direction * 12,
        p.dy + 5,
        p.dx,
        p.dy + 3,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .82)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawLeaf(
    Canvas canvas,
    Offset p,
    double angle,
    Color color,
  ) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      const Rect.fromLTWH(-4.5, -2.4, 9, 4.8),
      Paint()..color = color.withValues(alpha: .9),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VipRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.level != level ||
      oldDelegate.styleId != styleId;
}
