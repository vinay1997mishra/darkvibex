import {
  applyIdLevelExp,
  idLevelRewards,
  idLevelExpToNext,
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
    db.prepare(`CREATE TABLE IF NOT EXISTS user_id_level_exp_state (
      user_id TEXT PRIMARY KEY,
      level INTEGER NOT NULL DEFAULT 0 CHECK (level >= 0),
      exp INTEGER NOT NULL DEFAULT 0 CHECK (exp >= 0),
      gift_coin_remainder INTEGER NOT NULL DEFAULT 0 CHECK (gift_coin_remainder >= 0),
      raw_exp INTEGER NOT NULL DEFAULT 0 CHECK (raw_exp >= 0),
      revision INTEGER NOT NULL DEFAULT 0,
      last_event_id TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS user_id_level_exp_events (
      event_id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      source TEXT NOT NULL CHECK (source IN ('gift','room_entry','room_share')),
      coins INTEGER NOT NULL DEFAULT 0 CHECK (coins >= 0),
      exp INTEGER NOT NULL DEFAULT 0 CHECK (exp >= 0),
      created_at INTEGER NOT NULL,
      processed INTEGER NOT NULL DEFAULT 0 CHECK (processed IN (0,1)),
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

async function ensureProgressRow(db, userId) {
  await db.prepare(
    'INSERT OR IGNORE INTO user_id_level_exp_state (user_id) VALUES (?)'
  ).bind(String(userId)).run();
}

async function applyPendingIdLevelEvents(db, userId) {
  await ensureProgressRow(db, userId);
  const uid = String(userId);
  for (let count = 0; count < 500; count += 1) {
    const event = await db.prepare(
      'SELECT event_id,source,coins,exp FROM user_id_level_exp_events WHERE user_id=? AND processed=0 ORDER BY created_at,event_id LIMIT 1'
    ).bind(uid).first();
    if (!event) return;

    const state = await db.prepare(
      'SELECT level,exp,gift_coin_remainder,raw_exp,revision FROM user_id_level_exp_state WHERE user_id=?'
    ).bind(uid).first();
    const oldLevel = Number(state?.level ?? 0);
    const oldExp = Number(state?.exp ?? 0);
    let remainder = Number(state?.gift_coin_remainder ?? 0);
    let earnedExp = Number(event.exp ?? 0);
    if (event.source === 'gift') {
      const coins = Number(event.coins ?? 0);
      const coinTotal = remainder + coins;
      earnedExp = Math.floor(coinTotal / ID_LEVEL_GIFT_COINS_PER_EXP);
      remainder = coinTotal % ID_LEVEL_GIFT_COINS_PER_EXP;
    }
    const next = applyIdLevelExp(oldLevel, oldExp, earnedExp);
    const revision = Number(state?.revision ?? 0) + 1;
    const batch = await db.batch([
      db.prepare(`UPDATE user_id_level_exp_state
        SET level=?,exp=?,gift_coin_remainder=?,raw_exp=raw_exp+?,revision=?,last_event_id=?
        WHERE user_id=? AND revision=?
        AND EXISTS (SELECT 1 FROM user_id_level_exp_events WHERE event_id=? AND user_id=? AND processed=0)`)
        .bind(next.level, next.exp, remainder, earnedExp, revision, event.event_id, uid,
          Number(state?.revision ?? 0), event.event_id, uid),
      db.prepare(`UPDATE user_id_level_exp_events SET processed=1
        WHERE event_id=? AND user_id=? AND processed=0
        AND EXISTS (SELECT 1 FROM user_id_level_exp_state WHERE user_id=? AND revision=? AND last_event_id=?)`)
        .bind(event.event_id, uid, uid, revision, event.event_id),
    ]);
    if (Number(batch?.[1]?.meta?.changes ?? 0) === 0) {
      // Another request advanced the same user's state; reload and apply this event against it.
      continue;
    }
  }
}

export async function awardIdLevelGift(db, userId, coins, eventId, ts = Date.now()) {
  await ensureIdLevelTables(db);
  if (!Number.isSafeInteger(Number(coins)) || Number(coins) <= 0 || !eventId) return null;
  const uid = String(userId);
  const amount = Number(coins);
  const id = `idlevel-gift:${uid}:${String(eventId)}`;
  await db.batch([
    db.prepare(
      'INSERT OR IGNORE INTO user_id_level_gifts (event_id,user_id,coins,created_at) VALUES (?,?,?,?)'
    ).bind(String(eventId), uid, amount, Number(ts)),
    db.prepare(
      'INSERT OR IGNORE INTO user_id_level_exp_events (event_id,user_id,source,coins,exp,created_at) VALUES (?,?,?,?,0,?)'
    ).bind(id, uid, 'gift', amount, Number(ts)),
  ]);
  await applyPendingIdLevelEvents(db, uid);
}

export async function awardIdLevelDaily(db, userId, activity, ts = Date.now()) {
  await ensureIdLevelTables(db);
  const points = activity === 'room_entry'
    ? ID_LEVEL_ROOM_ENTRY_EXP_PER_DAY
    : activity === 'room_share'
      ? ID_LEVEL_ROOM_SHARE_EXP_PER_DAY
      : 0;
  if (!points) throw new Error('invalid_id_level_activity');
  const uid = String(userId);
  const dayKey = indiaDayKey(ts);
  const eventId = `idlevel-daily:${uid}:${activity}:${dayKey}`;
  const result = await db.batch([
    db.prepare(
      'INSERT OR IGNORE INTO user_id_level_daily (user_id,activity,day_key,exp,created_at) VALUES (?,?,?,?,?)'
    ).bind(uid, activity, dayKey, points, Number(ts)),
    db.prepare(
      'INSERT OR IGNORE INTO user_id_level_exp_events (event_id,user_id,source,coins,exp,created_at) VALUES (?,?,?,0,?,?)'
    ).bind(eventId, uid, activity, points, Number(ts)),
  ]);
  await applyPendingIdLevelEvents(db, uid);
  return Number(result?.[0]?.meta?.changes ?? 0) > 0 ? points : 0;
}

export async function getIdLevelStatus(db, userId) {
  await ensureIdLevelTables(db);
  const uid = String(userId);
  await applyPendingIdLevelEvents(db, uid);
  const [gift, daily, claims, state] = await Promise.all([
    db.prepare('SELECT COALESCE(SUM(coins),0) AS coins FROM user_id_level_gifts WHERE user_id=?')
      .bind(uid).first(),
    db.prepare('SELECT COALESCE(SUM(exp),0) AS exp FROM user_id_level_daily WHERE user_id=?')
      .bind(uid).first(),
    db.prepare('SELECT level FROM user_id_level_claims WHERE user_id=? ORDER BY level')
      .bind(uid).all(),
    db.prepare('SELECT level,exp,raw_exp FROM user_id_level_exp_state WHERE user_id=?')
      .bind(uid).first(),
  ]);
  const giftCoins = Number(gift?.coins ?? 0);
  const giftExp = Math.floor(giftCoins / ID_LEVEL_GIFT_COINS_PER_EXP);
  const dailyExp = Number(daily?.exp ?? 0);
  const level = Number(state?.level ?? 0);
  const exp = Number(state?.exp ?? 0);
  const claimed = new Set((claims.results ?? []).map(row => Number(row.level)));
  return {
    level,
    exp,
    exp_to_next: idLevelExpToNext(level),
    total_exp: Number(state?.raw_exp ?? giftExp + dailyExp),
    gift_coins_consumed: giftCoins,
    gift_coins_per_exp: ID_LEVEL_GIFT_COINS_PER_EXP,
    daily_exp: dailyExp,
    daily_rewards: {
      room_entry: ID_LEVEL_ROOM_ENTRY_EXP_PER_DAY,
      room_share: ID_LEVEL_ROOM_SHARE_EXP_PER_DAY,
    },
    claimed_levels: [...claimed],
    rewards: idLevelRewards(level).map(reward => ({
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
