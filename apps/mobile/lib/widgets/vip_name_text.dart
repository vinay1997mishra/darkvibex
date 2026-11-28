import 'package:material_ui/material_ui.dart';

import '../vip/vip_policy.dart';

/// A display name painted in the owner's active VIP colour (Vinay,
/// 2026-11-20): VIP5-18 get their level colour, VIP18 gets the
/// gold-to-red gradient, below VIP5 the name keeps [style] as given.
/// Callers pass 0 for [vipLevel] when the VIP is not active.
class VipNameText extends StatelessWidget {
  const VipNameText({
    super.key,
    required this.name,
    required this.vipLevel,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.textKey,
  });

  final String name;
  final int vipLevel;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final gradient = VipPolicy.nameGradientForLevel(vipLevel);
    if (gradient != null) {
      // Gradient text (VIP18): paint the gradient through the glyphs
      // like the metallic-gold VIP N hero text. Shadows are dropped —
      // the shader would tint them and they read as a glow, not a
      // readable shadow.
      return ShaderMask(
        shaderCallback: (Rect bounds) =>
            LinearGradient(colors: gradient).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Text(
          name,
          key: textKey,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: style.copyWith(
            color: Colors.white,
            shadows: const <Shadow>[],
          ),
        ),
      );
    }
    final colour = VipPolicy.nameColourForLevel(vipLevel);
    if (colour == null) {
      return Text(
        name,
        key: textKey,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        style: style,
      );
    }
    // Nickname Light Effect (VIP8-17): a soft glow in the level's own
    // colour, layered under any readability shadow the caller passed.
    // VIP18 keeps the gradient branch above (no glow — the shader would
    // tint it); below VIP8 there is no light effect.
    final bool lightEffect = vipLevel >= 8 && vipLevel <= 17;
    return Text(
      name,
      key: textKey,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      style: style.copyWith(
        color: colour,
        shadows: lightEffect
            ? <Shadow>[
                ...?style.shadows,
                Shadow(color: colour, blurRadius: 10),
              ]
            : style.shadows,
      ),
    );
  }
}
