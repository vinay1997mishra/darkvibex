import { normalizeRole } from "./role_policy.js";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,PUT,DELETE,OPTIONS",
  "access-control-allow-headers": "authorization,content-type,x-file-key",
};

const json = (data, init = {}) =>
  new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...corsHeaders,
      ...(init.headers ?? {}),
    },
  });

const now = () => Date.now();
const id = () => crypto.randomUUID();
const encoder = new TextEncoder();
let schemaReady = false;

function bearerToken(request) {
  const value = String(request.headers.get("authorization") ?? "");
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}

async function bodyJson(request) {
  const value = await request.json();
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("invalid_json");
  return value;
}

async function sha256Hex(value) {
  const bytes = await crypto.subtle.digest("SHA-256", encoder.encode(String(value)));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function safeParse(value, fallback) {
  try {
    const parsed = JSON.parse(String(value ?? ""));
    return parsed == null ? fallback : parsed;
  } catch (_) {
    return fallback;
  }
}

function clampInt(value, min, max, fallback = min) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(min, Math.min(max, Math.trunc(parsed)));
}

function defaultPermissions(role) {
  if (role === "super_admin") return ["*"];
  if (role === "admin") {
    return [
      "dashboard", "users.read", "users.write", "users.moderate", "wallet.write",
      "rooms.read", "rooms.write", "catalog.read", "catalog.write",
      "settings.read", "settings.write", "announcements.read", "announcements.write",
      "staff.read", "audit.read",
    ];
  }
  if (role === "manager") {
    return [
      "dashboard", "users.read", "rooms.read", "rooms.write", "catalog.read",
      "catalog.write", "settings.read", "announcements.read", "announcements.write",
      "audit.read",
    ];
  }
  return ["dashboard", "users.read", "users.moderate", "rooms.read", "rooms.write", "audit.read"];
}

function can(actor, permission) {
  return actor.permissions.includes("*") || actor.permissions.includes(permission);
}

function requirePermission(actor, permission) {
  if (!can(actor, permission)) {
    const error = new Error("forbidden");
    error.status = 403;
    throw error;
  }
}

async function ensureOwnerSchema(db) {
  if (schemaReady) return;
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL DEFAULT '',
      avatar_key TEXT,
      role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','room_owner','room_admin','moderator','coin_seller','merchant','platform_owner')),
      coins INTEGER NOT NULL DEFAULT 0 CHECK (coins >= 0),
      diamonds INTEGER NOT NULL DEFAULT 0 CHECK (diamonds >= 0),
      vip_level INTEGER NOT NULL DEFAULT 0 CHECK (vip_level >= 0),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      seat_count INTEGER NOT NULL DEFAULT 12 CHECK (seat_count BETWEEN 8 AND 42),
      locked INTEGER NOT NULL DEFAULT 0 CHECK (locked IN (0,1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (owner_user_id) REFERENCES users(id)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS room_members (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      seat_index INTEGER,
      mic_muted INTEGER NOT NULL DEFAULT 1 CHECK (mic_muted IN (0,1)),
      joined_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS room_messages (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS direct_messages (
      id TEXT PRIMARY KEY,
      sender_user_id TEXT NOT NULL,
      receiver_user_id TEXT NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      read_at INTEGER,
      FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (receiver_user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS wallet_ledger (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      amount INTEGER NOT NULL,
      balance_after INTEGER NOT NULL,
      reference_id TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS gift_events (
      id TEXT PRIMARY KEY,
      room_id TEXT,
      sender_user_id TEXT NOT NULL,
      receiver_user_id TEXT NOT NULL,
      gift_id TEXT NOT NULL,
      coin_cost INTEGER NOT NULL CHECK (coin_cost > 0),
      created_at INTEGER NOT NULL,
      FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (receiver_user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS game_bets (
      id TEXT PRIMARY KEY,
      game_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      stake INTEGER NOT NULL CHECK (stake > 0),
      result TEXT NOT NULL,
      payout INTEGER NOT NULL DEFAULT 0 CHECK (payout >= 0),
      created_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_rooms_owner ON rooms(owner_user_id)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_room_members_room ON room_members(room_id)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_room_messages_room_time ON room_messages(room_id, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_dm_receiver_time ON direct_messages(receiver_user_id, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_wallet_user_time ON wallet_ledger(user_id, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_gifts_receiver_time ON gift_events(receiver_user_id, created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_game_bets_user_time ON game_bets(user_id, created_at DESC)"),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_controls (
      user_id TEXT PRIMARY KEY,
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','banned')),
      muted_until INTEGER,
      banned_until INTEGER,
      note TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_settings (
      key TEXT PRIMARY KEY,
      value_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_catalog (
      kind TEXT NOT NULL,
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
      sort_order INTEGER NOT NULL DEFAULT 0,
      price_coins INTEGER NOT NULL DEFAULT 0 CHECK (price_coins >= 0),
      country TEXT NOT NULL DEFAULT '',
      json_data TEXT NOT NULL DEFAULT '{}',
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (kind, id)
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_staff (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('super_admin','admin','manager','moderator')),
      token_hash TEXT NOT NULL UNIQUE,
      permissions_json TEXT NOT NULL DEFAULT '[]',
      enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      last_used_at INTEGER
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_audit (
      id TEXT PRIMARY KEY,
      actor_type TEXT NOT NULL,
      actor_id TEXT NOT NULL,
      action TEXT NOT NULL,
      target_type TEXT NOT NULL,
      target_id TEXT NOT NULL,
      summary TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_announcements (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
      starts_at INTEGER,
      ends_at INTEGER,
      country TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_catalog_kind ON owner_catalog(kind, sort_order, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_audit_time ON owner_audit(created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_announcements_time ON owner_announcements(updated_at DESC)"),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.voice', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.gifts', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.games', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.messages', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.room_creation', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.store', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.family', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.relationships', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.music', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('maintenance', '{\"enabled\":false,\"message\":\"\"}', ?)").bind(now()),
  ]);
  schemaReady = true;
}

async function authenticate(request, env, db) {
  const supplied = bearerToken(request);
  if (!supplied) return null;

  const ownerToken = String(env.OWNER_ADMIN_TOKEN ?? "").trim();
  if (ownerToken && supplied === ownerToken) {
    return { type: "owner", id: "owner", name: "Platform Owner", role: "owner", permissions: ["*"] };
  }

  const hash = await sha256Hex(supplied);
  const staff = await db.prepare(
    "SELECT id, display_name, role, permissions_json FROM owner_staff WHERE token_hash = ? AND enabled = 1 LIMIT 1"
  ).bind(hash).first();
  if (!staff) return null;

  const explicit = safeParse(staff.permissions_json, []);
  const permissions = Array.isArray(explicit) && explicit.length ? explicit.map(String) : defaultPermissions(staff.role);
  await db.prepare("UPDATE owner_staff SET last_used_at = ?, updated_at = ? WHERE id = ?")
    .bind(now(), now(), staff.id).run();
  return { type: "staff", id: staff.id, name: staff.display_name, role: staff.role, permissions };
}

async function audit(db, actor, action, targetType, targetId, summary = "") {
  await db.prepare(
    "INSERT INTO owner_audit (id, actor_type, actor_id, action, target_type, target_id, summary, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
  ).bind(id(), actor.type, actor.id, action, targetType, String(targetId ?? ""), String(summary ?? "").slice(0, 300), now()).run();
}

async function getUserDetails(db, userId) {
  const user = await db.prepare(
    `SELECT u.id, u.display_name, u.role, u.coins, u.diamonds, u.vip_level, u.avatar_key, u.created_at, u.updated_at,
            COALESCE(c.status, 'active') AS status, c.muted_until, c.banned_until, COALESCE(c.note, '') AS moderation_note
       FROM users u
       LEFT JOIN owner_user_controls c ON c.user_id = u.id
      WHERE u.id = ?`
  ).bind(userId).first();
  if (!user) return null;
  const ledger = await db.prepare(
    "SELECT id, kind, amount, balance_after, reference_id, created_at FROM wallet_ledger WHERE user_id = ? ORDER BY created_at DESC LIMIT 25"
  ).bind(userId).all();
  const room = await db.prepare(
    `SELECT m.room_id, m.seat_index, m.mic_muted, m.updated_at, r.name AS room_name
       FROM room_members m LEFT JOIN rooms r ON r.id = m.room_id
      WHERE m.user_id = ? ORDER BY m.updated_at DESC LIMIT 1`
  ).bind(userId).first();
  return { ...user, wallet_ledger: ledger.results ?? [], current_room: room ?? null };
}

async function listRooms(db, query = "") {
  const q = String(query ?? "").trim();
  const pattern = `%${q}%`;
  const result = await db.prepare(
    `SELECT r.id, r.name, r.owner_user_id, r.seat_count, r.locked, r.created_at, r.updated_at,
            COALESCE(u.display_name, '') AS owner_name,
            (SELECT COUNT(*) FROM room_members m WHERE m.room_id = r.id) AS online
       FROM rooms r
       LEFT JOIN users u ON u.id = r.owner_user_id
      WHERE (? = '' OR r.id LIKE ? OR r.name LIKE ? OR r.owner_user_id LIKE ? OR u.display_name LIKE ?)
      ORDER BY r.updated_at DESC LIMIT 200`
  ).bind(q, pattern, pattern, pattern, pattern).all();
  return result.results ?? [];
}

async function handleOverview(db, actor) {
  requirePermission(actor, "dashboard");
  const [users, rooms, online, coins, diamonds, banned, gifts, bets, roomRows, auditRows] = await Promise.all([
    db.prepare("SELECT COUNT(*) AS value FROM users").first(),
    db.prepare("SELECT COUNT(*) AS value FROM rooms").first(),
    db.prepare("SELECT COUNT(*) AS value FROM room_members").first(),
    db.prepare("SELECT COALESCE(SUM(coins),0) AS value FROM users").first(),
    db.prepare("SELECT COALESCE(SUM(diamonds),0) AS value FROM users").first(),
    db.prepare("SELECT COUNT(*) AS value FROM owner_user_controls WHERE status = 'banned'").first(),
    db.prepare("SELECT COUNT(*) AS value FROM gift_events").first(),
    db.prepare("SELECT COUNT(*) AS value FROM game_bets").first(),
    listRooms(db),
    db.prepare("SELECT actor_type, actor_id, action, target_type, target_id, summary, created_at FROM owner_audit ORDER BY created_at DESC LIMIT 12").all(),
  ]);
  return json({
    ok: true,
    actor: { id: actor.id, name: actor.name, role: actor.role, permissions: actor.permissions },
    stats: {
      users: Number(users?.value ?? 0), rooms: Number(rooms?.value ?? 0), online: Number(online?.value ?? 0),
      coins: Number(coins?.value ?? 0), diamonds: Number(diamonds?.value ?? 0), banned: Number(banned?.value ?? 0),
      gifts: Number(gifts?.value ?? 0), bets: Number(bets?.value ?? 0),
    },
    rooms: roomRows.slice(0, 30),
    audit: auditRows.results ?? [],
  });
}

async function handleUsers(request, db, actor, url, parts) {
  if (parts.length === 3 && request.method === "GET") {
    requirePermission(actor, "users.read");
    const query = String(url.searchParams.get("q") ?? "").trim();
    const limit = clampInt(url.searchParams.get("limit"), 1, 200, 100);
    const pattern = `%${query}%`;
    const rows = await db.prepare(
      `SELECT u.id, u.display_name, u.role, u.coins, u.diamonds, u.vip_level, u.updated_at,
              COALESCE(c.status,'active') AS status, c.muted_until, c.banned_until
         FROM users u LEFT JOIN owner_user_controls c ON c.user_id = u.id
        WHERE (? = '' OR u.id LIKE ? OR u.display_name LIKE ?)
        ORDER BY u.updated_at DESC LIMIT ?`
    ).bind(query, pattern, pattern, limit).all();
    return json({ ok: true, users: rows.results ?? [] });
  }

  const userId = decodeURIComponent(parts[3] ?? "");
  if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });

  if (parts.length === 4 && request.method === "GET") {
    requirePermission(actor, "users.read");
    const user = await getUserDetails(db, userId);
    return user ? json({ ok: true, user }) : json({ ok: false, error: "not_found" }, { status: 404 });
  }

  if (parts[4] === "profile" && request.method === "POST") {
    requirePermission(actor, "users.write");
    const body = await bodyJson(request);
    const current = await db.prepare("SELECT id, display_name, role, vip_level FROM users WHERE id = ?").bind(userId).first();
    if (!current) return json({ ok: false, error: "not_found" }, { status: 404 });
    const name = body.display_name == null ? current.display_name : String(body.display_name).trim().slice(0, 60);
    const role = body.role == null ? current.role : normalizeRole(body.role);
    const vip = body.vip_level == null ? Number(current.vip_level ?? 0) : clampInt(body.vip_level, 0, 11, Number(current.vip_level ?? 0));
    await db.prepare("UPDATE users SET display_name = ?, role = ?, vip_level = ?, updated_at = ? WHERE id = ?")
      .bind(name || current.display_name, role, vip, now(), userId).run();
    await audit(db, actor, "user_profile_update", "user", userId, `role=${role}; vip=${vip}`);
    return json({ ok: true, user: await getUserDetails(db, userId) });
  }

  if (parts[4] === "wallet" && request.method === "POST") {
    requirePermission(actor, "wallet.write");
    const body = await bodyJson(request);
    const current = await db.prepare("SELECT coins, diamonds FROM users WHERE id = ?").bind(userId).first();
    if (!current) return json({ ok: false, error: "not_found" }, { status: 404 });
    const coinDelta = clampInt(body.coin_delta ?? 0, -900000000000000, 900000000000000, 0);
    const diamondDelta = clampInt(body.diamond_delta ?? 0, -900000000000000, 900000000000000, 0);
    const nextCoins = Number(current.coins ?? 0) + coinDelta;
    const nextDiamonds = Number(current.diamonds ?? 0) + diamondDelta;
    if (!Number.isSafeInteger(nextCoins) || !Number.isSafeInteger(nextDiamonds) ||
        nextCoins < 0 || nextDiamonds < 0) {
      return json({ ok: false, error: "invalid_balance_change" }, { status: 400 });
    }
    const ts = now();
    const statements = [db.prepare("UPDATE users SET coins = ?, diamonds = ?, updated_at = ? WHERE id = ?").bind(nextCoins, nextDiamonds, ts, userId)];
    if (coinDelta !== 0) {
      statements.push(db.prepare(
        "INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) VALUES (?, ?, 'owner_adjustment', ?, ?, ?, ?)"
      ).bind(id(), userId, coinDelta, nextCoins, actor.id, ts));
    }
    await db.batch(statements);
    await audit(db, actor, "wallet_adjustment", "user", userId, `coins=${coinDelta}; diamonds=${diamondDelta}`);
    return json({ ok: true, coins: nextCoins, diamonds: nextDiamonds });
  }

  if (parts[4] === "moderation" && request.method === "POST") {
    if (!can(actor, "users.moderate") && !can(actor, "users.write")) requirePermission(actor, "users.moderate");
    const body = await bodyJson(request);
    const status = ["active", "suspended", "banned"].includes(String(body.status)) ? String(body.status) : "active";
    const mutedUntil = body.muted_until == null ? null : Math.max(0, Number(body.muted_until) || 0);
    const bannedUntil = body.banned_until == null ? null : Math.max(0, Number(body.banned_until) || 0);
    const note = String(body.note ?? "").trim().slice(0, 500);
    await db.prepare(
      `INSERT INTO owner_user_controls (user_id, status, muted_until, banned_until, note, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET status=excluded.status, muted_until=excluded.muted_until,
         banned_until=excluded.banned_until, note=excluded.note, updated_at=excluded.updated_at`
    ).bind(userId, status, mutedUntil, bannedUntil, note, now()).run();
    await audit(db, actor, "moderation_update", "user", userId, `status=${status}`);
    return json({ ok: true, user: await getUserDetails(db, userId) });
  }

  return null;
}

async function handleRooms(request, db, actor, url, parts) {
  if (parts.length === 3 && request.method === "GET") {
    requirePermission(actor, "rooms.read");
    return json({ ok: true, rooms: await listRooms(db, url.searchParams.get("q") ?? "") });
  }
  const roomId = decodeURIComponent(parts[3] ?? "");
  if (!roomId) return json({ ok: false, error: "room_id_required" }, { status: 400 });

  if (parts.length === 4 && request.method === "POST") {
    requirePermission(actor, "rooms.write");
    const body = await bodyJson(request);
    const room = await db.prepare("SELECT id, name, seat_count, locked FROM rooms WHERE id = ?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "not_found" }, { status: 404 });
    const name = body.name == null ? room.name : String(body.name).trim().slice(0, 80) || room.name;
    const seats = body.seat_count == null ? Number(room.seat_count) : clampInt(body.seat_count, 8, 42, Number(room.seat_count));
    const locked = body.locked == null ? Number(room.locked) : (body.locked === true ? 1 : 0);
    await db.prepare("UPDATE rooms SET name = ?, seat_count = ?, locked = ?, updated_at = ? WHERE id = ?")
      .bind(name, seats, locked, now(), roomId).run();
    await audit(db, actor, "room_update", "room", roomId, `locked=${locked}; seats=${seats}`);
    return json({ ok: true });
  }

  if (parts.length === 4 && request.method === "DELETE") {
    requirePermission(actor, "rooms.write");
    await db.prepare("DELETE FROM rooms WHERE id = ?").bind(roomId).run();
    await audit(db, actor, "room_delete", "room", roomId, "room removed");
    return json({ ok: true });
  }
  return null;
}

async function handleSettings(request, db, actor, parts) {
  if (parts.length === 3 && request.method === "GET") {
    requirePermission(actor, "settings.read");
    const rows = await db.prepare("SELECT key, value_json, updated_at FROM owner_settings ORDER BY key ASC").all();
    return json({ ok: true, settings: (rows.results ?? []).map((row) => ({ ...row, value: safeParse(row.value_json, {}) })) });
  }
  if (parts.length === 4 && request.method === "POST") {
    requirePermission(actor, "settings.write");
    const key = decodeURIComponent(parts[3]).trim().slice(0, 100);
    const body = await bodyJson(request);
    const value = body.value ?? {};
    await db.prepare(
      "INSERT INTO owner_settings (key, value_json, updated_at) VALUES (?, ?, ?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json, updated_at=excluded.updated_at"
    ).bind(key, JSON.stringify(value), now()).run();
    await audit(db, actor, "setting_update", "setting", key, "configuration updated");
    return json({ ok: true, key, value });
  }
  return null;
}

async function handleCatalog(request, db, actor, url, parts) {
  if (parts.length === 3 && request.method === "GET") {
    requirePermission(actor, "catalog.read");
    const filter = String(url.searchParams.get("kind") ?? "").trim();
    const rows = filter
      ? await db.prepare("SELECT kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at FROM owner_catalog WHERE kind = ? ORDER BY sort_order ASC, updated_at DESC").bind(filter).all()
      : await db.prepare("SELECT kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at FROM owner_catalog ORDER BY kind ASC, sort_order ASC, updated_at DESC LIMIT 500").all();
    return json({ ok: true, items: (rows.results ?? []).map((row) => ({ ...row, data: safeParse(row.json_data, {}) })) });
  }
  if (parts.length === 3 && request.method === "POST") {
    requirePermission(actor, "catalog.write");
    const body = await bodyJson(request);
    const itemKind = String(body.kind ?? "").trim().slice(0, 60);
    const itemId = String(body.id ?? "").trim().slice(0, 100) || id();
    const name = String(body.name ?? "").trim().slice(0, 120);
    if (!itemKind || !name) return json({ ok: false, error: "kind_and_name_required" }, { status: 400 });
    const enabled = body.enabled === false ? 0 : 1;
    const sortOrder = clampInt(body.sort_order ?? 0, -100000, 100000, 0);
    const priceCoins = clampInt(body.price_coins ?? 0, 0, 900000000000000, 0);
    const country = String(body.country ?? "").trim().slice(0, 20);
    const data = body.data && typeof body.data === "object" ? body.data : {};
    await db.prepare(
      `INSERT INTO owner_catalog (kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at)
       VALUES (?,?,?,?,?,?,?,?,?)
       ON CONFLICT(kind,id) DO UPDATE SET name=excluded.name, enabled=excluded.enabled,
         sort_order=excluded.sort_order, price_coins=excluded.price_coins, country=excluded.country,
         json_data=excluded.json_data, updated_at=excluded.updated_at`
    ).bind(itemKind, itemId, name, enabled, sortOrder, priceCoins, country, JSON.stringify(data), now()).run();
    await audit(db, actor, "catalog_upsert", itemKind, itemId, name);
    return json({ ok: true, id: itemId });
  }
  if (parts.length === 5 && request.method === "DELETE") {
    requirePermission(actor, "catalog.write");
    const itemKind = decodeURIComponent(parts[3]);
    const itemId = decodeURIComponent(parts[4]);
    await db.prepare("DELETE FROM owner_catalog WHERE kind = ? AND id = ?").bind(itemKind, itemId).run();
    await audit(db, actor, "catalog_delete", itemKind, itemId, "item removed");
    return json({ ok: true });
  }
  return null;
}

async function handleAnnouncements(request, db, actor, parts) {
  if (parts.length === 3 && request.method === "GET") {
    requirePermission(actor, "announcements.read");
    const rows = await db.prepare(
      "SELECT id,title,body,enabled,starts_at,ends_at,country,created_at,updated_at FROM owner_announcements ORDER BY updated_at DESC LIMIT 200"
    ).all();
    return json({ ok: true, announcements: rows.results ?? [] });
  }
  if (parts.length === 3 && request.method === "POST") {
    requirePermission(actor, "announcements.write");
    const body = await bodyJson(request);
    const announcementId = String(body.id ?? "").trim() || id();
    const title = String(body.title ?? "").trim().slice(0, 120);
    const message = String(body.body ?? "").trim().slice(0, 2000);
    if (!title || !message) return json({ ok: false, error: "title_and_body_required" }, { status: 400 });
    const ts = now();
    await db.prepare(
      `INSERT INTO owner_announcements (id,title,body,enabled,starts_at,ends_at,country,created_at,updated_at)
       VALUES (?,?,?,?,?,?,?,?,?)
       ON CONFLICT(id) DO UPDATE SET title=excluded.title, body=excluded.body, enabled=excluded.enabled,
         starts_at=excluded.starts_at, ends_at=excluded.ends_at, country=excluded.country, updated_at=excluded.updated_at`
    ).bind(
      announcementId, title, message, body.enabled === false ? 0 : 1,
      body.starts_at == null ? null : Number(body.starts_at), body.ends_at == null ? null : Number(body.ends_at),
      String(body.country ?? "").trim().slice(0, 20), ts, ts,
    ).run();
    await audit(db, actor, "announcement_upsert", "announcement", announcementId, title);
    return json({ ok: true, id: announcementId });
  }
  if (parts.length === 4 && request.method === "DELETE") {
    requirePermission(actor, "announcements.write");
    const announcementId = decodeURIComponent(parts[3]);
    await db.prepare("DELETE FROM owner_announcements WHERE id = ?").bind(announcementId).run();
    await audit(db, actor, "announcement_delete", "announcement", announcementId, "announcement removed");
    return json({ ok: true });
  }
  return null;
}

async function handleStaff(request, db, actor, parts) {
  if (parts.length === 3 && request.method === "GET") {
    requirePermission(actor, "staff.read");
    const rows = await db.prepare(
      "SELECT id,display_name,role,permissions_json,enabled,created_at,updated_at,last_used_at FROM owner_staff ORDER BY created_at DESC"
    ).all();
    return json({ ok: true, staff: (rows.results ?? []).map((row) => ({ ...row, permissions: safeParse(row.permissions_json, []) })) });
  }
  if (parts.length === 3 && request.method === "POST") {
    requirePermission(actor, "staff.write");
    const body = await bodyJson(request);
    const displayName = String(body.display_name ?? "").trim().slice(0, 80);
    const role = ["super_admin", "admin", "manager", "moderator"].includes(String(body.role)) ? String(body.role) : "manager";
    if (!displayName) return json({ ok: false, error: "display_name_required" }, { status: 400 });
    const staffId = id();
    const raw = crypto.getRandomValues(new Uint8Array(24));
    const token = "dvx_" + [...raw].map((byte) => byte.toString(16).padStart(2, "0")).join("");
    const tokenHash = await sha256Hex(token);
    const permissions = Array.isArray(body.permissions) ? body.permissions.map(String) : defaultPermissions(role);
    const ts = now();
    await db.prepare(
      "INSERT INTO owner_staff (id,display_name,role,token_hash,permissions_json,enabled,created_at,updated_at,last_used_at) VALUES (?,?,?,?,?,1,?,?,NULL)"
    ).bind(staffId, displayName, role, tokenHash, JSON.stringify(permissions), ts, ts).run();
    await audit(db, actor, "staff_create", "staff", staffId, `${displayName}; role=${role}`);
    return json({ ok: true, staff: { id: staffId, display_name: displayName, role, permissions }, token });
  }

  const staffId = decodeURIComponent(parts[3] ?? "");
  if (!staffId) return null;
  if (parts.length === 4 && request.method === "POST") {
    requirePermission(actor, "staff.write");
    const body = await bodyJson(request);
    const current = await db.prepare("SELECT id,display_name,role,permissions_json,enabled FROM owner_staff WHERE id = ?").bind(staffId).first();
    if (!current) return json({ ok: false, error: "not_found" }, { status: 404 });
    const displayName = body.display_name == null ? current.display_name : String(body.display_name).trim().slice(0, 80) || current.display_name;
    const role = body.role == null ? current.role : (["super_admin", "admin", "manager", "moderator"].includes(String(body.role)) ? String(body.role) : current.role);
    const permissions = Array.isArray(body.permissions) ? body.permissions.map(String) : safeParse(current.permissions_json, defaultPermissions(role));
    const enabled = body.enabled == null ? Number(current.enabled) : (body.enabled === true ? 1 : 0);
    await db.prepare("UPDATE owner_staff SET display_name=?,role=?,permissions_json=?,enabled=?,updated_at=? WHERE id=?")
      .bind(displayName, role, JSON.stringify(permissions), enabled, now(), staffId).run();
    await audit(db, actor, "staff_update", "staff", staffId, `${displayName}; role=${role}; enabled=${enabled}`);
    return json({ ok: true });
  }
  if (parts.length === 4 && request.method === "DELETE") {
    requirePermission(actor, "staff.write");
    if (actor.type === "staff" && actor.id === staffId) return json({ ok: false, error: "cannot_delete_current_staff" }, { status: 400 });
    await db.prepare("DELETE FROM owner_staff WHERE id = ?").bind(staffId).run();
    await audit(db, actor, "staff_delete", "staff", staffId, "staff removed");
    return json({ ok: true });
  }
  return null;
}

async function handleAudit(request, db, actor, url) {
  if (request.method !== "GET") return null;
  requirePermission(actor, "audit.read");
  const limit = clampInt(url.searchParams.get("limit"), 1, 500, 100);
  const rows = await db.prepare(
    "SELECT id,actor_type,actor_id,action,target_type,target_id,summary,created_at FROM owner_audit ORDER BY created_at DESC LIMIT ?"
  ).bind(limit).all();
  return json({ ok: true, audit: rows.results ?? [] });
}

export async function handleOwnerApi(request, env, url) {
  if (!env.OWNER_ADMIN_TOKEN) {
    return json({ ok: false, error: "owner_token_not_configured" }, { status: 503 });
  }
  if (!env.DB) return json({ ok: false, error: "database_not_bound" }, { status: 503 });
  const db = env.DB;

  try {
    await ensureOwnerSchema(db);
    const actor = await authenticate(request, env, db);
    if (!actor) return json({ ok: false, error: "unauthorized" }, { status: 401 });
    const parts = url.pathname.split("/").filter(Boolean);

    if (url.pathname === "/api/owner/session" && request.method === "GET") {
      return json({ ok: true, actor: { id: actor.id, name: actor.name, role: actor.role, permissions: actor.permissions } });
    }
    if (url.pathname === "/api/owner/overview" && request.method === "GET") return handleOverview(db, actor);

    let response = null;
    if (parts[2] === "users") response = await handleUsers(request, db, actor, url, parts);
    else if (parts[2] === "rooms") response = await handleRooms(request, db, actor, url, parts);
    else if (parts[2] === "settings") response = await handleSettings(request, db, actor, parts);
    else if (parts[2] === "catalog") response = await handleCatalog(request, db, actor, url, parts);
    else if (parts[2] === "announcements") response = await handleAnnouncements(request, db, actor, parts);
    else if (parts[2] === "staff") response = await handleStaff(request, db, actor, parts);
    else if (parts[2] === "audit") response = await handleAudit(request, db, actor, url);
    if (response) return response;

    return json({ ok: false, error: "not_found" }, { status: 404 });
  } catch (error) {
    const message = String(error?.message ?? error);
    return json({ ok: false, error: message }, { status: Number(error?.status ?? 400) });
  }
}
