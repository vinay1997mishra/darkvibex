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
      duration: const Duration(milliseconds: 1750),
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
              final progress = Curves.easeInCubic.transform(_controller.value);
              final fade = (1.0 - ((_controller.value - .72) / .28))
                  .clamp(0.0, 1.0)
                  .toDouble();
              final rocketSize = 56.0 + progress * 22.0;
              final trailHeight = 16.0 + progress * 88.0;
              final left = constraints.maxWidth -
                  rocketSize -
                  12.0 -
                  constraints.maxWidth * .42 * progress;
              final bottom = 90.0 + constraints.maxHeight * 1.02 * progress;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: math.max(0.0, left),
                    bottom: bottom,
                    child: Opacity(
                      opacity: fade,
                      child: Transform.rotate(
                        angle: -.84,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RoomStealthRocketLogo(
                              key: const Key('room-rocket-launching-art'),
                              size: rocketSize,
                              level: widget.level,
                            ),
                            Container(
                              width: rocketSize * .12,
                              height: trailHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(rocketSize),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    accentColorForLevel(widget.level)
                                        .withValues(alpha: .86 * fade),
                                    accentColorForLevel(widget.level)
                                        .withValues(alpha: .42 * fade),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColorForLevel(widget.level)
                                        .withValues(alpha: .48 * fade),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
