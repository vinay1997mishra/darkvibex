// DarkVibeX — role tags on the ID (Coin Seller, CS, CS Leader, Merchant,
// Admin, Official).
//
// Pure Dart (no Flutter import): role -> R2 URL mapping for the six
// transparent role-tag PNGs (tags/role-<slug>.png, 120px tall at 3x,
// 3D treatment: drop shadow, top gloss, bevel, real-metal colours).
//
// HIDDEN (Vinay, 2026-11-23 03:24 IST: "Laga de app me lekin dikhna nhi
// chahiye"): the tags are wired into the app (own profile, room profile
// card, room chat sender) but [kRoleTagsVisible] is false, so
// [RoleTagImage] renders nothing anywhere. Flip it to true when Vinay
// says the tags should show.
//
// Role mapping: users.role values 'coin_seller' and 'merchant' exist in
// the DB today; 'platform_owner' is mapped to Official (Vinay to
// confirm — Official has no explicit role in code). 'admin',
// 'customer_service' and 'cs_leader' have NO users.role value yet
// (staff roles live in the staff table with no app-user mapping — the
// PR #205 F3 decision), so those three tags stay dormant until such a
// role exists. The mapping is written anyway so the tags light up the
// moment the role does.

import 'vip_visual_assets.dart';

/// Role tags are in the app but hidden — see the header comment.
const bool kRoleTagsVisible = false;

/// Direct R2 URL of the role tag for [role], or null when the role has
/// no tag. Case/whitespace tolerant; null/empty/unknown -> null.
String? roleTagUrlForRole(String? role) {
  final key = role?.trim().toLowerCase() ?? '';
  const Map<String, String> slugs = <String, String>{
    'coin_seller': 'coin-seller',
    'merchant': 'merchant',
    'platform_owner': 'official',
    'admin': 'admin',
    'customer_service': 'cs',
    'cs': 'cs',
    'cs_leader': 'cs-leader',
  };
  final slug = slugs[key];
  if (slug == null) return null;
  return '$kVipVisualR2PublicBaseUrl/tags/role-$slug.png';
}
