// DarkVibeX — Vehicle Entry Effect v2 (Flutter / Dart snippet)
// ---------------------------------------------------------------------------
// PURPOSE
//   The CustomPaint FALLBACK for the animal vehicle entries (VIP5-18,
//   tier 1-14; tier = VIP - 4), used ONLY when the member's animal video
//   (direct R2 MP4, played by CustomAssetEffectPlayback via directVideoUrl)
//   is unavailable — e.g. no network, or a level with no video yet.
//   The animal set (single authoritative list, apps/worker/src/
//   vehicle_entry_animals.js):
//     Deer (VIP5), Wolf (VIP6), Eagle (VIP7), Panther (VIP8),
//     Cobra (VIP9), Lion (VIP10), Tiger (VIP11), Mammoth (VIP12),
//     Gorilla (VIP13), Bear (VIP14), Kraken (VIP15), Leviathan (VIP16),
//     Phoenix (VIP17), Dragon (VIP18).
//   The old 7-car list (Starlight Coupe, Royal Chariot, Phoenix GT,
//   King of VIP, Neon Comet GT, Dragon Royal Chariot, Celestial
//   Phoenix) was superseded by Vinay on 2026-11-18 and is gone from the
//   worker catalog. The painter branches below are the legacy car
//   shapes, kept as placeholder silhouettes keyed by animal theme — the
//   video is primary and these painters are never the main visual.
//
// HOW TO MERGE
//   This file IS the vehicle-entry effect v2 (it replaces the original
//   v2 file). For the room arrival flow, use animalVideoUrlForVipLevel()
//   below and pass it as directVideoUrl to CustomAssetEffectPlayback —
//   direct R2 playback, never through the Worker /api/files (its
//   allowlist rejects vehicles/ keys). The CustomPaint branches below
//   are the fallback only, when no video is available.
//   entryRectForVipLevel() gives the arrival overlay rect: VIP5-15
//   bottom-anchored 40% height, VIP16-18 full-screen.
//
//   This file is self-contained and compile-plausible as a Dart snippet:
//   it only needs `package:flutter/material.dart` and `dart:math`.
//   It is NOT a full widget — the animation controller, label layout
//   and CustomPaint wrapper stay in the original vehicle_entry_effect.dart.

// STYLE DIRECTION (2026-11-18, from Vinay's two reference videos)
//   "Aise dikhna chahiye" + "Real jaisa anime style" — realistic anime
//   for ALL 14 vehicles, NOT flat cartoon / simple vector drawing.
//   Reference 1 — Yacht: workspace/user/media_library/video/88/
//   886f3d7764d31d868f430bb721ef5698035f8173cab0e9078d7ca8273809cca1.mp4
//   (8 s, 704x1280 vertical). Stills in this folder:
//   reference-frames/yacht-02s.jpg, yacht-04s.jpg, yacht-06s.jpg.
//   Shows: white multi-deck luxury yacht sailing toward the camera on
//   a deep-blue ocean at sunset, purple storm clouds, orange sunset
//   glow, huge turquoise wave, white spray, turquoise pool, gold lights.
//   Reference 2 — Phoenix: workspace/user/media_library/video/96/
//   96690be8c4ede147329569f1be57cba28e29843ea537dd7e6f1cbe4587487579.mp4
//   (8 s, 480x864 vertical). Stills in this folder:
//   reference-frames/phoenix-02s.jpg, phoenix-04s.jpg, phoenix-06s.jpg.
//   Shows (verified from frames): 2 s close-up head — glowing yellow
//   eyes, red/gold layered feathers, flame crest, fire background;
//   4 s wing close-up — red feathers with gold tips, flames; 6 s full
//   bird flying toward camera — wings spread wide, dark background,
//   long golden tail feathers, embers and flame trails.
//
//   HONEST LIMITATION — read before merging:
//   Flutter CustomPaint (paths, gradients, ovals) CANNOT fully match
//   either video. It can approximate the composition, and that is what
//   _paintYachtBackdrop(), _paintPhoenixBackdrop() and
//   _paintCinematicBackdrop() below do, as a lightweight fallback with
//   no asset download. For true realistic-anime quality the app MUST
//   play a rendered VIDEO (video_player) or GLB (model_viewer_plus)
//   asset per vehicle, via the app's existing CustomAssetEffectPlayback
//   (active_vehicle_video_key / active_vehicle_glb_key). The app has
//   NO SVGA and NO Lottie package — do NOT specify SVGA/Lottie assets.
//   Shot list for the Yacht asset: 0-2 s purple clouds + sunset glow,
//   swell rises; 2-5 s giant turquoise wave, yacht bow rises with spray;
//   5-7 s yacht fills frame, decks/windows/pool in detail, gold lights;
//   7-8 s name + "VIP 15" in glowing gold, fade. Shot list for the
//   Phoenix asset: 0-2 s close-up head, glowing eyes, feathers ignite;
//   2-5 s wings spread wide, flames + embers rising, tail feathers
//   streaming; 5-7 s full bird flying toward camera, dark sky, flame
//   trails; 7-8 s name + "VIP 17" in glowing gold, fade. Duration 8 s
//   (or cut to 4.8 s to match animation_ms), vertical, full-screen.
//   Do NOT present the CustomPaint version as the finished realistic
//   look — it is the fallback when no video/GLB asset is available.
//
// ANIMAL SET (Vinay, 2026-11-18) — REPLACES the car/yacht list above:
//   VIP5 Deer Land Rare, VIP6 Wolf Land Rare, VIP7 Eagle Air Rare,
//   VIP8 Panther Land Epic, VIP9 Cobra Land Epic, VIP10 Lion Land Epic,
//   VIP11 Tiger Land Epic, VIP12 Mammoth Land Legendary, VIP13 Gorilla
//   Land Legendary, VIP14 Bear Land Legendary, VIP15 Kraken Water
//   Legendary, VIP16 Leviathan Water Mythic, VIP17 Phoenix Air Mythic,
//   VIP18 Dragon Air Mythic. Each has a rendered MP4 in videos/ — see
//   ANIMAL_VIDEO_FILES below and vehicle_entry_animals.js (video_key
//   per entry). vehicleStyles below is keyed by animal style_id
//   ('deer' ... 'dragon'); the painter branches are the CustomPaint
//   fallback only — the video asset is what plays.
//
// LAYOUT (Vinay, 2026-11-18):
//   VIP5-15 : bottom-anchored, touching the bottom edge, height = 40%
//             of screen, full width. BOTTOM_ENTRY_HEIGHT_FRACTION = 0.40.
//             entryRectForVipLevel() returns Rect.fromLTWH(0,
//             screenHeight * 0.60, screenWidth, screenHeight * 0.40).
//   VIP16-18: full-screen, 100% height (super premium).
//             isFullscreenVipLevel(level) == level >= 16.
//
// ANIMATED BACKGROUND: the backdrop is NOT a static picture. Every
//   backdrop painter takes `progress` (0.0-1.0 across the animation)
//   and moves with time: _paintAnimatedBackground() draws drifting
//   particles, a pulsing glow and rising embers/flames whose positions
//   are a function of progress, and paintVehicle() calls it BEFORE the
//   per-style _paintCinematicBackdrop(). The MP4 videos themselves
//   also carry the animated anime scene.
//
// DIRECT R2 PLAYBACK (Vinay, 2026-11-18) — videos play DIRECTLY from
//   Cloudflare R2, with NO Worker in the playback path:
//     video URL = r2PublicBaseUrl + '/' + animalVideoKeys[level]
//     e.g. '<base>/vehicles/vip17-phoenix.mp4'
//   The Worker (darkvibex-api) already has an R2 binding FILES ->
//   bucket "darkvibex-files", but that binding is only for
//   upload/storage. Playback must NOT go through a Worker URL:
//   the room plays the MP4 straight from the R2 public URL with
//   video_player (VideoPlayerController.networkUrl), served by the
//   Cloudflare CDN with zero egress — fastest start on room entry.
//   r2PublicBaseUrl below is already set to the bucket's public
//   r2.dev URL (https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev),
//   merged via PR #124. If the bucket later gets a custom domain,
//   change that one constant and both the worker and Dart sides use it.
//   If it were ever '' again, animalVideoUrlForVipLevel() would
//   return null and the CustomPaint fallback below is used.
//
//   PREFETCH / PRELOAD (for instant entry playback): the room must
//   NOT wait for the entry moment to fetch the video. On room join
//   (or when the joining user's VIP level is known), create the
//   controller early and await initialize() so the first frames are
//   already buffered when the entry plays:
//     // final url = animalVideoUrlForVipLevel(vipLevel);
//     // if (url != null) {
//     //   _vehicleController = VideoPlayerController.networkUrl(
//     //     Uri.parse(url),
//     //   );
//     //   await _vehicleController!.initialize(); // prefetch on join
//     //   // ... on entry: show the video widget (entryRectForVipLevel)
//     //   // and call _vehicleController!.play(); dispose it afterwards.
//     // }
//   (Requires package:video_player/video_player.dart in the real
//   room widget — this snippet itself stays import-free of it.)
//   The video widget is placed in entryRectForVipLevel(level):
//   VIP5-15 bottom 40%, VIP16-18 full-screen.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

// ---------------------------------------------------------------------------
// 1. Style table — one entry per tier / VIP level.
//    style_id values MUST match vehicle_catalog.js (VEHICLE_ENTRY_CATALOG).
// ---------------------------------------------------------------------------

class VehicleStyle {
  const VehicleStyle({
    required this.styleId,
    required this.name,
    required this.minVip,
    required this.tier,
    required this.colors,
    required this.animationType,
  });

  final String styleId;
  final String name;
  final int minVip;
  final int tier;
  final List<Color> colors; // [primary, secondary, accent]
  final String animationType; // 'run' | 'fly' | 'strike' | 'rise'
}

const Map<String, VehicleStyle> vehicleStyles = <String, VehicleStyle>{
  // One entry per animal (VIP5-18, tier 1-14). style_id, name, colors
  // and animationType mirror apps/worker/src/vehicle_entry_animals.js.
  // Phoenix is VIP17 and Dragon is VIP18 (the old car list had the
  // Phoenix GT at VIP12 — that was superseded with the cars).
  'deer': VehicleStyle(
    styleId: 'deer',
    name: 'Deer',
    minVip: 5,
    tier: 1,
    colors: <Color>[Color(0xFFFFD700), Color(0xFF7FB3FF), Color(0xFFFFF3B0)],
    animationType: 'run',
  ),
  'wolf': VehicleStyle(
    styleId: 'wolf',
    name: 'Wolf',
    minVip: 6,
    tier: 2,
    colors: <Color>[Color(0xFFC0C0C0), Color(0xFF00B0FF), Color(0xFFE8ECF5)],
    animationType: 'run',
  ),
  'eagle': VehicleStyle(
    styleId: 'eagle',
    name: 'Eagle',
    minVip: 7,
    tier: 3,
    colors: <Color>[Color(0xFFFFD700), Color(0xFF00B0FF), Color(0xFFFFF3B0)],
    animationType: 'fly',
  ),
  'panther': VehicleStyle(
    styleId: 'panther',
    name: 'Panther',
    minVip: 8,
    tier: 4,
    colors: <Color>[Color(0xFF111111), Color(0xFF00E676), Color(0xFF7B2FFF)],
    animationType: 'run',
  ),
  'cobra': VehicleStyle(
    styleId: 'cobra',
    name: 'Cobra',
    minVip: 9,
    tier: 5,
    colors: <Color>[Color(0xFFFFD700), Color(0xFFFF6D00), Color(0xFFFFF3B0)],
    animationType: 'strike',
  ),
  'lion': VehicleStyle(
    styleId: 'lion',
    name: 'Lion',
    minVip: 10,
    tier: 6,
    colors: <Color>[Color(0xFFFFB300), Color(0xFFFF6D00), Color(0xFFFFD700)],
    animationType: 'run',
  ),
  'tiger': VehicleStyle(
    styleId: 'tiger',
    name: 'Tiger',
    minVip: 11,
    tier: 7,
    colors: <Color>[Color(0xFFFF6D00), Color(0xFFFFC400), Color(0xFFFFE082)],
    animationType: 'run',
  ),
  'mammoth': VehicleStyle(
    styleId: 'mammoth',
    name: 'Mammoth',
    minVip: 12,
    tier: 8,
    colors: <Color>[Color(0xFFB3E5FC), Color(0xFF00B0FF), Color(0xFFFFFFFF)],
    animationType: 'run',
  ),
  'gorilla': VehicleStyle(
    styleId: 'gorilla',
    name: 'Gorilla',
    minVip: 13,
    tier: 9,
    colors: <Color>[Color(0xFF8D6E63), Color(0xFFFFD700), Color(0xFFFFF3B0)],
    animationType: 'run',
  ),
  'bear': VehicleStyle(
    styleId: 'bear',
    name: 'Bear',
    minVip: 14,
    tier: 10,
    colors: <Color>[Color(0xFF6D4C41), Color(0xFFD50000), Color(0xFFFF6D00)],
    animationType: 'run',
  ),
  'kraken': VehicleStyle(
    styleId: 'kraken',
    name: 'Kraken',
    minVip: 15,
    tier: 11,
    colors: <Color>[Color(0xFF0B3D91), Color(0xFF00B0FF), Color(0xFF7FE3F2)],
    animationType: 'rise',
  ),
  'leviathan': VehicleStyle(
    styleId: 'leviathan',
    name: 'Leviathan',
    minVip: 16,
    tier: 12,
    colors: <Color>[Color(0xFF0B3D91), Color(0xFF00E5FF), Color(0xFFB3E5FC)],
    animationType: 'fly',
  ),
  'phoenix': VehicleStyle(
    styleId: 'phoenix',
    name: 'Phoenix',
    minVip: 17,
    tier: 13,
    colors: <Color>[Color(0xFFFF3D00), Color(0xFFFF9E00), Color(0xFFFFD54F)],
    animationType: 'fly',
  ),
  'dragon': VehicleStyle(
    styleId: 'dragon',
    name: 'Dragon',
    minVip: 18,
    tier: 14,
    colors: <Color>[Color(0xFFFFC400), Color(0xFFFF6D00), Color(0xFFFFE082)],
    animationType: 'fly',
  ),
};

/// Mirrors the NEW vip_policy.js rule Vinay wants: tier = level - 4
/// for VIP5-18 (VIP5 = tier 1 ... VIP18 = tier 14), otherwise null.
/// Old rule was level - 7 for VIP8-18 — update vip_policy.js and
/// vip_policy.dart (privilege minLevel 8 -> 5) when merging.
VehicleStyle? vehicleStyleForVipLevel(int level) {
  if (level < 5 || level > 18) return null;
  final int tier = level - 4;
  for (final VehicleStyle style in vehicleStyles.values) {
    if (style.tier == tier) return style;
  }
  return null;
}

VehicleStyle? vehicleStyleForTier(int tier) {
  for (final VehicleStyle style in vehicleStyles.values) {
    if (style.tier == tier) return style;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 1b. Layout + animal video assets (Vinay, 2026-11-18).
//     Mirrors vehicle_catalog.js: BOTTOM_ENTRY_HEIGHT_FRACTION,
//     FULLSCREEN_HEIGHT_FRACTION, SUPER_PREMIUM_MIN_VIP.
// ---------------------------------------------------------------------------

/// VIP5-15 entries sit at the bottom, touching the bottom edge,
/// 40% of screen height, full width. VIP16-18 are full-screen.
const double bottomEntryHeightFraction = 0.40;
const double fullscreenHeightFraction = 1.0;
const int superPremiumMinVip = 16; // VIP16 Leviathan, VIP17 Phoenix, VIP18 Dragon.

bool isFullscreenVipLevel(int level) => level >= superPremiumMinVip;

/// Rect the video / effect occupies on screen. VIP5-15: bottom 40%
/// (y = 0.60 * height .. height). VIP16-18: the whole screen.
/// Returns null for levels with no vehicle (VIP < 5 or > 18).
Rect? entryRectForVipLevel(int level, Size screenSize) {
  if (level < 5 || level > 18) return null;
  if (isFullscreenVipLevel(level)) {
    return Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
  }
  final double h = screenSize.height * bottomEntryHeightFraction;
  return Rect.fromLTWH(0, screenSize.height - h, screenSize.width, h);
}

/// Rendered MP4 per VIP level (videos/ — 720x1280, 10 s, Bear 8 s).
/// Host on a CDN/server; store only this filename as
/// active_vehicle_video_key — do NOT commit the MP4s to git.
const Map<int, String> animalVideoFiles = <int, String>{
  5: 'media-generation-vip5-deer-superpower-0-ffb877e8-d2f5-4801-9edb-1cf2d632d369.mp4',
  6: 'media-generation-vip6-wolf-superpower-0-f4092fd8-b6f2-4301-a37c-08c87b19dea7.mp4',
  7: 'media-generation-vip7-eagle-superpower-0-6aa08eef-0bc5-4eab-85e1-1c83eac84732.mp4',
  8: 'media-generation-vip8-panther-superpower-0-0a0d1da0-6d2d-4125-89f9-bbebd0f3bbbf.mp4',
  9: 'media-generation-vip9-cobra-superpower-0-b39a4267-c970-4cac-8254-621d22ec7fcf.mp4',
  10: 'media-generation-vip10-lion-superpower-0-e9243c51-2b33-4742-947f-06f3b09d7b6f.mp4',
  11: 'media-generation-vip11-tiger-premium-0-243fd86c-1899-47c6-ba46-cd0aae7c6266.mp4',
  12: 'media-generation-vip12-mammoth-premium-0-41b4160e-85fd-4b73-8f30-166576579a85.mp4',
  13: 'media-generation-vip13-gorilla-premium-0-5e0741a5-605c-49e6-b472-50773a3c75a2.mp4',
  14: 'media-generation-vip14-bear-premium-0-3679e073-39f9-40fd-9582-b58e2a03dcec.mp4',
  15: 'media-generation-vip15-kraken-premium-0-3eab4c0a-43c0-4c1b-b923-44353f93b938.mp4',
  16: 'media-generation-vip16-leviathan-superpremium-0-b26ea4d0-6ba8-4ef0-b87e-b47acf3d5a22.mp4',
  17: 'media-generation-vip17-phoenix-superpremium-0-17afdbe2-e126-4aad-9342-654fad7e499d.mp4',
  18: 'media-generation-vip18-dragon-superpremium-0-e260a266-1eee-4158-b306-a98657b28d62.mp4',
};

String? animalVideoFileForVipLevel(int level) => animalVideoFiles[level];

/// DIRECT R2 PLAYBACK — public base URL of the "darkvibex-files"
/// bucket. Set to the bucket's custom domain (recommended) or its
/// public r2.dev URL, with NO trailing slash. Empty = not configured
/// yet; keep it empty rather than inventing a domain.
const String r2PublicBaseUrl = 'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev';

/// R2 object key per VIP level — clean names uploaded by
/// cloudflare-r2-upload.sh into bucket "darkvibex-files".
/// Mirrors vehicle_catalog.js (video_key per entry).
const Map<int, String> animalVideoKeys = <int, String>{
  5: 'vehicles/vip5-deer.mp4',
  6: 'vehicles/vip6-wolf.mp4',
  7: 'vehicles/vip7-eagle.mp4',
  8: 'vehicles/vip8-panther.mp4',
  9: 'vehicles/vip9-cobra.mp4',
  10: 'vehicles/vip10-lion.mp4',
  11: 'vehicles/vip11-tiger.mp4',
  12: 'vehicles/vip12-mammoth.mp4',
  13: 'vehicles/vip13-gorilla.mp4',
  14: 'vehicles/vip14-bear.mp4',
  15: 'vehicles/vip15-kraken.mp4',
  16: 'vehicles/vip16-leviathan.mp4',
  17: 'vehicles/vip17-phoenix.mp4',
  18: 'vehicles/vip18-dragon.mp4',
};

/// True once r2PublicBaseUrl has been set to the real public URL.
bool get isR2Configured => r2PublicBaseUrl.trim().isNotEmpty;

/// Full DIRECT R2 URL for a VIP level's entry video, or null when
/// R2 is not configured yet (or the level has no vehicle). This is
/// the URL to feed to VideoPlayerController.networkUrl — never a
/// Worker URL, never a local asset path for the hosted videos.
String? animalVideoUrlForVipLevel(int level) {
  final String? key = animalVideoKeys[level];
  if (key == null || !isR2Configured) return null;
  final String base = r2PublicBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$base/$key';
}

/// Animated anime backdrop theme per VIP level (matches the catalog's
/// backgroundTheme). Used by _paintAnimatedBackground().
const Map<int, String> animalBackgroundThemes = <int, String>{
  5: 'moonlit-forest',
  6: 'moonlit-night-forest',
  7: 'golden-clouds-sky',
  8: 'neon-night-jungle',
  9: 'golden-temple-fire',
  10: 'savanna-sunset',
  11: 'jungle-sunset-fire',
  12: 'snowy-mountain-ice',
  13: 'jungle-gold-earth',
  14: 'pine-forest-fire',
  15: 'stormy-ocean',
  16: 'storm-ocean-lightning',
  17: 'fire-dark-sky',
  18: 'golden-clouds-storm',
};

// ---------------------------------------------------------------------------
// 2. Painter dispatch — call this from _EntryVehiclePainter.paint().
//    `progress` is 0.0-1.0 across the 4.8 s animation. `bob` is a small
//    vertical offset for fly/sail vehicles (sin(progress * pi * 2) * 4).
// ---------------------------------------------------------------------------

void paintVehicle(
  Canvas canvas,
  Size size,
  String styleId,
  double progress,
) {
  final VehicleStyle? style = vehicleStyles[styleId];
  if (style == null) return;
  // Only flying / rising animals bob (fly, rise). Land animals (run) and
  // the striking Cobra stay planted — a running Deer or striking Cobra
  // must not float up and down.
  final double bob = (style.animationType == 'fly' ||
          style.animationType == 'rise')
      ? math.sin(progress * math.pi * 2) * 5.0
      : 0.0;
  final double cx = size.width * 0.5;
  final double cy = size.height * 0.52 + bob;
  final double w = size.width * 0.62;
  final double h = size.height * 0.42;

  // ANIMATED background first: time-driven particles / pulsing glow /
  // rising embers (see _paintAnimatedBackground). The backdrop is
  // animated, never a static picture — positions are a function of
  // `progress`, so it moves across the 4.8 s / 10 s entry.
  // Then the per-style cinematic backdrop, then the vehicle.
  _paintAnimatedBackground(canvas, size, styleId, progress);
  // Cinematic backdrop for EVERY style, painted BEFORE the vehicle:
  // per-style sky/scene (night forest, fire, galaxy, ocean, palace...).
  // _paintCinematicBackdrop() dispatches to _paintYachtBackdrop() for
  // the water animals and _paintPhoenixBackdrop() for the Phoenix.
  _paintCinematicBackdrop(canvas, size, styleId, progress);
  // FALLBACK silhouettes only — the real visual is the animal video.
  // The legacy car painter branches are reused by animal theme (sleek
  // silver for the Deer, winged shapes for the flyers, royal shapes
  // for the big land animals, fire shapes for the fire animals).
  switch (styleId) {
    case 'deer':
      _paintSilverMoonCoupe(canvas, cx, cy, w, h, style, progress);
      break;
    case 'wolf':
      _paintSapphireFalconGT(canvas, cx, cy, w, h, style, progress);
      break;
    case 'eagle':
      _paintSapphireFalconGT(canvas, cx, cy, w, h, style, progress);
      break;
    case 'panther':
      _paintGoldenDragon(canvas, cx, cy, w, h, style, progress);
      break;
    case 'cobra':
      _paintCelestialPhoenix(canvas, cx, cy, w, h, style, progress);
      break;
    case 'lion':
      _paintRoyalLionCarriage(canvas, cx, cy, w, h, style, progress);
      break;
    case 'tiger':
      _paintGoldenDragon(canvas, cx, cy, w, h, style, progress);
      break;
    case 'mammoth':
      _paintRoyalLionCarriage(canvas, cx, cy, w, h, style, progress);
      break;
    case 'gorilla':
      _paintEternalSovereign(canvas, cx, cy, w, h, style, progress);
      break;
    case 'bear':
      _paintRoyalLionCarriage(canvas, cx, cy, w, h, style, progress);
      break;
    case 'kraken':
      _paintDiamondJet(canvas, cx, cy, w, h, style, progress);
      break;
    case 'leviathan':
      _paintDiamondJet(canvas, cx, cy, w, h, style, progress);
      break;
    case 'phoenix':
      _paintPhoenixGT(canvas, cx, cy, w, h, style, progress);
      break;
    case 'dragon':
      _paintInfernoDragon(canvas, cx, cy, w, h, style, progress);
      break;
    default:
      _paintFallbackCoupe(canvas, cx, cy, w, h, style);
      break;
  }
  _paintTrail(canvas, size, style, progress);
}

// ---------------------------------------------------------------------------
// 3. Shared helpers
// ---------------------------------------------------------------------------

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round;

void _paintWheel(Canvas canvas, Offset centre, double radius, Color tyre) {
  canvas.drawCircle(centre, radius, _fill(tyre));
  canvas.drawCircle(centre, radius * 0.55, _fill(const Color(0xFFE8E8E8)));
  canvas.drawCircle(centre, radius * 0.22, _fill(const Color(0xFF333333)));
}

void _paintTrail(Canvas canvas, Size size, VehicleStyle style, double progress) {
  // Fading speed-lines behind the vehicle. Uses only the style colours.
  final Paint trail = _stroke(style.colors[0].withOpacity(0.55), 3);
  for (int i = 0; i < 3; i++) {
    final double y = size.height * (0.35 + i * 0.14);
    final double x0 = size.width * (0.02 + progress * 0.05);
    final double x1 = size.width * (0.16 + i * 0.05);
    canvas.drawLine(Offset(x0, y), Offset(x1, y), trail);
  }
}

Path _flamePath(Offset tip, double length, double width) {
  final Path path = Path();
  path.moveTo(tip.dx, tip.dy);
  path.quadraticBezierTo(
    tip.dx - length * 0.6,
    tip.dy - width,
    tip.dx - length,
    tip.dy,
  );
  path.quadraticBezierTo(
    tip.dx - length * 0.6,
    tip.dy + width,
    tip.dx,
    tip.dy,
  );
  path.close();
  return path;
}

// ---------------------------------------------------------------------------
// 4. New vehicle shapes (distinct from the original file)
// ---------------------------------------------------------------------------

void _paintGoldenDragon(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color gold = style.colors[0];
  final Color orange = style.colors[1];
  final Color pale = style.colors[2];
  // Serpent body: three overlapping ellipses, head to the right.
  for (int i = 0; i < 3; i++) {
    final double x = cx - w * 0.32 + i * w * 0.26;
    final double y = cy + math.sin(progress * 6 + i) * 3.0;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: w * 0.30, height: h * 0.34),
      _fill(i.isEven ? gold : orange),
    );
  }
  // Wing — raised gold triangle with a pale edge.
  final Path wing = Path()
    ..moveTo(cx - w * 0.05, cy - h * 0.10)
    ..lineTo(cx + w * 0.08, cy - h * 0.62)
    ..lineTo(cx + w * 0.28, cy - h * 0.08)
    ..close();
  canvas.drawPath(wing, _fill(gold));
  canvas.drawPath(wing, _stroke(pale, 2));
  // Head, horn and eye.
  canvas.drawCircle(Offset(cx + w * 0.42, cy - h * 0.08), h * 0.22, _fill(gold));
  canvas.drawLine(
    Offset(cx + w * 0.42, cy - h * 0.28),
    Offset(cx + w * 0.48, cy - h * 0.52),
    _stroke(pale, 3),
  );
  canvas.drawCircle(Offset(cx + w * 0.48, cy - h * 0.12), 3, _fill(Colors.black));
  // Flame breath.
  canvas.drawPath(
    _flamePath(Offset(cx + w * 0.52, cy), w * 0.22, h * 0.12),
    _fill(orange),
  );
}

// ---------------------------------------------------------------------------
// Ocean backdrop (was the Luxury Yacht backdrop) — realistic-anime ocean
// scene, now the fallback backdrop for the water animals (Kraken,
// Leviathan). See the STYLE DIRECTION note at the top of this file: this
// is a CustomPaint approximation only. The finished look needs a video
// (video_player) or GLB (model_viewer_plus) asset (see the shot list
// in the STYLE DIRECTION note); this painter is the lightweight
// fallback when no such asset is available. No SVGA/Lottie in the app.
// ---------------------------------------------------------------------------

/// Cinematic backdrop for the Yacht entry: purple storm-cloud sky,
/// orange sunset glow on the horizon, a huge turquoise wave curling
/// behind the yacht, and a deep-blue ocean with sunset reflections.
/// Paint this first, then _paintLuxuryYacht() on top of it.
void _paintYachtBackdrop(Canvas canvas, Size size, double progress) {
  final double w = size.width;
  final double h = size.height;

  // Sunset sky: deep purple at the top -> violet -> orange at horizon.
  final Paint sky = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFF2B1155),
        Color(0xFF6D28A8),
        Color(0xFFC65A8A),
        Color(0xFFFF8C00),
      ],
      stops: <double>[0.0, 0.38, 0.62, 0.78],
    ).createShader(Rect.fromLTWH(0, 0, w, h * 0.62));
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.62), sky);

  // Sun glow, low on the horizon to the right (as in the reference).
  final Paint sunGlow = Paint()
    ..shader = RadialGradient(
      colors: <Color>[
        const Color(0xFFFFF6C8).withOpacity(0.95),
        const Color(0xFFFFBF47).withOpacity(0.55),
        const Color(0xFFFF8C00).withOpacity(0.0),
      ],
    ).createShader(
      Rect.fromCircle(center: Offset(w * 0.78, h * 0.52), radius: w * 0.30),
    );
  canvas.drawCircle(Offset(w * 0.78, h * 0.52), w * 0.30, sunGlow);
  canvas.drawCircle(
    Offset(w * 0.78, h * 0.52),
    w * 0.05,
    _fill(const Color(0xFFFFF3B0)),
  );

  // Purple storm clouds — layered ellipses, darker on top, lit underneath.
  final List<Color> cloudShades = <Color>[
    const Color(0xFF3D1470),
    const Color(0xFF5B2391),
    const Color(0xFF8A4FD0),
  ];
  for (int i = 0; i < 3; i++) {
    final double cy = h * (0.07 + i * 0.09);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * (0.22 + i * 0.26), cy),
        width: w * (0.55 - i * 0.08),
        height: h * 0.10,
      ),
      _fill(cloudShades[i].withOpacity(0.9)),
    );
    // Warm under-light on the lowest cloud, from the sunset.
    if (i == 2) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.74, cy + h * 0.03),
          width: w * 0.34,
          height: h * 0.04,
          ),
        _fill(const Color(0xFFC65A8A).withOpacity(0.55)),
      );
    }
  }

  // Huge turquoise wave curling behind the yacht (upper ocean band).
  final Path wave = Path()
    ..moveTo(0, h * 0.58)
    ..quadraticBezierTo(w * 0.22, h * 0.46, w * 0.42, h * 0.55)
    ..quadraticBezierTo(w * 0.62, h * 0.63, w * 0.82, h * 0.54)
    ..quadraticBezierTo(w * 0.94, h * 0.50, w, h * 0.56)
    ..lineTo(w, h * 0.68)
    ..lineTo(0, h * 0.68)
    ..close();
  final Paint wavePaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFFEAFcff),
        Color(0xFF7FE3F2),
        Color(0xFF00B4D8),
        Color(0xFF0A7BA8),
      ],
    ).createShader(Rect.fromLTWH(0, h * 0.46, w, h * 0.22));
  canvas.drawPath(wave, wavePaint);
  // White crest + spray dots on the wave.
  canvas.drawPath(
    Path()
      ..moveTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.22, h * 0.46, w * 0.42, h * 0.55)
      ..quadraticBezierTo(w * 0.62, h * 0.63, w * 0.82, h * 0.54)
      ..quadraticBezierTo(w * 0.94, h * 0.50, w, h * 0.56),
    _stroke(const Color(0xFFFFFFFF).withOpacity(0.9), 3),
  );
  for (int i = 0; i < 5; i++) {
    canvas.drawCircle(
      Offset(w * (0.12 + i * 0.18), h * (0.52 + (i % 2) * 0.03)),
      2.5,
      _fill(Colors.white.withOpacity(0.85)),
    );
  }

  // Deep-blue ocean below, with sunset reflection and swell lines.
  final Paint sea = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF0A5E8A), Color(0xFF062A44)],
    ).createShader(Rect.fromLTWH(0, h * 0.68, w, h * 0.32));
  canvas.drawRect(Rect.fromLTWH(0, h * 0.68, w, h * 0.32), sea);
  final Paint reflection = Paint()
    ..color = const Color(0xFFFFD27A).withOpacity(0.35)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.72, h * 0.74),
      width: w * 0.30,
      height: h * 0.06,
    ),
    reflection,
  );
  for (int i = 0; i < 3; i++) {
    final double y = h * (0.76 + i * 0.07);
    canvas.drawPath(
      Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(w * 0.25, y - 4, w * 0.5, y)
        ..quadraticBezierTo(w * 0.75, y + 4, w, y),
      _stroke(const Color(0xFF7FE3F2).withOpacity(0.5 - i * 0.12), 2),
    );
  }
  // Animated spray at the bow, driven by progress.
  final double spray = math.sin(progress * math.pi * 2) * 3.0;
  canvas.drawCircle(
    Offset(w * 0.5 + spray, h * 0.70),
    4,
    _fill(Colors.white.withOpacity(0.7)),
  );
}

void _paintRoyalLionCarriage(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color amber = style.colors[0];
  final Color brown = style.colors[1];
  final Color gold = style.colors[2];
  // Lion (front, right): mane circle + face + ears.
  final Offset lion = Offset(cx + w * 0.34, cy - h * 0.05);
  canvas.drawCircle(lion, h * 0.34, _fill(amber));
  canvas.drawCircle(lion, h * 0.22, _fill(gold));
  canvas.drawCircle(Offset(lion.dx - h * 0.16, lion.dy - h * 0.28), h * 0.09, _fill(amber));
  canvas.drawCircle(Offset(lion.dx + h * 0.16, lion.dy - h * 0.28), h * 0.09, _fill(amber));
  canvas.drawCircle(Offset(lion.dx - h * 0.07, lion.dy - h * 0.03), 2.5, _fill(Colors.black));
  canvas.drawCircle(Offset(lion.dx + h * 0.07, lion.dy - h * 0.03), 2.5, _fill(Colors.black));
  // Carriage body (left): arched cabin.
  final Rect cabin = Rect.fromCenter(
    center: Offset(cx - w * 0.18, cy - h * 0.05),
    width: w * 0.42,
    height: h * 0.52,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(cabin, const Radius.circular(14)),
    _fill(brown),
  );
  canvas.drawArc(cabin, math.pi, math.pi, false, _stroke(gold, 3));
  canvas.drawCircle(Offset(cx - w * 0.18, cy - h * 0.05), h * 0.10, _fill(gold));
  // Harness line + wheels.
  canvas.drawLine(
    Offset(cx + w * 0.10, cy),
    Offset(cx + w * 0.22, cy - h * 0.02),
    _stroke(gold, 2.5),
  );
  _paintWheel(canvas, Offset(cx - w * 0.34, cy + h * 0.34), h * 0.17, Colors.black);
  _paintWheel(canvas, Offset(cx - w * 0.02, cy + h * 0.34), h * 0.17, Colors.black);
}

void _paintDiamondJet(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color ice = style.colors[0];
  final Color white = style.colors[1];
  final Color blue = style.colors[2];
  // Fuselage — long diamond-shaped body, nose to the right.
  final Path body = Path()
    ..moveTo(cx - w * 0.48, cy)
    ..lineTo(cx - w * 0.10, cy - h * 0.22)
    ..lineTo(cx + w * 0.46, cy)
    ..lineTo(cx - w * 0.10, cy + h * 0.22)
    ..close();
  canvas.drawPath(body, _fill(ice));
  canvas.drawPath(body, _stroke(white, 2));
  // Delta wing + tail fin.
  final Path wing = Path()
    ..moveTo(cx - w * 0.05, cy)
    ..lineTo(cx - w * 0.28, cy + h * 0.48)
    ..lineTo(cx + w * 0.05, cy + h * 0.10)
    ..close();
  canvas.drawPath(wing, _fill(blue));
  final Path tail = Path()
    ..moveTo(cx - w * 0.38, cy - h * 0.05)
    ..lineTo(cx - w * 0.30, cy - h * 0.48)
    ..lineTo(cx - w * 0.18, cy - h * 0.05)
    ..close();
  canvas.drawPath(tail, _fill(blue));
  // Cockpit diamond + sparkles.
  canvas.drawCircle(Offset(cx + w * 0.22, cy), h * 0.10, _fill(white));
  for (int i = 0; i < 3; i++) {
    final double sx = cx - w * (0.30 - i * 0.12);
    final double sy = cy - h * (0.30 + (i % 2) * 0.18);
    canvas.drawCircle(Offset(sx, sy), 2.5, _fill(white));
  }
}

void _paintInfernoDragon(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color red = style.colors[0];
  final Color orange = style.colors[1];
  final Color ember = style.colors[2];
  // Dark-red body, larger and lower than the Golden Dragon.
  for (int i = 0; i < 3; i++) {
    final double x = cx - w * 0.34 + i * w * 0.28;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, cy + h * 0.08), width: w * 0.32, height: h * 0.38),
      _fill(i == 1 ? red : orange),
    );
  }
  // Bat wing — scalloped edge, drawn as a filled path.
  final Path wing = Path()
    ..moveTo(cx - w * 0.10, cy - h * 0.05)
    ..lineTo(cx - w * 0.02, cy - h * 0.60)
    ..quadraticBezierTo(cx + w * 0.10, cy - h * 0.30, cx + w * 0.18, cy - h * 0.52)
    ..quadraticBezierTo(cx + w * 0.24, cy - h * 0.28, cx + w * 0.34, cy - h * 0.42)
    ..lineTo(cx + w * 0.30, cy - h * 0.02)
    ..close();
  canvas.drawPath(wing, _fill(red));
  // Horned head + glowing eye.
  canvas.drawCircle(Offset(cx + w * 0.42, cy), h * 0.24, _fill(red));
  canvas.drawLine(
    Offset(cx + w * 0.40, cy - h * 0.20),
    Offset(cx + w * 0.34, cy - h * 0.48),
    _stroke(ember, 3),
  );
  canvas.drawLine(
    Offset(cx + w * 0.48, cy - h * 0.20),
    Offset(cx + w * 0.54, cy - h * 0.48),
    _stroke(ember, 3),
  );
  canvas.drawCircle(Offset(cx + w * 0.48, cy - h * 0.04), 3.5, _fill(ember));
  // Inferno breath.
  canvas.drawPath(
    _flamePath(Offset(cx + w * 0.54, cy + h * 0.06), w * 0.26, h * 0.16),
    _fill(orange),
  );
}

void _paintEternalSovereign(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color gold = style.colors[0];
  final Color violet = style.colors[1];
  final Color white = style.colors[2];
  // Sovereign carriage: violet body, gold roof, white trim.
  final Path body = Path()
    ..moveTo(cx - w * 0.44, cy + h * 0.28)
    ..lineTo(cx - w * 0.44, cy - h * 0.10)
    ..quadraticBezierTo(cx, cy - h * 0.52, cx + w * 0.44, cy - h * 0.10)
    ..lineTo(cx + w * 0.44, cy + h * 0.28)
    ..close();
  canvas.drawPath(body, _fill(violet));
  canvas.drawPath(body, _stroke(gold, 3));
  // Crown on top — the VIP18 mark.
  final Path crown = Path()
    ..moveTo(cx - w * 0.16, cy - h * 0.42)
    ..lineTo(cx - w * 0.16, cy - h * 0.66)
    ..lineTo(cx - w * 0.08, cy - h * 0.52)
    ..lineTo(cx, cy - h * 0.72)
    ..lineTo(cx + w * 0.08, cy - h * 0.52)
    ..lineTo(cx + w * 0.16, cy - h * 0.66)
    ..lineTo(cx + w * 0.16, cy - h * 0.42)
    ..close();
  canvas.drawPath(crown, _fill(gold));
  canvas.drawCircle(Offset(cx, cy - h * 0.50), h * 0.07, _fill(white));
  // Windows + wheels.
  for (int i = 0; i < 3; i++) {
    canvas.drawCircle(
      Offset(cx - w * 0.22 + i * w * 0.22, cy + h * 0.02),
      h * 0.09,
      _fill(white),
    );
  }
  _paintWheel(canvas, Offset(cx - w * 0.30, cy + h * 0.36), h * 0.17, Colors.black);
  _paintWheel(canvas, Offset(cx + w * 0.30, cy + h * 0.36), h * 0.17, Colors.black);
}


// ---------------------------------------------------------------------------
// 5. Cinematic backdrops — one per style, painted before the vehicle.
//    These are CustomPaint approximations only (see the STYLE DIRECTION
//    note at the top): the finished realistic-anime look needs a video
//    (video_player) or GLB (model_viewer_plus) asset. No SVGA/Lottie.
// ---------------------------------------------------------------------------

/// ANIMATED anime background — painted first, under everything.
/// `progress` is 0.0-1.0 across the entry animation, so every element
/// moves with time: particles drift (x shifts with progress), the
/// centre glow pulses (radius/opacity = f(sin(progress * 2pi))),
/// embers/flames rise (y = f(progress)), and clouds drift sideways.
/// Never a static picture. Theme colours come from the style's
/// palette; fire themes get rising embers, water themes get rising
/// bubbles, sky themes get drifting stars, land themes get floating
/// light motes.
void _paintAnimatedBackground(
  Canvas canvas,
  Size size,
  String styleId,
  double progress,
) {
  final double w = size.width;
  final double h = size.height;
  // Fire animals (Phoenix, Dragon, Tiger) get ember-orange particles;
  // water animals (Kraken, Leviathan) get aqua particles; the rest get
  // warm gold sparkles.
  final bool isFire = styleId == 'phoenix' ||
      styleId == 'dragon' ||
      styleId == 'tiger';
  final bool isWater = styleId == 'kraken' || styleId == 'leviathan';
  final Color particleColor = isFire
      ? const Color(0xFFFFB300)
      : isWater
          ? const Color(0xFF7FE3F2)
          : const Color(0xFFFFF3B0);
  // Pulsing centre glow — radius and opacity breathe with time.
  final double pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2);
  final Paint glow = Paint()
    ..shader = RadialGradient(
      center: const Alignment(0.5, 0.55),
      radius: 0.55 + pulse * 0.15,
      colors: <Color>[
        particleColor.withOpacity(0.28 + pulse * 0.14),
        particleColor.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glow);
  // Drifting particles — x drifts with progress, y rises with progress.
  for (int i = 0; i < 16; i++) {
    final double x = ((i * 53.0 + 19.0 + progress * w * 0.25) % w);
    final double y = h - ((progress * h * 0.6 + i * 37.0) % h);
    final double r = 1.2 + (i % 3) * 0.9;
    // sin() keeps opacity in 0.05..0.85 — always a valid double.
    final double twinkle = 0.45 + 0.4 * math.sin(progress * math.pi * 4 + i);
    canvas.drawCircle(
      Offset(x, y),
      r,
      _fill(particleColor.withOpacity(twinkle)),
    );
  }
  // Drifting cloud band — two soft ellipses sliding sideways with time.
  final double drift = (progress * w * 0.12) % (w * 0.3);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.25 + drift, h * 0.14),
      width: w * 0.42,
      height: h * 0.08,
    ),
    _fill(Colors.white.withOpacity(0.10 + pulse * 0.06)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(w * 0.75 - drift, h * 0.22),
      width: w * 0.36,
      height: h * 0.07,
    ),
    _fill(Colors.white.withOpacity(0.08 + pulse * 0.05)),
  );
}

/// Dispatches to the per-style backdrop. Called for EVERY style from
/// paintVehicle(), before the vehicle itself is drawn.
void _paintCinematicBackdrop(
  Canvas canvas,
  Size size,
  String styleId,
  double progress,
) {
  // Backdrop by the animal's backgroundTheme (vehicle_entry_animals.js):
  // night forest / night sky for the night animals, fire for the fire
  // animals, galaxy for the storm-ocean animals, sky for the flyers and
  // the ice Mammoth, gold for the royal land animals.
  switch (styleId) {
    case 'kraken':
    case 'leviathan':
      _paintYachtBackdrop(canvas, size, progress);
      break;
    case 'phoenix':
      _paintPhoenixBackdrop(canvas, size, progress);
      break;
    case 'tiger':
    case 'dragon':
      _paintFireBackdrop(canvas, size, progress, const Color(0xFFFFC400));
      break;
    case 'panther':
      _paintGalaxyBackdrop(canvas, size, progress);
      break;
    case 'eagle':
    case 'mammoth':
      _paintSkyBackdrop(canvas, size, progress);
      break;
    case 'deer':
    case 'wolf':
    case 'cobra':
      _paintNightSkyBackdrop(canvas, size, progress, styleId);
      break;
    case 'lion':
    case 'gorilla':
    case 'bear':
      _paintGoldenBackdrop(canvas, size, progress, styleId);
      break;
  }
}

void _paintStars(Canvas canvas, Size size, int count, double maxRadius) {
  final Paint star = _fill(Colors.white);
  for (int i = 0; i < count; i++) {
    final double x = (i * 67.0 + 31.0) % size.width;
    final double y = (i * 113.0 + 17.0) % (size.height * 0.6);
    canvas.drawCircle(Offset(x, y), 0.8 + (i % 3) * 0.5, star);
  }
  // maxRadius is kept for callers that scale sparkle size; stars here
  // stay small so they read as a night sky, not as snow.
  assert(maxRadius > 0);
}

/// Phoenix backdrop — matches the reference video (frames phoenix-02s /
/// phoenix-04s / phoenix-06s): near-black sky, warm fire glow in the
/// centre, flame wisps curling at the edges, and embers rising.
void _paintPhoenixBackdrop(Canvas canvas, Size size, double progress) {
  final double w = size.width;
  final double h = size.height;
  final Paint sky = Paint()
    ..shader = const RadialGradient(
      center: Alignment(0.5, 0.45),
      radius: 0.75,
      colors: <Color>[
        Color(0xFF5A1200),
        Color(0xFF2A0A06),
        Color(0xFF0A0508),
      ],
      stops: <double>[0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);
  // Flame wisps at the top and bottom edges, blurred by layering.
  for (int i = 0; i < 3; i++) {
    final Path wisp = Path()
      ..moveTo(w * (0.05 + i * 0.35), h * 0.06)
      ..quadraticBezierTo(
        w * (0.20 + i * 0.30), h * 0.02, w * (0.35 + i * 0.30), h * 0.08);
    canvas.drawPath(
      wisp,
      _stroke(Color(0xFFFF6D00).withOpacity(0.5 - i * 0.12), 4),
    );
  }
  // Embers rising — small gold dots, drifting up with progress.
  for (int i = 0; i < 12; i++) {
    final double x = (i * 53.0 + 19.0) % w;
    final double y = h - ((progress * h * 0.5 + i * 37.0) % h);
    canvas.drawCircle(
      Offset(x, y),
      1.5 + (i % 3) * 0.8,
      _fill(Color(0xFFFFB300).withOpacity(0.75)),
    );
  }
}

void _paintFireBackdrop(
  Canvas canvas,
  Size size,
  double progress,
  Color glow,
) {
  final Paint sky = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        const Color(0xFF1A0500),
        const Color(0xFF7F0000),
        glow.withOpacity(0.35),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sky);
  _paintPhoenixBackdrop(canvas, size, progress);
}

void _paintGalaxyBackdrop(Canvas canvas, Size size, double progress) {
  final Paint sky = Paint()
    ..shader = const RadialGradient(
      center: Alignment(0.5, 0.4),
      radius: 0.8,
      colors: <Color>[Color(0xFF4A1A8A), Color(0xFF2A1060), Color(0xFF0B0626)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sky);
  _paintStars(canvas, size, 22, 2);
  // Nebula blobs, violet + cyan.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(size.width * 0.75, size.height * 0.25),
      width: size.width * 0.4,
      height: size.height * 0.16,
    ),
    _fill(const Color(0xFF7B2FFF).withOpacity(0.35)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(size.width * 0.25, size.height * 0.2),
      width: size.width * 0.3,
      height: size.height * 0.12,
    ),
    _fill(const Color(0xFF00E5FF).withOpacity(0.25)),
  );
}

void _paintSkyBackdrop(Canvas canvas, Size size, double progress) {
  final Paint sky = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF062A44), Color(0xFF0A5E8A), Color(0xFF7FD4F2)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sky);
  _paintStars(canvas, size, 10, 2);
  // Cloud puffs, white with blue shade.
  for (int i = 0; i < 3; i++) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * (0.2 + i * 0.3), size.height * (0.18 + i * 0.08)),
        width: size.width * 0.28,
        height: size.height * 0.10,
      ),
      _fill(Colors.white.withOpacity(0.55)),
    );
  }
}

void _paintNightSkyBackdrop(
  Canvas canvas,
  Size size,
  double progress,
  String styleId,
) {
  final Paint sky = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF060A1E), Color(0xFF1A3A6E)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sky);
  _paintStars(canvas, size, 18, 2);
  if (styleId == 'deer') {
    // Full moon, low right — the Deer's moonlit-forest light source.
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.20),
      size.width * 0.07,
      _fill(const Color(0xFFFFF3B0)),
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.20),
      size.width * 0.10,
      _fill(const Color(0xFFFFF3B0).withOpacity(0.18)),
    );
  }
  if (styleId == 'wolf') {
    // Comet streak across the top of the frame.
    canvas.drawLine(
      Offset(size.width * 0.95, size.height * 0.08),
      Offset(size.width * 0.55, size.height * 0.30),
      _stroke(const Color(0xFF00F0FF).withOpacity(0.8), 3),
    );
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.08),
      5,
      _fill(Colors.white),
    );
  }
}

void _paintGoldenBackdrop(
  Canvas canvas,
  Size size,
  double progress,
  String styleId,
) {
  final Paint sky = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF241A02), Color(0xFF5A3A00), Color(0xFF8A6300)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sky);
  // Palace columns at the edges for the Lion/Bear; jungle trees
  // (dark green circles) for the Gorilla.
  if (styleId == 'gorilla') {
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.08 + i * 0.42), size.height * 0.18),
        size.height * 0.12,
        _fill(const Color(0xFF0A2A16).withOpacity(0.85)),
      );
    }
  } else {
    for (final double x in <double>[size.width * 0.05, size.width * 0.95]) {
      canvas.drawRect(
        Rect.fromLTWH(x - 6, size.height * 0.05, 12, size.height * 0.9),
        _fill(const Color(0xFF5A3A00)),
      );
      canvas.drawRect(
        Rect.fromLTWH(x - 10, size.height * 0.05, 20, 8),
        _fill(const Color(0xFFFFD700)),
      );
    }
  }
  // Warm light pooling on the floor.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.88),
      width: size.width * 0.7,
      height: size.height * 0.12,
    ),
    _fill(const Color(0xFFFFD700).withOpacity(0.18)),
  );
}

// ---------------------------------------------------------------------------
// 6. New phoenix + lower-tier vehicle shapes
// ---------------------------------------------------------------------------

/// Phoenix — layered-feather phoenix, based on the reference video.
/// Wings spread wide, head front-on with glowing orange eyes, flame
/// crest, body of layered red/gold feathers, long golden tail feathers.
void _paintPhoenixGT(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color red = style.colors[0];
  final Color orange = style.colors[1];
  final Color gold = style.colors[2];
  // Wings spread wide — layered feather rows, red -> orange -> gold tips.
  for (int side = -1; side <= 1; side += 2) {
    for (int row = 0; row < 3; row++) {
      final Path wing = Path()
        ..moveTo(cx + side * w * 0.05, cy - h * 0.05)
        ..quadraticBezierTo(
          cx + side * w * (0.30 + row * 0.08), cy - h * (0.30 + row * 0.08),
          cx + side * w * 0.48, cy + h * (0.02 - row * 0.06))
        ..quadraticBezierTo(
          cx + side * w * 0.28, cy + h * 0.14,
          cx + side * w * 0.05, cy - h * 0.05)
        ..close();
      canvas.drawPath(
        wing,
        _fill(row == 0 ? red : row == 1 ? orange : gold),
      );
    }
  }
  // Body — layered feather ellipses, red with gold centres.
  for (int i = 0; i < 3; i++) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + h * (0.05 + i * 0.12)),
        width: w * (0.30 - i * 0.04),
        height: h * 0.22,
      ),
      _fill(i.isEven ? red : orange),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + h * (0.05 + i * 0.12)),
        width: w * 0.16,
        height: h * 0.12,
      ),
      _fill(gold.withOpacity(0.7)),
    );
  }
  // Head — front-on, glowing orange eyes, gold beak, flame crest.
  canvas.drawCircle(Offset(cx, cy - h * 0.28), h * 0.22, _fill(red));
  final Path crest = Path()
    ..moveTo(cx - w * 0.06, cy - h * 0.42)
    ..lineTo(cx, cy - h * 0.72)
    ..lineTo(cx + w * 0.06, cy - h * 0.42)
    ..close();
  canvas.drawPath(crest, _fill(orange));
  canvas.drawPath(crest, _stroke(gold, 2));
  canvas.drawCircle(Offset(cx - w * 0.05, cy - h * 0.30), 4, _fill(gold));
  canvas.drawCircle(Offset(cx + w * 0.05, cy - h * 0.30), 4, _fill(gold));
  canvas.drawCircle(Offset(cx - w * 0.05, cy - h * 0.30), 1.8, _fill(Colors.black));
  canvas.drawCircle(Offset(cx + w * 0.05, cy - h * 0.30), 1.8, _fill(Colors.black));
  canvas.drawPath(
    Path()
      ..moveTo(cx - w * 0.04, cy - h * 0.22)
      ..lineTo(cx, cy - h * 0.08)
      ..lineTo(cx + w * 0.04, cy - h * 0.22)
      ..close(),
    _fill(gold),
  );
  // Long golden tail feathers streaming down-left and down-right.
  for (int i = 0; i < 3; i++) {
    final double dir = i == 1 ? 0.0 : (i == 0 ? -1.0 : 1.0);
    final Path tail = Path()
      ..moveTo(cx + dir * w * 0.04, cy + h * 0.30)
      ..quadraticBezierTo(
        cx + dir * w * 0.22, cy + h * 0.55,
        cx + dir * w * 0.34, cy + h * 0.78)
      ..quadraticBezierTo(
        cx + dir * w * 0.16, cy + h * 0.58,
        cx + dir * w * 0.04, cy + h * 0.30)
      ..close();
    canvas.drawPath(tail, _fill(i == 1 ? gold : orange));
  }
}

/// Celestial phoenix shape — same layered-feather structure as the
/// Phoenix, in violet/cyan starlight colours instead of fire colours.
/// (Fallback silhouette for the Cobra.)
void _paintCelestialPhoenix(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  // Reuse the Phoenix GT geometry by painting with the celestial
  // palette: violet body, cyan wings, pale-lilac tail. The painter
  // below mirrors _paintPhoenixGT with the style colours swapped.
  final VehicleStyle fireStyle = VehicleStyle(
    styleId: style.styleId,
    name: style.name,
    minVip: style.minVip,
    tier: style.tier,
    colors: <Color>[style.colors[0], style.colors[1], style.colors[2]],
    animationType: style.animationType,
  );
  _paintPhoenixGT(canvas, cx, cy, w, h, fireStyle, progress);
  // Star sparkles on the wings, in cyan.
  for (int i = 0; i < 4; i++) {
    canvas.drawCircle(
      Offset(cx - w * 0.30 + i * w * 0.20, cy - h * 0.18),
      2.5,
      _fill(const Color(0xFF00E5FF)),
    );
  }
}

void _paintSilverMoonCoupe(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color silver = style.colors[0];
  final Color blue = style.colors[1];
  final Color moon = style.colors[2];
  final RRect body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: w * 0.72, height: h * 0.42),
    const Radius.circular(12),
  );
  canvas.drawRRect(body, _fill(silver));
  canvas.drawRRect(body, _stroke(blue, 2));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx + w * 0.05, cy - h * 0.12), width: w * 0.30, height: h * 0.18),
      const Radius.circular(6),
    ),
    _fill(blue),
  );
  // Glowing headlights — moon-yellow beams to the right.
  canvas.drawCircle(Offset(cx + w * 0.36, cy + h * 0.05), h * 0.07, _fill(moon));
  canvas.drawPath(
    Path()
      ..moveTo(cx + w * 0.36, cy)
      ..lineTo(cx + w * 0.62, cy - h * 0.10)
      ..lineTo(cx + w * 0.62, cy + h * 0.18)
      ..close(),
    _fill(moon.withOpacity(0.25)),
  );
  _paintWheel(canvas, Offset(cx - w * 0.22, cy + h * 0.28), h * 0.15, Colors.black);
  _paintWheel(canvas, Offset(cx + w * 0.22, cy + h * 0.28), h * 0.15, Colors.black);
}

void _paintSapphireFalconGT(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
  double progress,
) {
  final Color sapphire = style.colors[0];
  final Color sky = style.colors[1];
  final Color ice = style.colors[2];
  // Falcon wings rising from the GT body.
  for (int side = -1; side <= 1; side += 2) {
    final Path wing = Path()
      ..moveTo(cx + side * w * 0.05, cy)
      ..lineTo(cx + side * w * 0.22, cy - h * 0.55)
      ..lineTo(cx + side * w * 0.40, cy - h * 0.10)
      ..close();
    canvas.drawPath(wing, _fill(sky));
    canvas.drawPath(wing, _stroke(ice, 2));
  }
  final RRect body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy + h * 0.05), width: w * 0.68, height: h * 0.40),
    const Radius.circular(12),
  );
  canvas.drawRRect(body, _fill(sapphire));
  canvas.drawRRect(body, _stroke(ice, 2));
  canvas.drawCircle(Offset(cx + w * 0.30, cy + h * 0.05), h * 0.08, _fill(ice));
  _paintWheel(canvas, Offset(cx - w * 0.20, cy + h * 0.32), h * 0.14, Colors.black);
  _paintWheel(canvas, Offset(cx + w * 0.20, cy + h * 0.32), h * 0.14, Colors.black);
}

void _paintFallbackCoupe(
  Canvas canvas,
  double cx,
  double cy,
  double w,
  double h,
  VehicleStyle style,
) {
  // Used only if a new style_id is added without a dedicated branch.
  // Keeps the room from showing a blank entry.
  final RRect body = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: w * 0.72, height: h * 0.42),
    const Radius.circular(12),
  );
  canvas.drawRRect(body, _fill(style.colors[0]));
  _paintWheel(canvas, Offset(cx - w * 0.22, cy + h * 0.28), h * 0.15, Colors.black);
  _paintWheel(canvas, Offset(cx + w * 0.22, cy + h * 0.28), h * 0.15, Colors.black);
}
