# DarkVibeX Royal Rocket Collection

The Rocket collection contains **12 separate transparent SVG badges**, Rocket 01–12. Every level has its own silhouette and signature palette, with progressively richer metal gradients, exhaust colours, star flares and orbit accents.

## Visual progression
- **Rocket 01–04 — Launch / Blaze / Comet / Solar:** clean core silhouettes with cool cyan, mint, violet and solar-gold palettes.
- **Rocket 05–08 — Nova / Gold Rush / Tidal / Rose Jet:** brighter neon gradients, extra glints and streaks to make the middle tiers more premium.
- **Rocket 09–10 — Phantom / Inferno:** electric-violet and hot multi-tone flame treatments with additional sparkle details.
- **Rocket 11–12 — Stellar / Orbit King:** prismatic metallic colour, orbital bands and extra luminous highlights for the highest tiers.

## Integration
- `rocket_01.svg` … `rocket_12.svg`: individually scalable rocket-level badges.
- `vip_01.svg` … `vip_18.svg`: VIP-level medals.
- `lib/widgets/level_medal.dart`: reusable animated Flutter badge; rocket stages have tier-specific glows and later tiers have animated orbit rings.
- `lib/screens/medal_gallery_screen.dart`: the in-app Medal Collection gallery.

Rocket artwork is custom vector illustration with lightweight code-based animation. It is not photorealistic 3D rendering or a rendered video; those would require a separate 3D/video asset pipeline. No rocket progression thresholds, gift prices, coin balances, or reward rules are changed by this visual update.
