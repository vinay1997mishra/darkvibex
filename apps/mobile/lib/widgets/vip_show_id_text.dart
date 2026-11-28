import 'package:material_ui/material_ui.dart';

import '../vip/vip_policy.dart';

/// A user ID rendered with the Show-ID skin (VIP privilege 'show_id',
/// VIP5+): the ID number shows in the level's VIP colour, bold, instead
/// of the plain muted colour. VIP15-18 keep the VIP14 style
/// (VipPolicy.showIdStyleLevel clamps to 14). Below VIP5 the ID renders
/// with [style] unchanged. Callers pass 0 for [vipLevel] when the VIP
/// is not active.
class VipShowIdText extends StatelessWidget {
  const VipShowIdText({
    super.key,
    required this.text,
    required this.vipLevel,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final int vipLevel;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    if (vipLevel < 5) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }
    final int styleLevel = VipPolicy.showIdStyleLevel(vipLevel);
    final Color? colour = VipPolicy.nameColourForLevel(styleLevel);
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      style: style.copyWith(
        color: colour ?? const Color(0xFFFFD700),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
