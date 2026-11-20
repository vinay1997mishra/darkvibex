// Shared room teardown (worker audit 2026-11-20): deleting a room must
// remove every row scoped to it, or the rows orphan — and a later room
// with the same id (room ids are the owner's permanent public id)
// inherits stale admins, bans, messages and lamp state. Tables for a
// feature the room never used may not exist yet, so they are skipped via
// sqlite_master instead of failing the delete.
const ROOM_TABLES = [
  "room_members",
  "room_settings",
  "room_images",
  "room_followers",
  "room_admins",
  "room_bans",
  "room_reports",
  "room_chat_bans",
  "room_seat_controls",
  "room_seat_requests",
  "room_seat_invites",
  "room_kick_events",
  "room_custom_themes",
  "room_lucky_pouch_claims",
  "room_lucky_pouches",
  "room_messages",
  "lamp_task_progress",
  "lamp_daily_uniques",
  "lamp_room_user_first_seen",
  "lamp_room_user_days",
  "lamp_mic_invites",
  "lamp_room_clock",
];

export async function deleteRoomRows(db, roomId, files = null) {
  // room_message_images is keyed by message_id, not room_id, so it is
  // looked up with the rest but deleted by its own subquery below.
  const tables = [...ROOM_TABLES, "room_message_images"];
  const existing = await db.prepare(
    `SELECT name FROM sqlite_master WHERE type='table' AND name IN (${tables.map(() => "?").join(",")})`
  ).bind(...tables).all();
  const present = new Set((existing.results ?? []).map((row) => String(row.name)));
  // The room avatar key (for the caller's best-effort R2 delete): the
  // room_images rows are deleted below, so read it first.
  let avatarKey = "";
  if (present.has("room_images")) {
    const avatarRow = await db.prepare(
      "SELECT image_key FROM room_images WHERE room_id = ? LIMIT 1"
    ).bind(roomId).first();
    avatarKey = String(avatarRow?.image_key ?? "").trim();
  }
  // Message image files on R2 (best-effort): the DB rows are deleted
  // below, so collect the keys first.
  let messageImageKeys = [];
  if (files && present.has("room_message_images") && present.has("room_messages")) {
    const rows = await db.prepare(
      "SELECT image_key FROM room_message_images WHERE message_id IN (SELECT id FROM room_messages WHERE room_id=?)"
    ).bind(roomId).all();
    messageImageKeys = (rows.results ?? [])
      .map((row) => String(row?.image_key ?? "").trim())
      .filter(Boolean);
  }
  const statements = [];
  for (const table of ROOM_TABLES) {
    if (!present.has(table)) continue;
    statements.push(db.prepare(`DELETE FROM ${table} WHERE room_id = ?`).bind(roomId));
  }
  if (present.has("room_message_images") && present.has("room_messages")) {
    statements.push(db.prepare(
      "DELETE FROM room_message_images WHERE message_id IN (SELECT id FROM room_messages WHERE room_id=?)"
    ).bind(roomId));
  }
  statements.push(db.prepare("DELETE FROM rooms WHERE id = ?").bind(roomId));
  await db.batch(statements);
  for (const key of messageImageKeys) {
    try {
      await files.delete(key);
    } catch (_) {}
  }
  return { avatarKey };
}
