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
    this.height = 90,
  });

  final String styleId;
  final double height;

  List<Color> get _colors => switch (styleId) {
        'bubble-heart' => const <Color>[
            Color(0xFFFFB7D8),
            Color(0xFFFF3D98),
            Color(0xFF9B2CFF),
          ],
        'bubble-king' => const <Color>[
            Color(0xFF9ED7FF),
            Color(0xFF397BFF),
            Color(0xFFFFB11B),
          ],
        _ => const <Color>[
            Color(0xFFFFF1A8),
            Color(0xFFFFB11B),
            Color(0xFFFF7A1A),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BubblePainter(colors, styleId),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Hello',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                shadows: <Shadow>[
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter(this.colors, this.styleId);

  final List<Color> colors;
  final String styleId;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .08,
        size.height * .18,
        size.width * .82,
        size.height * .56,
      ),
      Radius.circular(size.height * .28),
    );

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = colors[1].withValues(alpha: .22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(body, glow);

    final fill = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          colors.last.withValues(alpha: .42),
          const Color(0xFF160D1F),
        ],
      ).createShader(body.outerRect);
    canvas.drawRRect(body, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..shader = LinearGradient(colors: colors).createShader(body.outerRect);
    canvas.drawRRect(body, border);

    final tail = Path()
      ..moveTo(size.width * .73, size.height * .72)
      ..lineTo(size.width * .82, size.height * .90)
      ..lineTo(size.width * .84, size.height * .69)
      ..close();
    canvas.drawPath(tail, border);

    if (styleId == 'bubble-heart') {
      final heartPaint = Paint()..color = colors[1];
      for (final p in <Offset>[
        Offset(size.width * .13, size.height * .22),
        Offset(size.width * .88, size.height * .26),
      ]) {
        canvas.drawCircle(p, 6, heartPaint);
        canvas.drawCircle(Offset(p.dx + 7, p.dy), 6, heartPaint);
      }
    } else if (styleId == 'bubble-king') {
      final crown = Paint()..color = colors.last;
      final path = Path()
        ..moveTo(size.width * .12, size.height * .22)
        ..lineTo(size.width * .16, size.height * .06)
        ..lineTo(size.width * .20, size.height * .20)
        ..lineTo(size.width * .25, size.height * .05)
        ..lineTo(size.width * .29, size.height * .22)
        ..close();
      canvas.drawPath(path, crown);
    }

    final sparkle = Paint()..color = colors.first;
    for (final p in <Offset>[
      Offset(size.width * .18, size.height * .12),
      Offset(size.width * .77, size.height * .11),
      Offset(size.width * .91, size.height * .47),
    ]) {
      canvas.drawCircle(p, 2.2, sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.styleId != styleId;
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
