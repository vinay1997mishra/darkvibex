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
    this.showVehicle = true,
  });

  final String displayName;
  final int level;
  final bool customVehicle;
  final String? vehicleLabel;
  final bool showVehicle;

  @override
  State<VehicleEntryEffect> createState() => _VehicleEntryEffectState();
}

class VehicleShowcase extends StatelessWidget {
  const VehicleShowcase({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final colors = level >= 18
        ? const [Color(0xFFFFE8A3), Color(0xFFFF922E), Color(0xFFFF3E84)]
        : level >= 16
            ? const [Color(0xFFFFE8A3), Color(0xFFEC4B69), Color(0xFFFF8E40)]
            : level >= 12
            ? const [Color(0xFFFFE8A3), Color(0xFFFFB52E), Color(0xFFB675FF)]
            : const [Color(0xFFBFA7FF), Color(0xFF53D9FF), Color(0xFFFFD36A)];
    return SizedBox.expand(child: CustomPaint(painter: _EntryVehiclePainter(.2, colors, level)));
  }
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
    final colors = widget.level >= 18
        ? const [Color(0xFFFFE8A3), Color(0xFFFF922E), Color(0xFFFF3E84)]
        : widget.level >= 16
            ? const [Color(0xFFFFE8A3), Color(0xFFEC4B69), Color(0xFFFF8E40)]
            : widget.level >= 12
            ? const [Color(0xFFFFE8A3), Color(0xFFFFB52E), Color(0xFFB675FF)]
            : const [Color(0xFFBFA7FF), Color(0xFF53D9FF), Color(0xFFFFD36A)];
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
                          painter: _EntryVehiclePainter(t, colors, widget.level),
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
  const _EntryVehiclePainter(this.progress, this.colors, this.level);
  final double progress;
  final List<Color> colors;
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Path()
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
    final glow = Paint()
      ..color = colors[1].withOpacity(.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawPath(body, glow);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.first, colors[1], const Color(0xFF261832)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(body, paint);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colors.first.withOpacity(.95);
    canvas.drawPath(body, outline);

    final window = Path()
      ..moveTo(w * .35, h * .45)
      ..lineTo(w * .43, h * .28)
      ..quadraticBezierTo(w * .45, h * .25, w * .52, h * .25)
      ..lineTo(w * .66, h * .25)
      ..quadraticBezierTo(w * .71, h * .26, w * .75, h * .34)
      ..lineTo(w * .83, h * .45)
      ..close();
    canvas.drawPath(window, Paint()..color = const Color(0xFF101225));
    canvas.drawPath(window, outline);

    final wheelPaint = Paint()..color = const Color(0xFF090A12);
    final hubPaint = Paint()..color = colors.first;
    for (final x in [w * .28, w * .77]) {
      canvas.drawCircle(Offset(x, h * .75), h * .17, wheelPaint);
      canvas.drawCircle(Offset(x, h * .75), h * .08, hubPaint);
    }
    final headlight = Paint()..color = const Color(0xFFFFF5CF);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .89, h * .51, w * .07, h * .07), const Radius.circular(5)), headlight);
    final trim = Paint()
      ..color = colors.first.withOpacity(.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    if (level >= 12) {
      final sideFlare = Path()
        ..moveTo(w * .13, h * .61)
        ..quadraticBezierTo(w * .5, h * .55, w * .91, h * .61);
      canvas.drawPath(sideFlare, trim);
    }
    if (level >= 16) {
      final wing = Path()
        ..moveTo(w * .18, h * .48)
        ..lineTo(w * .21, h * .35)
        ..lineTo(w * .32, h * .43)
        ..moveTo(w * .14, h * .48)
        ..lineTo(w * .27, h * .47);
      canvas.drawPath(wing, trim);
    }
    if (level >= 18) {
      final crown = Path()
        ..moveTo(w * .47, h * .18)
        ..lineTo(w * .49, h * .08)
        ..lineTo(w * .54, h * .15)
        ..lineTo(w * .58, h * .06)
        ..lineTo(w * .62, h * .18)
        ..close();
      canvas.drawPath(crown, Paint()..color = colors.first);
      canvas.drawPath(crown, trim);
    }
    final beam = Paint()..color = colors.first.withOpacity(.16);
    final beamPath = Path()
      ..moveTo(w * .94, h * .53)
      ..lineTo(w, h * .35)
      ..lineTo(w, h * .69)
      ..close();
    canvas.drawPath(beamPath, beam);
    final underglow = Paint()
      ..color = colors[1].withOpacity(.55 + .25 * math.sin(progress * math.pi * 8))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * .53, h * .84), width: w * .66, height: h * .1), underglow);
  }

  @override
  bool shouldRepaint(covariant _EntryVehiclePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors || oldDelegate.level != level;
}
