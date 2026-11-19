# DarkVibeX premium medal collection

This collection contains **18 individual transparent SVG assets** (VIP 1–18). Each file has its own silhouette, tier palette, metal treatment and decorative motif. The assets remain separate and scalable rather than being flattened into a contact sheet.

## Rocket medals (Rocket 1–18)

Rocket medals are **premium medal PNGs on R2**, not bundled SVGs: `rocket-medals/rocket-medal-lvNN.png` (512px, transparent). Each is a gold medallion built from Vinay's rocket for that level — colour-matched frame per rocket, gold "LV.N" ribbon. The `lib/widgets/level_medal.dart` widget loads them direct from R2 (`rocketMedalUrlForLevel` in `lib/vip/vip_visual_assets.dart`); the bundled `rocket_01.svg` … `rocket_12.svg` files below remain only as an offline fallback for levels 1–12.

## Integration
- `vip_01.svg` … `vip_18.svg`: VIP level medals.
- `rocket_01.svg` … `rocket_12.svg`: rocket level badges (offline fallback only).
- `lib/widgets/level_medal.dart`: reusable Flutter widget with a restrained glow/pulse and rocket tilt.
- `lib/screens/medal_gallery_screen.dart`: in-app gallery with VIP and Rocket tabs (Rocket 1–18).

Open **VIP → VIP & Rocket Medal Collection** to preview both sets. The VIP overview uses the current VIP level medal. Rocket badges are available in the gallery as visual assets; this change does not attach them to a live gifting/reward rule.

The assets work with the existing `flutter_svg` dependency. Animation is rendered in Flutter, so no remote service, video download or GIF playback is needed. These are custom vector illustrations and code-based ambient animations, not photorealistic AI-generated 3D bitmaps.
