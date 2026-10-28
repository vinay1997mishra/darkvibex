import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short cinematic room entrance effect. The vehicle artwork is drawn in
/// Flutter so the effect works without downloading a large video asset.
class VehicleEntryEffect extends StatefulWidget {
  const VehicleEntryEffect({
    super.key,
    required this.displayName,
    required this.level,
    this.customVehicle = false,
    this.vehicleLabel,
    this.vehicleId,
    this.showVehicle = true,
  });

  final String displayName;
  final int level;
  final bool customVehicle;
  final String? vehicleLabel;
  final String? vehicleId;
  final bool showVehicle;

  @override
  State<VehicleEntryEffect> createState() => _VehicleEntryEffectState();
}

List<Color> _vehicleColorsFor(int level, String? styleId) {
  final id = (styleId ?? '').toLowerCase();
  if (id.contains('phoenix') ||
      id.contains('dragon') ||
      id.contains('fire') ||
      id.contains('inferno') ||
      id.contains('angel-wings')) {
    return const [
      Color(0xFFFFD36E),
      Color(0xFFFF4B3E),
      Color(0xFFFF5DA8),
    ];
  }
  if (id.contains('royal') ||
      id.contains('king') ||
      id.contains('chariot') ||
      id.contains('castle') ||
      id.contains('golden')) {
    return const [
      Color(0xFFFFE9A6),
      Color(0xFFFFAA32),
      Color(0xFF9F6BFF),
    ];
  }
  if (id.contains('neon') || id.contains('comet')) {
    return const [
      Color(0xFFB8FAFF),
      Color(0xFF35B9FF),
      Color(0xFF9F6BFF),
    ];
  }
  if (level >= 18) {
    return const [Color(0xFFBFA7FF), Color(0xFFFF922E), Color(0xFFFF3E84)];
  }
  if (level >= 16) {
    return const [Color(0xFFBFA7FF), Color(0xFFEC4B69), Color(0xFFFF8E40)];
  }
  if (level >= 12) {
    return const [Color(0xFFBFA7FF), Color(0xFFFFB52E), Color(0xFFB675FF)];
  }
  return const [Color(0xFFBFA7FF), Color(0xFF53D9FF), Color(0xFF50D8FF)];
}

class VehicleShowcase extends StatefulWidget {
  const VehicleShowcase({
    super.key,
    required this.level,
    this.styleId = 'vehicle_spark',
  });

  final int level;
  final String styleId;

  @override
  State<VehicleShowcase> createState() => _VehicleShowcaseState();
}

class _VehicleShowcaseState extends State<VehicleShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SizedBox.expand(
          child: CustomPaint(
            painter: _EntryVehiclePainter(
              _controller.value,
              _vehicleColorsFor(widget.level, widget.styleId),
              widget.level,
              styleId: widget.styleId,
              showcase: true,
            ),
          ),
        ),
      );
}

class _VehicleEntryEffectState extends State<VehicleEntryEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styleId = widget.vehicleId ?? widget.vehicleLabel;
    final colors = _vehicleColorsFor(widget.level, styleId);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = t < .12 ? t / .12 : t > .84 ? (1 - t) / .16 : 1.0;
        final drive = Curves.easeOutCubic.transform((t / .62).clamp(0.0, 1.0).toDouble());
        final x = -1.2 + (drive * 1.35);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0).toDouble(),
          child: ColoredBox(
            color: const Color(0xE9080611),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _EntryBackdropPainter(t, colors),
                ),
                Align(
                  alignment: Alignment(0, -.28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.vehicleLabel ?? (widget.customVehicle ? 'KING OF VIP' : 'VIP ARRIVAL'),
                        style: TextStyle(
                          color: colors.first,
                          fontSize: 13,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: colors.first, blurRadius: 18)],
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'LEVEL ${widget.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showVehicle)
                  Align(
                    alignment: Alignment(0, .12),
                    child: Transform.translate(
                      offset: Offset(MediaQuery.sizeOf(context).width * x, 0),
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width * .82,
                        height: MediaQuery.sizeOf(context).height * .24,
                        child: CustomPaint(
                          painter: _EntryVehiclePainter(
                            t,
                            colors,
                            widget.level,
                            styleId: styleId,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: const Alignment(0, .12),
                    child: Icon(Icons.auto_awesome_rounded, size: 100, color: colors.first.withOpacity(.9)),
                  ),
                Align(
                  alignment: const Alignment(0, .55),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xD9161022),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.first.withOpacity(.8)),
                      boxShadow: [BoxShadow(color: colors.first.withOpacity(.22), blurRadius: 24)],
                    ),
                    child: Text(
                      widget.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 12,
                  right: 14,
                  child: IconButton(
                    onPressed: () => _controller.value = 1,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EntryBackdropPainter extends CustomPainter {
  const _EntryBackdropPainter(this.progress, this.colors);
  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .49);
    final radius = size.shortestSide * (.22 + progress * .08);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [colors[1].withOpacity(.30), colors[1].withOpacity(.05), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 2.8));
    canvas.drawCircle(center, radius * 2.8, glow);
    final rayPaint = Paint()..color = colors.first.withOpacity(.11);
    for (var i = 0; i < 18; i++) {
      final angle = i * math.pi / 9 + progress * .3;
      final end = Offset(center.dx + math.cos(angle) * size.width, center.dy + math.sin(angle) * size.height);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(end.dx, end.dy)
        ..close();
      canvas.drawPath(path, rayPaint);
    }
    final stars = Paint()..color = colors.first.withOpacity(.8);
    for (var i = 0; i < 22; i++) {
      final x = ((i * 67.0 + progress * 170) % size.width).toDouble();
      final y = ((i * 113.0 + progress * 90) % size.height).toDouble();
      final r = (1.1 + (i % 3) * .55).toDouble();
      canvas.drawCircle(Offset(x, y), r, stars);
    }
  }

  @override
  bool shouldRepaint(covariant _EntryBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}

class _EntryVehiclePainter extends CustomPainter {
  const _EntryVehiclePainter(
    this.progress,
    this.colors,
    this.level, {
    this.styleId = 'vehicle_spark',
    this.showcase = false,
  });

  final double progress;
  final List<Color> colors;
  final int level;
  final String styleId;
  final bool showcase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final id = styleId.toLowerCase();
    final isRoyal = id.contains('royal') ||
        id.contains('king') ||
        id.contains('chariot') ||
        id.contains('castle');
    final isPhoenix = id.contains('phoenix') ||
        id.contains('dragon') ||
        id.contains('fire') ||
        id.contains('inferno') ||
        id.contains('angel-wings');
    final isNeon = id.contains('neon') || id.contains('comet');
    final isKing = id.contains('king') || level >= 18;

    // Moving streaks sit behind the vehicle so the store preview feels alive,
    // while the room entry uses the same art in a one-way cinematic pass.
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final trailShift = showcase ? (progress * w * .14) : (progress * w * .08);
    for (var i = 0; i < 6; i++) {
      final y = h * (.36 + i * .075);
      final x = w * (.04 + (i % 3) * .045) + trailShift;
      trailPaint
        ..strokeWidth = 1.0 + (i % 3) * .65
        ..color = colors[i % colors.length].withOpacity(
          .18 + .16 * (1 - (progress - .5).abs() * 2),
        );
      canvas.drawLine(Offset(x, y), Offset(x + w * (.12 + (i % 2) * .05), y - h * .025), trailPaint);
    }

    final body = Path();
    if (isRoyal) {
      // A high-backed royal chariot silhouette, with a rounded cabin and
      // raised golden side panels rather than the default low sports coupe.
      body
        ..moveTo(w * .10, h * .68)
        ..lineTo(w * .17, h * .55)
        ..lineTo(w * .29, h * .51)
        ..lineTo(w * .31, h * .35)
        ..quadraticBezierTo(w * .33, h * .17, w * .49, h * .17)
        ..lineTo(w * .61, h * .17)
        ..quadraticBezierTo(w * .76, h * .18, w * .78, h * .36)
        ..lineTo(w * .79, h * .52)
        ..lineTo(w * .91, h * .56)
        ..lineTo(w * .97, h * .66)
        ..lineTo(w * .93, h * .77)
        ..lineTo(w * .10, h * .77)
        ..close();
    } else {
      body
        ..moveTo(w * .08, h * .68)
        ..lineTo(w * .16, h * .55)
        ..lineTo(w * .29, h * .49)
        ..lineTo(w * .39, h * .27)
        ..quadraticBezierTo(w * .43, h * .19, w * .52, h * .19)
        ..lineTo(w * .68, h * .19)
        ..quadraticBezierTo(w * .74, h * .20, w * .80, h * .31)
        ..lineTo(w * .91, h * .43)
        ..lineTo(w * .97, h * .51)
        ..lineTo(w * .99, h * .69)
        ..lineTo(w * .94, h * .77)
        ..lineTo(w * .08, h * .77)
        ..close();
    }

    final glow = Paint()
      ..color = colors[1].withOpacity(.48)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawPath(body, glow);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.first, colors[1], const Color(0xFF21142E)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(body, paint);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = showcase ? 1.65 : 2.2
      ..color = colors.first.withOpacity(.98);
    canvas.drawPath(body, outline);

    final window = Path();
    if (isRoyal) {
      window
        ..moveTo(w * .38, h * .45)
        ..lineTo(w * .38, h * .32)
        ..quadraticBezierTo(w * .40, h * .25, w * .50, h * .25)
        ..lineTo(w * .60, h * .25)
        ..quadraticBezierTo(w * .69, h * .25, w * .70, h * .34)
        ..lineTo(w * .71, h * .45)
        ..close();
    } else {
      window
        ..moveTo(w * .35, h * .45)
        ..lineTo(w * .43, h * .28)
        ..quadraticBezierTo(w * .45, h * .25, w * .52, h * .25)
        ..lineTo(w * .66, h * .25)
        ..quadraticBezierTo(w * .71, h * .26, w * .75, h * .34)
        ..lineTo(w * .83, h * .45)
        ..close();
    }
    canvas.drawPath(window, Paint()..color = const Color(0xFF101225));
    canvas.drawPath(window, outline);

    final wheelPaint = Paint()..color = const Color(0xFF080912);
    final hubPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(.95), colors.first, colors[2]],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: h * .15));
    for (final x in [w * .28, w * .77]) {
      final center = Offset(x, h * .75);
      canvas.drawCircle(center, h * .18, glow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawCircle(center, h * .17, wheelPaint);
      canvas.drawCircle(center, h * .105, outline);
      canvas.drawCircle(center, h * .08, hubPaint..shader = RadialGradient(
        colors: [Colors.white.withOpacity(.95), colors.first, colors[2]],
      ).createShader(Rect.fromCircle(center: center, radius: h * .10)));
      final spokePaint = Paint()
        ..color = colors.first.withOpacity(.75)
        ..strokeWidth = showcase ? 1 : 1.5;
      for (var spoke = 0; spoke < 6; spoke++) {
        final angle = (math.pi * 2 * spoke / 6) + progress * math.pi * 2;
        canvas.drawLine(
          Offset(center.dx + math.cos(angle) * h * .025, center.dy + math.sin(angle) * h * .025),
          Offset(center.dx + math.cos(angle) * h * .07, center.dy + math.sin(angle) * h * .07),
          spokePaint,
        );
      }
    }

    final headlight = Paint()..color = const Color(0xFFFFF5CF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .89, h * .51, w * .07, h * .07),
        const Radius.circular(5),
      ),
      headlight,
    );
    final trim = Paint()
      ..color = colors.first.withOpacity(.95)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = showcase ? 1.8 : 2.3;

    final sideFlare = Path()
      ..moveTo(w * .13, h * .61)
      ..quadraticBezierTo(w * .5, h * (.55 - .015 * math.sin(progress * math.pi * 2)), w * .91, h * .61);
    canvas.drawPath(sideFlare, trim);

    if (isPhoenix) {
      // Feather/flame fins and a trailing ember plume distinguish the phoenix
      // vehicle at every size without any external animation dependency.
      final wing = Path()
        ..moveTo(w * .18, h * .55)
        ..quadraticBezierTo(w * .02, h * .39, w * .13, h * .31)
        ..lineTo(w * .22, h * .42)
        ..lineTo(w * .28, h * .34)
        ..lineTo(w * .31, h * .48)
        ..moveTo(w * .16, h * .55)
        ..quadraticBezierTo(w * .04, h * .49, w * .06, h * .43);
      canvas.drawPath(wing, trim);
      final flame = Paint()
        ..color = colors[1].withOpacity(.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      for (var i = 0; i < 4; i++) {
        final baseX = w * (.08 - i * .015);
        final flicker = math.sin((progress * math.pi * 2) + i) * h * .025;
        final flamePath = Path()
          ..moveTo(baseX, h * (.60 + i * .035))
          ..quadraticBezierTo(baseX - w * .07, h * (.49 + i * .035) + flicker, baseX - w * .12, h * (.54 + i * .035))
          ..quadraticBezierTo(baseX - w * .06, h * (.62 + i * .035), baseX, h * (.65 + i * .035))
          ..close();
        canvas.drawPath(flamePath, flame);
      }
    }

    if (isRoyal || isKing || level >= 16) {
      final crown = Path()
        ..moveTo(w * .46, h * .18)
        ..lineTo(w * .48, h * .075)
        ..lineTo(w * .54, h * .145)
        ..lineTo(w * .59, h * .055)
        ..lineTo(w * .64, h * .18)
        ..close();
      canvas.drawPath(crown, Paint()..color = colors.first);
      canvas.drawPath(crown, trim);
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(w * (.49 + i * .065), h * (.13 + (i == 1 ? -.018 : .005))),
          h * .012,
          Paint()..color = Colors.white.withOpacity(.9),
        );
      }
    }

    if (isNeon) {
      final orbit = Paint()
        ..color = colors.first.withOpacity(.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = showcase ? 1.2 : 1.8;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * .53, h * .54),
          width: w * (.83 + .035 * math.sin(progress * math.pi * 2)),
          height: h * .52,
        ),
        orbit,
      );
    }
    if (level >= 16 || isKing) {
      final wing = Path()
        ..moveTo(w * .18, h * .48)
        ..lineTo(w * .21, h * .35)
        ..lineTo(w * .32, h * .43)
        ..moveTo(w * .14, h * .48)
        ..lineTo(w * .27, h * .47);
      canvas.drawPath(wing, trim);
    }

    final beam = Paint()..color = colors.first.withOpacity(.20);
    final beamPath = Path()
      ..moveTo(w * .94, h * .53)
      ..lineTo(w, h * .35)
      ..lineTo(w, h * .69)
      ..close();
    canvas.drawPath(beamPath, beam);
    final underglow = Paint()
      ..color = colors[1].withOpacity(.55 + .25 * math.sin(progress * math.pi * 8))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * .53, h * .84),
        width: w * (.66 + .025 * math.sin(progress * math.pi * 2)),
        height: h * .1,
      ),
      underglow,
    );

    // A few tiny glints animate around the vehicle's silhouette.
    final sparkle = Paint();
    for (var i = 0; i < 12; i++) {
      final phase = (progress + i / 12) % 1;
      final x = w * (.08 + ((i * .173 + phase * .20) % .84));
      final y = h * (.22 + ((i * .317 + phase * .27) % .57));
      sparkle.color = colors[i % colors.length].withOpacity(.18 + .55 * math.sin(phase * math.pi));
      final radius = (showcase ? 1.0 : 1.4) + (i % 3) * .6;
      canvas.drawCircle(Offset(x, y), radius, sparkle);
    }
  }

  @override
  bool shouldRepaint(covariant _EntryVehiclePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.level != level ||
      oldDelegate.styleId != styleId ||
      oldDelegate.showcase != showcase;
}
