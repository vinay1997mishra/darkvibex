// DarkVibeX — Vehicle Entry Catalog v4 (ANIMAL set)
// Complete 14-vehicle set, one per VIP level 5-18 (tier 1-14).
// This REPLACES the old car/yacht list (Silver Moon Coupe, Sapphire
// Falcon GT, Emerald Royal Carriage, Starlight Coupe, Neon Comet GT,
// Royal Chariot, Golden Dragon, Phoenix GT, Luxury Yacht, Royal Lion
// Carriage, Celestial Phoenix, Diamond Jet, Inferno Dragon, King of
// VIP). Vinay replaced it on 2026-11-18 with an animal-themed list.
// Matches the existing COSMETIC_CATALOG shape in
// apps/worker/src/cosmetics.js and the NEW VIP rule Vinay wants
// (see README — the old rule unlocked at VIP8; this set unlocks
// at VIP5):
//   entrance_vehicle_tier = level >= 5 ? level - 4 : 0
//   VIP5 = tier 1 ... VIP18 = tier 14
// Entrance Vehicle privilege unlocks at VIP5.
//
// Timepass only — no earning. All prices are 0, exactly like the
// existing 7-vehicle catalog (price_coins: 0, duration_days: 30).
//
// LAYOUT (Vinay, 2026-11-18) — the main rule for playback:
//   VIP5-15 : bottom-anchored, touching the bottom edge, height = 40%
//             of screen, full width. layout {anchor:'bottom',
//             heightFraction: 0.40}
//   VIP16-18: full-screen, 100% height (super premium tier).
//             layout {anchor:'full', heightFraction: 1.0}
//   The room stays visible above the entry for VIP5-15; VIP16-18
//   take over the whole screen.
//
// BACKGROUND: anime style premium ANIMATED effects — the backdrop
// behind each animal is animated (moving particles, pulsing glow,
// drifting clouds / fire / water), not a static picture. Each entry
// has backgroundTheme naming its animated backdrop; the Dart file
// paints it time-animated via _paintAnimatedBackground() (driven by
// animation progress), and the MP4 itself carries the animated scene.
//
// VIDEO: every entry is a rendered MP4 (video_player), NOT SVGA /
// Lottie — the app has NO SVGA and NO Lottie package. video_file is
// the exact filename in videos/ (720x1280 vertical, 10 s, except
// Bear VIP14 = 8 s). Playback is DIRECT from Cloudflare R2:
// videoUrlForVipLevel(level) = R2_PUBLIC_BASE_URL + '/' + video_key,
// played via video_player (VideoPlayerController.networkUrl) in
// CustomAssetEffectPlayback (active_vehicle_video_key = that full
// direct R2 URL). NO Worker URL in the playback path. Do NOT commit
// the MP4s to git — they live in R2 bucket "darkvibex-files" under
// vehicles/ (see README "Direct R2 playback").

// DIRECT R2 PLAYBACK (Vinay, 2026-11-18) — videos play DIRECTLY from
// Cloudflare R2, with NO Worker in the playback path. The Worker
// (darkvibex-api, wrangler.jsonc) already has an R2 binding FILES ->
// bucket "darkvibex-files", but that binding is only for upload/storage.
// Playback: app video_player fetches the MP4 straight from the R2
// public URL (Cloudflare CDN, zero egress) — fastest start on room
// entry, no Worker hop. Set R2_PUBLIC_BASE_URL below to the bucket's
// public base URL, with NO trailing slash:
//   - Custom domain (recommended): e.g. 'https://cdn.example.com'
//     (R2 bucket > Settings > Custom Domain — use your own domain)
//   - Or the public r2.dev URL: e.g. 'https://pub-xxx.r2.dev'
//     (R2 bucket > Settings > allow public access / r2.dev subdomain)
//   Leave it '' until the domain is set — videoUrlForVipLevel()
//   then returns null and the CustomPaint fallback is used.
//   Do NOT invent a domain here; the real one is set by Vinay.
export const R2_PUBLIC_BASE_URL = 'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev';

// R2 object key per vehicle (clean names, uploaded by
// cloudflare-r2-upload.sh into bucket "darkvibex-files").
// Public URL for a vehicle = R2_PUBLIC_BASE_URL + '/' + video_key.
export const R2_BUCKET = 'darkvibex-files';

export const VEHICLE_ENTRY_CATALOG = [
  {
    id: 'vehicle_deer',
    kind: 'vehicle',
    name: 'Deer',
    emoji: '🦌',
    category: 'Land',
    rarity: 'Rare',
    price_coins: 0,
    min_vip_level: 5,
    duration_days: 30,
    tier: 1,
    animation_type: 'run',
    animation_ms: 10000,
    style_id: 'deer',
    video_file: 'media-generation-vip5-deer-superpower-0-ffb877e8-d2f5-4801-9edb-1cf2d632d369.mp4',
    video_key: 'vehicles/vip5-deer.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'moonlit-forest',
    colors: ['#FFD700', '#7FB3FF', '#FFF3B0'],
    description: 'Cinematic realistic-anime Deer — running through a moonlit forest, roaring, glowing antlers unleashing a superpower energy blast.',
  },
  {
    id: 'vehicle_wolf',
    kind: 'vehicle',
    name: 'Wolf',
    emoji: '🐺',
    category: 'Land',
    rarity: 'Rare',
    price_coins: 0,
    min_vip_level: 6,
    duration_days: 30,
    tier: 2,
    animation_type: 'run',
    animation_ms: 10000,
    style_id: 'wolf',
    video_file: 'media-generation-vip6-wolf-superpower-0-f4092fd8-b6f2-4301-a37c-08c87b19dea7.mp4',
    video_key: 'vehicles/vip6-wolf.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'moonlit-night-forest',
    colors: ['#C0C0C0', '#00B0FF', '#E8ECF5'],
    description: 'Cinematic realistic-anime Wolf — running through a dark night forest, howling at the full moon, blue superpower aura shockwave.',
  },
  {
    id: 'vehicle_eagle',
    kind: 'vehicle',
    name: 'Eagle',
    emoji: '🦅',
    category: 'Air',
    rarity: 'Rare',
    price_coins: 0,
    min_vip_level: 7,
    duration_days: 30,
    tier: 3,
    animation_type: 'fly',
    animation_ms: 10000,
    style_id: 'eagle',
    video_file: 'media-generation-vip7-eagle-superpower-0-6aa08eef-0bc5-4eab-85e1-1c83eac84732.mp4',
    video_key: 'vehicles/vip7-eagle.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'golden-clouds-sky',
    colors: ['#FFD700', '#00B0FF', '#FFF3B0'],
    description: 'Cinematic realistic-anime Eagle — diving through golden clouds, wings spread wide, screeching, lightning superpower from its wings.',
  },
  {
    id: 'vehicle_panther',
    kind: 'vehicle',
    name: 'Panther',
    emoji: '🐆',
    category: 'Land',
    rarity: 'Epic',
    price_coins: 0,
    min_vip_level: 8,
    duration_days: 30,
    tier: 4,
    animation_type: 'run',
    animation_ms: 10000,
    style_id: 'panther',
    video_file: 'media-generation-vip8-panther-superpower-0-0a0d1da0-6d2d-4125-89f9-bbebd0f3bbbf.mp4',
    video_key: 'vehicles/vip8-panther.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'neon-night-jungle',
    colors: ['#111111', '#00E676', '#7B2FFF'],
    description: 'Cinematic realistic-anime Panther — leaping through a neon night jungle, roaring, dark purple shadow superpower energy blast.',
  },
  {
    id: 'vehicle_cobra',
    kind: 'vehicle',
    name: 'Cobra',
    emoji: '🐍',
    category: 'Land',
    rarity: 'Epic',
    price_coins: 0,
    min_vip_level: 9,
    duration_days: 30,
    tier: 5,
    animation_type: 'strike',
    animation_ms: 10000,
    style_id: 'cobra',
    video_file: 'media-generation-vip9-cobra-superpower-0-b39a4267-c970-4cac-8254-621d22ec7fcf.mp4',
    video_key: 'vehicles/vip9-cobra.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'golden-temple-fire',
    colors: ['#FFD700', '#FF6D00', '#FFF3B0'],
    description: 'Cinematic realistic-anime Cobra — striking in a golden temple, hood spread wide, hissing, fiery golden venom superpower blast.',
  },
  {
    id: 'vehicle_lion',
    kind: 'vehicle',
    name: 'Lion',
    emoji: '🦁',
    category: 'Land',
    rarity: 'Epic',
    price_coins: 0,
    min_vip_level: 10,
    duration_days: 30,
    tier: 6,
    animation_type: 'run',
    animation_ms: 10000,
    style_id: 'lion',
    video_file: 'media-generation-vip10-lion-superpower-0-e9243c51-2b33-4742-947f-06f3b09d7b6f.mp4',
    video_key: 'vehicles/vip10-lion.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'savanna-sunset',
    colors: ['#FFB300', '#FF6D00', '#FFD700'],
    description: 'Cinematic realistic-anime Lion — running on a savanna at sunset, rearing up and roaring, golden superpower shockwave from its glowing mane.',
  },
  {
    id: 'vehicle_tiger',
    kind: 'vehicle',
    name: 'Tiger',
    emoji: '🐅',
    category: 'Land',
    rarity: 'Epic',
    price_coins: 0,
    min_vip_level: 11,
    duration_days: 30,
    tier: 7,
    animation_type: 'run',
    animation_ms: 10000,
    style_id: 'tiger',
    video_file: 'media-generation-vip11-tiger-premium-0-243fd86c-1899-47c6-ba46-cd0aae7c6266.mp4',
    video_key: 'vehicles/vip11-tiger.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'jungle-sunset-fire',
    colors: ['#FF6D00', '#FFC400', '#FFE082'],
    description: 'Ultra-premium realistic-anime Tiger — running through a jungle at sunset, roaring, fiery orange superpower shockwave, glowing stripes.',
  },
  {
    id: 'vehicle_mammoth',
    kind: 'vehicle',
    name: 'Mammoth',
    emoji: '🦣',
    category: 'Land',
    rarity: 'Legendary',
    price_coins: 0,
    min_vip_level: 12,
    duration_days: 30,
    tier: 8,
    animation_type: 'run',
    animation_ms: 10000,
    style_id: 'mammoth',
    video_file: 'media-generation-vip12-mammoth-premium-0-41b4160e-85fd-4b73-8f30-166576579a85.mp4',
    video_key: 'vehicles/vip12-mammoth.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'snowy-mountain-ice',
    colors: ['#B3E5FC', '#00B0FF', '#FFFFFF'],
    description: 'Ultra-premium realistic-anime Mammoth — charging through a snowy mountain valley, trumpeting, icy blue superpower shockwave from glowing tusks.',
  },
  {
    id: 'vehicle_gorilla',
    kind: 'vehicle',
    name: 'Gorilla',
    emoji: '🦍',
    category: 'Land',
    rarity: 'Legendary',
    price_coins: 0,
    min_vip_level: 13,
    duration_days: 30,
    tier: 9,
    animation_type: 'run',
    animation_ms: 10000,
    style_id: 'gorilla',
    video_file: 'media-generation-vip13-gorilla-premium-0-5e0741a5-605c-49e6-b472-50773a3c75a2.mp4',
    video_key: 'vehicles/vip13-gorilla.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'jungle-gold-earth',
    colors: ['#8D6E63', '#FFD700', '#FFF3B0'],
    description: 'Ultra-premium realistic-anime Gorilla — running through the jungle, chest-pounding and roaring, golden earth superpower shockwave.',
  },
  {
    id: 'vehicle_bear',
    kind: 'vehicle',
    name: 'Bear',
    emoji: '🐻',
    category: 'Land',
    rarity: 'Legendary',
    price_coins: 0,
    min_vip_level: 14,
    duration_days: 30,
    tier: 10,
    animation_type: 'run',
    animation_ms: 8000,
    style_id: 'bear',
    video_file: 'media-generation-vip14-bear-premium-0-3679e073-39f9-40fd-9582-b58e2a03dcec.mp4',
    video_key: 'vehicles/vip14-bear.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'pine-forest-fire',
    colors: ['#6D4C41', '#D50000', '#FF6D00'],
    description: 'Ultra-premium realistic-anime Bear — running through a pine forest, standing and roaring, fiery red superpower shockwave from glowing claws. NOTE: video is 8 s, not 10 s.',
  },
  {
    id: 'vehicle_kraken',
    kind: 'vehicle',
    name: 'Kraken',
    emoji: '🐙',
    category: 'Water',
    rarity: 'Legendary',
    price_coins: 0,
    min_vip_level: 15,
    duration_days: 30,
    tier: 11,
    animation_type: 'rise',
    animation_ms: 10000,
    style_id: 'kraken',
    video_file: 'media-generation-vip15-kraken-premium-0-3eab4c0a-43c0-4c1b-b923-44353f93b938.mp4',
    video_key: 'vehicles/vip15-kraken.mp4',
    layout: { anchor: 'bottom', heightFraction: 0.40 },
    backgroundTheme: 'stormy-ocean',
    colors: ['#0B3D91', '#00B0FF', '#7FE3F2'],
    description: 'Ultra-premium realistic-anime Kraken — rising from a stormy ocean, tentacles waving, roaring, deep blue water superpower whirlpool blast.',
  },
  {
    id: 'vehicle_leviathan',
    kind: 'vehicle',
    name: 'Leviathan',
    emoji: '🐋',
    category: 'Water',
    rarity: 'Mythic',
    price_coins: 0,
    min_vip_level: 16,
    duration_days: 30,
    tier: 12,
    animation_type: 'fly',
    animation_ms: 10000,
    style_id: 'leviathan',
    video_file: 'media-generation-vip16-leviathan-superpremium-0-b26ea4d0-6ba8-4ef0-b87e-b47acf3d5a22.mp4',
    video_key: 'vehicles/vip16-leviathan.mp4',
    layout: { anchor: 'full', heightFraction: 1.0 },
    backgroundTheme: 'storm-ocean-lightning',
    colors: ['#0B3D91', '#00E5FF', '#B3E5FC'],
    description: 'SUPER-premium realistic-anime Leviathan — colossal sea serpent flying through storm clouds and ocean, roaring, massive water + lightning superpower blast. FULL-SCREEN.',
  },
  {
    id: 'vehicle_phoenix',
    kind: 'vehicle',
    name: 'Phoenix',
    emoji: '🔥',
    category: 'Air',
    rarity: 'Mythic',
    price_coins: 0,
    min_vip_level: 17,
    duration_days: 30,
    tier: 13,
    animation_type: 'fly',
    animation_ms: 10000,
    style_id: 'phoenix',
    video_file: 'media-generation-vip17-phoenix-superpremium-0-17afdbe2-e126-4aad-9342-654fad7e499d.mp4',
    video_key: 'vehicles/vip17-phoenix.mp4',
    layout: { anchor: 'full', heightFraction: 1.0 },
    backgroundTheme: 'fire-dark-sky',
    colors: ['#FF3D00', '#FF9E00', '#FFD54F'],
    description: 'SUPER-premium realistic-anime Phoenix — fire phoenix flying toward camera, wings spread wide, glowing orange eyes, massive fire superpower blast, long golden tail feathers. FULL-SCREEN.',
  },
  {
    id: 'vehicle_dragon',
    kind: 'vehicle',
    name: 'Dragon',
    emoji: '🐉',
    category: 'Air',
    rarity: 'Mythic',
    price_coins: 0,
    min_vip_level: 18,
    duration_days: 30,
    tier: 14,
    animation_type: 'fly',
    animation_ms: 10000,
    style_id: 'dragon',
    video_file: 'media-generation-vip18-dragon-superpremium-0-e260a266-1eee-4158-b306-a98657b28d62.mp4',
    video_key: 'vehicles/vip18-dragon.mp4',
    layout: { anchor: 'full', heightFraction: 1.0 },
    backgroundTheme: 'golden-clouds-storm',
    colors: ['#FFC400', '#FF6D00', '#FFE082'],
    description: 'SUPER-premium realistic-anime Dragon — golden dragon flying through golden clouds and storm sky, roaring, massive golden fire + lightning superpower blast. FULL-SCREEN.',
  },
];

// Layout rules (Vinay, 2026-11-18). Single source of truth for the
// Dart side — vehicle_entry_effect_v2.dart mirrors these constants.
export const BOTTOM_ENTRY_HEIGHT_FRACTION = 0.40;
export const FULLSCREEN_HEIGHT_FRACTION = 1.0;
export const SUPER_PREMIUM_MIN_VIP = 16; // VIP16-18 = full-screen

export function layoutForVipLevel(level) {
  const v = vehicleForVipLevel(level);
  return v == null ? null : v.layout;
}

export function isFullscreenVipLevel(level) {
  return Number(level) >= SUPER_PREMIUM_MIN_VIP;
}

// Helpers — mirror the NEW vip_policy.js rule Vinay wants:
// tier = level - 4 for level >= 5 (VIP5 = tier 1 ... VIP18 = tier 14).
export function vehicleForTier(tier) {
  if (!Number.isInteger(tier) || tier < 1 || tier > 14) return null;
  return VEHICLE_ENTRY_CATALOG.find((v) => v.tier === tier) ?? null;
}

export function vehicleForVipLevel(level) {
  const n = Number(level);
  if (!Number.isInteger(n) || n < 5 || n > 18) return null;
  return vehicleForTier(n - 4);
}

export function vehicleById(id) {
  return VEHICLE_ENTRY_CATALOG.find((v) => v.id === id) ?? null;
}

export function vehicleByStyleId(styleId) {
  return VEHICLE_ENTRY_CATALOG.find((v) => v.style_id === styleId) ?? null;
}

export function videoFileForVipLevel(level) {
  const v = vehicleForVipLevel(level);
  return v == null ? null : v.video_file;
}

// Direct R2 playback helpers — the single place the public base URL
// is joined to a vehicle's R2 key. Returns null when R2 is not
// configured yet (R2_PUBLIC_BASE_URL == ''), so callers fall back
// to the CustomPaint effect instead of playing a broken URL.
export function isR2Configured() {
  return typeof R2_PUBLIC_BASE_URL === 'string' && R2_PUBLIC_BASE_URL.trim() !== '';
}

export function videoUrlForVipLevel(level) {
  const v = vehicleForVipLevel(level);
  if (v == null || !isR2Configured()) return null;
  const base = R2_PUBLIC_BASE_URL.replace(/\/+$/, '');
  return `${base}/${v.video_key}`;
}

// Full direct R2 URL for every vehicle (null entries only when R2
// is unconfigured). Example once configured:
//   videoUrlForVipLevel(17) -> '<base>/vehicles/vip17-phoenix.mp4'
export function allVideoUrls() {
  return VEHICLE_ENTRY_CATALOG.map((v) => ({
    min_vip_level: v.min_vip_level,
    name: v.name,
    video_key: v.video_key,
    video_url: videoUrlForVipLevel(v.min_vip_level),
  }));
}

// Legacy mapping — the 7 old vehicles in apps/worker/src/cosmetics.js
// (car list, superseded by the animal list). Old id -> tier, by the
// same tier number the old entry used, so existing equipped items
// resolve to the animal at that tier instead of breaking.
//   vehicle_spark            -> tier 4  (Panther, VIP8)
//   vehicle_neon_comet       -> tier 5  (Cobra, VIP9)
//   vehicle_royal            -> tier 6  (Lion, VIP10)
//   vehicle_dragon_royal     -> tier 7  (Tiger, VIP11)
//   vehicle_phoenix          -> tier 13 (Phoenix, VIP17 — note: the
//                               old Phoenix GT was VIP12/tier 8; the
//                               animal Phoenix is VIP17/tier 13)
//   vehicle_celestial_phoenix -> tier 11 (Kraken, VIP15)
//   vehicle_king             -> tier 14 (Dragon, VIP18)
export const LEGACY_VEHICLE_MAP = Object.freeze({
  vehicle_spark: 4,
  vehicle_neon_comet: 5,
  vehicle_royal: 6,
  vehicle_dragon_royal: 7,
  vehicle_phoenix: 13,
  vehicle_celestial_phoenix: 11,
  vehicle_king: 14,
});

export function vehicleForLegacyId(legacyId) {
  const tier = LEGACY_VEHICLE_MAP[legacyId];
  return tier == null ? null : vehicleForTier(tier);
}
