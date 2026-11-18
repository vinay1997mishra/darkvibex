# DarkVibeX — Vehicle Entry Set (VIP5–18, Tier 1–14)

Timepass only. No earning, no payout, no price change — all vehicles are
`price_coins: 0`, exactly like the existing catalog.

## What was already there

Verified from `vinay1997mishra/darkvibex` (main, read-only — nothing here
was pushed to GitHub):

- **VIP system:** VIP1–VIP18 in `apps/worker/src/vip_policy.js` and
  `apps/mobile/lib/vip/vip_policy.dart`.
  - Old rule: `entrance_vehicle_tier = level >= 8 ? level - 7 : 0`
  - VIP8 = tier 1 … VIP18 = tier 11.
  - Entrance Vehicle privilege unlocked at VIP8.
- **Old vehicle catalog:** `apps/worker/src/cosmetics.js` — only **7** vehicles:
  `vehicle_spark` (Starlight Coupe, VIP0, tier 1),
  `vehicle_royal` (Royal Chariot, VIP4, tier 4),
  `vehicle_phoenix` (Phoenix GT, VIP8, tier 8),
  `vehicle_king` (King of VIP, VIP18, tier 18),
  `vehicle_neon_comet` (Neon Comet GT, VIP6, tier 6),
  `vehicle_dragon_royal` (Dragon Royal Chariot, VIP12, tier 12),
  `vehicle_celestial_phoenix` (Celestial Phoenix, VIP16, tier 16).
  All `price_coins: 0`, `duration_days: 30`, `animation_ms: 4800`.
  Note: the old `tier` field there is *not* the VIP tier (1–14) — it was
  the old cosmetic tier. The new catalog re-maps it (see below).
- **Flutter effect:** `apps/mobile/lib/widgets/vehicle_entry_effect.dart`
  — generic `CustomPaint` vehicle (sports coupe / royal chariot / phoenix /
  neon / king variants), 4.8 s animation, drives left to right, shows
  `VIP LEVEL + name`, transparent-friendly, no video asset needed.
- **Room + store wiring:** `room_screen.dart` already plays
  `VehicleEntryEffect` / `CustomAssetEffectPlayback` on arrival; the store
  has a Vehicles category, `kind: 'vehicle'`.
- **Asset formats in the app (checked 2026-11-18, pubspec.yaml):**
  `video_player ^2.10.1`, `model_viewer_plus ^1.10.0` (GLB),
  `flutter_svg ^2.2.1`, plus Flutter CustomPaint. The app has **NO SVGA
  and NO Lottie package** — do not specify SVGA/Lottie assets. Final
  realistic-anime entries should be video (video_player) or GLB
  (model_viewer_plus) assets via `CustomAssetEffectPlayback`
  (`active_vehicle_video_key` / `active_vehicle_glb_key`).

## What is new here — 14 vs 7

Vinay expanded the scope on 2026-11-18: vehicle entries from **VIP5 to
VIP18 (14 vehicles)**, not just VIP8–18, then REPLACED the car/yacht
list with an animal-themed list (same VIP5–18 range, category + rarity
per animal — see the table below). Tier numbering is **tier = VIP − 4**
(VIP5 = tier 1 … VIP18 = tier 14).

| Tier | VIP | Animal | Category | Rarity | style_id | Animation | Cinematic scene |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 5 | Deer | Land | Rare | `deer` | run | Moonlit forest, roaring, antler energy blast |
| 2 | 6 | Wolf | Land | Rare | `wolf` | run | Moonlit night forest, howl, blue aura shockwave |
| 3 | 7 | Eagle | Air | Rare | `eagle` | fly | Golden clouds sky, dive, lightning wings |
| 4 | 8 | Panther | Land | Epic | `panther` | run | Neon night jungle, leap, shadow energy blast |
| 5 | 9 | Cobra | Land | Epic | `cobra` | strike | Golden temple fire, hood spread, venom blast |
| 6 | 10 | Lion | Land | Epic | `lion` | run | Savanna sunset, roar, golden mane shockwave |
| 7 | 11 | Tiger | Land | Epic | `tiger` | run | Jungle sunset fire, roar, fire shockwave |
| 8 | 12 | Mammoth | Land | Legendary | `mammoth` | run | Snowy mountain ice, charge, ice shockwave |
| 9 | 13 | Gorilla | Land | Legendary | `gorilla` | run | Jungle gold earth, chest pound, earth shockwave |
| 10 | 14 | Bear | Land | Legendary | `bear` | run | Pine forest fire, roar, fire shockwave (8 s video) |
| 11 | 15 | Kraken | Water | Legendary | `kraken` | rise | Stormy ocean, tentacles, water whirlpool blast |
| 12 | 16 | Leviathan | Water | Mythic | `leviathan` | fly | Storm ocean + lightning, water superpower blast |
| 13 | 17 | Phoenix | Air | Mythic | `phoenix` | fly | Fire dark sky, wings spread, fire superpower blast |
| 14 | 18 | Dragon | Air | Mythic | `dragon` | fly | Golden clouds storm, roar, fire + lightning blast |

This animal list REPLACES the old car/yacht list (Silver Moon Coupe,
Sapphire Falcon GT, Emerald Royal Carriage, Starlight Coupe, Neon
Comet GT, Royal Chariot, Golden Dragon, Phoenix GT, Luxury Yacht,
Royal Lion Carriage, Celestial Phoenix, Diamond Jet, Inferno Dragon,
King of VIP). Phoenix moved to VIP17 and the Yacht dropped out.

Quality tiers (Vinay, 2026-11-18): VIP5-15 = premium quality,
VIP16-18 (Leviathan, Phoenix, Dragon) = SUPER premium quality.
All 14 MP4s are in videos/ — see videos/VIDEO_ASSETS.md.

### Files in this folder

- `vehicle_catalog.js` — `VEHICLE_ENTRY_CATALOG` (14 animal entries, same
  shape as `COSMETIC_CATALOG` plus `category, rarity, video_file, layout,
  backgroundTheme`): `id, kind:'vehicle', name, emoji, category, rarity,
  price_coins:0, min_vip_level, duration_days:30, tier, animation_type,
  animation_ms:10000 (Bear 8000), style_id, video_file, layout,
  backgroundTheme, colors:[3 hex], description`), plus
  `vehicleForVipLevel(level)`, `vehicleForTier(tier)`, `vehicleById()`,
  `vehicleByStyleId()`, `videoFileForVipLevel()`, `layoutForVipLevel()`,
  `isFullscreenVipLevel()`, and `LEGACY_VEHICLE_MAP` /
  `vehicleForLegacyId()`.
  `vehicleForVipLevel(5)` = Deer (tier 1), `vehicleForVipLevel(15)` =
  Kraken (tier 11), `vehicleForVipLevel(17)` = Phoenix (tier 13),
  `vehicleForVipLevel(18)` = Dragon (tier 14).
- `vehicle_entry_effect_v2.dart` — Flutter/Dart snippet. `VEHICLE_STYLES`
  map (car styles, kept as the CustomPaint fallback), `vehicleStyleForVipLevel()`
  (VIP5+, tier = level − 4), `paintVehicle()` dispatch,
  `_paintAnimatedBackground()` (time-animated particles / pulsing glow /
  drifting clouds — the animated anime background),
  `_paintCinematicBackdrop()` (per-style backdrop for every style),
  plus the layout constants `bottomEntryHeightFraction = 0.40`,
  `fullscreenHeightFraction = 1.0`, `superPremiumMinVip = 16`,
  `entryRectForVipLevel()`, `isFullscreenVipLevel()`,
  `animalVideoFiles` (exact MP4 filename per VIP level) and
  `animalBackgroundThemes`. No external assets in the snippet itself.
- `preview.html` — standalone interactive preview. Inline SVG/CSS only,
  no external images. Grid of all 14 animals with name / VIP / tier /
  category / rarity / background theme / video filename; each **Play**
  button shows the entry for 4.8 s in the room stage — VIP5–15 in the
  bottom 40% touching the bottom edge, VIP16–18 full-screen — while
  the stage background animates (CSS keyframes: pulsing glow, rising
  particles, drifting clouds) and switches theme per animal (fire,
  water, gold, night, snow). Open it directly in a browser.
- `videos/` — all 14 MP4s + `VIDEO_ASSETS.md` (per-file list, layout,
  merge note).
- `reference-frames/yacht-02s.jpg`, `yacht-04s.jpg`, `yacht-06s.jpg` —
  stills from Vinay's Yacht video (ffmpeg, 2 s / 4 s / 6 s, 704×1280).
- `reference-frames/phoenix-02s.jpg`, `phoenix-04s.jpg`, `phoenix-06s.jpg` —
  stills from Vinay's Phoenix video (ffmpeg, 2 s / 4 s / 6 s, 480×864).
  Style reference only; the videos themselves were NOT copied here.
- `README.md` — this file.

## Style direction — Realistic anime, all 14, not flat cartoon

From Vinay, 2026-11-18: "Aise dikhna chahiye" / "Real jaisa anime
style" — and then "Ye sab entry chahiye mujhe" (all entries like this).

- **Reference video 1 — Yacht:** `workspace/user/media_library/video/88/886f3d7764d31d868f430bb721ef5698035f8173cab0e9078d7ca8273809cca1.mp4` (8 s, 704×1280 vertical, h264).
  Frames: `reference-frames/yacht-02s.jpg`, `yacht-04s.jpg`, `yacht-06s.jpg`.
  What it shows: a white multi-deck luxury yacht sailing toward the
  camera on a deep-blue ocean at sunset, purple storm clouds above,
  orange sunset glow on the horizon, a huge turquoise wave curling
  behind the yacht, white spray/wake, a turquoise pool on deck, and
  gold window lights / gold trim.
- **Reference video 2 — Phoenix:** `workspace/user/media_library/video/96/96690be8c4ede147329569f1be57cba28e29843ea537dd7e6f1cbe4587487579.mp4` (8 s, 480×864 vertical, h264).
  Frames: `reference-frames/phoenix-02s.jpg`, `phoenix-04s.jpg`, `phoenix-06s.jpg` (verified visually).
  What it shows: 2 s — close-up phoenix head, glowing yellow eyes,
  red/gold layered feathers, flame crest, fire background; 4 s — wing
  close-up, red feathers with gold tips, flames; 6 s — full phoenix
  flying toward camera, wings spread wide, dark background, long
  golden tail feathers, embers and flame trails.
- **Target:** detailed shading, layered gradients, glow, highlights
  and a cinematic background for every vehicle. Flat single-colour
  vector shapes are NOT the target. The per-vehicle scene table above
  is the standard for the final asset of each vehicle.
- **Honest limitation:** Flutter `CustomPaint` (paths, gradients,
  ovals) can approximate these compositions but cannot fully match
  either video. The Dart painters (`_paintYachtBackdrop()`,
  `_paintPhoenixBackdrop()`, `_paintCinematicBackdrop()` and the
  `_paint*` vehicle helpers) are lightweight fallbacks only.
  **For the final app, every vehicle should be a rendered video
  (video_player) or GLB (model_viewer_plus) asset** in this
  realistic-anime style, played via `CustomAssetEffectPlayback`
  (`active_vehicle_video_key` / `active_vehicle_glb_key`). No SVGA,
  no Lottie — those packages are not in the app.
  - Yacht asset shot list: 0–2 s purple clouds + sunset glow, ocean
    swell rises; 2–5 s giant turquoise wave curls behind, yacht bow
    rises toward camera with spray; 5–7 s yacht fills the frame,
    decks / windows / pool in detail, gold lights on; 7–8 s name +
    "VIP 13" in glowing gold, then fade. Duration 8 s (or cut to
    4.8 s to match `animation_ms`), vertical 704×1280.
  - Phoenix asset shot list: 0–2 s close-up head, glowing eyes,
    feathers ignite; 2–5 s wings spread wide, flames + embers rising,
    tail feathers streaming; 5–7 s full bird flying toward camera,
    dark sky, flame trails; 7–8 s name + "VIP 12" in glowing gold,
    then fade. Duration 8 s (or cut to 4.8 s), vertical 480×864.
  - Other vehicles: same 8 s / 4.8 s structure, each with its scene
    from the table above as the background and the vehicle as the hero.

## Layout — bottom 40% for VIP5-15, full-screen for VIP16-18

Vinay, 2026-11-18: "VIP15 tak niche se touch kar ke 40% screen me show
honi chahiye" — and the background also in anime style premium
animated effects.

- **VIP5–15 (Deer … Kraken):** entry is **bottom-anchored, touching
  the bottom edge, height = 40% of screen, full width**. The room
  (seats, chat) stays visible above it. In the catalog this is
  `layout: { anchor: 'bottom', heightFraction: 0.40 }`; in Dart it is
  `bottomEntryHeightFraction = 0.40` and `entryRectForVipLevel()` =
  `Rect.fromLTWH(0, screenHeight * 0.60, screenWidth,
  screenHeight * 0.40)`.
- **VIP16–18 (Leviathan, Phoenix, Dragon — super premium):** entry is
  **full-screen, 100% height**. `layout: { anchor: 'full',
  heightFraction: 1.0 }`; Dart `isFullscreenVipLevel(level)` =
  `level >= 16`, `entryRectForVipLevel()` returns the whole screen.
- **Background:** anime style premium **animated** effects — the
  backdrop behind each animal moves with time (drifting particles,
  pulsing glow, drifting clouds, rising embers/flames/bubbles), never
  a static picture. Dart: `_paintAnimatedBackground(canvas, size,
  styleId, progress)` — every element is a function of `progress`
  (0.0–1.0 across the entry) — called from `paintVehicle()` before
  `_paintCinematicBackdrop()`. The MP4 videos themselves also carry
  the animated anime scene. The preview (`preview.html`) shows the
  same animated background with CSS keyframes (glow pulse, rising
  particles, drifting clouds) and the stage switches theme per animal.
- **Video playback:** the room should play the MP4 in the rect above
  via `video_player` / `CustomAssetEffectPlayback`
  (`active_vehicle_video_key` = the catalog `video_file` filename).
  For VIP5–15 the video widget is bottom-anchored at 40% height;
  for VIP16–18 it fills the screen. The CustomPaint painters in
  `vehicle_entry_effect_v2.dart` remain the lightweight fallback
  when no video asset is set.

## Direct R2 playback — videos play straight from R2, no Worker in the path

Vinay, 2026-11-18: "R2 se direct video play ho aisa karna hai."

- **Bucket:** the EXISTING bucket **`darkvibex-files`** — no new bucket.
  It is already bound to the Worker in `apps/worker/wrangler.jsonc`
  (`r2_buckets: [{ binding: 'FILES', bucket_name: 'darkvibex-files' }]`),
  but that binding is only for **upload/storage**. Playback does NOT
  go through the Worker (`darkvibex-api`) — a Worker hop would add
  latency on every room entry, and direct CDN playback is faster.
- **R2 keys (clean names):** `vehicles/vip5-deer.mp4`,
  `vehicles/vip6-wolf.mp4`, `vehicles/vip7-eagle.mp4`,
  `vehicles/vip8-panther.mp4`, `vehicles/vip9-cobra.mp4`,
  `vehicles/vip10-lion.mp4`, `vehicles/vip11-tiger.mp4`,
  `vehicles/vip12-mammoth.mp4`, `vehicles/vip13-gorilla.mp4`,
  `vehicles/vip14-bear.mp4`, `vehicles/vip15-kraken.mp4`,
  `vehicles/vip16-leviathan.mp4`, `vehicles/vip17-phoenix.mp4`,
  `vehicles/vip18-dragon.mp4`. Uploaded by `cloudflare-r2-upload.sh`
  (already targets `darkvibex-files`; see below).
- **Make the bucket public — dashboard steps:**
  1. Open [dash.cloudflare.com](https://dash.cloudflare.com) → **R2
     Object Storage** → open bucket **`darkvibex-files`**.
  2. Either connect a **Custom Domain** (recommended): bucket →
     **Settings → Custom Domain** → add your domain, e.g.
     `cdn.example.com` (must be a domain in your Cloudflare account).
     Files are then served by the Cloudflare CDN from that domain.
  3. Or enable the public **r2.dev** URL: bucket → **Settings** →
     allow public access / the `https://pub-xxx.r2.dev` subdomain.
  4. Upload the 14 MP4s under `vehicles/` (script or dashboard
     drag-and-drop). R2 free tier is 10 GB storage with zero egress;
     these 14 videos total ~157 MB.
- **Public URL pattern:** `<R2_PUBLIC_BASE_URL>/vehicles/vip17-phoenix.mp4`
  — e.g. `https://cdn.example.com/vehicles/vip17-phoenix.mp4` or
  `https://pub-xxx.r2.dev/vehicles/vip17-phoenix.mp4`.
- **Where to set the base URL (one place, same value in both files):**
  - Worker catalog `vehicle_catalog.js`: `R2_PUBLIC_BASE_URL = ''` →
    set to the custom domain / r2.dev URL (no trailing slash).
    `videoUrlForVipLevel(level)` returns the full direct URL, or
    `null` while it is still `''`; `isR2Configured()` reports it.
  - Dart `vehicle_entry_effect_v2.dart`: `r2PublicBaseUrl = ''` →
    same value. `animalVideoUrlForVipLevel(level)` returns the full
    direct URL, or `null` while unconfigured. The exact domain is
    NOT known yet — it is deliberately left `''`, do not invent one.
- **Playback in the app:** the room plays the URL from
  `videoUrlForVipLevel()` / `animalVideoUrlForVipLevel()` with
  `video_player` (`VideoPlayerController.networkUrl(Uri.parse(url))`)
  inside `CustomAssetEffectPlayback` (`active_vehicle_video_key` =
  that full direct R2 URL). **Never a Worker URL.**
- **Prefetch for instant entry:** on room join (once the joining
  user's VIP level is known), create the controller early and
  `await initialize()` so the first frames are buffered before the
  entry plays; `play()` on entry, dispose afterwards. See the
  commented example in `vehicle_entry_effect_v2.dart` (DIRECT R2
  PLAYBACK header). Layout is unchanged: VIP5–15 bottom 40%,
  VIP16–18 full-screen, animated anime background behind it.
- **Upload script:** `cloudflare-r2-upload.sh` — needs
  `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`
  (R2 API token), bucket defaults to `darkvibex-files`. The actual
  upload still needs Vinay's R2 access/keys.

## VIP rule change required on merge

Vinay wants vehicle entry from **VIP5**, not VIP8. The old rule must
change when merging — this workspace set already uses the new rule:

- `apps/worker/src/vip_policy.js`: `entrance_vehicle_tier` from
  `level >= 8 ? level - 7 : 0` → `level >= 5 ? level - 4 : 0`.
- `apps/mobile/lib/vip/vip_policy.dart`: Entrance Vehicle privilege
  `minLevel: 8` → `minLevel: 5`, and any `level - 7` tier math → `level - 4`.
- `vehicle_catalog.js` (`vehicleForVipLevel`) and
  `vehicle_entry_effect_v2.dart` (`vehicleStyleForVipLevel`) already
  use tier = level − 4 for VIP5–18.

## Legacy mapping (so nothing breaks)

Old id → new tier (in `vehicle_catalog.js` as `LEGACY_VEHICLE_MAP`;
old tiers were VIP8–18 = 1–11, new tiers are VIP5–18 = 1–14, so every
old tier shifts by +3):

- `vehicle_spark` → tier 4 (was 1)
- `vehicle_neon_comet` → tier 5 (was 2)
- `vehicle_royal` → tier 6 (was 3)
- `vehicle_dragon_royal` → tier 7 (was 4)
- `vehicle_phoenix` → tier 8 (was 5)
- `vehicle_celestial_phoenix` → tier 11 (was 8)
- `vehicle_king` → tier 14 (was 11)

Keep the old ids working in the store until every client has the new
catalog; do not delete them in the same release you add the new ones.

## How to merge into the repo

1. **Worker catalog — `apps/worker/src/cosmetics.js`**
   Replace / extend the 7-entry vehicle section with the 14 entries from
   `vehicle_catalog.js`. Keep `kind: 'vehicle'`, `price_coins: 0`,
   `duration_days: 30`, `animation_ms: 4800`. Add the legacy-id lookup
   (`vehicleForLegacyId`) if the store resolves equipped items by old id.
2. **VIP rule — change as above** (`vip_policy.js` + `vip_policy.dart`).
3. **Flutter painters — `apps/mobile/lib/widgets/vehicle_entry_effect.dart`**
   Add the `VEHICLE_STYLES` map, `_paintCinematicBackdrop()` and the new
   `_paint*` branches from `vehicle_entry_effect_v2.dart` into
   `_EntryVehiclePainter` (see the merge comments at the top of that
   file). Do not replace the existing 3 branches (Starlight Coupe,
   Neon Comet GT, Royal Chariot). Pass the new `style_id` from the room
   / cosmetics store so VIP5+ actually get the right vehicle instead
   of the fallback coupe.
4. **Tests — must update.**
   - `apps/worker/test/cosmetics.test.js` (and any equivalent catalog test)
     asserts `vehicles.length == 7`. **Update it to 14**, and add an
     assertion that tiers 1–14 map to VIP 5–18 with no gaps.
   - Run the worker tests and the Flutter widget tests for
     `vehicle_entry_effect.dart` before merging.

## Merge risks

- **Test failure if not updated:** the 7→14 count change will fail
  `cosmetics.test.js` until it is updated (see above).
- **Old tier meaning:** the old catalog's `tier` values (1, 4, 6, 8, 12, 16, 18)
  are not the new 1–14 VIP tiers. Any code that treated the old number as
  a VIP tier, or gated a vehicle by `min_vip_level` from the old entries
  (e.g. Starlight Coupe was VIP0), must be re-checked — in the new catalog
  every vehicle requires VIP5+.
- **VIP rule change:** if `vip_policy.js` / `vip_policy.dart` are not
  updated to VIP5 / level − 4, VIP5–7 users will not unlock a vehicle
  even though the catalog lists them.
- **Style-id mismatch:** if `room_screen.dart` still passes an old style
  name, the painter falls back to the generic coupe (by design in the
  snippet). Verify the style_id round-trip: catalog → store → room →
  `VehicleEntryEffect`.
- **No earning:** prices stay 0 on purpose. Do not wire these vehicles to
  any payout / withdraw flow — DarkVibeX is timepass only by Vinay's decision.
- **No SVGA/Lottie:** do not add SVGA/Lottie assets or packages on merge;
  use video (video_player) / GLB (model_viewer_plus) only.

## Verification done here

- `node --check vehicle_catalog.js` — passed.
- Runtime import test — passed: count 14; `vehicleForVipLevel(5)` =
  Deer (tier 1, Land Rare, bottom 40%), `vehicleForVipLevel(15)` =
  Kraken (tier 11, bottom 40%, fullscreen false), `vehicleForVipLevel(16)`
  = Leviathan (tier 12, full-screen), `vehicleForVipLevel(18)` = Dragon
  (tier 14, full-screen), `vehicleForVipLevel(4)` = null;
  all 14 have a `video_file`, all 14 video files exist on disk;
  VIP5–15 all `layout.anchor='bottom', heightFraction=0.40`, VIP16–18
  all `layout.anchor='full', heightFraction=1.0`.
- `preview.html` — ~15 KB, < 1 MB, inline SVG/CSS only.
- Dart: braces 69/69, parens 953/953, brackets 72/72 (count-checked);
  not compiled — no `dart`/`flutter` binary in this VM. Compile it in
  the Flutter project before merging.
- Reference frames: 6 JPGs (3 yacht 704×1280, 3 phoenix 480×864),
  extracted with ffmpeg at 2 s / 4 s / 6 s; Phoenix 2 s / 4 s / 6 s
  frames viewed to confirm the description.
- Dart: braces 63/63, parens balanced (checked by inspection count);
  not compiled — no `dart`/`flutter` binary in this VM. Compile it in
  the Flutter project before merging.
- Nothing was pushed to GitHub; no repo files were edited.
