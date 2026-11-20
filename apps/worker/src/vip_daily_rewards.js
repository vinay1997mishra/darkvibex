// VIP Daily Rewards (Vinay, 2026-11-20): a VIP-active user claims coins
// once per UTC day, from VIP5 onwards. The reward is 70% of the VIP
// level's $ value, spread over 30 days — so the per-day claim is
// (level $ value x 0.70) / 30, paid in coins at the server coin rate
// ($1 = 8,000,000 coins by default, owner setting `economy.coin_rate`).
// The level $ value is the cumulative EXP threshold / 150 EXP per $1
// (VIP5 $150 ... VIP18 $10,000 — see vip_policy.js). VIP1-4 get no
// daily reward (min level 5).
//
// Claims are server-validated and idempotent: one claim row per
// (user, UTC day), coins credited only when this claim's row exists,
// and the wallet ledger carries reference `vip-daily-reward:<user>:<day>`
// so a retry can never double-pay. Claim rows are financial records
// (they back the wallet ledger) and are NEVER age-deleted by the
// retention jobs.
import { vipRule } from "./vip_policy.js";
import { getVipStatus } from "./vip_store.js";

export const DAILY_REWARD_MIN_LEVEL = 5;
const EXP_PER_USD = 150;
const REWARD_DAYS = 30;
const REWARD_FRACTION_NUM = 70;
const REWARD_FRACTION_DEN = 100;
const DEFAULT_COINS_PER_USD = 8000000;
const DAY_MS = 24 * 60 * 60 * 1000;

/// Per-day coin reward for a VIP [level] at [coinsPerUsd] coins per $1.
//  Floored to whole coins. 0 for levels below the minimum, unknown
// levels, or a bad coin rate.
export function dailyRewardCoinsForLevel(level, coinsPerUsd) {
  const vipLevel = Number(level);
  if (!Number.isInteger(vipLevel) || vipLevel < DAILY_REWARD_MIN_LEVEL) {
    return 0;
  }
  const rule = vipRule(vipLevel);
  if (!rule) return 0;
  const dollars = rule.total / EXP_PER_USD;
  if (!Number.isInteger(dollars)) return 0;
  const rate = Number(coinsPerUsd);
  if (!Number.isSafeInteger(rate) || rate <= 0) return 0;
  return Math.floor(
    (dollars * REWARD_FRACTION_NUM * rate) /
      (REWARD_FRACTION_DEN * REWARD_DAYS),
  );
}

/// UTC day number for a timestamp (claims reset at UTC midnight).
export function vipDailyRewardEpochDay(timestampMs) {
  return Math.floor(Number(timestampMs) / DAY_MS);
}

export async function ensureVipDailyRewardSchema(db) {
  await db
    .prepare(
      `CREATE TABLE IF NOT EXISTS vip_daily_reward_claims (
        user_id TEXT NOT NULL,
        claim_epoch_day INTEGER NOT NULL,
        level INTEGER NOT NULL,
        coins INTEGER NOT NULL,
        claim_key TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, claim_epoch_day)
      )`,
    )
    .run();
}

async function coinsPerUsd(db) {
  try {
    const row = await db
      .prepare(
        "SELECT value_json FROM owner_settings WHERE key = 'economy.coin_rate'",
      )
      .first();
    if (!row?.value_json) return DEFAULT_COINS_PER_USD;
    const parsed = JSON.parse(String(row.value_json));
    const rate = Number(parsed?.coins_per_usd);
    return Number.isSafeInteger(rate) && rate > 0
      ? rate
      : DEFAULT_COINS_PER_USD;
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) {
      return DEFAULT_COINS_PER_USD;
    }
    throw error;
  }
}

export async function vipDailyRewardStatus(db, userId, ts = Date.now()) {
  await ensureVipDailyRewardSchema(db);
  const vip = await getVipStatus(db, userId, ts);
  const level = vip.active ? Number(vip.level ?? 0) : 0;
  const rate = await coinsPerUsd(db);
  const amount = dailyRewardCoinsForLevel(level, rate);
  const today = vipDailyRewardEpochDay(ts);
  const row = await db
    .prepare(
      "SELECT coins FROM vip_daily_reward_claims WHERE user_id=? AND claim_epoch_day=? LIMIT 1",
    )
    .bind(userId, today)
    .first();
  return {
    eligible: vip.active && level >= DAILY_REWARD_MIN_LEVEL,
    active: vip.active,
    level,
    amount_coins: amount,
    claimed_today: row != null,
    claimed_coins: row == null ? 0 : Number(row.coins ?? 0),
    day: today,
  };
}

export async function claimVipDailyReward(db, userId, ts = Date.now(), newId) {
  await ensureVipDailyRewardSchema(db);
  const status = await vipDailyRewardStatus(db, userId, ts);
  const today = vipDailyRewardEpochDay(ts);

  if (status.claimed_today) {
    const user = await db
      .prepare("SELECT coins FROM users WHERE id=?")
      .bind(userId)
      .first();
    return {
      ok: true,
      duplicate: true,
      reward: 0,
      coin_balance: Number(user?.coins ?? 0),
      ...status,
    };
  }
  if (!status.active) {
    return { ok: false, error: "vip_inactive", ...status };
  }
  if (!status.eligible) {
    return { ok: false, error: "vip_daily_reward_locked", ...status };
  }

  const reward = Number(status.amount_coins);
  if (!Number.isSafeInteger(reward) || reward <= 0) {
    return { ok: false, error: "vip_daily_reward_amount", ...status };
  }
  const claimKey = newId();
  const referenceId = `vip-daily-reward:${userId}:${today}`;

  await db.batch([
    db
      .prepare(
        `INSERT OR IGNORE INTO vip_daily_reward_claims(
          user_id,claim_epoch_day,level,coins,claim_key,created_at
        ) VALUES(?,?,?,?,?,?)`,
      )
      .bind(userId, today, status.level, reward, claimKey, ts),
    db
      .prepare(
        `UPDATE users
            SET coins=coins+?,updated_at=?
          WHERE id=?
            AND EXISTS(
              SELECT 1 FROM vip_daily_reward_claims WHERE claim_key=?
            )`,
      )
      .bind(reward, ts, userId, claimKey),
    db
      .prepare(
        `INSERT INTO wallet_ledger(
          id,user_id,kind,amount,balance_after,reference_id,created_at
        )
        SELECT ?,u.id,'vip_daily_reward',?,u.coins,?,?
          FROM users u
         WHERE u.id=?
           AND EXISTS(
             SELECT 1 FROM vip_daily_reward_claims WHERE claim_key=?
           )`,
      )
      .bind(newId(), reward, referenceId, ts, userId, claimKey),
  ]);

  const claim = await db
    .prepare(
      "SELECT claim_key,level,coins FROM vip_daily_reward_claims WHERE user_id=? AND claim_epoch_day=? LIMIT 1",
    )
    .bind(userId, today)
    .first();
  const user = await db
    .prepare("SELECT coins FROM users WHERE id=?")
    .bind(userId)
    .first();
  const current = await vipDailyRewardStatus(db, userId, ts);
  const ownClaim = String(claim?.claim_key ?? "") === claimKey;
  return {
    ok: true,
    duplicate: !ownClaim,
    reward: ownClaim ? Number(claim?.coins ?? reward) : 0,
    level: ownClaim ? Number(claim?.level ?? status.level) : status.level,
    coin_balance: Number(user?.coins ?? 0),
    ...current,
  };
}
