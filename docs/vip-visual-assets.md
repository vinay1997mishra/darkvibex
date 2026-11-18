# VIP Visual Assets — Frames, Entry Effects, Tags (R2 wiring)

All three sets are hosted on Cloudflare R2 (bucket `darkvibex-files`,
public base `https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev`) and
wired into the app by level. VIP1-4 have no animal visuals.

## Level → asset mapping (VIP5-18)

| Level | Animal | Frame WebM | Frame still (PNG) | Entry banner | Tag |
|---|---|---|---|---|---|
| 5 | Deer | `frames/vip5-deer-transparent.webm` | `frames/vip5-deer-transparent.png` | `entry-effects/vip5-entry.png` | `vip-tags/vip5-tag.png` |
| 6 | Wolf | `frames/vip6-wolf-transparent.webm` | `frames/vip6-wolf-transparent.png` | `entry-effects/vip6-entry.png` | `vip-tags/vip6-tag.png` |
| 7 | Eagle | `frames/vip7-eagle-transparent.webm` | `frames/vip7-eagle-transparent.png` | `entry-effects/vip7-entry.png` | `vip-tags/vip7-tag.png` |
| 8 | Panther | `frames/vip8-panther-transparent.webm` | `frames/vip8-panther-transparent.png` | `entry-effects/vip8-entry.png` | `vip-tags/vip8-tag.png` |
| 9 | Cobra | `frames/vip9-cobra-transparent.webm` | `frames/vip9-cobra-transparent.png` | `entry-effects/vip9-entry.png` | `vip-tags/vip9-tag.png` |
| 10 | Lion | `frames/vip10-lion-transparent.webm` | `frames/vip10-lion-transparent.png` | `entry-effects/vip10-entry.png` | `vip-tags/vip10-tag.png` |
| 11 | Tiger | `frames/vip11-tiger-transparent.webm` | `frames/vip11-tiger-transparent.png` | `entry-effects/vip11-entry.png` | `vip-tags/vip11-tag.png` |
| 12 | Mammoth | `frames/vip12-mammoth-transparent.webm` | `frames/vip12-mammoth-transparent.png` | `entry-effects/vip12-entry.png` | `vip-tags/vip12-tag.png` |
| 13 | Gorilla | `frames/vip13-gorilla-transparent.webm` | `frames/vip13-gorilla-transparent.png` | `entry-effects/vip13-entry.png` | `vip-tags/vip13-tag.png` |
| 14 | Bear | `frames/vip14-bear-transparent.webm` | `frames/vip14-bear-transparent.png` | `entry-effects/vip14-entry.png` | `vip-tags/vip14-tag.png` |
| 15 | Kraken | `frames/vip15-kraken-transparent.webm` | `frames/vip15-kraken-transparent.png` | `entry-effects/vip15-entry.png` | `vip-tags/vip15-tag.png` |
| 16 | Leviathan | `frames/vip16-leviathan-transparent.webm` | `frames/vip16-leviathan-transparent.png` | `entry-effects/vip16-entry.png` | `vip-tags/vip16-tag.png` |
| 17 | Phoenix | `frames/vip17-phoenix-transparent.webm` | `frames/vip17-phoenix-transparent.png` | `entry-effects/vip17-entry.png` | `vip-tags/vip17-tag.png` |
| 18 | Dragon | `frames/vip18-dragon-transparent.webm` | `frames/vip18-dragon-transparent.png` | `entry-effects/vip18-entry.png` | `vip-tags/vip18-tag.png` |

Full URL = public base + `/` + key. The WebMs are on R2 (14 objects);
the entry banners are on R2 (14 objects); the tags are on R2
(14 objects). The PNG frame stills are NOT on R2 yet — see below.

## Where each set shows

- **Frames** — on every avatar: room seat, seat profile sheet, room
  member list, own profile DP, room chat sender avatar. The frame is the
  member's equipped custom frame when one is set, else the Owner's
  `vip_rule` frame, else the level's animal frame.
- **Entry banners** — top banner of the room arrival overlay (VIP5-18),
  next to the vehicle video at the bottom. The arriving user's DP is
  composited into the banner's transparent circle (per-level measured
  geometry in `vip_visual_assets.dart`).
- **Tags** — next to the VIP level text: room chat sender name and the
  profile VIP badge. Pure level badge, never equipped.

## Direct R2 URLs — never through the Worker

The Worker's `GET /api/files` allowlist is only
`users|rooms|messages|custom-gifts|room-themes|banners|custom-assets|creator-assets`
— `frames/`, `entry-effects/`, `vip-tags/` and `vehicles/` return 400
`invalid_file_key`. So the app must NEVER pass those keys through
`backend.fileUrl()`. Use `resolveVipVisualAssetUrl(key, backend.fileUrl)`
(`apps/mobile/lib/vip/vip_visual_assets.dart`): direct R2 URL for those
prefixes (and for full http(s) URLs), `fileUrl()` for everything else
(user avatars, custom uploads).

## WebM alpha — finding and recommendation

The frame WebMs are VP9 **with an alpha channel** (transparency so the
DP shows through the centre). Flutter's `video_player` (^2.10.1,
ExoPlayer on Android) renders video to an **opaque texture** — it does
not carry the alpha channel, so a transparent WebM played through it
shows a **black box**, not transparency. The app has no SVGA, Lottie or
VAP player, and its existing video path (`CustomAssetEffectPlayback`)
has no alpha handling anywhere. The ecosystem confirms this: alpha
video in Flutter needs a dedicated alpha-video player (e.g. Tencent
VAP via `flutter_vap_player`), which is why that package exists.

**Recommendation (implemented): display the transparent PNG still**
through the existing frame image path (`VipAnimatedFrame.assetUrl` →
`TransparentArtworkImage`, which renders PNG alpha natively and
validates the transparent centre). The WebM URL helpers
(`vipFrameVideoUrlForVipLevel` / `frameVideoUrlForVipLevel`) are kept
so a future alpha-capable player can pick the animated version up
without a catalog change. Do NOT wire the WebM through `video_player`
expecting transparency.

**Pending Vinay's go-ahead:** upload the 14 transparent PNG stills to
R2 under `frames/vip<N>-<animal>-transparent.png` (Content-Type
`image/png`). They already exist locally in
`~/workspace/darkvibex-vip-section/final-frames/`. Until they are on R2,
the frame still URLs 404 and `VipAnimatedFrame` falls back to its
painted ring — the wiring is in place, the images are not.

## Automatic sizing (Vinay, 2026-11-18)

Frames and tags scale automatically with the seat/DP/chat avatar —
never a fixed size per place, and the caller never passes a manual size
per seat:

- `VipAnimatedFrame.auto` reads the size at runtime: tight parent
  constraints first (seat diameter container, 28px chat avatar box,
  profile sheet box), otherwise it measures its child avatar once
  (GlobalKey + post-frame) — e.g. `ListTile.leading` and `Row` give
  loose constraints. Ring, gems, animal head and VIP plate scale
  proportionally (all painters/clippers use fractions of the size).
  The same frame code works on a big host seat, a small guest seat, a
  room-list avatar, a profile DP and a chat avatar.
- Tags size from the neighbouring text (`VipTagImage`, height =
  fontSize x 1.5).
- Entry banners size to the room width (per-level aspect ratio +
  DP-circle geometry measured from the PNGs).

## Files

Worker: `apps/worker/src/vip_frame_catalog.js`,
`apps/worker/src/vip_entry_effect_catalog.js`,
`apps/worker/src/vip_tag_catalog.js` (new; each mirrors
`vehicle_entry_animals.js` and is NOT part of `COSMETIC_CATALOG` —
the cosmetics test pins frames at 29), `apps/worker/src/index.js`
(`vipVisualsForLevel` animal fallbacks + `vip_tag`, member block copies
`active_entry_asset_key` / `active_vip_tag_id` /
`active_vip_tag_asset_key`), `apps/worker/test/vip_visual_assets.test.js`.

Dart: `apps/mobile/lib/vip/vip_visual_assets.dart` (pure-Dart catalogs +
resolver), `apps/mobile/lib/widgets/vip_tag_image.dart`,
`apps/mobile/lib/widgets/vip_entry_effect_banner.dart` (new),
`apps/mobile/lib/widgets/vip_animated_frame.dart` (`.auto`),
`apps/mobile/lib/widgets/room_chat_sender_header.dart` (frame + tag),
`apps/mobile/lib/screens/room_screen.dart` (seat/sheet/list `.auto`,
chat header, arrival banner),
`apps/mobile/lib/screens/profile_screen.dart` (`.auto` + tag),
`apps/mobile/test/vip_visual_assets_test.dart`.

Dart is not compiled in this environment — compile in the real Flutter
project before release.
