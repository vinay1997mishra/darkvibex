const readyDatabases = new WeakSet();

// Bubble and final frame artwork catalogs stay in parity with the mobile Store UI.
export const COSMETIC_CATALOG = [
  { id: "frame_royal", kind: "frame", name: "Royal Ember", price_coins: 0, min_vip_level: 1, duration_days: 30, tier: 1 },
  { id: "frame_sapphire", kind: "frame", name: "Sapphire Crown", price_coins: 0, min_vip_level: 4, duration_days: 30, tier: 4 },
  { id: "frame_phoenix", kind: "frame", name: "Phoenix Halo", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "frame_king", kind: "frame", name: "King of VIP", price_coins: 0, min_vip_level: 15, duration_days: 30, tier: 18 },

  { id: "frame_golden_crown", kind: "frame", name: "Royal Crown", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 18, animation_type: "crown_shine", animation_ms: 2000 },
  { id: "frame_pink_heart", kind: "frame", name: "Love Heart", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 8, animation_type: "heart_pulse", animation_ms: 2000 },
  { id: "frame_blue_butterfly", kind: "frame", name: "Angel Wings", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 8, animation_type: "butterfly_wings", animation_ms: 2000 },
  { id: "frame_red_rose", kind: "frame", name: "Butterfly Dream", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 10, animation_type: "butterfly_wings", animation_ms: 2000 },
  { id: "frame_purple_star", kind: "frame", name: "Nature Flower", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 10, animation_type: "petal_sparkle", animation_ms: 2000 },
  { id: "frame_golden_flower", kind: "frame", name: "Dragon Flame", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 12, animation_type: "ember_sparkle", animation_ms: 2000 },
  { id: "frame_pink_blossom", kind: "frame", name: "Ice Crystal", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 12, animation_type: "crystal_twinkle", animation_ms: 2000 },
  { id: "frame_blue_angel_crown", kind: "frame", name: "Sakura Blossom", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 14, animation_type: "crown_shine", animation_ms: 2000 },
  { id: "frame_red_black_royal_wings", kind: "frame", name: "Galaxy Star", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 16, animation_type: "wing_shimmer", animation_ms: 2000 },
  { id: "frame_purple_butterfly", kind: "frame", name: "Ocean Pearl", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 14, animation_type: "butterfly_wings", animation_ms: 2000 },
  { id: "frame_royal_love", kind: "frame", name: "Dark Rose", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 16, animation_type: "heart_pulse", animation_ms: 2000 },
  { id: "frame_green_nature", kind: "frame", name: "Phoenix Fire", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 8, animation_type: "petal_sparkle", animation_ms: 2000 },

  { id: "vehicle_spark", kind: "vehicle", name: "Starlight Coupe", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "vehicle_royal", kind: "vehicle", name: "Royal Chariot", price_coins: 0, min_vip_level: 4, duration_days: 30, tier: 4 },
  { id: "vehicle_phoenix", kind: "vehicle", name: "Phoenix GT", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "vehicle_king", kind: "vehicle", name: "King of VIP", price_coins: 0, min_vip_level: 18, duration_days: 30, tier: 18 },

  { id: "profile-card-royal-gold", kind: "profile_card", name: "Royal Gold Card", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-card-pink-heart", kind: "profile_card", name: "Pink Heart Card", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-card-crystal-star", kind: "profile_card", name: "Crystal Star Card", price_coins: 0, min_vip_level: 3, duration_days: 30, tier: 3 },
  { id: "profile-card-vip-queen", kind: "profile_card", name: "VIP Queen Card", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "profile-card-family-leader", kind: "profile_card", name: "Family Leader Card", price_coins: 0, min_vip_level: 10, duration_days: 30, tier: 10 },
  { id: "profile-card-birthday", kind: "profile_card", name: "Birthday Card", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-card-winner", kind: "profile_card", name: "Winner Card", price_coins: 0, min_vip_level: 5, duration_days: 30, tier: 5 },

  { id: "ring-heart", kind: "ring", name: "Heart Ring", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "ring-crystal", kind: "ring", name: "Crystal Ring", price_coins: 0, min_vip_level: 3, duration_days: 30, tier: 3 },
  { id: "ring-royal", kind: "ring", name: "Royal Ring", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8 },

  { id: "profile-bg-night", kind: "profile_background", name: "Night Royal", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-bg-heart", kind: "profile_background", name: "Heart Glow", price_coins: 0, min_vip_level: 3, duration_days: 30, tier: 3 },
  { id: "profile-bg-diamond", kind: "profile_background", name: "Diamond Hall", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8 },

  { id: "entry-golden-sports-car", kind: "entry", name: "Golden Sports Car", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "entry-angel-wings", kind: "entry", name: "Angel Wings", price_coins: 0, min_vip_level: 4, duration_days: 30, tier: 4 },
  { id: "entry-rose-love-castle", kind: "entry", name: "Rose Love Castle", price_coins: 0, min_vip_level: 6, duration_days: 30, tier: 6 },
  { id: "entry-royal-lion", kind: "entry", name: "Royal Lion", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "entry-luxury-yacht", kind: "entry", name: "Luxury Yacht", price_coins: 0, min_vip_level: 10, duration_days: 30, tier: 10 },
  { id: "entry-princess-castle", kind: "entry", name: "Princess Castle", price_coins: 0, min_vip_level: 12, duration_days: 30, tier: 12 },
  { id: "entry-phoenix-fire", kind: "entry", name: "Phoenix Fire", price_coins: 0, min_vip_level: 14, duration_days: 30, tier: 14 },
  { id: "entry-diamond-ice", kind: "entry", name: "Diamond Ice", price_coins: 0, min_vip_level: 16, duration_days: 30, tier: 16 },
  { id: "entry-rocket-star", kind: "entry", name: "Rocket Star", price_coins: 0, min_vip_level: 17, duration_days: 30, tier: 17 },
  { id: "entry-winner-trophy", kind: "entry", name: "Winner Trophy", price_coins: 0, min_vip_level: 18, duration_days: 30, tier: 18 },

  { id: "bubble-gold", kind: "bubble", name: "Golden Bubble", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "bubble-heart", kind: "bubble", name: "Heart Bubble", price_coins: 0, min_vip_level: 2, duration_days: 30, tier: 2 },
  { id: "bubble-king", kind: "bubble", name: "King Bubble", price_coins: 0, min_vip_level: 10, duration_days: 30, tier: 10 },
  { id: "bubble-dream", kind: "bubble", name: "Dream Bubble", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 4 },
  { id: "bubble-nature", kind: "bubble", name: "Nature Bubble", price_coins: 0, min_vip_level: 0, duration_days: 0, tier: 5 },
  { id: "bubble-dragon", kind: "bubble", name: "Dragon Bubble", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "bubble-ice", kind: "bubble", name: "Ice Bubble", price_coins: 0, min_vip_level: 0, duration_days: 30, tier: 6 },
  { id: "bubble-sakura", kind: "bubble", name: "Sakura Bubble", price_coins: 0, min_vip_level: 5, duration_days: 30, tier: 5 },

// DarkVibeX VIP 1-18 dedicated entrance nameplates and full profile cards.
  { id: "entrance-vip-01", kind: "entry", name: "Royal Crown Entrance", price_coins: 0, min_vip_level: 1, duration_days: 30, tier: 1, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-02", kind: "entry", name: "Love Heart Entrance", price_coins: 0, min_vip_level: 2, duration_days: 30, tier: 2, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-03", kind: "entry", name: "Angel Wings Entrance", price_coins: 0, min_vip_level: 3, duration_days: 30, tier: 3, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-04", kind: "entry", name: "Butterfly Dream Entrance", price_coins: 0, min_vip_level: 4, duration_days: 30, tier: 4, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-05", kind: "entry", name: "Nature Flower Entrance", price_coins: 0, min_vip_level: 5, duration_days: 30, tier: 5, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-06", kind: "entry", name: "Dragon Flame Entrance", price_coins: 0, min_vip_level: 6, duration_days: 30, tier: 6, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-07", kind: "entry", name: "Ice Crystal Entrance", price_coins: 0, min_vip_level: 7, duration_days: 30, tier: 7, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-08", kind: "entry", name: "Sakura Blossom Entrance", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-09", kind: "entry", name: "Galaxy Star Entrance", price_coins: 0, min_vip_level: 9, duration_days: 30, tier: 9, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-10", kind: "entry", name: "Ocean Pearl Entrance", price_coins: 0, min_vip_level: 10, duration_days: 30, tier: 10, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-11", kind: "entry", name: "Dark Rose Entrance", price_coins: 0, min_vip_level: 11, duration_days: 30, tier: 11, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-12", kind: "entry", name: "Phoenix Fire Entrance", price_coins: 0, min_vip_level: 12, duration_days: 30, tier: 12, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-13", kind: "entry", name: "Celestial Violet Entrance", price_coins: 0, min_vip_level: 13, duration_days: 30, tier: 13, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-14", kind: "entry", name: "Solar Emperor Entrance", price_coins: 0, min_vip_level: 14, duration_days: 30, tier: 14, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-15", kind: "entry", name: "Nebula Dragon Entrance", price_coins: 0, min_vip_level: 15, duration_days: 30, tier: 15, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-16", kind: "entry", name: "Glacier King Entrance", price_coins: 0, min_vip_level: 16, duration_days: 30, tier: 16, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-17", kind: "entry", name: "Inferno Phoenix Entrance", price_coins: 0, min_vip_level: 17, duration_days: 30, tier: 17, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "entrance-vip-18", kind: "entry", name: "Eternal Sovereign Entrance", price_coins: 0, min_vip_level: 18, duration_days: 30, tier: 18, animation_type: "nameplate_glow", animation_ms: 2000 },
  { id: "profile-vip-01", kind: "profile_card", name: "Royal Crown Profile", price_coins: 0, min_vip_level: 1, duration_days: 30, tier: 1, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-02", kind: "profile_card", name: "Love Heart Profile", price_coins: 0, min_vip_level: 2, duration_days: 30, tier: 2, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-03", kind: "profile_card", name: "Angel Wings Profile", price_coins: 0, min_vip_level: 3, duration_days: 30, tier: 3, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-04", kind: "profile_card", name: "Butterfly Dream Profile", price_coins: 0, min_vip_level: 4, duration_days: 30, tier: 4, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-05", kind: "profile_card", name: "Nature Flower Profile", price_coins: 0, min_vip_level: 5, duration_days: 30, tier: 5, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-06", kind: "profile_card", name: "Dragon Flame Profile", price_coins: 0, min_vip_level: 6, duration_days: 30, tier: 6, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-07", kind: "profile_card", name: "Ice Crystal Profile", price_coins: 0, min_vip_level: 7, duration_days: 30, tier: 7, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-08", kind: "profile_card", name: "Sakura Blossom Profile", price_coins: 0, min_vip_level: 8, duration_days: 30, tier: 8, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-09", kind: "profile_card", name: "Galaxy Star Profile", price_coins: 0, min_vip_level: 9, duration_days: 30, tier: 9, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-10", kind: "profile_card", name: "Ocean Pearl Profile", price_coins: 0, min_vip_level: 10, duration_days: 30, tier: 10, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-11", kind: "profile_card", name: "Dark Rose Profile", price_coins: 0, min_vip_level: 11, duration_days: 30, tier: 11, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-12", kind: "profile_card", name: "Phoenix Fire Profile", price_coins: 0, min_vip_level: 12, duration_days: 30, tier: 12, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-13", kind: "profile_card", name: "Celestial Violet Profile", price_coins: 0, min_vip_level: 13, duration_days: 30, tier: 13, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-14", kind: "profile_card", name: "Solar Emperor Profile", price_coins: 0, min_vip_level: 14, duration_days: 30, tier: 14, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-15", kind: "profile_card", name: "Nebula Dragon Profile", price_coins: 0, min_vip_level: 15, duration_days: 30, tier: 15, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-16", kind: "profile_card", name: "Glacier King Profile", price_coins: 0, min_vip_level: 16, duration_days: 30, tier: 16, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-17", kind: "profile_card", name: "Inferno Phoenix Profile", price_coins: 0, min_vip_level: 17, duration_days: 30, tier: 17, animation_type: "profile_glow", animation_ms: 2000 },
  { id: "profile-vip-18", kind: "profile_card", name: "Eternal Sovereign Profile", price_coins: 0, min_vip_level: 18, duration_days: 30, tier: 18, animation_type: "profile_glow", animation_ms: 2000 },
];

const legacyKinds = new Set(["frame", "vehicle"]);

export async function ensureCosmeticsSchema(db) {
  if (readyDatabases.has(db)) return;
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_cosmetics (
    user_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('frame','vehicle')),
    acquired_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0,1)),
    PRIMARY KEY (user_id, item_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  await db.prepare("CREATE INDEX IF NOT EXISTS idx_user_cosmetics_active ON user_cosmetics(user_id, kind, active, expires_at)").run();

  // Non-legacy Tinni-style props live in a separate table so existing
  // installations keep their original frame/vehicle CHECK constraint safely.
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_props (
    user_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    acquired_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0,1)),
    PRIMARY KEY (user_id, item_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  await db.prepare("CREATE INDEX IF NOT EXISTS idx_user_props_active ON user_props(user_id, kind, active, expires_at)").run();
  readyDatabases.add(db);
}

export function cosmeticUsesLegacyTable(kind) {
  return legacyKinds.has(String(kind));
}

export function cosmeticTableForKind(kind) {
  return cosmeticUsesLegacyTable(kind) ? "user_cosmetics" : "user_props";
}

export async function ownedCosmetics(db, userId, ts = Date.now()) {
  await ensureCosmeticsSchema(db);
  const legacy = await db.prepare(
    "SELECT item_id,kind,acquired_at,expires_at,active FROM user_cosmetics WHERE user_id=? AND expires_at>? ORDER BY acquired_at DESC"
  ).bind(userId, ts).all();
  const props = await db.prepare(
    "SELECT item_id,kind,acquired_at,expires_at,active FROM user_props WHERE user_id=? AND expires_at>? ORDER BY acquired_at DESC"
  ).bind(userId, ts).all();
  return [...(legacy.results ?? []), ...(props.results ?? [])]
    .sort((a,b)=>Number(b.acquired_at??0)-Number(a.acquired_at??0));
}
