import { rocketMedalObjects, userRocketMedals } from "./rocket_medal_grants.js";

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
            f.created_at,f.updated_at
       FROM family_members fm
       JOIN families f ON f.id=fm.family_id
      WHERE fm.user_id=? LIMIT 1`
  ).bind(userId).first();
}

function familyLevel(experience) {
  const thresholds = [0, 100, 500, 1500, 5000, 15000, 50000, 150000];
  let level = 1;
  for (let i = 1; i < thresholds.length; i += 1) {
    if (Number(experience || 0) >= thresholds[i]) level = i + 1;
  }
  const next = level < thresholds.length ? thresholds[level] : null;
  return { level, next_exp: next };
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
  const thresholdInfo = async (key, points) => {
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
      thresholds = [
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
    wealth: await thresholdInfo("wealth_level_thresholds", sentCoins),
    charm: await thresholdInfo("charm_level_thresholds", receivedCoins),
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
  const balance = Number(user.coins ?? 0) + Number(task.reward_coins);
  const createdAt = ts();
  await db.batch([
    db.prepare(
      "UPDATE users SET coins=?,updated_at=? WHERE id=?"
    ).bind(balance, createdAt, userId),
    db.prepare(
      "INSERT INTO user_task_claims(user_id,task_id,reward_coins,claimed_at) VALUES(?,?,?,?)"
    ).bind(userId, task.id, task.reward_coins, createdAt),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(uid("task-"), userId, "task_reward", task.reward_coins, balance, task.id, createdAt),
  ]);
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

export async function familyList(db, limitValue = 100) {
  await ensureTinniSocialSchema(db);
  const limit = Math.max(1, Math.min(100, Number(limitValue) || 100));
  const rows = await db.prepare(
    `SELECT f.id,f.name,f.tag,f.notice,f.leader_user_id,
            f.experience,f.wallet_coins,f.created_at,f.updated_at,
            u.display_name AS leader_name,u.avatar_key AS leader_avatar_key,
            COUNT(fm.user_id) AS member_count
       FROM families f
       LEFT JOIN family_members fm ON fm.family_id=f.id
       LEFT JOIN users u ON u.id=f.leader_user_id
      GROUP BY f.id
      ORDER BY f.experience DESC, member_count DESC, f.created_at ASC
      LIMIT ?`
  ).bind(limit).all();
  return (rows.results ?? []).map((row) => ({
    ...row,
    level: familyLevel(row.experience),
  }));
}

export async function familyCreate(db, userId, nameValue, tagValue) {
  await ensureTinniSocialSchema(db);
  if (await familyMembership(db, userId)) throw new Error("already_in_family");
  const name = clean(nameValue, 40);
  const tag = clean(tagValue, 12).toUpperCase();
  if (name.length < 2 || tag.length < 2) throw new Error("invalid_family_name_or_tag");
  const duplicate = await db.prepare(
    "SELECT id FROM families WHERE LOWER(name)=LOWER(?) OR UPPER(tag)=UPPER(?) LIMIT 1"
  ).bind(name, tag).first();
  if (duplicate) throw new Error("family_name_or_tag_in_use");
  const createdAt = ts();
  const familyId = uid("family-");
  await db.batch([
    db.prepare(
      "INSERT INTO families(id,name,tag,leader_user_id,notice,experience,wallet_coins,created_at,updated_at) VALUES(?,?,?,?,?,0,0,?,?)"
    ).bind(familyId,name,tag,userId,"Welcome to " + name + " ❤️",createdAt,createdAt),
    db.prepare(
      "INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,'leader',?)"
    ).bind(familyId,userId,createdAt),
  ]);
  return { ok: true, family_id: familyId };
}

export async function familyState(db, userId) {
  await ensureTinniSocialSchema(db);
  const member = await familyMembership(db, userId);
  if (!member) {
    return { family: null, members: [], join_requests: [], available_families: await familyList(db, 100) };
  }
  const members = await db.prepare(
    `SELECT fm.user_id,fm.role,fm.joined_at,u.display_name,u.avatar_key,
            CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS public_id,
            COALESCE((
              SELECT SUM(t.coins)
                FROM family_wallet_transfers t
               WHERE t.family_id=fm.family_id
                 AND t.receiver_user_id=fm.user_id
            ),0) AS received_coins
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
  const family = await db.prepare("SELECT id FROM families WHERE id=?").bind(familyId).first();
  if (!family) throw new Error("family_not_found");
  const createdAt = ts();
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
    statements.push(
      db.prepare(
        "INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,'member',?)"
      ).bind(actor.family_id,targetId,updatedAt)
    );
  }
  await db.batch(statements);
  return { ok: true, approved: Boolean(approve) };
}

export async function familySetAdmin(db, actorId, targetId, admin) {
  const actor = await familyMembership(db, actorId);
  const target = await familyMembership(db, targetId);
  if (!actor || actor.role !== "leader") throw new Error("family_leader_required");
  if (!target || target.family_id !== actor.family_id || target.role === "leader") {
    throw new Error("invalid_family_member");
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
  return { ok: true };
}

export async function familyLeave(db, userId) {
  const member = await familyMembership(db, userId);
  if (!member) return { ok: true };
  if (member.role === "leader") throw new Error("family_leader_cannot_leave");
  await db.prepare(
    "DELETE FROM family_members WHERE family_id=? AND user_id=?"
  ).bind(member.family_id,userId).run();
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
  const exp = 1;
  const createdAt = ts();
  await db.batch([
    db.prepare(
      "INSERT INTO family_daily_logins(family_id,user_id,day_key,exp_awarded,created_at) VALUES(?,?,?,?,?)"
    ).bind(member.family_id,userId,dayKey,exp,createdAt),
    db.prepare(
      "UPDATE families SET experience=experience+?,updated_at=? WHERE id=?"
    ).bind(exp,createdAt,member.family_id),
  ]);
  return { ok: true, already_checked_in: false, exp_awarded: exp };
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
      "UPDATE families SET experience=experience+?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM family_wallet_transfers WHERE id=?)"
    ).bind(amount,createdAt,sender.family_id,transferId),
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
    await db.prepare(
      `UPDATE cp_relationships
          SET disconnect_state='requested',
              disconnect_requested_by=?,
              disconnect_requested_at=?,
              updated_at=?
        WHERE user_a=? AND user_b=? AND state='active'`
    ).bind(userId,updatedAt,updatedAt,state.user_a,state.user_b).run();
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
  try {
    await db.prepare(
      `INSERT INTO cp_relationships(
        user_a,user_b,state,intimacy,level,cycle_a_to_b,cycle_b_to_a,requested_by,created_at,updated_at
      ) VALUES(?,?,'pending',0,1,0,0,?,?,?)
      ON CONFLICT(user_a,user_b) DO UPDATE SET
        state='pending',intimacy=0,level=1,cycle_a_to_b=0,cycle_b_to_a=0,
        requested_by=excluded.requested_by,activated_at=NULL,
        disconnect_state='none',disconnect_requested_by=NULL,disconnect_requested_at=NULL,
        heartbeat_state='idle',heartbeat_choice_a=NULL,heartbeat_choice_b=NULL,heartbeat_updated_at=NULL,
        created_at=excluded.created_at,updated_at=excluded.updated_at`
    ).bind(a,b,userId,createdAt,createdAt).run();
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

  if (eventId) {
    const existing = await db.prepare(
      "SELECT 1 AS recorded FROM cp_gift_progress WHERE event_id=? LIMIT 1"
    ).bind(eventId).first();
    if (existing) {
      return { progress:0, duplicate:true, cp:await cpState(db,senderUserId) };
    }
  }

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
  let nextAToB = Math.max(0, Math.floor(Number(relation.pair_a_to_b ?? relation.cycle_a_to_b ?? 0)));
  let nextBToA = Math.max(0, Math.floor(Number(relation.pair_b_to_a ?? relation.cycle_b_to_a ?? 0)));
  if (aToB) nextAToB += progress;
  if (bToA) nextBToA += progress;
  if (!Number.isSafeInteger(nextAToB) || !Number.isSafeInteger(nextBToA)) {
    throw new Error("cp_progress_limit");
  }

  let levelAfter = levelBefore;
  if (relationCanLevelUp(levelBefore,nextAToB,nextBToA)) {
    levelAfter += 1;
    nextAToB = 0;
    nextBToA = 0;
  }

  const intimacy = Math.max(0, Math.floor(Number(relation.intimacy ?? 0))) + progress;
  if (!Number.isSafeInteger(intimacy)) throw new Error("cp_progress_limit");
  const updatedAt=ts();

  await db.prepare(
    `UPDATE cp_relationships
        SET intimacy=?,level=?,cycle_a_to_b=?,cycle_b_to_a=?,updated_at=?
      WHERE user_a=? AND user_b=? AND state='active'`
  ).bind(
    intimacy,levelAfter,nextAToB,nextBToA,updatedAt,relation.user_a,relation.user_b
  ).run();

  if (eventId) {
    await db.prepare(
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
      levelAfter,
      updatedAt,
    ).run();
  }

  return {
    progress,
    level_before:levelBefore,
    level_after:levelAfter,
    level_up:levelAfter > levelBefore,
    intimacy,
    cp:await cpState(db,senderUserId),
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
