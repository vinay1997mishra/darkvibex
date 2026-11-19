// DarkVibeX — D1 Space Retention
//
// D1 space rule (Vinay, 2026-11-19): "D1 ka data bhi bachana hai jo
// bhi jaruri nhi hai wo delete ho jana chahiye ki isme ka space full
// na ho" — delete whatever is not necessary from D1 so its space
// never fills up. Same daily 03:00 UTC job as the message and game
// data retention; D1 rows only, no R2 files.
//
// What is deleted (and why it is safe):
// - email_otp_requests older than 1 day: an OTP expires within
//   minutes; the verify flow only ever reads the latest request per
//   email and checks expires_at. A day-old OTP can never be used.
// - direct_calls older than 45 days: call history. A 45-day-old call
//   cannot be a live call; the active-call check only looks at
//   current states.
// - profile_visitors not visited in 45 days (last_visited_at): the
//   visitors list shows the recent 100 by last_visited_at; older rows
//   are never displayed.
// - game_bets older than 30 days: the rankings leaderboard reads
//   game_bets with a window of day / week / month — 30 days at most.
//   Rows older than 30 days are never read. (The table is legacy: no
//   code writes to it anymore, so this mostly shrinks it once.)
// - owner_notifications older than 45 days: old owner-panel notices.
//
// What is NEVER deleted here:
// - gift_events: room lifetime totals, top gifters and Rocket
//   progress are SUMs over this table — deleting rows corrupts them.
// - wallet_ledger, diamond_conversions, legal_consents, invite
//   rewards, rocket_reward_claims: financial / legal records.
// - users, rooms, room_members, game_rooms: live data.
// Each table group is deleted independently and a missing table is
// skipped, so a fresh database never breaks the daily cleanup.

/// Email OTP requests are useless after this many days.
export const EMAIL_OTP_BACKUP_DAYS = 1;

/// Call history, visitor history and owner notifications are kept
/// this many days (same window as the message/game backup).
export const D1_SPACE_BACKUP_DAYS = 45;

/// Old game bets are kept this many days (the rankings leaderboard
/// never looks back further than its 30-day month window).
export const GAME_BETS_BACKUP_DAYS = 30;

const DAY_MS = 24 * 60 * 60 * 1000;

/// The cutoff timestamp for a given backup window in days.
export function d1SpaceCutoffMs(days, nowMs = Date.now()) {
  return nowMs - days * DAY_MS;
}

async function deleteCount(db, sql, ...bound) {
  const result = await db.prepare(sql).bind(...bound).run();
  return Number(result?.meta?.changes ?? 0);
}

/// Deletes unnecessary D1 rows past their backup windows. Returns the
/// counts deleted per group. Best-effort per group: a missing table
/// is skipped, never fatal.
export async function expireOldD1SpaceData(db, nowMs = Date.now()) {
  const counts = {
    emailOtps: 0,
    directCalls: 0,
    profileVisitors: 0,
    gameBets: 0,
    ownerNotifications: 0,
  };

  try {
    counts.emailOtps += await deleteCount(
      db,
      `DELETE FROM email_otp_requests WHERE created_at < ?`,
      d1SpaceCutoffMs(EMAIL_OTP_BACKUP_DAYS, nowMs),
    );
  } catch (_) {
    // Table missing — nothing to delete.
  }

  try {
    counts.directCalls += await deleteCount(
      db,
      `DELETE FROM direct_calls WHERE created_at < ?`,
      d1SpaceCutoffMs(D1_SPACE_BACKUP_DAYS, nowMs),
    );
  } catch (_) {
    // Table missing — nothing to delete.
  }

  try {
    counts.profileVisitors += await deleteCount(
      db,
      `DELETE FROM profile_visitors WHERE last_visited_at < ?`,
      d1SpaceCutoffMs(D1_SPACE_BACKUP_DAYS, nowMs),
    );
  } catch (_) {
    // Table missing — nothing to delete.
  }

  try {
    counts.gameBets += await deleteCount(
      db,
      `DELETE FROM game_bets WHERE created_at < ?`,
      d1SpaceCutoffMs(GAME_BETS_BACKUP_DAYS, nowMs),
    );
  } catch (_) {
    // Table missing — nothing to delete.
  }

  try {
    counts.ownerNotifications += await deleteCount(
      db,
      `DELETE FROM owner_notifications WHERE created_at < ?`,
      d1SpaceCutoffMs(D1_SPACE_BACKUP_DAYS, nowMs),
    );
  } catch (_) {
    // Table missing — nothing to delete.
  }

  return counts;
}
