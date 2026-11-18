// DarkVibeX — VIP visual assets (frames, entry effects, tags).
//
// Pure Dart (no Flutter import): level -> R2 URL mappings for the three
// R2-hosted VIP visual sets, plus the resolver that turns a worker asset
// key into a playable/displayable URL.
//
// R2 bucket "darkvibex-files", public base:
//   https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev
// The Worker's /api/files endpoint REJECTS these prefixes (400
// invalid_file_key) — its allowlist is only users/rooms/messages/
// custom-gifts/room-themes/banners/custom-assets/creator-assets. So the
// app must NEVER pass a frames/, entry-effects/, vip-tags/, vehicles/ or
// vap/ key through backend.fileUrl(); use resolveVipVisualAssetUrl()
// instead, which builds the direct R2 URL for those prefixes and falls
// back to fileUrl() for everything else (user avatars, custom uploads).
//
// FRAMES — one transparent animal frame per VIP level 5-18:
//   vap:   vap/vip<N>-<animal>.mp4 (Tencent VAP v1: H.264, alpha mask on
//          the LEFT half, RGB on the RIGHT half of each frame) — the
//          ANIMATED frame the app plays (VipFrameAlphaVideo).
//   video: frames/vip<N>-<animal>-transparent.webm (VP9 WITH alpha) —
//          source for the VAP conversion; NOT played in the app.
//   still: frames/vip<N>-<animal>-transparent.png (transparent PNG) —
//          fallback/poster: shown while the VAP loads, and after the 5 s
//          animation finishes (it plays once, then ends calmly).
// WEBM-ALPHA LIMITATION: Flutter's video_player (ExoPlayer on Android)
// renders video to an OPAQUE texture — it does not carry the VP9 alpha
// channel, so a transparent WebM played through it shows a BLACK box.
// Do NOT feed the WebM to video_player. The animated path is the VAP mp4
// via flutter_vap_player (VapPlayerController.networkUrl with
// enableOldVersion: true). The PNG still is the fallback, never a black
// box: VipFrameAlphaVideo shows the still while the VAP loads and swaps
// back to it if the video errors or finishes.
//
// ENTRY EFFECTS — one wide banner per VIP level 5-18:
//   entry-effects/vip<N>-entry.png (transparent background, transparent
//   DP circle on the left, animal on the right). The DP circle is NOT in
//   the same place on every banner — its centre/diameter were measured
//   from the PNGs (2026-11-18) and are stored per level below
//   (EntryEffectCircle: fractions of image width/height). Do not guess
//   one position for all levels.
//
// TAGS — one golden tag per VIP level 5-18:
//   vip-tags/vip<N>-tag.png (transparent background). A pure level badge:
//   never equipped, never bought. Shown wherever the VIP level is
//   displayed (chat sender name, seat, profile VIP badge), auto-sized
//   to the row it sits in.
//
// SIZING (Vinay, 2026-11-18): frames and tags must SCALE automatically
// with the seat/DP/chat avatar they sit on — never a fixed size per
// place, and the caller must not pass a manual size per seat. The frame
// widget reads its size from its child avatar at runtime
// (VipAnimatedFrame.auto, LayoutBuilder) and the ring/gems/head/plate
// scale proportionally (they are all fractions of the frame size).
// Entry banners size to the room width (aspect ratio per level below).

/// Public base URL of the "darkvibex-files" R2 bucket. No trailing slash.
const String kVipVisualR2PublicBaseUrl =
    'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev';

/// R2 key prefixes that must be played/displayed DIRECTLY from R2.
/// Anything else goes through backend.fileUrl() as before.
const List<String> kDirectR2AssetPrefixes = <String>[
  'frames/',
  'entry-effects/',
  'vip-tags/',
  'vehicles/',
  'vap/',
];

/// True when [key] is a direct-R2 asset key (never send it to /api/files).
bool isDirectR2AssetKey(String key) {
  final String trimmed = key.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return true;
  }
  for (final String prefix in kDirectR2AssetPrefixes) {
    if (trimmed.startsWith(prefix)) return true;
  }
  return false;
}

/// Turns a worker asset key into a URL the app can load:
/// - full http(s) URL -> used as-is (already a direct R2 URL);
/// - frames//entry-effects//vip-tags//vehicles//vap/ key -> direct R2 URL;
/// - anything else -> fileUrl(key) (Worker /api/files, e.g. user avatars).
/// [fileUrl] is backend.fileUrl — passed in so this file stays pure Dart.
String resolveVipVisualAssetUrl(
  String key,
  String Function(String key) fileUrl,
) {
  final String trimmed = key.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (isDirectR2AssetKey(trimmed)) {
    return '$kVipVisualR2PublicBaseUrl/$trimmed';
  }
  return fileUrl(trimmed);
}

// ---------------------------------------------------------------------------
// Frames (VIP5-18)
// ---------------------------------------------------------------------------

/// Animal per VIP level (VIP1-4 have no animal frame).
const Map<int, String> vipFrameAnimals = <int, String>{
  5: 'deer',
  6: 'wolf',
  7: 'eagle',
  8: 'panther',
  9: 'cobra',
  10: 'lion',
  11: 'tiger',
  12: 'mammoth',
  13: 'gorilla',
  14: 'bear',
  15: 'kraken',
  16: 'leviathan',
  17: 'phoenix',
  18: 'dragon',
};

/// R2 key of the transparent WebM per level.
Map<int, String> get vipFrameVideoKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipFrameAnimals.entries)
        entry.key:
            'frames/vip${entry.key}-${entry.value}-transparent.webm',
    };

/// R2 key of the transparent PNG still per level.
Map<int, String> get vipFrameStillKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipFrameAnimals.entries)
        entry.key:
            'frames/vip${entry.key}-${entry.value}-transparent.png',
    };

/// Direct R2 URL of the transparent WebM frame for [level], or null
/// for VIP1-4 / out of range. For a future alpha-capable player only —
/// do NOT feed this to video_player (opaque texture, black box).
String? vipFrameVideoUrlForVipLevel(int level) {
  final String? key = vipFrameVideoKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Direct R2 URL of the transparent PNG still for [level], or null for
/// VIP1-4 / out of range. This is the frame image the app displays.
String? vipFrameStillUrlForVipLevel(int level) {
  final String? key = vipFrameStillKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// R2 key of the Tencent VAP mp4 per level (the animated frame).
Map<int, String> get vipFrameVapKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipFrameAnimals.entries)
        entry.key: 'vap/vip${entry.key}-${entry.value}.mp4',
    };

/// Direct R2 URL of the Tencent VAP mp4 for [level], or null for VIP1-4 /
/// out of range. Played by VipFrameAlphaVideo (flutter_vap_player,
/// enableOldVersion: true — VAP v1, alpha on the LEFT half of the frame).
String? vipFrameVapUrlForVipLevel(int level) {
  final String? key = vipFrameVapKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// VAP video URL for the frame actually being displayed, or null when the
/// frame has no VAP video.
///
/// A VAP video exists ONLY for the ANIMAL frame (VIP5-18). It is used
/// when the displayed still IS the animal still: [assetKey] is the
/// member's active_frame_asset_key — the animal still key, or empty (no
/// frame configured, so the caller falls back to the animal still).
/// A custom/Owner frame has no VAP video, so this returns null and the
/// caller shows the PNG still only. Never guess a VAP URL for a custom
/// frame — that would play the wrong animal's animation over it.
String? vipFrameVapUrlForDisplay(String? assetKey, int level) {
  final String? stillKey = vipFrameStillKeys[level];
  if (stillKey == null) return null; // VIP1-4 / out of range: no animal frame.
  final String key = (assetKey ?? '').trim();
  if (key.isEmpty || key == stillKey) {
    return vipFrameVapUrlForVipLevel(level);
  }
  return null; // Custom/Owner frame: PNG still only, no VAP video.
}

// ---------------------------------------------------------------------------
// Entry effects (VIP5-18)
// ---------------------------------------------------------------------------

/// R2 key of the entry banner PNG per level.
Map<int, String> get vipEntryEffectKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipFrameAnimals.entries)
        entry.key: 'entry-effects/vip${entry.key}-entry.png',
    };

/// Direct R2 URL of the entry banner for [level], or null for VIP1-4.
String? vipEntryEffectUrlForVipLevel(int level) {
  final String? key = vipEntryEffectKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Transparent DP circle inside an entry banner, as fractions of the
/// banner image (measured from the PNGs, 2026-11-18 — the circle sits
/// in a different place on each banner, so this is per level).
class EntryEffectCircle {
  const EntryEffectCircle({
    required this.centerX,
    required this.centerY,
    required this.diameter,
  });

  /// Circle centre x as a fraction of image width.
  final double centerX;

  /// Circle centre y as a fraction of image height.
  final double centerY;

  /// Circle diameter as a fraction of image height.
  final double diameter;
}

/// Width / height of each banner image (measured from the PNGs).
const Map<int, double> vipEntryEffectAspectRatios = <int, double>{
  5: 3.989,
  6: 2.642,
  7: 2.762,
  8: 3.276,
  9: 2.516,
  10: 2.695,
  11: 3.287,
  12: 2.945,
  13: 2.892,
  14: 2.432,
  15: 2.353,
  16: 2.670,
  17: 2.475,
  18: 3.197,
};

/// DP circle geometry per level (measured from the PNGs, 2026-11-18).
const Map<int, EntryEffectCircle> vipEntryEffectCircles =
    <int, EntryEffectCircle>{
  5: EntryEffectCircle(centerX: 0.097, centerY: 0.460, diameter: 0.638),
  6: EntryEffectCircle(centerX: 0.148, centerY: 0.474, diameter: 0.597),
  7: EntryEffectCircle(centerX: 0.160, centerY: 0.449, diameter: 0.580),
  8: EntryEffectCircle(centerX: 0.130, centerY: 0.429, diameter: 0.539),
  9: EntryEffectCircle(centerX: 0.161, centerY: 0.414, diameter: 0.499),
  10: EntryEffectCircle(centerX: 0.129, centerY: 0.514, diameter: 0.533),
  11: EntryEffectCircle(centerX: 0.126, centerY: 0.492, diameter: 0.615),
  12: EntryEffectCircle(centerX: 0.155, centerY: 0.505, diameter: 0.471),
  13: EntryEffectCircle(centerX: 0.123, centerY: 0.514, diameter: 0.380),
  14: EntryEffectCircle(centerX: 0.174, centerY: 0.549, diameter: 0.475),
  15: EntryEffectCircle(centerX: 0.148, centerY: 0.493, diameter: 0.353),
  16: EntryEffectCircle(centerX: 0.133, centerY: 0.533, diameter: 0.392),
  17: EntryEffectCircle(centerX: 0.127, centerY: 0.528, diameter: 0.468),
  18: EntryEffectCircle(centerX: 0.121, centerY: 0.533, diameter: 0.434),
};

// ---------------------------------------------------------------------------
// Tags (VIP5-18)
// ---------------------------------------------------------------------------

/// R2 key of the golden tag PNG per level.
Map<int, String> get vipTagKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipFrameAnimals.entries)
        entry.key: 'vip-tags/vip${entry.key}-tag.png',
    };

/// Direct R2 URL of the golden tag for [level], or null for VIP1-4.
String? vipTagUrlForVipLevel(int level) {
  final String? key = vipTagKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}
