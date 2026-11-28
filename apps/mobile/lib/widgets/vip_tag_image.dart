import 'package:material_ui/material_ui.dart';

/// Golden "VIP N" text for a VIP level (VIP1-18) — no ribbon, no plaque
/// (Vinay, 2026-11-23: "VIP gold me likha dikhna chahiye, ribbon tag nhi").
/// The old R2 plaque image (vip-tags/vip<N>-tag.png, a gold oval with the
/// level animal + a gem) is what made the tag look like a ribbon, so the
/// widget no longer loads it: the level now shows as metallic-gold text,
/// sized from the neighbouring text via [fontSize] (default 12). Out of
/// range (VIP 0) renders nothing.
class VipTagImage extends StatelessWidget {
  const VipTagImage({
    super.key,
    required this.vipLevel,
    this.fontSize,
  });

  final int vipLevel;

  /// Font size of the VIP level text this tag sits next to.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    if (vipLevel < 1 || vipLevel > 18) return const SizedBox.shrink();
    return ShaderMask(
      shaderCallback: (Rect bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFFFFE9A8),
          Color(0xFFD09A0A),
          Color(0xFFFFF3C4),
        ],
        stops: <double>[0, 0.55, 1],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        'VIP $vipLevel',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}
