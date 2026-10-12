import {
  calculateIdLevel,
  idLevelRewards,
  ID_LEVEL_GIFT_COINS_PER_EXP,
  ID_LEVEL_ROOM_ENTRY_EXP_PER_DAY,
  ID_LEVEL_ROOM_SHARE_EXP_PER_DAY,
} from './id_level_policy.js';

export async function ensureIdLevelTables(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS user_id_level_gifts (
      event_id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      coins INTEGER NOT NULL CHECK (coins > 0),
      created_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS user_id_level_daily (
      user_id TEXT NOT NULL,
      activity TEXT NOT NULL CHECK (activity IN ('room_entry','room_share')),
      day_key TEXT NOT NULL,
      exp INTEGER NOT NULL CHECK (exp > 0),
      created_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, activity, day_key),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS user_id_level_claims (
      user_id TEXT NOT NULL,
      level INTEGER NOT NULL CHECK (level > 0),
      claimed_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, level),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
  ]);
}

export function indiaDayKey(ts = Date.now()) {
  return new Date(Number(ts) + 19800000).toISOString().slice(0, 10);
}

export async function awardIdLevelGift(db, userId, coins, eventId, ts = Date.now()) {
  await ensureIdLevelTables(db);
  if (!Number.isSafeInteger(Number(coins)) || Number(coins) <= 0 || !eventId) return null;
  await db.prepare(
    'INSERT OR IGNORE INTO user_id_level_gifts (event_id,user_id,coins,created_at) VALUES (?,?,?,?)'
  ).bind(String(eventId), String(userId), Number(coins), Number(ts)).run();
}

export async function awardIdLevelDaily(db, userId, activity, ts = Date.now()) {
  await ensureIdLevelTables(db);
  const points = activity === 'room_entry'
    ? ID_LEVEL_ROOM_ENTRY_EXP_PER_DAY
    : activity === 'room_share'
      ? ID_LEVEL_ROOM_SHARE_EXP_PER_DAY
      : 0;
  if (!points) throw new Error('invalid_id_level_activity');
  const result = await db.prepare(
    'INSERT OR IGNORE INTO user_id_level_daily (user_id,activity,day_key,exp,created_at) VALUES (?,?,?,?,?)'
  ).bind(String(userId), activity, indiaDayKey(ts), points, Number(ts)).run();
  return Number(result?.meta?.changes ?? 0) > 0 ? points : 0;
}

export async function getIdLevelStatus(db, userId) {
  await ensureIdLevelTables(db);
  const [gift, daily, claims] = await Promise.all([
    db.prepare('SELECT COALESCE(SUM(coins),0) AS coins FROM user_id_level_gifts WHERE user_id=?')
      .bind(String(userId)).first(),
    db.prepare('SELECT COALESCE(SUM(exp),0) AS exp FROM user_id_level_daily WHERE user_id=?')
      .bind(String(userId)).first(),
    db.prepare('SELECT level FROM user_id_level_claims WHERE user_id=? ORDER BY level')
      .bind(String(userId)).all(),
  ]);
  const giftCoins = Number(gift?.coins ?? 0);
  const giftExp = Math.floor(giftCoins / ID_LEVEL_GIFT_COINS_PER_EXP);
  const dailyExp = Number(daily?.exp ?? 0);
  const totalExp = giftExp + dailyExp;
  const progression = calculateIdLevel(totalExp);
  const claimed = new Set((claims.results ?? []).map(row => Number(row.level)));
  return {
    level: progression.level,
    exp: progression.exp,
    exp_to_next: progression.exp_to_next,
    total_exp: totalExp,
    gift_coins_consumed: giftCoins,
    gift_coins_per_exp: ID_LEVEL_GIFT_COINS_PER_EXP,
    daily_exp: dailyExp,
    daily_rewards: {
      room_entry: ID_LEVEL_ROOM_ENTRY_EXP_PER_DAY,
      room_share: ID_LEVEL_ROOM_SHARE_EXP_PER_DAY,
    },
    claimed_levels: [...claimed],
    rewards: idLevelRewards(progression.level).map(reward => ({
      ...reward,
      claimed: claimed.has(reward.level),
    })),
  };
}

export async function claimIdLevelReward(db, userId, level, ts = Date.now()) {
  await ensureIdLevelTables(db);
  const status = await getIdLevelStatus(db, userId);
  const rewardLevel = Number(level);
  if (!Number.isSafeInteger(rewardLevel) || rewardLevel < 1 || rewardLevel > status.level) {
    return { ok: false, error: 'id_level_reward_locked' };
  }
  const reward = status.rewards.find(item => item.level === rewardLevel);
  if (!reward || reward.claimed) return { ok: false, error: 'id_level_reward_claimed' };
  const result = await db.prepare(
    'INSERT OR IGNORE INTO user_id_level_claims (user_id,level,claimed_at) VALUES (?,?,?)'
  ).bind(String(userId), rewardLevel, Number(ts)).run();
  if (Number(result?.meta?.changes ?? 0) === 0) {
    return { ok: false, error: 'id_level_reward_claimed' };
  }
  return { ok: true, reward };
}
