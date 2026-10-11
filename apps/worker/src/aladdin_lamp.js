export const LAMP_BONUS_PERCENT = 5;

export const LAMP_TASKS = Object.freeze([
  { id: "host_invite_mic_1", title: "Successfully invited 1 user to mic by host", reward_coins: 11360, target: 1, action: "invite_mic", icon: "mic" },
  { id: "host_invite_mic_10", title: "Successfully invited 10 users to mic by host", reward_coins: 15440, target: 10, action: "invite_mic", icon: "mic" },
  { id: "host_invite_new_mic_3", title: "Successfully invited 3 new users to mic by host", reward_coins: 15440, target: 3, action: "invite_mic", icon: "mic" },
  { id: "host_gift_1", title: "Sending gift by host for once", reward_coins: 11360, target: 1, action: "host_gift", icon: "gift" },
  { id: "host_gift_10", title: "Sending gifts by host for 10 times", reward_coins: 15440, target: 10, action: "host_gift", icon: "gift" },
  { id: "host_gift_new_users_3", title: "Sending gifts by host to 3 new users", reward_coins: 15440, target: 3, action: "host_gift", icon: "gift" },
  { id: "room_gifters_5", title: "5 users in the room sending gifts today", reward_coins: 23600, target: 5, action: "room_activity", icon: "gift" },
  { id: "new_room_gifters_3", title: "3 new users in the room sending gifts today", reward_coins: 23600, target: 3, action: "room_activity", icon: "gift" },
  { id: "room_followers_1", title: "1 new follower of the room", reward_coins: 11360, target: 1, action: "share_room", icon: "people" },
  { id: "room_followers_10", title: "10 new followers of the room", reward_coins: 15440, target: 10, action: "share_room", icon: "people" },
  { id: "new_room_followers_3", title: "3 new users followed the room", reward_coins: 15440, target: 3, action: "share_room", icon: "people" },
  { id: "share_whatsapp", title: "Successfully shared room link to WhatsApp by host", reward_coins: 15440, target: 1, action: "share_whatsapp", icon: "share" },
  { id: "share_facebook", title: "Successfully shared room link to Facebook by host", reward_coins: 15440, target: 1, action: "share_facebook", icon: "share" },
  { id: "room_entries_10", title: "10 users entered the room", reward_coins: 11360, target: 10, action: "share_room", icon: "people" },
  { id: "new_room_entries_3", title: "3 new users entered the room", reward_coins: 15440, target: 3, action: "share_room", icon: "people" },
  { id: "consecutive_visitors_5", title: "More than 5 users have entered your room for 2 consecutive days", reward_coins: 23600, target: 5, action: "share_room", icon: "people" },
  { id: "three_users_mic_1m", title: "3 users mic at the same time for 1 minute", reward_coins: 11360, target: 60, action: "mic_time", icon: "mic" },
  { id: "three_users_mic_10m", title: "3 users mic at the same time for 10 minutes", reward_coins: 15440, target: 600, action: "mic_time", icon: "mic" },
  { id: "three_new_users_mic_5m", title: "3 new users mic at the same time for 5 minutes", reward_coins: 23600, target: 300, action: "mic_time", icon: "mic" },
  { id: "host_mic_10m", title: "The host mic for 10 minutes", reward_coins: 11360, target: 600, action: "host_mic", icon: "mic" },
  { id: "host_mic_30m", title: "The host mic for 30 minutes", reward_coins: 15440, target: 1800, action: "host_mic", icon: "mic" },
  { id: "host_mic_60m", title: "The host mic for 60 minutes", reward_coins: 23600, target: 3600, action: "host_mic", icon: "mic" },
]);

const TASKS = new Map(LAMP_TASKS.map((task) => [task.id, task]));
const DAY_MS = 86400000;
let schemaReady = false;
const dayKey = (ts = Date.now()) => Math.floor(Number(ts) / DAY_MS);
const dayStart = (ts = Date.now()) => dayKey(ts) * DAY_MS;

export async function ensureLampSchema(db) {
  if (schemaReady) return;
  await db.batch([
    db.prepare("CREATE TABLE IF NOT EXISTS lamp_task_progress (room_id TEXT NOT NULL, day_key INTEGER NOT NULL, task_id TEXT NOT NULL, progress INTEGER NOT NULL DEFAULT 0, claimed_at INTEGER, updated_at INTEGER NOT NULL, PRIMARY KEY (room_id, day_key, task_id))"),
    db.prepare("CREATE TABLE IF NOT EXISTS lamp_daily_uniques (room_id TEXT NOT NULL, day_key INTEGER NOT NULL, scope TEXT NOT NULL, user_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (room_id, day_key, scope, user_id))"),
    db.prepare("CREATE TABLE IF NOT EXISTS lamp_room_user_first_seen (room_id TEXT NOT NULL, user_id TEXT NOT NULL, first_seen_at INTEGER NOT NULL, PRIMARY KEY (room_id, user_id))"),
    db.prepare("CREATE TABLE IF NOT EXISTS lamp_room_user_days (room_id TEXT NOT NULL, user_id TEXT NOT NULL, day_key INTEGER NOT NULL, first_entered_at INTEGER NOT NULL, PRIMARY KEY (room_id, user_id, day_key))"),
    db.prepare("CREATE TABLE IF NOT EXISTS room_followers (room_id TEXT NOT NULL, user_id TEXT NOT NULL, followed_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY (room_id, user_id))"),
    db.prepare("CREATE TABLE IF NOT EXISTS lamp_mic_invites (room_id TEXT NOT NULL, day_key INTEGER NOT NULL, invitee_user_id TEXT NOT NULL, invited_by_user_id TEXT NOT NULL, invited_at INTEGER NOT NULL, accepted_at INTEGER, PRIMARY KEY (room_id, day_key, invitee_user_id))"),
    db.prepare("CREATE TABLE IF NOT EXISTS lamp_room_clock (room_id TEXT NOT NULL, day_key INTEGER NOT NULL, last_sample_at INTEGER NOT NULL, PRIMARY KEY (room_id, day_key))"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_lamp_progress_room_day ON lamp_task_progress(room_id, day_key)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_lamp_user_days_room_day ON lamp_room_user_days(room_id, day_key)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_room_followers_room ON room_followers(room_id)")
  ]);
  schemaReady = true;
}

async function ownerOf(db, roomId) {
  const row = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
  return row?.owner_user_id ? String(row.owner_user_id) : "";
}

async function increment(db, roomId, taskId, amount, ts = Date.now()) {
  const task = TASKS.get(taskId);
  const delta = Math.max(0, Math.floor(Number(amount) || 0));
  if (!task || !delta) return;
  const day = dayKey(ts);
  await db.prepare(
    "INSERT INTO lamp_task_progress (room_id,day_key,task_id,progress,claimed_at,updated_at) VALUES (?,?,?,?,NULL,?) " +
    "ON CONFLICT(room_id,day_key,task_id) DO UPDATE SET progress=MIN(?,lamp_task_progress.progress+excluded.progress),updated_at=excluded.updated_at"
  ).bind(roomId, day, taskId, Math.min(task.target, delta), ts, task.target).run();
}

async function unique(db, roomId, scope, taskIds, userId, ts = Date.now()) {
  const result = await db.prepare(
    "INSERT OR IGNORE INTO lamp_daily_uniques (room_id,day_key,scope,user_id,created_at) VALUES (?,?,?,?,?)"
  ).bind(roomId, dayKey(ts), scope, userId, ts).run();
  if (Number(result?.meta?.changes ?? 0) <= 0) return false;
  for (const taskId of taskIds) await increment(db, roomId, taskId, 1, ts);
  return true;
}

async function markFirstSeen(db, roomId, userId, ts) {
  const result = await db.prepare(
    "INSERT OR IGNORE INTO lamp_room_user_first_seen (room_id,user_id,first_seen_at) VALUES (?,?,?)"
  ).bind(roomId, userId, ts).run();
  if (Number(result?.meta?.changes ?? 0) > 0) return true;
  return isNewToday(db, roomId, userId, ts);
}

async function isNewToday(db, roomId, userId, ts) {
  const row = await db.prepare(
    "SELECT first_seen_at FROM lamp_room_user_first_seen WHERE room_id=? AND user_id=?"
  ).bind(roomId, userId).first();
  const first = Number(row?.first_seen_at ?? 0);
  return first >= dayStart(ts) && first < dayStart(ts) + DAY_MS;
}

export async function recordLampRoomEntry(db, roomId, userId, ts = Date.now()) {
  await ensureLampSchema(db);
  const ownerId = await ownerOf(db, roomId);
  if (!ownerId || !userId) return;
  const isNew = await markFirstSeen(db, roomId, userId, ts);
  const day = dayKey(ts);
  const entered = await db.prepare(
    "INSERT OR IGNORE INTO lamp_room_user_days (room_id,user_id,day_key,first_entered_at) VALUES (?,?,?,?)"
  ).bind(roomId, userId, day, ts).run();
  if (userId === ownerId || Number(entered?.meta?.changes ?? 0) <= 0) return;
  await unique(db, roomId, "room_entry", ["room_entries_10"], userId, ts);
  if (isNew) await unique(db, roomId, "new_room_entry", ["new_room_entries_3"], userId, ts);
  const yesterday = await db.prepare(
    "SELECT 1 AS yes FROM lamp_room_user_days WHERE room_id=? AND user_id=? AND day_key=? LIMIT 1"
  ).bind(roomId, userId, day - 1).first();
  if (yesterday) await unique(db, roomId, "consecutive_visitor", ["consecutive_visitors_5"], userId, ts);
}

export async function recordLampGiftActivity(db, roomId, senderId, receiverId, ts = Date.now()) {
  if (!roomId) return;
  await ensureLampSchema(db);
  const ownerId = await ownerOf(db, roomId);
  if (!ownerId) return;
  if (senderId === ownerId) {
    await increment(db, roomId, "host_gift_1", 1, ts);
    await increment(db, roomId, "host_gift_10", 1, ts);
    if (receiverId && receiverId !== ownerId && await isNewToday(db, roomId, receiverId, ts)) {
      await unique(db, roomId, "host_gift_new_user", ["host_gift_new_users_3"], receiverId, ts);
    }
    return;
  }
  if (!senderId) return;
  await unique(db, roomId, "room_gifter", ["room_gifters_5"], senderId, ts);
  if (await isNewToday(db, roomId, senderId, ts)) {
    await unique(db, roomId, "new_room_gifter", ["new_room_gifters_3"], senderId, ts);
  }
}

export async function recordLampRoomFollow(db, roomId, userId, follow, ts = Date.now()) {
  await ensureLampSchema(db);
  const ownerId = await ownerOf(db, roomId);
  if (!ownerId || !userId || userId === ownerId) return false;
  if (!follow) {
    await db.prepare("DELETE FROM room_followers WHERE room_id=? AND user_id=?").bind(roomId, userId).run();
    return false;
  }
  await db.prepare(
    "INSERT INTO room_followers (room_id,user_id,followed_at,updated_at) VALUES (?,?,?,?) " +
    "ON CONFLICT(room_id,user_id) DO UPDATE SET updated_at=excluded.updated_at"
  ).bind(roomId, userId, ts, ts).run();
  const firstToday = await unique(db, roomId, "room_follower", ["room_followers_1","room_followers_10"], userId, ts);
  if (firstToday && await isNewToday(db, roomId, userId, ts)) {
    await unique(db, roomId, "new_room_follower", ["new_room_followers_3"], userId, ts);
  }
  return true;
}

export async function roomFollowState(db, roomId, userId) {
  await ensureLampSchema(db);
  return Boolean(await db.prepare(
    "SELECT 1 AS yes FROM room_followers WHERE room_id=? AND user_id=? LIMIT 1"
  ).bind(roomId, userId).first());
}

export async function recordLampRoomShare(db, roomId, userId, platform, ts = Date.now()) {
  await ensureLampSchema(db);
  if (await ownerOf(db, roomId) !== userId) throw new Error("room_owner_required");
  const taskId = platform === "facebook" ? "share_facebook" : platform === "whatsapp" ? "share_whatsapp" : "";
  if (!taskId) throw new Error("unsupported_share_platform");
  await increment(db, roomId, taskId, 1, ts);
}

export async function createLampMicInvite(db, roomId, hostId, inviteeId, ts = Date.now()) {
  await ensureLampSchema(db);
  if (await ownerOf(db, roomId) !== hostId) throw new Error("room_owner_required");
  if (!inviteeId || inviteeId === hostId) throw new Error("invalid_invitee");
  const member = await db.prepare(
    "SELECT seat_index FROM room_members WHERE room_id=? AND user_id=?"
  ).bind(roomId, inviteeId).first();
  if (!member) throw new Error("invitee_not_in_room");
  if (member.seat_index != null) throw new Error("invitee_already_on_mic");
  await db.prepare(
    "INSERT INTO lamp_mic_invites (room_id,day_key,invitee_user_id,invited_by_user_id,invited_at,accepted_at) VALUES (?,?,?,?,?,NULL) " +
    "ON CONFLICT(room_id,day_key,invitee_user_id) DO UPDATE SET invited_by_user_id=excluded.invited_by_user_id,invited_at=excluded.invited_at WHERE lamp_mic_invites.accepted_at IS NULL"
  ).bind(roomId, dayKey(ts), inviteeId, hostId, ts).run();
}

export async function acceptPendingLampMicInvite(db, roomId, userId, ts = Date.now()) {
  await ensureLampSchema(db);
  const result = await db.prepare(
    "UPDATE lamp_mic_invites SET accepted_at=? WHERE room_id=? AND day_key=? AND invitee_user_id=? AND accepted_at IS NULL"
  ).bind(ts, roomId, dayKey(ts), userId).run();
  if (Number(result?.meta?.changes ?? 0) <= 0) return false;
  await unique(db, roomId, "accepted_mic_invite", ["host_invite_mic_1","host_invite_mic_10"], userId, ts);
  if (await isNewToday(db, roomId, userId, ts)) {
    await unique(db, roomId, "accepted_new_mic_invite", ["host_invite_new_mic_3"], userId, ts);
  }
  return true;
}

export async function sampleLampMicProgress(db, roomId, ts = Date.now()) {
  await ensureLampSchema(db);
  const ownerId = await ownerOf(db, roomId);
  if (!ownerId) return;
  const day = dayKey(ts);
  const clock = await db.prepare(
    "SELECT last_sample_at FROM lamp_room_clock WHERE room_id=? AND day_key=?"
  ).bind(roomId, day).first();
  if (!clock) {
    await db.prepare("INSERT INTO lamp_room_clock (room_id,day_key,last_sample_at) VALUES (?,?,?)")
      .bind(roomId, day, ts).run();
    return;
  }
  const previous = Math.max(day * DAY_MS, Number(clock.last_sample_at ?? ts));
  const seconds = Math.max(0, Math.floor((ts - previous) / 1000));
  await db.prepare("UPDATE lamp_room_clock SET last_sample_at=? WHERE room_id=? AND day_key=?")
    .bind(ts, roomId, day).run();
  if (!seconds) return;
  const rows = await db.prepare(
    "SELECT user_id FROM room_members WHERE room_id=? AND seat_index IS NOT NULL AND mic_muted=0"
  ).bind(roomId).all();
  const active = (rows.results ?? []).map((row) => String(row.user_id));
  if (active.includes(ownerId)) {
    for (const taskId of ["host_mic_10m","host_mic_30m","host_mic_60m"]) await increment(db, roomId, taskId, seconds, ts);
  }
  if (active.length >= 3) {
    await increment(db, roomId, "three_users_mic_1m", seconds, ts);
    await increment(db, roomId, "three_users_mic_10m", seconds, ts);
    let newUsers = 0;
    for (const userId of active) {
      if (userId !== ownerId && await isNewToday(db, roomId, userId, ts)) newUsers += 1;
      if (newUsers >= 3) break;
    }
    if (newUsers >= 3) await increment(db, roomId, "three_new_users_mic_5m", seconds, ts);
  }
}

export async function getLampStatus(db, roomId, viewerId, ts = Date.now()) {
  await ensureLampSchema(db);
  await sampleLampMicProgress(db, roomId, ts);
  const ownerId = await ownerOf(db, roomId);
  if (!ownerId) throw new Error("room_not_found");
  const day = dayKey(ts);
  const rows = await db.prepare(
    "SELECT task_id,progress,claimed_at FROM lamp_task_progress WHERE room_id=? AND day_key=?"
  ).bind(roomId, day).all();
  const progress = new Map((rows.results ?? []).map((row) => [String(row.task_id), row]));
  return {
    room_id: roomId,
    owner_user_id: ownerId,
    is_host: viewerId === ownerId,
    bonus_percent: LAMP_BONUS_PERCENT,
    day_key: day,
    reset_at: (day + 1) * DAY_MS,
    tasks: LAMP_TASKS.map((task) => {
      const row = progress.get(task.id);
      const value = Math.max(0, Math.min(task.target, Number(row?.progress ?? 0)));
      return { ...task, progress: value, completed: value >= task.target, claimed: row?.claimed_at != null, claimed_at: row?.claimed_at ?? null };
    })
  };
}

export async function claimLampTask(db, roomId, userId, taskId, ts = Date.now()) {
  await ensureLampSchema(db);
  await sampleLampMicProgress(db, roomId, ts);
  if (await ownerOf(db, roomId) !== userId) throw new Error("room_owner_required");
  const task = TASKS.get(String(taskId));
  if (!task) throw new Error("lamp_task_not_found");
  const day = dayKey(ts);
  const row = await db.prepare(
    "SELECT progress,claimed_at FROM lamp_task_progress WHERE room_id=? AND day_key=? AND task_id=?"
  ).bind(roomId, day, task.id).first();
  if (Number(row?.progress ?? 0) < task.target) throw new Error("lamp_task_incomplete");
  if (row?.claimed_at != null) throw new Error("lamp_task_already_claimed");
  const locked = await db.prepare(
    "UPDATE lamp_task_progress SET claimed_at=?,updated_at=? WHERE room_id=? AND day_key=? AND task_id=? AND claimed_at IS NULL"
  ).bind(ts, ts, roomId, day, task.id).run();
  if (Number(locked?.meta?.changes ?? 0) <= 0) throw new Error("lamp_task_already_claimed");

  const bonus = Math.floor(task.reward_coins * LAMP_BONUS_PERCENT / 100);
  const payout = task.reward_coins + bonus;
  try {
    const user = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
    if (!user) throw new Error("user_not_found");
    const next = Number(user.coins ?? 0) + payout;
    await db.batch([
      db.prepare("UPDATE users SET coins=?,updated_at=? WHERE id=?").bind(next, ts, userId),
      db.prepare("INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES (?,?,\'aladdin_lamp_reward\',?,?,?,?)")
        .bind(crypto.randomUUID(), userId, payout, next, roomId + ":" + day + ":" + task.id, ts)
    ]);
    return { task_id: task.id, reward_coins: task.reward_coins, bonus_coins: bonus, payout_coins: payout, coin_balance: next };
  } catch (error) {
    await db.prepare(
      "UPDATE lamp_task_progress SET claimed_at=NULL,updated_at=? WHERE room_id=? AND day_key=? AND task_id=? AND claimed_at=?"
    ).bind(Date.now(), roomId, day, task.id, ts).run();
    throw error;
  }
}
