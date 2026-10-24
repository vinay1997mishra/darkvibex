# DarkVibeX premium medal collection

This collection contains **30 individual transparent SVG assets**: VIP 1–18 and Rocket 1–12. Each file has its own silhouette, tier palette, metal treatment and decorative motif. The assets remain separate and scalable rather than being flattened into a contact sheet.

## Integration
- `vip_01.svg` … `vip_18.svg`: VIP level medals.
- `rocket_01.svg` … `rocket_12.svg`: rocket level badges.
- `lib/widgets/level_medal.dart`: reusable Flutter widget with a restrained glow/pulse and rocket tilt.
- `lib/screens/medal_gallery_screen.dart`: in-app gallery with VIP and Rocket tabs.

Open **VIP → VIP & Rocket Medal Collection** to preview both sets. The VIP overview uses the current VIP level medal. Rocket badges are available in the gallery as visual assets; this change does not attach them to a live gifting/reward rule.

The assets work with the existing `flutter_svg` dependency. Animation is rendered in Flutter, so no remote service, video download or GIF playback is needed. These are custom vector illustrations and code-based ambient animations, not photorealistic AI-generated 3D bitmaps.
