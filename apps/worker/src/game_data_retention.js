// DarkVibeX — Game Data Retention (45 days)
//
// Game data rule (Vinay, 2026-11-19): "game ka data 45 days me
// automatic delete hogi backup se d1 me se" — the server keeps a backup
// of game data for 45 days only. After 45 days the backup is deleted
// from D1. Same window and same daily job as the message backup
// (message_retention.js, 03:00 UTC); game data is D1 rows only, no R2
// files are involved (bets, results, sessions and pouches reference
// no stored files).
//
// What is deleted (rows older than 45 days):
// - Ludo: ludo_room_sessions (updated_at) and their
//   ludo_room_players. A session untouched for 45 days is an abandoned
//   game, never a live one.
// - Greedy Girl: greedy_girl_bets (created_at) and
//   greedy_girl_results (settled_at).
// - Girls Party: fruit_party_bets (created_at),
//   fruit_party_results (settled_at) and fruit_party_lucky_windows
//   (created_at).
// - Lucky pouch / lucky number: room_lucky_pouches (created_at) and
//   their room_lucky_pouch_claims, plus room_lucky_numbers
//   (created_at).
//
// What is NOT touched:
// - game_rooms / game_room_members: a game room is the owner's room,
//   like a voice room — rooms are never deleted by retention.
// - inbox_red_envelopes / claims: inbox envelopes, like VIP support
//   messages, are excluded from retention (same as message retention).
// - Users' coin balances (users.coins): deleting bet/result history
//   never changes a balance; balances live in their own column.
//
// Each table group is deleted independently and a missing table is
// skipped, so a fresh database (a game never played yet) never breaks
// the daily cleanup.

/// The server keeps a backup of game data for this many days.
export const GAME_DATA_BACKUP_DAYS = 45;

/// Milliseconds in the 45-day backup window.
export const GAME_DATA_BACKUP_WINDOW_MS =
  GAME_DATA_BACKUP_DAYS * 24 * 60 * 60 * 1000;

/// The cutoff timestamp: game rows older than this are past the
/// 45-day backup and are deleted. [nowMs] defaults to Date.now().
export function gameDataBackupCutoffMs(nowMs = Date.now()) {
  return nowMs - GAME_DATA_BACKUP_WINDOW_MS;
}

async function deleteCount(db, sql, ...bound) {
  const result = await db.prepare(sql).bind(...bound).run();
  return Number(result?.meta?.changes ?? 0);
}

/// Deletes game data older than the 45-day backup window from D1.
/// Returns the counts deleted per group. Best-effort per group: a
/// missing table (game never played) is skipped, never fatal.
export async function expireOldGameData(db, nowMs = Date.now()) {
  const cutoff = gameDataBackupCutoffMs(nowMs);
  const counts = {
    ludoSessions: 0,
    ludoPlayers: 0,
    greedyGirlBets: 0,
    greedyGirlResults: 0,
    fruitPartyBets: 0,
    fruitPartyResults: 0,
    fruitPartyLuckyWindows: 0,
    luckyPouches: 0,
    luckyPouchClaims: 0,
    luckyNumbers: 0,
  };

  // Ludo: players of expired sessions go first, then the sessions.
  try {
    counts.ludoPlayers += await deleteCount(
      db,
      `DELETE FROM ludo_room_players
        WHERE joined_at < ?
           OR room_id IN (SELECT room_id FROM ludo_room_sessions WHERE updated_at < ?)`,
      cutoff,
      cutoff,
    );
    counts.ludoSessions += await deleteCount(
      db,
      `DELETE FROM ludo_room_sessions WHERE updated_at < ?`,
      cutoff,
    );
  } catch (_) {
    // Table missing (Ludo never played) — nothing to delete.
  }

  // Greedy Girl: old bets, then old settled results.
  try {
    counts.greedyGirlBets += await deleteCount(
      db,
      `DELETE FROM greedy_girl_bets WHERE created_at < ?`,
      cutoff,
    );
    counts.greedyGirlResults += await deleteCount(
      db,
      `DELETE FROM greedy_girl_results WHERE settled_at < ?`,
      cutoff,
    );
  } catch (_) {
    // Table missing (Greedy Girl never played) — nothing to delete.
  }

  // Girls Party: old bets, old settled results, old lucky windows.
  try {
    counts.fruitPartyBets += await deleteCount(
      db,
      `DELETE FROM fruit_party_bets WHERE created_at < ?`,
      cutoff,
    );
    counts.fruitPartyResults += await deleteCount(
      db,
      `DELETE FROM fruit_party_results WHERE settled_at < ?`,
      cutoff,
    );
    counts.fruitPartyLuckyWindows += await deleteCount(
      db,
      `DELETE FROM fruit_party_lucky_windows WHERE created_at < ?`,
      cutoff,
    );
  } catch (_) {
    // Table missing (Girls Party never played) — nothing to delete.
  }

  // Lucky pouch / lucky number: claims of expired pouches go first,
  // then the pouches, then the numbers.
  try {
    counts.luckyPouchClaims += await deleteCount(
      db,
      `DELETE FROM room_lucky_pouch_claims
        WHERE created_at < ?
           OR pouch_id IN (SELECT id FROM room_lucky_pouches WHERE created_at < ?)`,
      cutoff,
      cutoff,
    );
    counts.luckyPouches += await deleteCount(
      db,
      `DELETE FROM room_lucky_pouches WHERE created_at < ?`,
      cutoff,
    );
    counts.luckyNumbers += await deleteCount(
      db,
      `DELETE FROM room_lucky_numbers WHERE created_at < ?`,
      cutoff,
    );
  } catch (_) {
    // Table missing (no lucky pouches yet) — nothing to delete.
  }

  return counts;
}
