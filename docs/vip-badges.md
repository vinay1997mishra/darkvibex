# VIP Badge Videos

One premium 3D animated VIP level badge per level (VIP1–18): a shield
with the level animal, wings, and a gold "VIP N" banner on a pedestal,
each level's own colour and superpower.

## Sources (Vinay, 2026-11-19)

- **11 videos are Vinay's own uploads** — VIP5 Deer, VIP6 Wolf,
  VIP8 Panther, VIP9 Cobra, VIP10 Lion, VIP11 Tiger, VIP13 Gorilla,
  VIP15 Kraken, VIP16 Leviathan, VIP17 Phoenix (gold fire), VIP18
  Dragon. Portrait (720×1260 or 720×1080), 5.184 s each, except
  VIP17 gold at 10.144 s.
- **7 videos were made by Ghost** in the same style — VIP1 Cat, VIP2
  Swan, VIP3 Dolphin, VIP4 Fox, VIP7 Eagle, VIP12 Mammoth, VIP14
  Bear. Landscape 1280×720, 10.000 s each.

## VIP17 purple variant

Vinay asked for the VIP17 phoenix in purple ("17 ye hai isko purple
colour ka bana de"). The purple phoenix
(`vip-badges/vip17-phoenix-purple.mp4`, 10.000 s) is a **separate
variant** of the VIP17 entry (`variant_video_key` /
`variant_animation_ms`). The **gold phoenix stays the canonical
VIP17 badge** — the purple one is never the default.

## Placement (Vinay, 2026-11-19)

- **VIP page hero card:** the badge video plays on the **right side**,
  next to the "VIP N" text + EXP, **big (~150px)** — it replaces the
  86px LevelMedal slot. Text stays left, badge video right. It is
  NOT a full-width background hero. The big "VIP N" text is metallic
  gold (a real gold gradient, not flat yellow).
- **Medal Gallery:** tapping a VIP medal tile opens a dialog that
  plays that level's badge video once. **No autoplay in the grid** —
  18 videos must never play at once. Rocket medals have no badge
  video and are not tappable.

## Behaviour

- The video plays **once** (no loop) and ends calmly; on completion
  the widget swaps back to the LevelMedal SVG, so the hero card stays
  visible at rest.
- While the video downloads/initialises, the LevelMedal SVG is shown
  (the poster) — the slot is never an empty box.
- On any video error (bad URL, download failure, decoder failure) it
  swaps back to the LevelMedal SVG. **Never a black box.**
- When there is no video URL at all (out of range, or a custom/Owner
  video key), the LevelMedal SVG is shown directly and no player is
  created.

## R2 keys (bucket `darkvibex-files`, direct public playback)

Videos play **direct from R2**, NOT via the Worker — same decision
as vehicle entry videos. Public base:
`https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev`

| Level | Animal | Video | Duration |
|------:|--------|-------|---------:|
| 1 | cat | `vip-badges/vip1-cat.mp4` | 10.000 s |
| 2 | swan | `vip-badges/vip2-swan.mp4` | 10.000 s |
| 3 | dolphin | `vip-badges/vip3-dolphin.mp4` | 10.000 s |
| 4 | fox | `vip-badges/vip4-fox.mp4` | 10.000 s |
| 5 | deer | `vip-badges/vip5-deer.mp4` | 5.184 s |
| 6 | wolf | `vip-badges/vip6-wolf.mp4` | 5.184 s |
| 7 | eagle | `vip-badges/vip7-eagle.mp4` | 10.000 s |
| 8 | panther | `vip-badges/vip8-panther.mp4` | 5.184 s |
| 9 | cobra | `vip-badges/vip9-cobra.mp4` | 5.184 s |
| 10 | lion | `vip-badges/vip10-lion.mp4` | 5.184 s |
| 11 | tiger | `vip-badges/vip11-tiger.mp4` | 5.184 s |
| 12 | mammoth | `vip-badges/vip12-mammoth.mp4` | 10.000 s |
| 13 | gorilla | `vip-badges/vip13-gorilla.mp4` | 5.184 s |
| 14 | bear | `vip-badges/vip14-bear.mp4` | 10.000 s |
| 15 | kraken | `vip-badges/vip15-kraken.mp4` | 5.184 s |
| 16 | leviathan | `vip-badges/vip16-leviathan.mp4` | 5.184 s |
| 17 | phoenix | `vip-badges/vip17-phoenix.mp4` | 10.144 s |
| 17 | phoenix (purple variant) | `vip-badges/vip17-phoenix-purple.mp4` | 10.000 s |
| 18 | dragon | `vip-badges/vip18-dragon.mp4` | 5.184 s |

## Code

- Worker catalog: `apps/worker/src/vip_badge_catalog.js`
  (`VIP_BADGE_CATALOG`, `vipBadgeForVipLevel`,
  `vipBadgeVisualForVipLevel`, `vipBadgeUrlForVipLevel`,
  `vipBadgeVariantUrlForVipLevel`, `allVipBadgeUrls`). Exposed as
  `vip_badge` in `vipVisualsForLevel()` (`apps/worker/src/index.js`).
- Dart URLs: `apps/mobile/lib/vip/vip_visual_assets.dart`
  (`vipBadgeAnimals`, `vipBadgeVideoKeys`, `vipBadgeAnimationMs`,
  `vipBadgeVideoUrlForVipLevel`, `vipBadgeVariantVideoUrlForVipLevel`,
  `vipBadgeVideoUrlForDisplay`). `vip-badges/` is a direct-R2 prefix
  in `kDirectR2AssetPrefixes`.
- Dart widget: `apps/mobile/lib/widgets/vip_badge_video.dart`
  (`VipBadgeVideo`, `VipBadgeVideo.forVipLevel`).
- Wired into: `apps/mobile/lib/screens/vip_screen.dart` (hero card,
  150px, metallic gold "VIP N") and
  `apps/mobile/lib/screens/medal_gallery_screen.dart` (tap a VIP
  tile → dialog player).

## Tests

- Worker: `apps/worker/test/vip_boosts.test.js` (badge catalog,
  `vip_visuals.vip_badge` via `GET /api/vip/:id`, VIP17 variant).
- Dart: `apps/mobile/test/vip_visual_assets_test.dart` (badge URLs,
  durations, display resolution, variant, direct-R2 prefix).

## New privileges added in the same change (Vinay, 2026-11-19)

The VIP page now shows **only** the privileges the user has at their
level, cumulative (`VipPolicy.unlockedAt(level)` in
`vip_screen.dart`) — higher-level privileges do not appear at all,
not even as locked tiles. The catalog grew from 41 to **55**
entries: `friends_limit` (VIP4) was removed, and 15 new entries were
added — EXP Boost (VIP1 1.1x, VIP5 1.2x, VIP11 1.4x, VIP16 1.5x),
Coins Bonus on purchase (VIP5 +5%, VIP11 +10%, VIP16 +20%), Gift
Discount (VIP8 10%, VIP14 20%, VIP18 30%), Name Colour (VIP5–18),
Daily Rewards (VIP2), Priority Message (VIP9), Anti-Mute (VIP13),
VIP-Only Rooms (VIP10).

**Functional in this change:** EXP boost (worker EXP accrual × level
boost), Coins bonus (added to coins credited on purchase), Gift
discount (reduces the gift coin cost at send time). Helpers:
`expBoostForLevel`, `coinsBonusForLevel`, `coinsBonusForPurchase`,
`giftDiscountForVipLevel`, `applyGiftDiscount` in
`apps/worker/src/vip_policy.js`; mirrored in Dart as
`VipPolicy.expMultiplier`, `coinsBonusRate`, `giftDiscountRate`.

**Display-only in this change:** Name Colour, Daily Rewards,
Priority Message, Anti-Mute, VIP-Only Rooms — they appear in the
catalog and on the VIP page, but have no backend feature behind them
yet. Do not present them as working features.

Unchanged and FINAL: EXP thresholds, 150 EXP per $1 base rate,
expiry/drop rules.
