import { rocketMedalObjects, userRocketMedals } from "./rocket_medal_grants.js";
import { checkContent } from "./content_filter.js";
import {
  FAMILY_MAX_LEVEL,
  FAMILY_TASK_REWARDS,
  FAMILY_WEEKLY_ELIGIBILITY_COINS,
  FAMILY_WEEKLY_TIERS,
  familyDeputyLimit,
  familyGameExp,
  familyGiftExp,
  familyLevelBand,
  familyLevelForExp,
  familyMemberLimit,
  familyMonthlyVaultReward,
  familyRankForMonthlyExp,
  familyUpgradeVaultReward,
  familyWeeklyTierForTotal,
  familyWeeklyTopCoins,
} from "./family_rules.js";

const ts = () => Date.now();
const uid = (prefix = "") => prefix + crypto.randomUUID();

export async function ensureTinniSocialSchema(db) {
  const statements = [
    `CREATE TABLE IF NOT EXISTS owner_user_overrides (
      user_id TEXT PRIMARY KEY,
      invisible_id INTEGER NOT NULL DEFAULT 0,
      locked_room_bypass INTEGER NOT NULL DEFAULT 0,
      wallet_frozen INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL DEFAULT 0
    )`,
    `CREATE TABLE IF NOT EXISTS user_follows (
      follower_id TEXT NOT NULL,
      target_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (follower_id, target_id),
      CHECK (follower_id <> target_id)
    )`,
    `CREATE TABLE IF NOT EXISTS user_task_claims (
      user_id TEXT NOT NULL,
      task_id TEXT NOT NULL,
      reward_coins INTEGER NOT NULL,
      claimed_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, task_id)
    )`,
    `CREATE TABLE IF NOT EXISTS official_notices (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )`,
    `CREATE TABLE IF NOT EXISTS activity_read_receipts (
      user_id TEXT NOT NULL,
      item_id TEXT NOT NULL,
      read_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, item_id)
    )`,
    `CREATE TABLE IF NOT EXISTS profile_trends (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )`,
    `CREATE INDEX IF NOT EXISTS idx_profile_trends_user_time
       ON profile_trends(user_id,created_at DESC)`,
    `CREATE TABLE IF NOT EXISTS user_feedback (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      category TEXT NOT NULL,
      message TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'submitted',
      created_at INTEGER NOT NULL
    )`,
    `CREATE TABLE IF NOT EXISTS families (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      tag TEXT NOT NULL,
      leader_user_id TEXT NOT NULL,
      notice TEXT NOT NULL DEFAULT '',
      experience INTEGER NOT NULL DEFAULT 0,
      wallet_coins INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`,
    // Last login per user (also created by ensureOwnerControlSchema):
    // the Management page shows "Today / 1 day ago" per member, and
    // the 15-day leader auto-transfer reads the same table.
    `CREATE TABLE IF NOT EXISTS owner_user_devices (
      device_key TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      last_seen_at INTEGER NOT NULL
    )`,
    `CREATE INDEX IF NOT EXISTS idx_owner_user_devices_user
       ON owner_user_devices(user_id,last_seen_at DESC)`,
    `CREATE UNIQUE INDEX IF NOT EXISTS idx_families_name_ci
       ON families(LOWER(name))`,
    `CREATE UNIQUE INDEX IF NOT EXISTS idx_families_tag_ci
       ON families(UPPER(tag))`,
    `CREATE TABLE IF NOT EXISTS family_members (
      family_id TEXT NOT NULL,
      user_id TEXT NOT NULL UNIQUE,
      role TEXT NOT NULL DEFAULT 'member',
      joined_at INTEGER NOT NULL,
      PRIMARY KEY (family_id, user_id)
    )`,
    `CREATE TABLE IF NOT EXISTS family_join_requests (
      family_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (family_id, user_id)
    )`,
    `CREATE TABLE IF NOT EXISTS family_daily_logins (
      family_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      day_key TEXT NOT NULL,
      exp_awarded INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (family_id, user_id, day_key)
    )`,
    `CREATE TABLE IF NOT EXISTS family_wallet_transfers (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL,
      sender_user_id TEXT NOT NULL,
      receiver_user_id TEXT NOT NULL,
      coins INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(family_id) REFERENCES families(id) ON DELETE CASCADE,
      FOREIGN KEY(sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY(receiver_user_id) REFERENCES users(id) ON DELETE CASCADE
    )`,
    `CREATE INDEX IF NOT EXISTS idx_family_wallet_transfers_family_time
       ON family_wallet_transfers(family_id,created_at DESC)`,
    // Family Rules (Mr. Wrong, 2026-11-24): monthly EXP per family (the
    // monthly list is ranked by this month's EXP and settles on the 1st),
    // per-member monthly stats for the Charm/Wealth/Active Star rankings,
    // daily task progress (room stay / mic minutes), family Trends posts,
    // and the vault reward history (level-up + monthly top-10 rewards).
    `CREATE TABLE IF NOT EXISTS family_monthly_exp (
      family_id TEXT NOT NULL,
      month_key TEXT NOT NULL,
      exp INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (family_id, month_key)
    )`,
    `CREATE TABLE IF NOT EXISTS family_member_monthly (
      family_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      month_key TEXT NOT NULL,
      given_exp INTEGER NOT NULL DEFAULT 0,
      received_exp INTEGER NOT NULL DEFAULT 0,
      active_minutes INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (family_id, user_id, month_key)
    )`,
    `CREATE TABLE IF NOT EXISTS family_task_progress (
      family_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      day_key TEXT NOT NULL,
      kind TEXT NOT NULL,
      minutes INTEGER NOT NULL DEFAULT 0,
      awarded INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (family_id, user_id, day_key, kind)
    )`,
    `CREATE TABLE IF NOT EXISTS family_posts (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(family_id) REFERENCES families(id) ON DELETE CASCADE
    )`,
    `CREATE INDEX IF NOT EXISTS idx_family_posts_family_time
       ON family_posts(family_id,created_at DESC)`,
    `CREATE TABLE IF NOT EXISTS family_post_likes (
      post_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (post_id, user_id)
    )`,
    `CREATE TABLE IF NOT EXISTS family_post_comments (
      id TEXT PRIMARY KEY,
      post_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )`,
    `CREATE INDEX IF NOT EXISTS idx_family_post_comments_post_time
       ON family_post_comments(post_id,created_at ASC)`,
    `CREATE TABLE IF NOT EXISTS family_vault_history (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      detail TEXT NOT NULL DEFAULT '',
      coins INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )`,
    `CREATE INDEX IF NOT EXISTS idx_family_vault_history_family_time
       ON family_vault_history(family_id,created_at DESC)`,
    `CREATE TABLE IF NOT EXISTS family_monthly_rewards (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL,
      month_key TEXT NOT NULL,
      rank_value INTEGER NOT NULL,
      vault_coins INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE (family_id, month_key)
    )`,
    // Family Weekly Rewards (Mr. Wrong, 2026-11-24): one row per settled
    // reward (leader coins + top-15 coins + the 7-day frame/medal/tag/
    // vehicle items, recorded as granted display items). Idempotent per
    // (family, week, user, kind).
    `CREATE TABLE IF NOT EXISTS family_weekly_rewards (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL,
      week_key TEXT NOT NULL,
      user_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      rank_value INTEGER NOT NULL DEFAULT 0,
      coins INTEGER NOT NULL DEFAULT 0,
      detail TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      UNIQUE (family_id, week_key, user_id, kind)
    )`,
    `CREATE INDEX IF NOT EXISTS idx_family_weekly_rewards_week
       ON family_weekly_rewards(week_key,family_id)`,
    // Today's Family Lucky Draw Records (Mr. Wrong, 2026-11-24): who won
    // what in the Daily Lucky Wheel. The wheel SPIN is on HOLD (event) —
    // this table is empty until the event is built; the list UI reads it.
    `CREATE TABLE IF NOT EXISTS family_lucky_draw_records (
      id TEXT PRIMARY KEY,
      family_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      display_name TEXT NOT NULL DEFAULT '',
      coins INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )`,
    `CREATE INDEX IF NOT EXISTS idx_family_lucky_draw_records_family_time
       ON family_lucky_draw_records(family_id,created_at DESC)`,
    `CREATE TABLE IF NOT EXISTS cp_relationships (
      user_a TEXT NOT NULL,
      user_b TEXT NOT NULL,
      state TEXT NOT NULL DEFAULT 'pending',
      intimacy INTEGER NOT NULL DEFAULT 0,
      level INTEGER NOT NULL DEFAULT 1,
      cycle_a_to_b INTEGER NOT NULL DEFAULT 0,
      cycle_b_to_a INTEGER NOT NULL DEFAULT 0,
      requested_by TEXT,
      ring_id TEXT,
      activated_at INTEGER,
      disconnect_state TEXT NOT NULL DEFAULT 'none',
      disconnect_requested_by TEXT,
      disconnect_requested_at INTEGER,
      heartbeat_state TEXT NOT NULL DEFAULT 'idle',
      heartbeat_choice_a TEXT,
      heartbeat_choice_b TEXT,
      heartbeat_updated_at INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (user_a, user_b)
    )`,
    `CREATE TABLE IF NOT EXISTS cp_gift_progress (
      event_id TEXT PRIMARY KEY,
      user_a TEXT NOT NULL,
      user_b TEXT NOT NULL,
      pair_started_at INTEGER NOT NULL,
      sender_user_id TEXT NOT NULL,
      receiver_user_id TEXT NOT NULL,
      progress INTEGER NOT NULL,
      level_before INTEGER NOT NULL,
      level_after INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )`,
    `CREATE INDEX IF NOT EXISTS idx_cp_gift_progress_pair_time
       ON cp_gift_progress(user_a,user_b,pair_started_at,created_at DESC)`,
    `CREATE TABLE IF NOT EXISTS cp_memories (
      id TEXT PRIMARY KEY,
      user_a TEXT NOT NULL,
      user_b TEXT NOT NULL,
      body TEXT NOT NULL,
      created_by TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )`,
  ];
  for (const sql of statements) await db.prepare(sql).run();
  // VS removed (Vinay, 2026-11-20) — drop its tables on existing
  // databases; fresh databases never create them (no CREATE above).
  await db.prepare("DROP TABLE IF EXISTS vs_relationships").run();
  await db.prepare("DROP TABLE IF EXISTS vs_gift_progress").run();
  try {
    await db.prepare("ALTER TABLE cp_relationships ADD COLUMN ring_id TEXT").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE cp_relationships ADD COLUMN cycle_a_to_b INTEGER NOT NULL DEFAULT 0").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE cp_relationships ADD COLUMN cycle_b_to_a INTEGER NOT NULL DEFAULT 0").run();
  } catch (_) {}
  for (const sql of [
    "ALTER TABLE cp_relationships ADD COLUMN activated_at INTEGER",
    "ALTER TABLE direct_messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'",
    "ALTER TABLE cp_relationships ADD COLUMN disconnect_state TEXT NOT NULL DEFAULT 'none'",
    "ALTER TABLE cp_relationships ADD COLUMN disconnect_requested_by TEXT",
    "ALTER TABLE cp_relationships ADD COLUMN disconnect_requested_at INTEGER",
    "ALTER TABLE cp_relationships ADD COLUMN heartbeat_state TEXT NOT NULL DEFAULT 'idle'",
    "ALTER TABLE cp_relationships ADD COLUMN heartbeat_choice_a TEXT",
    "ALTER TABLE cp_relationships ADD COLUMN heartbeat_choice_b TEXT",
    "ALTER TABLE cp_relationships ADD COLUMN heartbeat_updated_at INTEGER"
  ]) {
    try { await db.prepare(sql).run(); } catch (_) {}
  }
  // Family create (Mr. Wrong, 2026-11-24): approval setting (1 = leader
  // must approve join requests, 0 = anyone joins directly) + logo key.
  // Rename rule (Mr. Wrong, 2026-11-24): the family name and tag can
  // each only be changed once a month — name_changed_at / tag_changed_at
  // record the last change (creation counts as the first change).
  for (const sql of [
    "ALTER TABLE families ADD COLUMN approval_required INTEGER NOT NULL DEFAULT 1",
    "ALTER TABLE families ADD COLUMN logo_key TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE families ADD COLUMN name_changed_at INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE families ADD COLUMN tag_changed_at INTEGER NOT NULL DEFAULT 0",
  ]) {
    try { await db.prepare(sql).run(); } catch (_) {}
  }
  await db.prepare(
    "INSERT OR IGNORE INTO official_notices(id,title,body,created_at) VALUES(?,?,?,?)"
  ).bind(
    "official-welcome",
    "Welcome to DarkVibeX",
    "Official notices, safety updates and app information will appear here.",
    1,
  ).run();
}

function clean(value, max) {
  return String(value ?? "").trim().slice(0, max);
}

function pair(a, b) {
  return [String(a), String(b)].sort();
}

async function familyMembership(db, userId) {
  return db.prepare(
    `SELECT fm.family_id,fm.role,fm.joined_at,
            f.name,f.tag,f.notice,f.leader_user_id,f.experience,f.wallet_coins,
            f.logo_key,f.approval_required,f.name_changed_at,f.tag_changed_at,
            f.created_at,f.updated_at
       FROM family_members fm
       JOIN families f ON f.id=fm.family_id
      WHERE fm.user_id=? LIMIT 1`
  ).bind(userId).first();
}

// Family level (Mr. Wrong, 2026-11-24): Lv.1-Lv.50, the other app's EXP
// thresholds x1.5 (see family_rules.js — the two observed points are
// Lv.4 = 3,240,000,000 and Lv.17 = 157,125,000,000). Replaces the old
// L1-L8 ladder [0,100,500,1500,5000,15000,50000,150000].
function familyLevel(experience) {
  return familyLevelForExp(experience);
}

export { FAMILY_MAX_LEVEL, familyLevelBand };

// Dollar level (Vinay, 2026-11-23): a level based on the user's total
// recharge in US cents. L1-L10 are Vinay's numbers ($2, $5, $12, $20,
// $40, $70, $110, $150, $190, $250); L100 is $11,000 and L200 is
// $25,000 (Vinay, 2026-11-23). Between them the ladder is filled in
// evenly: L11-L100 interpolate $250 → $11,000 in whole dollars,
// L101-L200 add exactly $140 per level.
// Milestones: L20 $1,444, L50 $5,028, L100 $11,000, L150 $18,000,
// L200 $25,000.
// The owner can override the whole ladder with the owner_settings key
// `dollar_level_thresholds` (JSON array of cents).
export function dollarLevelThresholdsCents() {
  const thresholds = [200, 500, 1200, 2000, 4000, 7000, 11000, 15000, 19000, 25000];
  for (let level = 11; level <= 100; level += 1) {
    const dollars = Math.round(250 + (10750 * (level - 10)) / 90);
    thresholds.push(dollars * 100);
  }
  for (let level = 101; level <= 200; level += 1) {
    thresholds.push((11000 + 140 * (level - 100)) * 100);
  }
  return thresholds;
}

const COINS_PER_USD = 8_000_000;

// Total recharge of a user in US cents: granted Play purchases (by
// product, refunded/pending excluded) + coins received into the normal
// wallet from a coin seller / merchant transfer, valued at the fixed
// $1 = 8,000,000 coins rate. The VIP purchase bonus is free platform
// coins, not a recharge, so vip_coins_bonus rows are not counted.
export async function totalRechargedUsdCents(db, userId) {
  let playCents = 0;
  const hasPlay = await db.prepare(
    "SELECT 1 AS yes FROM sqlite_master WHERE type='table' AND name='play_purchases'"
  ).first();
  if (hasPlay) {
    const row = await db.prepare(`
      SELECT COALESCE(SUM(CASE product_id
        WHEN 'coins_8000000' THEN 100
        WHEN 'coins_16000000' THEN 200
        WHEN 'coins_40000000' THEN 500
        WHEN 'coins_80000000' THEN 1000
        ELSE 0 END),0) AS total
        FROM play_purchases
       WHERE user_id=? AND status='granted'
    `).bind(userId).first();
    playCents = Number(row?.total ?? 0);
  }
  const seller = await db.prepare(`
    SELECT COALESCE(SUM(amount),0) AS total FROM wallet_ledger
     WHERE user_id=? AND kind IN ('coin_seller_received','merchant_received')
  `).bind(userId).first();
  const sellerCents = Math.floor(Number(seller?.total ?? 0) * 100 / COINS_PER_USD);
  return playCents + sellerCents;
}

// Dollar levels for a batch of users (room chat tags, Vinay 2026-11-23):
// one Play query + one ledger query for all ids, then the same ladder
// (with the owner override) as profileStats, so the chat tag and the
// profile always agree. Wealth IS the dollar level — one gold-$ tag.
export async function dollarLevelsByUser(db, userIds) {
  const ids = [...new Set(
    (userIds ?? []).map((id) => String(id ?? "").trim()).filter(Boolean),
  )];
  const levels = new Map(ids.map((id) => [id, 0]));
  if (!ids.length) return levels;
  const placeholders = ids.map(() => "?").join(",");
  const centsByUser = new Map(ids.map((id) => [id, 0]));
  const isMissingTable = (error) => /no such table/i.test(String(error?.message ?? error));
  // Granted Play purchases, by product (refunded/pending excluded).
  try {
    const rows = await db.prepare(`
      SELECT user_id, COALESCE(SUM(CASE product_id
        WHEN 'coins_8000000' THEN 100
        WHEN 'coins_16000000' THEN 200
        WHEN 'coins_40000000' THEN 500
        WHEN 'coins_80000000' THEN 1000
        ELSE 0 END),0) AS total
        FROM play_purchases
       WHERE user_id IN (${placeholders}) AND status='granted'
       GROUP BY user_id
    `).bind(...ids).all();
    for (const row of rows.results ?? []) {
      centsByUser.set(String(row.user_id), Number(row.total ?? 0));
    }
  } catch (error) {
    if (!isMissingTable(error)) throw error;
  }
  // Coins received from a coin seller / merchant transfer, $1 = 8M coins.
  try {
    const rows = await db.prepare(`
      SELECT user_id, COALESCE(SUM(amount),0) AS total FROM wallet_ledger
       WHERE user_id IN (${placeholders})
         AND kind IN ('coin_seller_received','merchant_received')
       GROUP BY user_id
    `).bind(...ids).all();
    for (const row of rows.results ?? []) {
      const userId = String(row.user_id);
      const sellerCents = Math.floor(Number(row.total ?? 0) * 100 / COINS_PER_USD);
      centsByUser.set(userId, (centsByUser.get(userId) ?? 0) + sellerCents);
    }
  } catch (error) {
    if (!isMissingTable(error)) throw error;
  }
  // The owner can override the whole ladder (same key as profileStats).
  let thresholds = dollarLevelThresholdsCents();
  try {
    const row = await db.prepare(
      "SELECT value_json FROM owner_settings WHERE key=?"
    ).bind("dollar_level_thresholds").first();
    const parsed = JSON.parse(String(row?.value_json ?? "[]"));
    if (Array.isArray(parsed)) {
      const custom = parsed
        .map((value) => Math.max(0, Number(value || 0)))
        .filter(Number.isFinite)
        .sort((a, b) => a - b);
      if (custom.length) thresholds = custom;
    }
  } catch (_) {}
  for (const [userId, cents] of centsByUser) {
    let level = 0;
    for (const threshold of thresholds) {
      if (cents >= threshold) level += 1;
      else break;
    }
    levels.set(userId, level);
  }
  return levels;
}

export async function profileStats(db, userId) {
  await ensureTinniSocialSchema(db);
  const following = await db.prepare(
    "SELECT COUNT(*) AS total FROM user_follows WHERE follower_id=?"
  ).bind(userId).first();
  const followers = await db.prepare(
    "SELECT COUNT(*) AS total FROM user_follows WHERE target_id=?"
  ).bind(userId).first();
  const sent = await db.prepare(
    "SELECT COALESCE(SUM(coin_cost),0) AS total FROM gift_events WHERE sender_user_id=?"
  ).bind(userId).first();
  const received = await db.prepare(
    "SELECT COALESCE(SUM(coin_cost),0) AS total FROM gift_events WHERE receiver_user_id=?"
  ).bind(userId).first();
  const sentCoins = Math.max(0, Number(sent?.total ?? 0));
  const receivedCoins = Math.max(0, Number(received?.total ?? 0));
  const rechargedCents = await totalRechargedUsdCents(db, userId);
  const thresholdInfo = async (key, points, fallback) => {
    let thresholds = [];
    try {
      const row = await db.prepare(
        "SELECT value_json FROM owner_settings WHERE key=?"
      ).bind(key).first();
      const parsed = JSON.parse(String(row?.value_json ?? "[]"));
      if (Array.isArray(parsed)) {
        thresholds = parsed
          .map((value) => Math.max(0, Number(value || 0)))
          .filter(Number.isFinite)
          .sort((a, b) => a - b);
      }
    } catch (_) {}
    if (thresholds.length === 0) {
      thresholds = fallback ?? [
        100000, 500000, 1000000, 5000000, 10000000,
        25000000, 50000000, 100000000, 250000000, 500000000,
      ];
    }
    let level = 0;
    for (const threshold of thresholds) {
      if (points >= threshold) level += 1;
      else break;
    }
    return {
      level,
      next_threshold: level < thresholds.length ? thresholds[level] : null,
      thresholds,
    };
  };
  return {
    user_id: userId,
    following_count: Number(following?.total ?? 0),
    followers_count: Number(followers?.total ?? 0),
    lifetime_sent_coins: sentCoins,
    lifetime_received_coins: receivedCoins,
    total_recharged_usd_cents: rechargedCents,
    wealth: await thresholdInfo("wealth_level_thresholds", sentCoins),
    charm: await thresholdInfo("charm_level_thresholds", receivedCoins),
    dollar_level: await thresholdInfo(
      "dollar_level_thresholds", rechargedCents, dollarLevelThresholdsCents(),
    ),
  };
}

export async function followUser(db, followerId, targetId, follow = true) {
  await ensureTinniSocialSchema(db);
  if (!followerId || !targetId || followerId === targetId) {
    throw new Error("invalid_follow_target");
  }
  if (follow) {
    await db.prepare(
      "INSERT OR IGNORE INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)"
    ).bind(followerId, targetId, ts()).run();
  } else {
    await db.prepare(
      "DELETE FROM user_follows WHERE follower_id=? AND target_id=?"
    ).bind(followerId, targetId).run();
  }
  return { ok: true, following: Boolean(follow) };
}

export async function followStatus(db, followerId, targetId) {
  await ensureTinniSocialSchema(db);
  const row = await db.prepare(
    "SELECT 1 AS active FROM user_follows WHERE follower_id=? AND target_id=?"
  ).bind(followerId, targetId).first();
  return Boolean(row);
}

export async function listFollowers(db, userId) {
  await ensureTinniSocialSchema(db);
  const rows = await db.prepare(
    `SELECT u.id,
            CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS public_id,
            u.display_name,u.avatar_key,f.created_at,
            EXISTS(
              SELECT 1 FROM user_follows reverse_follow
               WHERE reverse_follow.follower_id=? AND reverse_follow.target_id=u.id
            ) AS mutual
       FROM user_follows f
       JOIN users u ON u.id=f.follower_id
       LEFT JOIN owner_user_overrides io ON io.user_id=u.id
      WHERE f.target_id=? ORDER BY f.created_at DESC LIMIT 300`
  ).bind(userId,userId).all();
  return (rows.results ?? []).map((row) => ({
    ...row,
    mutual: Number(row.mutual ?? 0) === 1,
  }));
}

export async function listFollowing(db, userId) {
  await ensureTinniSocialSchema(db);
  const rows = await db.prepare(
    `SELECT u.id,
            CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS public_id,
            u.display_name,u.avatar_key,f.created_at,
            EXISTS(
              SELECT 1 FROM user_follows reverse_follow
               WHERE reverse_follow.follower_id=u.id AND reverse_follow.target_id=?
            ) AS mutual
       FROM user_follows f
       JOIN users u ON u.id=f.target_id
       LEFT JOIN owner_user_overrides io ON io.user_id=u.id
      WHERE f.follower_id=? ORDER BY f.created_at DESC LIMIT 300`
  ).bind(userId,userId).all();
  return (rows.results ?? []).map((row) => ({
    ...row,
    mutual: Number(row.mutual ?? 0) === 1,
  }));
}

export async function taskState(db, userId) {
  await ensureTinniSocialSchema(db);
  const user = await db.prepare(
    "SELECT display_name,date_of_birth,avatar_key FROM users WHERE id=?"
  ).bind(userId).first();
  if (!user) throw new Error("user_not_found");
  const followed = await db.prepare(
    "SELECT 1 AS ok FROM user_follows WHERE follower_id=? LIMIT 1"
  ).bind(userId).first();
  const family = await db.prepare(
    "SELECT 1 AS ok FROM family_members WHERE user_id=? LIMIT 1"
  ).bind(userId).first();
  const gifted = await db.prepare(
    "SELECT 1 AS ok FROM gift_events WHERE sender_user_id=? LIMIT 1"
  ).bind(userId).first();
  const entered = await db.prepare(
    "SELECT 1 AS ok FROM room_members WHERE user_id=? LIMIT 1"
  ).bind(userId).first();
  const claims = await db.prepare(
    "SELECT task_id FROM user_task_claims WHERE user_id=?"
  ).bind(userId).all();
  const claimed = new Set((claims.results ?? []).map((row) => String(row.task_id)));
  const definitions = [
    {
      id: "profile_complete",
      title: "Complete your profile",
      reward_coins: 100,
      completed: Boolean(
        clean(user.display_name, 60) &&
        clean(user.date_of_birth, 20) &&
        clean(user.avatar_key, 500)
      ),
    },
    { id: "follow_one", title: "Follow 1 user", reward_coins: 100, completed: Boolean(followed) },
    { id: "enter_room", title: "Enter a Party room", reward_coins: 100, completed: Boolean(entered) },
    { id: "send_gift", title: "Send your first gift", reward_coins: 200, completed: Boolean(gifted) },
    { id: "join_family", title: "Join a Family", reward_coins: 300, completed: Boolean(family) },
  ];
  return definitions.map((item) => ({ ...item, claimed: claimed.has(item.id) }));
}

export async function claimTask(db, userId, taskId) {
  const tasks = await taskState(db, userId);
  const task = tasks.find((item) => item.id === String(taskId ?? ""));
  if (!task) throw new Error("task_not_found");
  if (!task.completed) throw new Error("task_not_complete");
  if (task.claimed) throw new Error("task_already_claimed");
  const user = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
  if (!user) throw new Error("user_not_found");
  const createdAt = ts();
  // Relative credit (Wallet audit H3, 2026-11-22): the old code read
  // the balance, then wrote it back absolutely, so a concurrent
  // credit to the same user overwrote it and lost coins. The claim
  // itself is still guarded by PRIMARY KEY(user_id, task_id) on
  // user_task_claims, so a concurrent double-claim fails the batch.
  // The ledger balance is read inside the batch (post-credit).
  await db.batch([
    db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=?"
    ).bind(Number(task.reward_coins), createdAt, userId),
    db.prepare(
      "INSERT INTO user_task_claims(user_id,task_id,reward_coins,claimed_at) VALUES(?,?,?,?)"
    ).bind(userId, task.id, task.reward_coins, createdAt),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) " +
      "SELECT ?,u.id,'task_reward',?,u.coins,?,? FROM users u WHERE u.id=? AND changes()=1"
    ).bind(uid("task-"), task.reward_coins, task.id, createdAt, userId),
  ]);
  const afterRow = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
  const balance = Number(afterRow?.coins ?? 0);
  return { ok: true, task: { ...task, claimed: true }, tasks: await taskState(db, userId), coin_balance: balance };
}

export async function feedbackHistory(db, userId) {
  await ensureTinniSocialSchema(db);
  const rows = await db.prepare(
    "SELECT id,category,message,status,created_at FROM user_feedback WHERE user_id=? ORDER BY created_at DESC LIMIT 100"
  ).bind(userId).all();
  return rows.results ?? [];
}

export async function submitFeedback(db, userId, categoryValue, messageValue) {
  await ensureTinniSocialSchema(db);
  const category = clean(categoryValue || "General", 40) || "General";
  const message = clean(messageValue, 2000);
  if (message.length < 3) throw new Error("feedback_too_short");
  const row = {
    id: uid("feedback-"),
    user_id: userId,
    category,
    message,
    status: "submitted",
    created_at: ts(),
  };
  await db.prepare(
    "INSERT INTO user_feedback(id,user_id,category,message,status,created_at) VALUES(?,?,?,?,?,?)"
  ).bind(row.id,row.user_id,row.category,row.message,row.status,row.created_at).run();
  return { ok: true, feedback: row };
}

export async function medalState(db, userId) {
  const status = await profileStats(db, userId);
  const user = await db.prepare(
    "SELECT vip_level FROM users WHERE id=?"
  ).bind(userId).first();
  const medals = [];
  if (Number(user?.vip_level ?? 0) > 0) {
    medals.push({ id: "vip", name: "VIP", color: "#D09A0A" });
  }
  if (status.lifetime_sent_coins > 0) {
    medals.push({ id: "gifter", name: "Gift Sender", color: "#A55EEA" });
  }
  if (status.lifetime_received_coins > 0) {
    medals.push({ id: "charm", name: "Charm", color: "#FF6B9A" });
  }
  const idLevel = await db.prepare(
    "SELECT level FROM user_id_levels WHERE user_id=?"
  ).bind(userId).first().catch(() => null);
  if (Number(idLevel?.level ?? 0) > 0) {
    medals.push({
      id: "level",
      name: "ID Level " + Number(idLevel.level),
      color: "#45AAF2",
    });
  }
  // Earned Rocket medals (permanent, granted to Top 1/2/3 on a rocket
  // launch): they show with the earner's name in the room profile card.
  const rocketMedals = await userRocketMedals(db, userId);
  medals.push(...rocketMedalObjects(rocketMedals.map((row) => row.level)));
  return medals;
}

export async function familyList(db, limitValue = 100, countryValue = '') {
  await ensureTinniSocialSchema(db);
  const limit = Math.max(1, Math.min(100, Number(limitValue) || 100));
  // Local scope (Top Families page, 2026-11-24): when a country is given,
  // only families whose LEADER is in that country are listed.
  const country = String(countryValue ?? '').trim().toUpperCase();
  const where = country
    ? `WHERE UPPER(COALESCE(u.country_code,'')) = ?`
    : '';
  const params = country ? [country, limit] : [limit];
  const rows = await db.prepare(
    `SELECT f.id,f.name,f.tag,f.notice,f.leader_user_id,
            f.experience,f.wallet_coins,f.logo_key,f.approval_required,
            f.created_at,f.updated_at,
            u.display_name AS leader_name,u.avatar_key AS leader_avatar_key,
            u.country_code AS leader_country_code,
            COUNT(fm.user_id) AS member_count
       FROM families f
       LEFT JOIN family_members fm ON fm.family_id=f.id
       LEFT JOIN users u ON u.id=f.leader_user_id
      ${where}
      GROUP BY f.id
      ORDER BY f.experience DESC, member_count DESC, f.created_at ASC
      LIMIT ?`
  ).bind(...params).all();
  return (rows.results ?? []).map((row) => {
    const level = familyLevel(row.experience);
    return {
      ...row,
      level,
      // Join the family page (Mr. Wrong, 2026-11-24): "44/45" style
      // member counts — the limit grows with the family level.
      member_limit: familyMemberLimit(level.level),
    };
  });
}

// Family create (Mr. Wrong, 2026-11-24): creating a family costs
// 90,000,000 coins, free for Wealth Level >= 30 or VIP Level >= 6.
// The create page shows the name limit 0/20 and the tag limit 0/10.
export const FAMILY_CREATE_COST_COINS = 90000000;
export const FAMILY_CREATE_FREE_WEALTH_LEVEL = 30;
export const FAMILY_CREATE_FREE_VIP_LEVEL = 6;

export async function familyCreate(
  db,
  userId,
  nameValue,
  tagValue,
  options = {},
) {
  await ensureTinniSocialSchema(db);
  if (await familyMembership(db, userId)) throw new Error("already_in_family");
  const name = clean(nameValue, 20);
  const tag = clean(tagValue, 10).toUpperCase();
  if (name.length < 2 || tag.length < 2) throw new Error("invalid_family_name_or_tag");
  // Strong security (Vinay, 2026-11-22): no gaaliyan, porn, political
  // content, and no other apps' names — in the family name or tag.
  const nameHit = checkContent(name);
  if (nameHit.blocked) throw new Error("content_blocked");
  const tagHit = checkContent(tag);
  if (tagHit.blocked) throw new Error("content_blocked");
  const duplicate = await db.prepare(
    "SELECT id FROM families WHERE LOWER(name)=LOWER(?) OR UPPER(tag)=UPPER(?) LIMIT 1"
  ).bind(name, tag).first();
  if (duplicate) throw new Error("family_name_or_tag_in_use");
  const approvalRequired = options.approvalRequired === false ? 0 : 1;
  const logoKey = clean(options.logoKey, 512);
  // Logo is mandatory (Mr. Wrong, 2026-11-24: "Logo ke bina family
  // create hi nhi hogi") — a family cannot be created without one.
  if (!logoKey) throw new Error("logo_required");
  // Free creation for Wealth Level >= 30 or VIP Level >= 6, otherwise
  // the 90,000,000-coin cost is deducted from the user's wallet.
  const user = await db.prepare(
    "SELECT coins,vip_level FROM users WHERE id=?"
  ).bind(userId).first();
  if (!user) throw new Error("user_not_found");
  const stats = await profileStats(db, userId);
  const wealthLevel = Number(stats?.wealth?.level ?? 0);
  const vipLevel = Number(user.vip_level ?? 0);
  const free =
    wealthLevel >= FAMILY_CREATE_FREE_WEALTH_LEVEL ||
    vipLevel >= FAMILY_CREATE_FREE_VIP_LEVEL;
  const priceCoins = free ? 0 : FAMILY_CREATE_COST_COINS;
  if (priceCoins > 0) {
    const debit = await db.prepare(
      "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=?"
    ).bind(priceCoins, ts(), userId, priceCoins).run();
    if (Number(debit.meta?.changes ?? 0) !== 1) {
      throw new Error("insufficient_coins");
    }
  }
  const createdAt = ts();
  const familyId = uid("family-");
  try {
    await db.batch([
      db.prepare(
        "INSERT INTO families(id,name,tag,leader_user_id,notice,experience,wallet_coins,approval_required,logo_key,name_changed_at,tag_changed_at,created_at,updated_at) VALUES(?,?,?,?,?,0,0,?,?,?,?,?,?)"
      ).bind(familyId, name, tag, userId, "Welcome to " + name + " ❤️", approvalRequired, logoKey, createdAt, createdAt, createdAt, createdAt),
      db.prepare(
        "INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,'leader',?)"
      ).bind(familyId, userId, createdAt),
    ]);
  } catch (error) {
    // The family was not created: give the coins back.
    if (priceCoins > 0) {
      await db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?")
        .bind(priceCoins, ts(), userId).run();
    }
    throw error;
  }
  if (priceCoins > 0) {
    const wallet = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
    try {
      await db.prepare(
        "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
      ).bind(
        uid("ledger-"),
        userId,
        "family_create",
        -priceCoins,
        Number(wallet?.coins ?? 0),
        familyId,
        ts(),
      ).run();
    } catch (error) {
      // The ledger insert failed after the family was created: take the
      // family back and refund, or the user would keep a free family.
      await db.prepare("DELETE FROM family_members WHERE family_id=?").bind(familyId).run();
      await db.prepare("DELETE FROM families WHERE id=?").bind(familyId).run();
      await db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?")
        .bind(priceCoins, ts(), userId).run();
      throw error;
    }
  }
  // The creator is the family's first member: their Trends feed starts
  // with "I was born!", like every member who joins after them.
  await familyAutoBornPost(db, familyId, userId);
  return { ok: true, family_id: familyId, price_coins: priceCoins, free };
}

// Family rename rule (Mr. Wrong, 2026-11-24): the family name and the
// family tag can each only be changed once a month (30 days). Only the
// family leader can rename; creation counts as the first change.
export const FAMILY_RENAME_COOLDOWN_MS = 30 * 24 * 60 * 60 * 1000;

export async function familyUpdateNameTag(db, userId, changes = {}) {
  await ensureTinniSocialSchema(db);
  const member = await familyMembership(db, userId);
  if (!member) throw new Error("not_in_family");
  if (String(member.role) !== "leader") throw new Error("family_leader_required");
  const now = ts();
  const updates = [];
  const params = [];
  if (changes.name !== undefined) {
    const name = clean(changes.name, 20);
    if (name.length < 2) throw new Error("invalid_family_name_or_tag");
    const nameHit = checkContent(name);
    if (nameHit.blocked) throw new Error("content_blocked");
    if (Number(member.name_changed_at ?? 0) > 0 &&
        now - Number(member.name_changed_at) < FAMILY_RENAME_COOLDOWN_MS) {
      throw new Error("family_name_change_too_soon");
    }
    const duplicate = await db.prepare(
      "SELECT id FROM families WHERE LOWER(name)=LOWER(?) AND id<>? LIMIT 1"
    ).bind(name, member.family_id).first();
    if (duplicate) throw new Error("family_name_or_tag_in_use");
    updates.push("name=?", "name_changed_at=?");
    params.push(name, now);
  }
  if (changes.tag !== undefined) {
    const tag = clean(changes.tag, 10).toUpperCase();
    if (tag.length < 2) throw new Error("invalid_family_name_or_tag");
    const tagHit = checkContent(tag);
    if (tagHit.blocked) throw new Error("content_blocked");
    if (Number(member.tag_changed_at ?? 0) > 0 &&
        now - Number(member.tag_changed_at) < FAMILY_RENAME_COOLDOWN_MS) {
      throw new Error("family_tag_change_too_soon");
    }
    const duplicate = await db.prepare(
      "SELECT id FROM families WHERE UPPER(tag)=UPPER(?) AND id<>? LIMIT 1"
    ).bind(tag, member.family_id).first();
    if (duplicate) throw new Error("family_name_or_tag_in_use");
    updates.push("tag=?", "tag_changed_at=?");
    params.push(tag, now);
  }
  if (updates.length === 0) throw new Error("nothing_to_update");
  updates.push("updated_at=?");
  params.push(now, member.family_id);
  await db.prepare(
    `UPDATE families SET ${updates.join(", ")} WHERE id=?`
  ).bind(...params).run();
  const updated = await db.prepare(
    "SELECT name,tag,name_changed_at,tag_changed_at FROM families WHERE id=?"
  ).bind(member.family_id).first();
  return {
    ok: true,
    name: updated?.name ?? "",
    tag: updated?.tag ?? "",
    name_changed_at: Number(updated?.name_changed_at ?? 0),
    tag_changed_at: Number(updated?.tag_changed_at ?? 0),
  };
}

// Leader auto-transfer (Mr. Wrong, 2026-11-24): if the family leader
// does not log in for 15 days, the leader position automatically moves
// to the longest-joined admin, else the longest-joined member. Activity
// is the leader's last device seen time (owner_user_devices.last_seen_at,
// refreshed on every authenticated request with a device id). A leader
// with no device record is left alone — no data, no transfer.
export const FAMILY_LEADER_INACTIVE_MS = 15 * 24 * 60 * 60 * 1000;

export async function transferInactiveFamilyLeaders(db, onlyFamilyId) {
  await ensureTinniSocialSchema(db);
  const families = onlyFamilyId
    ? await db.prepare("SELECT id,leader_user_id FROM families WHERE id=?").bind(onlyFamilyId).all()
    : await db.prepare("SELECT id,leader_user_id FROM families").all();
  const transferred = [];
  for (const family of families.results ?? []) {
    const familyId = String(family.id);
    const leaderId = String(family.leader_user_id ?? "");
    if (!leaderId) continue;
    let lastSeen = null;
    try {
      const row = await db.prepare(
        "SELECT MAX(last_seen_at) AS last_seen FROM owner_user_devices WHERE user_id=?"
      ).bind(leaderId).first();
      lastSeen = Number(row?.last_seen ?? 0) || null;
    } catch (_) {
      // No device table (older DB): never transfer without data.
      continue;
    }
    if (lastSeen == null) continue;
    if (Date.now() - lastSeen < FAMILY_LEADER_INACTIVE_MS) continue;
    const successor = await db.prepare(
      `SELECT user_id FROM family_members WHERE family_id=? AND user_id<>?
        ORDER BY CASE role WHEN 'admin' THEN 0 ELSE 1 END, joined_at ASC LIMIT 1`
    ).bind(familyId, leaderId).first();
    if (!successor) continue;
    const successorId = String(successor.user_id);
    const now = ts();
    await db.batch([
      db.prepare("UPDATE families SET leader_user_id=?,updated_at=? WHERE id=?")
        .bind(successorId, now, familyId),
      db.prepare("UPDATE family_members SET role='leader' WHERE family_id=? AND user_id=?")
        .bind(familyId, successorId),
      db.prepare("UPDATE family_members SET role='member' WHERE family_id=? AND user_id=?")
        .bind(familyId, leaderId),
    ]);
    transferred.push({ family_id: familyId, from: leaderId, to: successorId });
  }
  return transferred;
}

export async function familyState(db, userId) {
  await ensureTinniSocialSchema(db);
  let member = await familyMembership(db, userId);
  if (!member) {
    return { family: null, members: [], join_requests: [], available_families: await familyList(db, 100) };
  }
  // Lazy leader auto-transfer (Mr. Wrong, 2026-11-24): if the leader has
  // not logged in for 15 days, the position moves before we answer, so
  // the family page always shows the current leader. The daily scheduled
  // sweep does the same for families nobody opens.
  try {
    const moved = await transferInactiveFamilyLeaders(db, member.family_id);
    if (moved.length > 0) member = await familyMembership(db, userId);
  } catch (_) {}
  const members = await db.prepare(
    `SELECT fm.user_id,fm.role,fm.joined_at,u.display_name,u.avatar_key,
            CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS public_id,
            COALESCE((
              SELECT SUM(t.coins)
                FROM family_wallet_transfers t
               WHERE t.family_id=fm.family_id
                 AND t.receiver_user_id=fm.user_id
            ),0) AS received_coins,
            (SELECT MAX(d.last_seen_at) FROM owner_user_devices d WHERE d.user_id=fm.user_id) AS last_seen_at
       FROM family_members fm JOIN users u ON u.id=fm.user_id
       LEFT JOIN owner_user_overrides io ON io.user_id=fm.user_id
      WHERE fm.family_id=?
      ORDER BY CASE fm.role WHEN 'leader' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
               fm.joined_at ASC`
  ).bind(member.family_id).all();
  let joinRequests = [];
  if (member.role === "leader" || member.role === "admin") {
    const requests = await db.prepare(
      `SELECT r.user_id,r.created_at,u.display_name,u.avatar_key
         FROM family_join_requests r JOIN users u ON u.id=r.user_id
        WHERE r.family_id=? AND r.status='pending'
        ORDER BY r.created_at ASC`
    ).bind(member.family_id).all();
    joinRequests = requests.results ?? [];
  }
  return {
    family: {
      id: member.family_id,
      name: member.name,
      tag: member.tag,
      notice: member.notice,
      leader_user_id: member.leader_user_id,
      experience: Number(member.experience ?? 0),
      wallet_coins: Number(member.wallet_coins ?? 0),
      logo_key: member.logo_key ?? "",
      approval_required: Number(member.approval_required ?? 1),
      name_changed_at: Number(member.name_changed_at ?? 0),
      tag_changed_at: Number(member.tag_changed_at ?? 0),
      my_role: member.role,
      ...familyLevel(member.experience),
    },
    members: members.results ?? [],
    join_requests: joinRequests,
  };
}

export async function familyRequestJoin(db, userId, familyId) {
  await ensureTinniSocialSchema(db);
  if (await familyMembership(db, userId)) throw new Error("already_in_family");
  const family = await db.prepare("SELECT id,approval_required,experience FROM families WHERE id=?").bind(familyId).first();
  if (!family) throw new Error("family_not_found");
  const createdAt = ts();
  // No approval required: the user joins the family directly.
  if (Number(family.approval_required ?? 1) === 0) {
    await enforceFamilyMemberLimit(db, family);
    await db.prepare(
      "INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,'member',?)"
    ).bind(familyId, userId, createdAt).run();
    await familyAutoBornPost(db, familyId, userId);
    return { ok: true, joined: true };
  }
  await db.prepare(
    `INSERT INTO family_join_requests(family_id,user_id,status,created_at,updated_at)
     VALUES(?,?,'pending',?,?)
     ON CONFLICT(family_id,user_id) DO UPDATE SET status='pending',updated_at=excluded.updated_at`
  ).bind(familyId,userId,createdAt,createdAt).run();
  return { ok: true };
}

export async function familyResolveJoin(db, actorId, targetId, approve) {
  await ensureTinniSocialSchema(db);
  const actor = await familyMembership(db, actorId);
  if (!actor || !["leader","admin"].includes(String(actor.role))) throw new Error("family_admin_required");
  const request = await db.prepare(
    "SELECT 1 AS ok FROM family_join_requests WHERE family_id=? AND user_id=? AND status='pending'"
  ).bind(actor.family_id,targetId).first();
  if (!request) throw new Error("family_join_request_not_found");
  const updatedAt = ts();
  const statements = [
    db.prepare(
      "UPDATE family_join_requests SET status=?,updated_at=? WHERE family_id=? AND user_id=?"
    ).bind(approve ? "approved" : "rejected",updatedAt,actor.family_id,targetId),
  ];
  if (approve) {
    if (await familyMembership(db, targetId)) throw new Error("already_in_family");
    const family = await db.prepare("SELECT id,experience FROM families WHERE id=?").bind(actor.family_id).first();
    if (family) await enforceFamilyMemberLimit(db, family);
    statements.push(
      db.prepare(
        "INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,'member',?)"
      ).bind(actor.family_id,targetId,updatedAt)
    );
  }
  await db.batch(statements);
  if (approve) await familyAutoBornPost(db, actor.family_id, targetId);
  return { ok: true, approved: Boolean(approve) };
}

// Member limit (Family Rules, Mr. Wrong 2026-11-24): a family can hold
// only familyMemberLimit(level) members — Lv.1 60 ... Lv.50 495.
async function enforceFamilyMemberLimit(db, family) {
  const level = familyLevel(Number(family.experience ?? 0)).level;
  const count = await db.prepare(
    "SELECT COUNT(*) AS total FROM family_members WHERE family_id=?"
  ).bind(family.id).first();
  if (Number(count?.total ?? 0) >= familyMemberLimit(level)) {
    throw new Error("family_full");
  }
}

export async function familySetAdmin(db, actorId, targetId, admin) {
  const actor = await familyMembership(db, actorId);
  const target = await familyMembership(db, targetId);
  if (!actor || actor.role !== "leader") throw new Error("family_leader_required");
  if (!target || target.family_id !== actor.family_id || target.role === "leader") {
    throw new Error("invalid_family_member");
  }
  if (admin && target.role !== "admin") {
    // Deputy limit (Family Rules, Mr. Wrong 2026-11-24): the leader can
    // appoint only familyDeputyLimit(level) deputies — Lv.1-5: 3 ... Lv.30+: 18.
    const family = await db.prepare("SELECT experience FROM families WHERE id=?").bind(actor.family_id).first();
    const level = familyLevel(Number(family?.experience ?? 0)).level;
    const count = await db.prepare(
      "SELECT COUNT(*) AS total FROM family_members WHERE family_id=? AND role='admin'"
    ).bind(actor.family_id).first();
    if (Number(count?.total ?? 0) >= familyDeputyLimit(level)) {
      throw new Error("family_deputy_limit");
    }
  }
  await db.prepare(
    "UPDATE family_members SET role=? WHERE family_id=? AND user_id=?"
  ).bind(admin ? "admin" : "member",actor.family_id,targetId).run();
  return { ok: true, role: admin ? "admin" : "member" };
}

export async function familyRemoveMember(db, actorId, targetId) {
  const actor = await familyMembership(db, actorId);
  const target = await familyMembership(db, targetId);
  if (!actor || !target || actor.family_id !== target.family_id) throw new Error("invalid_family_member");
  const allowed = actor.role === "leader"
    ? target.role !== "leader"
    : actor.role === "admin" && target.role === "member";
  if (!allowed) throw new Error("family_permission_required");
  await db.prepare(
    "DELETE FROM family_members WHERE family_id=? AND user_id=?"
  ).bind(actor.family_id,targetId).run();
  // Being removed clears the user's personal family EXP.
  await clearFamilyPersonalExp(db, actor.family_id, targetId);
  return { ok: true };
}

export async function familyLeave(db, userId) {
  const member = await familyMembership(db, userId);
  if (!member) return { ok: true };
  if (member.role === "leader") {
    // Family Rules (Mr. Wrong, 2026-11-24): the leader can only leave
    // when they are the only person left in the family — then the family
    // is disbanded.
    const count = await db.prepare(
      "SELECT COUNT(*) AS total FROM family_members WHERE family_id=?"
    ).bind(member.family_id).first();
    if (Number(count?.total ?? 0) > 1) throw new Error("family_leader_cannot_leave");
    await db.batch([
      db.prepare("DELETE FROM family_members WHERE family_id=?").bind(member.family_id),
      db.prepare("DELETE FROM family_daily_logins WHERE family_id=?").bind(member.family_id),
      db.prepare("DELETE FROM family_member_monthly WHERE family_id=?").bind(member.family_id),
      db.prepare("DELETE FROM family_task_progress WHERE family_id=?").bind(member.family_id),
      db.prepare("DELETE FROM family_posts WHERE family_id=?").bind(member.family_id),
      db.prepare("DELETE FROM family_monthly_exp WHERE family_id=?").bind(member.family_id),
      db.prepare("DELETE FROM families WHERE id=?").bind(member.family_id),
    ]);
    return { ok: true, disbanded: true };
  }
  await db.prepare(
    "DELETE FROM family_members WHERE family_id=? AND user_id=?"
  ).bind(member.family_id,userId).run();
  // Leaving clears the user's personal family EXP.
  await clearFamilyPersonalExp(db, member.family_id, userId);
  return { ok: true };
}

export async function familyUpdateNotice(db, userId, noticeValue) {
  const member = await familyMembership(db, userId);
  if (!member || !["leader","admin"].includes(String(member.role))) {
    throw new Error("family_admin_required");
  }
  const notice = clean(noticeValue, 300);
  await db.prepare(
    "UPDATE families SET notice=?,updated_at=? WHERE id=?"
  ).bind(notice,ts(),member.family_id).run();
  return { ok: true, notice };
}

export async function familyCheckIn(db, userId) {
  const member = await familyMembership(db, userId);
  if (!member) throw new Error("join_family_first");
  const dayKey = new Date().toISOString().slice(0,10);
  const existing = await db.prepare(
    "SELECT exp_awarded FROM family_daily_logins WHERE family_id=? AND user_id=? AND day_key=?"
  ).bind(member.family_id,userId,dayKey).first();
  if (existing) return { ok: true, already_checked_in: true, exp_awarded: Number(existing.exp_awarded ?? 0) };
  // Daily sign-in task (Family Rules, Mr. Wrong 2026-11-24): 405,000
  // family EXP + 8,100 coins to the user, once a day. The other app's
  // 270,000 EXP / 5,400 coins x1.5.
  const exp = FAMILY_TASK_REWARDS.signIn.exp;
  const coins = FAMILY_TASK_REWARDS.signIn.coins;
  const createdAt = ts();
  const wallet = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
  await db.batch([
    db.prepare(
      "INSERT INTO family_daily_logins(family_id,user_id,day_key,exp_awarded,created_at) VALUES(?,?,?,?,?)"
    ).bind(member.family_id,userId,dayKey,exp,createdAt),
    db.prepare(
      "UPDATE families SET experience=experience+?,updated_at=? WHERE id=?"
    ).bind(exp,createdAt,member.family_id),
    db.prepare(
      "INSERT INTO family_monthly_exp(family_id,month_key,exp) VALUES(?,?,?) ON CONFLICT(family_id,month_key) DO UPDATE SET exp=exp+excluded.exp"
    ).bind(member.family_id,familyMonthKey(),exp),
    db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?").bind(coins,createdAt,userId),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(uid("ledger-"),userId,"family_task",coins,Number(wallet?.coins ?? 0)+coins,"sign-in-task",createdAt),
  ]);
  return { ok: true, already_checked_in: false, exp_awarded: exp, coins_awarded: coins };
}

export async function familyTransferCoins(db, senderId, receiverId, coinsValue) {
  await ensureTinniSocialSchema(db);
  const amount = Math.floor(Number(coinsValue ?? 0));
  if (!Number.isSafeInteger(amount) || amount <= 0) throw new Error("invalid_coin_amount");
  if (!senderId || !receiverId || senderId === receiverId) throw new Error("invalid_family_member");
  const sender = await familyMembership(db, senderId);
  const receiver = await familyMembership(db, receiverId);
  if (!sender || !receiver || String(sender.family_id) !== String(receiver.family_id)) {
    throw new Error("family_member_required");
  }
  const transferId = uid("family-transfer-");
  const createdAt = ts();

  await db.batch([
    db.prepare(
      `INSERT INTO family_wallet_transfers(
        id,family_id,sender_user_id,receiver_user_id,coins,created_at
      )
      SELECT ?,?,?,?,?,?
       WHERE EXISTS(SELECT 1 FROM users WHERE id=? AND coins>=?)`
    ).bind(
      transferId,sender.family_id,senderId,receiverId,amount,createdAt,
      senderId,amount,
    ),
    db.prepare(
      "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM family_wallet_transfers WHERE id=?)"
    ).bind(amount,createdAt,senderId,transferId),
    db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM family_wallet_transfers WHERE id=?)"
    ).bind(amount,createdAt,receiverId,transferId),
    db.prepare(
      `INSERT INTO wallet_ledger(
        id,user_id,kind,amount,balance_after,reference_id,created_at
      )
      SELECT ?,u.id,'family_send',?,u.coins,?,?
        FROM users u
       WHERE u.id=? AND EXISTS(SELECT 1 FROM family_wallet_transfers WHERE id=?)`
    ).bind(uid(),-amount,transferId,createdAt,senderId,transferId),
    db.prepare(
      `INSERT INTO wallet_ledger(
        id,user_id,kind,amount,balance_after,reference_id,created_at
      )
      SELECT ?,u.id,'family_receive',?,u.coins,?,?
        FROM users u
       WHERE u.id=? AND EXISTS(SELECT 1 FROM family_wallet_transfers WHERE id=?)`
    ).bind(uid(),amount,transferId,createdAt,receiverId,transferId),
  ]);

  const created = await db.prepare(
    "SELECT id FROM family_wallet_transfers WHERE id=? LIMIT 1"
  ).bind(transferId).first();
  if (!created) throw new Error("insufficient_coins");
  // Family EXP (1:1 on the transfer) goes through the engine so monthly
  // EXP and level-up vault rewards apply too.
  await addFamilyExp(db, sender.family_id, amount);
  const balance = await db.prepare(
    "SELECT coins FROM users WHERE id=? LIMIT 1"
  ).bind(senderId).first();
  const family = await db.prepare(
    "SELECT experience FROM families WHERE id=? LIMIT 1"
  ).bind(sender.family_id).first();
  return {
    ok: true,
    transfer_id: transferId,
    receiver_user_id: receiverId,
    coins: amount,
    coin_balance: Number(balance?.coins ?? 0),
    family_experience: Number(family?.experience ?? 0),
    family_level: familyLevel(family?.experience ?? 0),
  };
}

export async function familyWalletTransfers(db, userId, limitValue = 100) {
  await ensureTinniSocialSchema(db);
  const membership = await familyMembership(db, userId);
  if (!membership) return [];
  const limit = Math.max(1, Math.min(200, Math.floor(Number(limitValue) || 100)));
  const rows = await db.prepare(
    `SELECT t.id,t.sender_user_id,t.receiver_user_id,t.coins,t.created_at,
            su.display_name AS sender_name,su.avatar_key AS sender_avatar_key,
            su.public_id AS sender_public_id,
            ru.display_name AS receiver_name,ru.avatar_key AS receiver_avatar_key,
            ru.public_id AS receiver_public_id
       FROM family_wallet_transfers t
       JOIN users su ON su.id=t.sender_user_id
       JOIN users ru ON ru.id=t.receiver_user_id
      WHERE t.family_id=?
      ORDER BY t.created_at DESC
      LIMIT ?`
  ).bind(membership.family_id,limit).all();
  return rows.results ?? [];
}

// ---------------------------------------------------------------------------
// Family Rules engine (Mr. Wrong, 2026-11-24): EXP, levels, tasks, monthly
// rankings, vault rewards, Trends. Every number is the other app's x1.5
// (see family_rules.js).
// ---------------------------------------------------------------------------

export function familyMonthKey(date = new Date()) {
  return date.toISOString().slice(0, 7);
}

function familyDayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

// Add EXP to a family (lifetime + this month). On a level-up the vault
// receives the level-up reward (familyUpgradeVaultReward) and the reward
// is recorded in the vault history. Returns the new level info.
export async function addFamilyExp(db, familyId, exp, monthKey = familyMonthKey()) {
  const amount = Math.max(0, Math.floor(Number(exp ?? 0)));
  if (amount <= 0) {
    const row = await db.prepare("SELECT experience FROM families WHERE id=?").bind(familyId).first();
    return { level: familyLevel(row?.experience ?? 0).level, leveled_up: false, reward_coins: 0 };
  }
  const before = await db.prepare("SELECT experience FROM families WHERE id=?").bind(familyId).first();
  const beforeExp = Number(before?.experience ?? 0);
  const beforeLevel = familyLevel(beforeExp).level;
  const now = ts();
  await db.batch([
    db.prepare("UPDATE families SET experience=experience+?,updated_at=? WHERE id=?")
      .bind(amount, now, familyId),
    db.prepare(
      `INSERT INTO family_monthly_exp(family_id,month_key,exp) VALUES(?,?,?)
       ON CONFLICT(family_id,month_key) DO UPDATE SET exp=exp+excluded.exp`
    ).bind(familyId, monthKey, amount),
  ]);
  const afterLevel = familyLevel(beforeExp + amount).level;
  let rewardCoins = 0;
  if (afterLevel > beforeLevel) {
    for (let level = beforeLevel + 1; level <= afterLevel; level += 1) {
      rewardCoins += familyUpgradeVaultReward(level);
    }
    if (rewardCoins > 0) {
      await db.batch([
        db.prepare("UPDATE families SET wallet_coins=wallet_coins+?,updated_at=? WHERE id=?")
          .bind(rewardCoins, now, familyId),
        db.prepare(
          "INSERT INTO family_vault_history(id,family_id,kind,detail,coins,created_at) VALUES(?,?,?,?,?,?)"
        ).bind(uid("vault-"), familyId, "level_up", `Reached Lv.${afterLevel}`, rewardCoins, now),
      ]);
    }
  }
  return { level: afterLevel, leveled_up: afterLevel > beforeLevel, reward_coins: rewardCoins };
}

async function recordMemberMonthly(db, familyId, userId, monthKey, delta = {}) {
  const given = Math.max(0, Math.floor(Number(delta.given ?? 0)));
  const received = Math.max(0, Math.floor(Number(delta.received ?? 0)));
  const minutes = Math.max(0, Math.floor(Number(delta.minutes ?? 0)));
  if (!given && !received && !minutes) return;
  await db.prepare(
    `INSERT INTO family_member_monthly(family_id,user_id,month_key,given_exp,received_exp,active_minutes)
     VALUES(?,?,?,?,?,?)
     ON CONFLICT(family_id,user_id,month_key) DO UPDATE SET
       given_exp=given_exp+excluded.given_exp,
       received_exp=received_exp+excluded.received_exp,
       active_minutes=active_minutes+excluded.active_minutes`
  ).bind(familyId, userId, monthKey, given, received, minutes).run();
}

// Gift EXP (called best-effort from the gift send flow, after the gift is
// committed — a failure here must never fail the paid send). Giving gifts
// earns the SENDER's family 1 EXP per coin (x2 when giver and receiver
// are in the same family); receiving earns the RECEIVER's family the
// same. Lucky (and rebate) gifts only count 10%.
export async function awardFamilyGiftExp(db, senderId, receiverId, coins, giftCategory) {
  await ensureTinniSocialSchema(db);
  const sender = await familyMembership(db, senderId);
  const receiver = await familyMembership(db, receiverId);
  if (!sender && !receiver) return { ok: true, awarded: false };
  const sameFamily = Boolean(
    sender && receiver && String(sender.family_id) === String(receiver.family_id),
  );
  const exp = familyGiftExp(coins, sameFamily, giftCategory);
  if (exp <= 0) return { ok: true, awarded: false };
  const monthKey = familyMonthKey();
  if (sender) {
    await addFamilyExp(db, sender.family_id, exp, monthKey);
    await recordMemberMonthly(db, sender.family_id, senderId, monthKey, { given: exp });
  }
  if (receiver) {
    await addFamilyExp(db, receiver.family_id, exp, monthKey);
    await recordMemberMonthly(db, receiver.family_id, receiverId, monthKey, { received: exp });
  }
  return { ok: true, awarded: true, exp };
}

// Game EXP: 100 coins bet = 1 EXP for the bettor's family.
export async function awardFamilyGameExp(db, userId, coins) {
  await ensureTinniSocialSchema(db);
  const member = await familyMembership(db, userId);
  if (!member) return { ok: true, awarded: false };
  const exp = familyGameExp(coins);
  if (exp <= 0) return { ok: true, awarded: false };
  await addFamilyExp(db, member.family_id, exp);
  return { ok: true, awarded: true, exp };
}

// Leaving / being removed clears the user's PERSONAL family EXP (Mr.
// Wrong, 2026-11-24): their daily check-ins, monthly contributions and
// task progress in that family are deleted. The family's lifetime EXP
// itself is not reduced.
export async function clearFamilyPersonalExp(db, familyId, userId) {
  await db.batch([
    db.prepare("DELETE FROM family_daily_logins WHERE family_id=? AND user_id=?").bind(familyId, userId),
    db.prepare("DELETE FROM family_member_monthly WHERE family_id=? AND user_id=?").bind(familyId, userId),
    db.prepare("DELETE FROM family_task_progress WHERE family_id=? AND user_id=?").bind(familyId, userId),
  ]);
  return { ok: true };
}

// Daily task status for today: sign-in done?, stay/mic minutes + awarded?.
export async function familyTaskStatus(db, userId) {
  await ensureTinniSocialSchema(db);
  const member = await familyMembership(db, userId);
  if (!member) throw new Error("not_in_family");
  const dayKey = familyDayKey();
  const checkIn = await db.prepare(
    "SELECT exp_awarded FROM family_daily_logins WHERE family_id=? AND user_id=? AND day_key=?"
  ).bind(member.family_id, userId, dayKey).first();
  const progress = await db.prepare(
    "SELECT kind,minutes,awarded FROM family_task_progress WHERE family_id=? AND user_id=? AND day_key=?"
  ).bind(member.family_id, userId, dayKey).all();
  const byKind = {};
  for (const row of progress.results ?? []) {
    byKind[String(row.kind)] = { minutes: Number(row.minutes ?? 0), awarded: Number(row.awarded ?? 0) === 1 };
  }
  return {
    ok: true,
    signed_in: Boolean(checkIn),
    sign_in_exp: Number(checkIn?.exp_awarded ?? 0),
    stay: byKind.stay ?? { minutes: 0, awarded: false },
    mic: byKind.mic ?? { minutes: 0, awarded: false },
  };
}

// Room stay / mic task (Mr. Wrong, 2026-11-24): minutes only count while
// the user is inside a family room — a voice room whose owner is a member
// of the user's family. Minutes accumulate through the day; reaching the
// threshold (stay 20 min, mic 10 min) awards the task EXP + coins once.
export async function familyTaskProgress(db, userId, kind, minutesValue) {
  await ensureTinniSocialSchema(db);
  const kindValue = kind === "mic" ? "mic" : "stay";
  const minutes = Math.max(0, Math.min(600, Math.floor(Number(minutesValue ?? 0))));
  if (minutes <= 0) throw new Error("invalid_minutes");
  const member = await familyMembership(db, userId);
  if (!member) throw new Error("not_in_family");
  // The user must be inside a family room right now.
  const room = await db.prepare(
    `SELECT r.owner_user_id AS owner
       FROM room_members rm JOIN rooms r ON r.id=rm.room_id
      WHERE rm.user_id=? LIMIT 1`
  ).bind(userId).first();
  if (!room) throw new Error("not_in_family_room");
  const ownerMember = await db.prepare(
    "SELECT 1 AS yes FROM family_members WHERE family_id=? AND user_id=? LIMIT 1"
  ).bind(member.family_id, String(room.owner)).first();
  if (!ownerMember) throw new Error("not_in_family_room");
  const dayKey = familyDayKey();
  const threshold = kindValue === "mic" ? 10 : 20;
  const reward = kindValue === "mic" ? FAMILY_TASK_REWARDS.mic10 : FAMILY_TASK_REWARDS.stay20;
  const existing = await db.prepare(
    "SELECT minutes,awarded FROM family_task_progress WHERE family_id=? AND user_id=? AND day_key=? AND kind=?"
  ).bind(member.family_id, userId, dayKey, kindValue).first();
  const totalMinutes = Number(existing?.minutes ?? 0) + minutes;
  const alreadyAwarded = Number(existing?.awarded ?? 0) === 1;
  const now = ts();
  await db.prepare(
    `INSERT INTO family_task_progress(family_id,user_id,day_key,kind,minutes,awarded)
     VALUES(?,?,?,?,?,?)
     ON CONFLICT(family_id,user_id,day_key,kind) DO UPDATE SET minutes=excluded.minutes`
  ).bind(member.family_id, userId, dayKey, kindValue, totalMinutes, alreadyAwarded ? 1 : 0).run();
  let awardedNow = false;
  if (!alreadyAwarded && totalMinutes >= threshold) {
    await db.prepare(
      "UPDATE family_task_progress SET awarded=1 WHERE family_id=? AND user_id=? AND day_key=? AND kind=?"
    ).bind(member.family_id, userId, dayKey, kindValue).run();
    await addFamilyExp(db, member.family_id, reward.exp);
    await recordMemberMonthly(db, member.family_id, userId, familyMonthKey(), { minutes: totalMinutes });
    const wallet = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
    await db.batch([
      db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?").bind(reward.coins, now, userId),
      db.prepare(
        "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
      ).bind(uid("ledger-"), userId, "family_task", reward.coins, Number(wallet?.coins ?? 0) + reward.coins, `${kindValue}-task`, now),
    ]);
    awardedNow = true;
  }
  return {
    ok: true,
    kind: kindValue,
    minutes: totalMinutes,
    threshold,
    awarded: alreadyAwarded || awardedNow,
    awarded_now: awardedNow,
    exp_awarded: awardedNow ? reward.exp : 0,
    coins_awarded: awardedNow ? reward.coins : 0,
  };
}

// Monthly ranking inside one family: Charm Star = gifts RECEIVED this
// month, Wealth Star = gifts GIVEN this month, Active Star = minutes in
// the family room this month. Settles on the 1st of each month.
export async function familyMonthlyRanking(db, familyId, kind) {
  await ensureTinniSocialSchema(db);
  const family = await db.prepare("SELECT id FROM families WHERE id=?").bind(familyId).first();
  if (!family) throw new Error("family_not_found");
  const kindValue = kind === "wealth" ? "wealth" : kind === "active" ? "active" : "charm";
  const column = kindValue === "wealth" ? "given_exp" : kindValue === "active" ? "active_minutes" : "received_exp";
  const monthKey = familyMonthKey();
  const rows = await db.prepare(
    `SELECT m.user_id,m.given_exp,m.received_exp,m.active_minutes,
            fm.role,fm.joined_at,u.display_name,u.avatar_key,
            CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS public_id
       FROM family_member_monthly m
       JOIN family_members fm ON fm.family_id=m.family_id AND fm.user_id=m.user_id
       JOIN users u ON u.id=m.user_id
       LEFT JOIN owner_user_overrides io ON io.user_id=m.user_id
      WHERE m.family_id=? AND m.month_key=?
      ORDER BY m.${column} DESC, m.user_id ASC
      LIMIT 100`
  ).bind(familyId, monthKey).all();
  return {
    ok: true,
    kind: kindValue,
    month_key: monthKey,
    members: (rows.results ?? []).map((row, index) => ({
      rank: index + 1,
      user_id: String(row.user_id),
      display_name: String(row.display_name ?? ""),
      avatar_key: row.avatar_key ?? "",
      public_id: row.public_id ?? "",
      role: String(row.role ?? "member"),
      given_exp: Number(row.given_exp ?? 0),
      received_exp: Number(row.received_exp ?? 0),
      active_minutes: Number(row.active_minutes ?? 0),
      value: Number(row[column] ?? 0),
    })),
  };
}

// Top member of each star for the family HOME tab.
export async function familyTopMembers(db, familyId) {
  const top = {};
  for (const kind of ["charm", "wealth", "active"]) {
    const ranking = await familyMonthlyRanking(db, familyId, kind);
    top[kind] = ranking.members[0] ?? null;
  }
  return top;
}

// The family's room: the leader's voice room (if the leader owns one),
// with how many family members are inside right now.
export async function familyRoomFor(db, familyId) {
  await ensureTinniSocialSchema(db);
  const family = await db.prepare("SELECT leader_user_id FROM families WHERE id=?").bind(familyId).first();
  if (!family) return null;
  const room = await db.prepare(
    `SELECT r.id,r.name,r.owner_user_id,r.seat_count,
            (SELECT COUNT(*) FROM room_members rm WHERE rm.room_id=r.id) AS live_count,
            (SELECT COUNT(*) FROM room_members rm
               JOIN family_members fm ON fm.user_id=rm.user_id AND fm.family_id=?
              WHERE rm.room_id=r.id) AS family_live_count
       FROM rooms r WHERE r.owner_user_id=? ORDER BY r.created_at DESC LIMIT 1`
  ).bind(familyId, String(family.leader_user_id)).first();
  if (!room) return null;
  return {
    id: String(room.id),
    name: String(room.name ?? ""),
    owner_user_id: String(room.owner_user_id ?? ""),
    seat_count: Number(room.seat_count ?? 0),
    live_count: Number(room.live_count ?? 0),
    family_live_count: Number(room.family_live_count ?? 0),
  };
}

// Public family detail page data (HOME tab): header, EXP card, rank,
// announcement, top members, member avatars, family room, vault (members
// only), today's check-ins.
export async function familyDetail(db, familyId, viewerUserId) {
  await ensureTinniSocialSchema(db);
  const family = await db.prepare(
    `SELECT f.id,f.name,f.tag,f.notice,f.leader_user_id,f.experience,
            f.wallet_coins,f.logo_key,f.approval_required,f.created_at,
            u.display_name AS leader_name,u.avatar_key AS leader_avatar_key
       FROM families f LEFT JOIN users u ON u.id=f.leader_user_id
      WHERE f.id=?`
  ).bind(familyId).first();
  if (!family) throw new Error("family_not_found");
  const experience = Number(family.experience ?? 0);
  const levelInfo = familyLevel(experience);
  const monthKey = familyMonthKey();
  const monthly = await db.prepare(
    "SELECT exp FROM family_monthly_exp WHERE family_id=? AND month_key=?"
  ).bind(familyId, monthKey).first();
  const monthlyExp = Number(monthly?.exp ?? 0);
  const rankInfo = familyRankForMonthlyExp(monthlyExp);
  const members = await db.prepare(
    `SELECT fm.user_id,fm.role,fm.joined_at,u.display_name,u.avatar_key,
            CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS public_id,
            COALESCE((
              SELECT SUM(t.coins)
                FROM family_wallet_transfers t
               WHERE t.family_id=fm.family_id
                 AND t.receiver_user_id=fm.user_id
            ),0) AS received_coins,
            (SELECT MAX(d.last_seen_at) FROM owner_user_devices d WHERE d.user_id=fm.user_id) AS last_seen_at
       FROM family_members fm JOIN users u ON u.id=fm.user_id
       LEFT JOIN owner_user_overrides io ON io.user_id=fm.user_id
      WHERE fm.family_id=?
      ORDER BY CASE fm.role WHEN 'leader' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
               fm.joined_at ASC`
  ).bind(familyId).all();
  const memberRows = members.results ?? [];
  const dayKey = familyDayKey();
  const checkIns = await db.prepare(
    "SELECT COUNT(*) AS total FROM family_daily_logins WHERE family_id=? AND day_key=?"
  ).bind(familyId, dayKey).first();
  const viewer = viewerUserId ? await familyMembership(db, viewerUserId) : null;
  const isMember = Boolean(viewer && String(viewer.family_id) === String(familyId));
  const myContribution = await db.prepare(
    "SELECT COALESCE(SUM(exp_awarded),0) AS total FROM family_daily_logins WHERE family_id=? AND user_id=?"
  ).bind(familyId, viewerUserId ?? "").first();
  const topMembers = await familyTopMembers(db, familyId);
  const room = await familyRoomFor(db, familyId);
  // Join requests (Mr. Wrong, 2026-11-24): the members page shows them
  // too, exactly like the Management page — but only to the leader and
  // admins of this family, never to plain members or outsiders.
  let joinRequests = [];
  if (isMember && (viewer.role === "leader" || viewer.role === "admin")) {
    const requests = await db.prepare(
      `SELECT r.user_id,r.created_at,u.display_name,u.avatar_key
         FROM family_join_requests r JOIN users u ON u.id=r.user_id
        WHERE r.family_id=? AND r.status='pending'
        ORDER BY r.created_at ASC`
    ).bind(familyId).all();
    joinRequests = requests.results ?? [];
  }
  return {
    ok: true,
    family: {
      id: String(family.id),
      name: String(family.name ?? ""),
      tag: String(family.tag ?? ""),
      notice: String(family.notice ?? ""),
      leader_user_id: String(family.leader_user_id ?? ""),
      leader_name: String(family.leader_name ?? ""),
      leader_avatar_key: family.leader_avatar_key ?? "",
      experience,
      level: levelInfo.level,
      next_exp: levelInfo.next_exp,
      level_band: familyLevelBand(levelInfo.level),
      monthly_exp: monthlyExp,
      rank: rankInfo.rank,
      rank_progress: rankInfo.progress,
      rank_need: rankInfo.need,
      rank_next: rankInfo.next_rank,
      wallet_coins: isMember ? Number(family.wallet_coins ?? 0) : null,
      logo_key: family.logo_key ?? "",
      approval_required: Number(family.approval_required ?? 1),
      member_count: memberRows.length,
      check_ins_today: Number(checkIns?.total ?? 0),
      my_contributed_exp: Number(myContribution?.total ?? 0),
      is_member: isMember,
      my_role: isMember ? String(viewer.role) : null,
    },
    top_members: topMembers,
    members: memberRows.map((row) => ({
      user_id: String(row.user_id),
      role: String(row.role ?? "member"),
      display_name: String(row.display_name ?? ""),
      avatar_key: row.avatar_key ?? "",
      public_id: row.public_id ?? "",
      joined_at: Number(row.joined_at ?? 0),
      received_coins: Number(row.received_coins ?? 0),
      last_seen_at: Number(row.last_seen_at ?? 0),
    })),
    join_requests: joinRequests.map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name ?? ""),
      avatar_key: row.avatar_key ?? "",
      created_at: Number(row.created_at ?? 0),
    })),
    room,
  };
}

// Monthly settlement (runs on the 1st of each month, 03:00 UTC job): the
// top-10 families of the LAST month by monthly EXP receive their vault
// coins. Idempotent per (family, month) via family_monthly_rewards.
export async function settleFamilyMonthly(db, monthKey) {
  await ensureTinniSocialSchema(db);
  const key = String(monthKey ?? "").trim();
  if (!/^\d{4}-\d{2}$/.test(key)) throw new Error("invalid_month_key");
  const rows = await db.prepare(
    `SELECT family_id,exp FROM family_monthly_exp
      WHERE month_key=? ORDER BY exp DESC, family_id ASC LIMIT 10`
  ).bind(key).all();
  const settled = [];
  const now = ts();
  for (const [index, row] of (rows.results ?? []).entries()) {
    const rank = index + 1;
    const reward = familyMonthlyVaultReward(rank);
    if (reward <= 0) continue;
    const familyId = String(row.family_id);
    const existing = await db.prepare(
      "SELECT id FROM family_monthly_rewards WHERE family_id=? AND month_key=?"
    ).bind(familyId, key).first();
    if (existing) continue;
    await db.batch([
      db.prepare(
        "INSERT INTO family_monthly_rewards(id,family_id,month_key,rank_value,vault_coins,created_at) VALUES(?,?,?,?,?,?)"
      ).bind(uid("monthly-reward-"), familyId, key, rank, reward, now),
      db.prepare("UPDATE families SET wallet_coins=wallet_coins+?,updated_at=? WHERE id=?")
        .bind(reward, now, familyId),
      db.prepare(
        "INSERT INTO family_vault_history(id,family_id,kind,detail,coins,created_at) VALUES(?,?,?,?,?,?)"
      ).bind(uid("vault-"), familyId, "monthly_rank", `Monthly rank No.${rank} (${key})`, reward, now),
    ]);
    settled.push({ family_id: familyId, rank, vault_coins: reward });
  }
  return { ok: true, month_key: key, settled };
}

export async function familyVaultHistory(db, familyId, limitValue = 50) {
  await ensureTinniSocialSchema(db);
  const limit = Math.max(1, Math.min(100, Math.floor(Number(limitValue) || 50)));
  const rows = await db.prepare(
    `SELECT id,kind,detail,coins,created_at FROM family_vault_history
      WHERE family_id=? ORDER BY created_at DESC LIMIT ?`
  ).bind(familyId, limit).all();
  return rows.results ?? [];
}

// ---------------------------------------------------------------------------
// Family Weekly Rewards (Mr. Wrong, 2026-11-24): "Send gifts and win
// rewards!" The week runs Monday 00:00 to Sunday 23:59 in UTC+3 (the
// other app's timezone). Weekly gifting = coins of gifts SENT by family
// members in the week (gift_events). Tiers 148.5M / 315M / 765M (other
// app's 99M / 210M / 510M x1.5).
// ---------------------------------------------------------------------------

// Monday 00:00 UTC+3 bounds for the week containing `date`. week_key is
// the Monday date (YYYY-MM-DD, UTC+3).
export function familyWeekBounds(date = new Date()) {
  const utc3 = new Date(date.getTime() + 3 * 3600 * 1000);
  const daysSinceMonday = (utc3.getUTCDay() + 6) % 7;
  const mondayUtc3 = new Date(Date.UTC(
    utc3.getUTCFullYear(), utc3.getUTCMonth(), utc3.getUTCDate() - daysSinceMonday,
  ));
  const startMs = mondayUtc3.getTime() - 3 * 3600 * 1000;
  return {
    startMs,
    endMs: startMs + 7 * 24 * 3600 * 1000,
    weekKey: mondayUtc3.toISOString().slice(0, 10),
  };
}

// Weekly gifting of one family: total + per-member ranking, for the week
// starting at startMs (inclusive) and ending at endMs (exclusive).
async function familyWeeklyTotals(db, familyId, startMs, endMs) {
  const members = await db.prepare(
    `SELECT fm.user_id,u.display_name,u.avatar_key,fm.role
       FROM family_members fm JOIN users u ON u.id=fm.user_id
      WHERE fm.family_id=?`
  ).bind(familyId).all();
  const memberRows = members.results ?? [];
  const memberIds = new Set(memberRows.map((row) => String(row.user_id)));
  const gifts = await db.prepare(
    `SELECT sender_user_id AS user_id,SUM(coin_cost) AS total
       FROM gift_events WHERE created_at>=? AND created_at<?
      GROUP BY sender_user_id`
  ).bind(startMs, endMs).all();
  const byUser = new Map();
  for (const row of gifts.results ?? []) {
    const userId = String(row.user_id);
    if (memberIds.has(userId)) byUser.set(userId, Number(row.total ?? 0));
  }
  const ranking = memberRows
    .map((row) => ({
      user_id: String(row.user_id),
      display_name: String(row.display_name ?? ""),
      avatar_key: row.avatar_key ?? "",
      role: String(row.role ?? "member"),
      weekly_gifts: byUser.get(String(row.user_id)) ?? 0,
    }))
    .sort((a, b) => b.weekly_gifts - a.weekly_gifts || String(a.user_id).localeCompare(String(b.user_id)))
    .map((row, index) => ({ ...row, rank: index + 1 }));
  return {
    total: ranking.reduce((sum, row) => sum + row.weekly_gifts, 0),
    ranking,
  };
}

export async function familyWeeklyState(db, familyId, viewerUserId) {
  await ensureTinniSocialSchema(db);
  const family = await db.prepare(
    "SELECT id,name,leader_user_id FROM families WHERE id=?"
  ).bind(familyId).first();
  if (!family) throw new Error("family_not_found");
  const now = new Date();
  const current = familyWeekBounds(now);
  const last = familyWeekBounds(new Date(current.startMs - 1));
  const thisPeriod = await familyWeeklyTotals(db, familyId, current.startMs, current.endMs);
  const lastPeriod = await familyWeeklyTotals(db, familyId, last.startMs, last.endMs);
  const tierIndex = familyWeeklyTierForTotal(thisPeriod.total);
  const nextTier = FAMILY_WEEKLY_TIERS[tierIndex + 1] ?? null;
  const me = thisPeriod.ranking.find((row) => String(row.user_id) === String(viewerUserId ?? "")) ?? null;
  const settled = await db.prepare(
    "SELECT user_id,kind,rank_value,coins,detail FROM family_weekly_rewards WHERE family_id=? AND week_key=?"
  ).bind(familyId, last.weekKey).all();
  return {
    ok: true,
    family_id: String(family.id),
    family_name: String(family.name ?? ""),
    week_key: current.weekKey,
    week_ends_at: current.endMs,
    server_time: now.getTime(),
    total: thisPeriod.total,
    tier_index: tierIndex,
    tiers: FAMILY_WEEKLY_TIERS.map((tier) => ({
      threshold: tier.threshold,
      leader_coins: tier.leader_coins,
      reached: thisPeriod.total >= tier.threshold,
    })),
    next_tier_threshold: nextTier ? nextTier.threshold : null,
    eligibility_coins: FAMILY_WEEKLY_ELIGIBILITY_COINS,
    this_period: thisPeriod,
    last_period: lastPeriod,
    last_period_week_key: last.weekKey,
    my_rank: me ? me.rank : 0,
    my_weekly_gifts: me ? me.weekly_gifts : 0,
    last_settled: (settled.results ?? []).map((row) => ({
      user_id: String(row.user_id),
      kind: String(row.kind),
      rank_value: Number(row.rank_value ?? 0),
      coins: Number(row.coins ?? 0),
      detail: String(row.detail ?? ""),
    })),
  };
}

// Weekly settlement (runs Monday 03:00 UTC in the daily job — 06:00
// UTC+3, after the week ended): the finished week's tier decides the
// leader coins; the top 15 members by weekly gifting (each over
// 7,200,000 weekly gifts) get their top coins. Coins are credited to
// the users' wallets for real; the 7-day frame/medal/tag/vehicle items
// are recorded as granted display items (no grant system exists yet).
// Idempotent per (family, week, user, kind).
export async function settleFamilyWeekly(db, weekKey) {
  await ensureTinniSocialSchema(db);
  const key = String(weekKey ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) throw new Error("invalid_week_key");
  const monday = new Date(`${key}T00:00:00+03:00`);
  const startMs = monday.getTime();
  const endMs = startMs + 7 * 24 * 3600 * 1000;
  const families = await db.prepare("SELECT id,leader_user_id FROM families").all();
  const settled = [];
  const now = ts();
  for (const family of families.results ?? []) {
    const familyId = String(family.id);
    const leaderId = String(family.leader_user_id ?? "");
    const totals = await familyWeeklyTotals(db, familyId, startMs, endMs);
    if (totals.total <= 0) continue;
    const tierIndex = familyWeeklyTierForTotal(totals.total);
    const record = async (userId, kind, rankValue, coins, detail) => {
      const existing = await db.prepare(
        "SELECT id FROM family_weekly_rewards WHERE family_id=? AND week_key=? AND user_id=? AND kind=?"
      ).bind(familyId, key, userId, kind).first();
      if (existing) return false;
      await db.prepare(
        "INSERT INTO family_weekly_rewards(id,family_id,week_key,user_id,kind,rank_value,coins,detail,created_at) VALUES(?,?,?,?,?,?,?,?,?)"
      ).bind(uid("weekly-reward-"), familyId, key, userId, kind, rankValue, coins, detail, now).run();
      return true;
    };
    const creditCoins = async (userId, coins, kind, reference) => {
      if (coins <= 0) return;
      const wallet = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
      await db.batch([
        db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?").bind(coins, now, userId),
        db.prepare(
          "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
        ).bind(uid("ledger-"), userId, kind, coins, Number(wallet?.coins ?? 0) + coins, reference, now),
      ]);
    };
    if (tierIndex >= 0 && leaderId) {
      const leaderCoins = FAMILY_WEEKLY_TIERS[tierIndex].leader_coins;
      if (await record(leaderId, "leader", 0, leaderCoins, `Weekly tier ${tierIndex + 1}`)) {
        await creditCoins(leaderId, leaderCoins, "family_weekly_leader", `family-weekly:${key}`);
        await record(leaderId, "leader_items", 0, 0, "Super Leader medal (7d) + Bronze Family frame (7d) + Tag-Bronze Family (7d)");
        settled.push({ family_id: familyId, user_id: leaderId, kind: "leader", coins: leaderCoins });
      }
      // Every member gets the Bronze Family frame + tag when any tier
      // is reached (7-day display items, recorded as granted).
      for (const member of totals.ranking) {
        await record(member.user_id, "member_items", 0, 0, "Bronze Family frame (7d) + Tag-Bronze Family (7d)");
      }
    }
    for (const member of totals.ranking.slice(0, 15)) {
      if (member.weekly_gifts <= FAMILY_WEEKLY_ELIGIBILITY_COINS) continue;
      const coins = familyWeeklyTopCoins(member.rank);
      if (coins <= 0) continue;
      if (await record(member.user_id, "top", member.rank, coins, `Weekly top ${member.rank}`)) {
        await creditCoins(member.user_id, coins, "family_weekly_top", `family-weekly:${key}`);
        await record(member.user_id, "top_items", member.rank, 0, "Super Sponsor medal (7d) + Blue star vehicle (7d)");
        settled.push({ family_id: familyId, user_id: member.user_id, kind: "top", rank: member.rank, coins });
      }
    }
  }
  return { ok: true, week_key: key, settled };
}

// Today's Family Lucky Draw Records (Mr. Wrong, 2026-11-24). The wheel
// SPIN is on HOLD (event) — this only reads the records table, which is
// empty until the event is built.
export async function familyLuckyDrawRecords(db, familyId, limitValue = 100) {
  await ensureTinniSocialSchema(db);
  const family = await db.prepare("SELECT id FROM families WHERE id=?").bind(familyId).first();
  if (!family) throw new Error("family_not_found");
  const limit = Math.max(1, Math.min(200, Math.floor(Number(limitValue) || 100)));
  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);
  const rows = await db.prepare(
    `SELECT id,user_id,display_name,coins,created_at FROM family_lucky_draw_records
      WHERE family_id=? AND created_at>=? ORDER BY created_at DESC LIMIT ?`
  ).bind(familyId, dayStart.getTime(), limit).all();
  return (rows.results ?? []).map((row) => ({
    id: String(row.id),
    user_id: String(row.user_id),
    display_name: String(row.display_name ?? ""),
    coins: Number(row.coins ?? 0),
    created_at: Number(row.created_at ?? 0),
  }));
}

// ---------------------------------------------------------------------------
// Family Trends (posts feed on the family detail page).
// ---------------------------------------------------------------------------

async function familyAutoBornPost(db, familyId, userId) {
  const createdAt = ts();
  try {
    await db.prepare(
      "INSERT INTO family_posts(id,family_id,user_id,text,created_at) VALUES(?,?,?,?,?)"
    ).bind(uid("family-post-"), familyId, userId, "I was born!", createdAt).run();
  } catch (_) {
    // Best-effort: a failed auto-post never blocks joining.
  }
}

export async function familyPosts(db, familyId, viewerUserId, limitValue = 50) {
  await ensureTinniSocialSchema(db);
  const family = await db.prepare("SELECT id FROM families WHERE id=?").bind(familyId).first();
  if (!family) throw new Error("family_not_found");
  const limit = Math.max(1, Math.min(100, Math.floor(Number(limitValue) || 50)));
  const rows = await db.prepare(
    `SELECT p.id,p.user_id,p.text,p.created_at,u.display_name,u.avatar_key,
            (SELECT COUNT(*) FROM family_post_likes l WHERE l.post_id=p.id) AS like_count,
            (SELECT COUNT(*) FROM family_post_comments c WHERE c.post_id=p.id) AS comment_count,
            EXISTS(SELECT 1 FROM family_post_likes l WHERE l.post_id=p.id AND l.user_id=?) AS liked_by_me
       FROM family_posts p JOIN users u ON u.id=p.user_id
      WHERE p.family_id=? ORDER BY p.created_at DESC LIMIT ?`
  ).bind(viewerUserId ?? "", familyId, limit).all();
  return (rows.results ?? []).map((row) => ({
    id: String(row.id),
    user_id: String(row.user_id),
    display_name: String(row.display_name ?? ""),
    avatar_key: row.avatar_key ?? "",
    text: String(row.text ?? ""),
    created_at: Number(row.created_at ?? 0),
    like_count: Number(row.like_count ?? 0),
    comment_count: Number(row.comment_count ?? 0),
    liked_by_me: Number(row.liked_by_me ?? 0) === 1,
  }));
}

export async function familyCreatePost(db, userId, textValue) {
  await ensureTinniSocialSchema(db);
  const member = await familyMembership(db, userId);
  if (!member) throw new Error("not_in_family");
  const text = clean(textValue, 500);
  if (text.length < 1) throw new Error("invalid_post_text");
  const hit = checkContent(text);
  if (hit.blocked) throw new Error("content_blocked");
  const createdAt = ts();
  const postId = uid("family-post-");
  await db.prepare(
    "INSERT INTO family_posts(id,family_id,user_id,text,created_at) VALUES(?,?,?,?,?)"
  ).bind(postId, member.family_id, userId, text, createdAt).run();
  return { ok: true, post_id: postId };
}

export async function familyLikePost(db, userId, postId) {
  await ensureTinniSocialSchema(db);
  const post = await db.prepare("SELECT family_id FROM family_posts WHERE id=?").bind(postId).first();
  if (!post) throw new Error("family_post_not_found");
  const member = await familyMembership(db, userId);
  if (!member || String(member.family_id) !== String(post.family_id)) {
    throw new Error("not_in_family");
  }
  const existing = await db.prepare(
    "SELECT 1 AS yes FROM family_post_likes WHERE post_id=? AND user_id=?"
  ).bind(postId, userId).first();
  if (existing) {
    await db.prepare("DELETE FROM family_post_likes WHERE post_id=? AND user_id=?").bind(postId, userId).run();
    return { ok: true, liked: false };
  }
  await db.prepare(
    "INSERT INTO family_post_likes(post_id,user_id,created_at) VALUES(?,?,?)"
  ).bind(postId, userId, ts()).run();
  return { ok: true, liked: true };
}

export async function familyPostComments(db, postId) {
  await ensureTinniSocialSchema(db);
  const post = await db.prepare("SELECT id FROM family_posts WHERE id=?").bind(postId).first();
  if (!post) throw new Error("family_post_not_found");
  const rows = await db.prepare(
    `SELECT c.id,c.user_id,c.text,c.created_at,u.display_name,u.avatar_key
       FROM family_post_comments c JOIN users u ON u.id=c.user_id
      WHERE c.post_id=? ORDER BY c.created_at ASC LIMIT 100`
  ).bind(postId).all();
  return (rows.results ?? []).map((row) => ({
    id: String(row.id),
    user_id: String(row.user_id),
    display_name: String(row.display_name ?? ""),
    avatar_key: row.avatar_key ?? "",
    text: String(row.text ?? ""),
    created_at: Number(row.created_at ?? 0),
  }));
}

export async function familyCommentPost(db, userId, postId, textValue) {
  await ensureTinniSocialSchema(db);
  const post = await db.prepare("SELECT family_id FROM family_posts WHERE id=?").bind(postId).first();
  if (!post) throw new Error("family_post_not_found");
  const member = await familyMembership(db, userId);
  if (!member || String(member.family_id) !== String(post.family_id)) {
    throw new Error("not_in_family");
  }
  const text = clean(textValue, 500);
  if (text.length < 1) throw new Error("invalid_post_text");
  const hit = checkContent(text);
  if (hit.blocked) throw new Error("content_blocked");
  const createdAt = ts();
  const commentId = uid("family-comment-");
  await db.prepare(
    "INSERT INTO family_post_comments(id,post_id,user_id,text,created_at) VALUES(?,?,?,?,?)"
  ).bind(commentId, postId, userId, text, createdAt).run();
  return { ok: true, comment_id: commentId };
}

function relationLevelTarget(levelValue) {
  const level = Math.max(1, Math.floor(Number(levelValue ?? 1)));
  const target = 150000000 + ((level - 1) * 100000000);
  if (!Number.isSafeInteger(target) || target <= 0) {
    throw new Error("relationship_level_target_limit");
  }
  return target;
}

function relationDirectionalProgress(row, userId) {
  const aToB = Math.max(0, Math.floor(Number(row.cycle_a_to_b ?? 0)));
  const bToA = Math.max(0, Math.floor(Number(row.cycle_b_to_a ?? 0)));
  const viewerIsA = String(row.user_a) === String(userId);
  return {
    a_to_b: aToB,
    b_to_a: bToA,
    sending: viewerIsA ? aToB : bToA,
    receiving: viewerIsA ? bToA : aToB,
  };
}

function relationCanLevelUp(level, aToB, bToA) {
  const target = relationLevelTarget(level);
  return aToB >= target && bToA >= target;
}

const RELATION_DISCONNECT_TIMEOUT_MS = 24 * 60 * 60 * 1000;

function relationDays(row) {
  if (String(row?.state ?? "") !== "active") return 0;
  const start = Math.max(0, Number(row?.activated_at ?? row?.created_at ?? 0));
  if (start <= 0) return 0;
  return Math.max(1, Math.floor((ts() - start) / (24 * 60 * 60 * 1000)) + 1);
}

async function normalizeDisconnectTimeout(db, row) {
  if (!row || String(row.disconnect_state ?? "none") !== "requested") return row;
  const requestedAt = Math.max(0, Number(row.disconnect_requested_at ?? 0));
  if (requestedAt <= 0 || ts() - requestedAt < RELATION_DISCONNECT_TIMEOUT_MS) return row;
  await db.prepare(
    `UPDATE cp_relationships
        SET disconnect_state='timedOut',updated_at=?
      WHERE user_a=? AND user_b=? AND disconnect_state='requested'`
  ).bind(ts(),row.user_a,row.user_b).run();
  return { ...row, disconnect_state:"timedOut" };
}

async function relationDisconnectRequest(db, userId) {
  const state = await cpState(db,userId);
  if (!state || state.state !== "active") throw new Error("cp_not_active");
  if (state.disconnect_state === "requested") {
    if (String(state.disconnect_requested_by ?? "") === String(userId)) return state;
    throw new Error("cp_disconnect_waiting_for_response");
  }
  // Breaking a CP costs 20,000,000 coins (Vinay, 2026-11-20), paid by
  // the partner who asks for the disconnect, up front — no refund if
  // the partner refuses, same as a rejected CP request.
  const disconnectCost = 20000000;
  const debit = await db.prepare(
    "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=?"
  ).bind(disconnectCost,ts(),userId,disconnectCost).run();
  if (Number(debit.meta?.changes ?? 0) !== 1) {
    throw new Error("insufficient_coins");
  }
  const partnerId = String(state.user_a) === String(userId)
    ? String(state.user_b)
    : String(state.user_a);
  const updatedAt = ts();
  try {
    const marked = await db.prepare(
      `UPDATE cp_relationships
          SET disconnect_state='requested',
              disconnect_requested_by=?,
              disconnect_requested_at=?,
              updated_at=?
        WHERE user_a=? AND user_b=? AND state='active'`
    ).bind(userId,updatedAt,updatedAt,state.user_a,state.user_b).run();
    if (Number(marked.meta?.changes ?? 0) !== 1) {
      // The row changed between the read and this update (partner
      // responded, timed out, or the CP ended): throw so the catch
      // below refunds, instead of charging 20M for a request that
      // never landed (audit 2026-11-20).
      throw new Error("cp_not_active");
    }
    const wallet = await db.prepare(
      "SELECT coins FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    await db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(
      uid("cp-"),
      userId,
      "cp_disconnect",
      -disconnectCost,
      Number(wallet?.coins ?? 0),
      "cp:" + partnerId,
      updatedAt,
    ).run();
  } catch (error) {
    await db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=?"
    ).bind(disconnectCost,ts(),userId).run();
    throw error;
  }
  return cpState(db,userId);
}

async function relationDisconnectRespond(db, userId, accept) {
  const state = await cpState(db,userId);
  if (!state || state.state !== "active") throw new Error("cp_not_active");
  if (state.disconnect_state !== "requested") {
    throw new Error("cp_disconnect_request_not_found");
  }
  if (String(state.disconnect_requested_by ?? "") === String(userId)) {
    throw new Error("cp_disconnect_waiting_for_partner");
  }
  if (accept) {
    await db.prepare(
      `DELETE FROM cp_relationships WHERE user_a=? AND user_b=?`
    ).bind(state.user_a,state.user_b).run();
    return null;
  }
  await db.prepare(
    `UPDATE cp_relationships
        SET disconnect_state='refused',updated_at=?
      WHERE user_a=? AND user_b=?`
  ).bind(ts(),state.user_a,state.user_b).run();
  return cpState(db,userId);
}

async function relationHeartbeat(db, userId, actionValue, choiceValue) {
  const state = await cpState(db,userId);
  if (!state || state.state !== "active") throw new Error("cp_not_active");
  const action = String(actionValue ?? "state").trim().toLowerCase();
  const viewerIsA = String(state.user_a) === String(userId);
  const updatedAt = ts();

  if (action === "start") {
    await db.prepare(
      `UPDATE cp_relationships
          SET heartbeat_state='selecting',
              heartbeat_choice_a=NULL,
              heartbeat_choice_b=NULL,
              heartbeat_updated_at=?,
              updated_at=?
        WHERE user_a=? AND user_b=?`
    ).bind(updatedAt,updatedAt,state.user_a,state.user_b).run();
  } else if (action === "choose") {
    const choice = clean(choiceValue,20).toUpperCase();
    if (choice !== "A" && choice !== "B") throw new Error("invalid_heartbeat_choice");
    const column = viewerIsA ? "heartbeat_choice_a" : "heartbeat_choice_b";
    await db.prepare(
      `UPDATE cp_relationships
          SET heartbeat_state='selecting',
              ${column}=?,
              heartbeat_updated_at=?,
              updated_at=?
        WHERE user_a=? AND user_b=? AND state='active'`
    ).bind(choice,updatedAt,updatedAt,state.user_a,state.user_b).run();
    const current = await db.prepare(
      `SELECT heartbeat_choice_a,heartbeat_choice_b
         FROM cp_relationships WHERE user_a=? AND user_b=? LIMIT 1`
    ).bind(state.user_a,state.user_b).first();
    const a = String(current?.heartbeat_choice_a ?? "");
    const b = String(current?.heartbeat_choice_b ?? "");
    if (a && b) {
      await db.prepare(
        `UPDATE cp_relationships
            SET heartbeat_state=?,heartbeat_updated_at=?,updated_at=?
          WHERE user_a=? AND user_b=?`
      ).bind(a === b ? "matched" : "failed",updatedAt,updatedAt,state.user_a,state.user_b).run();
    }
  } else if (action === "close") {
    await db.prepare(
      `UPDATE cp_relationships
          SET heartbeat_state='idle',
              heartbeat_choice_a=NULL,
              heartbeat_choice_b=NULL,
              heartbeat_updated_at=?,
              updated_at=?
        WHERE user_a=? AND user_b=?`
    ).bind(updatedAt,updatedAt,state.user_a,state.user_b).run();
  } else if (action !== "state") {
    throw new Error("invalid_heartbeat_action");
  }

  return cpState(db,userId);
}

export async function cpDisconnectRequest(db,userId) {
  return relationDisconnectRequest(db,userId);
}

export async function cpDisconnectRespond(db,userId,accept) {
  return relationDisconnectRespond(db,userId,accept);
}

export async function cpHeartbeat(db,userId,action,choice) {
  return relationHeartbeat(db,userId,action,choice);
}

async function cpBlockingFlow(db, userId) {
  if (!userId) return false;
  const row = await db.prepare(
    "SELECT state FROM cp_relationships WHERE (user_a=? OR user_b=?) AND state IN ('pending','active') LIMIT 1"
  ).bind(userId,userId).first();
  return row?.state === "pending" || row?.state === "active";
}

export async function cpState(db, userId) {
  await ensureTinniSocialSchema(db);
  let row = await db.prepare(
    `SELECT c.*,ua.display_name AS user_a_name,ua.avatar_key AS user_a_avatar_key,
            ua.public_id AS user_a_public_id,
            ub.display_name AS user_b_name,ub.avatar_key AS user_b_avatar_key,
            ub.public_id AS user_b_public_id
       FROM cp_relationships c
       LEFT JOIN users ua ON ua.id=c.user_a
       LEFT JOIN users ub ON ub.id=c.user_b
      WHERE (c.user_a=? OR c.user_b=?)
        AND c.state IN ('pending','active')
      ORDER BY CASE WHEN c.state='active' THEN 0 ELSE 1 END,
               c.updated_at DESC
      LIMIT 1`
  ).bind(userId,userId).first();
  if (!row) return null;
  row = await normalizeDisconnectTimeout(db,row);
  const intimacy = Math.max(0, Number(row.intimacy ?? 0));
  const level = Math.max(1, Math.floor(Number(row.level ?? 1)));
  const target = relationLevelTarget(level);
  const cycle = relationDirectionalProgress(row, userId);
  return {
    ...row,
    intimacy,
    level,
    pair_a_to_b: cycle.a_to_b,
    pair_b_to_a: cycle.b_to_a,
    level_sending: cycle.sending,
    level_receiving: cycle.receiving,
    next_level_target: target,
    next_level_sending_required: target,
    next_level_receiving_required: target,
    level_sending_remaining: Math.max(0, target - cycle.sending),
    level_receiving_remaining: Math.max(0, target - cycle.receiving),
    love_days: relationDays(row),
    heartbeat_choice:
      String(row.user_a) === String(userId)
        ? row.heartbeat_choice_a
        : row.heartbeat_choice_b,
    partner_heartbeat_choice:
      String(row.user_a) === String(userId)
        ? row.heartbeat_choice_b
        : row.heartbeat_choice_a,
    previous_level_threshold: 0,
    next_level_threshold: target,
  };
}

async function mutualFriends(db, userId, targetId) {
  const row = await db.prepare(
    `SELECT
       EXISTS(SELECT 1 FROM user_follows WHERE follower_id=? AND target_id=?) AS a,
       EXISTS(SELECT 1 FROM user_follows WHERE follower_id=? AND target_id=?) AS b`
  ).bind(userId,targetId,targetId,userId).first();
  return Number(row?.a ?? 0) === 1 && Number(row?.b ?? 0) === 1;
}

export async function cpRequest(db, userId, targetIdValue) {
  await ensureTinniSocialSchema(db);
  const targetId = String(targetIdValue ?? "").trim();
  if (!targetId || userId === targetId) throw new Error("invalid_cp_target");
  const target = await db.prepare("SELECT id FROM users WHERE id=? LIMIT 1")
    .bind(targetId).first();
  if (!target) throw new Error("cp_user_not_found");
  if (!(await mutualFriends(db,userId,targetId))) {
    throw new Error("cp_friend_required");
  }
  if (await cpBlockingFlow(db,userId)) throw new Error("cp_already_active");
  if (await cpBlockingFlow(db,targetId)) throw new Error("target_cp_already_active");

  // CP costs 20,000,000 coins (Vinay, 2026-11-20), paid by the requester
  // up front. No refund if the partner rejects (Vinay: "Nhi milenge
  // wapas 20m reject hone per").
  const inviteCost = 20000000;
  const debit = await db.prepare(
    "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=?"
  ).bind(inviteCost,ts(),userId,inviteCost).run();
  if (Number(debit.meta?.changes ?? 0) !== 1) {
    throw new Error("insufficient_coins");
  }

  const [a,b] = pair(userId,targetId);
  const createdAt=ts();
  // Insert only when no row exists for the pair: the old upsert let two
  // concurrent requests (A→B and B→A) both debit 20M and reset an ACTIVE
  // CP back to pending (audit 2026-11-20). A 0-row insert means the pair
  // already has a row — refund the debit and report it.
  const inserted = await db.prepare(
    `INSERT INTO cp_relationships(
      user_a,user_b,state,intimacy,level,cycle_a_to_b,cycle_b_to_a,requested_by,created_at,updated_at
    ) SELECT ?,?,'pending',0,1,0,0,?,?,?
        WHERE NOT EXISTS (
          SELECT 1 FROM cp_relationships WHERE user_a=? AND user_b=?
        )`
  ).bind(a,b,userId,createdAt,createdAt,a,b).run();
  if (Number(inserted.meta?.changes ?? 0) !== 1) {
    await db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=?"
    ).bind(inviteCost,ts(),userId).run();
    throw new Error("cp_already_active");
  }
  try {
    const wallet = await db.prepare(
      "SELECT coins FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    await db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(
      uid("cp-"),
      userId,
      "cp_connect",
      -inviteCost,
      Number(wallet?.coins ?? 0),
      "cp:" + targetId,
      createdAt,
    ).run();
    // CP invite DM (Vinay, 2026-11-20): the invite shows PERMANENTLY in
    // the DM chat with Accept/Reject, and the pop-up reads the pending
    // CP row. One DM per invite — a new request after a reject writes a
    // new row; the old one keeps its decided kind.
    const requester = await db.prepare(
      "SELECT display_name FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    const requesterName = String(requester?.display_name ?? "").trim() || "Someone";
    await db.prepare(
      "INSERT INTO direct_messages(id,sender_user_id,receiver_user_id,kind,text,created_at,read_at) VALUES(?,?,?,?,?,?,NULL)"
    ).bind(
      uid("dm-"),
      userId,
      targetId,
      "cp_invite",
      `💌 CP invite from ${requesterName}`,
      createdAt,
    ).run();
  } catch (error) {
    // The row was created by this call (the insert above only ever adds
    // a new row), so remove it too — otherwise a ledger/DM failure
    // would leave a FREE pending CP behind the refund.
    await db.prepare(
      "DELETE FROM cp_relationships WHERE user_a=? AND user_b=? AND requested_by=? AND created_at=?"
    ).bind(a,b,userId,createdAt).run();
    await db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=?"
    ).bind(inviteCost,ts(),userId).run();
    throw error;
  }
  return cpState(db,userId);
}

export async function cpRespond(db, userId, accept) {
  await ensureTinniSocialSchema(db);
  const row = await db.prepare(
    "SELECT * FROM cp_relationships WHERE (user_a=? OR user_b=?) AND state='pending' ORDER BY updated_at DESC LIMIT 1"
  ).bind(userId,userId).first();
  if (!row) throw new Error("cp_request_not_found");
  if (row.requested_by === userId) throw new Error("cp_request_waiting_for_partner");
  if (accept) {
    await db.prepare(
      "UPDATE cp_relationships SET state='active',activated_at=?,disconnect_state='none',disconnect_requested_by=NULL,disconnect_requested_at=NULL,heartbeat_state='idle',heartbeat_choice_a=NULL,heartbeat_choice_b=NULL,updated_at=? WHERE user_a=? AND user_b=?"
    ).bind(ts(),ts(),row.user_a,row.user_b).run();
  } else {
    // Reject: the 20,000,000 request coins are NOT refunded (Vinay,
    // 2026-11-20) — the row is simply deleted.
    await db.prepare(
      "DELETE FROM cp_relationships WHERE user_a=? AND user_b=?"
    ).bind(row.user_a,row.user_b).run();
  }
  // The invite DM keeps its verdict forever (Vinay, 2026-11-20): Accept
  // or Reject can be chosen only ONCE per invite, so the message records
  // the choice and its buttons never come back. A later re-invite writes
  // a NEW dm row; this update only touches still-pending invites.
  await db.prepare(
    "UPDATE direct_messages SET kind=? WHERE kind='cp_invite' AND sender_user_id=? AND receiver_user_id=?"
  ).bind(accept ? "cp_invite_accepted" : "cp_invite_rejected", row.requested_by, userId).run();
  return accept ? cpState(db,userId) : null;
}

export async function cpDisconnect(db, userId) {
  const row = await cpState(db,userId);
  if (!row) return { ok: true, cp:null };
  if (String(row.state ?? "") !== "active") {
    // A pending invite is not a CP yet: cancelling it costs nothing
    // extra (the requester already paid 20M up front, which stays
    // non-refunded like a reject). The old code charged another 20M to
    // delete a pending row (audit 2026-11-20). Stamp the invite DM so
    // its Accept/Reject buttons never come back.
    const partnerId = String(row.requested_by ?? "") === String(row.user_a)
      ? String(row.user_b)
      : String(row.user_a);
    await db.prepare(
      "DELETE FROM cp_relationships WHERE user_a=? AND user_b=?"
    ).bind(row.user_a,row.user_b).run();
    await db.prepare(
      "UPDATE direct_messages SET kind='cp_invite_rejected' WHERE kind='cp_invite' AND sender_user_id=? AND receiver_user_id=?"
    ).bind(row.requested_by, partnerId).run();
    return { ok: true, cp:null };
  }
  // Direct breakup also costs 20,000,000 coins (Vinay, 2026-11-20),
  // paid by whoever breaks it. No app screen calls this directly —
  // the app uses the request/respond flow — but the price is the same.
  const disconnectCost = 20000000;
  const debit = await db.prepare(
    "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=?"
  ).bind(disconnectCost,ts(),userId,disconnectCost).run();
  if (Number(debit.meta?.changes ?? 0) !== 1) {
    throw new Error("insufficient_coins");
  }
  const partnerId = String(row.user_a) === String(userId)
    ? String(row.user_b)
    : String(row.user_a);
  const deletedAt = ts();
  try {
    await db.prepare(
      "DELETE FROM cp_relationships WHERE user_a=? AND user_b=?"
    ).bind(row.user_a,row.user_b).run();
    const wallet = await db.prepare(
      "SELECT coins FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    await db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(
      uid("cp-"),
      userId,
      "cp_disconnect",
      -disconnectCost,
      Number(wallet?.coins ?? 0),
      "cp:" + partnerId,
      deletedAt,
    ).run();
  } catch (error) {
    await db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=?"
    ).bind(disconnectCost,ts(),userId).run();
    throw error;
  }
  return { ok: true, cp:null };
}

export async function cpAddMemory(db, userId, bodyValue) {
  const relation = await cpState(db,userId);
  if (!relation || relation.state !== "active") throw new Error("cp_not_active");
  const body = clean(bodyValue,500);
  if (!body) throw new Error("cp_memory_required");
  const memory={id:uid("cp-memory-"),body,created_by:userId,created_at:ts()};
  await db.prepare(
    "INSERT INTO cp_memories(id,user_a,user_b,body,created_by,created_at) VALUES(?,?,?,?,?,?)"
  ).bind(memory.id,relation.user_a,relation.user_b,body,userId,memory.created_at).run();
  return memory;
}

export async function cpMemories(db, userId) {
  const relation = await cpState(db,userId);
  if (!relation) return [];
  const rows=await db.prepare(
    "SELECT id,body,created_by,created_at FROM cp_memories WHERE user_a=? AND user_b=? ORDER BY created_at DESC LIMIT 100"
  ).bind(relation.user_a,relation.user_b).all();
  return rows.results ?? [];
}

export async function recordCpGiftProgress(
  db,
  senderUserId,
  receiverUserId,
  coinValue,
  eventId,
) {
  await ensureTinniSocialSchema(db);

  const relation = await cpState(db,senderUserId);
  if (!relation || relation.state !== "active") {
    return { progress:0, cp:relation };
  }

  const sender = String(senderUserId);
  const receiver = String(receiverUserId);
  const a = String(relation.user_a);
  const b = String(relation.user_b);
  const aToB = sender === a && receiver === b;
  const bToA = sender === b && receiver === a;
  const progress = Math.max(0, Math.floor(Number(coinValue ?? 0)));

  if ((!aToB && !bToA) || !Number.isSafeInteger(progress) || progress <= 0) {
    return { progress:0, cp:relation };
  }

  const levelBefore = Math.max(1, Math.floor(Number(relation.level ?? 1)));
  const updatedAt=ts();

  // Claim the event FIRST: the old code checked for duplicates, then
  // updated progress, then inserted the marker — two concurrent calls
  // with the same event both passed the check and counted the gift
  // twice (audit 2026-11-20). A 0-row insert means the event was
  // already recorded.
  if (eventId) {
    const claimed = await db.prepare(
      `INSERT OR IGNORE INTO cp_gift_progress(
        event_id,user_a,user_b,pair_started_at,sender_user_id,receiver_user_id,
        progress,level_before,level_after,created_at
      ) VALUES(?,?,?,?,?,?,?,?,?,?)`
    ).bind(
      eventId,
      relation.user_a,
      relation.user_b,
      Number(relation.created_at ?? 0),
      senderUserId,
      receiverUserId,
      progress,
      levelBefore,
      levelBefore,
      updatedAt,
    ).run();
    if (Number(claimed.meta?.changes ?? 0) === 0) {
      return { progress:0, duplicate:true, cp:await cpState(db,senderUserId) };
    }
  }

  // Relative increments, never an absolute SET from a stale read: two
  // concurrent gifts used to read the same cycles and overwrite each
  // other, losing one gift's progress.
  await db.prepare(
    `UPDATE cp_relationships
        SET intimacy=intimacy+?,
            cycle_a_to_b=cycle_a_to_b+?,
            cycle_b_to_a=cycle_b_to_a+?,
            updated_at=?
      WHERE user_a=? AND user_b=? AND state='active'`
  ).bind(
    progress,
    aToB ? progress : 0,
    bToA ? progress : 0,
    updatedAt,relation.user_a,relation.user_b,
  ).run();

  // Level-up is decided on the fresh totals, with a compare-and-swap on
  // the level so two concurrent gifts can only level the pair up once.
  // (The excess is still discarded on level-up, as before — only the
  // race is fixed, not the level math.)
  const fresh = await cpState(db,senderUserId);
  let levelAfter = levelBefore;
  if (fresh && fresh.state === "active" && relationCanLevelUp(
    levelBefore,
    Math.max(0, Math.floor(Number(fresh.pair_a_to_b ?? fresh.cycle_a_to_b ?? 0))),
    Math.max(0, Math.floor(Number(fresh.pair_b_to_a ?? fresh.cycle_b_to_a ?? 0))),
  )) {
    const leveled = await db.prepare(
      `UPDATE cp_relationships
          SET level=level+1,cycle_a_to_b=0,cycle_b_to_a=0,updated_at=?
        WHERE user_a=? AND user_b=? AND state='active' AND level=?`
    ).bind(updatedAt,relation.user_a,relation.user_b,levelBefore).run();
    if (Number(leveled.meta?.changes ?? 0) === 1) {
      levelAfter = levelBefore + 1;
    }
  }
  if (eventId && levelAfter !== levelBefore) {
    await db.prepare(
      "UPDATE cp_gift_progress SET level_after=? WHERE event_id=?"
    ).bind(levelAfter,eventId).run();
  }

  const finalState = await cpState(db,senderUserId);
  return {
    progress,
    level_before:levelBefore,
    level_after:levelAfter,
    level_up:levelAfter > levelBefore,
    intimacy: Math.max(0, Math.floor(Number(finalState?.intimacy ?? 0))),
    cp: finalState,
  };
}

export async function cpRanking(db, limitValue=100) {
  await ensureTinniSocialSchema(db);
  const limit=Math.max(1,Math.min(100,Number(limitValue)||100));
  const rows=await db.prepare(
    `SELECT c.*,ua.display_name AS user_a_name,ua.avatar_key AS user_a_avatar_key,
            ub.display_name AS user_b_name,ub.avatar_key AS user_b_avatar_key
       FROM cp_relationships c
       LEFT JOIN users ua ON ua.id=c.user_a
       LEFT JOIN users ub ON ub.id=c.user_b
      WHERE c.state='active'
      ORDER BY c.level DESC,c.intimacy DESC,c.updated_at ASC LIMIT ?`
  ).bind(limit).all();
  return (rows.results ?? [])
    .sort((a,b) =>
      Number(b.level ?? 1) - Number(a.level ?? 1) ||
      Number(b.intimacy ?? 0) - Number(a.intimacy ?? 0) ||
      Number(a.updated_at ?? 0) - Number(b.updated_at ?? 0)
    )
    .map((row,index) => ({
      ...row,
      rank:index+1,
      level:Math.max(1,Math.floor(Number(row.level ?? 1))),
      next_level_target:relationLevelTarget(row.level ?? 1),
    }));
}


export async function profileTrends(db, userId, limitValue=40) {
  await ensureTinniSocialSchema(db);
  const limit=Math.max(1,Math.min(100,Number(limitValue)||40));
  const rows=await db.prepare(
    "SELECT id,user_id,text,created_at FROM profile_trends WHERE user_id=? ORDER BY created_at DESC LIMIT ?"
  ).bind(userId,limit).all();
  return rows.results ?? [];
}

export async function addProfileTrend(db, userId, textValue) {
  await ensureTinniSocialSchema(db);
  const text=clean(textValue,500);
  if(!text) throw new Error("trend_text_required");
  const row={
    id:uid("trend-"),
    user_id:userId,
    text,
    created_at:ts(),
  };
  await db.prepare(
    "INSERT INTO profile_trends(id,user_id,text,created_at) VALUES(?,?,?,?)"
  ).bind(row.id,row.user_id,row.text,row.created_at).run();
  return row;
}

export async function officialNotices(db) {
  await ensureTinniSocialSchema(db);
  const rows = await db.prepare(
    "SELECT id,title,body,created_at FROM official_notices ORDER BY created_at DESC LIMIT 100"
  ).all();
  return rows.results ?? [];
}

export async function activityFeed(db, userId) {
  await ensureTinniSocialSchema(db);
  const items = [];
  try {
    const wallet = await db.prepare(
      "SELECT id,kind,amount,balance_after,created_at FROM wallet_ledger WHERE user_id=? ORDER BY created_at DESC LIMIT 40"
    ).bind(userId).all();
    for (const row of wallet.results ?? []) {
      items.push({
        id: "wallet:" + String(row.id),
        kind: "wallet",
        title: String(row.kind ?? "Wallet activity"),
        body:
          (Number(row.amount ?? 0) >= 0 ? "+" : "") +
          String(row.amount ?? 0) +
          " coins • Balance " +
          String(row.balance_after ?? 0),
        created_at: Number(row.created_at ?? 0),
      });
    }
  } catch (_) {}
  try {
    const visits = await db.prepare(
      `SELECT v.visitor_user_id,u.display_name,v.last_visited_at
         FROM profile_visitors v
         JOIN users u ON u.id=v.visitor_user_id
        WHERE v.viewed_user_id=?
        ORDER BY v.last_visited_at DESC LIMIT 30`
    ).bind(userId).all();
    for (const row of visits.results ?? []) {
      items.push({
        id: "visit:" + String(row.visitor_user_id) + ":" + String(row.last_visited_at),
        kind: "visitor",
        title: "Profile visitor",
        body: String(row.display_name ?? "User") + " visited your profile",
        created_at: Number(row.last_visited_at ?? 0),
      });
    }
  } catch (_) {}
  try {
    const gifts = await db.prepare(
      `SELECT g.id,g.coin_cost,g.created_at,u.display_name
         FROM gift_events g
         LEFT JOIN users u ON u.id=g.sender_user_id
        WHERE g.receiver_user_id=?
        ORDER BY g.created_at DESC LIMIT 30`
    ).bind(userId).all();
    for (const row of gifts.results ?? []) {
      items.push({
        id: "gift:" + String(row.id),
        kind: "gift",
        title: "Gift received",
        body:
          String(row.display_name ?? "User") +
          " sent a gift worth " +
          String(row.coin_cost ?? 0) +
          " coins",
        created_at: Number(row.created_at ?? 0),
      });
    }
  } catch (_) {}
  items.sort((a,b) => Number(b.created_at) - Number(a.created_at));
  const visibleItems = items.slice(0,100);
  const receipts = await db.prepare(
    "SELECT item_id FROM activity_read_receipts WHERE user_id=?"
  ).bind(userId).all();
  const readItemIds = new Set(
    (receipts.results ?? []).map((row) => String(row.item_id ?? ""))
  );
  return visibleItems.map((item) => ({
    ...item,
    is_read: readItemIds.has(String(item.id)),
  }));
}

export async function markActivityRead(db, userId, itemIds) {
  await ensureTinniSocialSchema(db);
  const requestedIds = [...new Set(
    (Array.isArray(itemIds) ? itemIds : [])
      .map((value) => String(value ?? "").trim())
      .filter(Boolean)
  )].slice(0, 100);
  if (requestedIds.length === 0) return { read_count: 0 };

  // Only allow read receipts for activity entries actually owned by this user.
  const visibleIds = new Set((await activityFeed(db, userId)).map((item) => item.id));
  const validIds = requestedIds.filter((itemId) => visibleIds.has(itemId));
  if (validIds.length === 0) return { read_count: 0 };

  const readAt = ts();
  await db.batch(validIds.map((itemId) => db.prepare(
    "INSERT OR IGNORE INTO activity_read_receipts(user_id,item_id,read_at) VALUES(?,?,?)"
  ).bind(userId, itemId, readAt)));

  // Keep each user's receipts bounded while preserving recent read state.
  await db.prepare(
    `DELETE FROM activity_read_receipts
      WHERE user_id=?
        AND item_id NOT IN (
          SELECT item_id FROM activity_read_receipts
           WHERE user_id=?
           ORDER BY read_at DESC LIMIT 500
        )`
  ).bind(userId, userId).run();

  return { read_count: validIds.length };
}
