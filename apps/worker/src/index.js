import { normalizeRole } from "./role_policy.js";
import { handleOwnerApi } from "./owner_api.js";
import { awardSellerVipExp, getVipStatus } from "./vip_store.js";
import { changeVipUniqueId, consumeFreeSayHi, setVipPreference } from "./vip_actions.js";
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

async function ensureUser(db, userId, displayName = "DarkVibeX User") {
  const ts = now();
  await db.prepare(
    `INSERT INTO users (id, display_name, role, coins, diamonds, vip_level, created_at, updated_at)
     VALUES (?, ?, 'user', 2500000, 120, 0, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       display_name = CASE WHEN excluded.display_name <> '' THEN excluded.display_name ELSE users.display_name END,
       updated_at = excluded.updated_at`
  ).bind(userId, displayName, ts, ts).run();
  return db.prepare(
    "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key FROM users WHERE id = ?"
  ).bind(userId).first();
}

async function ensureRoomSettingsTable(db) {
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_settings (
      room_id TEXT PRIMARY KEY,
      announcement TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
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
}

async function listRooms(db) {
  await ensureImageTables(db);
  const result = await db.prepare(
    `SELECT r.id, r.name, r.owner_user_id, r.seat_count, r.locked,
            ri.image_key AS avatar_key,
            COALESCE(u.display_name, '') AS owner_name,
            (SELECT COUNT(*) FROM room_members m WHERE m.room_id = r.id) AS online
       FROM rooms r
       LEFT JOIN users u ON u.id = r.owner_user_id
       LEFT JOIN room_images ri ON ri.room_id = r.id
      ORDER BY r.updated_at DESC
      LIMIT 100`
  ).all();
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
    const user = await ensureUser(db, userId, displayName);
    await ensureUserAllowed(db, userId);
    const token = await createSessionToken(env, userId, user.display_name);
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

  if (parts[0] === "api" && parts[1] === "users" && parts.length === 3 && request.method === "GET") {
    const user = await db.prepare(
      "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key FROM users WHERE id = ?"
    ).bind(parts[2]).first();
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

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "settings") {
    const roomId = parts[2];
    await ensureRoomSettingsTable(db);
    const room = await db.prepare(
      `SELECT r.id, r.owner_user_id, r.name, r.seat_count, r.locked,
              COALESCE(s.announcement, '') AS announcement
         FROM rooms r LEFT JOIN room_settings s ON s.room_id = r.id
        WHERE r.id = ?`
    ).bind(roomId).first();
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
          "INSERT INTO room_settings (room_id, announcement, updated_at) VALUES (?, ?, ?) ON CONFLICT(room_id) DO UPDATE SET announcement = excluded.announcement, updated_at = excluded.updated_at"
        ).bind(roomId, announcement, ts),
      ]);
      return json({ ok: true, settings: { ...room, name, seat_count: seatCount, locked, announcement } });
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
    const requestedSeatCount = Math.max(8, Math.min(42, Number(body.seat_count ?? 12)));
    if (!ownerId || !name) return json({ ok: false, error: "owner_and_name_required" }, { status: 400 });
    await ensureUser(db, ownerId, String(body.owner_name ?? "DarkVibeX User"));
    await ensureUserAllowed(db, ownerId);
    const vipStatus = await getVipStatus(db, ownerId);
    const seatCount = Math.max(8, Math.min(requestedSeatCount, Number(vipStatus.room_seat_limit ?? 12)));
    const roomId = String(body.id ?? "").trim() || String(Math.floor(100000 + Math.random() * 900000));
    const ts = now();
    await db.prepare(
      "INSERT INTO rooms (id, owner_user_id, name, seat_count, locked, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)"
    ).bind(roomId, ownerId, name, seatCount, ts, ts).run();
    await db.prepare(
      "INSERT OR REPLACE INTO room_members (room_id, user_id, seat_index, mic_muted, joined_at, updated_at) VALUES (?, ?, NULL, 1, ?, ?)"
    ).bind(roomId, ownerId, ts, ts).run();
    return json({ ok: true, room_id: roomId }, { status: 201 });
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
    return json({ ok: true });
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
    await ensureUserAllowed(db, userId);
    const seatIndex = body.seat_index == null ? null : Number(body.seat_index);
    const muted = body.mic_muted === false ? 0 : 1;
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await sampleLampMicProgress(db, roomId, now());
    if (seatIndex != null) {
      const occupied = await db.prepare(
        "SELECT user_id FROM room_members WHERE room_id = ? AND seat_index = ? AND user_id <> ? LIMIT 1"
      ).bind(roomId, seatIndex, userId).first();
      if (occupied) return json({ ok: false, error: "seat_occupied" }, { status: 409 });
    }
    await db.prepare(
      "UPDATE room_members SET seat_index = ?, mic_muted = ?, updated_at = ? WHERE room_id = ? AND user_id = ?"
    ).bind(seatIndex, muted, now(), roomId, userId).run();
    if (seatIndex != null) await acceptPendingLampMicInvite(db, roomId, userId, now());
    return json({ ok: true, seat_index: seatIndex, mic_muted: Boolean(muted) });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "messages") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const roomId = parts[2];
    if (request.method === "GET") {
      const authError = await requireSession(request, env);
      if (authError) return authError;
      const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
      const member = await db.prepare(
        "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, String(session.sub)).first();
      if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      const rows = await db.prepare(
        `SELECT m.id, m.user_id, u.display_name, m.text, m.created_at
           FROM room_messages m
           LEFT JOIN users u ON u.id = m.user_id
          WHERE m.room_id = ?
          ORDER BY m.created_at DESC LIMIT 100`
      ).bind(roomId).all();
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
      if (!userId || !textValue) return json({ ok: false, error: "message_required" }, { status: 400 });
      const messageId = id();
      await db.prepare(
        "INSERT INTO room_messages (id, room_id, user_id, text, created_at) VALUES (?, ?, ?, ?, ?)"
      ).bind(messageId, roomId, userId, textValue, now()).run();
      return json({ ok: true, message_id: messageId }, { status: 201 });
    }
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "members") {
    const roomId = parts[2];
    if (request.method === "GET") {
      const authError = await requireSession(request, env);
      if (authError) return authError;
      const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
      const member = await db.prepare(
        "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, String(session.sub)).first();
      if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      const rows = await db.prepare(
        `SELECT m.user_id, u.display_name, u.avatar_key, m.seat_index, m.mic_muted, m.joined_at, m.updated_at
           FROM room_members m
           LEFT JOIN users u ON u.id = m.user_id
          WHERE m.room_id = ?
          ORDER BY CASE WHEN m.seat_index IS NULL THEN 1 ELSE 0 END, m.seat_index ASC, m.joined_at ASC
          LIMIT 200`
      ).bind(roomId).all();
      return json({ ok: true, members: rows.results ?? [] });
    }
    if (request.method === "POST") {
      const body = await bodyJson(request);
      const ownerId = String(body.user_id ?? "").trim();
      const targetId = String(body.target_user_id ?? "").trim();
      const authError = await requireSession(request, env, ownerId);
      if (authError) return authError;
      if (!targetId || targetId === ownerId) return json({ ok: false, error: "invalid_target" }, { status: 400 });
      const room = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
      if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
      if (room.owner_user_id !== ownerId) return json({ ok: false, error: "room_owner_required" }, { status: 403 });
      await ensureRoomSafetyTables(db);
      const shouldBan = body.ban === true;
      if (env.LIVEKIT_URL && env.LIVEKIT_API_KEY && env.LIVEKIT_API_SECRET) {
        const seconds = Math.floor(Date.now() / 1000);
        const adminToken = await signJwt(
          String(env.LIVEKIT_API_SECRET),
          { alg: "HS256", typ: "JWT" },
          {
            iss: String(env.LIVEKIT_API_KEY),
            sub: ownerId,
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
        ).bind(roomId, targetId, ownerId, now()).run();
      }
      const result = await db.prepare(
        "DELETE FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, targetId).run();
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
    const rows = await db.prepare(
      `SELECT m.id, m.sender_user_id, m.receiver_user_id, m.text, m.created_at, m.read_at,
              i.image_key
         FROM direct_messages m
         LEFT JOIN direct_message_images i ON i.message_id = m.id
        WHERE (m.sender_user_id = ? AND m.receiver_user_id = ?)
           OR (m.sender_user_id = ? AND m.receiver_user_id = ?)
        ORDER BY m.created_at ASC
        LIMIT 200`
    ).bind(userId, otherId, otherId, userId).all();
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
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    return json({ ok: true, vip: await getVipStatus(db, userId) });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length === 4 && parts[3] === "preferences" && request.method === "POST") {
    const userId = String(parts[2] ?? "").trim();
    const body = await bodyJson(request);
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    const vip = await setVipPreference(db, userId, body.key, body.enabled === true);
    return json({ ok: true, vip });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length === 4 && parts[3] === "unique-id" && request.method === "POST") {
    const userId = String(parts[2] ?? "").trim();
    const body = await bodyJson(request);
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    const customId = await changeVipUniqueId(db, userId, body.custom_id);
    return json({ ok: true, custom_id: customId, vip: await getVipStatus(db, userId) });
  }

  if (parts[0] === "api" && parts[1] === "vip" && parts.length === 4 && parts[3] === "say-hi" && request.method === "POST") {
    const userId = String(parts[2] ?? "").trim();
    const body = await bodyJson(request);
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId, { checkMute: true });
    const usage = await consumeFreeSayHi(db, userId, body.message);
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

  if (url.pathname === "/api/gifts/send" && request.method === "POST") {
    const giftsFeature = await ownerSetting(db, "feature.gifts", { enabled: true });
    if (giftsFeature.enabled === false) return json({ ok: false, error: "gifts_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const authError = await requireSession(request, env, sender);
    if (authError) return authError;
    const giftId = String(body.gift_id ?? "gift").trim().slice(0, 80);
    const cost = Number(body.coin_cost ?? 0);
    if (!sender || !receiver || giftId !== "basic-star" || cost !== 5000) {
      return json({ ok: false, error: "invalid_gift" }, { status: 400 });
    }
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
        const object = await env.FILES.get(key);
        if (!object) return json({ ok: false, error: "file_not_found" }, { status: 404 });
        const headers = new Headers(corsHeaders);
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);
        headers.set("cache-control", "public, max-age=3600");
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
