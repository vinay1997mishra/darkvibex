import { normalizeRole } from "./role_policy.js";
import { ensureSupportSchema } from "./support_store.js";
import { adjustRoleWallet, roleWalletDetail } from "./role_wallets.js";
import { COSMETIC_CATALOG } from "./cosmetics.js";
import { BASE_GIFT_CATALOG, DARKVIBE_EXTRA_GIFTS } from "./gift_catalog.js";
import { BASE_UNIQUE_ID_CATALOG } from "./unique_id_store.js";

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
      "treasury.read", "economy.read",
      "support.read", "support.write",
      "notifications.read", "notifications.write",
      "messaging.read", "messaging.write", "tags.write",
      "users.device", "users.override", "wallet.freeze",
      "rooms.read", "rooms.write", "rooms.live", "rooms.media", "rooms.theme",
      "roles.read", "roles.write", "banners.read", "banners.write",
      "games.read", "games.write", "policies.read", "policies.write",
      "catalog.read", "catalog.write",
      "settings.read", "settings.write", "announcements.read", "announcements.write",
      "staff.read", "audit.read",
    ];
  }
  if (role === "manager") {
    return [
      "dashboard", "users.read", "economy.read", "rooms.read", "rooms.write", "rooms.live",
      "notifications.read", "messaging.read", "roles.read", "banners.read", "games.read", "policies.read",
      "catalog.read", "catalog.write", "settings.read", "announcements.read", "announcements.write",
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
      public_id TEXT,
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
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_public_id_history (
      user_id TEXT NOT NULL,
      public_id TEXT NOT NULL,
      changed_at INTEGER NOT NULL,
      changed_by TEXT NOT NULL,
      PRIMARY KEY (user_id, public_id)
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_old_public_id ON owner_public_id_history(public_id)"),
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
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_treasury (
      id TEXT PRIMARY KEY,
      balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0),
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_treasury_ledger (
      id TEXT PRIMARY KEY,
      amount INTEGER NOT NULL,
      balance_after INTEGER NOT NULL CHECK (balance_after >= 0),
      kind TEXT NOT NULL,
      target_user_id TEXT,
      actor_id TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_treasury_ledger_time ON owner_treasury_ledger(created_at DESC)"),
    db.prepare("INSERT OR IGNORE INTO owner_treasury (id, balance, updated_at) VALUES ('main', 0, ?)").bind(now()),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_catalog_kind ON owner_catalog(kind, sort_order, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_audit_time ON owner_audit(created_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_announcements_time ON owner_announcements(updated_at DESC)"),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.voice', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.gifts', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.games', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.messages', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('feature.room_creation', '{\"enabled\":true}', ?)").bind(now()),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_notifications (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL DEFAULT 'platform',
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      user_id TEXT,
      read_at INTEGER,
      created_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_notifications_time ON owner_notifications(created_at DESC)"),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_overrides (
      user_id TEXT PRIMARY KEY,
      invisible_id INTEGER NOT NULL DEFAULT 0 CHECK(invisible_id IN (0,1)),
      locked_room_bypass INTEGER NOT NULL DEFAULT 0 CHECK(locked_room_bypass IN (0,1)),
      wallet_frozen INTEGER NOT NULL DEFAULT 0 CHECK(wallet_frozen IN (0,1)),
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_device_bans (
      device_key TEXT PRIMARY KEY,
      user_id TEXT,
      banned INTEGER NOT NULL DEFAULT 1 CHECK(banned IN (0,1)),
      note TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_device_bans_user ON owner_device_bans(user_id,updated_at DESC)"),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_devices (
      device_key TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      last_seen_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_user_devices_user ON owner_user_devices(user_id,last_seen_at DESC)"),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_tags (
      user_id TEXT NOT NULL,
      tag_id TEXT NOT NULL,
      name TEXT NOT NULL,
      color TEXT NOT NULL DEFAULT '#FFD54F',
      kind TEXT NOT NULL DEFAULT 'custom',
      designation TEXT NOT NULL DEFAULT '',
      background_color TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY(user_id,tag_id)
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_user_tags_kind ON owner_user_tags(kind,designation,updated_at DESC)"),
    db.prepare(`CREATE TRIGGER IF NOT EXISTS owner_wallet_freeze_guard
      BEFORE UPDATE OF coins ON users
      WHEN NEW.coins < OLD.coins
       AND EXISTS(
         SELECT 1 FROM owner_user_overrides o
          WHERE o.user_id=OLD.id AND o.wallet_frozen=1
       )
      BEGIN
        SELECT RAISE(ABORT,'wallet_frozen');
      END`),
    db.prepare(`CREATE TABLE IF NOT EXISTS room_images (
      room_id TEXT PRIMARY KEY,
      image_key TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS room_settings (
      room_id TEXT PRIMARY KEY,
      announcement TEXT NOT NULL DEFAULT '',
      theme_id TEXT NOT NULL DEFAULT 'dark',
      group_pk_enabled INTEGER NOT NULL DEFAULT 0,
      welcome_image_key TEXT NOT NULL DEFAULT '',
      party_mode TEXT NOT NULL DEFAULT 'Friends-making Party',
      room_mode TEXT NOT NULL DEFAULT 'voice',
      seat_theme_id TEXT NOT NULL DEFAULT 'royal-gold',
      mic_mode TEXT NOT NULL DEFAULT 'free',
      public_screen_enabled INTEGER NOT NULL DEFAULT 1,
      lock_password_hash TEXT NOT NULL DEFAULT '',
      lock_password_code TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS room_custom_themes (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      owner_user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      asset_key TEXT NOT NULL,
      price_coins INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      expires_at INTEGER
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS push_devices (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      device_key TEXT NOT NULL DEFAULT '',
      platform TEXT NOT NULL DEFAULT 'android',
      enabled INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_push_devices_owner_user ON push_devices(user_id,updated_at DESC)"),
    db.prepare(`INSERT OR IGNORE INTO users
      (id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at)
      VALUES('darkvibex_official',NULL,'DarkVibeX Official','platform_owner',0,0,0,?,?)`).bind(now(),now()),
    db.prepare("INSERT OR IGNORE INTO owner_settings (key, value_json, updated_at) VALUES ('maintenance', '{\"enabled\":false,\"message\":\"\"}', ?)").bind(now()),
  ]);
  try {
    const pushInfo = await db.prepare("PRAGMA table_info(push_devices)").all();
    const pushColumns = new Set((pushInfo.results ?? []).map((row) => String(row.name ?? "")));
    if (!pushColumns.has("device_key")) {
      await db.prepare("ALTER TABLE push_devices ADD COLUMN device_key TEXT NOT NULL DEFAULT ''").run();
    }
  } catch (_) {}
  try {
    const roomSettingsInfo = await db.prepare("PRAGMA table_info(room_settings)").all();
    const roomSettingsColumns = new Set((roomSettingsInfo.results ?? []).map((row) => String(row.name ?? "")));
    const roomSettingsAdditions = [
      ["announcement", "TEXT NOT NULL DEFAULT ''"],
      ["theme_id", "TEXT NOT NULL DEFAULT 'dark'"],
      ["group_pk_enabled", "INTEGER NOT NULL DEFAULT 0"],
      ["welcome_image_key", "TEXT NOT NULL DEFAULT ''"],
      ["party_mode", "TEXT NOT NULL DEFAULT 'Friends-making Party'"],
      ["room_mode", "TEXT NOT NULL DEFAULT 'voice'"],
      ["seat_theme_id", "TEXT NOT NULL DEFAULT 'royal-gold'"],
      ["mic_mode", "TEXT NOT NULL DEFAULT 'free'"],
      ["public_screen_enabled", "INTEGER NOT NULL DEFAULT 1"],
      ["lock_password_hash", "TEXT NOT NULL DEFAULT ''"],
      ["lock_password_code", "TEXT NOT NULL DEFAULT ''"],
      ["updated_at", "INTEGER NOT NULL DEFAULT 0"],
    ];
    for (const [name, definition] of roomSettingsAdditions) {
      if (!roomSettingsColumns.has(name)) {
        await db.prepare(`ALTER TABLE room_settings ADD COLUMN ${name} ${definition}`).run();
      }
    }
  } catch (_) {}
  const userInfo = await db.prepare("PRAGMA table_info(users)").all();
  const userColumns = new Set((userInfo.results ?? []).map((row) => String(row.name ?? "")));
  if (!userColumns.has("public_id")) {
    await db.prepare("ALTER TABLE users ADD COLUMN public_id TEXT").run();
  }
  await db.prepare("CREATE UNIQUE INDEX IF NOT EXISTS idx_owner_users_public_id ON users(public_id) WHERE public_id IS NOT NULL AND public_id <> ''").run();
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
    `SELECT u.id, u.public_id, u.display_name, u.role, u.coins, u.diamonds, u.vip_level, u.avatar_key, u.created_at, u.updated_at,
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
  const role_wallets = {};
  if (user.role === "coin_seller" || user.role === "merchant") {
    try {
      role_wallets[user.role] = await roleWalletDetail(db,userId,user.role,25,now());
    } catch (_) {}
  }
  const oldIds = await db.prepare(
    "SELECT public_id, changed_at, changed_by FROM owner_public_id_history WHERE user_id = ? ORDER BY changed_at DESC LIMIT 25"
  ).bind(userId).all();
  const overrides = await db.prepare(
    "SELECT invisible_id,locked_room_bypass,wallet_frozen,updated_at FROM owner_user_overrides WHERE user_id=?"
  ).bind(userId).first();
  const devices = await db.prepare(
    `SELECT d.device_key,
            COALESCE(
              (SELECT p.token FROM push_devices p
                WHERE p.user_id=d.user_id
                  AND (p.device_key=d.device_key OR p.token=d.device_key)
                ORDER BY p.updated_at DESC LIMIT 1),
              ''
            ) AS token,
            COALESCE(
              (SELECT p.platform FROM push_devices p
                WHERE p.user_id=d.user_id
                  AND (p.device_key=d.device_key OR p.token=d.device_key)
                ORDER BY p.updated_at DESC LIMIT 1),
              'android'
            ) AS platform,
            COALESCE(
              (SELECT p.enabled FROM push_devices p
                WHERE p.user_id=d.user_id
                  AND (p.device_key=d.device_key OR p.token=d.device_key)
                ORDER BY p.updated_at DESC LIMIT 1),
              1
            ) AS enabled,
            d.last_seen_at AS updated_at,
            COALESCE(b.banned,0) AS banned,
            COALESCE(b.note,'') AS ban_note
       FROM owner_user_devices d
       LEFT JOIN owner_device_bans b ON b.device_key=d.device_key
      WHERE d.user_id=?
      ORDER BY d.last_seen_at DESC LIMIT 20`
  ).bind(userId).all();
  const tags = await db.prepare(
    "SELECT tag_id,name,color,kind,designation,background_color,updated_at FROM owner_user_tags WHERE user_id=? ORDER BY updated_at DESC"
  ).bind(userId).all();
  return {
    ...user,
    wallet_ledger: ledger.results ?? [],
    role_wallets,
    old_public_ids: oldIds.results ?? [],
    current_room: room ?? null,
    owner_overrides: overrides ?? {invisible_id:0,locked_room_bypass:0,wallet_frozen:0},
    devices: devices.results ?? [],
    tags: tags.results ?? [],
  };
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
  const treasury = await db.prepare("SELECT balance FROM owner_treasury WHERE id = 'main'").first();
  return json({
    ok: true,
    actor: { id: actor.id, name: actor.name, role: actor.role, permissions: actor.permissions },
    stats: {
      users: Number(users?.value ?? 0), rooms: Number(rooms?.value ?? 0), online: Number(online?.value ?? 0),
      coins: Number(coins?.value ?? 0), diamonds: Number(diamonds?.value ?? 0), banned: Number(banned?.value ?? 0),
      gifts: Number(gifts?.value ?? 0), bets: Number(bets?.value ?? 0),
      treasury: Number(treasury?.balance ?? 0),
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
      `SELECT u.id, u.public_id, u.display_name, u.role, u.coins, u.diamonds, u.vip_level, u.updated_at,
              COALESCE(c.status,'active') AS status, c.muted_until, c.banned_until
         FROM users u LEFT JOIN owner_user_controls c ON c.user_id = u.id
        WHERE (? = '' OR u.id LIKE ? OR COALESCE(u.public_id,'') LIKE ? OR u.display_name LIKE ?
          OR EXISTS (SELECT 1 FROM owner_public_id_history h WHERE h.user_id = u.id AND h.public_id LIKE ?))
        ORDER BY u.updated_at DESC LIMIT ?`
    ).bind(query, pattern, pattern, pattern, pattern, limit).all();
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
    const vip = body.vip_level == null ? Number(current.vip_level ?? 0) : clampInt(body.vip_level, 0, 18, Number(current.vip_level ?? 0));
    const changedAt = now();
    await db.prepare("UPDATE users SET display_name = ?, role = ?, vip_level = ?, updated_at = ? WHERE id = ?")
      .bind(name || current.display_name, role, vip, changedAt, userId).run();
    if (body.vip_level != null && vip !== Number(current.vip_level ?? 0)) {
      try {
        const activeUntil = vip > 0
          ? changedAt + (vip >= 18 ? 45 : 30) * 24 * 60 * 60 * 1000
          : null;
        await db.prepare("UPDATE user_vip SET level = ?, active_until = ?, updated_at = ? WHERE user_id = ?")
          .bind(vip, activeUntil, changedAt, userId).run();
      } catch (error) {
        if (!String(error?.message ?? error).includes("no such table")) throw error;
      }
    }
    await audit(db, actor, "user_profile_update", "user", userId, `role=${role}; vip=${vip}`);
    return json({ ok: true, user: await getUserDetails(db, userId) });
  }

  if (parts[4] === "public-id" && request.method === "POST") {
    requirePermission(actor, "users.write");
    const body = await bodyJson(request);
    const requested = String(body.public_id ?? "").trim();
    if (!/^\d{7}$/.test(requested) || Number(requested) < 1000001) {
      return json({ ok: false, error: "public_id_must_be_1000001_to_9999999" }, { status: 400 });
    }
    const current = await db.prepare("SELECT public_id FROM users WHERE id = ?").bind(userId).first();
    if (!current) return json({ ok: false, error: "not_found" }, { status: 404 });
    const taken = await db.prepare("SELECT id FROM users WHERE public_id = ? AND id <> ? LIMIT 1").bind(requested, userId).first();
    if (taken) return json({ ok: false, error: "public_id_already_used" }, { status: 409 });
    const reserved = await db.prepare("SELECT user_id FROM owner_public_id_history WHERE public_id = ? AND user_id <> ? LIMIT 1").bind(requested, userId).first();
    if (reserved) return json({ ok: false, error: "public_id_reserved_by_history" }, { status: 409 });
    try {
      const custom = await db.prepare("SELECT user_id FROM user_vip WHERE custom_id = ? AND user_id <> ? LIMIT 1").bind(requested, userId).first();
      if (custom) return json({ ok: false, error: "public_id_owned_by_another_user" }, { status: 409 });
    } catch (error) {
      if (!String(error?.message ?? error).includes("no such table")) throw error;
    }
    try {
      const purchase = await db.prepare("SELECT buyer_user_id FROM unique_id_purchases WHERE public_id = ? AND buyer_user_id <> ? LIMIT 1").bind(requested, userId).first();
      if (purchase) return json({ ok: false, error: "public_id_owned_by_another_user" }, { status: 409 });
    } catch (error) {
      if (!String(error?.message ?? error).includes("no such table")) throw error;
    }
    const previous = String(current.public_id ?? "").trim();
    const ts = now();
    const statements = [
      db.prepare("UPDATE users SET public_id = ?, updated_at = ? WHERE id = ?").bind(requested, ts, userId),
    ];
    if (previous && previous !== requested) {
      statements.push(
        db.prepare("INSERT OR IGNORE INTO owner_public_id_history (user_id, public_id, changed_at, changed_by) VALUES (?, ?, ?, ?)")
          .bind(userId, previous, ts, actor.id)
      );
    }
    await db.batch(statements);
    await audit(db, actor, "public_id_change", "user", userId, `old=${previous || "-"}; new=${requested}`);
    return json({ ok: true, public_id: requested, old_public_id: previous || null });
  }

  if (parts[4] === "wallet" && request.method === "POST") {
    requirePermission(actor, "wallet.write");
    const body = await bodyJson(request);
    const current = await db.prepare("SELECT role,coins,diamonds FROM users WHERE id=?")
      .bind(userId).first();
    if (!current) return json({ ok:false,error:"not_found" }, { status:404 });

    const coinDelta=clampInt(body.coin_delta ?? 0,-900000000000000,900000000000000,0);
    const diamondDelta=clampInt(body.diamond_delta ?? 0,-900000000000000,900000000000000,0);
    const nextCoins=Number(current.coins ?? 0)+coinDelta;
    const nextDiamonds=Number(current.diamonds ?? 0)+diamondDelta;
    if(!Number.isSafeInteger(nextCoins)||!Number.isSafeInteger(nextDiamonds)||
       nextCoins<0||nextDiamonds<0){
      return json({ok:false,error:"invalid_balance_change"},{status:400});
    }

    const ts=now();
    const statements=[
      db.prepare("UPDATE users SET coins=?,diamonds=?,updated_at=? WHERE id=?")
        .bind(nextCoins,nextDiamonds,ts,userId),
    ];
    if(coinDelta!==0){
      statements.push(
        db.prepare(
          "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,'owner_adjustment',?,?,?,?)"
        ).bind(id(),userId,coinDelta,nextCoins,actor.id,ts)
      );
    }
    await db.batch(statements);

    let roleWallet=null;
    const walletType=String(body.role_wallet_type ?? "").trim();
    if(walletType){
      if(walletType!=="coin_seller"&&walletType!=="merchant"){
        return json({ok:false,error:"invalid_role_wallet"},{status:400});
      }
      const roleCoinDelta=clampInt(
        body.role_coin_delta ?? 0,
        -900000000000000,900000000000000,0,
      );
      try{
        roleWallet=await adjustRoleWallet(db,{
          userId,
          walletType,
          coinDelta:roleCoinDelta,
          referenceId:"owner:"+actor.id,
          ts,
        });
      }catch(error){
        return json({ok:false,error:String(error?.message ?? error)},{status:400});
      }
    }

    await audit(
      db,actor,"wallet_adjustment","user",userId,
      `coins=${coinDelta}; diamonds=${diamondDelta}; role=${walletType || "-"}`
    );
    return json({
      ok:true,
      coins:nextCoins,
      diamonds:nextDiamonds,
      role_wallet:roleWallet,
    });
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

  if (parts[4] === "owner-overrides" && request.method === "POST") {
    requirePermission(actor, "users.override");
    const body = await bodyJson(request);
    const invisible = body.invisible_id === true ? 1 : 0;
    const bypass = body.locked_room_bypass === true ? 1 : 0;
    const frozen = body.wallet_frozen === true ? 1 : 0;
    const exists = await db.prepare("SELECT id FROM users WHERE id=?").bind(userId).first();
    if (!exists) return json({ok:false,error:"not_found"},{status:404});
    await db.prepare(
      `INSERT INTO owner_user_overrides(user_id,invisible_id,locked_room_bypass,wallet_frozen,updated_at)
       VALUES(?,?,?,?,?)
       ON CONFLICT(user_id) DO UPDATE SET invisible_id=excluded.invisible_id,
         locked_room_bypass=excluded.locked_room_bypass,wallet_frozen=excluded.wallet_frozen,updated_at=excluded.updated_at`
    ).bind(userId,invisible,bypass,frozen,now()).run();
    await audit(db,actor,"user_owner_overrides","user",userId,`invisible=${invisible}; bypass=${bypass}; wallet_frozen=${frozen}`);
    return json({ok:true,user:await getUserDetails(db,userId)});
  }

  if (parts[4] === "device-ban" && request.method === "POST") {
    requirePermission(actor, "users.device");
    const body = await bodyJson(request);
    const deviceKey = String(body.device_key ?? body.token ?? "").trim().slice(0,500);
    if (!deviceKey) return json({ok:false,error:"device_key_required"},{status:400});
    const banned = body.banned === false ? 0 : 1;
    const note = String(body.note ?? "").trim().slice(0,300);
    await db.prepare(
      `INSERT INTO owner_device_bans(device_key,user_id,banned,note,updated_at) VALUES(?,?,?,?,?)
       ON CONFLICT(device_key) DO UPDATE SET user_id=excluded.user_id,banned=excluded.banned,note=excluded.note,updated_at=excluded.updated_at`
    ).bind(deviceKey,userId,banned,note,now()).run();
    if (banned) {
      await db.prepare("UPDATE push_devices SET enabled=0 WHERE user_id=? AND (device_key=? OR token=?)")
        .bind(userId,deviceKey,deviceKey).run();
    }
    await audit(db,actor,banned?"device_ban":"device_unban","user",userId,deviceKey.slice(0,80));
    return json({ok:true,user:await getUserDetails(db,userId)});
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

  if (parts[4] === "live" && request.method === "GET") {
    requirePermission(actor,"rooms.live");
    const room = await db.prepare(
      `SELECT r.*,COALESCE(u.display_name,'') AS owner_name,ri.image_key,
              COALESCE(rs.theme_id,'dark') AS theme_id,COALESCE(rs.announcement,'') AS announcement,
              COALESCE(rs.party_mode,'Friends-making Party') AS party_mode,
              COALESCE(rs.room_mode,'voice') AS room_mode,COALESCE(rs.lock_password_code,'') AS lock_code,
              COALESCE(ct.asset_key,'') AS background_key
         FROM rooms r LEFT JOIN users u ON u.id=r.owner_user_id
         LEFT JOIN room_images ri ON ri.room_id=r.id
         LEFT JOIN room_settings rs ON rs.room_id=r.id
         LEFT JOIN room_custom_themes ct ON ct.id=rs.theme_id AND ct.room_id=r.id
        WHERE r.id=?`
    ).bind(roomId).first();
    if(!room) return json({ok:false,error:"not_found"},{status:404});
    const members=await db.prepare(
      `SELECT m.user_id,m.seat_index,m.mic_muted,m.joined_at,m.updated_at,
              u.public_id,u.display_name,u.avatar_key,u.vip_level
         FROM room_members m LEFT JOIN users u ON u.id=m.user_id
        WHERE m.room_id=? ORDER BY CASE WHEN m.seat_index IS NULL THEN 1 ELSE 0 END,m.seat_index,m.joined_at`
    ).bind(roomId).all();
    return json({ok:true,room,members:members.results ?? []});
  }

  if (parts[4] === "media" && request.method === "POST") {
    requirePermission(actor,"rooms.media");
    const body=await bodyJson(request);
    const room=await db.prepare("SELECT owner_user_id FROM rooms WHERE id=?").bind(roomId).first();
    if(!room) return json({ok:false,error:"not_found"},{status:404});
    const ts=now();
    if(Object.prototype.hasOwnProperty.call(body,"image_key")){
      const imageKey=String(body.image_key ?? "").trim().slice(0,500);
      if(imageKey){
        await db.prepare(
          "INSERT INTO room_images(room_id,image_key,updated_at) VALUES(?,?,?) ON CONFLICT(room_id) DO UPDATE SET image_key=excluded.image_key,updated_at=excluded.updated_at"
        ).bind(roomId,imageKey,ts).run();
      }else{
        await db.prepare("DELETE FROM room_images WHERE room_id=?").bind(roomId).run();
      }
    }
    if(Object.prototype.hasOwnProperty.call(body,"background_key")){
      const backgroundKey=String(body.background_key ?? "").trim().slice(0,500);
      await db.prepare("INSERT OR IGNORE INTO room_settings(room_id,updated_at) VALUES(?,?)").bind(roomId,ts).run();
      if(backgroundKey){
        const themeId="owner-theme-"+roomId;
        await db.prepare(
          `INSERT INTO room_custom_themes(id,room_id,owner_user_id,name,asset_key,price_coins,created_at,expires_at)
           VALUES(?,?,?,?,?,0,?,NULL)
           ON CONFLICT(id) DO UPDATE SET asset_key=excluded.asset_key,created_at=excluded.created_at,expires_at=NULL`
        ).bind(themeId,roomId,room.owner_user_id,"Owner Background",backgroundKey,ts).run();
        await db.prepare("UPDATE room_settings SET theme_id=?,updated_at=? WHERE room_id=?").bind(themeId,ts,roomId).run();
      }else{
        await db.prepare("UPDATE room_settings SET theme_id='dark',updated_at=? WHERE room_id=?").bind(ts,roomId).run();
        await db.prepare("DELETE FROM room_custom_themes WHERE id=?").bind("owner-theme-"+roomId).run();
      }
    }
    await audit(db,actor,"room_media_update","room",roomId,"DP/background override");
    return json({ok:true});
  }

  if (parts[4] === "theme" && request.method === "POST") {
    requirePermission(actor,"rooms.theme");
    const body=await bodyJson(request);
    const themeId=String(body.theme_id ?? "dark").trim().slice(0,120);
    await db.prepare("INSERT OR IGNORE INTO room_settings(room_id,updated_at) VALUES(?,?)").bind(roomId,now()).run();
    await db.prepare("UPDATE room_settings SET theme_id=?,updated_at=? WHERE room_id=?").bind(themeId,now(),roomId).run();
    await audit(db,actor,"room_theme_override","room",roomId,themeId);
    return json({ok:true,theme_id:themeId});
  }
  return null;
}


async function handleEconomy(request, db, actor) {
  const key = "economy.coin_rate";
  const fallback = 5000000;
  if (request.method === "GET") {
    requirePermission(actor, "economy.read");
    const row = await db.prepare("SELECT value_json, updated_at FROM owner_settings WHERE key = ?").bind(key).first();
    const value = safeParse(row?.value_json, {});
    const parsed = Number(value?.coins_per_usd);
    const coinsPerUsd = Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
    return json({ ok: true, coins_per_usd: coinsPerUsd, updated_at: row?.updated_at ?? null });
  }
  if (request.method !== "POST") return null;

  requirePermission(actor, "economy.write");
  const body = await bodyJson(request);
  const coinsPerUsd = Number(body.coins_per_usd);
  if (!Number.isSafeInteger(coinsPerUsd) || coinsPerUsd < 1 || coinsPerUsd > 900000000000000) {
    return json({ ok: false, error: "invalid_coins_per_usd" }, { status: 400 });
  }
  const current = await db.prepare("SELECT value_json FROM owner_settings WHERE key = ?").bind(key).first();
  const oldValue = safeParse(current?.value_json, {});
  const oldRate = Number.isSafeInteger(Number(oldValue?.coins_per_usd)) && Number(oldValue?.coins_per_usd) > 0
    ? Number(oldValue.coins_per_usd)
    : fallback;
  const ts = now();
  const value = { coins_per_usd: coinsPerUsd };
  await db.prepare(
    "INSERT INTO owner_settings (key, value_json, updated_at) VALUES (?, ?, ?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json, updated_at=excluded.updated_at"
  ).bind(key, JSON.stringify(value), ts).run();
  await audit(db, actor, "coin_rate_update", "economy", "coin_rate", `old=${oldRate}; new=${coinsPerUsd}`);
  return json({ ok: true, coins_per_usd: coinsPerUsd, updated_at: ts });
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



async function handleNotifications(request, db, actor, parts) {
  if(parts.length===3 && request.method==="GET"){
    requirePermission(actor,"notifications.read");
    const rows=await db.prepare(
      "SELECT id,kind,title,body,user_id,read_at,created_at FROM owner_notifications ORDER BY created_at DESC LIMIT 300"
    ).all();
    return json({ok:true,notifications:rows.results ?? []});
  }
  if(parts.length===3 && request.method==="POST"){
    requirePermission(actor,"notifications.write");
    const body=await bodyJson(request);
    const title=String(body.title ?? "Owner notification").trim().slice(0,160);
    const message=String(body.body ?? "").trim().slice(0,2000);
    if(!message) return json({ok:false,error:"body_required"},{status:400});
    const notificationId=id();
    await db.prepare(
      "INSERT INTO owner_notifications(id,kind,title,body,user_id,read_at,created_at) VALUES(?,?,?,?,?,NULL,?)"
    ).bind(notificationId,String(body.kind ?? "platform").slice(0,40),title,message,String(body.user_id ?? "").trim()||null,now()).run();
    await audit(db,actor,"notification_create","notification",notificationId,title);
    return json({ok:true,id:notificationId});
  }
  const notificationId=decodeURIComponent(parts[3] ?? "");
  if(notificationId && parts[4]==="read" && request.method==="POST"){
    requirePermission(actor,"notifications.write");
    await db.prepare("UPDATE owner_notifications SET read_at=? WHERE id=?").bind(now(),notificationId).run();
    return json({ok:true});
  }
  if(notificationId && request.method==="DELETE"){
    requirePermission(actor,"notifications.write");
    await db.prepare("DELETE FROM owner_notifications WHERE id=?").bind(notificationId).run();
    await audit(db,actor,"notification_delete","notification",notificationId,"deleted");
    return json({ok:true});
  }
  return null;
}

async function handleMessaging(request, db, actor, url, parts) {
  if(parts[2]==="messages" && request.method==="POST"){
    requirePermission(actor,"messaging.write");
    const body=await bodyJson(request);
    const message=String(body.text ?? "").trim().slice(0,2000);
    if(!message) return json({ok:false,error:"message_required"},{status:400});
    let recipients=[];
    if(body.all_users===true){
      const rows=await db.prepare("SELECT id FROM users WHERE id<>'darkvibex_official' ORDER BY created_at ASC LIMIT 10000").all();
      recipients=(rows.results ?? []).map(r=>String(r.id));
    }else{
      recipients=Array.isArray(body.user_ids)?body.user_ids.map(String).filter(Boolean).slice(0,1000):[];
    }
    const ts=now();
    for(const userId of recipients){
      await db.prepare(
        "INSERT INTO direct_messages(id,sender_user_id,receiver_user_id,text,created_at,read_at) VALUES(?,?,?,?,?,NULL)"
      ).bind(id(),"darkvibex_official",userId,message,ts).run();
    }
    await audit(db,actor,"official_message","users",body.all_users===true?"all":String(recipients.length),message.slice(0,120));
    return json({ok:true,sent:recipients.length});
  }
  if(parts[2]==="tags" && request.method==="POST"){
    requirePermission(actor,"tags.write");
    const body=await bodyJson(request);
    const userIds=Array.isArray(body.user_ids)?body.user_ids.map(String).filter(Boolean).slice(0,1000):[];
    const name=String(body.name ?? "").trim().slice(0,60);
    if(!name||userIds.length===0) return json({ok:false,error:"name_and_users_required"},{status:400});
    const kind=String(body.kind ?? "custom").trim().slice(0,40);
    const designation=String(body.designation ?? "").trim().slice(0,80);
    const color=String(body.color ?? "#FFD54F").trim().slice(0,20);
    const background=String(body.background_color ?? color).trim().slice(0,20);
    const rawId=kind==="v_official" ? "v-official-"+designation : name;
    const tagId=String(body.tag_id ?? rawId.toLowerCase().replace(/[^a-z0-9]+/g,"-")).slice(0,100);
    const ts=now();
    for(const userId of userIds){
      await db.prepare(
        `INSERT INTO owner_user_tags(user_id,tag_id,name,color,kind,designation,background_color,created_at,updated_at)
         VALUES(?,?,?,?,?,?,?,?,?)
         ON CONFLICT(user_id,tag_id) DO UPDATE SET name=excluded.name,color=excluded.color,kind=excluded.kind,
           designation=excluded.designation,background_color=excluded.background_color,updated_at=excluded.updated_at`
      ).bind(userId,tagId,name,color,kind,designation,background,ts,ts).run();
    }
    await audit(db,actor,"tag_apply","users",String(userIds.length),name);
    return json({ok:true,tagged:userIds.length,name,tag_id:tagId});
  }
  if(parts[2]==="tags" && request.method==="GET"){
    requirePermission(actor,"messaging.read");
    const kind=String(url.searchParams.get("kind") ?? "").trim();
    const rows=await db.prepare(
      `SELECT t.user_id,t.tag_id,t.name,t.color,t.kind,t.designation,t.background_color,t.updated_at,
              u.public_id,u.display_name,u.avatar_key
         FROM owner_user_tags t LEFT JOIN users u ON u.id=t.user_id
        WHERE (?='' OR t.kind=?) ORDER BY t.designation,t.updated_at DESC LIMIT 1000`
    ).bind(kind,kind).all();
    return json({ok:true,tags:rows.results ?? []});
  }
  const userId=decodeURIComponent(parts[3] ?? "");
  const tagId=decodeURIComponent(parts[4] ?? "");
  if(parts[2]==="tags" && userId && tagId && request.method==="DELETE"){
    requirePermission(actor,"tags.write");
    await db.prepare("DELETE FROM owner_user_tags WHERE user_id=? AND tag_id=?").bind(userId,tagId).run();
    await audit(db,actor,"tag_remove","user",userId,tagId);
    return json({ok:true});
  }
  return null;
}

async function handleRolesPosts(request, db, actor, url, parts) {
  requirePermission(actor, request.method==="GET" ? "roles.read" : "roles.write");
  const kind=String(url.searchParams.get("kind") ?? "role").trim()==="post"?"post":"role";
  if(parts.length===3 && request.method==="GET"){
    const rows=await db.prepare(
      "SELECT kind,id,name,enabled,sort_order,price_coins,json_data,updated_at FROM owner_catalog WHERE kind=? ORDER BY sort_order,updated_at DESC"
    ).bind(kind).all();
    return json({ok:true,kind,items:(rows.results ?? []).map(parseStoreRow)});
  }
  if(parts.length===3 && request.method==="POST"){
    const body=await bodyJson(request);
    const itemId=String(body.id ?? id()).trim().slice(0,100);
    const name=String(body.name ?? "").trim().slice(0,100);
    if(!name) return json({ok:false,error:"name_required"},{status:400});
    const data=body.data&&typeof body.data==="object"&&!Array.isArray(body.data)?body.data:{};
    await db.prepare(
      `INSERT INTO owner_catalog(kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at)
       VALUES(?,?,?,?,?,0,'',?,?)
       ON CONFLICT(kind,id) DO UPDATE SET name=excluded.name,enabled=excluded.enabled,sort_order=excluded.sort_order,json_data=excluded.json_data,updated_at=excluded.updated_at`
    ).bind(kind,itemId,name,body.enabled===false?0:1,clampInt(body.sort_order ?? 0,-100000,100000,0),JSON.stringify(data),now()).run();
    await audit(db,actor,"role_post_upsert",kind,itemId,name);
    return json({ok:true,id:itemId});
  }
  const itemId=decodeURIComponent(parts[3] ?? "");
  if(itemId && request.method==="DELETE"){
    await db.prepare("DELETE FROM owner_catalog WHERE kind=? AND id=?").bind(kind,itemId).run();
    await audit(db,actor,"role_post_delete",kind,itemId,"deleted");
    return json({ok:true});
  }
  return null;
}

async function handleBanners(request, db, actor, parts) {
  requirePermission(actor, request.method==="GET" ? "banners.read" : "banners.write");
  if(parts.length===3 && request.method==="GET"){
    const rows=await db.prepare(
      "SELECT kind,id,name,enabled,sort_order,price_coins,json_data,updated_at FROM owner_catalog WHERE kind='banner' ORDER BY sort_order,updated_at DESC"
    ).all();
    return json({ok:true,banners:(rows.results ?? []).map(parseStoreRow)});
  }
  if(parts.length===3 && request.method==="POST"){
    const body=await bodyJson(request);
    const bannerId=String(body.id ?? id()).trim().slice(0,100);
    const name=String(body.name ?? "Banner").trim().slice(0,100);
    const data={asset_key:String(body.asset_key ?? "").trim().slice(0,500),link:String(body.link ?? "").trim().slice(0,500),
      starts_at:Number(body.starts_at ?? 0)||null,ends_at:Number(body.ends_at ?? 0)||null};
    await db.prepare(
      `INSERT INTO owner_catalog(kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at)
       VALUES('banner',?,?,?, ?,0,'',?,?)
       ON CONFLICT(kind,id) DO UPDATE SET name=excluded.name,enabled=excluded.enabled,sort_order=excluded.sort_order,json_data=excluded.json_data,updated_at=excluded.updated_at`
    ).bind(bannerId,name,body.enabled===false?0:1,clampInt(body.sort_order ?? 0,-100000,100000,0),JSON.stringify(data),now()).run();
    await audit(db,actor,"banner_upsert","banner",bannerId,name);
    return json({ok:true,id:bannerId});
  }
  const bannerId=decodeURIComponent(parts[3] ?? "");
  if(bannerId && request.method==="DELETE"){
    await db.prepare("DELETE FROM owner_catalog WHERE kind='banner' AND id=?").bind(bannerId).run();
    await audit(db,actor,"banner_delete","banner",bannerId,"deleted");
    return json({ok:true});
  }
  return null;
}

async function handleGamesOwner(request, db, actor) {
  if(request.method==="GET"){
    requirePermission(actor,"games.read");
    const [catalog,bets]=await Promise.all([
      db.prepare("SELECT kind,id,name,enabled,sort_order,price_coins,json_data,updated_at FROM owner_catalog WHERE kind='game_config' ORDER BY sort_order,updated_at DESC").all(),
      db.prepare(
        `SELECT game_id,COUNT(*) AS bets,COALESCE(SUM(stake),0) AS wagered,COALESCE(SUM(payout),0) AS payout,
                COALESCE(SUM(stake-payout),0) AS house_result
           FROM game_bets GROUP BY game_id ORDER BY wagered DESC LIMIT 100`
      ).all()
    ]);
    return json({ok:true,games:(catalog.results ?? []).map(parseStoreRow),stats:bets.results ?? []});
  }
  if(request.method==="POST"){
    requirePermission(actor,"games.write");
    const body=await bodyJson(request);
    const gameId=String(body.id ?? "").trim().slice(0,100);
    if(!gameId) return json({ok:false,error:"game_id_required"},{status:400});
    const existing=await db.prepare("SELECT name,json_data FROM owner_catalog WHERE kind='game_config' AND id=?").bind(gameId).first();
    const oldData=safeParse(existing?.json_data,{});
    const data={...oldData,...(body.data&&typeof body.data==="object"?body.data:{}),
      min_bet:clampInt(body.min_bet ?? oldData.min_bet ?? 1,1,900000000000000,1),
      max_bet:clampInt(body.max_bet ?? oldData.max_bet ?? 1000000,1,900000000000000,1000000)};
    await db.prepare(
      `INSERT INTO owner_catalog(kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at)
       VALUES('game_config',?,?,?,0,0,'',?,?)
       ON CONFLICT(kind,id) DO UPDATE SET name=excluded.name,enabled=excluded.enabled,json_data=excluded.json_data,updated_at=excluded.updated_at`
    ).bind(gameId,String(body.name ?? existing?.name ?? gameId).slice(0,100),body.enabled===false?0:1,JSON.stringify(data),now()).run();
    await audit(db,actor,"game_config_update","game",gameId,`enabled=${body.enabled!==false}`);
    return json({ok:true});
  }
  return null;
}

async function handlePoliciesOwner(request, db, actor, parts) {
  if(request.method==="GET"){
    requirePermission(actor,"policies.read");
    const rows=await db.prepare(
      "SELECT key,value_json,updated_at FROM owner_settings WHERE key LIKE 'policy.%' OR key LIKE 'economy.%' ORDER BY key"
    ).all();
    return json({ok:true,policies:(rows.results ?? []).map(r=>({key:r.key,value:safeParse(r.value_json,{}),updated_at:r.updated_at}))});
  }
  if(request.method==="POST"){
    requirePermission(actor,"policies.write");
    const body=await bodyJson(request);
    const key=String(body.key ?? "").trim().slice(0,100);
    if(!key || /agency|\bbd\b|host|guardian|verification/i.test(key)){
      return json({ok:false,error:"invalid_or_excluded_policy"},{status:400});
    }
    const fullKey=key.startsWith("policy.")||key.startsWith("economy.")?key:"policy."+key;
    const value=body.value&&typeof body.value==="object"&&!Array.isArray(body.value)?body.value:{value:body.value};
    await db.prepare(
      "INSERT INTO owner_settings(key,value_json,updated_at) VALUES(?,?,?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json,updated_at=excluded.updated_at"
    ).bind(fullKey,JSON.stringify(value),now()).run();
    await audit(db,actor,"policy_update","policy",fullKey,JSON.stringify(value).slice(0,160));
    return json({ok:true,key:fullKey,value});
  }
  const key=decodeURIComponent(parts[3] ?? "");
  if(key && request.method==="DELETE"){
    requirePermission(actor,"policies.write");
    const fullKey=key.startsWith("policy.")||key.startsWith("economy.")?key:"policy."+key;
    await db.prepare("DELETE FROM owner_settings WHERE key=?").bind(fullKey).run();
    await audit(db,actor,"policy_delete","policy",fullKey,"deleted");
    return json({ok:true});
  }
  return null;
}

function baseStoreItems(kind) {
  const k=String(kind ?? "").trim();
  if (k==="gift") {
    return [...BASE_GIFT_CATALOG,...DARKVIBE_EXTRA_GIFTS].map((item,index)=>({
      kind:k,id:String(item.id),name:String(item.name),enabled:1,sort_order:index,
      price_coins:Number(item.coin_cost ?? 0),source:"base",
      data:{
        emoji:String(item.emoji ?? "🎁"),
        min_vip_level:Number(item.vip_level ?? 0),
        vip_level:Number(item.vip_level ?? 0),
        category:String(item.category ?? "normal"),
        asset_key:String(item.asset_key ?? ""),
        duration_days:0,
        tier:0,
      },
    }));
  }
  if (k==="unique_id") {
    return BASE_UNIQUE_ID_CATALOG.map((item,index)=>({
      kind:k,id:String(item.public_id),name:String(item.public_id),enabled:1,sort_order:index,
      price_coins:Number(item.price_coins ?? 0),source:"base",
      data:{duration_days:Number(item.duration_days ?? 0),min_vip_level:0,tier:0,asset_key:""},
    }));
  }
  return COSMETIC_CATALOG.filter(item=>String(item.kind)===k).map((item,index)=>({
    kind:k,id:String(item.id),name:String(item.name),enabled:1,sort_order:index,
    price_coins:Number(item.price_coins ?? 0),source:"base",
    data:{
      min_vip_level:Number(item.min_vip_level ?? 0),
      duration_days:Number(item.duration_days ?? 30),
      tier:Number(item.tier ?? 0),
      asset_key:String(item.asset_key ?? ""),
      description:String(item.description ?? ""),
    },
  }));
}

function parseStoreRow(row) {
  let data={};
  try { data=JSON.parse(String(row?.json_data ?? "{}")) || {}; } catch (_) {}
  return {
    kind:String(row?.kind ?? ""),
    id:String(row?.id ?? ""),
    name:String(row?.name ?? ""),
    enabled:Number(row?.enabled ?? 1),
    sort_order:Number(row?.sort_order ?? 0),
    price_coins:Number(row?.price_coins ?? 0),
    updated_at:row?.updated_at ?? null,
    data,
  };
}

async function effectiveOwnerStore(db, kind) {
  const map=new Map(baseStoreItems(kind).map(item=>[item.id,item]));
  const rows=await db.prepare(
    "SELECT kind,id,name,enabled,sort_order,price_coins,json_data,updated_at FROM owner_catalog WHERE kind=? ORDER BY sort_order ASC,updated_at DESC"
  ).bind(kind).all();
  for(const raw of rows.results ?? []) {
    const row=parseStoreRow(raw);
    const previous=map.get(row.id) ?? {kind,id:row.id,source:"custom",data:{}};
    map.set(row.id,{
      ...previous,...row,
      source:previous.source==="base"?"override":"custom",
      data:{...(previous.data ?? {}),...(row.data ?? {})},
    });
  }
  return [...map.values()].sort((a,b)=>
    Number(a.sort_order ?? 0)-Number(b.sort_order ?? 0) ||
    String(a.name ?? "").localeCompare(String(b.name ?? ""))
  );
}

async function handleStore(request, db, actor, url, parts) {
  if (parts.length===3 && request.method==="GET") {
    requirePermission(actor,"catalog.read");
    const kind=String(url.searchParams.get("kind") ?? "").trim().slice(0,60);
    if(!kind) return json({ok:false,error:"kind_required"},{status:400});
    return json({ok:true,kind,items:await effectiveOwnerStore(db,kind)});
  }
  if (parts.length===3 && request.method==="POST") {
    requirePermission(actor,"catalog.write");
    const body=await bodyJson(request);
    const kind=String(body.kind ?? "").trim().slice(0,60);
    const itemId=String(body.id ?? "").trim().slice(0,100);
    const name=String(body.name ?? itemId).trim().slice(0,120);
    if(!kind||!itemId||!name) return json({ok:false,error:"kind_id_name_required"},{status:400});
    if(kind==="unique_id"&&!/^\d{4,8}$/.test(itemId)) {
      return json({ok:false,error:"numeric_unique_id_required"},{status:400});
    }
    const price=clampInt(body.price_coins ?? 0,0,900000000000000,0);
    const sortOrder=clampInt(body.sort_order ?? 0,-100000,100000,0);
    const enabled=body.enabled===false?0:1;
    const data=body.data&&typeof body.data==="object"&&!Array.isArray(body.data)?body.data:{};
    await db.prepare(
      `INSERT INTO owner_catalog(kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at)
       VALUES(?,?,?,?,?,?,?,?,?)
       ON CONFLICT(kind,id) DO UPDATE SET
         name=excluded.name,enabled=excluded.enabled,sort_order=excluded.sort_order,
         price_coins=excluded.price_coins,json_data=excluded.json_data,updated_at=excluded.updated_at`
    ).bind(kind,itemId,name,enabled,sortOrder,price,"",JSON.stringify(data),now()).run();
    await audit(db,actor,"store_upsert",kind,itemId,`${name}; price=${price}; enabled=${enabled}`);
    const items=await effectiveOwnerStore(db,kind);
    return json({ok:true,item:items.find(item=>item.id===itemId) ?? null});
  }
  if (parts.length===5 && request.method==="DELETE") {
    requirePermission(actor,"catalog.write");
    const kind=decodeURIComponent(parts[3]);
    const itemId=decodeURIComponent(parts[4]);
    const items=await effectiveOwnerStore(db,kind);
    const item=items.find(row=>row.id===itemId);
    if(!item) return json({ok:false,error:"not_found"},{status:404});
    await db.prepare(
      `INSERT INTO owner_catalog(kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at)
       VALUES(?,?,?,?,?,?,?,?,?)
       ON CONFLICT(kind,id) DO UPDATE SET enabled=0,updated_at=excluded.updated_at`
    ).bind(kind,itemId,String(item.name||itemId),0,Number(item.sort_order||0),Number(item.price_coins||0),"",JSON.stringify(item.data||{}),now()).run();
    await audit(db,actor,"store_remove",kind,itemId,"removed from app store");
    return json({ok:true});
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
    const data = body.data && typeof body.data === "object" ? body.data : {};
    await db.prepare(
      `INSERT INTO owner_catalog (kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at)
       VALUES (?,?,?,?,?,?,?,?,?)
       ON CONFLICT(kind,id) DO UPDATE SET name=excluded.name, enabled=excluded.enabled,
         sort_order=excluded.sort_order, price_coins=excluded.price_coins, country=excluded.country,
         json_data=excluded.json_data, updated_at=excluded.updated_at`
    ).bind(itemKind, itemId, name, enabled, sortOrder, priceCoins, "", JSON.stringify(data), now()).run();
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
      "SELECT id,title,body,enabled,starts_at,ends_at,created_at,updated_at FROM owner_announcements ORDER BY updated_at DESC LIMIT 200"
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
      "", ts, ts,
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

async function handleTreasury(request, db, actor) {
  if (request.method === "GET") {
    requirePermission(actor, "treasury.read");
    const row = await db.prepare("SELECT balance, updated_at FROM owner_treasury WHERE id = 'main'").first();
    const ledger = await db.prepare(
      "SELECT id, amount, balance_after, kind, target_user_id, actor_id, note, created_at FROM owner_treasury_ledger ORDER BY created_at DESC LIMIT 100"
    ).all();
    return json({ ok: true, treasury: { balance: Number(row?.balance ?? 0), updated_at: row?.updated_at ?? null }, ledger: ledger.results ?? [] });
  }
  if (request.method !== "POST") return null;

  requirePermission(actor, "treasury.write");
  const body = await bodyJson(request);
  const action = String(body.action ?? "").trim().toLowerCase();
  const amount = clampInt(body.amount ?? 0, 1, 900000000000000, 0);
  if (!amount) return json({ ok: false, error: "amount_required" }, { status: 400 });
  const ts = now();
  const note = String(body.note ?? "").trim().slice(0, 200);

  const current = await db.prepare("SELECT balance FROM owner_treasury WHERE id = 'main'").first();
  const balance = Number(current?.balance ?? 0);

  if (action === "add" || action === "deduct") {
    if (actor.type !== "owner") return json({ ok: false, error: "owner_only" }, { status: 403 });
    const delta = action === "add" ? amount : -amount;
    const next = balance + delta;
    if (!Number.isSafeInteger(next) || next < 0) return json({ ok: false, error: "invalid_treasury_balance" }, { status: 400 });
    await db.batch([
      db.prepare("UPDATE owner_treasury SET balance = ?, updated_at = ? WHERE id = 'main'").bind(next, ts),
      db.prepare("INSERT INTO owner_treasury_ledger (id, amount, balance_after, kind, target_user_id, actor_id, note, created_at) VALUES (?, ?, ?, ?, NULL, ?, ?, ?)")
        .bind(id(), delta, next, action === "add" ? "owner_topup" : "owner_deduct", actor.id, note, ts),
    ]);
    await audit(db, actor, action === "add" ? "treasury_add" : "treasury_deduct", "treasury", "main", `amount=${amount}`);
    return json({ ok: true, balance: next });
  }

  if (action === "send") {
    const userId = String(body.user_id ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const user = await db.prepare("SELECT id, coins FROM users WHERE id = ?").bind(userId).first();
    if (!user) return json({ ok: false, error: "user_not_found" }, { status: 404 });
    if (balance < amount) return json({ ok: false, error: "insufficient_treasury_balance" }, { status: 409 });
    const nextTreasury = balance - amount;
    const nextUser = Number(user.coins ?? 0) + amount;
    if (!Number.isSafeInteger(nextUser)) return json({ ok: false, error: "invalid_user_balance" }, { status: 400 });
    await db.batch([
      db.prepare("UPDATE owner_treasury SET balance = ?, updated_at = ? WHERE id = 'main'").bind(nextTreasury, ts),
      db.prepare("UPDATE users SET coins = ?, updated_at = ? WHERE id = ?").bind(nextUser, ts, userId),
      db.prepare("INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,'owner_treasury',?,?,?,?)")
        .bind(id(), userId, amount, nextUser, actor.id, ts),
      db.prepare("INSERT INTO owner_treasury_ledger (id, amount, balance_after, kind, target_user_id, actor_id, note, created_at) VALUES (?, ?, ?, 'send_to_user', ?, ?, ?, ?)")
        .bind(id(), -amount, nextTreasury, userId, actor.id, note, ts),
    ]);
    await audit(db, actor, "treasury_send", "user", userId, `amount=${amount}`);
    return json({ ok: true, balance: nextTreasury, user_balance: nextUser });
  }

  return json({ ok: false, error: "invalid_treasury_action" }, { status: 400 });
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

async function handleSupportTickets(request, db, actor, url, parts) {
  await ensureSupportSchema(db);
  const ticketId = parts[3] ? decodeURIComponent(parts[3]) : "";
  if (!ticketId && request.method === "GET") {
    requirePermission(actor, "support.read");
    const status = String(url.searchParams.get("status") ?? "all");
    const rows = await db.prepare(
      `SELECT t.id,t.user_id,t.subject,t.status,t.created_at,t.updated_at,
              COALESCE(u.display_name,'') AS display_name,u.vip_level,
              (SELECT body FROM vip_support_messages m WHERE m.ticket_id=t.id ORDER BY m.created_at DESC LIMIT 1) AS last_message,
              (SELECT sender_type FROM vip_support_messages m WHERE m.ticket_id=t.id ORDER BY m.created_at DESC LIMIT 1) AS last_sender
         FROM vip_support_tickets t LEFT JOIN users u ON u.id=t.user_id
        WHERE (?='all' OR t.status=?) ORDER BY t.updated_at DESC LIMIT 300`
    ).bind(status, status).all();
    return json({ ok: true, tickets: rows.results ?? [] });
  }
  if (!ticketId) return null;
  const ticket = await db.prepare(
    `SELECT t.id,t.user_id,t.subject,t.status,t.created_at,t.updated_at,
            COALESCE(u.display_name,'') AS display_name,u.vip_level
       FROM vip_support_tickets t LEFT JOIN users u ON u.id=t.user_id WHERE t.id=?`
  ).bind(ticketId).first();
  if (!ticket) return json({ ok: false, error: "not_found" }, { status: 404 });
  if (request.method === "GET" && parts.length === 4) {
    requirePermission(actor, "support.read");
    const rows = await db.prepare("SELECT id,sender_type,sender_id,body,created_at FROM vip_support_messages WHERE ticket_id=? ORDER BY created_at ASC LIMIT 500").bind(ticketId).all();
    return json({ ok: true, ticket, messages: rows.results ?? [] });
  }
  if (request.method === "POST" && parts[4] === "reply") {
    requirePermission(actor, "support.write");
    if (ticket.status !== "open") return json({ ok: false, error: "ticket_closed" }, { status: 409 });
    const body = await bodyJson(request);
    const message = String(body.message ?? "").trim();
    if (!message || message.length > 2000) return json({ ok: false, error: "message_length_invalid" }, { status: 400 });
    const ts = now();
    await db.batch([
      db.prepare("INSERT INTO vip_support_messages (id,ticket_id,sender_type,sender_id,body,created_at) VALUES (?,?,?,?,?,?)").bind(id(), ticketId, "staff", actor.id, message, ts),
      db.prepare("UPDATE vip_support_tickets SET updated_at=? WHERE id=?").bind(ts, ticketId),
    ]);
    await audit(db, actor, "support_reply", "vip_support_ticket", ticketId, `reply to ${ticket.user_id}`);
    return json({ ok: true });
  }
  if (request.method === "POST" && parts[4] === "close") {
    requirePermission(actor, "support.write");
    const ts = now();
    await db.prepare("UPDATE vip_support_tickets SET status='closed',updated_at=? WHERE id=?").bind(ts, ticketId).run();
    await audit(db, actor, "support_close", "vip_support_ticket", ticketId, `closed for ${ticket.user_id}`);
    return json({ ok: true });
  }
  return null;
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
    else if (parts[2] === "support-tickets") response = await handleSupportTickets(request, db, actor, url, parts);
    else if (parts[2] === "notifications") response = await handleNotifications(request, db, actor, parts);
    else if (parts[2] === "messages" || parts[2] === "tags") response = await handleMessaging(request, db, actor, url, parts);
    else if (parts[2] === "rooms") response = await handleRooms(request, db, actor, url, parts);
    else if (parts[2] === "roles-posts") response = await handleRolesPosts(request, db, actor, url, parts);
    else if (parts[2] === "banners") response = await handleBanners(request, db, actor, parts);
    else if (parts[2] === "games") response = await handleGamesOwner(request, db, actor);
    else if (parts[2] === "policies") response = await handlePoliciesOwner(request, db, actor, parts);
    else if (parts[2] === "economy") response = await handleEconomy(request, db, actor);
    else if (parts[2] === "settings") response = await handleSettings(request, db, actor, parts);
    else if (parts[2] === "store") response = await handleStore(request, db, actor, url, parts);
    else if (parts[2] === "catalog") response = await handleCatalog(request, db, actor, url, parts);
    else if (parts[2] === "announcements") response = await handleAnnouncements(request, db, actor, parts);
    else if (parts[2] === "treasury") response = await handleTreasury(request, db, actor);
    else if (parts[2] === "staff") response = await handleStaff(request, db, actor, parts);
    else if (parts[2] === "audit") response = await handleAudit(request, db, actor, url);
    if (response) return response;

    return json({ ok: false, error: "not_found" }, { status: 404 });
  } catch (error) {
    const message = String(error?.message ?? error);
    return json({ ok: false, error: message }, { status: Number(error?.status ?? 400) });
  }
}
