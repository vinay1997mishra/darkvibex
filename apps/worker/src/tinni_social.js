const ts = () => Date.now();
const uid = (prefix = "") => prefix + crypto.randomUUID();

export async function ensureTinniSocialSchema(db) {
  const statements = [
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
    `CREATE TABLE IF NOT EXISTS cp_relationships (
      user_a TEXT NOT NULL,
      user_b TEXT NOT NULL,
      state TEXT NOT NULL DEFAULT 'pending',
      intimacy INTEGER NOT NULL DEFAULT 0,
      level INTEGER NOT NULL DEFAULT 1,
      requested_by TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (user_a, user_b)
    )`,
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
    `SELECT u.id,u.display_name,u.avatar_key,f.created_at
       FROM user_follows f JOIN users u ON u.id=f.follower_id
      WHERE f.target_id=? ORDER BY f.created_at DESC LIMIT 300`
  ).bind(userId).all();
  return rows.results ?? [];
}

export async function listFollowing(db, userId) {
  await ensureTinniSocialSchema(db);
  const rows = await db.prepare(
    `SELECT u.id,u.display_name,u.avatar_key,f.created_at
       FROM user_follows f JOIN users u ON u.id=f.target_id
      WHERE f.follower_id=? ORDER BY f.created_at DESC LIMIT 300`
  ).bind(userId).all();
  return rows.results ?? [];
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
    `SELECT fm.user_id,fm.role,fm.joined_at,u.display_name,u.avatar_key
       FROM family_members fm JOIN users u ON u.id=fm.user_id
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

export async function cpState(db, userId) {
  await ensureTinniSocialSchema(db);
  const row = await db.prepare(
    `SELECT c.*,ua.display_name AS user_a_name,ua.avatar_key AS user_a_avatar_key,
            ub.display_name AS user_b_name,ub.avatar_key AS user_b_avatar_key
       FROM cp_relationships c
       LEFT JOIN users ua ON ua.id=c.user_a
       LEFT JOIN users ub ON ub.id=c.user_b
      WHERE c.user_a=? OR c.user_b=?
      ORDER BY c.updated_at DESC LIMIT 1`
  ).bind(userId,userId).first();
  return row ?? null;
}

export async function cpRequest(db, userId, targetId) {
  await ensureTinniSocialSchema(db);
  if (!targetId || userId === targetId) throw new Error("invalid_cp_target");
  const existing = await cpState(db,userId);
  if (existing && existing.state === "active") throw new Error("cp_already_active");
  const targetExisting = await cpState(db,targetId);
  if (targetExisting && targetExisting.state === "active") throw new Error("target_cp_already_active");
  const [a,b] = pair(userId,targetId);
  const createdAt=ts();
  await db.prepare(
    `INSERT INTO cp_relationships(user_a,user_b,state,intimacy,level,requested_by,created_at,updated_at)
     VALUES(?,?,'pending',0,1,?,?,?)
     ON CONFLICT(user_a,user_b) DO UPDATE SET
       state='pending',requested_by=excluded.requested_by,updated_at=excluded.updated_at`
  ).bind(a,b,userId,createdAt,createdAt).run();
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
      "UPDATE cp_relationships SET state='active',updated_at=? WHERE user_a=? AND user_b=?"
    ).bind(ts(),row.user_a,row.user_b).run();
  } else {
    await db.prepare(
      "DELETE FROM cp_relationships WHERE user_a=? AND user_b=?"
    ).bind(row.user_a,row.user_b).run();
  }
  return accept ? cpState(db,userId) : null;
}

export async function cpDisconnect(db, userId) {
  const row = await cpState(db,userId);
  if (!row) return { ok: true };
  await db.prepare(
    "DELETE FROM cp_relationships WHERE user_a=? AND user_b=?"
  ).bind(row.user_a,row.user_b).run();
  return { ok: true };
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
      ORDER BY c.intimacy DESC,c.updated_at ASC LIMIT ?`
  ).bind(limit).all();
  return rows.results ?? [];
}
