// DarkVibeX — Message Backup Retention (45 days, last 100 kept)
//
// Message backup rule (Vinay, 2026-11-19): "Msg ka backup rahega 45
// days ka baaki app me hi save hoga app delete hoga to old msg delete
// ho jayenge" — the server keeps a backup of messages for 45 days
// only. After 45 days the backup is deleted. The rest lives in the
// app itself (local), so deleting the app deletes the old messages
// with it.
//
// Retention increase (Vinay, 2026-11-22): "server per bhi last
// 100msg rahenge delete nhi honge" — the last 100 messages of every
// conversation / room are NEVER deleted, even past the 45-day window.
// "Retention badha de" — retention is increased, not shortened: the
// 45-day cleanup only ever deletes messages beyond the last 100.
//
// What this module does (server side):
// - Every day the scheduled worker deletes messages older than 45
//   days from D1: direct_messages, room_messages, game_room_messages,
//   EXCEPT the last 100 messages of each conversation / room.
// - Their image rows (direct_message_images, room_message_images) go
//   too, and the image files are deleted from the public R2 bucket
//   (FILES) so message media does not pile up forever.
// - VIP chat history (vip_support_messages) and system/inbox envelopes
//   are NOT touched — this is only chat messages.
//
// The 45-day cutoff is a fixed policy, not a VIP perk: it applies to
// everyone, VIP or not. (The separate VIP message_retention_days
// setting in /api/messages/thread only controls how far back the app
// LOADS, not what the server keeps — and it is capped at 45 days.)

/// The server keeps a backup of chat messages for this many days.
export const MESSAGE_BACKUP_DAYS = 45;

/// Milliseconds in the 45-day backup window.
export const MESSAGE_BACKUP_WINDOW_MS =
  MESSAGE_BACKUP_DAYS * 24 * 60 * 60 * 1000;

/// How many of the newest messages of each conversation / room are
/// never deleted, even past the 45-day backup window (Vinay,
/// 2026-11-22: "server per bhi last 100msg rahenge delete nhi honge").
export const MESSAGE_KEEP_LAST_COUNT = 100;

/// SQL fragment excluding the newest [MESSAGE_KEEP_LAST_COUNT] rows of
/// the conversation / room the outer row belongs to. [table] is the
/// messages table; [scope] correlates the inner alias `keep` to the
/// outer row (it must reference the outer table by name, e.g.
/// `keep.room_id = room_messages.room_id`). The id tiebreaker keeps
/// the "last 100" deterministic when several messages share one
/// created_at timestamp.
function keepLastSql(table, scope) {
  return `id NOT IN (SELECT id FROM ${table} AS keep WHERE ${scope} ORDER BY keep.created_at DESC, keep.id DESC LIMIT ${MESSAGE_KEEP_LAST_COUNT})`;
}

/// A direct conversation is the unordered sender/receiver pair — a
/// message from A to B and a message from B to A belong to the same
/// conversation, so the last 100 span both directions.
const DM_SCOPE =
  `(keep.sender_user_id = direct_messages.sender_user_id AND keep.receiver_user_id = direct_messages.receiver_user_id) ` +
  `OR (keep.sender_user_id = direct_messages.receiver_user_id AND keep.receiver_user_id = direct_messages.sender_user_id)`;

/// The cutoff timestamp: messages with created_at < this are past the
/// 45-day backup and are deleted. [nowMs] defaults to Date.now().
export function messageBackupCutoffMs(nowMs = Date.now()) {
  return nowMs - MESSAGE_BACKUP_WINDOW_MS;
}

/// Deletes chat messages older than the 45-day backup window from D1
/// and their image files from R2 (FILES bucket), EXCEPT the last 100
/// messages of each conversation / room, which are never deleted.
/// [db] is the D1 binding, [env] carries FILES (may be absent in
/// tests — R2 deletes are then skipped). Returns the counts deleted.
/// Best-effort on the R2 deletes: a failed file delete never stops
/// the D1 cleanup.
export async function expireOldMessages(db, env, nowMs = Date.now()) {
  const cutoff = messageBackupCutoffMs(nowMs);
  const counts = { direct: 0, room: 0, gameRoom: 0, images: 0 };

  const dmKeep = keepLastSql("direct_messages", DM_SCOPE);
  const roomKeep = keepLastSql("room_messages", "keep.room_id = room_messages.room_id");
  const gameRoomKeep = keepLastSql("game_room_messages", "keep.room_id = game_room_messages.room_id");

  // Collect the image keys of the expiring messages first — the
  // image rows are deleted with their messages, so the keys must be
  // read before the DELETEs run. The same last-100 exclusion applies:
  // images of kept messages are never deleted from R2.
  //
  // CP invite DMs are exempt (Vinay, 2026-11-20): the invite DM and its
  // Accept/Reject buttons stay permanently — the pop-up reads the CP
  // row, but the DM record IS the invite. All cp_invite* kinds
  // (cp_invite, cp_invite_accepted, cp_invite_rejected) survive the
  // 45-day cleanup, and so do their image rows.
  const dmImages = await db
    .prepare(
      `SELECT image_key FROM direct_message_images
        WHERE message_id IN
          (SELECT id FROM direct_messages WHERE created_at < ? AND kind NOT LIKE 'cp_invite%' AND ${dmKeep})`,
    )
    .bind(cutoff)
    .all();
  const roomImages = await db
    .prepare(
      `SELECT image_key FROM room_message_images
        WHERE message_id IN
          (SELECT id FROM room_messages WHERE created_at < ? AND ${roomKeep})`,
    )
    .bind(cutoff)
    .all();
  const imageKeys = [
    ...((dmImages.results ?? []).map((row) => String(row.image_key ?? ""))),
    ...((roomImages.results ?? []).map((row) => String(row.image_key ?? ""))),
  ].filter((key) => key.length > 0);

  const dm = await db
    .prepare(`DELETE FROM direct_messages WHERE created_at < ? AND kind NOT LIKE 'cp_invite%' AND ${dmKeep}`)
    .bind(cutoff)
    .run();
  counts.direct = Number(dm.meta?.changes ?? 0);
  const rm = await db
    .prepare(`DELETE FROM room_messages WHERE created_at < ? AND ${roomKeep}`)
    .bind(cutoff)
    .run();
  counts.room = Number(rm.meta?.changes ?? 0);
  const grm = await db
    .prepare(`DELETE FROM game_room_messages WHERE created_at < ? AND ${gameRoomKeep}`)
    .bind(cutoff)
    .run();
  counts.gameRoom = Number(grm.meta?.changes ?? 0);

  // Image rows are cleaned up by their message deletes where the
  // schema cascades; delete any stragglers explicitly.
  await db
    .prepare(
      "DELETE FROM direct_message_images WHERE message_id NOT IN (SELECT id FROM direct_messages)",
    )
    .run();
  await db
    .prepare(
      "DELETE FROM room_message_images WHERE message_id NOT IN (SELECT id FROM room_messages)",
    )
    .run();

  if (env?.FILES) {
    for (const key of imageKeys) {
      try {
        await env.FILES.delete(key);
        counts.images += 1;
      } catch (_) {
        // Best-effort: a missing file never stops the cleanup.
      }
    }
  }
  return counts;
}
