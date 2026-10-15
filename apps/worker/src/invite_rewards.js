const COINS_PER_USD = 6_000_000;

// Invite rewards are coin commission only. Eligible source is a Coin Seller
// or Merchant transfer into the invited user's normal wallet. Do not attach
// entry vehicles, frames, cosmetics, gifts, or other prize inventory.

// Direct-invite reward levels copied from the visible levels in the reference
// flow. The last visible level is 5%; higher levels can be added without
// changing stored invite/reward data.
const DIRECT_INVITE_TIERS = Object.freeze([
  { level: 1, minInvites: 1, minCoins: 0, rateBps: 300 },
  { level: 2, minInvites: 10, minCoins: 16_000_000, rateBps: 400 },
  { level: 3, minInvites: 20, minCoins: 48_000_000, rateBps: 450 },
  { level: 4, minInvites: 50, minCoins: 160_000_000, rateBps: 500 },
]);

export async function ensureInviteRewardSchema(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS invite_bindings (
    invitee_user_id TEXT PRIMARY KEY,
    inviter_user_id TEXT NOT NULL,
    invitation_code TEXT NOT NULL,
    bound_at INTEGER NOT NULL,
    CHECK(invitee_user_id <> inviter_user_id),
    FOREIGN KEY(invitee_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(inviter_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();

  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_invite_bindings_inviter
    ON invite_bindings(inviter_user_id, bound_at DESC)`).run();

  await db.prepare(`CREATE TABLE IF NOT EXISTS invite_commission_rewards (
    id TEXT PRIMARY KEY,
    inviter_user_id TEXT NOT NULL,
    invitee_user_id TEXT NOT NULL,
    source_transfer_id TEXT NOT NULL UNIQUE,
    source_coins INTEGER NOT NULL CHECK(source_coins > 0),
    rate_bps INTEGER NOT NULL CHECK(rate_bps >= 0),
    reward_coins INTEGER NOT NULL CHECK(reward_coins >= 0),
    created_at INTEGER NOT NULL,
    FOREIGN KEY(inviter_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(invitee_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();

  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_invite_rewards_inviter_time
    ON invite_commission_rewards(inviter_user_id, created_at DESC)`).run();
}

function normalizeCode(value) {
  return String(value ?? "").trim();
}

async function inviteStats(db, inviterUserId) {
  const row = await db.prepare(`
    SELECT
      COUNT(DISTINCT b.invitee_user_id) AS invite_count,
      COALESCE(SUM(r.source_coins), 0) AS source_coins,
      COALESCE(SUM(r.reward_coins), 0) AS reward_coins
    FROM invite_bindings b
    LEFT JOIN invite_commission_rewards r
      ON r.invitee_user_id = b.invitee_user_id
     AND r.inviter_user_id = b.inviter_user_id
    WHERE b.inviter_user_id = ?
  `).bind(inviterUserId).first();

  return {
    inviteCount: Number(row?.invite_count ?? 0),
    sourceCoins: Number(row?.source_coins ?? 0),
    rewardCoins: Number(row?.reward_coins ?? 0),
  };
}

function tierFor({ inviteCount, sourceCoins }) {
  let active = null;
  for (const tier of DIRECT_INVITE_TIERS) {
    if (inviteCount >= tier.minInvites && sourceCoins >= tier.minCoins) {
      active = tier;
    }
  }
  return active;
}

export async function bindInvitationCode(db, {
  inviteeUserId,
  invitationCode,
  ts = Date.now(),
}) {
  await ensureInviteRewardSchema(db);
  const code = normalizeCode(invitationCode);
  if (!inviteeUserId || !code) throw new Error("invitation_code_required");

  const current = await db.prepare(
    "SELECT inviter_user_id,invitation_code,bound_at FROM invite_bindings WHERE invitee_user_id=?"
  ).bind(inviteeUserId).first();
  if (current) {
    return {
      already_bound: true,
      inviter_user_id: String(current.inviter_user_id),
      invitation_code: String(current.invitation_code),
      bound_at: Number(current.bound_at ?? 0),
    };
  }

  // DarkVibeX public profile IDs are unique, so the inviter's public ID is
  // also the invitation code. This avoids a second identity/code system.
  const inviter = await db.prepare(
    "SELECT id,display_name,avatar_key FROM users WHERE id=?"
  ).bind(code).first();
  if (!inviter) throw new Error("invitation_code_not_found");
  if (String(inviter.id) === String(inviteeUserId)) {
    throw new Error("cannot_invite_self");
  }

  await db.prepare(
    "INSERT INTO invite_bindings(invitee_user_id,inviter_user_id,invitation_code,bound_at) VALUES(?,?,?,?)"
  ).bind(inviteeUserId, String(inviter.id), code, ts).run();

  return {
    already_bound: false,
    inviter_user_id: String(inviter.id),
    inviter_name: String(inviter.display_name ?? ""),
    invitation_code: code,
    bound_at: ts,
  };
}

export async function inviteRewardSummary(db, userId) {
  await ensureInviteRewardSchema(db);
  const stats = await inviteStats(db, userId);
  const tier = tierFor(stats);
  const binding = await db.prepare(`
    SELECT b.inviter_user_id,b.invitation_code,b.bound_at,
           u.display_name AS inviter_name,u.avatar_key AS inviter_avatar_key
      FROM invite_bindings b
      LEFT JOIN users u ON u.id=b.inviter_user_id
     WHERE b.invitee_user_id=?
  `).bind(userId).first();

  const invited = await db.prepare(`
    SELECT b.invitee_user_id,u.display_name,u.avatar_key,b.bound_at,
           COALESCE(SUM(r.source_coins),0) AS source_coins,
           COALESCE(SUM(r.reward_coins),0) AS reward_coins
      FROM invite_bindings b
      LEFT JOIN users u ON u.id=b.invitee_user_id
      LEFT JOIN invite_commission_rewards r
        ON r.invitee_user_id=b.invitee_user_id
       AND r.inviter_user_id=b.inviter_user_id
     WHERE b.inviter_user_id=?
     GROUP BY b.invitee_user_id,u.display_name,u.avatar_key,b.bound_at
     ORDER BY b.bound_at DESC
     LIMIT 100
  `).bind(userId).all();

  return {
    invitation_code: String(userId),
    coins_per_usd: COINS_PER_USD,
    invite_count: stats.inviteCount,
    invited_received_coins: stats.sourceCoins,
    invited_received_usd: stats.sourceCoins / COINS_PER_USD,
    commission_coins: stats.rewardCoins,
    commission_usd: stats.rewardCoins / COINS_PER_USD,
    current_level: tier?.level ?? 0,
    current_rate_bps: tier?.rateBps ?? 0,
    current_rate_percent: (tier?.rateBps ?? 0) / 100,
    bound_to: binding ? {
      inviter_user_id: String(binding.inviter_user_id),
      inviter_name: String(binding.inviter_name ?? ""),
      inviter_avatar_key: String(binding.inviter_avatar_key ?? ""),
      invitation_code: String(binding.invitation_code),
      bound_at: Number(binding.bound_at ?? 0),
    } : null,
    tiers: DIRECT_INVITE_TIERS.map((item) => ({
      level: item.level,
      min_invites: item.minInvites,
      min_received_coins: item.minCoins,
      rate_bps: item.rateBps,
      rate_percent: item.rateBps / 100,
    })),
    invited_users: (invited.results ?? []).map((row) => ({
      user_id: String(row.invitee_user_id),
      display_name: String(row.display_name ?? ""),
      avatar_key: String(row.avatar_key ?? ""),
      bound_at: Number(row.bound_at ?? 0),
      received_coins: Number(row.source_coins ?? 0),
      commission_coins: Number(row.reward_coins ?? 0),
    })),
  };
}

export async function recordCoinSellerInviteCommission(db, {
  inviteeUserId,
  sourceTransferId,
  sourceCoins,
  sourceWalletType = "coin_seller",
  ts = Date.now(),
}) {
  await ensureInviteRewardSchema(db);
  const amount = Number(sourceCoins);
  const walletType = String(sourceWalletType ?? "").trim();
  if (!inviteeUserId || !sourceTransferId ||
      !["coin_seller", "merchant"].includes(walletType) ||
      !Number.isSafeInteger(amount) || amount <= 0) {
    throw new Error("invalid_invite_commission_source");
  }

  const existing = await db.prepare(
    "SELECT id,reward_coins,rate_bps FROM invite_commission_rewards WHERE source_transfer_id=?"
  ).bind(sourceTransferId).first();
  if (existing) {
    return {
      applied: false,
      duplicate: true,
      reward_coins: Number(existing.reward_coins ?? 0),
      rate_bps: Number(existing.rate_bps ?? 0),
    };
  }

  const binding = await db.prepare(
    "SELECT inviter_user_id FROM invite_bindings WHERE invitee_user_id=?"
  ).bind(inviteeUserId).first();
  if (!binding?.inviter_user_id) {
    return { applied: false, reason: "no_inviter" };
  }

  const inviterUserId = String(binding.inviter_user_id);
  const statsBefore = await inviteStats(db, inviterUserId);
  const statsForTier = {
    inviteCount: statsBefore.inviteCount,
    sourceCoins: statsBefore.sourceCoins + amount,
  };
  const tier = tierFor(statsForTier);
  if (!tier || tier.rateBps <= 0) {
    return { applied: false, reason: "tier_not_active" };
  }

  const rewardCoins = Math.floor((amount * tier.rateBps) / 10_000);
  if (rewardCoins <= 0) {
    return { applied: false, reason: "reward_rounds_to_zero" };
  }

  const inviter = await db.prepare(
    "SELECT coins FROM users WHERE id=?"
  ).bind(inviterUserId).first();
  if (!inviter) return { applied: false, reason: "inviter_not_found" };

  const balanceAfter = Number(inviter.coins ?? 0) + rewardCoins;
  const rewardId = crypto.randomUUID();

  await db.batch([
    db.prepare(
      "INSERT INTO invite_commission_rewards(id,inviter_user_id,invitee_user_id,source_transfer_id,source_coins,rate_bps,reward_coins,created_at) VALUES(?,?,?,?,?,?,?,?)"
    ).bind(
      rewardId, inviterUserId, inviteeUserId, sourceTransferId,
      amount, tier.rateBps, rewardCoins, ts,
    ),
    db.prepare("UPDATE users SET coins=?,updated_at=? WHERE id=?")
      .bind(balanceAfter, ts, inviterUserId),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(
      crypto.randomUUID(), inviterUserId, "invite_commission",
      rewardCoins, balanceAfter, sourceTransferId, ts,
    ),
  ]);

  return {
    applied: true,
    inviter_user_id: inviterUserId,
    invitee_user_id: inviteeUserId,
    source_coins: amount,
    rate_bps: tier.rateBps,
    rate_percent: tier.rateBps / 100,
    reward_coins: rewardCoins,
    inviter_balance_after: balanceAfter,
    level: tier.level,
  };
}
