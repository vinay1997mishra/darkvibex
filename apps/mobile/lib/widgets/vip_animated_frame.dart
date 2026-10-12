import 'package:flutter/material.dart';

class VipAnimatedFrame extends StatefulWidget {
  const VipAnimatedFrame({
    super.key,
    required this.size,
    required this.child,
    this.enabled = true,
  });

  final double size;
  final Widget child;
  final bool enabled;

  @override
  State<VipAnimatedFrame> createState() => _VipAnimatedFrameState();
}

class _VipAnimatedFrameState extends State<VipAnimatedFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
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
          child: Padding(padding: const EdgeInsets.all(4), child: widget.child),
          builder: (context, child) => CustomPaint(
            painter: widget.enabled ? _VipRingPainter(_controller.value) : null,
            child: child,
          ),
        ),
      );
}

class _VipRingPainter extends CustomPainter {
  const _VipRingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        transform: GradientRotation(progress * 6.283185307179586),
        colors: const [
          Color(0x00FFD36A),
          Color(0xFFFFD36A),
          Color(0xFF9C7BFF),
          Color(0xFF55D9FF),
          Color(0x00FFD36A),
        ],
        stops: const [0, .2, .48, .76, 1],
      ).createShader(rect);
    canvas.drawCircle(rect.center, size.shortestSide / 2 - 2, paint);
  }

  @override
  bool shouldRepaint(covariant _VipRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
