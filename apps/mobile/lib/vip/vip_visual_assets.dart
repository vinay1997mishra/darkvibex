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
// FRAMES — one transparent animal frame per VIP level 1-18:
//   vap:   vap/vip<N>-<animal>.mp4 (Tencent VAP v1: H.264, alpha mask on
//          the LEFT half, RGB on the RIGHT half of each frame) — the
//          ANIMATED frame the app plays (VipFrameAlphaVideo). VIP5-18
//          only; VIP1-4 frames are static PNG stills (no VAP).
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
// ENTRY EFFECTS — one wide banner per VIP level 1-18:
//   entry-effects/vip<N>-entry.png (transparent background, transparent
//   DP circle on the left, animal on the right). The VIP3 banner is a
//   full-bleed scene (only the DP circle is transparent); the VIP4
//   banner is the thin slim gold bar (no text). The DP circle is NOT in
//   the same place on every banner — its centre/diameter were measured
//   from the PNGs (2026-11-18) and are stored per level below
//   (EntryEffectCircle: fractions of image width/height). Do not guess
//   one position for all levels.
//
// TAGS — one golden tag per VIP level 1-18:
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
  'vip-medals/',
  'profile-banners/',
  'profile-card-anims/',
  'profile-card-stills/',
  'vehicles/',
  'vap/',
  'gift-ribbons/',
  'vip-badges/',
  'rocket-medals/',
  'medals/',
  'seat-emotes/panda/vap/',
  'seat-emotes/panda/thumbs/',
  'greedy-girl/',
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
// Frames (VIP1-18)
// ---------------------------------------------------------------------------

/// Animal per VIP level for FRAMES. VIP1 = black cat, VIP2 = swan,
/// VIP3 = dolphin, VIP4 = fox (Vinay, 2026-11-19), VIP5-18 as before.
/// VIP1-4 frames are STATIC transparent PNG stills (no WebM, no VAP) —
/// see vipAnimatedFrameAnimals below.
const Map<int, String> vipFrameAnimals = <int, String>{
  1: 'cat',
  2: 'swan',
  3: 'dolphin',
  4: 'fox',
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

/// Animal per VIP level for ANIMATED frames (WebM + VAP video exist).
/// VIP1-4 have no animated frame — only the static PNG still.
const Map<int, String> vipAnimatedFrameAnimals = <int, String>{
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

/// R2 key of the transparent WebM per level (animated frames only).
Map<int, String> get vipFrameVideoKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipAnimatedFrameAnimals.entries)
        entry.key:
            'frames/vip${entry.key}-${entry.value}-transparent.webm',
    };

/// R2 key of the transparent PNG still per level.
Map<int, String> get vipFrameStillKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipFrameAnimals.entries)
        entry.key:
            'frames/vip${entry.key}-${entry.value}-transparent.png',
    };

/// VIP13 SECOND frame (Vinay's own design, 2026-11-20): the gorilla
/// second design (green energy, armored ring, VIP 13 plate). Same three
/// R2 files as the animal frames, under second-frame keys. The level-13
/// animal frame stays the default; this variant is selected by id
/// (Owner vip_rule frame_id = "vip-frame-13-second").
const String vip13SecondFrameStillKey =
    'frames/vip13-gorilla-second-frame-transparent.png';
const String vip13SecondFrameVapKey =
    'vap/vip13-gorilla-second-frame.mp4';
const String vip13SecondFrameVideoKey =
    'frames/vip13-gorilla-second-frame-transparent.webm';

/// Direct R2 URL of the VIP13 second frame's PNG still.
String get vip13SecondFrameStillUrl =>
    '$kVipVisualR2PublicBaseUrl/$vip13SecondFrameStillKey';

/// Direct R2 URL of the VIP13 second frame's VAP mp4.
String get vip13SecondFrameVapUrl =>
    '$kVipVisualR2PublicBaseUrl/$vip13SecondFrameVapKey';

/// Direct R2 URL of the transparent WebM frame for [level], or null
/// for VIP1-4 (static stills only) / out of range. For a future
/// alpha-capable player only — do NOT feed this to video_player
/// (opaque texture, black box).
String? vipFrameVideoUrlForVipLevel(int level) {
  final String? key = vipFrameVideoKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Direct R2 URL of the transparent PNG still for [level], or null for
/// out of range. This is the frame image the app displays. VIP1-4 show
/// this still only (no VAP video exists for them).
String? vipFrameStillUrlForVipLevel(int level) {
  final String? key = vipFrameStillKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// R2 key of the Tencent VAP mp4 per level (the animated frame).
/// Animated frames exist for VIP5-18 only.
Map<int, String> get vipFrameVapKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipAnimatedFrameAnimals.entries)
        entry.key: 'vap/vip${entry.key}-${entry.value}.mp4',
    };

/// Direct R2 URL of the Tencent VAP mp4 for [level], or null for VIP1-4
/// (static stills only) / out of range. Played by VipFrameAlphaVideo
/// (flutter_vap_player, enableOldVersion: true — VAP v1, alpha on the
/// LEFT half of the frame).
String? vipFrameVapUrlForVipLevel(int level) {
  final String? key = vipFrameVapKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// VAP video URL for the frame actually being displayed, or null when the
/// frame has no VAP video.
///
/// A VAP video exists ONLY for the ANIMAL frame (VIP5-18) and for the
/// VIP13 SECOND frame (same design family, selected by its own still
/// key). It is used when the displayed still IS the animal still (or the
/// second-frame still): [assetKey] is the member's
/// active_frame_asset_key — the animal still key, the second-frame still
/// key, or empty (no frame configured, so the caller falls back to the
/// animal still).
/// A custom/Owner frame has no VAP video, so this returns null and the
/// caller shows the PNG still only. Never guess a VAP URL for a custom
/// frame — that would play the wrong animal's animation over it.
String? vipFrameVapUrlForDisplay(String? assetKey, int level) {
  final String? stillKey = vipFrameStillKeys[level];
  if (stillKey == null) return null; // Out of range: no animal frame.
  final String key = (assetKey ?? '').trim();
  // VIP13 second frame (Vinay's design): it has its own VAP video,
  // played when the displayed still IS the second-frame still.
  if (level == 13 && key == vip13SecondFrameStillKey) {
    return vip13SecondFrameVapUrl;
  }
  if (key.isEmpty || key == stillKey) {
    // VIP1-4 have no VAP video (static stills) — this returns null and
    // the caller shows the PNG still only.
    return vipFrameVapUrlForVipLevel(level);
  }
  return null; // Custom/Owner frame: PNG still only, no VAP video.
}

// ---------------------------------------------------------------------------
// Entry effects (VIP1-18)
// ---------------------------------------------------------------------------

/// Animal per VIP level for ENTRY banners. VIP1 = black cat, VIP2 = swan,
/// VIP3 = dolphin, VIP4 = fox (Vinay, 2026-11-19), VIP5-18 as before.
/// NOTE: the VIP3 banner is a full-bleed scene (only the DP circle is
/// transparent); VIP1/VIP2/VIP4/VIP5-18 are transparent cutouts. The
/// VIP4 banner is the THIN slim gold bar (no text).
const Map<int, String> vipEntryEffectAnimals = <int, String>{
  1: 'cat',
  2: 'swan',
  3: 'dolphin',
  4: 'fox',
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

/// R2 key of the entry banner PNG per level.
Map<int, String> get vipEntryEffectKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipEntryEffectAnimals.entries)
        entry.key: 'entry-effects/vip${entry.key}-entry.png',
    };

/// Direct R2 URL of the entry banner for [level], or null for out of range.
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
/// VIP1/VIP2 are 2624x1472 (1.783), VIP3 is 2736x912 (3.0, full-bleed),
/// VIP4 is the thin 2112x1168 bar (1.808).
const Map<int, double> vipEntryEffectAspectRatios = <int, double>{
  1: 1.783,
  2: 1.783,
  3: 3.0,
  4: 1.808,
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

/// DP circle geometry per level (measured from the PNGs, 2026-11-18/19).
/// VIP1/2 measured from the flood-filled disc; VIP3 from the dark-neutral
/// disc blob; VIP4 from the thin bar's disc (centre 317,642 r=140).
const Map<int, EntryEffectCircle> vipEntryEffectCircles =
    <int, EntryEffectCircle>{
  1: EntryEffectCircle(centerX: 0.162, centerY: 0.514, diameter: 0.243),
  2: EntryEffectCircle(centerX: 0.098, centerY: 0.485, diameter: 0.242),
  3: EntryEffectCircle(centerX: 0.137, centerY: 0.498, diameter: 0.351),
  4: EntryEffectCircle(centerX: 0.150, centerY: 0.550, diameter: 0.240),
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
// Tags (VIP1-18)
// ---------------------------------------------------------------------------

/// Animal per VIP level for TAGS. VIP1 = black cat, VIP2 = swan,
/// VIP3 = dolphin, VIP4 = fox (Vinay, 2026-11-19), VIP5-18 as before.
const Map<int, String> vipTagAnimals = <int, String>{
  1: 'cat',
  2: 'swan',
  3: 'dolphin',
  4: 'fox',
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

/// R2 key of the golden tag PNG per level.
Map<int, String> get vipTagKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipTagAnimals.entries)
        entry.key: 'vip-tags/vip${entry.key}-tag.png',
    };

/// Direct R2 URL of the golden tag for [level], or null for out of range.
String? vipTagUrlForVipLevel(int level) {
  final String? key = vipTagKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

// ---------------------------------------------------------------------------
// Medals + scenic banners (VIP1-4)
// ---------------------------------------------------------------------------
//
// Shield medals (vip-medals/vip<N>-medal.png) and scenic/profile
// banners (profile-banners/vip<N>-banner.png for VIP1,
// profile-banners/vip<N>-scenic.png for VIP2-4). The Worker serves
// these in the vip visuals bundle (vip_medal / vip_scenic_banner).
// The LevelMedal widget still shows bundled SVGs and the profile
// cards are still painted glow effects — the Dart display swap for
// these two is a follow-up, so these helpers only resolve URLs for
// now. Returns null for VIP5-18 / out of range (no medal/scenic PNGs
// exist for those levels yet).

/// Animal per VIP level for MEDALS (VIP1-4 only).
const Map<int, String> vipMedalAnimals = <int, String>{
  1: 'cat',
  2: 'swan',
  3: 'dolphin',
  4: 'fox',
};

/// R2 key of the shield medal PNG per level (VIP1-4 only).
Map<int, String> get vipMedalKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipMedalAnimals.entries)
        entry.key: 'vip-medals/vip${entry.key}-medal.png',
    };

/// Direct R2 URL of the shield medal for [level], or null for VIP5-18 /
/// out of range.
String? vipMedalUrlForVipLevel(int level) {
  final String? key = vipMedalKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// R2 key of the scenic/profile banner PNG per level (VIP1-4 only).
/// VIP1 uses the "-banner" key, VIP2-4 use "-scenic".
Map<int, String> get vipScenicBannerKeys => <int, String>{
      1: 'profile-banners/vip1-banner.png',
      2: 'profile-banners/vip2-scenic.png',
      3: 'profile-banners/vip3-scenic.png',
      4: 'profile-banners/vip4-scenic.png',
    };

/// Direct R2 URL of the scenic/profile banner for [level], or null for
/// VIP5-18 / out of range.
String? vipScenicBannerUrlForVipLevel(int level) {
  final String? key = vipScenicBannerKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

// ---------------------------------------------------------------------------
// Rocket medals (Rocket 1-18)
// ---------------------------------------------------------------------------
//
// Premium medal badges (Vinay's 18 rockets as gold medallions, colour-
// matched frame per rocket, gold "LV.N" ribbon). Transparent PNGs on R2
// under rocket-medals/rocket-medal-lvNN.png (512px). The LevelMedal
// widget shows these for the rocket series; the bundled rocket_01-12.svg
// assets remain only as an offline fallback for levels 1-12.

/// R2 key of the Rocket medal PNG per level (Rocket 1-18).
String rocketMedalKeyForLevel(int level) {
  final int safeLevel = level.clamp(1, 18).toInt();
  return 'rocket-medals/rocket-medal-lv${safeLevel.toString().padLeft(2, '0')}.png';
}

/// Direct R2 URL of the Rocket medal PNG for [level] (clamped 1-18).
String rocketMedalUrlForLevel(int level) =>
    '$kVipVisualR2PublicBaseUrl/${rocketMedalKeyForLevel(level)}';

// ---------------------------------------------------------------------------
// Medal types (Wealth / Fan Club / Achievement / Family / Charm / Noble /
// Room / Event)
// ---------------------------------------------------------------------------
//
// The new medal series Vinay approved 2026-11-19. Transparent PNGs on
// R2 under medals/ (~512px). PK medals and Verified badges were REMOVED
// by Vinay — they are NOT here. Achievement is 6 medals x Lv.1-10
// (Active Star, Wealth, Live Stream, Live Star, Top Gifter, Fan Power);
// Room is Top 1/2/3 (no levels); Event is a single base medal.

/// Level counts per medal series.
const Map<String, int> kMedalTypeLevels = <String, int>{
  'wealth': 18,
  'fanclub': 18,
  'achievement': 10,
  'family': 10,
  'charm': 18,
  'noble': 10,
  'room': 3,
  'event': 1,
};

/// Slugs of the 6 achievement medals.
const List<String> kAchievementMedalSlugs = <String>[
  'active',
  'wealth',
  'live',
  'livestar',
  'topgifter',
  'fanpower',
];

/// R2 key of one medal image. [type] is wealth/fanclub/achievement/
/// family/charm/noble/room/event; [level] is clamped to the series
/// range. For achievement, [achievement] is the achievement slug.
/// For room, [level] is the rank 1-3 (Top 1/2/3).
String? medalTypeKeyForLevel(String type, int level, [String? achievement]) {
  final String series = type.trim().toLowerCase();
  final int? max = kMedalTypeLevels[series];
  if (max == null) return null;
  final int safeLevel = level.clamp(1, max).toInt();
  if (series == 'room') return 'medals/room-top$safeLevel.png';
  if (series == 'event') return 'medals/event-base.png';
  if (series == 'achievement') {
    final String slug = (achievement ?? 'active').trim().toLowerCase();
    final String safeSlug =
        kAchievementMedalSlugs.contains(slug) ? slug : 'active';
    return 'medals/achievement-$safeSlug-lv${safeLevel.toString().padLeft(2, '0')}.png';
  }
  return 'medals/$series-lv${safeLevel.toString().padLeft(2, '0')}.png';
}

/// Direct R2 URL of one medal image, or null for an unknown series.
String? medalTypeUrlForLevel(String type, int level, [String? achievement]) {
  final String? key = medalTypeKeyForLevel(type, level, achievement);
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

// ---------------------------------------------------------------------------
// Panda seat emotes (20)
// ---------------------------------------------------------------------------
//
// Full-body cute panda emotes for the room emoji panel (Vinay,
// 2026-11-19: "Panda wale me 20 emoji bana", "seat per dikhna
// chahiye", "room me emoji wale me alag section bana ke panda ka").
// The panel has two tabs: "Emoji" (unicode) and "Panda" (these 20).
// Tapping one sends the marker `[panda:<name>]` as a room message;
// the seat-reaction sync recognises the marker and plays the video on
// the sender's seat, above the DP, for 5 seconds — like the big
// animated emoji reactions in Bigo Live / QK Live.
//
// The app plays the VAP v1 MP4 (seat-emotes/panda/vap/panda-<name>.mp4
// on R2, alpha mask LEFT, RGB RIGHT) via flutter_vap_player — Flutter
// video_player cannot show VP9 alpha, so the transparent WebM
// (seat-emotes/panda/panda-<name>-transparent.webm) is the source
// asset only, not what the app plays.

/// The 20 panda emotes, in panel order.
const List<String> kPandaEmoteNames = <String>[
  'happy',
  'sad',
  'crying',
  'angry',
  'love',
  'laughing',
  'sleeping',
  'cool',
  'surprised',
  'winking',
  'kissing',
  'blushing',
  'hungry',
  'dancing',
  'waving',
  'clapping',
  'thinking',
  'scared',
  'silly',
  'party',
];

/// Display label for the panel grid.
const Map<String, String> kPandaEmoteLabels = <String, String>{
  'happy': 'Happy',
  'sad': 'Sad',
  'crying': 'Crying',
  'angry': 'Angry',
  'love': 'Love',
  'laughing': 'Laughing',
  'sleeping': 'Sleeping',
  'cool': 'Cool',
  'surprised': 'Surprised',
  'winking': 'Winking',
  'kissing': 'Kissing',
  'blushing': 'Blushing',
  'hungry': 'Hungry',
  'dancing': 'Dancing',
  'waving': 'Waving',
  'clapping': 'Clapping',
  'thinking': 'Thinking',
  'scared': 'Scared',
  'silly': 'Silly',
  'party': 'Party',
};

/// True when [name] is one of the 20 panda emotes.
bool isPandaEmoteName(String? name) =>
    name != null && kPandaEmoteNames.contains(name);

/// R2 key of the VAP v1 MP4 for [name] (what the app plays on the
/// seat). Null for unknown names.
String? pandaEmoteVapKeyForName(String? name) {
  if (!isPandaEmoteName(name)) return null;
  return 'seat-emotes/panda/vap/panda-$name.mp4';
}

/// Direct R2 URL of the VAP MP4 for [name], or null for unknown names.
String? pandaEmoteVapUrlForName(String? name) {
  final String? key = pandaEmoteVapKeyForName(name);
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// R2 key of the picker thumbnail PNG for [name] (a mid-video frame,
/// 256x456). Null for unknown names.
String? pandaEmoteThumbKeyForName(String? name) {
  if (!isPandaEmoteName(name)) return null;
  return 'seat-emotes/panda/thumbs/panda-$name.png';
}

/// Direct R2 URL of the picker thumbnail PNG for [name], or null for
/// unknown names.
String? pandaEmoteThumbUrlForName(String? name) {
  final String? key = pandaEmoteThumbKeyForName(name);
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// The chat marker sent when a user taps a panda emote in the panel.
String? pandaEmoteMarkerForName(String? name) {
  if (!isPandaEmoteName(name)) return null;
  return '[panda:$name]';
}

/// R2 key of the Greedy Girl kiss emote: a 5 s clip of the Greedy Girl
/// character blowing a kiss with a red heart, played as the game
/// background for players only (spectators see the static background).
const String greedyGirlKissEmoteKey =
    'greedy-girl/greedy-girl-kiss-emote.mp4';

/// Direct R2 URL of the Greedy Girl kiss emote video.
String get greedyGirlKissEmoteUrl =>
    '$kVipVisualR2PublicBaseUrl/$greedyGirlKissEmoteKey';

/// R2 key of the Greedy Girl game background picture (same girl as the
/// old mascot, sharp 1344x1728, no food bubbles). Served from R2 because
/// the GitHub push tool only carries UTF-8 text, never binary files.
const String greedyGirlBackgroundKey =
    'greedy-girl/greedy-girl-background.webp';

/// Direct R2 URL of the Greedy Girl game background picture.
String get greedyGirlBackgroundUrl =>
    '$kVipVisualR2PublicBaseUrl/$greedyGirlBackgroundKey';

/// Parses a chat message back into a panda emote name: "[panda:happy]"
/// -> "happy". Null for anything else.
String? pandaEmoteNameFromMarker(String? text) {
  final String trimmed = (text ?? '').trim();
  final RegExpMatch? match =
      RegExp(r'^\[panda:([a-z]+)\]$').firstMatch(trimmed);
  if (match == null) return null;
  final String name = match.group(1) ?? '';
  return isPandaEmoteName(name) ? name : null;
}

// ---------------------------------------------------------------------------
// Gift ribbons (VIP1-18)
// ---------------------------------------------------------------------------
//
// The gift ribbon is the banner shown in the room when a VIP sends a
// gift. 4 tiers, colour and premium quality increasing with the level:
//   VIP1-4   = Sleek Gold (basic, gold-dominant)
//   VIP5-10  = Purple & Gold Ornate (premium)
//   VIP11-15 = Royal Gold (more premium, purple-dominant)
//   VIP16-18 = Dragon Super Premium (richest colours)
// Every level gets its OWN banner: the tier base image (R2, direct,
// image/webp under gift-ribbons/) plus the VIP level written BIG and
// bold at runtime ("VIP N" is the most prominent text), plus the
// sender name, the gift name and the receiver name (sender -> receiver,
// gift below). The banner is 2736x912 (aspect ratio 3.0) with its own
// background, so no transparency is needed.
//
// The Worker attaches the ribbon to the gift flow (/api/gifts/send
// response + /api/rooms/:id/gift-events): gift_ribbon { tier, id, name,
// asset_key, url, vip_level } for the SENDER's VIP level, falling back
// to the basic tier for VIP0/no-VIP. The widget prefers the server URL
// and falls back to the local mapping by sender VIP level
// (giftRibbonUrlFromEvent). Panel colours per tier mirror the preview
// compositor (~/workspace/darkvibex-vip-section/gift-ribbons/
// make_previews.py): tier 1 gold plaque + dark bronze text; tiers 2
// and 4 black + gold text; tier 3 deep purple + gold text.

/// Gift ribbon tier (one tier covers a range of VIP levels).
enum GiftRibbonTier { basic, premium, royal, superPremium }

class GiftRibbonStyle {
  final String id;
  final String name;
  final String asset;
  final int minVip;
  final int maxVip;
  const GiftRibbonStyle({
    required this.id,
    required this.name,
    required this.asset,
    required this.minVip,
    required this.maxVip,
  });
}

const Map<GiftRibbonTier, GiftRibbonStyle> giftRibbonStyles = {
  GiftRibbonTier.basic: GiftRibbonStyle(
    id: 'ribbon_sleek_gold',
    name: 'Sleek Gold',
    asset: 'gift-ribbons/ribbon-sleek-gold.webp',
    minVip: 1,
    maxVip: 4,
  ),
  GiftRibbonTier.premium: GiftRibbonStyle(
    id: 'ribbon_purple_gold',
    name: 'Purple & Gold Ornate',
    asset: 'gift-ribbons/ribbon-purple-gold.webp',
    minVip: 5,
    maxVip: 10,
  ),
  GiftRibbonTier.royal: GiftRibbonStyle(
    id: 'ribbon_royal_gold',
    name: 'Royal Gold',
    asset: 'gift-ribbons/ribbon-royal-gold.webp',
    minVip: 11,
    maxVip: 15,
  ),
  GiftRibbonTier.superPremium: GiftRibbonStyle(
    id: 'ribbon_dragon_super',
    name: 'Dragon Super Premium',
    asset: 'gift-ribbons/ribbon-dragon-super.webp',
    minVip: 16,
    maxVip: 18,
  ),
};

/// Width / height of every ribbon banner image (2736x912).
const double kGiftRibbonAspectRatio = 3.0;

/// Centre panel of the banner, as fractions of the image (measured from
/// the designs: the baked placeholder text sits inside x 0.33-0.67,
/// y 0.43-0.69 on all four ribbons, so one panel covers it on every
/// design without touching the side mic icons or the frame edges).
/// The runtime overlay in GiftRibbonBanner uses these fractions.
const double kGiftRibbonPanelLeft = 0.315;
const double kGiftRibbonPanelTop = 0.40;
const double kGiftRibbonPanelRight = 0.685;
const double kGiftRibbonPanelBottom = 0.72;

/// Strict tier for a VIP level, or null for VIP0 / out of range.
/// (The gift flow falls back to basic separately — see below.)
GiftRibbonTier? giftRibbonTierForVipLevel(int level) {
  if (level < 1 || level > 18) return null;
  if (level >= 16) return GiftRibbonTier.superPremium;
  if (level >= 11) return GiftRibbonTier.royal;
  if (level >= 5) return GiftRibbonTier.premium;
  return GiftRibbonTier.basic;
}

/// Strict style for a VIP level, or null for VIP0 / out of range.
GiftRibbonStyle? giftRibbonForVipLevel(int level) {
  final GiftRibbonTier? tier = giftRibbonTierForVipLevel(level);
  return tier == null ? null : giftRibbonStyles[tier];
}

/// R2 key of the ribbon banner for [level], or null for VIP0 / out of
/// range. All levels in a tier share one base image; the level is
/// written on it at runtime.
String? giftRibbonKeyForVipLevel(int level) {
  return giftRibbonForVipLevel(level)?.asset;
}

/// Direct R2 URL of the ribbon banner for [level]. VIP0 / no-VIP falls
/// back to the basic (Sleek Gold) tier, mirroring the Worker
/// (giftRibbonForVipLevel) — every gift gets a ribbon.
String giftRibbonUrlForVipLevel(int level) {
  final GiftRibbonStyle style =
      giftRibbonForVipLevel(level) ?? giftRibbonStyles[GiftRibbonTier.basic]!;
  return '$kVipVisualR2PublicBaseUrl/${style.asset}';
}

/// VIP level a gift event's ribbon belongs to: the server ribbon's
/// vip_level when present, else the event's sender_vip_level, else 0.
int giftRibbonVipLevelFromEvent(Map<String, dynamic> event) {
  final Object? ribbon = event['gift_ribbon'];
  if (ribbon is Map) {
    final int? level = int.tryParse(ribbon['vip_level']?.toString() ?? '');
    if (level != null) return level;
  }
  return int.tryParse(event['sender_vip_level']?.toString() ?? '') ?? 0;
}

/// Direct R2 URL of the ribbon banner for a gift event: the server
/// ribbon URL when present, else the local mapping by sender VIP level
/// (basic tier for VIP0/no-VIP).
String giftRibbonUrlFromEvent(Map<String, dynamic> event) {
  final Object? ribbon = event['gift_ribbon'];
  if (ribbon is Map) {
    final String url = ribbon['url']?.toString().trim() ?? '';
    if (url.isNotEmpty) return url;
    final String key = ribbon['asset_key']?.toString().trim() ?? '';
    if (key.isNotEmpty) {
      return resolveVipVisualAssetUrl(key, (_) => '');
    }
  }
  return giftRibbonUrlForVipLevel(giftRibbonVipLevelFromEvent(event));
}

/// Centre-panel colours for a ribbon tier (as 0xFFRRGGBB ints, so this
/// file stays pure Dart — the widget turns them into Colors).
/// Tier 1: gold plaque + dark bronze text. Tiers 2 and 4: black + gold
/// text. Tier 3: deep purple + gold text.
class GiftRibbonPanelColors {
  const GiftRibbonPanelColors({
    required this.panel,
    required this.border,
    required this.vipText,
    required this.nameText,
    required this.giftText,
  });

  final int panel;
  final int border;
  final int vipText;
  final int nameText;
  final int giftText;
}

GiftRibbonPanelColors giftRibbonPanelColorsForTier(GiftRibbonTier tier) {
  switch (tier) {
    case GiftRibbonTier.basic:
      return const GiftRibbonPanelColors(
        panel: 0xFFD09E48,
        border: 0xFF8C641E,
        vipText: 0xFF785514,
        nameText: 0xFF6E4E12,
        giftText: 0xFF6E4E12,
      );
    case GiftRibbonTier.royal:
      return const GiftRibbonPanelColors(
        panel: 0xFF300873,
        border: 0xFFD4AF69,
        vipText: 0xFFE8C882,
        nameText: 0xFFE8C882,
        giftText: 0xFFC8AA64,
      );
    case GiftRibbonTier.premium:
    case GiftRibbonTier.superPremium:
      return const GiftRibbonPanelColors(
        panel: 0xFF050508,
        border: 0xFFD4AF69,
        vipText: 0xFFE8C882,
        nameText: 0xFFE8C882,
        giftText: 0xFFC8AA64,
      );
  }
}

/// Panel colours for a VIP level (basic tier colours for VIP0/no-VIP).
GiftRibbonPanelColors giftRibbonPanelColorsForVipLevel(int level) {
  final GiftRibbonTier tier =
      giftRibbonTierForVipLevel(level) ?? GiftRibbonTier.basic;
  return giftRibbonPanelColorsForTier(tier);
}

// ---------------------------------------------------------------------------
// Profile card animations (v4, VIP4-18)
// ---------------------------------------------------------------------------
//
// The profile card popup plays the level's 5-second animation as its
// BACKGROUND (video_player, direct R2 MP4, plays once, no loop) while
// the reference layout — DP top centre (in place of the frame's blue
// diamond), name + badges, medals, ID/Fans, bio, 4 buttons — renders
// in the FOREGROUND over it (Vinay, 2026-11-19, approved).
//
//   video: profile-card-anims/vip<N>-<animal>.mp4 (5 s, 832x896 canvas,
//          wide horizontal frame content inside; frame design stays
//          exactly as the starting still, camera static, NO zoom, only
//          the animal moves gently, ends calmly)
//   still: profile-card-stills/vip<N>-<animal>.png (the v3 design) —
//          poster while the video loads, and the fallback when the
//          video cannot play or finishes. EXCEPTION — VIP4: its old
//          still/video were built from an app screenshot
//          (cosmetics-shop UI behind the fox frame), so VIP4's still
//          below is the new clean frame
//          (profile-card-frames/vip4-fox.webp, generated 2026-11-21)
//          and VIP4 has NO video (still only).
//
// v4 runs from VIP5 onwards and NO design has a bottom line — every
// frame is open at the bottom, top and sides only, and no design
// carries any text ("VIP N" / "Profile Card" never appear; the VIP
// tag is already in the profile). VIP1-4 have NO video animation,
// only a normal still pic (Vinay, 2026-11-20, "normal pic lagegi
// 1 se 3 tak"; VIP4 still-only since 2026-11-21, screenshot video
// retired): the still helpers below return the pic for VIP1-18,
// the video helpers return null for VIP1-4.
//
// The video is a full-bleed scene (opaque background), NOT a
// transparent cutout — unlike the VAP frames, video_player CAN play
// it (opaque texture is fine here). Never feed it a WebM.

/// Animal per VIP level for PROFILE CARD animations. VIP5 = deer,
/// VIP6 = wolf ... VIP18 = dragon. VIP1-4 have no animation (VIP4's
/// old screenshot video was retired 2026-11-21 — still only, clean
/// frame).
const Map<int, String> vipProfileCardAnimAnimals = <int, String>{
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

/// Animal per VIP level for PROFILE CARD stills. VIP1 = cat,
/// VIP2 = swan, VIP3 = dolphin, VIP4 = fox ... VIP18 = dragon.
/// Every level 1-18 has a still pic; only VIP5-18 have a video
/// animation (see [vipProfileCardAnimAnimals]).
const Map<int, String> vipProfileCardStillAnimals = <int, String>{
  1: 'cat',
  2: 'swan',
  3: 'dolphin',
  4: 'fox',
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

/// R2 key of the 5-second background animation MP4 per level (VIP4-18).
Map<int, String> get vipProfileCardAnimVideoKeys => <int, String>{
      for (final MapEntry<int, String> entry
          in vipProfileCardAnimAnimals.entries)
        entry.key:
            'profile-card-anims/vip${entry.key}-${entry.value}.mp4',
    };

/// R2 key of the fallback still per level (VIP1-18). VIP4's still is
/// the new clean frame WebP (profile-card-frames/vip4-fox.webp) — the
/// old screenshot PNG (profile-card-stills/vip4-fox.png) must never
/// resolve from anywhere.
Map<int, String> get vipProfileCardAnimStillKeys => <int, String>{
      for (final MapEntry<int, String> entry
          in vipProfileCardStillAnimals.entries)
        entry.key: entry.key == 4
            ? 'profile-card-frames/vip4-fox.webp'
            : 'profile-card-stills/vip${entry.key}-${entry.value}.png',
    };

/// Direct R2 URL of the background animation MP4 for [level], or null
/// for VIP1-4 (no animation) / out of range.
String? profileCardAnimVideoUrlForVipLevel(int level) {
  final String? key = vipProfileCardAnimVideoKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Direct R2 URL of the fallback still for [level], or null out
/// of range. VIP1-4 have a still pic, no video.
String? profileCardAnimStillUrlForVipLevel(int level) {
  final String? key = vipProfileCardAnimStillKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Animation video URL for the card actually being displayed, or null
/// when the card has no animation video.
///
/// The video plays ONLY for the level's own animation: [videoKey] is
/// the member's profile_card_anim video_key from the Worker (the
/// level's own key, or empty when no key was configured, so the level
/// animation is used). A custom/Owner video key has no v4 animation,
/// so this returns null and the caller shows the still only. Never
/// guess a video URL for a custom card — that would play the wrong
/// level's animation behind it.
String? profileCardAnimVideoUrlForDisplay(String? videoKey, int level) {
  final String? animKey = vipProfileCardAnimVideoKeys[level];
  if (animKey == null) return null; // VIP1-4: no animation.
  final String key = (videoKey ?? '').trim();
  if (key.isEmpty || key == animKey) {
    return profileCardAnimVideoUrlForVipLevel(level);
  }
  return null; // Custom/Owner video: still only, no v4 animation.
}

// ---------------------------------------------------------------------------
// Profile card frames (VIP1-18 stills, VIP5-18 looping animations)
// ---------------------------------------------------------------------------
//
// The profile card popup shows the level's FRAME design as its
// background (Vinay, 2026-11-21, "Add kar de saare is bar dubara ke
// liye kuch mat chodiyo" — all 18 frames added in one pass):
//   still: profile-card-frames/vip<N>-<animal>.webp (the v3 frame
//          design; VIP1-3: v4 still; VIP4: new clean v3-style fox
//          frame generated 2026-11-21 — every local VIP4 frame file
//          was an app screenshot; VIP16: the clean wide frame
//          ...4957abf4...)
//   video: profile-card-frames/vip<N>-<animal>-anim.mp4 (5 s, LOOP,
//          VIP5-18 only; VIP1-4 have no frame animation, still only).
//
// The frame still is the poster while the video loads and the fallback
// when the video cannot play. The video LOOPS (Vinay, 2026-11-21,
// "Loop me rahega") — unlike the old profile-card-anims/ videos which
// played once. The old profile-card-anims/ + profile-card-stills/
// helpers above stay as-is (their R2 assets still exist); the popup
// now uses these frame helpers instead.

/// Animal per VIP level for PROFILE CARD FRAME animations. VIP5 = deer,
/// VIP6 = wolf, VIP7 = eagle, VIP8 = panther, VIP9 = cobra,
/// VIP10 = lion, VIP11 = tiger, VIP12 = mammoth, VIP13 = gorilla,
/// VIP14 = bear, VIP15 = kraken, VIP16 = leviathan, VIP17 = phoenix,
/// VIP18 = dragon. VIP1-4 have no frame animation (still only).
const Map<int, String> vipProfileCardFrameAnimAnimals = <int, String>{
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

/// R2 key of the frame still WebP per level (VIP1-18).
Map<int, String> get vipProfileCardFrameStillKeys => <int, String>{
      for (final MapEntry<int, String> entry
          in vipProfileCardStillAnimals.entries)
        entry.key:
            'profile-card-frames/vip${entry.key}-${entry.value}.webp',
    };

/// R2 key of the looping frame animation MP4 per level (VIP5-18).
Map<int, String> get vipProfileCardFrameAnimVideoKeys => <int, String>{
      for (final MapEntry<int, String> entry
          in vipProfileCardFrameAnimAnimals.entries)
        entry.key:
            'profile-card-frames/vip${entry.key}-${entry.value}-anim.mp4',
    };

/// Direct R2 URL of the frame still WebP for [level], or null out
/// of range. Every level 1-18 has a frame still.
String? profileCardFrameStillUrlForVipLevel(int level) {
  final String? key = vipProfileCardFrameStillKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Direct R2 URL of the looping frame animation MP4 for [level], or
/// null for VIP1-4 (no frame animation) / out of range.
String? profileCardFrameAnimVideoUrlForVipLevel(int level) {
  final String? key = vipProfileCardFrameAnimVideoKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Frame animation video URL for the card actually being displayed, or
/// null when the card has no frame animation video.
///
/// The video plays ONLY for the level's own frame animation: [videoKey]
/// is the member's profile_card_anim video_key from the Worker. The
/// Worker catalog still sends the level's old profile-card-anims/ key,
/// so that key AND the new frame anim key both count as "the level's
/// own video". A custom/Owner video key has no frame animation, so this
/// returns null and the caller shows the still only. Never guess a
/// video URL for a custom card — that would play the wrong level's
/// animation behind it.
String? profileCardFrameAnimVideoUrlForDisplay(String? videoKey, int level) {
  final String? frameAnimKey = vipProfileCardFrameAnimVideoKeys[level];
  if (frameAnimKey == null) return null; // VIP1-4: no frame animation.
  final String key = (videoKey ?? '').trim();
  if (key.isEmpty ||
      key == frameAnimKey ||
      key == vipProfileCardAnimVideoKeys[level]) {
    return profileCardFrameAnimVideoUrlForVipLevel(level);
  }
  return null; // Custom/Owner video: still only, no frame animation.
}

// ---------------------------------------------------------------------------
// VIP badge videos (VIP1-18)
// ---------------------------------------------------------------------------

/// Animal per VIP level for BADGES — the same animals as the
/// frames/vehicles. VIP1 cat, VIP2 swan, VIP3 dolphin, VIP4 fox
/// (Vinay, 2026-11-19), VIP5 deer, VIP6 wolf, VIP7 eagle, VIP8
/// panther, VIP9 cobra, VIP10 lion, VIP11 tiger, VIP12 mammoth,
/// VIP13 gorilla, VIP14 bear, VIP15 kraken, VIP16 leviathan,
/// VIP17 phoenix, VIP18 dragon.
///
/// The badge videos are premium 3D animated shields (animal + wings +
/// gold "VIP N" banner on a pedestal). 11 are Vinay's own uploads
/// (VIP5, 6, 8, 9, 10, 11, 13, 15, 16, 17 gold, 18 — portrait,
/// 5.184 s except VIP17 gold at 10.144 s); the other 7 (VIP1, 2, 3, 4,
/// 7, 12, 14) were made by Ghost in the same style (landscape
/// 1280x720, 10 s). They play on the VIP page hero card, on the right
/// side next to the "VIP N" text + EXP, and on tap in the Medal
/// Gallery. The video plays ONCE; the VipBadgeVideo widget falls back
/// to the LevelMedal SVG on completion/error — never a black box.
const Map<int, String> vipBadgeAnimals = <int, String>{
  1: 'cat',
  2: 'swan',
  3: 'dolphin',
  4: 'fox',
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

/// R2 key of the badge video MP4 per level (VIP1-18).
Map<int, String> get vipBadgeVideoKeys => <int, String>{
      for (final MapEntry<int, String> entry in vipBadgeAnimals.entries)
        entry.key: 'vip-badges/vip${entry.key}-${entry.value}.mp4',
    };

/// Measured duration of each badge video in milliseconds. Vinay's
/// portrait videos are 5.184 s, Ghost's landscape videos are 10 s,
/// VIP17 gold is 10.144 s. The VipBadgeVideo widget plays the video
/// once and falls back to the LevelMedal SVG when it ends.
const Map<int, int> vipBadgeAnimationMs = <int, int>{
  1: 10000,
  2: 10000,
  3: 10000,
  4: 10000,
  5: 5184,
  6: 5184,
  7: 10000,
  8: 5184,
  9: 5184,
  10: 5184,
  11: 5184,
  12: 10000,
  13: 5184,
  14: 10000,
  15: 5184,
  16: 5184,
  17: 10144,
  18: 5184,
};

/// Direct R2 URL of the badge video for [level], or null out of range.
String? vipBadgeVideoUrlForVipLevel(int level) {
  final String? key = vipBadgeVideoKeys[level];
  if (key == null) return null;
  return '$kVipVisualR2PublicBaseUrl/$key';
}

/// Direct R2 URL of the VIP17 purple phoenix variant, or null for any
/// other level (only VIP17 has a variant). The gold badge stays the
/// default for VIP17 — call this only when the purple variant is
/// explicitly requested.
String? vipBadgeVariantVideoUrlForVipLevel(int level) {
  if (level != 17) return null;
  return '$kVipVisualR2PublicBaseUrl/vip-badges/vip17-phoenix-purple.mp4';
}

/// Badge video URL for the level actually being displayed, or null when
/// the level has no badge video.
///
/// The video plays ONLY for the level's own badge: [videoKey] is the
/// member's vip_badge video_key from the Worker (the level's own key,
/// or empty when no key was configured, so the level badge is used).
/// A custom/Owner video key has no badge video, so this returns null
/// and the caller shows the LevelMedal SVG only. Never guess a video
/// URL for a custom badge — that would play the wrong level's badge.
String? vipBadgeVideoUrlForDisplay(String? videoKey, int level) {
  final String? badgeKey = vipBadgeVideoKeys[level];
  if (badgeKey == null) return null;
  final String key = (videoKey ?? '').trim();
  if (key.isEmpty || key == badgeKey) {
    return vipBadgeVideoUrlForVipLevel(level);
  }
  return null;
}
