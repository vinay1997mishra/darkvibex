export const ID_LEVEL_MAX = 100;
export const ID_LEVEL_FIRST_REQUIREMENTS = Object.freeze([10000, 13000, 18000, 25000, 36000]);

export function idLevelRequirement(level) {
  const n = Math.max(1, Math.floor(Number(level) || 1));
  if (n <= ID_LEVEL_FIRST_REQUIREMENTS.length) return ID_LEVEL_FIRST_REQUIREMENTS[n - 1];
  let amount = ID_LEVEL_FIRST_REQUIREMENTS.at(-1);
  for (let i = 6; i <= n; i += 1) amount = Math.round((amount * 1.4) / 1000) * 1000;
  return amount;
}

export async function ensureIdLevelSchema(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS user_id_levels (
      user_id TEXT PRIMARY KEY,
      level INTEGER NOT NULL DEFAULT 0,
      exp_in_level INTEGER NOT NULL DEFAULT 0,
      total_exp INTEGER NOT NULL DEFAULT 0,
      coin_remainder INTEGER NOT NULL DEFAULT 0,
      last_room_entry_day INTEGER NOT NULL DEFAULT -1,
      last_room_share_day INTEGER NOT NULL DEFAULT -1,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_user_id_levels_level ON user_id_levels(level)"),
  ]);
}

export async function getIdLevel(db, userId, ts = Date.now()) {
  await ensureIdLevelSchema(db);
  await db.prepare("INSERT OR IGNORE INTO user_id_levels (user_id,updated_at) VALUES (?,?)").bind(userId, ts).run();
  const row = await db.prepare("SELECT * FROM user_id_levels WHERE user_id=?").bind(userId).first();
  const level = Number(row?.level ?? 0);
  return {
    level,
    exp_in_level: Number(row?.exp_in_level ?? 0),
    total_exp: Number(row?.total_exp ?? 0),
    next_level_exp: level >= ID_LEVEL_MAX ? 0 : idLevelRequirement(level + 1),
    coin_remainder: Number(row?.coin_remainder ?? 0),
    max_level: ID_LEVEL_MAX,
  };
}

async function applyExp(db, userId, amount, ts) {
  let left = Math.max(0, Math.floor(Number(amount) || 0));
  if (!left) return getIdLevel(db, userId, ts);
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const current = await getIdLevel(db, userId, ts);
    if (current.level >= ID_LEVEL_MAX) return current;
    const target = current.next_level_exp;
    let level = current.level;
    let exp = current.exp_in_level + left;
    if (exp >= target) {
      level += 1;
      exp = 0; // A level-up starts the next level at zero; overflow is discarded.
    }
    const result = await db.prepare(`UPDATE user_id_levels SET level=?,exp_in_level=?,total_exp=total_exp+?,updated_at=?
      WHERE user_id=? AND level=? AND exp_in_level=?`)
      .bind(level, exp, left, ts, userId, current.level, current.exp_in_level).run();
    if (Number(result?.meta?.changes ?? 0) === 1) return getIdLevel(db, userId, ts);
  }
  throw new Error("id_level_update_conflict");
}

export async function awardIdLevelGiftCoins(db, userId, coins, ts = Date.now()) {
  await ensureIdLevelSchema(db);
  await db.prepare("INSERT OR IGNORE INTO user_id_levels (user_id,updated_at) VALUES (?,?)").bind(userId, ts).run();
  const spentCoins = Math.max(0, Math.floor(Number(coins) || 0));
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const row = await db.prepare("SELECT coin_remainder FROM user_id_levels WHERE user_id=?").bind(userId).first();
    const remainder = Number(row?.coin_remainder ?? 0);
    const total = remainder + spentCoins;
    const exp = Math.floor(total / 400);
    const stored = await db.prepare("UPDATE user_id_levels SET coin_remainder=?,updated_at=? WHERE user_id=? AND coin_remainder=?")
      .bind(total % 400, ts, userId, remainder).run();
    if (Number(stored?.meta?.changes ?? 0) === 1) return applyExp(db, userId, exp, ts);
  }
  throw new Error("id_level_update_conflict");
}

export async function awardIdLevelDailyActivity(db, userId, activity, ts = Date.now()) {
  await ensureIdLevelSchema(db);
  const column = activity === "room_entry" ? "last_room_entry_day" : activity === "room_share" ? "last_room_share_day" : "";
  const amount = activity === "room_entry" ? 70 : activity === "room_share" ? 75 : 0;
  if (!column) throw new Error("invalid_id_level_activity");
  const day = Math.floor(ts / 86400000);
  await db.prepare("INSERT OR IGNORE INTO user_id_levels (user_id,updated_at) VALUES (?,?)").bind(userId, ts).run();
  const result = await db.prepare(`UPDATE user_id_levels SET ${column}=?,updated_at=? WHERE user_id=? AND ${column}<>?`)
    .bind(day, ts, userId, day).run();
  if (Number(result?.meta?.changes ?? 0) !== 1) return { ...await getIdLevel(db, userId, ts), awarded_exp: 0 };
  return { ...await applyExp(db, userId, amount, ts), awarded_exp: amount };
}
