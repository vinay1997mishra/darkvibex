import 'package:flutter/material.dart';

import '../vip/role_tag_assets.dart';

/// Role tag image for a user role (Coin Seller, CS, CS Leader, Merchant,
/// Admin, Official).
///
/// Sits next to the name/ID the way the golden VIP tag does: height =
/// [fontSize] x 1.5 (default fontSize 12 -> 18 px tall), width from the
/// image's own aspect ratio. No fixed size per place — pass the
/// neighbouring text's font size and the tag follows it. Renders nothing
/// while [kRoleTagsVisible] is false (Vinay: in the app but hidden) or
/// when the role has no tag.
class RoleTagImage extends StatelessWidget {
  const RoleTagImage({
    super.key,
    required this.role,
    this.fontSize,
  });

  /// The user's role string (users.role), e.g. 'coin_seller'.
  final String? role;

  /// Font size of the text this tag sits next to.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    if (!kRoleTagsVisible) return const SizedBox.shrink();
    final String? url = roleTagUrlForRole(role);
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
