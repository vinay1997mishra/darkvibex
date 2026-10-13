import { normalizeRole } from "./role_policy.js";
import { awardIdLevelDaily, awardIdLevelGift, claimIdLevelReward, getIdLevelStatus } from "./id_level.js";
import { COSMETIC_CATALOG, ensureCosmeticsSchema } from "./cosmetics.js";
import { handleOwnerApi } from "./owner_api.js";
import { awardSellerVipExp, ensureVipSchema, getVipStatus } from "./vip_store.js";
import { changeVipUniqueId, consumeFreeSayHi, setVipPreference } from "./vip_actions.js";
import { ensureSupportSchema } from "./support_store.js";
import {
  acceptPendingLampMicInvite,
  claimLampTask,
  createLampMicInvite,
  getLampStatus,
  recordLampGiftActivity,
  recordLampRoomEntry,
  recordLampRoomFollow,
  recordLampRoomShare,
  roomFollowState,
  sampleLampMicProgress,
} from "./aladdin_lamp.js";

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
const decoder = new TextDecoder();

function base64UrlBytes(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlText(value) {
  return base64UrlBytes(encoder.encode(value));
}

function decodeBase64UrlText(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = Uint8Array.from(binary, (ch) => ch.charCodeAt(0));
  return decoder.decode(bytes);
}

async function hmacSignature(secret, input) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(input));
  return base64UrlBytes(new Uint8Array(signature));
}

async function signJwt(secret, header, payload) {
  const head = base64UrlText(JSON.stringify(header));
  const body = base64UrlText(JSON.stringify(payload));
  const input = head + "." + body;
  return input + "." + await hmacSignature(secret, input);
}

async function verifySessionToken(token, secret) {
  const parts = String(token ?? "").split(".");
  if (parts.length !== 3) throw new Error("invalid_session");
  const input = parts[0] + "." + parts[1];
  const expected = await hmacSignature(secret, input);
  if (expected !== parts[2]) throw new Error("invalid_session");
  const payload = JSON.parse(decodeBase64UrlText(parts[1]));
  const seconds = Math.floor(Date.now() / 1000);
  if (!payload?.sub || Number(payload.exp ?? 0) <= seconds) {
    throw new Error("session_expired");
  }
  return payload;
}


async function createSessionToken(env, userId, displayName) {
  if (!env.SESSION_SECRET) throw new Error("session_secret_not_configured");
  const seconds = Math.floor(Date.now() / 1000);
  return signJwt(
    String(env.SESSION_SECRET),
    { alg: "HS256", typ: "JWT" },
    {
      sub: String(userId),
      name: String(displayName ?? userId),
      iat: seconds,
      exp: seconds + 60 * 60 * 24 * 7,
    },
  );
}

async function verifyGoogleIdToken(idToken, expectedAudience) {
  const audience = String(expectedAudience ?? "").trim();
  if (!audience) throw new Error("google_auth_not_configured");
  const token = String(idToken ?? "").trim();
  if (!token) throw new Error("google_id_token_required");

  const response = await fetch(
    "https://oauth2.googleapis.com/tokeninfo?id_token=" + encodeURIComponent(token),
    { headers: { accept: "application/json" } },
  );
  if (!response.ok) throw new Error("invalid_google_token");
  const claims = await response.json();

  if (String(claims.aud ?? "") !== audience) {
    throw new Error("invalid_google_audience");
  }
  const issuer = String(claims.iss ?? "");
  if (issuer !== "accounts.google.com" && issuer !== "https://accounts.google.com") {
    throw new Error("invalid_google_issuer");
  }
  if (!claims.sub) throw new Error("invalid_google_subject");

  const verified = claims.email_verified === true || String(claims.email_verified ?? "") === "true";
  if (claims.email && !verified) throw new Error("google_email_not_verified");
  return claims;
}

function bearerToken(request) {
  const value = String(request.headers.get("authorization") ?? "");
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}

async function requireSession(request, env, expectedUserId) {
  let session;
  try {
    if (!env.SESSION_SECRET) throw new Error("session_secret_not_configured");
    session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
  } catch (_) {
    return json({ ok: false, error: "unauthorized" }, { status: 401 });
  }
  const actor = String(session?.sub ?? "").trim();
  if (!actor || (expectedUserId != null && actor !== String(expectedUserId))) {
    return json({ ok: false, error: "forbidden" }, { status: 403 });
  }
  return null;
}

async function bodyJson(request) {
  const value = await request.json();
  if (!value || typeof value !== "object") throw new Error("invalid_json");
  return value;
}

function requireDb(env) {
  if (!env.DB) throw new Error("database_not_bound");
  return env.DB;
}

async function ownerSetting(db, key, fallback = {}) {
  try {
    const row = await db.prepare("SELECT value_json FROM owner_settings WHERE key = ?").bind(key).first();
    if (!row?.value_json) return fallback;
    const parsed = JSON.parse(String(row.value_json));
    return parsed && typeof parsed === "object" ? parsed : fallback;
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return fallback;
    throw error;
  }
}

async function ensureUserAllowed(db, userId, { checkMute = false } = {}) {
  try {
    const control = await db.prepare(
      "SELECT status, muted_until, banned_until FROM owner_user_controls WHERE user_id = ?"
    ).bind(userId).first();
    if (!control) return;
    const ts = now();
    const bannedActive = control.status === "banned" &&
      (control.banned_until == null || Number(control.banned_until) <= 0 || Number(control.banned_until) > ts);
    if (bannedActive) throw new Error("user_banned");
    if (control.status === "suspended") throw new Error("user_suspended");
    if (checkMute && Number(control.muted_until ?? 0) > ts) throw new Error("user_muted");
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return;
    throw error;
  }
}

async function activeAnnouncements(db) {
  try {
    const ts = now();
    const rows = await db.prepare(
      `SELECT id,title,body,country,starts_at,ends_at,updated_at
         FROM owner_announcements
        WHERE enabled = 1
          AND (starts_at IS NULL OR starts_at <= ?)
          AND (ends_at IS NULL OR ends_at >= ?)
        ORDER BY updated_at DESC LIMIT 20`
    ).bind(ts, ts).all();
    return rows.results ?? [];
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return [];
    throw error;
  }
}

async function publicCatalog(db, kind) {
  try {
    const rows = await db.prepare(
      "SELECT kind,id,name,sort_order,price_coins,country,json_data,updated_at FROM owner_catalog WHERE kind = ? AND enabled = 1 ORDER BY sort_order ASC, updated_at DESC LIMIT 300"
    ).bind(kind).all();
    return (rows.results ?? []).map((row) => {
      let data = {};
      try { data = JSON.parse(String(row.json_data ?? "{}")); } catch (_) {}
      return { ...row, data };
    });
  } catch (error) {
    if (String(error?.message ?? error).includes("no such table")) return [];
    throw error;
  }
}

async function ensureUsersSchema(db) {
  // Worker deploys do not automatically apply schema.sql to D1. Make the
  // authentication path self-healing without issuing duplicate ALTER writes.
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL DEFAULT '',
      avatar_key TEXT,
      date_of_birth TEXT,
      role TEXT NOT NULL DEFAULT 'user',
      coins INTEGER NOT NULL DEFAULT 0,
      diamonds INTEGER NOT NULL DEFAULT 0,
      vip_level INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )`
  ).run();

  const info = await db.prepare("PRAGMA table_info(users)").all();
  const existing = new Set(
    (info.results ?? []).map((row) => String(row.name ?? "")),
  );
  const additions = [
    ["display_name", "TEXT NOT NULL DEFAULT ''"],
    ["avatar_key", "TEXT"],
    ["date_of_birth", "TEXT"],
    ["role", "TEXT NOT NULL DEFAULT 'user'"],
    ["coins", "INTEGER NOT NULL DEFAULT 0"],
    ["diamonds", "INTEGER NOT NULL DEFAULT 0"],
    ["vip_level", "INTEGER NOT NULL DEFAULT 0"],
    ["created_at", "INTEGER NOT NULL DEFAULT 0"],
    ["updated_at", "INTEGER NOT NULL DEFAULT 0"],
  ];
  for (const [name, definition] of additions) {
    if (existing.has(name)) continue;
    await db.prepare(`ALTER TABLE users ADD COLUMN ${name} ${definition}`).run();
  }
}

async function ensureUser(db, userId, displayName = "DarkVibeX User") {
  await ensureUsersSchema(db);
  const ts = now();
  await db.prepare(
    `INSERT INTO users (id, display_name, role, coins, diamonds, vip_level, created_at, updated_at)
     VALUES (?, ?, 'user', 2500000, 120, 0, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       display_name = CASE WHEN excluded.display_name <> '' THEN excluded.display_name ELSE users.display_name END,
       updated_at = excluded.updated_at`
  ).bind(userId, displayName, ts, ts).run();
  return db.prepare(
    "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key, date_of_birth FROM users WHERE id = ?"
  ).bind(userId).first();
}

async function ensureRoomSettingsTable(db) {
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_settings (
      room_id TEXT PRIMARY KEY,
      announcement TEXT NOT NULL DEFAULT '',
      theme_id TEXT NOT NULL DEFAULT 'dark',
      group_pk_enabled INTEGER NOT NULL DEFAULT 0,
      welcome_image_key TEXT NOT NULL DEFAULT '',
      party_mode TEXT NOT NULL DEFAULT 'Friends-making Party',
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN theme_id TEXT NOT NULL DEFAULT 'dark'").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN group_pk_enabled INTEGER NOT NULL DEFAULT 0").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN welcome_image_key TEXT NOT NULL DEFAULT ''").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN party_mode TEXT NOT NULL DEFAULT 'Friends-making Party'").run();
  } catch (_) {}
}


async function expireRoomLuckyPouches(db, roomId, ts = now()) {
  await db.batch([
    db.prepare("UPDATE room_lucky_pouches SET status='expired_pending' WHERE room_id=? AND status='open' AND expires_at<=?")
      .bind(roomId, ts),
    db.prepare("UPDATE users SET coins=coins+(SELECT COALESCE(SUM(p.remaining_coins),0) FROM room_lucky_pouches p WHERE p.room_id=? AND p.owner_user_id=users.id AND p.status='expired_pending'), updated_at=? WHERE id IN (SELECT owner_user_id FROM room_lucky_pouches WHERE room_id=? AND status='expired_pending' AND remaining_coins>0)")
      .bind(roomId, ts, roomId),
    db.prepare("INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) SELECT ?,u.id,'room_lucky_pouch_refund',p.remaining_coins,u.coins,p.id,? FROM room_lucky_pouches p JOIN users u ON u.id=p.owner_user_id WHERE p.room_id=? AND p.status='expired_pending' AND p.remaining_coins>0")
      .bind(id(), ts, roomId),
    db.prepare("UPDATE room_lucky_pouches SET status='expired_refunded' WHERE room_id=? AND status='expired_pending'")
      .bind(roomId),
  ]);
}

async function ensureRoomLuckyPouchTables(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS room_lucky_pouches (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    owner_user_id TEXT NOT NULL,
    total_coins INTEGER NOT NULL,
    total_slots INTEGER NOT NULL,
    remaining_coins INTEGER NOT NULL,
    remaining_slots INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'open',
    request_id TEXT NOT NULL,
    last_claim_key TEXT,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    UNIQUE (owner_user_id, request_id),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS room_lucky_pouch_claims (
    id TEXT PRIMARY KEY,
    claim_key TEXT NOT NULL UNIQUE,
    pouch_id TEXT NOT NULL,
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    amount INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    UNIQUE (pouch_id, user_id),
    FOREIGN KEY (pouch_id) REFERENCES room_lucky_pouches(id) ON DELETE CASCADE
  )`).run();
}

async function ensureInboxEnvelopeTables(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS inbox_red_envelopes (
      id TEXT PRIMARY KEY,
      sender_user_id TEXT NOT NULL,
      receiver_user_id TEXT NOT NULL,
      amount INTEGER NOT NULL CHECK (amount > 0),
      status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','claimed','expired')),
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      claimed_at INTEGER,
      refund_token TEXT
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS inbox_red_envelope_claims (
      envelope_id TEXT PRIMARY KEY,
      claim_token TEXT NOT NULL UNIQUE,
      user_id TEXT NOT NULL,
      amount INTEGER NOT NULL,
      claimed_at INTEGER NOT NULL,
      FOREIGN KEY (envelope_id) REFERENCES inbox_red_envelopes(id) ON DELETE CASCADE
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_inbox_envelopes_pair_time ON inbox_red_envelopes(sender_user_id,receiver_user_id,created_at DESC)"),
  ]);
}

async function expireInboxEnvelopes(db, ts = now()) {
  await ensureInboxEnvelopeTables(db);
  const expired = await db.prepare("SELECT id,sender_user_id FROM inbox_red_envelopes WHERE status='open' AND expires_at<=? ORDER BY expires_at LIMIT 500").bind(ts).all();
  for (const envelope of expired.results ?? []) {
    const token = id();
    const createdAt = ts;
    await db.batch([
      db.prepare("UPDATE inbox_red_envelopes SET status='expired',refund_token=? WHERE id=? AND status='open' AND expires_at<=?").bind(token, envelope.id, ts),
      db.prepare("UPDATE users SET coins=coins+(SELECT amount FROM inbox_red_envelopes WHERE id=? AND refund_token=?),updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM inbox_red_envelopes WHERE id=? AND refund_token=?)")
        .bind(envelope.id, token, createdAt, envelope.sender_user_id, envelope.id, token),
      db.prepare("INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) SELECT ?,u.id,'red_envelope_refund',e.amount,u.coins,e.id,? FROM users u JOIN inbox_red_envelopes e ON e.sender_user_id=u.id WHERE e.id=? AND e.refund_token=?")
        .bind(id(), createdAt, envelope.id, token),
    ]);
  }
}

async function ensureRoomAdminTable(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS room_admins (
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    added_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (room_id, user_id),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
  )`).run();
}

async function ensureRoomSafetyTables(db) {
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_bans (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      banned_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_reports (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL,
      reporter_user_id TEXT NOT NULL,
      reason TEXT NOT NULL,
      details TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
}

async function ensureLegalConsentTable(db) {
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS legal_consents (
      user_id TEXT NOT NULL,
      version TEXT NOT NULL,
      accepted_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, version),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`
  ).run();
}

async function ensureImageTables(db) {
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_images (
      room_id TEXT PRIMARY KEY,
      image_key TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )`
  ).run();
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS direct_message_images (
      message_id TEXT PRIMARY KEY,
      image_key TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )`
  ).run();
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_message_images (
      message_id TEXT PRIMARY KEY,
      image_key TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )`
  ).run();
}

async function listRooms(db) {
  await ensureImageTables(db);
  await ensureRoomSettingsTable(db);
  await ensureVipSchema(db);
  const result = await db.prepare(
    `SELECT r.id, r.name, r.owner_user_id, r.seat_count, r.locked,
            ri.image_key AS avatar_key,
            COALESCE(rs.party_mode, 'Friends-making Party') AS party_mode,
            CASE WHEN ov.level >= 18 AND ov.active_until > ?
                       AND json_extract(ov.preferences_json, '$.anonymous_everywhere') = 1
                 THEN 'Anonymous' ELSE COALESCE(u.display_name, '') END AS owner_name,
            (SELECT COUNT(*) FROM room_members m WHERE m.room_id = r.id) AS online
       FROM rooms r
       LEFT JOIN users u ON u.id = r.owner_user_id
       LEFT JOIN user_vip ov ON ov.user_id = r.owner_user_id
       LEFT JOIN room_images ri ON ri.room_id = r.id
       LEFT JOIN room_settings rs ON rs.room_id = r.id
      ORDER BY r.updated_at DESC
      LIMIT 100`
  ).bind(now()).all();
  return result.results ?? [];
}

async function walletChange(db, userId, amount, kind, referenceId = null) {
  const user = await db.prepare("SELECT coins FROM users WHERE id = ?").bind(userId).first();
  if (!user) throw new Error("user_not_found");
  const current = Number(user.coins ?? 0);
  const next = current + Number(amount);
  if (!Number.isSafeInteger(next) || next < 0) throw new Error("insufficient_coins");

  const ts = now();
  await db.batch([
    db.prepare("UPDATE users SET coins = ?, updated_at = ? WHERE id = ?").bind(next, ts, userId),
    db.prepare(
      "INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
    ).bind(id(), userId, kind, amount, next, referenceId, ts),
  ]);
  return next;
}

async function handleApi(request, env, url) {
  const db = requireDb(env);
  const parts = url.pathname.split("/").filter(Boolean);

  if (url.pathname === "/api/auth/config" && request.method === "GET") {
    return json({
      ok: true,
      google_web_client_id: String(env.GOOGLE_WEB_CLIENT_ID ?? ""),
    });
  }

  const maintenance = await ownerSetting(db, "maintenance", { enabled: false, message: "" });
  if (maintenance.enabled === true && url.pathname !== "/api/config") {
    return json({ ok: false, error: "maintenance", message: String(maintenance.message ?? "") }, { status: 503 });
  }

  if (url.pathname === "/api/config" && request.method === "GET") {
    const keys = ["feature.voice", "feature.gifts", "feature.games", "feature.messages", "feature.room_creation", "feature.aladdin_lamp", "maintenance"];
    const settings = {};
    for (const key of keys) settings[key] = await ownerSetting(db, key, {});
    return json({ ok: true, settings, announcements: await activeAnnouncements(db) });
  }

  if (url.pathname === "/api/catalog" && request.method === "GET") {
    const kind = String(url.searchParams.get("kind") ?? "").trim().slice(0, 60);
    if (!kind) return json({ ok: false, error: "kind_required" }, { status: 400 });
    return json({ ok: true, items: await publicCatalog(db, kind) });
  }

  if (parts[0] === "api" && parts[1] === "cosmetics" && parts.length === 3 && request.method === "GET") {
    const userId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUser(db, userId);
    await ensureCosmeticsSchema(db);
    const owned = await db.prepare(
      "SELECT item_id, kind, acquired_at, expires_at, active FROM user_cosmetics WHERE user_id = ? AND expires_at > ? ORDER BY acquired_at DESC"
    ).bind(userId, now()).all();
    return json({ ok: true, items: COSMETIC_CATALOG, owned: owned.results ?? [] });
  }

  if (url.pathname === "/api/cosmetics/purchase" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const recipientId = String(body.recipient_user_id ?? userId).trim();
    const itemId = String(body.item_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const product = COSMETIC_CATALOG.find((item) => item.id === itemId);
    if (!product) return json({ ok: false, error: "cosmetic_not_found" }, { status: 404 });
    await ensureUser(db, userId);
    if (!recipientId) return json({ ok: false, error: "recipient_required" }, { status: 400 });
    if (recipientId !== userId) {
      const recipient = await db.prepare("SELECT id FROM users WHERE id = ?").bind(recipientId).first();
      if (!recipient) return json({ ok: false, error: "recipient_not_found" }, { status: 404 });
    }
    await ensureUserAllowed(db, userId);
    if (recipientId !== userId) await ensureUserAllowed(db, recipientId);
    await ensureCosmeticsSchema(db);
    await ensureVipSchema(db);
    const ts = now();
    const vip = await db.prepare("SELECT level, active_until FROM user_vip WHERE user_id = ?").bind(recipientId).first();
    const vipLevel = Number(vip?.active_until ?? 0) > ts ? Number(vip?.level ?? 0) : 0;
    if (vipLevel < product.min_vip_level) {
      return json({ ok: false, error: "vip_level_required", required_level: product.min_vip_level }, { status: 403 });
    }
    const expiresAt = ts + product.duration_days * 24 * 60 * 60 * 1000;
    const result = await db.batch([
      db.prepare(
        "UPDATE users SET coins = coins - ?, updated_at = ? WHERE id = ? AND coins >= ? AND NOT EXISTS (SELECT 1 FROM user_cosmetics WHERE user_id = ? AND item_id = ? AND expires_at > ?)"
      ).bind(product.price_coins, ts, userId, product.price_coins, recipientId, product.id, ts),
      db.prepare(
        "INSERT INTO user_cosmetics (user_id,item_id,kind,acquired_at,expires_at,active) SELECT ?,?,?,?,?,0 WHERE changes() = 1 ON CONFLICT(user_id,item_id) DO UPDATE SET kind=excluded.kind, acquired_at=excluded.acquired_at, expires_at=excluded.expires_at, active=0 WHERE user_cosmetics.expires_at <= ?"
      ).bind(recipientId, product.id, product.kind, ts, expiresAt, ts),
      db.prepare(
        "INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) SELECT ?,id,?, ?,coins,?,? FROM users WHERE id=? AND EXISTS (SELECT 1 FROM user_cosmetics WHERE user_id=? AND item_id=? AND acquired_at=?)"
      ).bind(id(), recipientId === userId ? "cosmetic_purchase" : "cosmetic_gift", -product.price_coins, product.id, ts, userId, recipientId, product.id, ts),
    ]);
    if (Number(result[0]?.meta?.changes ?? 0) !== 1) {
      const alreadyOwned = await db.prepare("SELECT 1 AS owned FROM user_cosmetics WHERE user_id = ? AND item_id = ? AND expires_at > ?")
        .bind(recipientId, product.id, ts).first();
      return json({ ok: false, error: alreadyOwned ? "already_owned" : "insufficient_coins" }, { status: alreadyOwned ? 409 : 400 });
    }
    const wallet = await db.prepare("SELECT coins FROM users WHERE id = ?").bind(userId).first();
    return json({ ok: true, item_id: product.id, coin_balance: Number(wallet?.coins ?? 0), expires_at: expiresAt, recipient_user_id: recipientId });
  }

  if (url.pathname === "/api/cosmetics/equip" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const itemId = String(body.item_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUserAllowed(db, userId);
    await ensureCosmeticsSchema(db);
    await ensureVipSchema(db);
    const item = COSMETIC_CATALOG.find((product) => product.id === itemId);
    if (!item) return json({ ok: false, error: "cosmetic_not_found" }, { status: 404 });
    const vip = await db.prepare("SELECT level, active_until FROM user_vip WHERE user_id = ?").bind(userId).first();
    if (Number(vip?.active_until ?? 0) <= now() || Number(vip?.level ?? 0) < item.min_vip_level) {
      return json({ ok: false, error: "vip_level_required", required_level: item.min_vip_level }, { status: 403 });
    }
    const owned = await db.prepare("SELECT 1 AS owned FROM user_cosmetics WHERE user_id = ? AND item_id = ? AND expires_at > ?")
      .bind(userId, itemId, now()).first();
    if (!owned) return json({ ok: false, error: "cosmetic_not_owned" }, { status: 403 });
    await db.batch([
      db.prepare("UPDATE user_cosmetics SET active = 0 WHERE user_id = ? AND kind = ?").bind(userId, item.kind),
      db.prepare("UPDATE user_cosmetics SET active = 1 WHERE user_id = ? AND item_id = ? AND expires_at > ?").bind(userId, itemId, now()),
    ]);
    return json({ ok: true, item_id: itemId });
  }

  if (url.pathname === "/api/roles/validate" && request.method === "POST") {
    const body = await bodyJson(request);
    return json({ ok: true, role: normalizeRole(body.role) });
  }

  if (url.pathname === "/api/session/google" && request.method === "POST") {
    if (!env.SESSION_SECRET) {
      return json({ ok: false, error: "session_secret_not_configured" }, { status: 503 });
    }
    const body = await bodyJson(request);
    const idToken = String(body.id_token ?? "").trim();
    if (!idToken) return json({ ok: false, error: "google_id_token_required" }, { status: 400 });

    let claims;
    try {
      claims = await verifyGoogleIdToken(idToken, env.GOOGLE_WEB_CLIENT_ID);
    } catch (error) {
      const code = String(error?.message ?? error);
      const status = code === "google_auth_not_configured" ? 503 : 401;
      return json({ ok: false, error: code }, { status });
    }

    const userId = "g_" + String(claims.sub);
    const displayName = String(
      claims.name ?? claims.given_name ?? claims.email ?? "DarkVibeX User"
    ).trim().slice(0, 60);

    let user;
    try {
      user = await ensureUser(db, userId, displayName);
    } catch (error) {
      console.error("Google session user storage failed", error);
      return json({ ok: false, error: "google_session_storage_failed" }, { status: 503 });
    }

    try {
      await ensureUserAllowed(db, userId);
    } catch (error) {
      const code = String(error?.message ?? error);
      if (code === "user_banned" || code === "user_suspended") {
        return json({ ok: false, error: code }, { status: 403 });
      }
      console.error("Google session user policy failed", error);
      return json({ ok: false, error: "google_session_policy_failed" }, { status: 503 });
    }

    let token;
    try {
      token = await createSessionToken(env, userId, user.display_name);
    } catch (error) {
      console.error("Google session token creation failed", error);
      return json({ ok: false, error: "google_session_token_failed" }, { status: 503 });
    }
    return json({ ok: true, token, user, provider: "google" });
  }

  if (url.pathname === "/api/session/guest" && request.method === "POST") {
    if (!env.SESSION_SECRET) {
      return json({ ok: false, error: "session_secret_not_configured" }, { status: 503 });
    }
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim() ||
      String(Math.floor(10000000 + Math.random() * 90000000));
    const displayName = String(body.display_name ?? "DarkVibeX User").trim().slice(0, 60);
    const user = await ensureUser(db, userId, displayName);
    await ensureUserAllowed(db, userId);
    const token = await createSessionToken(env, userId, user.display_name);
    return json({ ok: true, token, user, provider: "guest" });
  }

  if (url.pathname === "/api/users/upsert" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const user = await ensureUser(db, userId, String(body.display_name ?? "").trim());
    await ensureUserAllowed(db, userId);
    return json({ ok: true, user });
  }

  if (url.pathname === "/api/users/profile" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const displayName = String(body.display_name ?? "").trim().slice(0, 60);
    const dateOfBirth = String(body.date_of_birth ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    if (!displayName) return json({ ok: false, error: "display_name_required" }, { status: 400 });
    if (dateOfBirth && !/^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth)) {
      return json({ ok: false, error: "invalid_date_of_birth" }, { status: 400 });
    }
    await ensureUsersSchema(db);
    await db.prepare(
      "UPDATE users SET display_name = ?, date_of_birth = ?, updated_at = ? WHERE id = ?"
    ).bind(displayName, dateOfBirth || null, now(), userId).run();
    const user = await db.prepare(
      "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key, date_of_birth FROM users WHERE id = ?"
    ).bind(userId).first();
    return json({ ok: true, user });
  }

  if (url.pathname === "/api/users/avatar" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const imageKey = String(body.avatar_key ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!imageKey.startsWith(`users/${userId}/avatar-`) || !/\.(jpg|jpeg|png|webp)$/i.test(imageKey)) {
      return json({ ok: false, error: "invalid_avatar_key" }, { status: 400 });
    }
    await db.prepare("UPDATE users SET avatar_key = ?, updated_at = ? WHERE id = ?")
      .bind(imageKey, now(), userId).run();
    return json({ ok: true, avatar_key: imageKey });
  }

  if (parts[0] === "api" && parts[1] === "users" && parts.length === 4 && parts[3] === "visitors" && request.method === "GET") {
    const userId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const rows = await db.prepare(
      `SELECT v.visitor_user_id AS user_id,
              CASE WHEN av.level >= 18 AND av.active_until > ?
                         AND json_extract(av.preferences_json, '$.anonymous_everywhere') = 1
                   THEN 'Anonymous' ELSE u.display_name END AS display_name,
              u.avatar_key, v.first_visited_at, v.last_visited_at, v.visit_count
         FROM profile_visitors v
         JOIN users u ON u.id = v.visitor_user_id
         LEFT JOIN user_vip av ON av.user_id = v.visitor_user_id
        WHERE v.viewed_user_id = ?
        ORDER BY v.last_visited_at DESC LIMIT 100`
    ).bind(now(), userId).all();
    return json({ ok: true, visitors: rows.results ?? [] });
  }

  if (parts[0] === "api" && parts[1] === "users" && parts.length === 3 && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const viewerId = String(session.sub);
    const viewedUserId = String(parts[2] ?? "").trim();
    await ensureVipSchema(db);
    const user = await db.prepare(
      "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key FROM users WHERE id = ?"
    ).bind(viewedUserId).first();
    if (user) {
      const targetVip = await getVipStatus(db, viewedUserId);
      user.active_vip_level = targetVip.active ? targetVip.level : 0;
      user.privacy_protection_enabled = targetVip.active && targetVip.level >= 15 && targetVip.preferences.privacy_protection === true;
    }
    if (user && viewerId !== viewedUserId) {
      const targetVip = await getVipStatus(db, viewedUserId);
      if (targetVip.active && targetVip.level >= 18 && targetVip.preferences.anonymous_everywhere === true) {
        user.display_name = "Anonymous";
      }
      const viewerVip = await getVipStatus(db, viewerId);
      const shouldHide = viewerVip.active && viewerVip.level >= 11 && viewerVip.preferences.hide_visitors === true;
      if (!shouldHide) {
        const ts = now();
        await db.prepare(
          "INSERT INTO profile_visitors (viewed_user_id,visitor_user_id,first_visited_at,last_visited_at,visit_count) VALUES (?,?,?,?,1) ON CONFLICT(viewed_user_id,visitor_user_id) DO UPDATE SET last_visited_at=excluded.last_visited_at,visit_count=profile_visitors.visit_count+1"
        ).bind(viewedUserId, viewerId, ts, ts).run();
      }
    }
    return user ? json({ ok: true, user }) : json({ ok: false, error: "not_found" }, { status: 404 });
  }

  if (url.pathname === "/api/legal/consent" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const version = String(url.searchParams.get("version") ?? "").trim().slice(0, 40);
    if (!version) return json({ ok: false, error: "version_required" }, { status: 400 });
    await ensureLegalConsentTable(db);
    const row = await db.prepare(
      "SELECT 1 AS accepted FROM legal_consents WHERE user_id = ? AND version = ?"
    ).bind(String(session.sub), version).first();
    return json({ ok: true, accepted: Boolean(row) });
  }

  if (url.pathname === "/api/legal/consent" && request.method === "POST") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const body = await bodyJson(request);
    const version = String(body.version ?? "").trim().slice(0, 40);
    if (!version) return json({ ok: false, error: "version_required" }, { status: 400 });
    await ensureLegalConsentTable(db);
    await db.prepare(
      "INSERT OR IGNORE INTO legal_consents (user_id, version, accepted_at) VALUES (?, ?, ?)"
    ).bind(String(session.sub), version, now()).run();
    return json({ ok: true, accepted: true, version });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "lucky-pouch") {
    const roomId = parts[2];
    await ensureRoomLuckyPouchTables(db);
    const room = await db.prepare("SELECT id, owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const userId = String(session.sub);
    const member = await db.prepare("SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?")
      .bind(roomId, userId).first();
    if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    await expireRoomLuckyPouches(db, roomId, now());

    if (request.method === "GET") {
      const pouch = await db.prepare(
        `SELECT p.id, p.owner_user_id, p.total_coins, p.total_slots, p.remaining_coins,
                p.remaining_slots, p.expires_at,
                EXISTS(SELECT 1 FROM room_lucky_pouch_claims c WHERE c.pouch_id = p.id AND c.user_id = ?) AS claimed
           FROM room_lucky_pouches p
          WHERE p.room_id = ? AND p.status = 'open' AND p.expires_at > ?
          ORDER BY p.created_at DESC LIMIT 1`
      ).bind(userId, roomId, now()).first();
      return json({ ok: true, pouch: pouch ?? null });
    }

    if (request.method === "POST") {
      const body = await bodyJson(request);
      const actorId = String(body.user_id ?? "").trim();
      const ownerError = await requireSession(request, env, actorId);
      if (ownerError) return ownerError;
      const totalCoins = Number(body.total_coins);
      const slots = Number(body.slots);
      const requestId = String(body.request_id ?? "").trim().slice(0, 100);
      if (!Number.isSafeInteger(totalCoins) || totalCoins < 100 || totalCoins > 10000000 ||
          !Number.isSafeInteger(slots) || slots < 2 || slots > 500 || !requestId) {
        return json({ ok: false, error: "invalid_pouch" }, { status: 400 });
      }
      const existing = await db.prepare("SELECT id FROM room_lucky_pouches WHERE owner_user_id = ? AND request_id = ?")
        .bind(actorId, requestId).first();
      if (existing) return json({ ok: true, pouch_id: existing.id, duplicate: true });
      const active = await db.prepare("SELECT id FROM room_lucky_pouches WHERE room_id = ? AND status = 'open' AND expires_at > ?")
        .bind(roomId, now()).first();
      if (active) return json({ ok: false, error: "pouch_already_active" }, { status: 409 });
      const pouchId = id();
      const ts = now();
      const balance = await db.prepare("SELECT coins FROM users WHERE id = ?").bind(actorId).first();
      if (!balance || Number(balance.coins ?? 0) < totalCoins) return json({ ok: false, error: "insufficient_coins" }, { status: 409 });
      await db.batch([
        db.prepare("INSERT INTO room_lucky_pouches (id, room_id, owner_user_id, total_coins, total_slots, remaining_coins, remaining_slots, status, request_id, created_at, expires_at) SELECT ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?, ? WHERE EXISTS (SELECT 1 FROM users WHERE id = ? AND coins >= ?)")
          .bind(pouchId, roomId, actorId, totalCoins, slots, totalCoins, slots, requestId, ts, ts + 86400000, actorId, totalCoins),
        db.prepare("UPDATE users SET coins = coins - ?, updated_at = ? WHERE id = ? AND coins >= ? AND EXISTS (SELECT 1 FROM room_lucky_pouches WHERE id = ?)")
          .bind(totalCoins, ts, actorId, totalCoins, pouchId),
        db.prepare("INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) SELECT ?, ?, 'room_lucky_pouch_create', ?, coins, ?, ? FROM users WHERE id = ? AND EXISTS (SELECT 1 FROM room_lucky_pouches WHERE id = ?)")
          .bind(id(), actorId, -totalCoins, pouchId, ts, actorId, pouchId),
      ]);
      const created = await db.prepare("SELECT id FROM room_lucky_pouches WHERE id = ?").bind(pouchId).first();
      if (!created) return json({ ok: false, error: "insufficient_coins" }, { status: 409 });
      const updated = await db.prepare("SELECT coins FROM users WHERE id = ?").bind(actorId).first();
      return json({ ok: true, pouch_id: pouchId, coin_balance: Number(updated?.coins ?? 0) });
    }
    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 5 &&
      parts[3] === "lucky-pouch" && parts[4] === "claim" && request.method === "POST") {
    const roomId = parts[2];
    await ensureRoomLuckyPouchTables(db);
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const member = await db.prepare("SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?")
      .bind(roomId, userId).first();
    if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    await expireRoomLuckyPouches(db, roomId, now());
    const pouch = await db.prepare(
      "SELECT * FROM room_lucky_pouches WHERE room_id = ? AND status = 'open' AND expires_at > ? ORDER BY created_at DESC LIMIT 1"
    ).bind(roomId, now()).first();
    if (!pouch) return json({ ok: false, error: "no_active_pouch" }, { status: 404 });
    const prior = await db.prepare("SELECT amount FROM room_lucky_pouch_claims WHERE pouch_id = ? AND user_id = ?")
      .bind(pouch.id, userId).first();
    if (prior) return json({ ok: true, amount: Number(prior.amount), duplicate: true });
    const remainingCoins = Number(pouch.remaining_coins);
    const remainingSlots = Number(pouch.remaining_slots);
    if (remainingSlots < 1 || remainingCoins < remainingSlots) return json({ ok: false, error: "pouch_empty" }, { status: 409 });
    const amount = remainingSlots === 1 ? remainingCoins : 1 + Math.floor(Math.random() * (remainingCoins - remainingSlots + 1));
    const claimKey = id();
    const ts = now();
    await db.batch([
      db.prepare("UPDATE room_lucky_pouches SET remaining_coins = remaining_coins - ?, remaining_slots = remaining_slots - 1, status = CASE WHEN remaining_slots = 1 THEN 'claimed' ELSE status END, last_claim_key = ? WHERE id = ? AND remaining_coins = ? AND remaining_slots = ? AND status = 'open' AND expires_at > ? AND NOT EXISTS (SELECT 1 FROM room_lucky_pouch_claims WHERE pouch_id = ? AND user_id = ?)")
        .bind(amount, claimKey, pouch.id, remainingCoins, remainingSlots, ts, pouch.id, userId),
      db.prepare("INSERT INTO room_lucky_pouch_claims (id, claim_key, pouch_id, room_id, user_id, amount, created_at) SELECT ?, ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM room_lucky_pouches WHERE id = ? AND last_claim_key = ?)")
        .bind(claimKey, claimKey, pouch.id, roomId, userId, amount, ts, pouch.id, claimKey),
      db.prepare("UPDATE users SET coins = coins + ?, updated_at = ? WHERE id = ? AND EXISTS (SELECT 1 FROM room_lucky_pouch_claims WHERE claim_key = ?)")
        .bind(amount, ts, userId, claimKey),
      db.prepare("INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) SELECT ?, ?, 'room_lucky_pouch_claim', ?, coins, ?, ? FROM users WHERE id = ? AND EXISTS (SELECT 1 FROM room_lucky_pouch_claims WHERE claim_key = ?)")
        .bind(id(), userId, amount, pouch.id, ts, userId, claimKey),
    ]);
    const claim = await db.prepare("SELECT amount FROM room_lucky_pouch_claims WHERE claim_key = ? AND user_id = ?")
      .bind(claimKey, userId).first();
    if (!claim) {
      const duplicate = await db.prepare("SELECT amount FROM room_lucky_pouch_claims WHERE pouch_id = ? AND user_id = ?")
        .bind(pouch.id, userId).first();
      if (duplicate) return json({ ok: true, amount: Number(duplicate.amount), duplicate: true });
      return json({ ok: false, error: "claim_race_retry" }, { status: 409 });
    }
    const balance = await db.prepare("SELECT coins FROM users WHERE id = ?").bind(userId).first();
    return json({ ok: true, amount: Number(claim.amount), coin_balance: Number(balance?.coins ?? 0) });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "settings") {
    const roomId = parts[2];
    await ensureRoomSettingsTable(db);
    await ensureVipSchema(db);
    const room = await db.prepare(
      `SELECT r.id, r.owner_user_id, r.name, r.seat_count, r.locked,
              COALESCE(s.announcement, '') AS announcement, COALESCE(s.theme_id, 'dark') AS theme_id, COALESCE(s.group_pk_enabled, 0) AS group_pk_enabled,
              COALESCE(s.party_mode, 'Friends-making Party') AS party_mode,
              CASE WHEN ov.level >= 5 AND ov.active_until > ? THEN COALESCE(s.welcome_image_key, '') ELSE '' END AS welcome_image_key
         FROM rooms r LEFT JOIN room_settings s ON s.room_id = r.id
         LEFT JOIN user_vip ov ON ov.user_id = r.owner_user_id
        WHERE r.id = ?`
    ).bind(now(), roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    if (request.method === "GET") {
      const authError = await requireSession(request, env);
      if (authError) return authError;
      const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
      const member = await db.prepare(
        "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, String(session.sub)).first();
      if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      return json({ ok: true, settings: room });
    }
    if (request.method === "POST") {
      const body = await bodyJson(request);
      const userId = String(body.user_id ?? "").trim();
      const authError = await requireSession(request, env, userId);
      if (authError) return authError;
      if (room.owner_user_id !== userId) return json({ ok: false, error: "room_owner_required" }, { status: 403 });
      const name = String(body.name ?? "").trim().slice(0, 80);
      const requestedSeatCount = Number(body.seat_count ?? room.seat_count);
      if (!Number.isSafeInteger(requestedSeatCount) || requestedSeatCount < 8 || requestedSeatCount > 42) {
        return json({ ok: false, error: "invalid_seat_count" }, { status: 400 });
      }
      const vipStatus = await getVipStatus(db, userId);
      const maxSeats = Math.max(8, Math.min(42, Number(vipStatus.room_seat_limit ?? 12)));
      if (requestedSeatCount > maxSeats && requestedSeatCount > Number(room.seat_count)) {
        return json({ ok: false, error: "room_seat_limit", max_seats: maxSeats }, { status: 403 });
      }
      const seatCount = requestedSeatCount;
      const locked = body.locked === true ? 1 : 0;
      const announcement = String(body.announcement ?? "").trim().slice(0, 500);
      const welcomeImageKey = Object.prototype.hasOwnProperty.call(body, "welcome_image_key")
        ? String(body.welcome_image_key ?? "").trim()
        : String(room.welcome_image_key ?? "");
      if (welcomeImageKey && welcomeImageKey !== String(room.welcome_image_key ?? "")) {
        if (!vipStatus.picture_welcome_enabled) {
          return json({ ok: false, error: "vip5_required_for_picture_welcome" }, { status: 403 });
        }
        if (!welcomeImageKey.startsWith(`users/${userId}/welcome-${roomId}-`) || !/\.(jpg|jpeg|png|webp)$/i.test(welcomeImageKey)) {
          return json({ ok: false, error: "invalid_welcome_image_key" }, { status: 400 });
        }
      }
      const allowedThemes = new Set(["dark", "midnight", "rose", "forest", "gold"]);
      const themeId = String(body.theme_id ?? room.theme_id ?? "dark");
      if (!allowedThemes.has(themeId)) return json({ ok: false, error: "invalid_theme" }, { status: 400 });
      if (themeId !== "dark" && themeId !== room.theme_id && !vipStatus.room_background_enabled) {
        return json({ ok: false, error: "vip3_required_for_room_background" }, { status: 403 });
      }
      const groupPkEnabled = body.group_pk_enabled === true ? 1 : 0;
      const requestedPartyMode = String(body.party_mode ?? room.party_mode ?? "Friends-making Party").trim();
      const partyMode = requestedPartyMode === "Event hosting mode" ? "Event hosting mode" : "Friends-making Party";
      if (!name) return json({ ok: false, error: "room_name_required" }, { status: 400 });
      const overflow = await db.prepare(
        "SELECT COUNT(*) AS total FROM room_members WHERE room_id = ? AND seat_index >= ?"
      ).bind(roomId, seatCount).first();
      if (Number(overflow?.total ?? 0) > 0) {
        return json({ ok: false, error: "seats_occupied" }, { status: 409 });
      }
      const ts = now();
      await db.batch([
        db.prepare("UPDATE rooms SET name = ?, seat_count = ?, locked = ?, updated_at = ? WHERE id = ?")
          .bind(name, seatCount, locked, ts, roomId),
        db.prepare(
          "INSERT INTO room_settings (room_id, announcement, theme_id, group_pk_enabled, welcome_image_key, party_mode, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(room_id) DO UPDATE SET announcement = excluded.announcement, theme_id = excluded.theme_id, group_pk_enabled = excluded.group_pk_enabled, welcome_image_key = excluded.welcome_image_key, party_mode = excluded.party_mode, updated_at = excluded.updated_at"
        ).bind(roomId, announcement, themeId, groupPkEnabled, welcomeImageKey, partyMode, ts),
      ]);
      return json({ ok: true, settings: { ...room, name, seat_count: seatCount, locked, announcement, theme_id: themeId, group_pk_enabled: groupPkEnabled, welcome_image_key: welcomeImageKey, party_mode: partyMode } });
    }
    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  if (url.pathname === "/api/rooms" && request.method === "GET") {
    return json({ ok: true, rooms: await listRooms(db) });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "avatar" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const imageKey = String(body.avatar_key ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const room = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    if (room.owner_user_id !== userId) return json({ ok: false, error: "room_owner_required" }, { status: 403 });
    if (!imageKey.startsWith(`rooms/${roomId}/avatar-`) || !/\.(jpg|jpeg|png|webp)$/i.test(imageKey)) {
      return json({ ok: false, error: "invalid_avatar_key" }, { status: 400 });
    }
    await ensureImageTables(db);
    await db.prepare(
      "INSERT INTO room_images (room_id, image_key, updated_at) VALUES (?, ?, ?) ON CONFLICT(room_id) DO UPDATE SET image_key = excluded.image_key, updated_at = excluded.updated_at"
    ).bind(roomId, imageKey, now()).run();
    return json({ ok: true, avatar_key: imageKey });
  }

  if (url.pathname === "/api/rooms" && request.method === "POST") {
    const roomCreation = await ownerSetting(db, "feature.room_creation", { enabled: true });
    if (roomCreation.enabled === false) return json({ ok: false, error: "room_creation_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const ownerId = String(body.owner_user_id ?? "").trim();
    const name = String(body.name ?? "").trim().slice(0, 80);
    const authError = await requireSession(request, env, ownerId);
    if (authError) return authError;
    const requestedSeatCount = Number(body.seat_count ?? 12);
    const requestedPartyMode = String(body.party_mode ?? "Friends-making Party").trim();
    const partyMode = requestedPartyMode === "Event hosting mode" ? "Event hosting mode" : "Friends-making Party";
    if (!ownerId || !name) return json({ ok: false, error: "owner_and_name_required" }, { status: 400 });
    if (!Number.isSafeInteger(requestedSeatCount) || requestedSeatCount < 8 || requestedSeatCount > 42) {
      return json({ ok: false, error: "invalid_seat_count" }, { status: 400 });
    }
    await ensureUser(db, ownerId, String(body.owner_name ?? "DarkVibeX User"));
    await ensureUserAllowed(db, ownerId);
    const vipStatus = await getVipStatus(db, ownerId);
    const seatCount = Math.max(8, Math.min(requestedSeatCount, Number(vipStatus.room_seat_limit ?? 12)));
    const roomId = String(body.id ?? "").trim() || String(Math.floor(100000 + Math.random() * 900000));
    const ts = now();
    await db.prepare(
      "INSERT INTO rooms (id, owner_user_id, name, seat_count, locked, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)"
    ).bind(roomId, ownerId, name, seatCount, ts, ts).run();
    await ensureRoomSettingsTable(db);
    await db.prepare(
      "INSERT INTO room_settings (room_id, announcement, theme_id, group_pk_enabled, welcome_image_key, party_mode, updated_at) VALUES (?, '', 'dark', 0, '', ?, ?) ON CONFLICT(room_id) DO UPDATE SET party_mode = excluded.party_mode, updated_at = excluded.updated_at"
    ).bind(roomId, partyMode, ts).run();
    await db.prepare(
      "INSERT OR REPLACE INTO room_members (room_id, user_id, seat_index, mic_muted, joined_at, updated_at) VALUES (?, ?, NULL, 1, ?, ?)"
    ).bind(roomId, ownerId, ts, ts).run();
    return json({ ok: true, room_id: roomId, party_mode: partyMode }, { status: 201 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "join" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUser(db, userId, String(body.display_name ?? "DarkVibeX User"));
    await ensureUserAllowed(db, userId);
    const roomAccess = await db.prepare(
      "SELECT owner_user_id, locked FROM rooms WHERE id = ?"
    ).bind(roomId).first();
    if (!roomAccess) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    await ensureRoomSafetyTables(db);
    const roomBan = await db.prepare(
      "SELECT 1 AS blocked FROM room_bans WHERE room_id = ? AND user_id = ?"
    ).bind(roomId, userId).first();
    if (roomBan && roomAccess.owner_user_id !== userId) {
      return json({ ok: false, error: "room_blocked" }, { status: 403 });
    }
    if (Number(roomAccess.locked) === 1 && roomAccess.owner_user_id !== userId) {
      return json({ ok: false, error: "room_locked" }, { status: 403 });
    }
    const ts = now();
    await db.prepare(
      "INSERT INTO room_members (room_id, user_id, seat_index, mic_muted, joined_at, updated_at) VALUES (?, ?, NULL, 1, ?, ?) ON CONFLICT(room_id,user_id) DO UPDATE SET updated_at = excluded.updated_at"
    ).bind(roomId, userId, ts, ts).run();
    await recordLampRoomEntry(db, roomId, userId, ts);
    const idLevelDailyExp = await awardIdLevelDaily(db, userId, "room_entry", ts);
    return json({ ok: true, id_level_daily_exp: idLevelDailyExp });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "leave" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const result = await db.prepare(
      "DELETE FROM room_members WHERE room_id = ? AND user_id = ?"
    ).bind(roomId, userId).run();
    return json({ ok: Number(result.meta?.changes ?? 0) > 0 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "seat" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const seatIndex = body.seat_index == null ? null : Number(body.seat_index);
    const muted = body.mic_muted === false ? 0 : 1;
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUserAllowed(db, userId);
    const room = await db.prepare("SELECT seat_count FROM rooms WHERE id = ?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    const member = await db.prepare("SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?")
      .bind(roomId, userId).first();
    if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    if (seatIndex != null && (!Number.isSafeInteger(seatIndex) || seatIndex < 0 || seatIndex >= Number(room.seat_count))) {
      return json({ ok: false, error: "invalid_seat_index" }, { status: 400 });
    }
    await sampleLampMicProgress(db, roomId, now());
    const result = await db.prepare(
      `UPDATE room_members
          SET seat_index = ?, mic_muted = ?, updated_at = ?
        WHERE room_id = ? AND user_id = ?
          AND (? IS NULL OR NOT EXISTS (
            SELECT 1 FROM room_members other
             WHERE other.room_id = ? AND other.seat_index = ? AND other.user_id <> ?
          ))`
    ).bind(seatIndex, muted, now(), roomId, userId, seatIndex, roomId, seatIndex, userId).run();
    if (Number(result.meta?.changes ?? 0) === 0) {
      const occupied = seatIndex == null ? null : await db.prepare(
        "SELECT 1 AS occupied FROM room_members WHERE room_id = ? AND seat_index = ? AND user_id <> ?"
      ).bind(roomId, seatIndex, userId).first();
      if (occupied) return json({ ok: false, error: "seat_occupied" }, { status: 409 });
      return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    }
    if (seatIndex != null) await acceptPendingLampMicInvite(db, roomId, userId, now());
    return json({ ok: true, seat_index: seatIndex, mic_muted: Boolean(muted) });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "messages") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const roomId = parts[2];
    if (request.method === "GET") {
      await ensureVipSchema(db);
      await ensureImageTables(db);
      const authError = await requireSession(request, env);
      if (authError) return authError;
      const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
      const member = await db.prepare(
        "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, String(session.sub)).first();
      if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      const rows = await db.prepare(
        `SELECT m.id, m.user_id,
                CASE WHEN v.level >= 18 AND v.active_until > ?
                           AND json_extract(v.preferences_json, '$.anonymous_everywhere') = 1
                     THEN 'Anonymous' ELSE u.display_name END AS display_name,
                m.text, m.created_at, mi.image_key
           FROM room_messages m
           LEFT JOIN users u ON u.id = m.user_id
           LEFT JOIN user_vip v ON v.user_id = m.user_id
           LEFT JOIN room_message_images mi ON mi.message_id = m.id
          WHERE m.room_id = ?
          ORDER BY m.created_at DESC LIMIT 100`
      ).bind(now(), roomId).all();
      return json({ ok: true, messages: (rows.results ?? []).reverse() });
    }
    if (request.method === "POST") {
      const body = await bodyJson(request);
      const userId = String(body.user_id ?? "").trim();
      const authError = await requireSession(request, env, userId);
      if (authError) return authError;
      await ensureUserAllowed(db, userId, { checkMute: true });
      const membership = await db.prepare(
        "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, userId).first();
      if (!membership) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      const textValue = String(body.text ?? "").trim().slice(0, 500);
      const imageKey = String(body.image_key ?? "").trim();
      if (!userId || (!textValue && !imageKey)) return json({ ok: false, error: "message_required" }, { status: 400 });
      if (imageKey) {
        if (!imageKey.startsWith(`messages/${userId}/`) || !/\.(jpg|jpeg|png|webp)$/i.test(imageKey)) {
          return json({ ok: false, error: "invalid_image_key" }, { status: 400 });
        }
        const vip = await getVipStatus(db, userId, now());
        if (!vip.room_images_enabled) return json({ ok: false, error: "vip_required", required_level: 10 }, { status: 403 });
      }
      const messageId = id();
      await ensureImageTables(db);
      const createdAt = now();
      const statements = [db.prepare(
        "INSERT INTO room_messages (id, room_id, user_id, text, created_at) VALUES (?, ?, ?, ?, ?)"
      ).bind(messageId, roomId, userId, textValue, createdAt)];
      if (imageKey) {
        statements.push(db.prepare("INSERT INTO room_message_images (message_id, image_key, created_at) VALUES (?, ?, ?)")
          .bind(messageId, imageKey, createdAt));
      }
      await db.batch(statements);
      return json({ ok: true, message_id: messageId, image_key: imageKey || null }, { status: 201 });
    }
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "members") {
    const roomId = parts[2];
    await ensureRoomAdminTable(db);
    if (request.method === "GET") {
      await ensureVipSchema(db);
      await ensureCosmeticsSchema(db);
      const authError = await requireSession(request, env);
      if (authError) return authError;
      const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
      const actorId = String(session.sub);
      const member = await db.prepare(
        "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, actorId).first();
      if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      const rows = await db.prepare(
        `SELECT m.user_id,
                CASE WHEN v.level >= 18 AND v.active_until > ?
                           AND json_extract(v.preferences_json, '$.anonymous_everywhere') = 1
                     THEN 'Anonymous' ELSE u.display_name END AS display_name,
                u.avatar_key,
                CASE WHEN v.active_until > ? THEN v.level ELSE 0 END AS active_vip_level,
                CASE WHEN v.level >= 14 AND v.active_until > ?
                           AND json_extract(v.preferences_json, '$.invisible_entry') = 1
                     THEN 1 ELSE 0 END AS invisible_entry,
                (SELECT c.item_id FROM user_cosmetics c WHERE c.user_id = m.user_id AND c.kind = 'frame' AND c.active = 1 AND c.expires_at > ? LIMIT 1) AS active_frame_id,
                (SELECT c.item_id FROM user_cosmetics c WHERE c.user_id = m.user_id AND c.kind = 'vehicle' AND c.active = 1 AND c.expires_at > ? LIMIT 1) AS active_vehicle_id,
                m.seat_index, m.mic_muted, m.joined_at, m.updated_at,
                CASE WHEN r.owner_user_id = m.user_id THEN 1 ELSE 0 END AS is_owner,
                CASE WHEN ra.user_id IS NULL THEN 0 ELSE 1 END AS is_admin
           FROM room_members m
           LEFT JOIN users u ON u.id = m.user_id
           LEFT JOIN user_vip v ON v.user_id = m.user_id
           LEFT JOIN rooms r ON r.id = m.room_id
           LEFT JOIN room_admins ra ON ra.room_id = m.room_id AND ra.user_id = m.user_id
          WHERE m.room_id = ?
          ORDER BY CASE WHEN r.owner_user_id = m.user_id THEN 0 WHEN ra.user_id IS NOT NULL THEN 1 ELSE 2 END,
                   active_vip_level DESC,
                   CASE WHEN m.seat_index IS NULL THEN 1 ELSE 0 END, m.seat_index ASC, m.joined_at ASC
          LIMIT 200`
      ).bind(now(), now(), now(), now(), now(), roomId).all();
      return json({ ok: true, members: rows.results ?? [] });
    }
    if (request.method === "POST") {
      const body = await bodyJson(request);
      const actorId = String(body.user_id ?? "").trim();
      const targetId = String(body.target_user_id ?? "").trim();
      const action = String(body.action ?? "").trim();
      const authError = await requireSession(request, env, actorId);
      if (authError) return authError;
      if (!targetId || targetId === actorId) return json({ ok: false, error: "invalid_target" }, { status: 400 });
      const room = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
      if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
      const isOwner = room.owner_user_id === actorId;
      const actorAdmin = await db.prepare("SELECT 1 AS active FROM room_admins WHERE room_id = ? AND user_id = ?")
        .bind(roomId, actorId).first();
      const actorMember = await db.prepare("SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?")
        .bind(roomId, actorId).first();
      if (!isOwner && actorAdmin && !actorMember) {
        return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      }
      const targetMember = await db.prepare("SELECT seat_index FROM room_members WHERE room_id = ? AND user_id = ?")
        .bind(roomId, targetId).first();
      if (!targetMember) return json({ ok: false, error: "target_not_in_room" }, { status: 404 });

      if (action === "set_admin" || action === "remove_admin") {
        if (!isOwner) return json({ ok: false, error: "room_owner_required" }, { status: 403 });
        if (room.owner_user_id === targetId) return json({ ok: false, error: "owner_role_fixed" }, { status: 400 });
        if (action === "set_admin") {
          await db.prepare("INSERT INTO room_admins (room_id, user_id, added_by, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(room_id, user_id) DO NOTHING")
            .bind(roomId, targetId, actorId, now()).run();
          return json({ ok: true, is_admin: true });
        }
        const result = await db.prepare("DELETE FROM room_admins WHERE room_id = ? AND user_id = ?")
          .bind(roomId, targetId).run();
        return json({ ok: true, is_admin: false, changed: Number(result.meta?.changes ?? 0) > 0 });
      }

      const isTargetOwner = room.owner_user_id === targetId;
      const targetAdmin = await db.prepare("SELECT 1 AS active FROM room_admins WHERE room_id = ? AND user_id = ?")
        .bind(roomId, targetId).first();
      if (!isOwner && !actorAdmin) return json({ ok: false, error: "room_moderator_required" }, { status: 403 });
      if (isTargetOwner || (!isOwner && targetAdmin)) {
        return json({ ok: false, error: "moderation_target_protected" }, { status: 403 });
      }

      const targetVip = await getVipStatus(db, targetId);
      if (!isOwner && targetMember.seat_index != null && targetVip.seat_protection_enabled) {
        return json({ ok: false, error: "vip_seat_protected" }, { status: 403 });
      }
      if (!isOwner && targetVip.kick_protection_enabled) {
        return json({ ok: false, error: "vip_kick_protected" }, { status: 403 });
      }

      await ensureRoomSafetyTables(db);
      const shouldBan = body.ban === true;
      if (env.LIVEKIT_URL && env.LIVEKIT_API_KEY && env.LIVEKIT_API_SECRET) {
        const seconds = Math.floor(Date.now() / 1000);
        const adminToken = await signJwt(
          String(env.LIVEKIT_API_SECRET),
          { alg: "HS256", typ: "JWT" },
          {
            iss: String(env.LIVEKIT_API_KEY),
            sub: actorId,
            nbf: seconds - 5,
            exp: seconds + 60,
            video: { room: roomId, roomAdmin: true },
          },
        );
        const livekitBase = String(env.LIVEKIT_URL).replace(/^ws(s?):\/\//i, "http$1://").replace(/\/$/, "");
        let livekitResponse;
        try {
          livekitResponse = await fetch(
            `${livekitBase}/twirp/livekit.RoomService/RemoveParticipant`,
            {
              method: "POST",
              headers: {
                authorization: `Bearer ${adminToken}`,
                "content-type": "application/json",
              },
              body: JSON.stringify({
                room: roomId,
                identity: targetId,
                revoke_token_ts: seconds,
              }),
            },
          );
        } catch (_) {
          return json({ ok: false, error: "livekit_unavailable" }, { status: 503 });
        }
        if (!livekitResponse.ok) {
          const detail = await livekitResponse.text();
          if (!/participant does not exist/i.test(detail)) {
            return json({ ok: false, error: "livekit_remove_failed" }, { status: 502 });
          }
        }
      }
      if (shouldBan) {
        await db.prepare(
          "INSERT INTO room_bans (room_id, user_id, banned_by, created_at) VALUES (?, ?, ?, ?) ON CONFLICT(room_id, user_id) DO UPDATE SET banned_by = excluded.banned_by, created_at = excluded.created_at"
        ).bind(roomId, targetId, actorId, now()).run();
      }
      if (isOwner) {
        await db.prepare("DELETE FROM room_admins WHERE room_id = ? AND user_id = ?").bind(roomId, targetId).run();
      }
      const result = await db.prepare("DELETE FROM room_members WHERE room_id = ? AND user_id = ?")
        .bind(roomId, targetId).run();
      return json({ ok: Number(result.meta?.changes ?? 0) > 0 });
    }
    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "report" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const reason = String(body.reason ?? "").trim().slice(0, 80);
    const details = String(body.details ?? "").trim().slice(0, 500);
    const allowedReasons = new Set(["Harassment", "Inappropriate content", "Spam or scam", "Safety concern", "Other"]);
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!allowedReasons.has(reason)) return json({ ok: false, error: "invalid_report_reason" }, { status: 400 });
    const membership = await db.prepare(
      "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
    ).bind(roomId, userId).first();
    if (!membership) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    await ensureRoomSafetyTables(db);
    const reportId = id();
    await db.prepare(
      "INSERT INTO room_reports (id, room_id, reporter_user_id, reason, details, created_at) VALUES (?, ?, ?, ?, ?, ?)"
    ).bind(reportId, roomId, userId, reason, details, now()).run();
    return json({ ok: true, report_id: reportId }, { status: 201 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "follow") {
    const roomId = parts[2];
    if (request.method === "GET") {
      const userId = String(url.searchParams.get("user_id") ?? "").trim();
      if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
      return json({ ok: true, following: await roomFollowState(db, roomId, userId) });
    }
    if (request.method === "POST") {
      const body = await bodyJson(request);
      const userId = String(body.user_id ?? "").trim();
      if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
      await ensureUser(db, userId);
      await ensureUserAllowed(db, userId);
      const following = await recordLampRoomFollow(db, roomId, userId, body.follow !== false, now());
      return json({ ok: true, following });
    }
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length >= 4 && parts[3] === "lamp") {
    const lampFeature = await ownerSetting(db, "feature.aladdin_lamp", { enabled: true });
    if (lampFeature.enabled === false) return json({ ok: false, error: "aladdin_lamp_disabled" }, { status: 403 });
    const roomId = parts[2];

    if (parts.length === 4 && request.method === "GET") {
      const userId = String(url.searchParams.get("user_id") ?? "").trim();
      if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
      const status = await getLampStatus(db, roomId, userId, now());
      return json({ ok: true, ...status });
    }

    if (parts.length === 5 && parts[4] === "claim" && request.method === "POST") {
      const body = await bodyJson(request);
      const userId = String(body.user_id ?? "").trim();
      const taskId = String(body.task_id ?? "").trim();
      if (!userId || !taskId) return json({ ok: false, error: "user_and_task_required" }, { status: 400 });
      await ensureUserAllowed(db, userId);
      const reward = await claimLampTask(db, roomId, userId, taskId, now());
      return json({ ok: true, ...reward });
    }

    if (parts.length === 5 && parts[4] === "share" && request.method === "POST") {
      const body = await bodyJson(request);
      const userId = String(body.user_id ?? "").trim();
      const platform = String(body.platform ?? "").trim().toLowerCase();
      await recordLampRoomShare(db, roomId, userId, platform, now());
      return json({ ok: true });
    }

    if (parts.length === 5 && parts[4] === "invite" && request.method === "POST") {
      const body = await bodyJson(request);
      const hostId = String(body.host_user_id ?? "").trim();
      const inviteeId = String(body.invitee_user_id ?? "").trim();
      await createLampMicInvite(db, roomId, hostId, inviteeId, now());
      return json({ ok: true });
    }
  }

  if (url.pathname === "/api/messages/red-envelope" && request.method === "POST") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const amount = Number(body.amount);
    const authError = await requireSession(request, env, sender);
    if (authError) return authError;
    if (!sender || !receiver || sender === receiver || !Number.isSafeInteger(amount) || amount < 1) {
      return json({ ok: false, error: "invalid_red_envelope" }, { status: 400 });
    }
    await ensureUserAllowed(db, sender, { checkMute: true });
    await ensureUserAllowed(db, receiver);
    const receiverExists = await db.prepare("SELECT 1 AS exists_user FROM users WHERE id=?").bind(receiver).first();
    if (!receiverExists) return json({ ok: false, error: "receiver_not_found" }, { status: 404 });
    await ensureVipSchema(db);
    const vip = await getVipStatus(db, sender);
    if (!vip.red_envelope_enabled) return json({ ok: false, error: "vip6_required_for_red_envelope" }, { status: 403 });
    await ensureInboxEnvelopeTables(db);
    await expireInboxEnvelopes(db);
    const envelopeId = id();
    const messageId = id();
    const ts = now();
    await db.batch([
      db.prepare(`INSERT INTO inbox_red_envelopes (id,sender_user_id,receiver_user_id,amount,status,created_at,expires_at)
        SELECT ?,u.id,?,?,'open',?,? FROM users u JOIN user_vip v ON v.user_id=u.id
         WHERE u.id=? AND u.coins>=? AND v.level>=6 AND v.active_until>?`)
        .bind(envelopeId, receiver, amount, ts, ts + 86400000, sender, amount, ts),
      db.prepare("UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=? AND EXISTS(SELECT 1 FROM inbox_red_envelopes WHERE id=? AND status='open')")
        .bind(amount, ts, sender, amount, envelopeId),
      db.prepare("INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) SELECT ?,id,'red_envelope_sent',-?,coins,?,? FROM users WHERE id=? AND EXISTS(SELECT 1 FROM inbox_red_envelopes WHERE id=?)")
        .bind(id(), amount, envelopeId, ts, sender, envelopeId),
      db.prepare("INSERT INTO direct_messages (id,sender_user_id,receiver_user_id,text,created_at,read_at) SELECT ?,?,?, '🎁 Red envelope',?,NULL WHERE EXISTS(SELECT 1 FROM inbox_red_envelopes WHERE id=?)")
        .bind(messageId, sender, receiver, ts, envelopeId),
    ]);
    const created = await db.prepare("SELECT id FROM inbox_red_envelopes WHERE id=?").bind(envelopeId).first();
    if (!created) return json({ ok: false, error: "insufficient_coins_or_vip_expired" }, { status: 409 });
    return json({ ok: true, envelope_id: envelopeId, expires_at: ts + 86400000 }, { status: 201 });
  }

  if (url.pathname === "/api/messages/red-envelopes" && request.method === "GET") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const otherId = String(url.searchParams.get("other_user_id") ?? "").trim();
    if (!userId || !otherId) return json({ ok: false, error: "user_ids_required" }, { status: 400 });
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureInboxEnvelopeTables(db);
    await expireInboxEnvelopes(db);
    const rows = await db.prepare(`SELECT e.id,e.sender_user_id,e.receiver_user_id,
      CASE WHEN e.sender_user_id=? OR EXISTS(SELECT 1 FROM inbox_red_envelope_claims own WHERE own.envelope_id=e.id AND own.user_id=?) THEN e.amount ELSE NULL END AS amount,
      e.status,e.created_at,e.expires_at,e.claimed_at,
      s.display_name AS sender_name,r.display_name AS receiver_name,
      EXISTS(SELECT 1 FROM inbox_red_envelope_claims c WHERE c.envelope_id=e.id AND c.user_id=?) AS claimed_by_me
      FROM inbox_red_envelopes e LEFT JOIN users s ON s.id=e.sender_user_id LEFT JOIN users r ON r.id=e.receiver_user_id
      WHERE (e.sender_user_id=? AND e.receiver_user_id=?) OR (e.sender_user_id=? AND e.receiver_user_id=?) ORDER BY e.created_at ASC LIMIT 200`)
      .bind(userId, userId, userId, userId, otherId, otherId, userId).all();
    return json({ ok: true, envelopes: rows.results ?? [] });
  }

  if (parts[0] === "api" && parts[1] === "messages" && parts[2] === "red-envelope" && parts.length === 5 && parts[4] === "claim" && request.method === "POST") {
    const envelopeId = parts[3];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUserAllowed(db, userId);
    await ensureInboxEnvelopeTables(db);
    await expireInboxEnvelopes(db);
    const existing = await db.prepare("SELECT amount FROM inbox_red_envelope_claims WHERE envelope_id=? AND user_id=?").bind(envelopeId, userId).first();
    if (existing) return json({ ok: true, amount: Number(existing.amount), duplicate: true });
    const claimToken = id();
    const ts = now();
    await db.batch([
      db.prepare(`INSERT OR IGNORE INTO inbox_red_envelope_claims (envelope_id,claim_token,user_id,amount,claimed_at)
        SELECT id,?,?,amount,? FROM inbox_red_envelopes WHERE id=? AND receiver_user_id=? AND status='open' AND expires_at>?`)
        .bind(claimToken, userId, ts, envelopeId, userId, ts),
      db.prepare("UPDATE inbox_red_envelopes SET status='claimed',claimed_at=? WHERE id=? AND status='open' AND expires_at>? AND EXISTS(SELECT 1 FROM inbox_red_envelope_claims WHERE envelope_id=? AND claim_token=? AND user_id=?)")
        .bind(ts, envelopeId, ts, envelopeId, claimToken, userId),
      db.prepare("UPDATE users SET coins=coins+(SELECT amount FROM inbox_red_envelope_claims WHERE envelope_id=? AND claim_token=?),updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM inbox_red_envelope_claims WHERE envelope_id=? AND claim_token=? AND user_id=?)")
        .bind(envelopeId, claimToken, ts, userId, envelopeId, claimToken, userId),
      db.prepare("INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) SELECT ?,id,'red_envelope_claim',c.amount,coins,?,? FROM users JOIN inbox_red_envelope_claims c ON c.user_id=users.id WHERE users.id=? AND c.envelope_id=? AND c.claim_token=?")
        .bind(id(), envelopeId, ts, userId, envelopeId, claimToken),
    ]);
    const claim = await db.prepare("SELECT amount FROM inbox_red_envelope_claims WHERE envelope_id=? AND claim_token=?").bind(envelopeId, claimToken).first();
    if (!claim) return json({ ok: false, error: "envelope_expired_claimed_or_not_for_you" }, { status: 409 });
    return json({ ok: true, amount: Number(claim.amount) });
  }

  if (url.pathname === "/api/messages/send" && request.method === "POST") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const authError = await requireSession(request, env, sender);
    if (authError) return authError;
    const textValue = String(body.text ?? "").trim().slice(0, 1000);
    const imageKey = String(body.image_key ?? "").trim();
    if (!sender || !receiver || (!textValue && !imageKey)) {
      return json({ ok: false, error: "invalid_message" }, { status: 400 });
    }
    if (imageKey && (!imageKey.startsWith(`messages/${sender}/`) || !/\.(jpg|jpeg|png|webp)$/i.test(imageKey))) {
      return json({ ok: false, error: "invalid_image_key" }, { status: 400 });
    }
    await ensureUser(db, sender);
    await ensureUser(db, receiver);
    await ensureUserAllowed(db, sender, { checkMute: true });
    await ensureUserAllowed(db, receiver);
    const messageId = id();
    await ensureImageTables(db);
    const createdAt = now();
    const statements = [
      db.prepare(
        "INSERT INTO direct_messages (id, sender_user_id, receiver_user_id, text, created_at, read_at) VALUES (?, ?, ?, ?, ?, NULL)"
      ).bind(messageId, sender, receiver, textValue, createdAt),
    ];
    if (imageKey) {
      statements.push(db.prepare(
        "INSERT INTO direct_message_images (message_id, image_key, created_at) VALUES (?, ?, ?)"
      ).bind(messageId, imageKey, createdAt));
    }
    await db.batch(statements);
    return json({ ok: true, message_id: messageId, image_key: imageKey || null }, { status: 201 });
  }

  if (url.pathname === "/api/messages/thread" && request.method === "GET") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const otherId = String(url.searchParams.get("other_user_id") ?? "").trim();
    if (!userId || !otherId) {
      return json({ ok: false, error: "user_ids_required" }, { status: 400 });
    }
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureImageTables(db);
    const vip = await getVipStatus(db, userId, now());
    const retentionDays = vip.active ? Number(vip.message_retention_days ?? 0) : 0;
    const cutoff = retentionDays > 0 ? now() - retentionDays * 86400000 : 0;
    const rows = await db.prepare(
      `SELECT m.id, m.sender_user_id, m.receiver_user_id, m.text, m.created_at, m.read_at,
              i.image_key
         FROM direct_messages m
         LEFT JOIN direct_message_images i ON i.message_id = m.id
        WHERE ((m.sender_user_id = ? AND m.receiver_user_id = ?)
           OR (m.sender_user_id = ? AND m.receiver_user_id = ?))
          AND (? = 0 OR m.created_at >= ?)
        ORDER BY m.created_at DESC
        LIMIT ?`
    ).bind(userId, otherId, otherId, userId, cutoff, cutoff, retentionDays > 0 ? 2000 : 20).all();
    rows.results = (rows.results ?? []).reverse();
    await db.prepare(
      "UPDATE direct_messages SET read_at = ? WHERE receiver_user_id = ? AND sender_user_id = ? AND read_at IS NULL"
    ).bind(now(), userId, otherId).run();
    return json({ ok: true, messages: rows.results ?? [] });
  }

  if (url.pathname === "/api/messages/inbox" && request.method === "GET") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    if (!userId) {
      return json({ ok: false, error: "user_id_required" }, { status: 400 });
    }
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureImageTables(db);
    const rows = await db.prepare(
      `SELECT m.id, m.sender_user_id, m.receiver_user_id, m.text, m.created_at, m.read_at,
              i.image_key,
              (SELECT COUNT(*) FROM direct_messages unread
                WHERE unread.sender_user_id = CASE WHEN m.sender_user_id = ? THEN m.receiver_user_id ELSE m.sender_user_id END
                  AND unread.receiver_user_id = ? AND unread.read_at IS NULL) AS unread_count,
              s.display_name AS sender_name, s.avatar_key AS sender_avatar_key,
              r.display_name AS receiver_name, r.avatar_key AS receiver_avatar_key
         FROM direct_messages m
         LEFT JOIN users s ON s.id = m.sender_user_id
         LEFT JOIN users r ON r.id = m.receiver_user_id
         LEFT JOIN direct_message_images i ON i.message_id = m.id
        WHERE m.sender_user_id = ? OR m.receiver_user_id = ?
        ORDER BY m.created_at DESC
        LIMIT 200`
    ).bind(userId, userId, userId, userId).all();

    const seen = new Set();
    const inbox = [];
    for (const row of rows.results ?? []) {
      const otherId = row.sender_user_id === userId ? row.receiver_user_id : row.sender_user_id;
      if (seen.has(otherId)) continue;
      seen.add(otherId);
      inbox.push({
        id: otherId,
        name: row.sender_user_id === userId ? row.receiver_name : row.sender_name,
        preview: row.text || (row.image_key ? "📷 Photo" : ""),
        avatar_key: row.sender_user_id === userId ? row.receiver_avatar_key : row.sender_avatar_key,
        image_key: row.image_key,
        created_at: row.created_at,
        unread: Number(row.unread_count ?? 0),
      });
    }
    return json({ ok: true, inbox });
  }

  if (parts[0] === "api" && parts[1] === "wallet" && parts.length === 3 && request.method === "GET") {
    const authError = await requireSession(request, env, parts[2]);
    if (authError) return authError;
    const user = await ensureUser(db, parts[2]);
    const ledger = await db.prepare(
      "SELECT id, kind, amount, balance_after, reference_id, created_at FROM wallet_ledger WHERE user_id = ? ORDER BY created_at DESC LIMIT 100"
    ).bind(parts[2]).all();
    return json({ ok: true, wallet: user, ledger: ledger.results ?? [] });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length === 3 && request.method === "GET") {
    const userId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    return json({ ok: true, vip: await getVipStatus(db, userId) });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length >= 4 && parts[3] === "support-tickets") {
    const userId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    const vip = await getVipStatus(db, userId);
    if (!vip.customer_service_enabled) return json({ ok: false, error: "vip9_required_for_support" }, { status: 403 });
    await ensureSupportSchema(db);
    if (parts.length === 4 && request.method === "GET") {
      const rows = await db.prepare("SELECT id,subject,status,created_at,updated_at FROM vip_support_tickets WHERE user_id=? ORDER BY updated_at DESC LIMIT 100").bind(userId).all();
      return json({ ok: true, tickets: rows.results ?? [] });
    }
    if (parts.length === 4 && request.method === "POST") {
      const body = await bodyJson(request);
      const subject = String(body.subject ?? "").trim().slice(0, 100);
      const message = String(body.message ?? "").trim();
      if (!subject || !message || message.length > 2000) return json({ ok: false, error: "subject_and_message_required" }, { status: 400 });
      const ticketId = id();
      const ts = now();
      await db.batch([
        db.prepare("INSERT INTO vip_support_tickets (id,user_id,subject,status,created_at,updated_at) VALUES (?,?,?,'open',?,?)").bind(ticketId, userId, subject, ts, ts),
        db.prepare("INSERT INTO vip_support_messages (id,ticket_id,sender_type,sender_id,body,created_at) VALUES (?,?, 'user',?,?,?)").bind(id(), ticketId, userId, message, ts),
      ]);
      return json({ ok: true, ticket_id: ticketId });
    }
    if (parts.length === 5 && request.method === "GET") {
      const ticketId = decodeURIComponent(parts[4]);
      const ticket = await db.prepare("SELECT id,subject,status,created_at,updated_at FROM vip_support_tickets WHERE id=? AND user_id=?").bind(ticketId, userId).first();
      if (!ticket) return json({ ok: false, error: "not_found" }, { status: 404 });
      const rows = await db.prepare("SELECT id,sender_type,body,created_at FROM vip_support_messages WHERE ticket_id=? ORDER BY created_at ASC LIMIT 500").bind(ticketId).all();
      return json({ ok: true, ticket, messages: rows.results ?? [] });
    }
    if (parts.length === 6 && parts[5] === "reply" && request.method === "POST") {
      const ticketId = decodeURIComponent(parts[4]);
      const ticket = await db.prepare("SELECT id,status FROM vip_support_tickets WHERE id=? AND user_id=?").bind(ticketId, userId).first();
      if (!ticket) return json({ ok: false, error: "not_found" }, { status: 404 });
      if (ticket.status !== "open") return json({ ok: false, error: "ticket_closed" }, { status: 409 });
      const body = await bodyJson(request);
      const message = String(body.message ?? "").trim();
      if (!message || message.length > 2000) return json({ ok: false, error: "message_length_invalid" }, { status: 400 });
      const ts = now();
      await db.batch([
        db.prepare("INSERT INTO vip_support_messages (id,ticket_id,sender_type,sender_id,body,created_at) VALUES (?,?, 'user',?,?,?)").bind(id(), ticketId, userId, message, ts),
        db.prepare("UPDATE vip_support_tickets SET updated_at=? WHERE id=?").bind(ts, ticketId),
      ]);
      return json({ ok: true });
    }
    return json({ ok: false, error: "not_found" }, { status: 404 });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length === 4 && parts[3] === "preferences" && request.method === "POST") {
    const userId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const body = await bodyJson(request);
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    const vip = await setVipPreference(db, userId, body.key, body.enabled === true);
    return json({ ok: true, vip });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length === 4 && parts[3] === "unique-id" && request.method === "POST") {
    const userId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const body = await bodyJson(request);
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    const customId = await changeVipUniqueId(db, userId, body.custom_id);
    return json({ ok: true, custom_id: customId, vip: await getVipStatus(db, userId) });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length === 4 && parts[3] === "say-hi" && request.method === "POST") {
    const userId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const body = await bodyJson(request);
    const receiverId = String(body.receiver_user_id ?? "").trim();
    if (!receiverId || receiverId === userId) return json({ ok: false, error: "invalid_receiver" }, { status: 400 });
    await ensureUser(db, userId);
    await ensureUser(db, receiverId);
    await ensureUserAllowed(db, userId, { checkMute: true });
    await ensureUserAllowed(db, receiverId);
    const usage = await consumeFreeSayHi(db, userId, receiverId, body.message);
    return json({ ok: true, usage });
  }

  if (url.pathname === "/api/wallet/coin-seller-transfer" && request.method === "POST") {
    const body = await bodyJson(request);
    const sellerId = String(body.seller_user_id ?? "").trim();
    const receiverId = String(body.receiver_user_id ?? "").trim();
    const authError = await requireSession(request, env, sellerId);
    if (authError) return authError;
    const amount = Number(body.coins ?? 0);
    if (!sellerId || !receiverId || sellerId === receiverId || !Number.isSafeInteger(amount) || amount <= 0) {
      return json({ ok: false, error: "invalid_coin_seller_transfer" }, { status: 400 });
    }
    await ensureUser(db, sellerId);
    await ensureUser(db, receiverId);
    await ensureUserAllowed(db, sellerId);
    await ensureUserAllowed(db, receiverId);
    const seller = await db.prepare("SELECT role, coins FROM users WHERE id = ?").bind(sellerId).first();
    const receiver = await db.prepare("SELECT coins FROM users WHERE id = ?").bind(receiverId).first();
    if (seller?.role !== "coin_seller") {
      return json({ ok: false, error: "coin_seller_required" }, { status: 403 });
    }
    const sellerBefore = Number(seller.coins ?? 0);
    const receiverBefore = Number(receiver?.coins ?? 0);
    if (sellerBefore < amount) {
      return json({ ok: false, error: "insufficient_coins" }, { status: 400 });
    }
    const transferId = id();
    const ts = now();
    const sellerAfter = sellerBefore - amount;
    const receiverAfter = receiverBefore + amount;
    await db.batch([
      db.prepare("UPDATE users SET coins = ?, updated_at = ? WHERE id = ?").bind(sellerAfter, ts, sellerId),
      db.prepare("UPDATE users SET coins = ?, updated_at = ? WHERE id = ?").bind(receiverAfter, ts, receiverId),
      db.prepare("INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES (?,?,?,?,?,?,?)").bind(id(), sellerId, "coin_seller_transfer_sent", -amount, sellerAfter, transferId, ts),
      db.prepare("INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES (?,?,?,?,?,?,?)").bind(id(), receiverId, "coin_seller_received", amount, receiverAfter, transferId, ts),
    ]);
    const vipAward = await awardSellerVipExp(db, receiverId, amount, ts);
    return json({
      ok: true,
      transfer_id: transferId,
      seller_coin_balance: sellerAfter,
      receiver_coin_balance: receiverAfter,
      vip_award: vipAward,
    });
  }

  const gameRoomMatch = url.pathname.match(/^\/api\/game-rooms\/([^/]+)(?:\/(join|tap))?$/);
  if (url.pathname === "/api/game-rooms" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await db.prepare("CREATE TABLE IF NOT EXISTS game_rooms (id TEXT PRIMARY KEY, owner_user_id TEXT NOT NULL, name TEXT NOT NULL, shared_score INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)").run();
    await db.prepare("CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))").run();
    const rows = await db.prepare("SELECT r.id,r.name,r.owner_user_id,u.display_name AS owner_name,r.shared_score,r.created_at,COUNT(m.user_id) AS member_count FROM game_rooms r JOIN users u ON u.id=r.owner_user_id LEFT JOIN game_room_members m ON m.room_id=r.id GROUP BY r.id ORDER BY r.updated_at DESC LIMIT 100").all();
    return json({ ok: true, rooms: rows.results ?? [] });
  }

  if (url.pathname === "/api/game-rooms" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const gamesFeature = await ownerSetting(db, "feature.games", { enabled: true });
    if (gamesFeature.enabled === false) return json({ ok: false, error: "games_disabled" }, { status: 403 });
    await ensureUser(db, userId);
    await db.prepare("CREATE TABLE IF NOT EXISTS game_rooms (id TEXT PRIMARY KEY, owner_user_id TEXT NOT NULL, name TEXT NOT NULL, shared_score INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)").run();
    await db.prepare("CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))").run();
    const roomId = id();
    const ts = now();
    const name = String(body.name ?? "Party Game Room").trim().slice(0, 48) || "Party Game Room";
    await db.batch([
      db.prepare("INSERT INTO game_rooms (id,owner_user_id,name,shared_score,created_at,updated_at) VALUES (?,?,?,0,?,?)").bind(roomId,userId,name,ts,ts),
      db.prepare("INSERT INTO game_room_members (room_id,user_id,seat_index,joined_at) VALUES (?,?,0,?)").bind(roomId,userId,ts),
    ]);
    return json({ ok: true, room_id: roomId }, { status: 201 });
  }

  if (gameRoomMatch && request.method === "GET") {
    const roomId = decodeURIComponent(gameRoomMatch[1]);
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await db.prepare("CREATE TABLE IF NOT EXISTS game_rooms (id TEXT PRIMARY KEY, owner_user_id TEXT NOT NULL, name TEXT NOT NULL, shared_score INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)").run();
    await db.prepare("CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))").run();
    const room = await db.prepare("SELECT r.id,r.name,r.owner_user_id,u.display_name AS owner_name,r.shared_score,r.created_at FROM game_rooms r JOIN users u ON u.id=r.owner_user_id WHERE r.id=?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "game_room_not_found" }, { status: 404 });
    const members = await db.prepare("SELECT m.user_id,m.seat_index,u.display_name,u.avatar_key,u.vip_level FROM game_room_members m JOIN users u ON u.id=m.user_id WHERE m.room_id=? ORDER BY m.seat_index").bind(roomId).all();
    return json({ ok: true, room, members: members.results ?? [] });
  }

  if (gameRoomMatch && gameRoomMatch[2] === "join" && request.method === "POST") {
    const roomId = decodeURIComponent(gameRoomMatch[1]);
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUser(db,userId);
    await db.prepare("CREATE TABLE IF NOT EXISTS game_rooms (id TEXT PRIMARY KEY, owner_user_id TEXT NOT NULL, name TEXT NOT NULL, shared_score INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)").run();
    await db.prepare("CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))").run();
    const exists = await db.prepare("SELECT 1 AS yes FROM game_room_members WHERE room_id=? AND user_id=?").bind(roomId,userId).first();
    if (exists) return json({ ok: true, already_joined: true });
    const count = await db.prepare("SELECT COUNT(*) AS total FROM game_room_members WHERE room_id=?").bind(roomId).first();
    if (Number(count?.total ?? 0) >= 15) return json({ ok: false, error: "game_room_full" }, { status: 409 });
    const seat = Number(count?.total ?? 0);
    const result = await db.prepare("INSERT INTO game_room_members (room_id,user_id,seat_index,joined_at) SELECT ?,?,?,? WHERE EXISTS(SELECT 1 FROM game_rooms WHERE id=?)").bind(roomId,userId,seat,now(),roomId).run();
    const joined = await db.prepare("SELECT 1 AS yes FROM game_room_members WHERE room_id=? AND user_id=?").bind(roomId,userId).first();
    if (!joined) return json({ ok: false, error: "game_room_not_found" }, { status: 404 });
    await db.prepare("UPDATE game_rooms SET updated_at=? WHERE id=?").bind(now(),roomId).run();
    return json({ ok: true, seat_index: seat });
  }

  if (gameRoomMatch && gameRoomMatch[2] === "tap" && request.method === "POST") {
    const roomId = decodeURIComponent(gameRoomMatch[1]);
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const updated = await db.prepare("UPDATE game_rooms SET shared_score=shared_score+1,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM game_room_members WHERE room_id=? AND user_id=?)").bind(now(),roomId,roomId,userId).run();
    if (!updated.meta?.changes) return json({ ok: false, error: "join_room_first" }, { status: 403 });
    const room = await db.prepare("SELECT shared_score FROM game_rooms WHERE id=?").bind(roomId).first();
    return json({ ok: true, shared_score: Number(room?.shared_score ?? 0) });
  }

  if (url.pathname === "/api/friends" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await db.prepare("CREATE TABLE IF NOT EXISTS user_friends (user_id TEXT NOT NULL, friend_user_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(user_id,friend_user_id), CHECK(user_id<>friend_user_id))").run();
    const vip = await getVipStatus(db, userId, now());
    const friends = await db.prepare("SELECT f.friend_user_id AS id, u.display_name, u.avatar_key, u.vip_level FROM user_friends f JOIN users u ON u.id=f.friend_user_id WHERE f.user_id=? ORDER BY f.created_at DESC").bind(userId).all();
    return json({ ok: true, friends: friends.results ?? [], friend_limit: vip.active ? null : 300 });
  }

  if (url.pathname === "/api/friends/add" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const friendId = String(body.friend_user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!friendId || friendId === userId) return json({ ok: false, error: "invalid_friend" }, { status: 400 });
    await ensureUser(db, userId);
    await ensureUser(db, friendId);
    await db.prepare("CREATE TABLE IF NOT EXISTS user_friends (user_id TEXT NOT NULL, friend_user_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(user_id,friend_user_id), CHECK(user_id<>friend_user_id))").run();
    const vip = await getVipStatus(db, userId, now());
    const friendVip = await getVipStatus(db, friendId, now());
    const count = await db.prepare("SELECT COUNT(*) AS total FROM user_friends WHERE user_id=?").bind(userId).first();
    const friendCount = await db.prepare("SELECT COUNT(*) AS total FROM user_friends WHERE user_id=?").bind(friendId).first();
    const exists = await db.prepare("SELECT 1 AS yes FROM user_friends WHERE user_id=? AND friend_user_id=?").bind(userId, friendId).first();
    if (!exists && ((!vip.active && Number(count?.total ?? 0) >= 300) || (!friendVip.active && Number(friendCount?.total ?? 0) >= 300))) {
      return json({ ok: false, error: "friend_limit_reached", friend_limit: 300 }, { status: 409 });
    }
    const ts = now();
    await db.batch([
      db.prepare("INSERT OR IGNORE INTO user_friends (user_id,friend_user_id,created_at) VALUES (?,?,?)").bind(userId, friendId, ts),
      db.prepare("INSERT OR IGNORE INTO user_friends (user_id,friend_user_id,created_at) VALUES (?,?,?)").bind(friendId, userId, ts),
    ]);
    return json({ ok: true, friend_limit: vip.active ? null : 300 });
  }

  if (url.pathname === "/api/friends/remove" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const friendId = String(body.friend_user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await db.prepare("CREATE TABLE IF NOT EXISTS user_friends (user_id TEXT NOT NULL, friend_user_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(user_id,friend_user_id), CHECK(user_id<>friend_user_id))").run();
    await db.batch([
      db.prepare("DELETE FROM user_friends WHERE user_id=? AND friend_user_id=?").bind(userId, friendId),
      db.prepare("DELETE FROM user_friends WHERE user_id=? AND friend_user_id=?").bind(friendId, userId),
    ]);
    return json({ ok: true });
  }

  if (url.pathname === "/api/id-level" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUser(db, userId);
    return json({ ok: true, level: await getIdLevelStatus(db, userId) });
  }

  if (url.pathname === "/api/id-level/room-share" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const roomId = String(body.room_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!userId || !roomId) return json({ ok: false, error: "user_and_room_required" }, { status: 400 });
    const member = await db.prepare("SELECT 1 AS joined FROM room_members WHERE room_id=? AND user_id=?")
      .bind(roomId, userId).first();
    if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    const awarded = await awardIdLevelDaily(db, userId, "room_share", now());
    return json({ ok: true, id_level_daily_exp: awarded, level: await getIdLevelStatus(db, userId) });
  }

  if (url.pathname === "/api/id-level/rewards/claim" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const level = Number(body.level);
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    await ensureUser(db, userId);
    const result = await claimIdLevelReward(db, userId, level, now());
    return json(result, { status: result.ok ? 200 : 409 });
  }

  if (url.pathname === "/api/gifts/catalog" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const vip = await getVipStatus(db, userId, now());
    const gifts = [
      { id: "basic-star", name: "Star", emoji: "⭐", coin_cost: 5000, vip_level: 0 },
      { id: "vip-rose", name: "VIP Rose", emoji: "🌹", coin_cost: 10000, vip_level: 3 },
      { id: "vip-crown", name: "Royal Crown", emoji: "👑", coin_cost: 50000, vip_level: 3 },
      { id: "vip-phoenix", name: "Golden Phoenix", emoji: "🔥", coin_cost: 100000, vip_level: 3 },
    ];
    return json({ ok: true, gifts: gifts.filter(g => g.vip_level === 0 || (vip.active && vip.level >= g.vip_level)) });
  }

  if (url.pathname === "/api/gifts/send" && request.method === "POST") {
    const giftsFeature = await ownerSetting(db, "feature.gifts", { enabled: true });
    if (giftsFeature.enabled === false) return json({ ok: false, error: "gifts_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const authError = await requireSession(request, env, sender);
    if (authError) return authError;
    const giftId = String(body.gift_id ?? "gift").trim().slice(0, 80);
    const catalog = {
      "basic-star": { cost: 5000, vip_level: 0 },
      "vip-rose": { cost: 10000, vip_level: 3 },
      "vip-crown": { cost: 50000, vip_level: 3 },
      "vip-phoenix": { cost: 100000, vip_level: 3 },
    };
    const gift = catalog[giftId];
    if (!sender || !receiver || !gift) return json({ ok: false, error: "invalid_gift" }, { status: 400 });
    const vip = await getVipStatus(db, sender, now());
    if (gift.vip_level > 0 && (!vip.active || vip.level < gift.vip_level)) return json({ ok: false, error: "vip_required" }, { status: 403 });
    const cost = gift.cost;
    await ensureUser(db, sender);
    await ensureUser(db, receiver);
    await ensureUserAllowed(db, sender);
    await ensureUserAllowed(db, receiver);
    const eventId = id();
    const balance = await walletChange(db, sender, -cost, "gift_sent", eventId);
    await db.batch([
      db.prepare("UPDATE users SET diamonds = diamonds + ?, updated_at = ? WHERE id = ?").bind(cost, now(), receiver),
      db.prepare(
        "INSERT INTO gift_events (id, room_id, sender_user_id, receiver_user_id, gift_id, coin_cost, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
      ).bind(eventId, body.room_id ?? null, sender, receiver, giftId, cost, now()),
    ]);
    await awardIdLevelGift(db, sender, cost, eventId, now());
    await recordLampGiftActivity(db, String(body.room_id ?? ""), sender, receiver, now());
    return json({ ok: true, event_id: eventId, sender_coin_balance: balance });
  }

  if (url.pathname === "/api/games/fruit-party/bet" && request.method === "POST") {
    const gamesFeature = await ownerSetting(db, "feature.games", { enabled: true });
    if (gamesFeature.enabled === false) return json({ ok: false, error: "games_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const stake = Number(body.stake ?? 0);
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!userId || stake !== 5000) {
      return json({ ok: false, error: "invalid_bet" }, { status: 400 });
    }
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    const betId = id();
    const afterStake = await walletChange(db, userId, -stake, "game_bet", betId);
    const symbols = ["apple", "orange", "watermelon", "grape", "kiwi", "strawberry", "cherry", "lemon"];
    const result = symbols[Math.floor(Math.random() * symbols.length)];
    const won = Math.random() < 0.28;
    const payout = won ? stake * 5 : 0;
    let balance = afterStake;
    if (payout > 0) balance = await walletChange(db, userId, payout, "game_win", betId);
    await db.prepare(
      "INSERT INTO game_bets (id, game_id, user_id, stake, result, payout, created_at) VALUES (?, 'fruit-party', ?, ?, ?, ?, ?)"
    ).bind(betId, userId, stake, result, payout, now()).run();
    return json({ ok: true, bet_id: betId, result, payout, coin_balance: balance });
  }

  if (url.pathname === "/api/files" && request.method === "PUT") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    if (!env.FILES) return json({ ok: false, error: "files_not_bound" }, { status: 503 });
    let session;
    try {
      session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    } catch (_) {
      return json({ ok: false, error: "unauthorized" }, { status: 401 });
    }
    const actor = String(session?.sub ?? "");
    const key = String(request.headers.get("x-file-key") ?? "").trim();
    const type = String(request.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
    const extensions = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };
    const extension = key.split(".").pop()?.toLowerCase();
    if (!actor || !extensions[type] || extension !== extensions[type] ||
        key.includes("..") || key.startsWith("/") || !/^[a-zA-Z0-9._/-]+$/.test(key)) {
      return json({ ok: false, error: "invalid_image_upload" }, { status: 400 });
    }
    const userPrefix = `users/${actor}/`;
    const messagePrefix = `messages/${actor}/`;
    let authorizedKey = key.startsWith(userPrefix) || key.startsWith(messagePrefix);
    const roomMatch = key.match(/^rooms\/([a-zA-Z0-9_-]+)\/avatar-[0-9]+\.(jpg|png|webp)$/i);
    if (roomMatch) {
      const room = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomMatch[1]).first();
      authorizedKey = room?.owner_user_id === actor;
    }
    if (!authorizedKey) return json({ ok: false, error: "file_owner_required" }, { status: 403 });
    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (declaredLength > 5 * 1024 * 1024) {
      return json({ ok: false, error: "image_size_invalid" }, { status: 413 });
    }
    const reader = request.body?.getReader();
    if (!reader) return json({ ok: false, error: "image_body_required" }, { status: 400 });
    const chunks = [];
    let size = 0;
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      size += part.value.byteLength;
      if (size > 5 * 1024 * 1024) {
        await reader.cancel();
        return json({ ok: false, error: "image_size_invalid" }, { status: 413 });
      }
      chunks.push(part.value);
    }
    if (!size) return json({ ok: false, error: "image_size_invalid" }, { status: 413 });
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const isPng = bytes.length >= 8 && bytes[0] === 137 && bytes[1] === 80 &&
      bytes[2] === 78 && bytes[3] === 71 && bytes[4] === 13 && bytes[5] === 10 &&
      bytes[6] === 26 && bytes[7] === 10;
    const isJpeg = bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
    const isWebp = bytes.length >= 12 && String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
    if ((type === "image/jpeg" && !isJpeg) || (type === "image/png" && !isPng) ||
        (type === "image/webp" && !isWebp)) {
      return json({ ok: false, error: "image_content_type_mismatch" }, { status: 400 });
    }
    await env.FILES.put(key, bytes, {
      httpMetadata: { contentType: type, cacheControl: "public, max-age=3600" },
    });
    return json({ ok: true, key }, { status: 201 });
  }

  return json({ ok: false, error: "not_found" }, { status: 404 });
}

async function handleLiveKitToken(request, env) {
  if (request.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }
  if (!env.SESSION_SECRET || !env.LIVEKIT_URL || !env.LIVEKIT_API_KEY || !env.LIVEKIT_API_SECRET) {
    return json({ ok: false, error: "voice_not_configured" }, { status: 503 });
  }

  const session = await verifySessionToken(
    bearerToken(request),
    String(env.SESSION_SECRET),
  );
  const db = requireDb(env);
  const voiceFeature = await ownerSetting(db, "feature.voice", { enabled: true });
  if (voiceFeature.enabled === false) {
    return json({ ok: false, error: "voice_disabled" }, { status: 403 });
  }
  await ensureUserAllowed(db, String(session.sub));
  const body = await bodyJson(request);
  const roomId = String(body.room_id ?? "").trim().slice(0, 100);
  if (!roomId) {
    return json({ ok: false, error: "room_id_required" }, { status: 400 });
  }
  const membership = await db.prepare(
    "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ? LIMIT 1"
  ).bind(roomId, String(session.sub)).first();
  if (!membership) return json({ ok: false, error: "room_membership_required" }, { status: 403 });

  const seconds = Math.floor(Date.now() / 1000);
  const token = await signJwt(
    String(env.LIVEKIT_API_SECRET),
    { alg: "HS256", typ: "JWT" },
    {
      iss: String(env.LIVEKIT_API_KEY),
      sub: String(session.sub),
      name: String(session.name ?? session.sub),
      nbf: seconds - 5,
      exp: seconds + 60 * 60,
      video: {
        room: roomId,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
      },
    },
  );

  return json({
    ok: true,
    server_url: String(env.LIVEKIT_URL),
    token,
  });
}

export default {
  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(expireInboxEnvelopes(requireDb(env)));
  },
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "darkvibex-api",
        db_bound: Boolean(env.DB),
        files_bound: Boolean(env.FILES),
      });
    }

    try {
      if (url.pathname === "/api/files" && request.method === "GET") {
        if (!env.FILES) return json({ ok: false, error: "files_not_bound" }, { status: 503 });
        const key = String(url.searchParams.get("key") ?? "").trim();
        if (!key || key.includes("..") || key.startsWith("/") ||
            !/^(users|rooms|messages)\/[a-zA-Z0-9._/-]+$/.test(key)) {
          return json({ ok: false, error: "invalid_file_key" }, { status: 400 });
        }
        if (key.startsWith("messages/")) {
          const authError = await requireSession(request, env);
          if (authError) return authError;
          const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
          const db = requireDb(env);
          await ensureImageTables(db);
          const allowed = await db.prepare(
            `SELECT 1 AS allowed
               FROM direct_message_images i
               JOIN direct_messages m ON m.id = i.message_id
              WHERE i.image_key = ? AND (m.sender_user_id = ? OR m.receiver_user_id = ?)
              LIMIT 1`
          ).bind(key, String(session.sub), String(session.sub)).first();
          if (!allowed) return json({ ok: false, error: "file_not_found" }, { status: 404 });
        }
        const protectedAvatar = key.match(/^users\/([^/]+)\/avatar-/);
        let privacyProtectedAvatar = false;
        if (protectedAvatar) {
          const db = requireDb(env);
          const targetId = protectedAvatar[1];
          const targetVip = await getVipStatus(db, targetId);
          if (targetVip.active && targetVip.level >= 15 && targetVip.preferences.privacy_protection === true) {
            privacyProtectedAvatar = true;
            const authError = await requireSession(request, env);
            if (authError) return json({ ok: false, error: "file_not_found" }, { status: 404 });
            const viewer = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
            if (String(viewer.sub) !== targetId) return json({ ok: false, error: "file_not_found" }, { status: 404 });
          }
        }
        const object = await env.FILES.get(key);
        if (!object) return json({ ok: false, error: "file_not_found" }, { status: 404 });
        const headers = new Headers(corsHeaders);
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);
        headers.set("cache-control", privacyProtectedAvatar ? "private, no-store" : "public, max-age=3600");
        headers.set("x-content-type-options", "nosniff");
        return new Response(object.body, { headers });
      }
      if (url.pathname === "/livekit/token") {
        return await handleLiveKitToken(request, env);
      }
      if (url.pathname.startsWith("/api/owner/")) {
        return await handleOwnerApi(request, env, url);
      }
      if (url.pathname.startsWith("/api/")) {
        return await handleApi(request, env, url);
      }
      if (env.ASSETS) return env.ASSETS.fetch(request);
      return json({ ok: false, error: "not_found" }, { status: 404 });
    } catch (error) {
      const message = String(error?.message ?? error);
      const status = message === "database_not_bound" ? 503 : 400;
      return json({ ok: false, error: message }, { status });
    }
  },
};
