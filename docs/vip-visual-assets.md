# VIP Visual Assets — Frames, Entry Effects, Tags, Medals, Scenic Banners (R2 wiring)

All sets are hosted on Cloudflare R2 (bucket `darkvibex-files`,
public base `https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev`) and
wired into the app by level. Every VIP level 1-18 now has animal
visuals. Theme map (Vinay, 2026-11-19): VIP1 = black cat, VIP2 = swan,
VIP3 = dolphin, VIP4 = fox.

## Level → asset mapping (VIP1-18)

| Level | Animal | Frame still (PNG) | Frame WebM / VAP | Entry banner | Tag | Medal | Scenic banner |
|---|---|---|---|---|---|---|---|
| 1 | Cat | `frames/vip1-cat-transparent.png` | — (static only) | `entry-effects/vip1-entry.png` | `vip-tags/vip1-tag.png` | `vip-medals/vip1-medal.png` | `profile-banners/vip1-banner.png` |
| 2 | Swan | `frames/vip2-swan-transparent.png` | — (static only) | `entry-effects/vip2-entry.png` | `vip-tags/vip2-tag.png` | `vip-medals/vip2-medal.png` | `profile-banners/vip2-scenic.png` |
| 3 | Dolphin | `frames/vip3-dolphin-transparent.png` | — (static only) | `entry-effects/vip3-entry.png` | `vip-tags/vip3-tag.png` | `vip-medals/vip3-medal.png` | `profile-banners/vip3-scenic.png` |
| 4 | Fox | `frames/vip4-fox-transparent.png` | — (static only) | `entry-effects/vip4-entry.png` | `vip-tags/vip4-tag.png` | `vip-medals/vip4-medal.png` | `profile-banners/vip4-scenic.png` |

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

Full URL = public base + `/` + key. The WebMs are on R2 (14 objects,
VIP5-18); the entry banners are on R2 (18 objects); the tags are on R2
(18 objects); the VAP alpha-videos are on R2 (14 objects under `vap/`,
VIP5-18); the medals are on R2 (4 objects under `vip-medals/`,
VIP1-4); the scenic banners are on R2 (4 objects under
`profile-banners/`, VIP1-4). The PNG frame stills are on R2 (18
objects under `frames/` — 17 correct, plus 1 STALE object:
`frames/vip4-dolphin-transparent.png` is the discarded dolphin VIP4
frame; VIP4 is FOX (`frames/vip4-fox-transparent.png`). No code
references the stale key; delete it from the bucket when convenient.)
**VIP1-4 frames are STATIC PNG stills only** — no WebM, no VAP video
exists for them, so `frameVisualForVipLevel` returns an empty
`video_key`/`vap_key` and `animation_type: ""`, and the app shows the
still only. **VIP3 entry is a full-bleed scene** (only the DP circle
is transparent); **VIP4 entry is the thin slim gold bar** (no text).
The VIP3 entry banner says "VIP ENTRY", not "VIP 3" (generator text).

## Where each set shows

- **Frames** — on every avatar: room seat, seat profile sheet, room
  member list, own profile DP, room chat sender avatar. The frame is the
  member's equipped custom frame when one is set, else the Owner's
  `vip_rule` frame, else the level's animal frame.
- **Entry banners** — top banner of the room arrival overlay (VIP1-18),
  next to the vehicle video at the bottom. The arriving user's DP is
  composited into the banner's transparent circle (per-level measured
  geometry in `vip_visual_assets.dart`).
- **Tags** — next to the VIP level text: room chat sender name and the
  profile VIP badge. Pure level badge, never equipped.
- **Medals** (VIP1-4) — shield medals, wired server-side
  (`vip_medal` in the vip visuals bundle). The app's `LevelMedal`
  widget still shows bundled SVGs; swapping the display to these R2
  PNGs is a follow-up (Vinay's approval).
- **Scenic banners** (VIP1-4) — gold-framed profile/scenic pictures,
  wired server-side (`vip_scenic_banner` in the vip visuals bundle).
  The profile screen is not wired to show them yet (follow-up).

## Direct R2 URLs — never through the Worker

The Worker's `GET /api/files` allowlist is only
`users|rooms|messages|custom-gifts|room-themes|banners|custom-assets|creator-assets`
— `frames/`, `entry-effects/`, `vip-tags/`, `vehicles/` and `vap/`
return 400 `invalid_file_key`. So the app must NEVER pass those keys
through `backend.fileUrl()`. Use `resolveVipVisualAssetUrl(key, backend.fileUrl)`
(`apps/mobile/lib/vip/vip_visual_assets.dart`): direct R2 URL for those
prefixes (and for full http(s) URLs), `fileUrl()` for everything else
(user avatars, custom uploads).

## WebM alpha — finding, and the VAP alpha-video player (implemented)

The frame WebMs are VP9 **with an alpha channel** (transparency so the
DP shows through the centre). Flutter's `video_player` (^2.10.1,
ExoPlayer on Android) renders video to an **opaque texture** — it does
not carry the alpha channel, so a transparent WebM played through it
shows a **black box**, not transparency. The app has no SVGA or Lottie
player, and its existing video path (`CustomAssetEffectPlayback`) has no
alpha handling anywhere. The ecosystem confirms this: alpha video in
Flutter needs a dedicated alpha-video player — which is why Tencent VAP
exists (it is the industry-standard player for live-app gift/frame
animations).

**Implemented (2026-11-18): Tencent VAP via `flutter_vap_player`
^2.2.0** (`apps/mobile/pubspec.yaml`). The 14 frame videos were
converted from the transparent WebMs to VAP v1 MP4s
(`vap/vip<N>-<animal>.mp4` on R2, ~39.9 MB total) with
`~/workspace/darkvibex-vip-section/alpha-video/webm_to_vap.py`:
ffmpeg decodes the WebM with `-c:v libvpx-vp9` (the native VP9 decoder
drops alpha), splits the stream, extracts the alpha with
`alphaextract`, and stacks the halves side by side — **alpha mask on
the LEFT half, RGB on the RIGHT half** of each frame — encoded
`libx264 -crf 20 -preset medium -pix_fmt yuv420p -r 24 -an
-movflags +faststart`. Each file was verified by decoding the VAP,
splitting the halves, reconstructing RGBA, and comparing it against
the source WebM frame (RGB/alpha mean abs diff ~1-2, centre alpha
matches the source) plus red/dark composites in
`~/workspace/darkvibex-vip-section/verify-2026-11-18/vap-vip<N>-*.jpg`.

**Playback** (`apps/mobile/lib/widgets/vip_frame_alpha_video.dart`,
`VipFrameAlphaVideo`): `VapPlayerController.networkUrl(url, options:
VapPlayerOptions(viewType: textureView, repeatCount: 0, scaleType:
fitCenter, enableOldVersion: true))` — `enableOldVersion` because our
files are VAP v1 (no `vapc` box). The video plays **once** (5 s, ends
calmly, per Vinay's frame rule) and then swaps back to the PNG still.
The PNG still is the poster while the video loads and the fallback on
any video error or on completion — **never a black box**. A VAP video
exists only for the animal frames (VIP5-18); custom/Owner frames have
none, so `vipFrameVapUrlForDisplay(assetKey, level)` returns null for
them and the still shows only. `VipAnimatedFrame` takes an optional
`videoUrl` (passed at the room seat, seat profile sheet, member list,
profile DP and room chat sender header); when it is null/empty the
widget shows the still directly, so the PR #125 display path is
unchanged for custom frames. Catalog: each frame entry carries
`vap_key` (`apps/worker/src/vip_frame_catalog.js`,
`frameVapUrlForVipLevel` / `allFrameVapUrls`); the member block in
`apps/worker/src/index.js` also returns `active_frame_vap_key`.

**Do NOT wire the WebM through `video_player`** expecting transparency.

**Device-test checklist (must be done in the real Flutter project, on
a real Android device — VAP does not render on the iOS simulator):**
1. Open a room with a VIP5-18 user: the frame animates once on seat
   join and ends on the still (no black box, no loop).
2. Check the halves are the right way round — if the frame looks like
   a grey silhouette next to a black rectangle, the layout is swapped;
   re-run the conversion with `LAYOUT=right` and re-upload.
3. Kill the network mid-load: the PNG still shows (never a black box).
4. A user with a custom frame: still only, no VAP video attempted.
5. Chat avatar (28px) and profile DP: frame auto-sizes, animation
   plays once there too.

**Pending Vinay's go-ahead:** upload the 14 transparent PNG stills to
R2 under `frames/vip<N>-<animal>-transparent.png` (Content-Type
`image/png`). They already exist locally in
`~/workspace/darkvibex-vip-section/final-frames/`. Only VIP13's still
is on R2 so far. Until the other 13 are on R2, the frame still URLs
404 and `VipAnimatedFrame` falls back to its painted ring — the wiring
is in place, the images are not. (The VAP videos ARE on R2, but the
still is also the poster/fallback, so the PNGs are still needed.)

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

## Gift ribbons

The gift ribbon is the fourth VIP visual set: the banner shown in the
room when a VIP sends a gift (4 tiers for VIP1-18, R2
`gift-ribbons/`, `image/webp`). Full detail — tiers, keys, Worker gift
flow, Dart widget, room-screen wiring — lives in
[`docs/gift-ribbon.md`](gift-ribbon.md). Worker catalog:
`apps/worker/src/gift_ribbon_catalog.js`; Dart data:
`apps/mobile/lib/vip/vip_visual_assets.dart` (ribbon section) +
`apps/mobile/lib/widgets/gift_ribbon_banner.dart`; wired in
`apps/mobile/lib/screens/room_screen.dart` (`_showGiftRibbon`,
`Key('room-gift-ribbon')`).

## Files

Worker: `apps/worker/src/vip_frame_catalog.js`,
`apps/worker/src/vip_entry_effect_catalog.js`,
`apps/worker/src/vip_tag_catalog.js`, `apps/worker/src/vip_medal_catalog.js`
(new, VIP1-4), `apps/worker/src/vip_scenic_banner_catalog.js` (new,
VIP1-4) — each mirrors `vehicle_entry_animals.js` and is NOT part of
`COSMETIC_CATALOG` — the cosmetics test pins frames at 29),
`apps/worker/src/index.js` (`vipVisualsForLevel` animal fallbacks +
`vip_tag` + `vip_medal` + `vip_scenic_banner`, member block copies
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
