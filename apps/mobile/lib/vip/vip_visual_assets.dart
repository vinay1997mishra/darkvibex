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
  'gift-ribbons/',
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
