// DarkVibeX — role tags on the ID (Coin Seller, CS, CS Leader, Merchant,
// Admin, Official).
//
// Pure Dart (no Flutter import): owner-assigned tag slug -> R2 URL mapping
// for the six transparent role-tag PNGs (tags/role-<slug>.png, 120px tall
// at 3x, 3D treatment: drop shadow, top gloss, bevel, real-metal colours).
//
// Owner-panel activation (Vinay, 2026-11-23): a tag shows ONLY when the
// owner activates it for an ID in the Owner Panel (ID box + tag option +
// Apply) — the worker stores one tag per user in owner_user_tags
// (kind 'role_tag') and serves it as `role_tag` on room messages and the
// profile endpoint. There is no visibility flag any more: an assigned
// tag IS visible, an unassigned ID shows nothing. The old custom /
// V Official text tags are gone entirely.
import 'vip_visual_assets.dart';

/// The six role-tag slugs the Owner Panel can assign.
const List<String> kRoleTagSlugs = <String>[
  'coin-seller',
  'cs',
  'cs-leader',
  'merchant',
  'admin',
  'official',
];

/// Display label per role-tag slug.
const Map<String, String> kRoleTagLabels = <String, String>{
  'coin-seller': 'Coin Seller',
  'cs': 'CS',
  'cs-leader': 'CS Leader',
  'merchant': 'Merchant',
  'admin': 'Admin',
  'official': 'Official',
};

/// Direct R2 URL of the role tag for [slug], or null when the slug is not
/// one of the six. Case/whitespace tolerant; null/empty/unknown -> null.
String? roleTagUrlForSlug(String? slug) {
  final key = slug?.trim().toLowerCase() ?? '';
  if (!kRoleTagSlugs.contains(key)) return null;
  return '$kVipVisualR2PublicBaseUrl/tags/role-$key.png';
}
