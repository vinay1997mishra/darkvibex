import { getIdLevelStatus } from "./id_level.js";
import { getVipStatus } from "./vip_store.js";

const ensureProfileFields = async (db) => {
  const rows = await db.prepare("PRAGMA table_info(users)").all();
  const columns = new Set((rows.results ?? []).map((row) => String(row.name)));
  if (!columns.has("country_code")) await db.prepare("ALTER TABLE users ADD COLUMN country_code TEXT NOT NULL DEFAULT ''").run();
  if (!columns.has("gender")) await db.prepare("ALTER TABLE users ADD COLUMN gender TEXT NOT NULL DEFAULT ''").run();
};

const ensureMineTables = async (db) => {
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_user_id TEXT NOT NULL,
    blocked_user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (blocker_user_id, blocked_user_id)
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS account_identities (
    user_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    subject TEXT NOT NULL,
    email TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    PRIMARY KEY (provider, subject),
    UNIQUE (user_id, provider)
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_follows (
    follower_user_id TEXT NOT NULL,
    followed_user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (follower_user_id, followed_user_id)
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS family_members (
    family_id TEXT NOT NULL, user_id TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK(role IN ('leader','admin','member')),
    joined_at INTEGER NOT NULL, PRIMARY KEY(family_id,user_id)
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_task_claims (
    user_id TEXT NOT NULL,
    task_id TEXT NOT NULL,
    reward_coins INTEGER NOT NULL,
    claimed_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, task_id)
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_feedback (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    category TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'received',
    created_at INTEGER NOT NULL
  )`).run();
};

export async function handleMineFeatureApi({ request, env, url, db, requireSession, json, now, id, walletChange, verifyGoogleIdToken }) {
  const path = url.pathname;
  if (!path.startsWith("/api/mine/")) return null;
  await ensureMineTables(db);

  if (path === "/api/mine/wealth" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const spent = await db.prepare(
      "SELECT COALESCE(SUM(coin_cost),0) AS total FROM gift_events WHERE sender_user_id = ?"
    ).bind(userId).first();
    const setting = await db.prepare("SELECT value_json FROM owner_settings WHERE key = ?").bind("wealth_level_thresholds").first();
    let thresholds = [];
    try {
      const parsed = JSON.parse(String(setting?.value_json ?? "[]"));
      if (Array.isArray(parsed)) thresholds = parsed.map((v) => Math.max(0, Number(v ?? 0))).filter(Number.isFinite).sort((a,b) => a-b);
    } catch (_) {}
    const lifetimeSent = Math.max(0, Number(spent?.total ?? 0));
    let level = 0;
    while (level < thresholds.length && lifetimeSent >= thresholds[level]) level += 1;
    return json({ ok: true, lifetime_sent_coins: lifetimeSent, wealth: { level, next_threshold: thresholds[level] ?? null, thresholds } });
  }

  if (path === "/api/mine/tasks" && request.method === "GET") {
    await ensureProfileFields(db);
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const user = await db.prepare("SELECT display_name,country_code,gender FROM users WHERE id = ?").bind(userId).first();
    if (!user) return json({ ok: false, error: "user_not_found" }, { status: 404 });
    const checks = await Promise.all([
      db.prepare("SELECT COUNT(*) AS count FROM user_follows WHERE follower_user_id = ?").bind(userId).first(),
      db.prepare("SELECT COUNT(*) AS count FROM lamp_room_user_first_seen WHERE user_id = ?").bind(userId).first(),
      db.prepare("SELECT COUNT(*) AS count FROM gift_events WHERE sender_user_id = ?").bind(userId).first(),
      db.prepare("SELECT COUNT(*) AS count FROM family_members WHERE user_id = ?").bind(userId).first(),
      db.prepare("SELECT task_id FROM user_task_claims WHERE user_id = ?").bind(userId).all(),
    ]);
    const completed = [
      Boolean(String(user.display_name ?? "").trim() && String(user.country_code ?? "").trim() && String(user.gender ?? "").trim()),
      Number(checks[0].count ?? 0) > 0,
      Number(checks[1].count ?? 0) > 0,
      Number(checks[2].count ?? 0) > 0,
      Number(checks[3].count ?? 0) > 0,
    ];
    const definitions = [
      { id: "profile_complete", title: "Complete your profile", reward_coins: 100 },
      { id: "follow_one", title: "Follow 1 user", reward_coins: 100 },
      { id: "enter_room", title: "Enter a Party room", reward_coins: 100 },
      { id: "send_gift", title: "Send your first gift", reward_coins: 200 },
      { id: "join_family", title: "Join a Family", reward_coins: 300 },
    ];
    const claims = new Set((checks[4].results ?? []).map((row) => String(row.task_id)));
    const tasks = definitions.map((task, i) => ({ ...task, completed: completed[i], claimed: claims.has(task.id) }));
    return json({ ok: true, tasks });
  }

  if (path === "/api/mine/tasks/claim" && request.method === "POST") {
    const body = await request.json();
    const userId = String(body.user_id ?? "").trim();
    const taskId = String(body.task_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const rows = await db.prepare("SELECT task_id FROM user_task_claims WHERE user_id = ?").bind(userId).all();
    const definition = [
      { id: "profile_complete", reward_coins: 100, title: "Complete your profile" },
      { id: "follow_one", reward_coins: 100, title: "Follow 1 user" },
      { id: "enter_room", reward_coins: 100, title: "Enter a Party room" },
      { id: "send_gift", reward_coins: 200, title: "Send your first gift" },
      { id: "join_family", reward_coins: 300, title: "Join a Family" },
    ].find((task) => task.id === taskId);
    if (!definition) return json({ ok: false, error: "task_not_found" }, { status: 404 });
    const stateResponse = await handleMineFeatureApi({ request: new Request(url.origin + "/api/mine/tasks?user_id=" + encodeURIComponent(userId), { headers: request.headers }), env, url: new URL(url.origin + "/api/mine/tasks?user_id=" + encodeURIComponent(userId)), db, requireSession, json, now, id, walletChange });
    const state = await stateResponse.json();
    const task = (state.tasks ?? []).find((row) => row.id === taskId);
    if (!task?.completed) return json({ ok: false, error: "task_incomplete" }, { status: 400 });
    if ((rows.results ?? []).some((row) => String(row.task_id) === taskId)) return json({ ok: false, error: "task_already_claimed" }, { status: 409 });
    const createdAt = now();
    await walletChange(db, userId, definition.reward_coins, "task_reward", "task:" + taskId);
    await db.prepare("INSERT INTO user_task_claims (user_id,task_id,reward_coins,claimed_at) VALUES (?,?,?,?)")
      .bind(userId, taskId, definition.reward_coins, createdAt).run();
    const updated = await db.prepare("SELECT coins,diamonds FROM users WHERE id = ?").bind(userId).first();
    const taskList = await handleMineFeatureApi({ request: new Request(url.origin + "/api/mine/tasks?user_id=" + encodeURIComponent(userId), { headers: request.headers }), env, url: new URL(url.origin + "/api/mine/tasks?user_id=" + encodeURIComponent(userId)), db, requireSession, json, now, id, walletChange });
    return json({ ok: true, task: { ...definition, completed: true, claimed: true }, tasks: (await taskList.json()).tasks, wallet: updated });
  }

  if (path === "/api/mine/medals" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const user = await db.prepare("SELECT vip_level FROM users WHERE id = ?").bind(userId).first();
    const vip = await getVipStatus(db, userId);
    const idLevel = await getIdLevelStatus(db, userId);
    const medals = [];
    if (vip.active && Number(vip.level) > 0) medals.push({ name: "VIP " + Number(vip.level), color: "#FFD54F" });
    if (Number(idLevel.level ?? 0) > 0) medals.push({ name: "ID Level " + Number(idLevel.level), color: "#66BB6A" });
    if (!medals.length && Number(user?.vip_level ?? 0) > 0) medals.push({ name: "VIP " + Number(user.vip_level), color: "#FFD54F" });
    return json({ ok: true, medals });
  }

  if (path === "/api/mine/feedback" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const result = await db.prepare(
      "SELECT id,category,message,status,created_at FROM user_feedback WHERE user_id = ? ORDER BY created_at DESC LIMIT 100"
    ).bind(userId).all();
    return json({ ok: true, feedback: result.results ?? [] });
  }

  if (path === "/api/mine/feedback" && request.method === "POST") {
    const body = await request.json();
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const category = String(body.category ?? "General").trim().slice(0, 40);
    const message = String(body.message ?? "").trim().slice(0, 4000);
    if (!category || message.length < 3) {
      return json({ ok: false, error: "feedback_required" }, { status: 400 });
    }
    const feedbackId = id();
    const createdAt = now();
    await db.prepare(
      "INSERT INTO user_feedback (id,user_id,category,message,status,created_at) VALUES (?,?,?,?,'received',?)"
    ).bind(feedbackId, userId, category, message, createdAt).run();
    return json({ ok: true, feedback: { id: feedbackId, category, message, status: "received", created_at: createdAt } }, { status: 201 });
  }

  if (path === "/api/mine/account-identities" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const result = await db.prepare(
      "SELECT provider,subject,email,created_at FROM account_identities WHERE user_id = ? ORDER BY created_at"
    ).bind(userId).all();
    return json({ ok: true, identities: result.results ?? [] });
  }

  if (path === "/api/mine/account-identities/google" && request.method === "POST") {
    const body = await request.json();
    const userId = String(body.user_id ?? "").trim();
    const idToken = String(body.id_token ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    let claims;
    try {
      claims = await verifyGoogleIdToken(idToken, env.GOOGLE_WEB_CLIENT_ID);
    } catch (error) {
      const code = String(error?.message ?? error);
      const status = code === "google_auth_not_configured" ? 503 : 401;
      return json({ ok: false, error: code }, { status });
    }
    const subject = String(claims.sub ?? "");
    const existing = await db.prepare("SELECT user_id FROM account_identities WHERE provider = 'google' AND subject = ?")
      .bind(subject).first();
    if (existing && String(existing.user_id) !== userId) {
      return json({ ok: false, error: "google_account_already_linked" }, { status: 409 });
    }
    await db.prepare("INSERT OR IGNORE INTO account_identities (user_id,provider,subject,email,created_at) VALUES (?,'google',?,?,?)")
      .bind(userId, subject, String(claims.email ?? ""), now()).run();
    const result = await db.prepare("SELECT provider,subject,email,created_at FROM account_identities WHERE user_id = ? ORDER BY created_at")
      .bind(userId).all();
    return json({ ok: true, identities: result.results ?? [] });
  }

  if (path === "/api/mine/follow" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const targetId = String(url.searchParams.get("target_user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!targetId) return json({ ok: false, error: "target_user_id_required" }, { status: 400 });
    const row = await db.prepare("SELECT 1 AS following FROM user_follows WHERE follower_user_id = ? AND followed_user_id = ?")
      .bind(userId, targetId).first();
    return json({ ok: true, following: Boolean(row) });
  }

  if (path === "/api/mine/follow" && request.method === "POST") {
    const body = await request.json();
    const userId = String(body.user_id ?? "").trim();
    const targetId = String(body.target_user_id ?? "").trim();
    const followed = body.followed === true;
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!targetId || targetId === userId) return json({ ok: false, error: "invalid_target" }, { status: 400 });
    const target = await db.prepare("SELECT 1 AS found FROM users WHERE id = ?").bind(targetId).first();
    if (!target) return json({ ok: false, error: "user_not_found" }, { status: 404 });
    if (followed) {
      await db.prepare("INSERT OR IGNORE INTO user_follows (follower_user_id,followed_user_id,created_at) VALUES (?,?,?)")
        .bind(userId, targetId, now()).run();
    } else {
      await db.prepare("DELETE FROM user_follows WHERE follower_user_id = ? AND followed_user_id = ?")
        .bind(userId, targetId).run();
    }
    return json({ ok: true, following: followed });
  }

  if (path === "/api/mine/blocks" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const result = await db.prepare(
      `SELECT b.blocked_user_id AS id, u.display_name, u.avatar_key, b.created_at
         FROM user_blocks b LEFT JOIN users u ON u.id = b.blocked_user_id
        WHERE b.blocker_user_id = ? ORDER BY b.created_at DESC`
    ).bind(userId).all();
    return json({ ok: true, blocked: result.results ?? [] });
  }

  if (path === "/api/mine/blocks" && request.method === "POST") {
    const body = await request.json();
    const userId = String(body.user_id ?? "").trim();
    const targetId = String(body.target_user_id ?? "").trim();
    const blocked = body.blocked === true;
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!targetId || targetId === userId) return json({ ok: false, error: "invalid_target" }, { status: 400 });
    if (blocked) {
      await db.prepare("INSERT OR IGNORE INTO user_blocks (blocker_user_id,blocked_user_id,created_at) VALUES (?,?,?)")
        .bind(userId, targetId, now()).run();
    } else {
      await db.prepare("DELETE FROM user_blocks WHERE blocker_user_id = ? AND blocked_user_id = ?")
        .bind(userId, targetId).run();
    }
    return json({ ok: true, blocked });
  }

  return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
}
