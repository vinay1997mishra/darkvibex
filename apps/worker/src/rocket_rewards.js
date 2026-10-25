import { ensureCosmeticsSchema } from "./cosmetics.js";

// Rocket target chest rewards. Reward pools are per room + reached rocket level.

export const ROCKET_REWARD_TIERS = Object.freeze([
  Object.freeze({
    minLevel: 1, maxLevel: 3, group: "1-3", label: "Rocket Levels 1–3",
    maxWinners: 50, frameWinners: 25, coinMin: 10_000, coinMax: 20_000, frameDays: 1,
  }),
  Object.freeze({
    minLevel: 4, maxLevel: 6, group: "4-6", label: "Rocket Levels 4–6",
    maxWinners: 70, frameWinners: 25, coinMin: 30_000, coinMax: 60_000, frameDays: 5,
  }),
  Object.freeze({
    minLevel: 7, maxLevel: 9, group: "7-9", label: "Rocket Levels 7–9",
    maxWinners: 80, frameWinners: 25, coinMin: 30_000, coinMax: 200_000, frameDays: 7,
  }),
  Object.freeze({
    minLevel: 10, maxLevel: 12, group: "10-12", label: "Rocket Levels 10–12",
    maxWinners: 100, frameWinners: 25, coinMin: 50_000, coinMax: 300_000, frameDays: 10,
  }),
]);

export const ROCKET_FRAME_REWARDS = Object.freeze({
  "1-3": Object.freeze({ id: "rocket_frame_aurora", name: "Rocket Aurora" }),
  "4-6": Object.freeze({ id: "rocket_frame_neon_wings", name: "Rocket Neon Wings" }),
  "7-9": Object.freeze({ id: "rocket_frame_golden_comet", name: "Rocket Golden Comet" }),
  "10-12": Object.freeze({ id: "rocket_frame_purple_nova", name: "Rocket Purple Nova" }),
});

export function rocketFrameRewardForGroup(group) {
  return ROCKET_FRAME_REWARDS[String(group ?? "")] ?? null;
}

// These milestone targets must stay aligned with apps/mobile/lib/utils/rocket_progress.dart.
export const ROCKET_MILESTONE_TARGETS = Object.freeze([
  8_000_000,
  15_000_000,
  30_000_000,
  50_000_000,
  90_000_000,
  150_000_000,
  200_000_000,
  250_000_000,
  350_000_000,
  500_000_000,
  650_000_000,
  800_000_000,
]);

export function rocketRewardConfigForLevel(level) {
  const safeLevel = Number(level);
  if (!Number.isInteger(safeLevel) || safeLevel < 1 || safeLevel > 12) return null;
  return ROCKET_REWARD_TIERS.find(
    (tier) => safeLevel >= tier.minLevel && safeLevel <= tier.maxLevel,
  ) ?? null;
}

export function rocketTargetForLevel(level) {
  const safeLevel = Number(level);
  if (!Number.isInteger(safeLevel) || safeLevel < 1) return null;
  return ROCKET_MILESTONE_TARGETS[safeLevel - 1] ?? null;
}

export function assignRocketReward(tier, claimedCount, randomValue = 0) {
  if (!tier || !Number.isInteger(claimedCount) || claimedCount < 0) {
    throw new TypeError("A reward tier and non-negative claimed count are required.");
  }
  if (claimedCount >= tier.maxWinners) return null;
  if (claimedCount < tier.frameWinners) {
    return {
      reward_type: "frame",
      coin_amount: 0,
      frame_days: tier.frameDays,
      frame_delivery_status: "pending_assets",
    };
  }
  const normalized = Math.max(0, Math.min(0.999999999999, Number(randomValue) || 0));
  const range = tier.coinMax - tier.coinMin + 1;
  return {
    reward_type: "coins",
    coin_amount: tier.coinMin + Math.floor(normalized * range),
    frame_days: 0,
    frame_delivery_status: "not_applicable",
  };
}

async function ensureRocketRewardSchema(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS rocket_reward_claims (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      rocket_level INTEGER NOT NULL CHECK (rocket_level BETWEEN 1 AND 12),
      reward_group TEXT NOT NULL CHECK (reward_group IN ('1-3','4-6','7-9','10-12')),
      user_id TEXT NOT NULL,
      reward_type TEXT NOT NULL CHECK (reward_type IN ('coins','frame')),
      coin_amount INTEGER NOT NULL DEFAULT 0 CHECK (coin_amount >= 0),
      frame_days INTEGER NOT NULL DEFAULT 0 CHECK (frame_days >= 0),
      frame_delivery_status TEXT NOT NULL DEFAULT 'not_applicable',
      claimed_at INTEGER NOT NULL,
      UNIQUE (room_id, reward_group, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE INDEX IF NOT EXISTS idx_rocket_reward_claims_pool
      ON rocket_reward_claims(room_id, reward_group, claimed_at)`),
  ]);
}

async function deliverPendingFrameClaim(db, row, deliveryAt) {
  if (!row || String(row.reward_type ?? "") !== "frame") return;
  const frame = rocketFrameRewardForGroup(row.reward_group);
  const userId = String(row.user_id ?? "");
  const claimId = String(row.id ?? "");
  const days = Math.max(1, Number(row.frame_days ?? 1));
  if (!frame || !userId || !claimId) return;

  // Start validity when legacy pending artwork is actually delivered so a
  // previous placeholder claim does not lose its full advertised duration.
  await db.batch([
    db.prepare(`INSERT INTO user_cosmetics
        (user_id,item_id,kind,acquired_at,expires_at,active)
      SELECT ?,?,'frame',?,?,0 FROM users WHERE id=?
      ON CONFLICT(user_id,item_id) DO UPDATE SET
        acquired_at=excluded.acquired_at,
        expires_at=MAX(user_cosmetics.expires_at,excluded.expires_at),
        active=user_cosmetics.active`).bind(
      userId, frame.id, deliveryAt, deliveryAt + days * 86400000, userId,
    ),
    db.prepare(`UPDATE rocket_reward_claims
      SET frame_delivery_status='delivered'
      WHERE id=? AND reward_type='frame'
        AND EXISTS (
          SELECT 1 FROM user_cosmetics
          WHERE user_id=? AND item_id=? AND expires_at>?
        )`).bind(claimId, userId, frame.id, deliveryAt),
  ]);
}

function asPublicClaim(row) {
  if (!row) return null;
  const frame = String(row.reward_type ?? "") === "frame"
    ? rocketFrameRewardForGroup(row.reward_group)
    : null;
  return {
    reward_type: String(row.reward_type ?? ""),
    coins: Number(row.coin_amount ?? 0),
    frame_days: Number(row.frame_days ?? 0),
    frame_id: frame?.id ?? null,
    frame_name: frame?.name ?? null,
    frame_delivery_status: String(row.frame_delivery_status ?? "not_applicable"),
    claimed_at: Number(row.claimed_at ?? 0),
  };
}

function secureRandomInt(min, max) {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  const span = max - min + 1;
  return min + (values[0] % span);
}

export async function handleRocketRewardRoute({
  request, env, url, parts, db, json, requireSession,
  verifySessionToken, bearerToken, now, newId, ownerSetting,
}) {
  if (
    parts[0] !== "api" || parts[1] !== "rooms" ||
    parts[3] !== "rocket-reward" ||
    ![4, 5].includes(parts.length)
  ) return null;

  const roomId = String(parts[2] ?? "").trim();
  const isClaim = parts.length === 5 && parts[4] === "claim" && request.method === "POST";
  const isStatus = parts.length === 4 && request.method === "GET";
  if (!roomId || (!isClaim && !isStatus)) {
    return json({ ok: false, error: "not_found" }, { status: 404 });
  }

  const authError = await requireSession(request, env);
  if (authError) return authError;
  const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
  const userId = String(session?.sub ?? "").trim();
  if (!userId) return json({ ok: false, error: "unauthorized" }, { status: 401 });

  const member = await db.prepare(
    "SELECT 1 AS active FROM room_members WHERE room_id=? AND user_id=? LIMIT 1",
  ).bind(roomId, userId).first();
  if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });

  const giftsFeature = await ownerSetting(db, "feature.gifts", { enabled: true });
  if (giftsFeature.enabled === false) {
    return json({ ok: false, error: "gifts_disabled" }, { status: 403 });
  }

  await ensureRocketRewardSchema(db);
  await ensureCosmeticsSchema(db);
  const requestedLevel = isClaim
    ? Number((await request.clone().json().catch(() => ({})))?.rocket_level)
    : Number(url.searchParams.get("level"));
  if (!Number.isInteger(requestedLevel) || requestedLevel < 1 || requestedLevel > 12) {
    return json({ ok: false, error: "invalid_rocket_level" }, { status: 400 });
  }

  const tier = rocketRewardConfigForLevel(requestedLevel);
  const target = rocketTargetForLevel(requestedLevel);
  const totalRow = await db.prepare(
    "SELECT COALESCE(SUM(coin_cost),0) AS lifetime_total FROM gift_events WHERE room_id=?",
  ).bind(roomId).first();
  const lifetimeTotal = Number(totalRow?.lifetime_total ?? 0);
  const poolRow = await db.prepare(
    "SELECT COUNT(*) AS claimed_count FROM rocket_reward_claims WHERE room_id=? AND reward_group=?",
  ).bind(roomId, tier.group).first();
  const claimedCount = Number(poolRow?.claimed_count ?? 0);
  let existingRow = await db.prepare(
    "SELECT id,room_id,reward_group,user_id,reward_type,coin_amount,frame_days,frame_delivery_status,claimed_at FROM rocket_reward_claims WHERE room_id=? AND reward_group=? AND user_id=? LIMIT 1",
  ).bind(roomId, tier.group, userId).first();
  if (existingRow?.reward_type === "frame" &&
      String(existingRow.frame_delivery_status ?? "") !== "delivered") {
    await deliverPendingFrameClaim(db, existingRow, now());
    existingRow = await db.prepare(
      "SELECT id,room_id,reward_group,user_id,reward_type,coin_amount,frame_days,frame_delivery_status,claimed_at FROM rocket_reward_claims WHERE room_id=? AND reward_group=? AND user_id=? LIMIT 1",
    ).bind(roomId, tier.group, userId).first();
  }
  const existingClaim = asPublicClaim(existingRow);

  if (isStatus) {
    return json({
      ok: true,
      room_id: roomId,
      rocket_level: requestedLevel,
      tier: {
        group: tier.group,
        label: tier.label,
        max_winners: tier.maxWinners,
        frame_winners: tier.frameWinners,
        coin_min: tier.coinMin,
        coin_max: tier.coinMax,
        frame_days: tier.frameDays,
      },
      lifetime_total: lifetimeTotal,
      target_coins: target,
      target_configured: target != null,
      reached: target != null && lifetimeTotal >= target,
      claimed_count: claimedCount,
      remaining_winners: Math.max(0, tier.maxWinners - claimedCount),
      claim: existingClaim,
      can_claim: target != null &&
        lifetimeTotal >= target &&
        !existingClaim &&
        claimedCount < tier.maxWinners,
    });
  }

  if (target == null) {
    return json({
      ok: false, error: "rocket_level_target_not_configured",
      rocket_level: requestedLevel,
    }, { status: 409 });
  }
  if (lifetimeTotal < target) {
    return json({
      ok: false, error: "rocket_target_not_reached",
      rocket_level: requestedLevel,
      current_total: lifetimeTotal,
      target_coins: target,
    }, { status: 409 });
  }
  if (existingClaim) {
    return json({
      ok: true,
      already_claimed: true,
      rocket_level: requestedLevel,
      ...existingClaim,
      claimed_count: claimedCount,
      max_winners: tier.maxWinners,
    });
  }
  if (claimedCount >= tier.maxWinners) {
    return json({ ok: false, error: "reward_claims_full", claimed_count: claimedCount }, { status: 409 });
  }

  const claimId = newId();
  const timestamp = now();
  const randomCoins = secureRandomInt(tier.coinMin, tier.coinMax);
  await db.batch([
    db.prepare(`WITH pool_state AS (
        SELECT
          (SELECT COUNT(*) FROM rocket_reward_claims WHERE room_id=? AND reward_group=?) AS claimed_count,
          (SELECT COALESCE(SUM(coin_cost),0) FROM gift_events WHERE room_id=?) AS lifetime_total
      )
      INSERT OR IGNORE INTO rocket_reward_claims
        (id,room_id,rocket_level,reward_group,user_id,reward_type,coin_amount,frame_days,frame_delivery_status,claimed_at)
      SELECT ?,?,?,?,?, 
        CASE WHEN claimed_count < ? THEN 'frame' ELSE 'coins' END,
        CASE WHEN claimed_count < ? THEN 0 ELSE ? END,
        CASE WHEN claimed_count < ? THEN ? ELSE 0 END,
        CASE WHEN claimed_count < ? THEN 'pending_assets' ELSE 'not_applicable' END,
        ?
      FROM pool_state
      WHERE claimed_count < ?
        AND lifetime_total >= ?
        AND EXISTS (SELECT 1 FROM room_members WHERE room_id=? AND user_id=?)
        AND NOT EXISTS (
          SELECT 1 FROM rocket_reward_claims WHERE room_id=? AND reward_group=? AND user_id=?
        )`).bind(
      roomId, tier.group, roomId,
      claimId, roomId, requestedLevel, tier.group, userId,
      tier.frameWinners,
      tier.frameWinners, randomCoins,
      tier.frameWinners, tier.frameDays,
      tier.frameWinners, timestamp,
      tier.maxWinners, target,
      roomId, userId,
      roomId, tier.group, userId,
    ),
    db.prepare(`UPDATE users
      SET coins = coins + (
        SELECT coin_amount FROM rocket_reward_claims
        WHERE id=? AND reward_type='coins'
      ), updated_at=?
      WHERE id=?
        AND EXISTS (
          SELECT 1 FROM rocket_reward_claims
          WHERE id=? AND reward_type='coins' AND coin_amount>0
        )
        AND NOT EXISTS (
          SELECT 1 FROM wallet_ledger WHERE reference_id=? AND kind='rocket_reward'
        )`).bind(claimId, timestamp, userId, claimId, claimId),
    db.prepare(`INSERT INTO wallet_ledger
        (id,user_id,kind,amount,balance_after,reference_id,created_at)
      SELECT ?,u.id,'rocket_reward',c.coin_amount,u.coins,c.id,?
      FROM users u
      JOIN rocket_reward_claims c ON c.user_id=u.id AND c.id=?
      WHERE changes()=1 AND c.reward_type='coins' AND c.coin_amount>0`).bind(
      newId(), timestamp, claimId,
    ),
    db.prepare(`INSERT INTO user_cosmetics
        (user_id,item_id,kind,acquired_at,expires_at,active)
      SELECT c.user_id,
        CASE c.reward_group
          WHEN '1-3' THEN 'rocket_frame_aurora'
          WHEN '4-6' THEN 'rocket_frame_neon_wings'
          WHEN '7-9' THEN 'rocket_frame_golden_comet'
          WHEN '10-12' THEN 'rocket_frame_purple_nova'
        END,
        'frame',?, ?,0
      FROM rocket_reward_claims c
      WHERE c.id=? AND c.reward_type='frame'
      ON CONFLICT(user_id,item_id) DO UPDATE SET
        acquired_at=excluded.acquired_at,
        expires_at=MAX(user_cosmetics.expires_at,excluded.expires_at),
        active=user_cosmetics.active`).bind(
      timestamp, timestamp + tier.frameDays * 86400000, claimId,
    ),
    db.prepare(`UPDATE rocket_reward_claims
      SET frame_delivery_status='delivered'
      WHERE id=? AND reward_type='frame'
        AND EXISTS (
          SELECT 1 FROM user_cosmetics uc
          WHERE uc.user_id=rocket_reward_claims.user_id
            AND uc.item_id=CASE rocket_reward_claims.reward_group
              WHEN '1-3' THEN 'rocket_frame_aurora'
              WHEN '4-6' THEN 'rocket_frame_neon_wings'
              WHEN '7-9' THEN 'rocket_frame_golden_comet'
              WHEN '10-12' THEN 'rocket_frame_purple_nova'
            END
            AND uc.expires_at>?
        )`).bind(claimId, timestamp),
  ]);

  const finalRow = await db.prepare(
    "SELECT id,room_id,reward_group,user_id,reward_type,coin_amount,frame_days,frame_delivery_status,claimed_at FROM rocket_reward_claims WHERE room_id=? AND reward_group=? AND user_id=? LIMIT 1",
  ).bind(roomId, tier.group, userId).first();
  if (!finalRow) {
    const latestCount = await db.prepare(
      "SELECT COUNT(*) AS claimed_count FROM rocket_reward_claims WHERE room_id=? AND reward_group=?",
    ).bind(roomId, tier.group).first();
    return json({
      ok: false,
      error: Number(latestCount?.claimed_count ?? 0) >= tier.maxWinners
        ? "reward_claims_full" : "reward_claim_failed",
      claimed_count: Number(latestCount?.claimed_count ?? 0),
    }, { status: 409 });
  }

  const claim = asPublicClaim(finalRow);
  const finalCount = await db.prepare(
    "SELECT COUNT(*) AS claimed_count FROM rocket_reward_claims WHERE room_id=? AND reward_group=?",
  ).bind(roomId, tier.group).first();
  return json({
    ok: true,
    already_claimed: String(finalRow.id ?? "") !== claimId,
    rocket_level: requestedLevel,
    ...claim,
    claimed_count: Number(finalCount?.claimed_count ?? 0),
    max_winners: tier.maxWinners,
  });
}
