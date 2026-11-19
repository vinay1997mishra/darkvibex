// DarkVibeX — Rocket medal grants (Top 1/2/3 on a rocket launch).
//
// Rocket medals (Rocket 1-18, rocket-medals/ on R2, gold "LV.N"
// ribbons) are PERMANENT (Vinay, 2026-11-19: cumulative/one-time,
// never decreases). Until this module they were DISPLAY-ONLY — the
// medal gallery shows all 18 tiles and the Rocket Room Page ladder
// shows the current level's medal, but no code ever gave a medal to
// anyone: there was no launch trigger and no medal ownership.
// Vinay (2026-11-20): "Top 1/2/3 ko mile" — when a room's cumulative
// gift total reaches a rocket level target, the Top 1/2/3 gifters at
// that moment get the Rocket Lv.N medal for that level.
//
// Launch detection lives here because no launch event exists anywhere
// else: the pool-claim flow (rocket_rewards.js) is claim-driven, and
// Top 1/2/3 VIP + launch coins are still DISPLAY-ONLY (computed by
// apps/mobile/lib/utils/rocket_top_rewards.dart for the Rocket Room
// Page) — this module grants ONLY the medal and changes no pool,
// coin or VIP rule. No frames are involved.
//
// Tables (created lazily, like rocket_reward_claims):
//   rocket_launches(room_id, rocket_level, launched_at) — one row per
//     room + level, so each level launches once per room and the
//     winners are frozen at that moment (the ranking can move later).
//   user_medals(user_id, series='rocket', level, room_id, granted_at)
//     — UNIQUE(user_id, series, level): permanent, once per user per
//     level; reaching the same level in another room does not duplicate
//     it. Retention jobs never delete these tables.
//
// Tier names mirror apps/mobile/lib/screens/medal_gallery_screen.dart
// (_rocketTier): Launch, Blaze, Comet, Solar, Nova, Gold Rush, Tidal,
// Rose Jet, Phantom, Inferno, Stellar, Orbit King, Star Forge, Nebula,
// Cosmic, Galactic, Supernova, Rocket Apex.

import {
  ROCKET_MILESTONE_TARGETS,
} from "./rocket_rewards.js";

export const ROCKET_MEDAL_SERIES = "rocket";

/// Rocket glow colour, matching MedalSeries.rocket in the app.
export const ROCKET_MEDAL_COLOR = "#69C9FF";

export const ROCKET_MEDAL_TIER_NAMES = Object.freeze([
  "Launch", "Blaze", "Comet", "Solar", "Nova", "Gold Rush", "Tidal",
  "Rose Jet", "Phantom", "Inferno", "Stellar", "Orbit King",
  "Star Forge", "Nebula", "Cosmic", "Galactic", "Supernova",
  "Rocket Apex",
]);

export function rocketMedalTierForLevel(level) {
  const safeLevel = Number(level);
  if (!Number.isInteger(safeLevel) || safeLevel < 1 || safeLevel > 18) return null;
  return ROCKET_MEDAL_TIER_NAMES[safeLevel - 1];
}

/// Display name of the Rocket medal for [level], e.g.
/// "Rocket Lv.6 — Gold Rush". Null for an invalid level.
export function rocketMedalNameForLevel(level) {
  const tier = rocketMedalTierForLevel(level);
  if (tier == null) return null;
  return `Rocket Lv.${Number(level)} — ${tier}`;
}

export async function ensureRocketMedalSchema(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS rocket_launches (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      rocket_level INTEGER NOT NULL CHECK (rocket_level BETWEEN 1 AND 18),
      launched_at INTEGER NOT NULL,
      UNIQUE (room_id, rocket_level)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS user_medals (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      series TEXT NOT NULL,
      level INTEGER NOT NULL CHECK (level BETWEEN 1 AND 18),
      room_id TEXT,
      granted_at INTEGER NOT NULL,
      UNIQUE (user_id, series, level),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE INDEX IF NOT EXISTS idx_user_medals_user
      ON user_medals(user_id, series, level)`),
  ]);
}

/// Highest rocket level whose target the room's lifetime gift total
/// has reached, or null when no target is reached yet. Targets stay
/// aligned with apps/mobile/lib/utils/rocket_progress.dart.
export async function rocketLevelReached(db, roomId) {
  const room = String(roomId ?? "").trim();
  if (!room) return null;
  const totalRow = await db.prepare(
    "SELECT COALESCE(SUM(coin_cost),0) AS lifetime_total FROM gift_events WHERE room_id=?",
  ).bind(room).first();
  const lifetimeTotal = Number(totalRow?.lifetime_total ?? 0);
  let reached = null;
  for (let level = 1; level <= ROCKET_MILESTONE_TARGETS.length; level++) {
    if (lifetimeTotal >= ROCKET_MILESTONE_TARGETS[level - 1]) reached = level;
  }
  return reached;
}

/// Top gifters of a room by lifetime sent coins — the same ranking as
/// GET /api/rooms/:id/gift-ranking (sent coins desc, gift count desc).
/// Returns at most [limit] rows: {user_id, display_name, sent_coins,
/// gift_count}.
export async function topRocketGifters(db, roomId, limit = 3) {
  const room = String(roomId ?? "").trim();
  if (!room) return [];
  const safeLimit = Math.max(0, Math.min(20, Number(limit) || 0));
  if (safeLimit === 0) return [];
  const rows = await db.prepare(
    `SELECT g.sender_user_id AS user_id,
            COALESCE(u.display_name,'User') AS display_name,
            SUM(g.coin_cost) AS sent_coins,
            COUNT(*) AS gift_count
       FROM gift_events g
       LEFT JOIN users u ON u.id=g.sender_user_id
      WHERE g.room_id=?
      GROUP BY g.sender_user_id,u.display_name
      ORDER BY sent_coins DESC,gift_count DESC
      LIMIT ?`,
  ).bind(room, safeLimit).all();
  return (rows.results ?? []).map((row) => ({
    user_id: String(row.user_id ?? ""),
    display_name: String(row.display_name ?? "User"),
    sent_coins: Number(row.sent_coins ?? 0),
    gift_count: Number(row.gift_count ?? 0),
  }));
}

/// Grant Rocket medals for every level the room has newly reached.
/// Called best-effort after a gift commits (see /api/gifts/send):
/// the room's lifetime total only moves when a gift lands, so the
/// first gift that crosses a level target is the launch moment, and
/// the Top 1/2/3 at that moment are the winners. A single gift can
/// cross several levels at once (e.g. from just below Lv.1 to past
/// Lv.2) — every newly reached level launches and grants its medal.
/// Returns { launched, levels, winners } where winners are
/// { level, rank, user_id, display_name }. Never throws for a
/// missing/empty room (returns launched:false); callers keep the
/// gift send itself unaffected.
export async function grantRocketMedalsOnLaunch(db, roomId, nowMs, newId) {
  const room = String(roomId ?? "").trim();
  if (!room) return { launched: false, levels: [], winners: [] };
  const reached = await rocketLevelReached(db, room);
  if (reached == null) return { launched: false, levels: [], winners: [] };
  await ensureRocketMedalSchema(db);
  const launchedRows = await db.prepare(
    "SELECT rocket_level FROM rocket_launches WHERE room_id=?",
  ).bind(room).all();
  const alreadyLaunched = new Set(
    (launchedRows.results ?? []).map((row) => Number(row.rocket_level)),
  );
  const levels = [];
  const winners = [];
  for (let level = 1; level <= reached; level++) {
    if (alreadyLaunched.has(level)) continue;
    // INSERT OR IGNORE + read-back by our id: only the request that
    // actually inserted the launch row grants the medals, so two
    // concurrent gifts crossing the same target cannot double-grant.
    const launchId = newId();
    await db.prepare(
      "INSERT OR IGNORE INTO rocket_launches (id,room_id,rocket_level,launched_at) VALUES(?,?,?,?)",
    ).bind(launchId, room, level, nowMs).run();
    const launchRow = await db.prepare(
      "SELECT id FROM rocket_launches WHERE id=? LIMIT 1",
    ).bind(launchId).first();
    if (!launchRow) continue;
    levels.push(level);
    const top = await topRocketGifters(db, room, 3);
    for (const [index, gifter] of top.entries()) {
      await db.prepare(
        "INSERT OR IGNORE INTO user_medals (id,user_id,series,level,room_id,granted_at) VALUES(?,?,?,?,?,?)",
      ).bind(newId(), gifter.user_id, ROCKET_MEDAL_SERIES, level, room, nowMs).run();
      winners.push({
        level,
        rank: index + 1,
        user_id: gifter.user_id,
        display_name: gifter.display_name,
      });
    }
  }
  return { launched: levels.length > 0, levels, winners };
}

/// Earned Rocket medal levels for one user, ascending. [] when the
/// user has none, or when the table does not exist yet (no launch
/// has ever run on this database).
export async function userRocketMedals(db, userId) {
  const user = String(userId ?? "").trim();
  if (!user) return [];
  try {
    const rows = await db.prepare(
      "SELECT level,room_id,granted_at FROM user_medals WHERE user_id=? AND series='rocket' ORDER BY level ASC",
    ).bind(user).all();
    return (rows.results ?? []).map((row) => ({
      level: Number(row.level ?? 0),
      room_id: String(row.room_id ?? ""),
      granted_at: Number(row.granted_at ?? 0),
    }));
  } catch (error) {
    if (/no such table/i.test(String(error?.message ?? error))) return [];
    throw error;
  }
}

/// Earned Rocket medal levels for many users at once: Map user_id ->
/// [levels ascending]. Missing table behaves like no medals.
export async function rocketMedalsByUser(db, userIds) {
  const ids = [...new Set(
    (userIds ?? []).map((value) => String(value ?? "").trim()).filter(Boolean),
  )];
  const byUser = new Map();
  if (!ids.length) return byUser;
  try {
    const placeholders = ids.map(() => "?").join(",");
    const rows = await db.prepare(
      `SELECT user_id,level FROM user_medals WHERE user_id IN (${placeholders}) AND series='rocket' ORDER BY level ASC`,
    ).bind(...ids).all();
    for (const row of rows.results ?? []) {
      const user = String(row.user_id ?? "");
      if (!byUser.has(user)) byUser.set(user, []);
      byUser.get(user).push(Number(row.level ?? 0));
    }
  } catch (error) {
    if (!/no such table/i.test(String(error?.message ?? error))) throw error;
  }
  return byUser;
}

/// /api/medals objects for earned Rocket levels: { id, name, color,
/// series, level }. The series/level let the app render the real
/// medal image next to the earner's name (room profile card).
export function rocketMedalObjects(levels) {
  const objects = [];
  for (const level of levels ?? []) {
    const name = rocketMedalNameForLevel(level);
    if (name == null) continue;
    objects.push({
      id: `rocket-${Number(level)}`,
      name,
      color: ROCKET_MEDAL_COLOR,
      series: ROCKET_MEDAL_SERIES,
      level: Number(level),
    });
  }
  return objects;
}
