import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant VipAnimatedFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
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
          child: Padding(padding: const EdgeInsets.all(7), child: widget.child),
          builder: (context, child) => CustomPaint(
            painter: widget.enabled
                ? _VipRingPainter(_controller.value, widget.level, widget.styleId)
                : null,
            child: child,
          ),
        ),
      );
}

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
    final tier = switch (styleId) {
      'frame_royal' => const [Color(0xFFFFE49B), Color(0xFFCC542E), Color(0xFFFFC95C)],
      'frame_sapphire' => const [Color(0xFFB8F4FF), Color(0xFF397BFF), Color(0xFF62D9FF)],
      'frame_phoenix' => const [Color(0xFFFFD37A), Color(0xFFE33F65), Color(0xFFFF8B40)],
      'frame_king' => const [Color(0xFFFFF0A6), Color(0xFFFF9F24), Color(0xFFDB62FF)],
      _ => level >= 18
        ? const [Color(0xFFFFF2B0), Color(0xFFFFA52E), Color(0xFFFFE59A)]
        : level >= 12
            ? const [Color(0xFFFFE8A3), Color(0xFFB87333), Color(0xFFFFD36A)]
            : const [Color(0xFFB8A1FF), Color(0xFF55D9FF), Color(0xFFFFD36A)],
    };

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = tier.first.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius - 1, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          tier.first.withValues(alpha: .18),
          tier.first,
          tier[1],
          tier.last,
          tier.first.withValues(alpha: .18),
        ],
        stops: const [0, .22, .5, .78, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius - 2, ring);

    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = tier.first.withValues(alpha: .9);
    canvas.drawCircle(center, radius - 5, detail);

    // Jewel points and tiny crown-like flares make the ring read as a frame.
    final jewelPaint = Paint()..color = tier.first;
    final jewelCount = level >= 18 ? 12 : level >= 12 ? 8 : 4;
    final jewelRadius = level >= 18 ? 2.1 : 1.7;
    for (var i = 0; i < jewelCount; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / jewelCount) +
          (progress * math.pi * 2);
      final point = Offset(
        center.dx + math.cos(angle) * (radius - 3),
        center.dy + math.sin(angle) * (radius - 3),
      );
      canvas.drawCircle(point, jewelRadius, jewelPaint);
      if (level >= 12 && i % 2 == 0) {
        final sparkle = Path()
          ..moveTo(point.dx, point.dy - 4)
          ..lineTo(point.dx + 1, point.dy - 1)
          ..lineTo(point.dx + 4, point.dy)
          ..lineTo(point.dx + 1, point.dy + 1)
          ..lineTo(point.dx, point.dy + 4)
          ..lineTo(point.dx - 1, point.dy + 1)
          ..lineTo(point.dx - 4, point.dy)
          ..lineTo(point.dx - 1, point.dy - 1)
          ..close();
        canvas.drawPath(sparkle, jewelPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VipRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.level != level || oldDelegate.styleId != styleId;
}
