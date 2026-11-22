const COINS_PER_USD = 8_000_000;
const SUCCESSFUL_INVITE_REWARD_COINS = 800_000;

// Invite/referral dollars (Vinay, 2026-11-23): every recharge an invitee
// makes within 3 months of binding earns the inviter 5% of the recharge
// in dollars. Dollars live on the Share page; at $3 the inviter can
// withdraw them to a coin seller / merchant, who then automatically
// receives 11,000,000 coins per $1 into their SELLER wallet (role
// wallet), never the normal user wallet. The sender gets nothing extra
// for sending the dollars. All dollar amounts are integer US cents.
export const REFERRAL_COMMISSION_RATE_BPS = 500;
export const REFERRAL_COMMISSION_WINDOW_MS = 90 * 24 * 60 * 60 * 1000;
export const REFERRAL_WITHDRAWAL_MIN_USD_CENTS = 300;
export const REFERRAL_WITHDRAWAL_COINS_PER_USD_CENT = 110_000;

// Invite-code rules (Vinay, 2026-11-23): the code must be entered within
// 48 hours of the ID being created — after that the option disappears.
// And one device can use an invite code for one ID only, so a single
// phone cannot farm the 800,000-coin reward with account after account.
export const INVITE_BIND_WINDOW_MS = 48 * 60 * 60 * 1000;

// Every newly successful invite gives the inviter a fixed one-time coin reward.
// Ongoing commission is separate and only counts coins credited through
// Coin Seller transfers into the invited user's normal wallet. Merchant transfers,
// gifts, game winnings, and other coin sources are excluded. No vehicle/cosmetic prize.

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
    device_key TEXT,
    CHECK(invitee_user_id <> inviter_user_id),
    FOREIGN KEY(invitee_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(inviter_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();

  // One device, one ID uses an invite code (Vinay, 2026-11-23): older
  // databases were created without the column, so add it when missing.
  const bindingInfo = await db.prepare(
    "PRAGMA table_info(invite_bindings)"
  ).all();
  const hasDeviceKey = (bindingInfo.results ?? []).some(
    (column) => String(column.name ?? "") === "device_key",
  );
  if (!hasDeviceKey) {
    await db.prepare(
      "ALTER TABLE invite_bindings ADD COLUMN device_key TEXT"
    ).run();
  }

  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_invite_bindings_inviter
    ON invite_bindings(inviter_user_id, bound_at DESC)`).run();
  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_invite_bindings_device
    ON invite_bindings(device_key)`).run();

  await db.prepare(`CREATE TABLE IF NOT EXISTS invite_success_rewards (
    id TEXT PRIMARY KEY,
    inviter_user_id TEXT NOT NULL,
    invitee_user_id TEXT NOT NULL UNIQUE,
    reward_coins INTEGER NOT NULL CHECK(reward_coins > 0),
    created_at INTEGER NOT NULL,
    FOREIGN KEY(inviter_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(invitee_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();

  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_invite_success_rewards_inviter
    ON invite_success_rewards(inviter_user_id, created_at DESC)`).run();

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

  // Referral dollars: one row per invitee recharge inside the window.
  // source_purchase_token is the Play purchase token, UNIQUE so a verify
  // retry or resume can never pay the same recharge twice.
  await db.prepare(`CREATE TABLE IF NOT EXISTS invite_dollar_commissions (
    id TEXT PRIMARY KEY,
    inviter_user_id TEXT NOT NULL,
    invitee_user_id TEXT NOT NULL,
    source_purchase_token TEXT NOT NULL UNIQUE,
    recharge_usd_cents INTEGER NOT NULL CHECK(recharge_usd_cents > 0),
    commission_usd_cents INTEGER NOT NULL CHECK(commission_usd_cents >= 0),
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','reversed')),
    created_at INTEGER NOT NULL,
    FOREIGN KEY(inviter_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(invitee_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();

  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_invite_dollar_commissions_inviter
    ON invite_dollar_commissions(inviter_user_id, created_at DESC)`).run();

  // Spendable referral-dollar balance, integer US cents. Withdrawals
  // debit it with a guarded relative UPDATE (balance >= amount).
  await db.prepare(`CREATE TABLE IF NOT EXISTS invite_dollar_balances (
    user_id TEXT PRIMARY KEY,
    balance_usd_cents INTEGER NOT NULL DEFAULT 0 CHECK(balance_usd_cents >= 0),
    updated_at INTEGER NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();

  // One row per withdrawal. idempotency_key is UNIQUE: a retry of the
  // same withdrawal returns the original result instead of paying twice.
  await db.prepare(`CREATE TABLE IF NOT EXISTS invite_dollar_withdrawals (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    provider_user_id TEXT NOT NULL,
    provider_role TEXT NOT NULL CHECK(provider_role IN ('coin_seller','merchant')),
    amount_usd_cents INTEGER NOT NULL CHECK(amount_usd_cents > 0),
    coins_credited INTEGER NOT NULL CHECK(coins_credited >= 0),
    idempotency_key TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY(provider_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();

  await db.prepare(`CREATE INDEX IF NOT EXISTS idx_invite_dollar_withdrawals_user
    ON invite_dollar_withdrawals(user_id, created_at DESC)`).run();
}

function normalizeCode(value) {
  const code = String(value ?? "").trim();
  return /^[1-9]\d{6}$/.test(code) ? code : "";
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

async function backfillInviteSuccessRewards(db, inviterUserId, ts = Date.now()) {
  const missing = await db.prepare(`
    SELECT b.invitee_user_id,b.bound_at
      FROM invite_bindings b
      LEFT JOIN invite_success_rewards s
        ON s.invitee_user_id=b.invitee_user_id
     WHERE b.inviter_user_id=?
       AND s.invitee_user_id IS NULL
     ORDER BY b.bound_at ASC
     LIMIT 500
  `).bind(inviterUserId).all();

  for (const row of missing.results ?? []) {
    const inviteeUserId = String(row.invitee_user_id ?? "");
    if (!inviteeUserId) continue;
    const rewardId = crypto.randomUUID();
    const ledgerId = crypto.randomUUID();
    const createdAt = Number(row.bound_at ?? 0) > 0
      ? Number(row.bound_at)
      : ts;
    await db.batch([
      db.prepare(
        "INSERT OR IGNORE INTO invite_success_rewards(id,inviter_user_id,invitee_user_id,reward_coins,created_at) VALUES(?,?,?,?,?)"
      ).bind(
        rewardId, inviterUserId, inviteeUserId,
        SUCCESSFUL_INVITE_REWARD_COINS, createdAt,
      ),
      db.prepare(
        "UPDATE users SET coins=coins+?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM invite_success_rewards WHERE id=? AND inviter_user_id=?)"
      ).bind(
        SUCCESSFUL_INVITE_REWARD_COINS, ts, inviterUserId,
        rewardId, inviterUserId,
      ),
      db.prepare(
        "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) SELECT ?,u.id,'invite_success_reward',?,u.coins,?,? FROM users u WHERE u.id=? AND EXISTS(SELECT 1 FROM invite_success_rewards WHERE id=?)"
      ).bind(
        ledgerId, SUCCESSFUL_INVITE_REWARD_COINS,
        rewardId, createdAt, inviterUserId, rewardId,
      ),
    ]);
  }
}

export async function bindInvitationCode(db, {
  inviteeUserId,
  invitationCode,
  deviceKey,
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
    "SELECT id,public_id,display_name,avatar_key,coins FROM users WHERE public_id=? LIMIT 1"
  ).bind(code).first();
  if (!inviter) throw new Error("invitation_code_not_found");
  if (String(inviter.id) === String(inviteeUserId)) {
    throw new Error("cannot_invite_self");
  }

  // The invite code must be entered within 48 hours of the ID being
  // created (Vinay, 2026-11-23). A missing created_at cannot prove the
  // account is old, so legacy rows stay bindable.
  const invitee = await db.prepare(
    "SELECT created_at FROM users WHERE id=? LIMIT 1"
  ).bind(inviteeUserId).first();
  const createdAt = Number(invitee?.created_at ?? 0);
  if (createdAt > 0 && ts - createdAt > INVITE_BIND_WINDOW_MS) {
    throw new Error("invite_window_expired");
  }

  // One device, one ID: a device that already used an invite code for
  // another account cannot use one again (Vinay, 2026-11-23). Old
  // clients send no device key, so the check only runs when one arrives.
  const device = String(deviceKey ?? "").trim();
  if (device !== "") {
    const other = await db.prepare(
      "SELECT invitee_user_id FROM invite_bindings WHERE device_key=? AND invitee_user_id<>? LIMIT 1"
    ).bind(device, inviteeUserId).first();
    if (other) throw new Error("device_already_used_invite");
  }

  const inviterUserId = String(inviter.id);
  const rewardId = crypto.randomUUID();
  const ledgerId = crypto.randomUUID();

  // The binding and fixed invite reward are written together. invitee_user_id
  // is unique in both tables, so retries cannot mint the 800,000 coin reward twice.
  await db.batch([
    db.prepare(
      "INSERT INTO invite_bindings(invitee_user_id,inviter_user_id,invitation_code,bound_at,device_key) VALUES(?,?,?,?,?)"
    ).bind(inviteeUserId, inviterUserId, code, ts, device !== "" ? device : null),
    db.prepare(
      "INSERT INTO invite_success_rewards(id,inviter_user_id,invitee_user_id,reward_coins,created_at) VALUES(?,?,?,?,?)"
    ).bind(
      rewardId, inviterUserId, inviteeUserId,
      SUCCESSFUL_INVITE_REWARD_COINS, ts,
    ),
    db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=?"
    ).bind(SUCCESSFUL_INVITE_REWARD_COINS, ts, inviterUserId),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) SELECT ?,u.id,'invite_success_reward',?,u.coins,?,? FROM users u WHERE u.id=?"
    ).bind(
      ledgerId, SUCCESSFUL_INVITE_REWARD_COINS,
      rewardId, ts, inviterUserId,
    ),
  ]);

  return {
    already_bound: false,
    inviter_user_id: inviterUserId,
    inviter_public_id: String(inviter.public_id ?? ""),
    inviter_name: String(inviter.display_name ?? ""),
    invitation_code: code,
    fixed_reward_coins: SUCCESSFUL_INVITE_REWARD_COINS,
    bound_at: ts,
  };
}

export async function inviteRewardSummary(db, userId) {
  await ensureInviteRewardSchema(db);
  // Existing successful invites from before the fixed-reward launch are
  // credited once on first summary load. Unique invitee_user_id prevents repeats.
  await backfillInviteSuccessRewards(db, userId);
  const stats = await inviteStats(db, userId);
  const tier = tierFor(stats);
  const owner = await db.prepare(
    "SELECT public_id,created_at FROM users WHERE id=? LIMIT 1"
  ).bind(userId).first();
  const invitationCode = String(owner?.public_id ?? "").trim();
  if (!/^[1-9]\d{6}$/.test(invitationCode)) {
    throw new Error("public_invitation_id_missing");
  }
  // The enter-code option lives only within 48 hours of the ID being
  // created (Vinay, 2026-11-23). The app hides the box and the
  // one-time prompt once the window closes; the server enforces it.
  const accountCreatedAt = Number(owner?.created_at ?? 0);
  const inviteWindowEndsAt = accountCreatedAt > 0
    ? accountCreatedAt + INVITE_BIND_WINDOW_MS
    : 0;
  const inviteWindowOpen = accountCreatedAt <= 0 ||
    Date.now() < inviteWindowEndsAt;
  const binding = await db.prepare(`
    SELECT b.inviter_user_id,b.invitation_code,b.bound_at,
           u.public_id AS inviter_public_id,
           u.display_name AS inviter_name,u.avatar_key AS inviter_avatar_key
      FROM invite_bindings b
      LEFT JOIN users u ON u.id=b.inviter_user_id
     WHERE b.invitee_user_id=?
  `).bind(userId).first();

  const successRewardTotal = await db.prepare(
    "SELECT COALESCE(SUM(reward_coins),0) AS reward_coins FROM invite_success_rewards WHERE inviter_user_id=?"
  ).bind(userId).first();

  const invited = await db.prepare(`
    SELECT b.invitee_user_id,u.public_id,u.display_name,u.avatar_key,b.bound_at,
           COALESCE(SUM(r.source_coins),0) AS source_coins,
           COALESCE(SUM(r.reward_coins),0) AS reward_coins,
           COALESCE(MAX(s.reward_coins),0) AS fixed_reward_coins
      FROM invite_bindings b
      LEFT JOIN users u ON u.id=b.invitee_user_id
      LEFT JOIN invite_success_rewards s
        ON s.invitee_user_id=b.invitee_user_id
       AND s.inviter_user_id=b.inviter_user_id
      LEFT JOIN invite_commission_rewards r
        ON r.invitee_user_id=b.invitee_user_id
       AND r.inviter_user_id=b.inviter_user_id
     WHERE b.inviter_user_id=?
     GROUP BY b.invitee_user_id,u.public_id,u.display_name,u.avatar_key,b.bound_at
     ORDER BY b.bound_at DESC
  `).bind(userId).all();

  const dollarByInvitee = await db.prepare(`
    SELECT invitee_user_id, COALESCE(SUM(commission_usd_cents),0) AS total
      FROM invite_dollar_commissions
     WHERE inviter_user_id=? AND status='active'
     GROUP BY invitee_user_id
  `).bind(userId).all();
  const dollarByInviteeMap = new Map(
    (dollarByInvitee.results ?? []).map((row) => [
      String(row.invitee_user_id),
      Number(row.total ?? 0),
    ]),
  );

  // Total Play recharge per invitee, in US cents (Vinay, 2026-11-23):
  // granted purchases only, so a refunded recharge stops counting.
  // The pack cents mirror PLAY_PACKS in play_billing.js. The table is
  // created lazily by the Play endpoints, so a summary read before any
  // purchase must not fail on the missing table.
  let rechargeByInviteeMap = new Map();
  const rechargeTable = await db.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='play_purchases'"
  ).first();
  if (rechargeTable) {
    const rechargeByInvitee = await db.prepare(`
      SELECT user_id, COALESCE(SUM(CASE product_id
        WHEN 'coins_8000000' THEN 100
        WHEN 'coins_16000000' THEN 200
        WHEN 'coins_40000000' THEN 500
        WHEN 'coins_80000000' THEN 1000
        ELSE 0 END), 0) AS total
        FROM play_purchases
       WHERE status='granted'
       GROUP BY user_id
    `).all();
    rechargeByInviteeMap = new Map(
      (rechargeByInvitee.results ?? []).map((row) => [
        String(row.user_id),
        Number(row.total ?? 0),
      ]),
    );
  }

  const dollarBalance = await db.prepare(
    "SELECT balance_usd_cents FROM invite_dollar_balances WHERE user_id=?"
  ).bind(userId).first();

  const dollarTotals = await db.prepare(
    "SELECT COALESCE(SUM(commission_usd_cents),0) AS total FROM invite_dollar_commissions WHERE inviter_user_id=? AND status='active'"
  ).bind(userId).first();

  const dollarCommissions = await db.prepare(`
    SELECT c.invitee_user_id,u.public_id,u.display_name,u.avatar_key,
           c.recharge_usd_cents,c.commission_usd_cents,c.status,c.created_at
      FROM invite_dollar_commissions c
      LEFT JOIN users u ON u.id=c.invitee_user_id
     WHERE c.inviter_user_id=?
     ORDER BY c.created_at DESC
     LIMIT 50
  `).bind(userId).all();

  const dollarWithdrawals = await db.prepare(`
    SELECT w.provider_user_id,w.provider_role,w.amount_usd_cents,
           w.coins_credited,w.created_at,
           u.public_id AS provider_public_id,u.display_name AS provider_name,
           u.avatar_key AS provider_avatar_key
      FROM invite_dollar_withdrawals w
      LEFT JOIN users u ON u.id=w.provider_user_id
     WHERE w.user_id=?
     ORDER BY w.created_at DESC
     LIMIT 50
  `).bind(userId).all();

  return {
    invitation_code: invitationCode,
    coins_per_usd: COINS_PER_USD,
    invite_count: stats.inviteCount,
    // Unlimited invites (Vinay, 2026-11-23): no cap on how many people
    // one user can invite; the Share-page table shows 5 at a time and
    // the rest scroll. The enter-code option closes 48 hours after the
    // ID is created.
    invite_window_open: inviteWindowOpen,
    invite_window_ends_at: inviteWindowEndsAt,
    invite_window_hours: INVITE_BIND_WINDOW_MS / (60 * 60 * 1000),
    invited_received_coins: stats.sourceCoins,
    invited_received_usd: stats.sourceCoins / COINS_PER_USD,
    commission_coins: stats.rewardCoins,
    commission_usd: stats.rewardCoins / COINS_PER_USD,
    fixed_reward_per_successful_invite: SUCCESSFUL_INVITE_REWARD_COINS,
    successful_invite_reward_coins: Number(successRewardTotal?.reward_coins ?? 0),
    // Referral dollars (Vinay, 2026-11-23): 5% of every invitee recharge
    // within 90 days of binding, in US cents. Withdrawable at $3 to a
    // coin seller / merchant, who then gets 11,000,000 coins per $1
    // into their seller wallet.
    referral_dollar_balance_usd_cents: Number(dollarBalance?.balance_usd_cents ?? 0),
    referral_dollar_commission_usd_cents: Number(dollarTotals?.total ?? 0),
    referral_commission_rate_bps: REFERRAL_COMMISSION_RATE_BPS,
    referral_commission_rate_percent: REFERRAL_COMMISSION_RATE_BPS / 100,
    referral_commission_window_days: 90,
    referral_withdrawal_min_usd_cents: REFERRAL_WITHDRAWAL_MIN_USD_CENTS,
    referral_withdrawal_coins_per_usd: REFERRAL_WITHDRAWAL_COINS_PER_USD_CENT * 100,
    referral_dollar_commissions: (dollarCommissions.results ?? []).map((row) => ({
      invitee_user_id: String(row.invitee_user_id),
      public_id: String(row.public_id ?? ""),
      display_name: String(row.display_name ?? ""),
      avatar_key: String(row.avatar_key ?? ""),
      recharge_usd_cents: Number(row.recharge_usd_cents ?? 0),
      commission_usd_cents: Number(row.commission_usd_cents ?? 0),
      status: String(row.status ?? "active"),
      created_at: Number(row.created_at ?? 0),
    })),
    referral_dollar_withdrawals: (dollarWithdrawals.results ?? []).map((row) => ({
      provider_user_id: String(row.provider_user_id),
      provider_role: String(row.provider_role ?? ""),
      provider_public_id: String(row.provider_public_id ?? ""),
      provider_name: String(row.provider_name ?? ""),
      provider_avatar_key: String(row.provider_avatar_key ?? ""),
      amount_usd_cents: Number(row.amount_usd_cents ?? 0),
      coins_credited: Number(row.coins_credited ?? 0),
      created_at: Number(row.created_at ?? 0),
    })),
    current_level: tier?.level ?? 0,
    current_rate_bps: tier?.rateBps ?? 0,
    current_rate_percent: (tier?.rateBps ?? 0) / 100,
    bound_to: binding ? {
      inviter_user_id: String(binding.inviter_user_id),
      inviter_public_id: String(binding.inviter_public_id ?? binding.invitation_code ?? ""),
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
      public_id: String(row.public_id ?? ""),
      display_name: String(row.display_name ?? ""),
      avatar_key: String(row.avatar_key ?? ""),
      bound_at: Number(row.bound_at ?? 0),
      received_coins: Number(row.source_coins ?? 0),
      commission_coins: Number(row.reward_coins ?? 0),
      referral_commission_usd_cents: dollarByInviteeMap.get(String(row.invitee_user_id)) ?? 0,
      total_recharge_usd_cents: rechargeByInviteeMap.get(String(row.invitee_user_id)) ?? 0,
      fixed_reward_coins: Number(row.fixed_reward_coins ?? 0),
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
  if (!inviteeUserId || !sourceTransferId) {
    throw new Error("invalid_invite_commission_source");
  }
  // Commission volume is strictly Coin Seller received coins. Merchant
  // transfers and other wallet sources must not earn invite commission.
  if (walletType !== "coin_seller") {
    return { applied: false, reason: "ineligible_source" };
  }
  if (!Number.isSafeInteger(amount) || amount <= 0) {
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

  const rewardId = crypto.randomUUID();

  // Relative, guarded credit (Wallet audit M3, 2026-11-22): the old
  // code read the inviter's balance, then wrote it back absolutely,
  // so two concurrent commissions overwrote each other and lost
  // coins — and the check-then-insert on the commission row raced,
  // so a concurrent duplicate ERRORED and the commission was lost
  // (logged, safe direction, but lossy). The INSERT is now OR
  // IGNORE on UNIQUE(source_transfer_id): a duplicate returns the
  // existing commission instead of erroring, and the balance moves
  // relatively with the ledger balance read inside the batch.
  const batchResults = await db.batch([
    db.prepare(
      "INSERT OR IGNORE INTO invite_commission_rewards(id,inviter_user_id,invitee_user_id,source_transfer_id,source_coins,rate_bps,reward_coins,created_at) VALUES(?,?,?,?,?,?,?,?)"
    ).bind(
      rewardId, inviterUserId, inviteeUserId, sourceTransferId,
      amount, tier.rateBps, rewardCoins, ts,
    ),
    db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=? AND changes()=1")
      .bind(rewardCoins, ts, inviterUserId),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) " +
      "SELECT ?,u.id,'invite_commission',?,u.coins,?,? FROM users u WHERE u.id=? AND changes()=1"
    ).bind(
      crypto.randomUUID(), rewardCoins, sourceTransferId, ts, inviterUserId,
    ),
  ]);
  if (Number(batchResults?.[0]?.meta?.changes ?? 0) !== 1) {
    // A concurrent call for the same transfer already recorded the
    // commission (the INSERT OR IGNORE was a no-op): return it
    // instead of erroring, so the commission is never lost.
    const raced = await db.prepare(
      "SELECT reward_coins,rate_bps FROM invite_commission_rewards WHERE source_transfer_id=?"
    ).bind(sourceTransferId).first();
    return {
      applied: false,
      duplicate: true,
      reward_coins: Number(raced?.reward_coins ?? 0),
      rate_bps: Number(raced?.rate_bps ?? 0),
    };
  }
  const afterRow = await db.prepare(
    "SELECT coins FROM users WHERE id=?"
  ).bind(inviterUserId).first();
  const balanceAfter = Number(afterRow?.coins ?? 0);

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

// --- Referral dollars: 5% of every recharge, 3 months from bind ---

// Record the 5% dollar commission for one Play recharge. Called from
// verifyPlayPurchase AFTER the coins are granted, best-effort: a failure
// here must never fail the purchase (the caller wraps it in try/catch).
// Idempotent on the purchase token: a verify retry or resume returns the
// stored commission instead of paying twice.
export async function recordRechargeInviteCommission(db, {
  inviteeUserId,
  purchaseToken,
  usdCents,
  ts = Date.now(),
}) {
  await ensureInviteRewardSchema(db);
  const token = String(purchaseToken ?? "").trim();
  const amount = Number(usdCents);
  if (!inviteeUserId || !token) {
    throw new Error("invalid_referral_commission_source");
  }
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new Error("invalid_referral_commission_source");
  }

  const existing = await db.prepare(
    "SELECT id,inviter_user_id,commission_usd_cents FROM invite_dollar_commissions WHERE source_purchase_token=?"
  ).bind(token).first();
  if (existing) {
    return {
      applied: false,
      duplicate: true,
      inviter_user_id: String(existing.inviter_user_id ?? ""),
      commission_usd_cents: Number(existing.commission_usd_cents ?? 0),
      rate_bps: REFERRAL_COMMISSION_RATE_BPS,
      rate_percent: REFERRAL_COMMISSION_RATE_BPS / 100,
    };
  }

  const binding = await db.prepare(
    "SELECT inviter_user_id,bound_at FROM invite_bindings WHERE invitee_user_id=?"
  ).bind(inviteeUserId).first();
  if (!binding?.inviter_user_id) {
    return { applied: false, reason: "no_inviter" };
  }
  const inviterUserId = String(binding.inviter_user_id);
  const boundAt = Number(binding.bound_at ?? 0);
  if (ts - boundAt > REFERRAL_COMMISSION_WINDOW_MS) {
    return { applied: false, reason: "window_expired" };
  }

  const commission = Math.floor((amount * REFERRAL_COMMISSION_RATE_BPS) / 10_000);
  if (commission <= 0) {
    return { applied: false, reason: "commission_rounds_to_zero" };
  }

  const commissionId = crypto.randomUUID();
  // The balance row must exist before the batch: the batch's UPDATE is
  // gated on the commission INSERT (changes()==1), so it cannot also
  // create the row.
  await db.prepare(
    "INSERT OR IGNORE INTO invite_dollar_balances(user_id,balance_usd_cents,updated_at) VALUES(?,0,?)"
  ).bind(inviterUserId, ts).run();

  const batchResults = await db.batch([
    db.prepare(
      "INSERT OR IGNORE INTO invite_dollar_commissions(id,inviter_user_id,invitee_user_id,source_purchase_token,recharge_usd_cents,commission_usd_cents,status,created_at) VALUES(?,?,?,?,?,?, 'active',?)"
    ).bind(
      commissionId, inviterUserId, inviteeUserId, token,
      amount, commission, ts,
    ),
    db.prepare(
      "UPDATE invite_dollar_balances SET balance_usd_cents=balance_usd_cents+?,updated_at=? WHERE user_id=? AND changes()=1"
    ).bind(commission, ts, inviterUserId),
  ]);
  if (Number(batchResults?.[0]?.meta?.changes ?? 0) !== 1) {
    const raced = await db.prepare(
      "SELECT inviter_user_id,commission_usd_cents FROM invite_dollar_commissions WHERE source_purchase_token=?"
    ).bind(token).first();
    return {
      applied: false,
      duplicate: true,
      inviter_user_id: String(raced?.inviter_user_id ?? ""),
      commission_usd_cents: Number(raced?.commission_usd_cents ?? 0),
      rate_bps: REFERRAL_COMMISSION_RATE_BPS,
      rate_percent: REFERRAL_COMMISSION_RATE_BPS / 100,
    };
  }
  const balanceRow = await db.prepare(
    "SELECT balance_usd_cents FROM invite_dollar_balances WHERE user_id=?"
  ).bind(inviterUserId).first();

  return {
    applied: true,
    inviter_user_id: inviterUserId,
    invitee_user_id: inviteeUserId,
    source_purchase_token: token,
    recharge_usd_cents: amount,
    commission_usd_cents: commission,
    rate_bps: REFERRAL_COMMISSION_RATE_BPS,
    rate_percent: REFERRAL_COMMISSION_RATE_BPS / 100,
    inviter_balance_usd_cents_after: Number(balanceRow?.balance_usd_cents ?? 0),
  };
}

// Reverse the dollar commission for one purchase (refund / RTDN revoke).
// The inviter keeps whatever they already withdrew; only the balance
// still held is clawed back, never below zero. The commission row is
// marked reversed so it never pays again and never counts in totals.
export async function reverseRechargeInviteCommission(db, {
  purchaseToken,
  ts = Date.now(),
}) {
  await ensureInviteRewardSchema(db);
  const token = String(purchaseToken ?? "").trim();
  if (!token) return { applied: false, reason: "invalid_purchase_token" };
  const row = await db.prepare(
    "SELECT id,inviter_user_id,commission_usd_cents,status FROM invite_dollar_commissions WHERE source_purchase_token=?"
  ).bind(token).first();
  if (!row) return { applied: false, reason: "no_commission" };
  if (String(row.status ?? "") === "reversed") {
    return { applied: false, duplicate: true, reason: "already_reversed" };
  }
  const inviterUserId = String(row.inviter_user_id);
  const commission = Number(row.commission_usd_cents ?? 0);
  const beforeRow = await db.prepare(
    "SELECT balance_usd_cents FROM invite_dollar_balances WHERE user_id=?"
  ).bind(inviterUserId).first();
  const before = Number(beforeRow?.balance_usd_cents ?? 0);
  const clawback = Math.min(before, commission);
  await db.batch([
    db.prepare(
      "UPDATE invite_dollar_balances SET balance_usd_cents=CASE WHEN balance_usd_cents>=? THEN balance_usd_cents-? ELSE 0 END,updated_at=? WHERE user_id=?"
    ).bind(commission, commission, ts, inviterUserId),
    db.prepare(
      "UPDATE invite_dollar_commissions SET status='reversed' WHERE id=? AND status='active'"
    ).bind(String(row.id)),
  ]);
  return {
    applied: true,
    inviter_user_id: inviterUserId,
    commission_usd_cents: commission,
    clawed_back_usd_cents: clawback,
    inviter_balance_usd_cents_after: Math.max(0, before - commission),
  };
}

// Withdraw referral dollars to a coin seller / merchant. The provider
// receives the dollars (recorded in the withdrawal row) and
// automatically receives 11,000,000 coins per $1 into their SELLER
// wallet (role wallet), never the normal user wallet. The sender gets
// nothing extra for sending the dollars. Idempotent on idempotency_key:
// a retry returns the original withdrawal instead of paying twice.
export async function withdrawInviteDollars(db, {
  userId,
  providerUserId,
  amountUsdCents,
  idempotencyKey,
  ts = Date.now(),
}) {
  await ensureInviteRewardSchema(db);
  const sender = String(userId ?? "").trim();
  const provider = String(providerUserId ?? "").trim();
  const key = String(idempotencyKey ?? "").trim();
  const amount = Number(amountUsdCents);
  if (!sender || !provider || !key) {
    throw new Error("invalid_withdrawal_request");
  }
  if (!Number.isSafeInteger(amount) || amount < REFERRAL_WITHDRAWAL_MIN_USD_CENTS) {
    throw new Error("withdrawal_below_minimum");
  }
  if (provider === sender) {
    throw new Error("cannot_withdraw_to_self");
  }

  const prior = await db.prepare(
    "SELECT id,user_id,provider_user_id,provider_role,amount_usd_cents,coins_credited,created_at FROM invite_dollar_withdrawals WHERE idempotency_key=?"
  ).bind(key).first();
  if (prior) {
    if (String(prior.user_id) !== sender) {
      throw new Error("idempotency_key_conflict");
    }
    return {
      ok: true,
      duplicate: true,
      withdrawal_id: String(prior.id),
      user_id: sender,
      provider_user_id: String(prior.provider_user_id),
      provider_role: String(prior.provider_role),
      amount_usd_cents: Number(prior.amount_usd_cents ?? 0),
      coins_credited: Number(prior.coins_credited ?? 0),
      created_at: Number(prior.created_at ?? 0),
    };
  }

  const providerRow = await db.prepare(
    "SELECT id,role FROM users WHERE id=?"
  ).bind(provider).first();
  if (!providerRow) throw new Error("provider_not_found");
  const providerRole = String(providerRow.role ?? "");
  if (providerRole !== "coin_seller" && providerRole !== "merchant") {
    throw new Error("provider_not_seller_or_merchant");
  }

  const coins = amount * REFERRAL_WITHDRAWAL_COINS_PER_USD_CENT;
  if (!Number.isSafeInteger(coins) || coins <= 0) {
    throw new Error("invalid_withdrawal_amount");
  }

  // The provider's seller wallet must exist before the batch: the
  // credit UPDATE inside it cannot create the row.
  const { ensureRoleWallet } = await import("./role_wallets.js");
  await ensureRoleWallet(db, provider, providerRole, ts);

  const withdrawalId = crypto.randomUUID();
  const batchResults = await db.batch([
    // 1. Debit the inviter's dollar balance, guarded: only if they
    // hold at least the amount. If this changes 0 rows, the rest of
    // the batch is gated off by changes()==1 and nothing moves.
    db.prepare(
      "UPDATE invite_dollar_balances SET balance_usd_cents=balance_usd_cents-?,updated_at=? WHERE user_id=? AND balance_usd_cents>=?"
    ).bind(amount, ts, sender, amount),
    // 2. Record the withdrawal (only when the debit moved).
    db.prepare(
      "INSERT INTO invite_dollar_withdrawals(id,user_id,provider_user_id,provider_role,amount_usd_cents,coins_credited,idempotency_key,created_at) SELECT ?,?,?,?,?,?,?,? WHERE changes()=1"
    ).bind(
      withdrawalId, sender, provider, providerRole,
      amount, coins, key, ts,
    ),
    // 3. Credit the provider's SELLER wallet (role wallet), guarded.
    db.prepare(
      "UPDATE role_wallets SET balance_coins=balance_coins+?,updated_at=? WHERE user_id=? AND wallet_type=? AND balance_coins+?>=0 AND changes()=1"
    ).bind(coins, ts, provider, providerRole, coins),
    // 4. Seller-wallet ledger row, gated on the credit.
    db.prepare(
      "INSERT INTO role_wallet_ledger(id,user_id,wallet_type,kind,coin_amount,coin_balance_after,counterparty_user_id,reference_id,created_at) SELECT ?,?,?, 'invite_dollar_withdrawal', ?, balance_coins, ?, ?, ? FROM role_wallets WHERE user_id=? AND wallet_type=? AND changes()=1"
    ).bind(
      crypto.randomUUID(), provider, providerRole,
      coins, sender, withdrawalId, ts, provider, providerRole,
    ),
  ]);
  if (Number(batchResults?.[0]?.meta?.changes ?? 0) !== 1) {
    const raced = await db.prepare(
      "SELECT id FROM invite_dollar_withdrawals WHERE idempotency_key=?"
    ).bind(key).first();
    if (raced) {
      return withdrawInviteDollars(db, {
        userId: sender,
        providerUserId: provider,
        amountUsdCents: amount,
        idempotencyKey: key,
        ts,
      });
    }
    throw new Error("insufficient_referral_dollar_balance");
  }

  const balanceRow = await db.prepare(
    "SELECT balance_usd_cents FROM invite_dollar_balances WHERE user_id=?"
  ).bind(sender).first();
  const sellerRow = await db.prepare(
    "SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).bind(provider, providerRole).first();

  return {
    ok: true,
    duplicate: false,
    withdrawal_id: withdrawalId,
    user_id: sender,
    provider_user_id: provider,
    provider_role: providerRole,
    amount_usd_cents: amount,
    coins_credited: coins,
    dollar_balance_usd_cents_after: Number(balanceRow?.balance_usd_cents ?? 0),
    provider_seller_wallet_balance_after: Number(sellerRow?.balance_coins ?? 0),
    created_at: ts,
  };
}
