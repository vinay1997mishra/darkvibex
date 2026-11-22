import 'package:flutter/material.dart';

import '../vip/role_tag_assets.dart';

/// Role tag image for the tag the owner assigned to an ID (Coin Seller,
/// CS, CS Leader, Merchant, Admin, Official).
///
/// Sits next to the name/ID the way the golden VIP tag does: height =
/// [fontSize] x 1.5 (default fontSize 12 -> 18 px tall), width from the
/// image's own aspect ratio. No fixed size per place — pass the
/// neighbouring text's font size and the tag follows it. Renders nothing
/// when no tag is assigned to this ID.
class RoleTagImage extends StatelessWidget {
  const RoleTagImage({
    super.key,
    required this.roleTag,
    this.fontSize,
  });

  /// The owner-assigned role-tag slug, e.g. 'coin-seller' (from the
  /// `role_tag` field the worker serves on room messages / profile).
  final String? roleTag;

  /// Font size of the text this tag sits next to.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final String? url = roleTagUrlForSlug(roleTag);
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
