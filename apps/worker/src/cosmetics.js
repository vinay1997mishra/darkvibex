const readyDatabases = new WeakSet();

export const COSMETIC_CATALOG = [
  { id: "frame_royal", kind: "frame", name: "Royal Ember", price_coins: 12000, min_vip_level: 1, duration_days: 30, tier: 1 },
  { id: "frame_sapphire", kind: "frame", name: "Sapphire Crown", price_coins: 28000, min_vip_level: 4, duration_days: 30, tier: 4 },
  { id: "frame_phoenix", kind: "frame", name: "Phoenix Halo", price_coins: 60000, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "frame_king", kind: "frame", name: "King of VIP", price_coins: 120000, min_vip_level: 15, duration_days: 30, tier: 18 },
  { id: "vehicle_spark", kind: "vehicle", name: "Starlight Coupe", price_coins: 25000, min_vip_level: 8, duration_days: 30, tier: 8 },
  { id: "vehicle_royal", kind: "vehicle", name: "Royal Chariot", price_coins: 65000, min_vip_level: 12, duration_days: 30, tier: 12 },
  { id: "vehicle_phoenix", kind: "vehicle", name: "Phoenix GT", price_coins: 140000, min_vip_level: 16, duration_days: 30, tier: 16 },
  { id: "vehicle_king", kind: "vehicle", name: "King of VIP", price_coins: 280000, min_vip_level: 18, duration_days: 30, tier: 18 },
];

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
  readyDatabases.add(db);
}
