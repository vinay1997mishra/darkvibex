const ensureMineTables = async (db) => {
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_user_id TEXT NOT NULL,
    blocked_user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (blocker_user_id, blocked_user_id)
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

export async function handleMineFeatureApi({ request, env, url, db, requireSession, json, now, id }) {
  const path = url.pathname;
  if (!path.startsWith("/api/mine/")) return null;
  await ensureMineTables(db);

  if (path === "/api/mine/guardian" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const windowDays = 30;
    const threshold = 5000000;
    const rows = await db.prepare(
      `SELECT g.sender_user_id AS user_id, u.display_name, u.avatar_key,
              SUM(g.coin_cost) AS gift_coins
         FROM gift_events g
         JOIN users u ON u.id = g.sender_user_id
        WHERE g.receiver_user_id = ? AND g.created_at >= ?
        GROUP BY g.sender_user_id, u.display_name, u.avatar_key
        ORDER BY gift_coins DESC, g.sender_user_id ASC
        LIMIT 20`
    ).bind(userId, now() - windowDays * 24 * 60 * 60 * 1000).all();
    const supporters = rows.results ?? [];
    const first = supporters[0] ?? null;
    const guardian = first && Number(first.gift_coins ?? 0) >= threshold
      ? { ...first, threshold, progress: Number(first.gift_coins ?? 0) }
      : null;
    return json({ ok: true, guardian, supporters, guardian_threshold: threshold, window_days: windowDays });
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
