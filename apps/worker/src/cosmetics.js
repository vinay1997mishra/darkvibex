const readyDatabases = new WeakSet();

export const COSMETIC_CATALOG = [
  { id: "frame_royal", kind: "frame", name: "Royal Ember", price_coins: 12000, min_vip_level: 1, duration_days: 30, tier: 1 },
  { id: "frame_sapphire", kind: "frame", name: "Sapphire Crown", price_coins: 28000, min_vip_level: 4, duration_days: 30, tier: 4 },
  { id: "frame_phoenix", kind: "frame", name: "Phoenix Halo", price_coins: 60000, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "frame_king", kind: "frame", name: "King of VIP", price_coins: 120000, min_vip_level: 15, duration_days: 30, tier: 18 },

  { id: "frame_neon_rose", kind: "frame", name: "Neon Rose", price_coins: 18000, min_vip_level: 0, duration_days: 30, tier: 2 },
  { id: "frame_midnight_crown", kind: "frame", name: "Midnight Crown", price_coins: 26000, min_vip_level: 2, duration_days: 30, tier: 3 },
  { id: "frame_diamond_frost", kind: "frame", name: "Diamond Frost", price_coins: 36000, min_vip_level: 3, duration_days: 30, tier: 4 },
  { id: "frame_love_heart", kind: "frame", name: "Love Heart", price_coins: 46000, min_vip_level: 4, duration_days: 30, tier: 5 },
  { id: "frame_thunder_bolt", kind: "frame", name: "Thunder Bolt", price_coins: 58000, min_vip_level: 5, duration_days: 30, tier: 6 },
  { id: "frame_emerald_royal", kind: "frame", name: "Emerald Royal", price_coins: 70000, min_vip_level: 6, duration_days: 30, tier: 7 },
  { id: "frame_starlight", kind: "frame", name: "Starlight", price_coins: 82000, min_vip_level: 7, duration_days: 30, tier: 8 },
  { id: "frame_dragon_fire", kind: "frame", name: "Dragon Fire", price_coins: 96000, min_vip_level: 8, duration_days: 30, tier: 10 },
  { id: "frame_angel_wings", kind: "frame", name: "Angel Wings", price_coins: 110000, min_vip_level: 10, duration_days: 30, tier: 12 },
  { id: "frame_cosmic_galaxy", kind: "frame", name: "Cosmic Galaxy", price_coins: 126000, min_vip_level: 12, duration_days: 30, tier: 14 },
  { id: "frame_black_gold", kind: "frame", name: "Black Gold", price_coins: 144000, min_vip_level: 14, duration_days: 30, tier: 16 },
  { id: "frame_queen_crown", kind: "frame", name: "Queen Crown", price_coins: 165000, min_vip_level: 16, duration_days: 30, tier: 18 },

  { id: "vehicle_spark", kind: "vehicle", name: "Starlight Coupe", price_coins: 25000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "vehicle_royal", kind: "vehicle", name: "Royal Chariot", price_coins: 65000, min_vip_level: 4, duration_days: 30, tier: 4 },
  { id: "vehicle_phoenix", kind: "vehicle", name: "Phoenix GT", price_coins: 140000, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "vehicle_king", kind: "vehicle", name: "King of VIP", price_coins: 280000, min_vip_level: 18, duration_days: 30, tier: 18 },

  { id: "profile-card-royal-gold", kind: "profile_card", name: "Royal Gold Card", price_coins: 20000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-card-pink-heart", kind: "profile_card", name: "Pink Heart Card", price_coins: 30000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-card-crystal-star", kind: "profile_card", name: "Crystal Star Card", price_coins: 45000, min_vip_level: 3, duration_days: 30, tier: 3 },
  { id: "profile-card-vip-queen", kind: "profile_card", name: "VIP Queen Card", price_coins: 90000, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "profile-card-family-leader", kind: "profile_card", name: "Family Leader Card", price_coins: 120000, min_vip_level: 10, duration_days: 30, tier: 10 },
  { id: "profile-card-birthday", kind: "profile_card", name: "Birthday Card", price_coins: 18000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-card-winner", kind: "profile_card", name: "Winner Card", price_coins: 75000, min_vip_level: 5, duration_days: 30, tier: 5 },

  { id: "ring-heart", kind: "ring", name: "Heart Ring", price_coins: 18000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "ring-crystal", kind: "ring", name: "Crystal Ring", price_coins: 42000, min_vip_level: 3, duration_days: 30, tier: 3 },
  { id: "ring-royal", kind: "ring", name: "Royal Ring", price_coins: 95000, min_vip_level: 8, duration_days: 30, tier: 8 },

  { id: "profile-bg-night", kind: "profile_background", name: "Night Royal", price_coins: 25000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "profile-bg-heart", kind: "profile_background", name: "Heart Glow", price_coins: 50000, min_vip_level: 3, duration_days: 30, tier: 3 },
  { id: "profile-bg-diamond", kind: "profile_background", name: "Diamond Hall", price_coins: 110000, min_vip_level: 8, duration_days: 30, tier: 8 },

  { id: "entry-golden-sports-car", kind: "entry", name: "Golden Sports Car", price_coins: 40000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "entry-angel-wings", kind: "entry", name: "Angel Wings", price_coins: 70000, min_vip_level: 4, duration_days: 30, tier: 4 },
  { id: "entry-rose-love-castle", kind: "entry", name: "Rose Love Castle", price_coins: 90000, min_vip_level: 6, duration_days: 30, tier: 6 },
  { id: "entry-royal-lion", kind: "entry", name: "Royal Lion", price_coins: 120000, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "entry-luxury-yacht", kind: "entry", name: "Luxury Yacht", price_coins: 160000, min_vip_level: 10, duration_days: 30, tier: 10 },
  { id: "entry-princess-castle", kind: "entry", name: "Princess Castle", price_coins: 200000, min_vip_level: 12, duration_days: 30, tier: 12 },
  { id: "entry-phoenix-fire", kind: "entry", name: "Phoenix Fire", price_coins: 240000, min_vip_level: 14, duration_days: 30, tier: 14 },
  { id: "entry-diamond-ice", kind: "entry", name: "Diamond Ice", price_coins: 280000, min_vip_level: 16, duration_days: 30, tier: 16 },
  { id: "entry-rocket-star", kind: "entry", name: "Rocket Star", price_coins: 320000, min_vip_level: 17, duration_days: 30, tier: 17 },
  { id: "entry-winner-trophy", kind: "entry", name: "Winner Trophy", price_coins: 380000, min_vip_level: 18, duration_days: 30, tier: 18 },

  { id: "bubble-gold", kind: "bubble", name: "Golden Bubble", price_coins: 15000, min_vip_level: 0, duration_days: 30, tier: 1 },
  { id: "bubble-heart", kind: "bubble", name: "Heart Bubble", price_coins: 35000, min_vip_level: 2, duration_days: 30, tier: 2 },
  { id: "bubble-king", kind: "bubble", name: "King Bubble", price_coins: 90000, min_vip_level: 10, duration_days: 30, tier: 10 },
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
