import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class JewelryRingPreview extends StatelessWidget {
  const JewelryRingPreview({
    super.key,
    required this.styleId,
    this.size = 108,
    this.imageProvider,
  });

  final String styleId;
  final double size;
  final ImageProvider<Object>? imageProvider;

  String? get _builtinAsset => switch (styleId) {
        'ring-heart' => 'assets/images/ring_heart.svg',
        'ring-crystal' => 'assets/images/ring_crystal.svg',
        'ring-royal' => 'assets/images/ring_royal.svg',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final asset = _builtinAsset;
    return SizedBox.square(
      dimension: size,
      child: imageProvider != null
          ? Image(
              image: imageProvider!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            )
          : asset != null
              ? SvgPicture.asset(
                  asset,
                  fit: BoxFit.contain,
                )
              : CustomPaint(
                  painter: _JewelryRingPainter(styleId),
                ),
    );
  }
}

String ringDisplayName(String? styleId) => switch (styleId) {
      'ring-heart' => 'Heart Ring',
      'ring-crystal' => 'Crystal Ring',
      'ring-royal' => 'Royal Ring',
      _ => 'CP Ring',
    };

class _RingTheme {
  const _RingTheme({
    required this.band,
    required this.gem,
    required this.glow,
    required this.shape,
  });

  final List<Color> band;
  final List<Color> gem;
  final Color glow;
  final String shape;
}

_RingTheme _ringTheme(String styleId) => switch (styleId) {
      'ring-heart' => const _RingTheme(
          band: <Color>[
            Color(0xFFFFE6B0),
            Color(0xFFFFA45B),
            Color(0xFFFFD8E8),
          ],
          gem: <Color>[
            Color(0xFFFFD2E7),
            Color(0xFFFF3D98),
            Color(0xFFB70D53),
          ],
          glow: Color(0xFFFF4FA8),
          shape: 'heart',
        ),
      'ring-crystal' => const _RingTheme(
          band: <Color>[
            Color(0xFFF5FAFF),
            Color(0xFF9CC7FF),
            Color(0xFFE4F3FF),
          ],
          gem: <Color>[
            Color(0xFFE8FBFF),
            Color(0xFF4FA8FF),
            Color(0xFF2154D8),
          ],
          glow: Color(0xFF55B9FF),
          shape: 'diamond',
        ),
      'ring-royal' => const _RingTheme(
          band: <Color>[
            Color(0xFFFFF0A6),
            Color(0xFFFFB11B),
            Color(0xFFB96A00),
          ],
          gem: <Color>[
            Color(0xFFFFD2B0),
            Color(0xFFFF4A39),
            Color(0xFF8E0A0A),
          ],
          glow: Color(0xFFFFA52E),
          shape: 'royal',
        ),
      _ => const _RingTheme(
          band: <Color>[
            Color(0xFFFFF0A6),
            Color(0xFFFFB11B),
            Color(0xFFEAC2FF),
          ],
          gem: <Color>[
            Color(0xFFF0D5FF),
            Color(0xFFB956FF),
            Color(0xFF6131C6),
          ],
          glow: Color(0xFFB956FF),
          shape: 'diamond',
        ),
    };

class _JewelryRingPainter extends CustomPainter {
  const _JewelryRingPainter(this.styleId);

  final String styleId;

  @override
  void paint(Canvas canvas, Size size) {
    final theme = _ringTheme(styleId);
    final center = Offset(size.width / 2, size.height * .62);
    final bandRect = Rect.fromCenter(
      center: center,
      width: size.width * .66,
      height: size.height * .34,
    );

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .12
      ..color = theme.glow.withValues(alpha: .20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(bandRect, glow);

    final band = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .095
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: theme.band,
      ).createShader(bandRect);
    canvas.drawOval(bandRect, band);

    final bandHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .018
      ..color = Colors.white.withValues(alpha: .80);
    canvas.drawArc(
      bandRect.deflate(size.width * .045),
      math.pi * 1.05,
      math.pi * .78,
      false,
      bandHighlight,
    );

    final gemCenter = Offset(size.width / 2, size.height * .29);
    final gemSize = size.width * .27;
    final gemGlow = Paint()
      ..color = theme.glow.withValues(alpha: .34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(gemCenter, gemSize * .72, gemGlow);

    final gemPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.25, -.35),
        radius: .95,
        colors: theme.gem,
      ).createShader(
        Rect.fromCircle(center: gemCenter, radius: gemSize),
      );

    final gemOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .018
      ..color = Colors.white.withValues(alpha: .82);

    if (theme.shape == 'heart') {
      final path = _heartPath(gemCenter, gemSize);
      canvas.drawPath(path, gemPaint);
      canvas.drawPath(path, gemOutline);
    } else {
      final path = Path()
        ..moveTo(gemCenter.dx, gemCenter.dy - gemSize * .65)
        ..lineTo(gemCenter.dx + gemSize * .62, gemCenter.dy - gemSize * .05)
        ..lineTo(gemCenter.dx, gemCenter.dy + gemSize * .68)
        ..lineTo(gemCenter.dx - gemSize * .62, gemCenter.dy - gemSize * .05)
        ..close();
      canvas.drawPath(path, gemPaint);
      canvas.drawPath(path, gemOutline);
      if (theme.shape == 'royal') {
        _drawCrown(canvas, gemCenter, gemSize, theme);
      }
    }

    final sideStone = Paint()..color = Colors.white.withValues(alpha: .92);
    for (final x in <double>[-.27, -.19, .19, .27]) {
      final p = Offset(
        size.width / 2 + size.width * x,
        size.height * .43 + x.abs() * size.height * .08,
      );
      canvas.drawCircle(p, size.width * .025, sideStone);
    }

    final sparkle = Paint()..color = theme.glow.withValues(alpha: .95);
    for (final point in <Offset>[
      Offset(size.width * .18, size.height * .23),
      Offset(size.width * .79, size.height * .20),
      Offset(size.width * .84, size.height * .47),
      Offset(size.width * .23, size.height * .55),
    ]) {
      _drawSpark(canvas, point, size.width * .035, sparkle);
    }
  }

  Path _heartPath(Offset c, double s) {
    return Path()
      ..moveTo(c.dx, c.dy + s * .58)
      ..cubicTo(
        c.dx - s * .68,
        c.dy + s * .12,
        c.dx - s * .66,
        c.dy - s * .48,
        c.dx - s * .28,
        c.dy - s * .48,
      )
      ..cubicTo(
        c.dx - s * .06,
        c.dy - s * .48,
        c.dx,
        c.dy - s * .26,
        c.dx,
        c.dy - s * .20,
      )
      ..cubicTo(
        c.dx,
        c.dy - s * .26,
        c.dx + s * .06,
        c.dy - s * .48,
        c.dx + s * .28,
        c.dy - s * .48,
      )
      ..cubicTo(
        c.dx + s * .66,
        c.dy - s * .48,
        c.dx + s * .68,
        c.dy + s * .12,
        c.dx,
        c.dy + s * .58,
      )
      ..close();
  }

  void _drawCrown(
    Canvas canvas,
    Offset c,
    double s,
    _RingTheme theme,
  ) {
    final crown = Path()
      ..moveTo(c.dx - s * .58, c.dy - s * .56)
      ..lineTo(c.dx - s * .32, c.dy - s * .92)
      ..lineTo(c.dx - s * .08, c.dy - s * .62)
      ..lineTo(c.dx + s * .12, c.dy - s * .96)
      ..lineTo(c.dx + s * .36, c.dy - s * .62)
      ..lineTo(c.dx + s * .58, c.dy - s * .88)
      ..lineTo(c.dx + s * .52, c.dy - s * .46)
      ..lineTo(c.dx - s * .50, c.dy - s * .46)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(colors: theme.band).createShader(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy - s * .70),
          width: s * 1.2,
          height: s * .6,
        ),
      );
    canvas.drawPath(crown, paint);
  }

  void _drawSpark(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
  }

  @override
  bool shouldRepaint(covariant _JewelryRingPainter oldDelegate) =>
      oldDelegate.styleId != styleId;
}

class BubbleCosmeticPreview extends StatelessWidget {
  const BubbleCosmeticPreview({
    super.key,
    required this.styleId,
    this.height = 94,
  });

  final String styleId;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = _bubbleTheme(styleId);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BubblePainter(theme),
      ),
    );
  }
}

class _BubbleTheme {
  const _BubbleTheme({
    required this.colors,
    required this.motif,
  });

  final List<Color> colors;
  final String motif;
}

_BubbleTheme _bubbleTheme(String styleId) => switch (styleId) {
      'bubble-heart' => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFFFC2DF),
            Color(0xFFFF3D98),
            Color(0xFFC016FF),
          ],
          motif: 'heart',
        ),
      'bubble-king' => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFB8E7FF),
            Color(0xFF2D77FF),
            Color(0xFFFFB11B),
          ],
          motif: 'king',
        ),
      'bubble-dream' => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFF0C9FF),
            Color(0xFF9B32FF),
            Color(0xFF5C20D6),
          ],
          motif: 'dream',
        ),
      'bubble-nature' => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFD9FFD9),
            Color(0xFF45E558),
            Color(0xFF0C8E38),
          ],
          motif: 'nature',
        ),
      'bubble-dragon' => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFFFC36A),
            Color(0xFFFF3A24),
            Color(0xFF8F121B),
          ],
          motif: 'dragon',
        ),
      'bubble-ice' => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFEAFBFF),
            Color(0xFF4CC8FF),
            Color(0xFF2F72FF),
          ],
          motif: 'ice',
        ),
      'bubble-sakura' => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFFFE2F0),
            Color(0xFFFF6FB5),
            Color(0xFFD62E84),
          ],
          motif: 'sakura',
        ),
      _ => const _BubbleTheme(
          colors: <Color>[
            Color(0xFFFFF2A6),
            Color(0xFFFFB11B),
            Color(0xFFFF6A18),
          ],
          motif: 'gold',
        ),
    };

class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.theme);

  final _BubbleTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .10,
        size.height * .22,
        size.width * .80,
        size.height * .50,
      ),
      Radius.circular(size.height * .22),
    );

    final outerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..color = theme.colors[1].withValues(alpha: .22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawRRect(body, outerGlow);

    final innerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = theme.colors.first.withValues(alpha: .26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(body, innerGlow);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          theme.colors.last.withValues(alpha: .36),
          const Color(0xFF120A1D).withValues(alpha: .96),
          Colors.black.withValues(alpha: .88),
        ],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..shader = LinearGradient(
        colors: <Color>[
          theme.colors.first,
          theme.colors[1],
          theme.colors.last,
          theme.colors.first,
        ],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, border);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: .75);
    canvas.drawArc(
      body.outerRect.deflate(3),
      math.pi * 1.08,
      math.pi * .58,
      false,
      highlight,
    );

    switch (theme.motif) {
      case 'heart':
        _drawHeartTheme(canvas, size);
        break;
      case 'king':
        _drawKingTheme(canvas, size);
        break;
      case 'dream':
        _drawDreamTheme(canvas, size);
        break;
      case 'nature':
        _drawNatureTheme(canvas, size);
        break;
      case 'dragon':
        _drawDragonTheme(canvas, size);
        break;
      case 'ice':
        _drawIceTheme(canvas, size);
        break;
      case 'sakura':
        _drawSakuraTheme(canvas, size);
        break;
      default:
        _drawGoldTheme(canvas, size);
        break;
    }

    final sparkle = Paint()..color = theme.colors.first;
    for (final p in <Offset>[
      Offset(size.width * .18, size.height * .17),
      Offset(size.width * .80, size.height * .14),
      Offset(size.width * .91, size.height * .45),
      Offset(size.width * .30, size.height * .77),
    ]) {
      _drawSpark(canvas, p, size.shortestSide * .022, sparkle);
    }
  }

  void _drawGoldTheme(Canvas canvas, Size size) {
    _drawCrown(
      canvas,
      Offset(size.width * .28, size.height * .22),
      size.width * .11,
      theme.colors,
    );
    for (final side in <double>[-1, 1]) {
      for (var i = 0; i < 4; i++) {
        final y = size.height * (.30 + i * .10);
        final x = side < 0 ? size.width * .12 : size.width * .88;
        _drawLeaf(
          canvas,
          Offset(x, y),
          side < 0 ? -.45 : math.pi + .45,
          size.width * .026,
          theme.colors[1],
        );
      }
    }
    _drawDiamond(
      canvas,
      Offset(size.width * .50, size.height * .72),
      size.width * .026,
      theme.colors.first,
    );
  }

  void _drawHeartTheme(Canvas canvas, Size size) {
    final paint = Paint()..color = theme.colors[1];
    final hearts = <Offset>[
      Offset(size.width * .13, size.height * .31),
      Offset(size.width * .18, size.height * .20),
      Offset(size.width * .84, size.height * .20),
      Offset(size.width * .90, size.height * .35),
      Offset(size.width * .84, size.height * .67),
    ];
    for (var i = 0; i < hearts.length; i++) {
      _drawHeart(
        canvas,
        hearts[i],
        size.width * (i == 0 ? .060 : .040),
        paint,
      );
    }
  }

  void _drawKingTheme(Canvas canvas, Size size) {
    _drawCrown(
      canvas,
      Offset(size.width * .48, size.height * .18),
      size.width * .12,
      theme.colors,
    );
    for (final side in <double>[-1, 1]) {
      for (var i = 0; i < 5; i++) {
        final y = size.height * (.31 + i * .085);
        final x = side < 0
            ? size.width * (.15 + i * .006)
            : size.width * (.85 - i * .006);
        _drawLeaf(
          canvas,
          Offset(x, y),
          side < 0 ? -.55 : math.pi + .55,
          size.width * .024,
          i.isEven ? theme.colors[2] : theme.colors[1],
        );
      }
    }
    _drawDiamond(
      canvas,
      Offset(size.width * .50, size.height * .72),
      size.width * .030,
      theme.colors[2],
    );
  }

  void _drawDreamTheme(Canvas canvas, Size size) {
    _drawButterfly(
      canvas,
      Offset(size.width * .18, size.height * .24),
      size.width * .055,
      theme.colors.first,
    );
    _drawButterfly(
      canvas,
      Offset(size.width * .84, size.height * .64),
      size.width * .047,
      theme.colors[1],
    );
    final p = Paint()..color = theme.colors.first;
    for (final point in <Offset>[
      Offset(size.width * .78, size.height * .20),
      Offset(size.width * .24, size.height * .67),
      Offset(size.width * .88, size.height * .34),
    ]) {
      _drawStar(canvas, point, size.width * .025, p);
    }
  }

  void _drawNatureTheme(Canvas canvas, Size size) {
    for (final side in <double>[-1, 1]) {
      for (var i = 0; i < 5; i++) {
        final x = side < 0 ? size.width * .14 : size.width * .86;
        final y = size.height * (.28 + i * .09);
        _drawLeaf(
          canvas,
          Offset(x, y),
          side < 0 ? -.65 : math.pi + .65,
          size.width * .028,
          theme.colors[1],
        );
      }
    }
    for (final point in <Offset>[
      Offset(size.width * .17, size.height * .32),
      Offset(size.width * .20, size.height * .62),
      Offset(size.width * .82, size.height * .30),
      Offset(size.width * .86, size.height * .59),
    ]) {
      _drawFlower(canvas, point, size.width * .040, Colors.white, theme.colors[2]);
    }
  }

  void _drawDragonTheme(Canvas canvas, Size size) {
    final flame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .022
      ..strokeCap = StrokeCap.round
      ..color = theme.colors[1];
    final left = Path()
      ..moveTo(size.width * .13, size.height * .58)
      ..quadraticBezierTo(
        size.width * .08,
        size.height * .36,
        size.width * .18,
        size.height * .22,
      )
      ..quadraticBezierTo(
        size.width * .22,
        size.height * .16,
        size.width * .27,
        size.height * .26,
      );
    canvas.drawPath(left, flame);
    final right = Path()
      ..moveTo(size.width * .86, size.height * .61)
      ..quadraticBezierTo(
        size.width * .95,
        size.height * .42,
        size.width * .88,
        size.height * .24,
      )
      ..quadraticBezierTo(
        size.width * .84,
        size.height * .14,
        size.width * .77,
        size.height * .24,
      );
    canvas.drawPath(right, flame);
    _drawDragonHead(
      canvas,
      Offset(size.width * .84, size.height * .31),
      size.width * .070,
    );
    _drawDiamond(
      canvas,
      Offset(size.width * .18, size.height * .66),
      size.width * .025,
      theme.colors.first,
    );
  }

  void _drawIceTheme(Canvas canvas, Size size) {
    for (final point in <Offset>[
      Offset(size.width * .16, size.height * .25),
      Offset(size.width * .22, size.height * .63),
      Offset(size.width * .80, size.height * .24),
      Offset(size.width * .86, size.height * .60),
    ]) {
      _drawSnowflake(
        canvas,
        point,
        size.width * .045,
        theme.colors.first,
      );
    }
  }

  void _drawSakuraTheme(Canvas canvas, Size size) {
    for (final point in <Offset>[
      Offset(size.width * .16, size.height * .27),
      Offset(size.width * .21, size.height * .60),
      Offset(size.width * .82, size.height * .25),
      Offset(size.width * .87, size.height * .58),
    ]) {
      _drawFlower(
        canvas,
        point,
        size.width * .046,
        theme.colors.first,
        theme.colors[1],
      );
    }
    final petal = Paint()..color = theme.colors.first.withValues(alpha: .9);
    for (final point in <Offset>[
      Offset(size.width * .34, size.height * .16),
      Offset(size.width * .74, size.height * .17),
      Offset(size.width * .70, size.height * .76),
    ]) {
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(.6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * .022,
          height: size.width * .040,
        ),
        petal,
      );
      canvas.restore();
    }
  }

  void _drawCrown(
    Canvas canvas,
    Offset center,
    double size,
    List<Color> colors,
  ) {
    final path = Path()
      ..moveTo(center.dx - size, center.dy + size * .36)
      ..lineTo(center.dx - size * .72, center.dy - size * .55)
      ..lineTo(center.dx - size * .28, center.dy - size * .08)
      ..lineTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * .30, center.dy - size * .08)
      ..lineTo(center.dx + size * .72, center.dy - size * .58)
      ..lineTo(center.dx + size, center.dy + size * .36)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(
        Rect.fromCenter(
          center: center,
          width: size * 2,
          height: size * 1.5,
        ),
      );
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .75),
    );
  }

  void _drawHeart(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * .85)
      ..cubicTo(
        c.dx - s * 1.25,
        c.dy + s * .1,
        c.dx - s * .9,
        c.dy - s * .95,
        c.dx,
        c.dy - s * .28,
      )
      ..cubicTo(
        c.dx + s * .9,
        c.dy - s * .95,
        c.dx + s * 1.25,
        c.dy + s * .1,
        c.dx,
        c.dy + s * .85,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawButterfly(Canvas canvas, Offset c, double s, Color color) {
    final wing = Paint()..color = color.withValues(alpha: .92);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-s * .60, -s * .05),
        width: s * 1.05,
        height: s * 1.40,
      ),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * .60, -s * .05),
        width: s * 1.05,
        height: s * 1.40,
      ),
      wing,
    );
    canvas.drawCircle(Offset.zero, s * .12, Paint()..color = Colors.white70);
    canvas.restore();
  }

  void _drawLeaf(
    Canvas canvas,
    Offset c,
    double angle,
    double s,
    Color color,
  ) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: s * 2.0,
        height: s,
      ),
      Paint()..color = color.withValues(alpha: .92),
    );
    canvas.restore();
  }

  void _drawFlower(
    Canvas canvas,
    Offset c,
    double s,
    Color petalColor,
    Color centerColor,
  ) {
    final petal = Paint()..color = petalColor.withValues(alpha: .94);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * math.pi * 2 / 5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -s * .55),
          width: s * .58,
          height: s,
        ),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      s * .22,
      Paint()..color = centerColor,
    );
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * .42;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * .72, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * .72, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white70,
    );
  }

  void _drawDragonHead(Canvas canvas, Offset c, double s) {
    final fill = Paint()..color = const Color(0xFF24111B);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = theme.colors[1];
    final path = Path()
      ..moveTo(c.dx - s, c.dy + s * .15)
      ..lineTo(c.dx - s * .25, c.dy - s * .62)
      ..lineTo(c.dx + s * .20, c.dy - s * .28)
      ..lineTo(c.dx + s * .92, c.dy - s * .60)
      ..lineTo(c.dx + s * .60, c.dy - s * .05)
      ..lineTo(c.dx + s, c.dy + s * .32)
      ..lineTo(c.dx + s * .30, c.dy + s * .20)
      ..lineTo(c.dx - s * .20, c.dy + s * .65)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, outline);
    canvas.drawCircle(
      Offset(c.dx + s * .30, c.dy - s * .05),
      s * .09,
      Paint()..color = theme.colors.first,
    );
  }

  void _drawSnowflake(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final end = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      canvas.drawLine(c, end, paint);
      final b1 = a + .55;
      final b2 = a - .55;
      final branchBase = Offset(
        c.dx + math.cos(a) * r * .62,
        c.dy + math.sin(a) * r * .62,
      );
      canvas.drawLine(
        branchBase,
        Offset(
          branchBase.dx + math.cos(b1) * r * .26,
          branchBase.dy + math.sin(b1) * r * .26,
        ),
        paint,
      );
      canvas.drawLine(
        branchBase,
        Offset(
          branchBase.dx + math.cos(b2) * r * .26,
          branchBase.dy + math.sin(b2) * r * .26,
        ),
        paint,
      );
    }
  }

  void _drawSpark(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * .25, c.dy - r * .25)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * .25, c.dy + r * .25)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * .25, c.dy + r * .25)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * .25, c.dy - r * .25)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.theme.motif != theme.motif ||
      oldDelegate.theme.colors != theme.colors;
}

class ProfileCardCosmeticPreview extends StatelessWidget {
  const ProfileCardCosmeticPreview({
    super.key,
    required this.styleId,
    required this.displayName,
    required this.publicId,
    required this.vipLevel,
    this.avatar,
  });

  final String styleId;
  final String displayName;
  final String publicId;
  final int vipLevel;
  final ImageProvider<Object>? avatar;

  List<Color> get _colors => switch (styleId) {
        'profile-card-pink-heart' => const <Color>[
            Color(0xFFFF3D98),
            Color(0xFF7B1B7C),
            Color(0xFF140B21),
          ],
        'profile-card-crystal-star' => const <Color>[
            Color(0xFF52C7FF),
            Color(0xFF4B36C9),
            Color(0xFF100D24),
          ],
        'profile-card-vip-queen' => const <Color>[
            Color(0xFFFFB11B),
            Color(0xFF9B2CFF),
            Color(0xFF150C22),
          ],
        'profile-card-family-leader' => const <Color>[
            Color(0xFF67D66F),
            Color(0xFF1B6652),
            Color(0xFF0A1716),
          ],
        'profile-card-birthday' => const <Color>[
            Color(0xFFFF7DB6),
            Color(0xFF6957FF),
            Color(0xFF160D24),
          ],
        'profile-card-winner' => const <Color>[
            Color(0xFFFFD36A),
            Color(0xFFFF6A2C),
            Color(0xFF1D0C12),
          ],
        _ => const <Color>[
            Color(0xFFFFD36A),
            Color(0xFF8B4D18),
            Color(0xFF150D18),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: colors.first.withValues(alpha: .9)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.first.withValues(alpha: .28),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.first.withValues(alpha: .6),
                  blurRadius: 10,
                ),
              ],
            ),
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              backgroundImage: avatar,
              child: avatar == null
                  ? const Icon(Icons.person_rounded, color: Colors.white70)
                  : null,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            displayName.isEmpty ? 'DarkVibeX' : displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: colors.first.withValues(alpha: .20),
                  border: Border.all(color: colors.first),
                ),
                child: Text(
                  'VIP$vipLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 8,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'ID $publicId',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD36A), size: 13),
              SizedBox(width: 4),
              Icon(Icons.favorite_rounded,
                  color: Color(0xFFFF79B0), size: 12),
              SizedBox(width: 4),
              Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF78C8FF), size: 12),
            ],
          ),
        ],
      ),
    );
  }
}
