import 'dart:math' as math;

import 'package:flutter/material.dart';

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
        milliseconds: _freeAnimatedFrameIds.contains(styleId) ? 2000 : 3200,
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
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          child: Padding(padding: const EdgeInsets.all(8), child: widget.child),
          builder: (context, child) => CustomPaint(
            painter: widget.enabled
                ? _VipRingPainter(
                    _controller.value,
                    widget.level,
                    widget.styleId,
                  )
                : null,
            child: child,
          ),
        ),
      );
}

class _FrameTheme {
  const _FrameTheme(this.colors, this.motif);
  final List<Color> colors;
  final String motif;
}

_FrameTheme _themeFor(String? styleId, int level) => switch (styleId) {
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
          <Color>[Color(0xFFD7FFD8), Color(0xFF67D66F), Color(0xFF23763D)],
          'nature',
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
