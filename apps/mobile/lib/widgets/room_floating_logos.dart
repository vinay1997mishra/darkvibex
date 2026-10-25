import 'dart:math' as math;

import 'package:flutter/material.dart';

class RoomGameKeyboardLogo extends StatelessWidget {
  const RoomGameKeyboardLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('game-keyboard-logo'),
      width: size,
      height: size * 0.66,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(size * 0.16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.88),
            width: 1.2,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55FFFFFF),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.13),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final whiteKeyWidth = constraints.maxWidth / 6;
              return Stack(
                children: <Widget>[
                  Row(
                    children: List<Widget>.generate(
                      6,
                      (index) => Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F3),
                            border: Border(
                              right: index == 5
                                  ? BorderSide.none
                                  : const BorderSide(
                                      color: Color(0xFF161616),
                                      width: 1,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final index in <int>[0, 1, 3, 4])
                    Positioned(
                      left: whiteKeyWidth * (index + 1) -
                          whiteKeyWidth * 0.19,
                      top: 0,
                      width: whiteKeyWidth * 0.38,
                      height: constraints.maxHeight * 0.60,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF080808),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class RoomStealthRocketLogo extends StatelessWidget {
  const RoomStealthRocketLogo({
    super.key,
    required this.size,
    this.level = 1,
  });

  final double size;
  final int level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('realistic-black-rocket-logo'),
      width: size,
      height: size,
      child: Transform.rotate(
        angle: 0.42,
        child: CustomPaint(
          painter: _StealthRocketPainter(level: level),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class _StealthRocketPainter extends CustomPainter {
  const _StealthRocketPainter({required this.level});

  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stage = level.clamp(1, 10).toInt();
    const bodyColors = <Color>[
      Color(0xFF61758D),
      Color(0xFF1768D2),
      Color(0xFF713BC0),
      Color(0xFF0A9479),
      Color(0xFFB8294B),
      Color(0xFFB87917),
      Color(0xFFB52FB3),
      Color(0xFF078DAE),
      Color(0xFF5842C8),
      Color(0xFFCBB66D),
    ];
    const accentColors = <Color>[
      Color(0xFF57E9FF),
      Color(0xFF4BA8FF),
      Color(0xFFD06BFF),
      Color(0xFF62FFD1),
      Color(0xFFFF5B83),
      Color(0xFFFFD45A),
      Color(0xFFFF83E6),
      Color(0xFF54F4FF),
      Color(0xFFAFA0FF),
      Color(0xFFFFF0A5),
    ];
    final bodyColor = bodyColors[stage - 1];
    final accentColor = accentColors[stage - 1];
    final bodyDark = Color.lerp(bodyColor, Colors.black, .72)!;
    final bodyLight = Color.lerp(
      bodyColor,
      Colors.white,
      stage >= 8 ? .66 : .38,
    )!;

    if (stage >= 7) {
      canvas.save();
      canvas.translate(w * .50, h * .46);
      canvas.rotate(-.55);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: w * (1.04 + (stage - 7) * .045),
          height: h * (.22 + (stage - 7) * .025),
        ),
        Paint()
          ..color = accentColor.withValues(alpha: stage >= 9 ? .74 : .52)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * (stage >= 9 ? .026 : .018),
      );
      canvas.restore();
      final stars = <Offset>[
        Offset(w * .13, h * .24),
        Offset(w * .83, h * .30),
        Offset(w * .17, h * .59),
        Offset(w * .80, h * .65),
        Offset(w * .50, h * .10),
      ];
      final starCount = stage >= 9 ? stars.length : 3;
      for (var index = 0; index < starCount; index++) {
        canvas.drawCircle(
          stars[index],
          w * (stage >= 9 ? .035 : .025),
          Paint()..color = accentColor.withValues(alpha: .82),
        );
      }
    }

    final flameGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accentColor.withValues(alpha: .78),
          accentColor.withValues(alpha: .24),
          Colors.transparent,
        ],
        stops: const <double>[0, 0.48, 1],
      ).createShader(
        Rect.fromCircle(
          center: Offset(w * 0.50, h * 0.89),
          radius: w * 0.34,
        ),
      );
    canvas.drawCircle(Offset(w * 0.50, h * 0.89), w * 0.34, flameGlow);

    final outerFlame = Path()
      ..moveTo(w * 0.40, h * 0.78)
      ..cubicTo(
        w * 0.31,
        h * 0.88,
        w * 0.40,
        h * 0.98,
        w * 0.50,
        h,
      )
      ..cubicTo(
        w * 0.60,
        h * 0.98,
        w * 0.69,
        h * 0.88,
        w * 0.60,
        h * 0.78,
      )
      ..close();
    canvas.drawPath(
      outerFlame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(accentColor, Colors.white, .76)!,
            accentColor,
            Color.lerp(accentColor, Colors.black, .12)!,
            Color.lerp(accentColor, Colors.black, .38)!,
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.76, w, h * 0.24)),
    );

    final innerFlame = Path()
      ..moveTo(w * 0.45, h * 0.79)
      ..quadraticBezierTo(w * 0.50, h * 0.95, w * 0.55, h * 0.79)
      ..close();
    canvas.drawPath(
      innerFlame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            Color.lerp(accentColor, Colors.white, .58)!,
            accentColor,
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.78, w, h * 0.18)),
    );

    final leftFin = Path()
      ..moveTo(w * 0.36, h * 0.58)
      ..lineTo(w * 0.12, h * 0.79)
      ..lineTo(w * 0.38, h * 0.73)
      ..close();
    final rightFin = Path()
      ..moveTo(w * 0.64, h * 0.58)
      ..lineTo(w * 0.88, h * 0.79)
      ..lineTo(w * 0.62, h * 0.73)
      ..close();

    final finPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          bodyDark,
          Color.lerp(bodyColor, Colors.white, .12)!,
          bodyDark,
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.55, w, h * 0.26));
    canvas.drawPath(leftFin, finPaint);
    canvas.drawPath(rightFin, finPaint);

    final finEdge = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.15, h * 0.78),
      Offset(w * 0.37, h * 0.62),
      finEdge,
    );
    canvas.drawLine(
      Offset(w * 0.85, h * 0.78),
      Offset(w * 0.63, h * 0.62),
      finEdge,
    );

    final body = Path()
      ..moveTo(w * 0.50, h * 0.04)
      ..cubicTo(
        w * 0.33,
        h * 0.14,
        w * 0.30,
        h * 0.40,
        w * 0.34,
        h * 0.70,
      )
      ..quadraticBezierTo(w * 0.50, h * 0.77, w * 0.66, h * 0.70)
      ..cubicTo(
        w * 0.70,
        h * 0.40,
        w * 0.67,
        h * 0.14,
        w * 0.50,
        h * 0.04,
      )
      ..close();

    final bodyRect =
        Rect.fromLTWH(w * 0.30, h * 0.03, w * 0.40, h * 0.75);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            bodyDark,
            Color.lerp(bodyColor, Colors.black, .30)!,
            bodyLight,
            bodyColor,
            bodyDark,
          ],
          stops: const <double>[0, 0.24, 0.48, 0.72, 1],
        ).createShader(bodyRect),
    );

    canvas.drawPath(
      body,
      Paint()
        ..color = Color.lerp(bodyColor, Colors.white, .62)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025,
    );

    final highlight = Path()
      ..moveTo(w * 0.43, h * 0.12)
      ..cubicTo(
        w * 0.38,
        h * 0.28,
        w * 0.39,
        h * 0.50,
        w * 0.41,
        h * 0.63,
      );
    canvas.drawPath(
      highlight,
      Paint()
        ..color = Color.lerp(accentColor, Colors.white, .52)!
            .withValues(alpha: .76)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );

    final accentY = h * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, accentY, w * 0.32, h * 0.06),
        Radius.circular(w * 0.025),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            Color.lerp(accentColor, Colors.black, .42)!,
            accentColor,
            Color.lerp(accentColor, Colors.white, .22)!,
          ],
        ).createShader(
          Rect.fromLTWH(w * 0.34, accentY, w * 0.32, h * 0.06),
        ),
    );

    final panelLine = Paint()
      ..color = accentColor.withValues(alpha: .48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014;
    canvas.drawLine(
      Offset(w * 0.36, h * 0.47),
      Offset(w * 0.64, h * 0.47),
      panelLine,
    );
    canvas.drawLine(
      Offset(w * 0.37, h * 0.61),
      Offset(w * 0.63, h * 0.61),
      panelLine,
    );

    final windowCenter = Offset(w * 0.50, h * 0.42);
    canvas.drawCircle(
      windowCenter,
      w * 0.135,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Color.lerp(bodyColor, Colors.white, .78)!,
            Color.lerp(bodyColor, Colors.white, .24)!,
            bodyDark,
          ],
        ).createShader(
          Rect.fromCircle(center: windowCenter, radius: w * 0.135),
        ),
    );
    canvas.drawCircle(
      windowCenter,
      w * 0.095,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.35, -0.40),
          colors: <Color>[
            Color.lerp(accentColor, Colors.white, .78)!,
            Color.lerp(accentColor, Colors.white, .22)!,
            accentColor,
            bodyDark,
          ],
          stops: const <double>[0, 0.22, 0.60, 1],
        ).createShader(
          Rect.fromCircle(center: windowCenter, radius: w * 0.095),
        ),
    );
    canvas.drawCircle(
      Offset(windowCenter.dx - w * 0.026, windowCenter.dy - h * 0.032),
      w * 0.022,
      Paint()..color = Colors.white.withValues(alpha: .9),
    );

    final nozzleRect =
        Rect.fromLTWH(w * 0.38, h * 0.70, w * 0.24, h * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        nozzleRect,
        Radius.circular(w * 0.04),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            bodyDark,
            Color.lerp(bodyColor, Colors.white, .86)!,
            Color.lerp(bodyColor, Colors.white, .26)!,
            bodyDark,
          ],
        ).createShader(nozzleRect),
    );
    canvas.drawLine(
      Offset(w * 0.39, h * 0.755),
      Offset(w * 0.61, h * 0.755),
      Paint()
        ..color = accentColor.withValues(alpha: .78)
        ..strokeWidth = w * 0.025,
    );
  }

  @override
  bool shouldRepaint(covariant _StealthRocketPainter oldDelegate) =>
      oldDelegate.level != level;
}

/// A room-wide, cinematic rocket take-off. This is the room target rocket,
/// separate from gift/vehicle effects.
class RoomRocketLaunchEffect extends StatefulWidget {
  const RoomRocketLaunchEffect({
    super.key,
    required this.level,
    required this.onFinished,
  });

  final int level;
  final VoidCallback onFinished;

  @override
  State<RoomRocketLaunchEffect> createState() =>
      _RoomRocketLaunchEffectState();
}

class _RoomRocketLaunchEffectState extends State<RoomRocketLaunchEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2850),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onFinished();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final raw = _controller.value;
              // A short engine-charge beat makes take-off feel deliberate.
              final ignition = (raw / .22).clamp(0.0, 1.0).toDouble();
              final flightRaw =
                  ((raw - .16) / .84).clamp(0.0, 1.0).toDouble();
              final flight = Curves.easeInCubic.transform(flightRaw);
              final fade = (1.0 - ((raw - .86) / .14))
                  .clamp(0.0, 1.0)
                  .toDouble();
              final flash = (1.0 - raw / .16).clamp(0.0, 1.0).toDouble();
              final shake = (1.0 - raw / .24).clamp(0.0, 1.0).toDouble();
              final shakeX = math.sin(raw * 170) * 4.8 * shake;
              final shakeY = math.cos(raw * 145) * 2.2 * shake;
              final rocketSize = 62.0 + flight * 20.0;
              final trailHeight = 10.0 + flight * 92.0;
              final left = constraints.maxWidth -
                  rocketSize -
                  8.0 -
                  constraints.maxWidth * .48 * flight;
              final bottom =
                  74.0 + constraints.maxHeight * 1.15 * flight;
              final accent = accentColorForLevel(widget.level);
              final rocketScale = 1.0 +
                  .11 * (1.0 - ((raw - .07) / .2).clamp(0.0, 1.0));

              return Transform.translate(
                offset: Offset(shakeX, shakeY),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Soft ignition bloom, rings and light streaks across the
                    // room give the launch a full-screen moment without
                    // blocking room chat or controls.
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RocketLaunchAtmospherePainter(
                          progress: raw,
                          flash: flash,
                          color: accent,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RocketLaunchTrailPainter(
                          progress: flight,
                          fade: fade,
                          color: accent,
                        ),
                      ),
                    ),
                    Positioned(
                      left: math.max(0.0, left).toDouble(),
                      bottom: bottom,
                      child: Opacity(
                        opacity: fade,
                        child: Transform.rotate(
                          angle: -.84 - (.035 * flight),
                          child: Transform.scale(
                            scale: rocketScale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RoomStealthRocketLogo(
                                  key: const Key('room-rocket-launching-art'),
                                  size: rocketSize,
                                  level: widget.level,
                                ),
                                CustomPaint(
                                  size: Size(rocketSize * .72, trailHeight),
                                  painter: _RocketExhaustPainter(
                                    progress: raw,
                                    ignition: ignition,
                                    flight: flight,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RocketLaunchAtmospherePainter extends CustomPainter {
  const _RocketLaunchAtmospherePainter({
    required this.progress,
    required this.flash,
    required this.color,
  });

  final double progress;
  final double flash;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final origin = Offset(size.width * .925, size.height * .79);

    if (flash > 0) {
      final radius = size.width * (.10 + (1.0 - flash) * .34);
      final bloom = Rect.fromCircle(center: origin, radius: radius);
      canvas.drawCircle(
        origin,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .28 * flash),
              color.withValues(alpha: .22 * flash),
              const Color(0xFF5C70FF).withValues(alpha: .08 * flash),
              Colors.transparent,
            ],
            stops: const [0, .22, .56, 1],
          ).createShader(bloom),
      );

      for (var ring = 0; ring < 3; ring++) {
        final ringProgress =
            ((progress * 1.7) - ring * .16).clamp(0.0, 1.0).toDouble();
        if (ringProgress <= 0) continue;
        canvas.drawCircle(
          origin,
          size.width * (.035 + ringProgress * .19),
          Paint()
            ..color = color.withValues(
              alpha: flash * (1.0 - ringProgress) * .38,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2 + (1.0 - ringProgress) * 1.8,
        );
      }
    }

    // Fast diagonal streaks appear only during the actual take-off.
    final streakFade = ((progress - .12) / .36).clamp(0.0, 1.0).toDouble() *
        (1.0 - progress * .55);
    for (var i = 0; i < 15; i++) {
      final seed = i.toDouble();
      final x = size.width * (.16 + (seed % 5) * .17) +
          math.sin(seed * 1.7 + progress * 12) * 9;
      final y = size.height * (.08 + (seed % 7) * .115) +
          progress * (20 + (i % 3) * 11);
      final length = 10.0 + (i % 4) * 8.0;
      final start = Offset(x, y);
      final finish = Offset(x - length * .46, y + length);
      canvas.drawLine(
        start,
        finish,
        Paint()
          ..color = (i.isEven ? Colors.white : color)
              .withValues(alpha: streakFade * .43)
          ..strokeWidth = i % 3 == 0 ? 1.6 : .8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _RocketLaunchAtmospherePainter oldDelegate,
  ) =>
      oldDelegate.progress != progress ||
      oldDelegate.flash != flash ||
      oldDelegate.color != color;
}

class _RocketExhaustPainter extends CustomPainter {
  const _RocketExhaustPainter({
    required this.progress,
    required this.ignition,
    required this.flight,
    required this.color,
  });

  final double progress;
  final double ignition;
  final double flight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final pulse = .78 + .22 * math.sin(progress * 47);
    final w = size.width;
    final h = size.height;
    final outerFlame = Path()
      ..moveTo(w * .37, 0)
      ..cubicTo(
        w * .28, h * .16,
        w * .04, h * (.38 + flight * .18),
        w * .50, h * pulse,
      )
      ..cubicTo(
        w * .96, h * (.38 + flight * .18),
        w * .72, h * .16,
        w * .63, 0,
      )
      ..close();

    // Warm, bright core with a cool outer plume based on rocket level.
    canvas.drawPath(
      outerFlame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: .98 * ignition),
            color.withValues(alpha: .96 * ignition),
            const Color(0xFFFF702A).withValues(alpha: .96 * ignition),
            const Color(0xFFFFD65B).withValues(alpha: .76 * ignition),
          ],
          stops: const <double>[0, .24, .64, 1],
        ).createShader(Offset.zero & size),
    );

    final coreFlame = Path()
      ..moveTo(w * .43, h * .02)
      ..cubicTo(w * .41, h * .24, w * .35, h * .42, w * .50, h * (pulse * .72))
      ..cubicTo(w * .65, h * .42, w * .59, h * .24, w * .57, h * .02)
      ..close();
    canvas.drawPath(
      coreFlame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            Color(0xFFFFF6C4),
            Color(0xFFFFA02E),
          ],
        ).createShader(Offset.zero & size),
    );

    // Rapidly flickering hot particles around the exhaust.
    for (var i = 0; i < 14; i++) {
      final seed = i.toDouble();
      final flicker = math.sin(progress * 44 + seed * 2.4);
      final x = w * (.10 + (seed % 7) * .13) + flicker * w * .11;
      final y = h * (.14 + (seed % 5) * .17) * pulse;
      final radius = (w * (.014 + ((i % 3) * .009))).toDouble();
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = (i.isEven ? Colors.white : color).withValues(
            alpha: (.78 - (i % 4) * .13).clamp(.22, .78).toDouble(),
          ),
      );
    }

    // A few wisps at the nozzle soften the transition from engine to trail.
    for (var i = 0; i < 5; i++) {
      final offset = Offset(
        w * (.28 + i * .11) + math.sin(progress * 20 + i) * 3,
        h * (.10 + (i % 3) * .12),
      );
      canvas.drawCircle(
        offset,
        3.0 + (i % 3) * 1.4,
        Paint()
          ..color = const Color(0xFF9DB7DE).withValues(
            alpha: (.18 + flight * .12) * ignition,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RocketExhaustPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ignition != ignition ||
      oldDelegate.flight != flight ||
      oldDelegate.color != color;
}

class _RocketLaunchTrailPainter extends CustomPainter {
  const _RocketLaunchTrailPainter({
    required this.progress,
    required this.fade,
    required this.color,
  });

  final double progress;
  final double fade;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;

    final start = Offset(size.width * .94, size.height * .80);
    final finish = Offset(size.width * .46, size.height * -.10);
    final head = Offset.lerp(start, finish, progress)!;
    final trajectory = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(head.dx, head.dy);

    canvas.drawPath(
      trajectory,
      Paint()
        ..color = color.withValues(alpha: .20 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 17),
    );
    canvas.drawPath(
      trajectory,
      Paint()
        ..color = const Color(0xFFFF8C32).withValues(alpha: .34 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      trajectory,
      Paint()
        ..color = Colors.white.withValues(alpha: .58 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    // Smoke puffs expand and drift behind the rocket rather than making the
    // launch trail look like a single static colored line.
    for (var i = 0; i < 16; i++) {
      final lag = .015 + i * .019;
      final fraction = (progress - lag).clamp(0.0, 1.0).toDouble();
      final age = progress - fraction;
      if (age <= 0) continue;
      final point = Offset.lerp(start, finish, fraction)!;
      final drift = math.sin(i * 1.9 + progress * 21) * age * 45;
      final puff = Offset(point.dx + drift, point.dy + age * 42);
      final radius = 4.5 + (i % 4) * 2.3 + age * 15;
      canvas.drawCircle(
        puff,
        radius,
        Paint()
          ..color = (i.isEven
                  ? const Color(0xFFB7C7E5)
                  : const Color(0xFF8B8DEB))
              .withValues(alpha: ((.19 - age * .45).clamp(0.0, .19)) * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Fresh multi-colour sparks linger briefly around the moving trail head.
    for (var i = 0; i < 58; i++) {
      final fraction = progress * (i / 58);
      final age = progress - fraction;
      if (age > .31) continue;
      final base = Offset.lerp(start, finish, fraction)!;
      final drift = math.sin(i * 2.13 + progress * 29) * age * 82;
      final position = Offset(base.dx + drift, base.dy + age * 58);
      final particleFade =
          ((1.0 - age / .31) * fade).clamp(0.0, 1.0).toDouble();
      final particleColor = switch (i % 5) {
        0 => Colors.white,
        1 => color,
        2 => const Color(0xFFFF8C32),
        3 => const Color(0xFF63DFFF),
        _ => const Color(0xFFD65DFF),
      };
      canvas.drawCircle(
        position,
        ((1.4 + (i % 3) * .65) * (1.0 - age * 1.25)).toDouble(),
        Paint()
          ..color = particleColor.withValues(alpha: particleFade * .96)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.7),
      );
    }

    // Rotating glints around the rocket head are visible during the ascent.
    final glintFade =
        ((1.0 - progress) * fade).clamp(0.0, 1.0).toDouble();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + progress * 9;
      final distance = 14.0 + progress * 21 + (i % 2) * 4.0;
      final point = Offset(
        head.dx + math.cos(angle) * distance,
        head.dy + math.sin(angle) * distance,
      );
      canvas.drawCircle(
        point,
        (1.4 + (i % 2) * .7).toDouble(),
        Paint()..color = Colors.white.withValues(alpha: glintFade * .95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RocketLaunchTrailPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fade != fade ||
      oldDelegate.color != color;
}

Color accentColorForLevel(int level) {
  const colors = <Color>[
    Color(0xFF57E9FF),
    Color(0xFF4BA8FF),
    Color(0xFFD06BFF),
    Color(0xFF62FFD1),
    Color(0xFFFF5B83),
    Color(0xFFFFD45A),
    Color(0xFFFF83E6),
    Color(0xFF54F4FF),
    Color(0xFFAFA0FF),
    Color(0xFFFFF0A5),
  ];
  return colors[level.clamp(1, 10).toInt() - 1];
}
