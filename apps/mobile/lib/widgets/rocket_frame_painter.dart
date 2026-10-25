import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/rocket_frame_catalog.dart';

/// A lightweight, GPU-painted circular Rocket frame. It intentionally draws
/// ornamental detail outside the avatar edge and keeps the DP itself round.
/// All 100 IDs vary by tier palette, ornament motif, gem layout and animation.
class RocketFramePainter extends CustomPainter {
  const RocketFramePainter({
    required this.styleId,
    required this.phase,
  });

  final String styleId;
  final double phase;

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFFFFD66B), Color(0xFFFF8D37), Color(0xFF55DFFF)],
    <Color>[Color(0xFF56E8FF), Color(0xFF4978FF), Color(0xFFD75CFF)],
    <Color>[Color(0xFFFF57D2), Color(0xFF9B56FF), Color(0xFF58D9FF)],
    <Color>[Color(0xFFFFE68A), Color(0xFFF5A623), Color(0xFFFF4A59), Color(0xFF66D9FF)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (!isRocketRewardFrameId(styleId)) return;
    final group = rocketFrameGroupIndex(styleId);
    final variant = rocketFrameVariant(styleId);
    final colors = _palettes[group - 1];
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 3;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final spin = phase * math.pi * 2;
    final premium = group >= 3;
    final legendary = group == 4;
    final motif = (variant - 1) % 10;

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = legendary ? 8 : (premium ? 6 : 5)
        ..color = colors.first.withValues(alpha: .32 + .1 * math.sin(spin))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = legendary ? 3.5 : 2.7
        ..shader = SweepGradient(
          transform: GradientRotation(spin),
          colors: <Color>[
            colors.first.withValues(alpha: .25),
            colors.first,
            colors[1],
            colors.last,
            colors.first.withValues(alpha: .25),
          ],
          stops: const <double>[0, .2, .48, .78, 1],
        ).createShader(bounds),
    );

    canvas.drawCircle(
      center,
      radius - 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..color = colors[1].withValues(alpha: .9),
    );

    if (premium) {
      canvas.drawCircle(
        center,
        radius - 9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.last.withValues(alpha: .65),
      );
    }

    _drawSegmentedHalo(canvas, center, radius, colors, spin, variant, legendary);
    _drawSideOrnaments(canvas, center, radius, colors, spin, motif, group);
    _drawTopCrown(canvas, center, radius, colors, spin, variant, group);
    _drawBottomGem(canvas, center, radius, colors, spin, motif, group);
    _drawOrbitAndParticles(canvas, center, radius, colors, spin, variant, group);
  }

  void _drawSegmentedHalo(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
    int variant,
    bool legendary,
  ) {
    final count = legendary ? 20 : 16;
    final arcRadius = radius - (legendary ? 7 : 8);
    final rect = Rect.fromCircle(center: center, radius: arcRadius);
    final sweep = math.pi * 2 / count;
    for (var i = 0; i < count; i++) {
      final start = phase * .18 + i * sweep;
      final color = colors[(i + variant) % colors.length];
      canvas.drawArc(
        rect,
        start,
        sweep * (i.isEven ? .52 : .29),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = i.isEven ? (legendary ? 2.4 : 1.8) : 1.2
          ..color = color.withValues(alpha: .95),
      );
      if (i % 2 == 0) {
        final angle = start + sweep * .5;
        final point = Offset(
          center.dx + math.cos(angle) * arcRadius,
          center.dy + math.sin(angle) * arcRadius,
        );
        _drawGem(
          canvas,
          point,
          i % 4 == 0 ? 3.5 : 2.4,
          color,
          phase + i,
        );
      }
    }
  }

  void _drawSideOrnaments(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
    int motif,
    int group,
  ) {
    final scale = group == 4 ? 1.15 : 1.0;
    for (final side in <double>[-1, 1]) {
      final x = center.dx + side * (radius - 1);
      final y = center.dy - radius * .15;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(side * .38 + math.sin(phase) * .07);
      final path = Path()
        ..moveTo(0, -radius * .34 * scale)
        ..quadraticBezierTo(
          side * radius * .22,
          -radius * .23,
          side * radius * .10,
          -radius * .02,
        )
        ..quadraticBezierTo(
          side * radius * .26,
          radius * .12,
          0,
          radius * .31 * scale,
        )
        ..quadraticBezierTo(
          -side * radius * .10,
          radius * .08,
          -side * radius * .08,
          -radius * .07,
        )
        ..close();
      final wingColor = colors[(motif + (side < 0 ? 1 : 0)) % colors.length];
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              wingColor.withValues(alpha: group >= 3 ? .9 : .65),
              wingColor.withValues(alpha: .06),
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * .5,
              height: radius * .8,
            ),
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = group >= 3 ? 1.6 : 1
          ..color = wingColor.withValues(alpha: .95),
      );
      for (var feather = 0; feather < 3; feather++) {
        final featherY = -radius * .18 + feather * radius * .15;
        canvas.drawLine(
          Offset(-side * radius * .03, featherY),
          Offset(side * radius * .08, featherY + radius * .06),
          Paint()
            ..strokeWidth = .9
            ..color = wingColor.withValues(alpha: .65),
        );
      }
      canvas.restore();
    }
  }

  void _drawTopCrown(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
    int variant,
    int group,
  ) {
    final width = radius * (group == 4 ? .68 : .57);
    final height = radius * (group == 4 ? .28 : .22);
    final y = center.dy - radius + 1 - (group == 4 ? 2 : 0);
    final pulse = 1 + math.sin(phase * 2 + variant) * .035;
    canvas.save();
    canvas.translate(center.dx, y);
    canvas.scale(pulse);
    final points = 3 + (variant % 3);
    final path = Path()..moveTo(-width / 2, height * .45);
    for (var i = 0; i < points; i++) {
      final x = -width / 2 + width * i / (points - 1);
      final tipY = -height * ((i + variant) % 2 == 0 ? 1 : .62);
      path
        ..lineTo(x + width / (points - 1) * .28, tipY)
        ..lineTo(x + width / (points - 1) * .5, height * .36);
    }
    path
      ..lineTo(width / 2, height * .45)
      ..lineTo(width / 2, height * .66)
      ..lineTo(-width / 2, height * .66)
      ..close();
    final rect = Rect.fromCenter(
      center: Offset(0, 0),
      width: width,
      height: height * 1.6,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[colors.first, colors[1], colors.last],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = colors.first.withValues(alpha: .98),
    );
    _drawGem(
      canvas,
      Offset(0, -height * .12),
      group == 4 ? 4.8 : 3.3,
      colors[0],
      phase,
    );
    canvas.restore();
  }

  void _drawBottomGem(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
    int motif,
    int group,
  ) {
    final bottom = Offset(center.dx, center.dy + radius - 1);
    if (motif == 4) {
      _drawHeart(canvas, bottom, group == 4 ? 7 : 5.5, colors[1], phase);
    } else if (motif == 1 || motif == 5) {
      _drawStar(canvas, bottom, group == 4 ? 7 : 5, colors[0], phase);
    } else {
      _drawGem(canvas, bottom, group == 4 ? 7 : 5, colors[motif % colors.length], phase);
    }
  }

  void _drawOrbitAndParticles(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    double phase,
    int variant,
    int group,
  ) {
    if (variant % 5 == 0 || group >= 3) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(phase * (variant.isEven ? .23 : -.19));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2.2,
          height: radius * .67,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = group == 4 ? 1.6 : 1
          ..color = colors.last.withValues(alpha: .7),
      );
      canvas.restore();
    }

    for (var i = 0; i < 8; i++) {
      final angle = phase + i * math.pi / 4 + variant * .21;
      final radial = radius + (i.isEven ? 2.8 : -2.6);
      final point = Offset(
        center.dx + math.cos(angle) * radial,
        center.dy + math.sin(angle) * radial,
      );
      final size = 1.2 + (math.sin(angle * 2) + 1) * (group == 4 ? 1.6 : 1.1);
      if ((i + variant) % 3 == 0) {
        _drawStar(canvas, point, size * 1.5, colors[i % colors.length], angle);
      } else {
        canvas.drawCircle(
          point,
          size,
          Paint()
            ..color = colors[(i + variant) % colors.length]
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
        );
      }
    }

    for (var i = 0; i < 5; i++) {
      final angle = phase * .4 + i * math.pi * 2 / 5;
      final point = Offset(
        center.dx + math.cos(angle) * (radius - 1),
        center.dy + math.sin(angle) * (radius - 1),
      );
      _drawSparkle(canvas, point, 1.5 + (math.sin(angle * 2) + 1) * 1.1, colors[i % colors.length]);
    }
  }

  void _drawGem(Canvas canvas, Offset center, double size, Color color, double rotation) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * .12);
    final path = Path()
      ..moveTo(0, -size)
      ..lineTo(size * .72, -size * .25)
      ..lineTo(size * .58, size * .62)
      ..lineTo(0, size)
      ..lineTo(-size * .58, size * .62)
      ..lineTo(-size * .72, -size * .25)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[Colors.white.withValues(alpha: .95), color, color.withValues(alpha: .5)],
        ).createShader(Rect.fromCenter(center: Offset.zero, width: size * 1.5, height: size * 2)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = Colors.white.withValues(alpha: .82),
    );
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color, double rotation) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = rotation + i * math.pi / 5 - math.pi / 2;
      final radius = size * (i.isEven ? 1 : .43);
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .95));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .55
        ..color = Colors.white.withValues(alpha: .85),
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color, double phase) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * .8)
      ..cubicTo(center.dx - size * 1.25, center.dy + size * .05, center.dx - size * .92, center.dy - size * .95, center.dx, center.dy - size * .35)
      ..cubicTo(center.dx + size * .92, center.dy - size * .95, center.dx + size * 1.25, center.dy + size * .05, center.dx, center.dy + size * .8);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .9 + .1 * math.sin(phase * 2)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = Colors.white.withValues(alpha: .8),
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color.withValues(alpha: .9);
    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint..strokeWidth = .8,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(covariant RocketFramePainter oldDelegate) =>
      oldDelegate.styleId != styleId || oldDelegate.phase != phase;
}
