import 'package:flutter/material.dart';

import '../vip/vip_visual_assets.dart';

/// Golden VIP tag image for a VIP level (VIP1-18).
///
/// The tag is a pure level badge — it is never equipped or bought. It sits
/// next to the VIP level text (room chat sender name, profile VIP badge,
/// room profile card ID row) and sizes itself from that text: height =
/// [fontSize] x 1.5 (default fontSize 12 -> 18 px tall), width from the
/// image's own aspect ratio. No fixed size per place — pass the
/// neighbouring text's font size and the tag follows it. Out of range
/// (VIP 0) renders nothing.
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
    final String? url = vipTagUrlForVipLevel(vipLevel);
    if (url == null) return const SizedBox.shrink();
    final double height = (fontSize ?? 12) * 1.5;
    return Image.network(
      url,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
