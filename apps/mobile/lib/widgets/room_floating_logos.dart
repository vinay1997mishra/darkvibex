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
  const RoomStealthRocketLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('realistic-black-rocket-logo'),
      width: size,
      height: size,
      child: Transform.rotate(
        angle: 0.42,
        child: CustomPaint(
          painter: const _StealthRocketPainter(),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class _StealthRocketPainter extends CustomPainter {
  const _StealthRocketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final flameGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0x99FF8A1F),
          const Color(0x33FF5A1F),
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
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFFFF6C8),
            Color(0xFFFFC13B),
            Color(0xFFFF7A1A),
            Color(0xFFFF3B12),
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
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white,
            Color(0xFFFFF2A8),
            Color(0xFFFFA62B),
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
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF050505),
          Color(0xFF26282C),
          Color(0xFF080808),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.55, w, h * 0.26));
    canvas.drawPath(leftFin, finPaint);
    canvas.drawPath(rightFin, finPaint);

    final redEdge = Paint()
      ..color = const Color(0xFF9E1C16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.15, h * 0.78),
      Offset(w * 0.37, h * 0.62),
      redEdge,
    );
    canvas.drawLine(
      Offset(w * 0.85, h * 0.78),
      Offset(w * 0.63, h * 0.62),
      redEdge,
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
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF050505),
            Color(0xFF15171A),
            Color(0xFF34373C),
            Color(0xFF101113),
            Color(0xFF030303),
          ],
          stops: <double>[0, 0.24, 0.48, 0.72, 1],
        ).createShader(bodyRect),
    );

    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF777B82)
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
        ..color = const Color(0x55FFFFFF)
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
        ..shader = const LinearGradient(
          colors: <Color>[
            Color(0xFF5C0907),
            Color(0xFFE33A24),
            Color(0xFF6C0A08),
          ],
        ).createShader(
          Rect.fromLTWH(w * 0.34, accentY, w * 0.32, h * 0.06),
        ),
    );

    final panelLine = Paint()
      ..color = const Color(0x665D6065)
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
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0xFFCBD2D7),
            Color(0xFF606870),
            Color(0xFF17191C),
          ],
        ).createShader(
          Rect.fromCircle(center: windowCenter, radius: w * 0.135),
        ),
    );
    canvas.drawCircle(
      windowCenter,
      w * 0.095,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.40),
          colors: <Color>[
            Color(0xFFD9FAFF),
            Color(0xFF39CFFF),
            Color(0xFF007AAE),
            Color(0xFF00263A),
          ],
          stops: <double>[0, 0.22, 0.60, 1],
        ).createShader(
          Rect.fromCircle(center: windowCenter, radius: w * 0.095),
        ),
    );
    canvas.drawCircle(
      Offset(windowCenter.dx - w * 0.026, windowCenter.dy - w * 0.032),
      w * 0.022,
      Paint()..color = const Color(0xBBFFFFFF),
    );

    final nozzleRect =
        Rect.fromLTWH(w * 0.38, h * 0.70, w * 0.24, h * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        nozzleRect,
        Radius.circular(w * 0.04),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF4A4D50),
            Color(0xFFD0D2D3),
            Color(0xFF666A6E),
            Color(0xFF1E2022),
          ],
        ).createShader(nozzleRect),
    );
    canvas.drawLine(
      Offset(w * 0.39, h * 0.755),
      Offset(w * 0.61, h * 0.755),
      Paint()
        ..color = const Color(0xFF181A1C)
        ..strokeWidth = w * 0.025,
    );
  }

  @override
  bool shouldRepaint(covariant _StealthRocketPainter oldDelegate) => false;
}
