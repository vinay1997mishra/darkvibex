import { normalizeRole } from "./role_policy.js";
import { awardIdLevelDaily, awardIdLevelGift, claimIdLevelReward, getIdLevelStatus } from "./id_level.js";
import { COSMETIC_CATALOG, ensureCosmeticsSchema, cosmeticUsesLegacyTable, ownedCosmetics } from "./cosmetics.js";
import { handleOwnerApi } from "./owner_api.js";
import { awardSellerVipExp, ensureVipSchema, getVipStatus } from "./vip_store.js";
import { changeVipUniqueId, consumeFreeSayHi, setVipPreference } from "./vip_actions.js";
import { ensureUniqueIdStoreSchema, uniqueIdCatalog, purchaseUniqueId } from "./unique_id_store.js";
import { ensureSupportSchema } from "./support_store.js";
import { BASE_GIFT_CATALOG, giftById } from "./gift_catalog.js";
import {
  roleWalletDetail,
  setRoleWalletCredential,
  verifyRoleWalletCredential,
  transferRoleCoins,
  requestRoleDollarWithdrawal,
} from "./role_wallets.js";
import {
  ensureTinniSocialSchema,
  profileStats,
  followUser,
  followStatus,
  listFollowers,
  listFollowing,
  taskState,
  claimTask as claimMineTask,
  feedbackHistory,
  submitFeedback,
  medalState,
  familyList,
  familyCreate,
  familyState,
  familyRequestJoin,
  familyResolveJoin,
  familySetAdmin,
  familyRemoveMember,
  familyLeave,
  familyUpdateNotice,
  familyCheckIn,
  cpState,
  cpRequest,
  cpRespond,
  cpDisconnect,
  cpAddMemory,
  cpMemories,
  cpRanking,
  vsState,
  vsRequest,
  vsRespond,
  vsDisconnect,
  vsRanking,
  officialNotices,
  activityFeed,
} from "./tinni_social.js";

import {
  acceptPendingLampMicInvite,
  claimLampTask,
  createLampMicInvite,
  getLampStatus,
  ensureLampSchema,
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

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(String(value ?? "")));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
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
      gender TEXT NOT NULL DEFAULT '',
      call_verified INTEGER NOT NULL DEFAULT 0,
      call_verification_status TEXT NOT NULL DEFAULT 'unverified',
      call_verified_at INTEGER,
      call_verification_revoked_at INTEGER,
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
    ["gender", "TEXT NOT NULL DEFAULT ''"],
    ["call_verified", "INTEGER NOT NULL DEFAULT 0"],
    ["call_verification_status", "TEXT NOT NULL DEFAULT 'unverified'"],
    ["call_verified_at", "INTEGER"],
    ["call_verification_revoked_at", "INTEGER"],
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

// Keep core room tables self-healing because Worker deployments do not auto-apply schema.sql to D1.
async function ensureRoomCoreSchema(db) {
  await ensureUsersSchema(db);
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY,
      owner_user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      seat_count INTEGER NOT NULL DEFAULT 12,
      locked INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (owner_user_id) REFERENCES users(id)
    )`
  ).run();

  const roomInfo = await db.prepare("PRAGMA table_info(rooms)").all();
  const roomColumns = new Set((roomInfo.results ?? []).map((row) => String(row.name ?? "")));
  const roomAdditions = [
    ["owner_user_id", "TEXT NOT NULL DEFAULT ''"],
    ["name", "TEXT NOT NULL DEFAULT ''"],
    ["seat_count", "INTEGER NOT NULL DEFAULT 12"],
    ["locked", "INTEGER NOT NULL DEFAULT 0"],
    ["created_at", "INTEGER NOT NULL DEFAULT 0"],
    ["updated_at", "INTEGER NOT NULL DEFAULT 0"],
  ];
  for (const [name, definition] of roomAdditions) {
    if (roomColumns.has(name)) continue;
    await db.prepare(`ALTER TABLE rooms ADD COLUMN ${name} ${definition}`).run();
  }

  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_members (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      seat_index INTEGER,
      mic_muted INTEGER NOT NULL DEFAULT 1,
      joined_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`
  ).run();

  const memberInfo = await db.prepare("PRAGMA table_info(room_members)").all();
  const memberColumns = new Set((memberInfo.results ?? []).map((row) => String(row.name ?? "")));
  const memberAdditions = [
    ["seat_index", "INTEGER"],
    ["mic_muted", "INTEGER NOT NULL DEFAULT 1"],
    ["joined_at", "INTEGER NOT NULL DEFAULT 0"],
    ["updated_at", "INTEGER NOT NULL DEFAULT 0"],
  ];
  for (const [name, definition] of memberAdditions) {
    if (memberColumns.has(name)) continue;
    await db.prepare(`ALTER TABLE room_members ADD COLUMN ${name} ${definition}`).run();
  }
}

async function ensureRoomSettingsTable(db) {
  await ensureRoomCoreSchema(db);
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_settings (
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
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN room_mode TEXT NOT NULL DEFAULT 'voice'").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN seat_theme_id TEXT NOT NULL DEFAULT 'royal-gold'").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN lock_password_hash TEXT NOT NULL DEFAULT ''").run();
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

async function ensureRoomControlTables(db, roomId = null) {
  await ensureRoomSettingsTable(db);
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN mic_mode TEXT NOT NULL DEFAULT 'free'").run();
  } catch (_) {}
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN public_screen_enabled INTEGER NOT NULL DEFAULT 1").run();
  } catch (_) {}
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_seat_controls (
      room_id TEXT NOT NULL,
      seat_index INTEGER NOT NULL,
      locked INTEGER NOT NULL DEFAULT 0,
      room_muted INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, seat_index),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_seat_requests (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      seat_index INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_chat_bans (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      banned_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS room_seat_invites (
      room_id TEXT NOT NULL,
      target_user_id TEXT NOT NULL,
      seat_index INTEGER NOT NULL,
      invited_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, target_user_id),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`
  ).run();
  if (roomId) {
    await db.prepare(
      "INSERT OR IGNORE INTO room_settings(room_id,announcement,theme_id,group_pk_enabled,welcome_image_key,party_mode,mic_mode,public_screen_enabled,updated_at) VALUES(?,'','dark',0,'','Friends-making Party','free',1,?)"
    ).bind(roomId, now()).run();
  }
}

async function roomModeratorState(db, roomId, userId) {
  await ensureRoomAdminTable(db);
  const room = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
  if (!room) return { room: null, isOwner: false, isAdmin: false };
  const admin = await db.prepare(
    "SELECT 1 AS active FROM room_admins WHERE room_id = ? AND user_id = ?"
  ).bind(roomId, userId).first();
  return {
    room,
    isOwner: room.owner_user_id === userId,
    isAdmin: Boolean(admin),
  };
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

async function ensureDiamondConversionTable(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS diamond_conversions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    diamonds INTEGER NOT NULL CHECK(diamonds>0),
    coins INTEGER NOT NULL CHECK(coins>=0),
    rate REAL NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
}

async function ensureAuthIdentityTable(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_auth_identities (
    provider TEXT NOT NULL,
    subject TEXT NOT NULL,
    user_id TEXT NOT NULL,
    email TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (provider, subject),
    UNIQUE (provider, user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
}

async function ensureUserBlockTable(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS user_blocks (
    user_id TEXT NOT NULL,
    blocked_user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (user_id, blocked_user_id),
    CHECK (user_id <> blocked_user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (blocked_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
}

async function usersBlockedEitherWay(db, firstUserId, secondUserId) {
  await ensureUserBlockTable(db);
  const row = await db.prepare(
    `SELECT 1 AS blocked
       FROM user_blocks
      WHERE (user_id=? AND blocked_user_id=?)
         OR (user_id=? AND blocked_user_id=?)
      LIMIT 1`
  ).bind(firstUserId, secondUserId, secondUserId, firstUserId).first();
  return Boolean(row);
}

async function ensureDirectCallTable(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS direct_calls (
    id TEXT PRIMARY KEY,
    caller_user_id TEXT NOT NULL,
    receiver_user_id TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'ringing',
    created_at INTEGER NOT NULL,
    answered_at INTEGER,
    ended_at INTEGER,
    updated_at INTEGER NOT NULL
  )`).run();
  await db.prepare(
    "CREATE INDEX IF NOT EXISTS idx_direct_calls_receiver_state ON direct_calls(receiver_user_id,state,created_at DESC)"
  ).run();
  await db.prepare(
    "CREATE INDEX IF NOT EXISTS idx_direct_calls_caller_state ON direct_calls(caller_user_id,state,created_at DESC)"
  ).run();
  const callInfo = await db.prepare("PRAGMA table_info(direct_calls)").all();
  const callColumns = new Set((callInfo.results ?? []).map((row) => String(row.name ?? "")));
  const callAdditions = [
    ["call_kind", "TEXT NOT NULL DEFAULT 'direct'"],
    ["cost_coins_per_minute", "INTEGER NOT NULL DEFAULT 0"],
    ["receiver_diamonds_per_minute", "INTEGER NOT NULL DEFAULT 0"],
    ["receiver_earning_eligible", "INTEGER NOT NULL DEFAULT 0"],
    ["billed_minutes", "INTEGER NOT NULL DEFAULT 0"],
    ["caller_cost_coins", "INTEGER NOT NULL DEFAULT 0"],
    ["receiver_reward_diamonds", "INTEGER NOT NULL DEFAULT 0"],
    ["end_reason", "TEXT"],
  ];
  for (const [name, definition] of callAdditions) {
    if (callColumns.has(name)) continue;
    await db.prepare(`ALTER TABLE direct_calls ADD COLUMN ${name} ${definition}`).run();
  }
}

async function ensureCallVerificationSchema(db) {
  await ensureUsersSchema(db);
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS call_verification_submissions (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending_owner',
      system_passed INTEGER NOT NULL DEFAULT 0,
      photo_front_key TEXT NOT NULL,
      photo_left_key TEXT NOT NULL,
      photo_right_key TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      reviewed_at INTEGER,
      review_note TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_call_verify_status_time ON call_verification_submissions(status,created_at DESC)"),
    db.prepare(`CREATE TABLE IF NOT EXISTS random_call_stats (
      user_id TEXT PRIMARY KEY,
      offers INTEGER NOT NULL DEFAULT 0,
      answered INTEGER NOT NULL DEFAULT 0,
      completed_calls INTEGER NOT NULL DEFAULT 0,
      total_minutes INTEGER NOT NULL DEFAULT 0,
      last_offer_at INTEGER,
      updated_at INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
  ]);
}

async function expireDirectCalls(db, ts = now()) {
  await ensureDirectCallTable(db);
  await db.prepare(
    "UPDATE direct_calls SET state='missed',ended_at=?,updated_at=? WHERE state='ringing' AND created_at<?"
  ).bind(ts, ts, ts - 45000).run();
}

async function directCallRow(db, callId) {
  await ensureDirectCallTable(db);
  return db.prepare(
    `SELECT c.*,
            caller.display_name AS caller_name,
            caller.avatar_key AS caller_avatar_key,
            receiver.display_name AS receiver_name,
            receiver.avatar_key AS receiver_avatar_key
       FROM direct_calls c
       LEFT JOIN users caller ON caller.id=c.caller_user_id
       LEFT JOIN users receiver ON receiver.id=c.receiver_user_id
      WHERE c.id=? LIMIT 1`
  ).bind(callId).first();
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
            COALESCE(rs.room_mode, 'voice') AS room_mode,
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

async function ensureCustomGiftSchema(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS custom_gifts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      asset_key TEXT NOT NULL,
      coin_cost INTEGER NOT NULL DEFAULT 5000 CHECK (coin_cost > 0),
      status TEXT NOT NULL DEFAULT 'approved' CHECK (status IN ('pending','approved','rejected')),
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_custom_gifts_status_time ON custom_gifts(status, updated_at DESC)"),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_custom_gifts_user_time ON custom_gifts(user_id, updated_at DESC)"),
  ]);
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

async function settleDirectCallBilling(db, callId, ts = now()) {
  await ensureDirectCallTable(db);
  const call = await db.prepare(
    "SELECT * FROM direct_calls WHERE id=? LIMIT 1"
  ).bind(callId).first();
  if (!call || call.state !== "active" || call.answered_at == null) {
    return call ? directCallRow(db, callId) : null;
  }
  const perMinuteCost = Number(call.cost_coins_per_minute ?? 0);
  if (perMinuteCost <= 0) return directCallRow(db, callId);
  const targetMinutes =
      1 + Math.max(0, Math.floor((ts - Number(call.answered_at)) / 60000));
  const billedMinutes = Number(call.billed_minutes ?? 0);
  const dueMinutes = targetMinutes - billedMinutes;
  if (dueMinutes <= 0) return directCallRow(db, callId);

  const caller = await db.prepare(
    "SELECT coins FROM users WHERE id=? LIMIT 1"
  ).bind(call.caller_user_id).first();
  const affordableMinutes = Math.min(
    dueMinutes,
    Math.floor(Number(caller?.coins ?? 0) / perMinuteCost),
  );
  if (affordableMinutes > 0) {
    const callerCost = affordableMinutes * perMinuteCost;
    const rewardPerMinute =
        Number(call.receiver_earning_eligible ?? 0) === 1
          ? Number(call.receiver_diamonds_per_minute ?? 0)
          : 0;
    const receiverReward = affordableMinutes * rewardPerMinute;
    await walletChange(
      db,
      String(call.caller_user_id),
      -callerCost,
      "call_charge",
      callId,
    );
    const statements = [
      db.prepare(
        `UPDATE direct_calls
            SET billed_minutes=billed_minutes+?,
                caller_cost_coins=caller_cost_coins+?,
                receiver_reward_diamonds=receiver_reward_diamonds+?,
                updated_at=?
          WHERE id=?`
      ).bind(affordableMinutes, callerCost, receiverReward, ts, callId),
    ];
    if (receiverReward > 0) {
      statements.push(
        db.prepare(
          "UPDATE users SET diamonds=diamonds+?,updated_at=? WHERE id=?"
        ).bind(receiverReward, ts, call.receiver_user_id),
      );
    }
    await db.batch(statements);
  }

  if (affordableMinutes < dueMinutes) {
    await db.prepare(
      "UPDATE direct_calls SET state='ended',ended_at=?,end_reason='insufficient_coins',updated_at=? WHERE id=? AND state='active'"
    ).bind(ts, ts, callId).run();
  }
  return directCallRow(db, callId);
}

async function recordRandomCallCompletion(db, callId, ts = now()) {
  await ensureCallVerificationSchema(db);
  const call = await db.prepare(
    "SELECT call_kind,receiver_user_id,billed_minutes FROM direct_calls WHERE id=? LIMIT 1"
  ).bind(callId).first();
  if (!call || String(call.call_kind ?? "") !== "random") return;
  await db.prepare(
    `INSERT INTO random_call_stats
      (user_id,offers,answered,completed_calls,total_minutes,last_offer_at,updated_at)
     VALUES (?,0,0,1,?,NULL,?)
     ON CONFLICT(user_id) DO UPDATE SET
       completed_calls=completed_calls+1,
       total_minutes=total_minutes+excluded.total_minutes,
       updated_at=excluded.updated_at`
  ).bind(call.receiver_user_id, Number(call.billed_minutes ?? 0), ts).run();
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

  if (url.pathname === "/api/messages/official" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    return json({ ok: true, notices: await officialNotices(db) });
  }

  if (url.pathname === "/api/messages/activity" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, activity: await activityFeed(db, userId) });
  }

  if (url.pathname === "/api/social/stats" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const targetId = userId || String(session.sub);
    await ensureTinniSocialSchema(db);
    return json({ ok: true, stats: await profileStats(db, targetId) });
  }

  if (url.pathname === "/api/social/blocked" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUserBlockTable(db);
    const rows = await db.prepare(
      `SELECT b.blocked_user_id AS user_id,
              COALESCE(u.display_name,'User') AS display_name,
              u.avatar_key,
              b.created_at
         FROM user_blocks b
         LEFT JOIN users u ON u.id=b.blocked_user_id
        WHERE b.user_id=?
        ORDER BY b.created_at DESC`
    ).bind(userId).all();
    return json({ ok: true, blocked: rows.results ?? [] });
  }

  if (url.pathname === "/api/social/block" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const targetId = String(body.target_user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!userId || !targetId || userId === targetId) {
      return json({ ok:false,error:"invalid_block_target" }, { status:400 });
    }
    await ensureUser(db, userId);
    await ensureUser(db, targetId);
    await ensureUserBlockTable(db);
    if (body.blocked === false) {
      await db.prepare(
        "DELETE FROM user_blocks WHERE user_id=? AND blocked_user_id=?"
      ).bind(userId,targetId).run();
      return json({ ok:true, blocked:false });
    }
    await db.prepare(
      `INSERT INTO user_blocks(user_id,blocked_user_id,created_at)
       VALUES(?,?,?)
       ON CONFLICT(user_id,blocked_user_id)
       DO UPDATE SET created_at=excluded.created_at`
    ).bind(userId,targetId,now()).run();
    await ensureTinniSocialSchema(db);
    await db.batch([
      db.prepare("DELETE FROM user_friends WHERE user_id=? AND friend_user_id=?")
        .bind(userId,targetId),
      db.prepare("DELETE FROM user_friends WHERE user_id=? AND friend_user_id=?")
        .bind(targetId,userId),
      db.prepare("DELETE FROM user_follows WHERE follower_id=? AND target_id=?")
        .bind(userId,targetId),
      db.prepare("DELETE FROM user_follows WHERE follower_id=? AND target_id=?")
        .bind(targetId,userId),
    ]);
    return json({ ok:true, blocked:true });
  }

  if (url.pathname === "/api/social/follow" && request.method === "GET") {
    const actor = String(url.searchParams.get("user_id") ?? "").trim();
    const target = String(url.searchParams.get("target_user_id") ?? "").trim();
    const authError = await requireSession(request, env, actor);
    if (authError) return authError;
    return json({ ok: true, following: await followStatus(db, actor, target) });
  }

  if (url.pathname === "/api/social/follow" && request.method === "POST") {
    const body = await bodyJson(request);
    const actor = String(body.user_id ?? "").trim();
    const target = String(body.target_user_id ?? "").trim();
    const authError = await requireSession(request, env, actor);
    if (authError) return authError;
    if (await usersBlockedEitherWay(db, actor, target)) {
      return json({ ok:false,error:"blocked_user" }, { status:403 });
    }
    try {
      return json(await followUser(db, actor, target, body.follow !== false));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/social/followers" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const targetId = userId || String(session.sub);
    return json({ ok: true, followers: await listFollowers(db, targetId) });
  }

  if (url.pathname === "/api/social/following" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const targetId = userId || String(session.sub);
    return json({ ok: true, following: await listFollowing(db, targetId) });
  }

  if (url.pathname === "/api/tasks" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, tasks: await taskState(db, userId) });
  }

  if (url.pathname === "/api/tasks/claim" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await claimMineTask(db, userId, body.task_id));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/feedback" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, feedback: await feedbackHistory(db, userId) });
  }

  if (url.pathname === "/api/feedback" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await submitFeedback(db, userId, body.category, body.message), { status: 201 });
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/medals" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, medals: await medalState(db, userId) });
  }

  if (url.pathname === "/api/family/list" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    return json({
      ok: true,
      families: await familyList(db, url.searchParams.get("limit") ?? 100),
    });
  }

  if (url.pathname === "/api/family" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, ...(await familyState(db, userId)) });
  }

  if (url.pathname === "/api/family/create" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familyCreate(db, userId, body.name, body.tag), { status: 201 });
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/family/join-request" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familyRequestJoin(db, userId, String(body.family_id ?? "")));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/family/join-request/resolve" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familyResolveJoin(
        db,
        userId,
        String(body.target_user_id ?? ""),
        body.approve === true,
      ));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/family/admin" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familySetAdmin(
        db,
        userId,
        String(body.target_user_id ?? ""),
        body.admin === true,
      ));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/family/member/remove" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familyRemoveMember(
        db,
        userId,
        String(body.target_user_id ?? ""),
      ));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/family/leave" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familyLeave(db, userId));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/family/notice" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familyUpdateNotice(db, userId, body.notice));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/family/check-in" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(await familyCheckIn(db, userId));
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/vs/ranking" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    return json({
      ok: true,
      ranking: await vsRanking(db, url.searchParams.get("limit") ?? 100),
    });
  }

  if (url.pathname === "/api/vs" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, vs: await vsState(db, userId) });
  }

  if (url.pathname === "/api/vs/request" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json(
        { ok: true, vs: await vsRequest(db, userId, String(body.target_user_id ?? "")) },
        { status: 201 },
      );
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/vs/respond" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok: true, vs: await vsRespond(db, userId, body.accept === true) });
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/vs/disconnect" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json(await vsDisconnect(db, userId));
  }

  if (url.pathname === "/api/cp/ranking" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    return json({
      ok: true,
      ranking: await cpRanking(db, url.searchParams.get("limit") ?? 100),
    });
  }

  if (url.pathname === "/api/cp" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, cp: await cpState(db, userId) });
  }

  if (url.pathname === "/api/cp/request" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok: true, cp: await cpRequest(db, userId, String(body.target_user_id ?? "")) }, { status: 201 });
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/cp/respond" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok: true, cp: await cpRespond(db, userId, body.accept === true) });
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/cp/disconnect" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json(await cpDisconnect(db, userId));
  }

  if (url.pathname === "/api/cp/memories" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json({ ok: true, memories: await cpMemories(db, userId) });
  }

  if (url.pathname === "/api/cp/memories" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok: true, memory: await cpAddMemory(db, userId, body.text) }, { status: 201 });
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/rooms/following" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureLampSchema(db);
    const rows = await db.prepare(
      `SELECT r.id,r.name,r.owner_name,r.owner_user_id,r.online,r.seat_count,
              r.avatar_key,COALESCE(s.party_mode,'Friends-making Party') AS party_mode,
              COALESCE(s.room_mode,'voice') AS room_mode,
              rf.followed_at
         FROM room_followers rf
         JOIN rooms r ON r.id=rf.room_id
         LEFT JOIN room_settings s ON s.room_id=r.id
        WHERE rf.user_id=?
        ORDER BY rf.updated_at DESC LIMIT 100`
    ).bind(userId).all();
    return json({ ok: true, rooms: rows.results ?? [] });
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
    const owned = await ownedCosmetics(db, userId, now());
    return json({ ok: true, items: COSMETIC_CATALOG, owned });
  }

  if (url.pathname === "/api/cosmetics/purchase" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const recipientId = String(body.recipient_user_id ?? userId).trim();
    const itemId = String(body.item_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const product = COSMETIC_CATALOG.find((item) => item.id === itemId);
    if (!product) return json({ ok:false,error:"cosmetic_not_found" }, { status:404 });
    await ensureUser(db,userId);
    if (!recipientId) return json({ ok:false,error:"recipient_required" }, { status:400 });
    if (recipientId !== userId) {
      const recipient = await db.prepare("SELECT id FROM users WHERE id=?").bind(recipientId).first();
      if (!recipient) return json({ ok:false,error:"recipient_not_found" }, { status:404 });
    }
    await ensureUserAllowed(db,userId);
    if (recipientId !== userId) await ensureUserAllowed(db,recipientId);
    await ensureCosmeticsSchema(db);
    await ensureVipSchema(db);
    const ts=now();
    const vip=await getVipStatus(db,recipientId,ts);
    if (Number(product.min_vip_level ?? 0) > 0 &&
        (!vip.active || vip.level < Number(product.min_vip_level))) {
      return json({
        ok:false,
        error:"vip_level_required",
        required_level:Number(product.min_vip_level),
      }, { status:403 });
    }

    const expiresAt = Number(product.duration_days ?? 0) > 0
      ? ts + Number(product.duration_days) * 86400000
      : 4102444800000;
    const legacy = cosmeticUsesLegacyTable(product.kind);
    const table = legacy ? "user_cosmetics" : "user_props";
    const owned = await db.prepare(
      `SELECT 1 AS owned FROM ${table} WHERE user_id=? AND item_id=? AND expires_at>?`
    ).bind(recipientId,itemId,ts).first();
    if (owned) return json({ ok:false,error:"already_owned" }, { status:409 });

    const debit = await db.prepare(
      "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=?"
    ).bind(product.price_coins,ts,userId,product.price_coins).run();
    if (Number(debit.meta?.changes ?? 0) !== 1) {
      return json({ ok:false,error:"insufficient_coins" }, { status:400 });
    }

    try {
      await db.prepare(
        `INSERT INTO ${table}(user_id,item_id,kind,acquired_at,expires_at,active)
         VALUES(?,?,?,?,?,0)
         ON CONFLICT(user_id,item_id)
         DO UPDATE SET kind=excluded.kind,acquired_at=excluded.acquired_at,
                       expires_at=excluded.expires_at,active=0`
      ).bind(recipientId,itemId,product.kind,ts,expiresAt).run();
      const wallet=await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
      await db.prepare(
        "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
      ).bind(
        id(),
        userId,
        recipientId===userId ? "cosmetic_purchase" : "cosmetic_gift",
        -Number(product.price_coins),
        Number(wallet?.coins ?? 0),
        itemId,
        ts,
      ).run();
      return json({
        ok:true,
        item_id:itemId,
        kind:product.kind,
        coin_balance:Number(wallet?.coins ?? 0),
        expires_at:expiresAt,
        recipient_user_id:recipientId,
      });
    } catch (error) {
      await db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?")
        .bind(product.price_coins,now(),userId).run();
      throw error;
    }
  }

  if (url.pathname === "/api/cosmetics/equip" && request.method === "POST") {
    const body=await bodyJson(request);
    const userId=String(body.user_id ?? "").trim();
    const itemId=String(body.item_id ?? "").trim();
    const authError=await requireSession(request,env,userId);
    if (authError) return authError;
    await ensureUserAllowed(db,userId);
    await ensureCosmeticsSchema(db);
    await ensureVipSchema(db);
    const item=COSMETIC_CATALOG.find((product)=>product.id===itemId);
    if (!item) return json({ok:false,error:"cosmetic_not_found"}, {status:404});
    const vip=await getVipStatus(db,userId,now());
    if (Number(item.min_vip_level ?? 0)>0 &&
        (!vip.active || vip.level<Number(item.min_vip_level))) {
      return json({
        ok:false,error:"vip_level_required",
        required_level:Number(item.min_vip_level),
      }, {status:403});
    }
    const table=cosmeticUsesLegacyTable(item.kind) ? "user_cosmetics" : "user_props";
    const owned=await db.prepare(
      `SELECT 1 AS owned FROM ${table} WHERE user_id=? AND item_id=? AND expires_at>?`
    ).bind(userId,itemId,now()).first();
    if (!owned) return json({ok:false,error:"cosmetic_not_owned"}, {status:403});
    await db.batch([
      db.prepare(`UPDATE ${table} SET active=0 WHERE user_id=? AND kind=?`)
        .bind(userId,item.kind),
      db.prepare(`UPDATE ${table} SET active=1 WHERE user_id=? AND item_id=? AND expires_at>?`)
        .bind(userId,itemId,now()),
    ]);
    return json({ok:true,item_id:itemId,kind:item.kind});
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

    await ensureAuthIdentityTable(db);
    const subject = String(claims.sub);
    const linkedIdentity = await db.prepare(
      "SELECT user_id FROM user_auth_identities WHERE provider='google' AND subject=? LIMIT 1"
    ).bind(subject).first();
    const userId = String(linkedIdentity?.user_id ?? ("g_" + subject));
    const displayName = String(
      claims.name ?? claims.given_name ?? claims.email ?? "DarkVibeX User"
    ).trim().slice(0, 60);

    let user;
    try {
      user = await ensureUser(db, userId, displayName);
      await db.prepare(
        `INSERT INTO user_auth_identities(provider,subject,user_id,email,created_at,updated_at)
         VALUES('google',?,?,?,?,?)
         ON CONFLICT(provider,subject)
         DO UPDATE SET email=excluded.email,updated_at=excluded.updated_at`
      ).bind(
        subject,
        userId,
        String(claims.email ?? "").trim() || null,
        now(),
        now(),
      ).run();
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

  if (url.pathname === "/api/account/bind-google" && request.method === "POST") {
    if (!env.SESSION_SECRET) {
      return json({ ok:false,error:"session_secret_not_configured" }, { status:503 });
    }
    const sessionError = await requireSession(request, env);
    if (sessionError) return sessionError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const userId = String(session.sub);
    const body = await bodyJson(request);
    const idToken = String(body.id_token ?? "").trim();
    if (!idToken) {
      return json({ ok:false,error:"google_id_token_required" }, { status:400 });
    }
    let claims;
    try {
      claims = await verifyGoogleIdToken(idToken, env.GOOGLE_WEB_CLIENT_ID);
    } catch (error) {
      const code = String(error?.message ?? error);
      return json(
        { ok:false,error:code },
        { status: code === "google_auth_not_configured" ? 503 : 401 },
      );
    }
    await ensureUser(db, userId);
    await ensureAuthIdentityTable(db);
    const subject = String(claims.sub);
    const existingSubject = await db.prepare(
      "SELECT user_id FROM user_auth_identities WHERE provider='google' AND subject=? LIMIT 1"
    ).bind(subject).first();
    if (existingSubject && String(existingSubject.user_id) !== userId) {
      return json({ ok:false,error:"google_account_already_bound" }, { status:409 });
    }
    const existingUser = await db.prepare(
      "SELECT subject FROM user_auth_identities WHERE provider='google' AND user_id=? LIMIT 1"
    ).bind(userId).first();
    if (existingUser && String(existingUser.subject) !== subject) {
      return json({ ok:false,error:"user_already_bound_to_google" }, { status:409 });
    }
    await db.prepare(
      `INSERT INTO user_auth_identities(provider,subject,user_id,email,created_at,updated_at)
       VALUES('google',?,?,?,?,?)
       ON CONFLICT(provider,subject)
       DO UPDATE SET user_id=excluded.user_id,email=excluded.email,updated_at=excluded.updated_at`
    ).bind(
      subject,
      userId,
      String(claims.email ?? "").trim() || null,
      now(),
      now(),
    ).run();
    return json({
      ok:true,
      provider:"google",
      email:String(claims.email ?? ""),
      user_id:userId,
    });
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
    const requestedUserId = String(parts[2] ?? "").trim();
    await ensureVipSchema(db);
    let viewedUserId = requestedUserId;
    let user = await db.prepare(
      "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key, date_of_birth FROM users WHERE id = ?"
    ).bind(viewedUserId).first();
    if (!user && requestedUserId) {
      const byPublicId = await db.prepare(
        `SELECT u.id,u.display_name,u.role,u.coins,u.diamonds,u.vip_level,u.avatar_key,u.date_of_birth
           FROM user_vip v
           JOIN users u ON u.id=v.user_id
          WHERE v.custom_id=?
            AND (v.custom_id_expires_at IS NULL OR v.custom_id_expires_at>?)
          LIMIT 1`
      ).bind(requestedUserId,now()).first();
      if (byPublicId) {
        user = byPublicId;
        viewedUserId = String(byPublicId.id);
      }
    }
    if (user) {
      const targetVip = await getVipStatus(db, viewedUserId);
      user.active_vip_level = targetVip.active ? targetVip.level : 0;
      user.public_id = targetVip.custom_id || user.id;
      user.public_id_expires_at = targetVip.custom_id_expires_at ?? null;
      const owned = await ownedCosmetics(db, viewedUserId, now());
      for (const prop of owned) {
        if (!(prop.active === true || Number(prop.active ?? 0) === 1)) continue;
        user["active_" + String(prop.kind) + "_id"] = String(prop.item_id ?? "");
      }
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
    const member = await db.prepare("SELECT seat_index FROM room_members WHERE room_id = ? AND user_id = ?")
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

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "controls") {
    const roomId = parts[2];
    await ensureRoomControlTables(db, roomId);
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const actorId = String(session.sub);
    const membership = await db.prepare(
      "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
    ).bind(roomId, actorId).first();
    if (!membership) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    const mod = await roomModeratorState(db, roomId, actorId);
    if (!mod.room) return json({ ok: false, error: "room_not_found" }, { status: 404 });

    if (request.method === "GET") {
      const settings = await db.prepare(
        "SELECT COALESCE(mic_mode,'free') AS mic_mode, COALESCE(public_screen_enabled,1) AS public_screen_enabled FROM room_settings WHERE room_id = ?"
      ).bind(roomId).first();
      const seatControls = await db.prepare(
        "SELECT seat_index,locked,room_muted FROM room_seat_controls WHERE room_id = ? ORDER BY seat_index"
      ).bind(roomId).all();
      const requests = (mod.isOwner || mod.isAdmin)
        ? await db.prepare(
            `SELECT q.user_id,q.seat_index,q.created_at,u.display_name,u.avatar_key
               FROM room_seat_requests q
               LEFT JOIN users u ON u.id=q.user_id
              WHERE q.room_id=?
              ORDER BY q.created_at ASC`
          ).bind(roomId).all()
        : { results: [] };
      const chatBan = await db.prepare(
        "SELECT 1 AS banned FROM room_chat_bans WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, actorId).first();
      const invite = await db.prepare(
        `SELECT i.seat_index,i.invited_by,i.created_at,
                COALESCE(u.display_name,'Room moderator') AS invited_by_name
           FROM room_seat_invites i
           LEFT JOIN users u ON u.id=i.invited_by
          WHERE i.room_id=? AND i.target_user_id=?`
      ).bind(roomId, actorId).first();
      return json({
        ok: true,
        mic_mode: settings?.mic_mode ?? "free",
        public_screen_enabled: Number(settings?.public_screen_enabled ?? 1) === 1,
        seat_controls: seatControls.results ?? [],
        seat_requests: requests.results ?? [],
        chat_banned: Boolean(chatBan),
        seat_invite: invite ?? null,
        is_owner: mod.isOwner,
        is_admin: mod.isAdmin,
      });
    }

    if (request.method === "POST") {
      const body = await bodyJson(request);
      const action = String(body.action ?? "").trim();
      if (action === "mic_mode") {
        if (!mod.isOwner) return json({ ok: false, error: "room_owner_required" }, { status: 403 });
        const mode = String(body.mic_mode ?? "").trim() === "apply" ? "apply" : "free";
        await db.prepare(
          "UPDATE room_settings SET mic_mode=?,updated_at=? WHERE room_id=?"
        ).bind(mode, now(), roomId).run();
        return json({ ok: true, mic_mode: mode });
      }
      if (action === "public_screen") {
        if (!mod.isOwner && !mod.isAdmin) return json({ ok: false, error: "room_moderator_required" }, { status: 403 });
        const enabled = body.enabled === true ? 1 : 0;
        await db.prepare(
          "UPDATE room_settings SET public_screen_enabled=?,updated_at=? WHERE room_id=?"
        ).bind(enabled, now(), roomId).run();
        return json({ ok: true, public_screen_enabled: Boolean(enabled) });
      }
      if (action === "seat_lock" || action === "seat_mute" || action === "seat_down") {
        if (!mod.isOwner && !mod.isAdmin) return json({ ok: false, error: "room_moderator_required" }, { status: 403 });
        const seatIndex = Number(body.seat_index);
        const roomRow = await db.prepare("SELECT seat_count,owner_user_id FROM rooms WHERE id=?").bind(roomId).first();
        if (!Number.isSafeInteger(seatIndex) || seatIndex < 0 || seatIndex >= Number(roomRow?.seat_count ?? 0)) {
          return json({ ok: false, error: "invalid_seat_index" }, { status: 400 });
        }
        if (action === "seat_lock") {
          const locked = body.locked === true ? 1 : 0;
          await db.prepare(
            "INSERT INTO room_seat_controls(room_id,seat_index,locked,room_muted,updated_at) VALUES(?,?,?,0,?) ON CONFLICT(room_id,seat_index) DO UPDATE SET locked=excluded.locked,updated_at=excluded.updated_at"
          ).bind(roomId, seatIndex, locked, now()).run();
          return json({ ok: true, seat_index: seatIndex, locked: Boolean(locked) });
        }
        const occupant = await db.prepare(
          "SELECT m.user_id, CASE WHEN ra.user_id IS NULL THEN 0 ELSE 1 END AS is_admin FROM room_members m LEFT JOIN room_admins ra ON ra.room_id=m.room_id AND ra.user_id=m.user_id WHERE m.room_id=? AND m.seat_index=?"
        ).bind(roomId, seatIndex).first();
        if (!occupant) return json({ ok: false, error: "seat_empty" }, { status: 404 });
        if (occupant.user_id === mod.room.owner_user_id) return json({ ok: false, error: "owner_seat_protected" }, { status: 403 });
        if (!mod.isOwner && Number(occupant.is_admin) === 1) return json({ ok: false, error: "admin_seat_protected" }, { status: 403 });
        if (action === "seat_down") {
          await db.prepare(
            "UPDATE room_members SET seat_index=NULL,mic_muted=1,updated_at=? WHERE room_id=? AND user_id=?"
          ).bind(now(), roomId, occupant.user_id).run();
          return json({ ok: true, seat_index: seatIndex, user_id: occupant.user_id });
        }
        const muted = body.muted === true ? 1 : 0;
        await db.batch([
          db.prepare(
            "INSERT INTO room_seat_controls(room_id,seat_index,locked,room_muted,updated_at) VALUES(?,?,0,?,?) ON CONFLICT(room_id,seat_index) DO UPDATE SET room_muted=excluded.room_muted,updated_at=excluded.updated_at"
          ).bind(roomId, seatIndex, muted, now()),
          db.prepare(
            "UPDATE room_members SET mic_muted=?,updated_at=? WHERE room_id=? AND seat_index=?"
          ).bind(muted, now(), roomId, seatIndex),
        ]);
        return json({ ok: true, seat_index: seatIndex, room_muted: Boolean(muted) });
      }
      if (action === "seat_invite") {
        if (!mod.isOwner && !mod.isAdmin) {
          return json({ ok:false,error:"room_moderator_required" }, { status:403 });
        }
        const targetId = String(body.target_user_id ?? "").trim();
        const seatIndex = Number(body.seat_index);
        if (!targetId || targetId === actorId) {
          return json({ ok:false,error:"invalid_target" }, { status:400 });
        }
        const roomRow = await db.prepare(
          "SELECT seat_count,owner_user_id FROM rooms WHERE id=?"
        ).bind(roomId).first();
        if (!Number.isSafeInteger(seatIndex) || seatIndex < 0 || seatIndex >= Number(roomRow?.seat_count ?? 0)) {
          return json({ ok:false,error:"invalid_seat_index" }, { status:400 });
        }
        const target = await db.prepare(
          "SELECT seat_index FROM room_members WHERE room_id=? AND user_id=?"
        ).bind(roomId,targetId).first();
        if (!target) return json({ ok:false,error:"target_not_in_room" }, { status:404 });
        if (target.seat_index != null) return json({ ok:false,error:"target_already_on_seat" }, { status:409 });
        const locked = await db.prepare(
          "SELECT locked FROM room_seat_controls WHERE room_id=? AND seat_index=?"
        ).bind(roomId,seatIndex).first();
        const occupied = await db.prepare(
          "SELECT 1 AS occupied FROM room_members WHERE room_id=? AND seat_index=?"
        ).bind(roomId,seatIndex).first();
        if (Number(locked?.locked ?? 0) === 1 || occupied) {
          return json({ ok:false,error:"seat_unavailable" }, { status:409 });
        }
        await db.prepare(
          "INSERT INTO room_seat_invites(room_id,target_user_id,seat_index,invited_by,created_at) VALUES(?,?,?,?,?) ON CONFLICT(room_id,target_user_id) DO UPDATE SET seat_index=excluded.seat_index,invited_by=excluded.invited_by,created_at=excluded.created_at"
        ).bind(roomId,targetId,seatIndex,actorId,now()).run();
        return json({ ok:true,target_user_id:targetId,seat_index:seatIndex });
      }
      if (action === "seat_invite_respond") {
        const invite = await db.prepare(
          "SELECT seat_index FROM room_seat_invites WHERE room_id=? AND target_user_id=?"
        ).bind(roomId,actorId).first();
        if (!invite) return json({ ok:false,error:"seat_invite_not_found" }, { status:404 });
        const seatIndex = Number(invite.seat_index);
        if (body.accepted === true) {
          const locked = await db.prepare(
            "SELECT locked FROM room_seat_controls WHERE room_id=? AND seat_index=?"
          ).bind(roomId,seatIndex).first();
          const occupied = await db.prepare(
            "SELECT 1 AS occupied FROM room_members WHERE room_id=? AND seat_index=?"
          ).bind(roomId,seatIndex).first();
          if (Number(locked?.locked ?? 0) === 1 || occupied) {
            await db.prepare(
              "DELETE FROM room_seat_invites WHERE room_id=? AND target_user_id=?"
            ).bind(roomId,actorId).run();
            return json({ ok:false,error:"seat_unavailable" }, { status:409 });
          }
          await db.prepare(
            "UPDATE room_members SET seat_index=?,mic_muted=1,updated_at=? WHERE room_id=? AND user_id=?"
          ).bind(seatIndex,now(),roomId,actorId).run();
          await acceptPendingLampMicInvite(db, roomId, actorId, now());
        }
        await db.prepare(
          "DELETE FROM room_seat_invites WHERE room_id=? AND target_user_id=?"
        ).bind(roomId,actorId).run();
        return json({ ok:true,accepted:body.accepted===true,seat_index:seatIndex });
      }
      if (action === "chat_ban") {
        if (!mod.isOwner && !mod.isAdmin) return json({ ok: false, error: "room_moderator_required" }, { status: 403 });
        const targetId = String(body.target_user_id ?? "").trim();
        if (!targetId) return json({ ok: false, error: "target_required" }, { status: 400 });
        const target = await roomModeratorState(db, roomId, targetId);
        if (!target.room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
        if (target.isOwner || (!mod.isOwner && target.isAdmin)) {
          return json({ ok: false, error: "moderation_target_protected" }, { status: 403 });
        }
        if (body.banned === true) {
          await db.prepare(
            "INSERT INTO room_chat_bans(room_id,user_id,banned_by,created_at) VALUES(?,?,?,?) ON CONFLICT(room_id,user_id) DO UPDATE SET banned_by=excluded.banned_by,created_at=excluded.created_at"
          ).bind(roomId, targetId, actorId, now()).run();
        } else {
          await db.prepare("DELETE FROM room_chat_bans WHERE room_id=? AND user_id=?").bind(roomId,targetId).run();
        }
        return json({ ok: true, target_user_id: targetId, chat_banned: body.banned === true });
      }
      return json({ ok: false, error: "invalid_room_control_action" }, { status: 400 });
    }
    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "seat-request" && request.method === "POST") {
    const roomId = parts[2];
    await ensureRoomControlTables(db, roomId);
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const seatIndex = Number(body.seat_index);
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const member = await db.prepare("SELECT 1 AS active FROM room_members WHERE room_id=? AND user_id=?").bind(roomId,userId).first();
    if (!member) return json({ ok:false,error:"room_membership_required" }, { status:403 });
    const settings = await db.prepare("SELECT COALESCE(mic_mode,'free') AS mic_mode FROM room_settings WHERE room_id=?").bind(roomId).first();
    if ((settings?.mic_mode ?? "free") !== "apply") return json({ ok:false,error:"mic_mode_free" }, { status:409 });
    const roomRow = await db.prepare("SELECT seat_count FROM rooms WHERE id=?").bind(roomId).first();
    if (!Number.isSafeInteger(seatIndex) || seatIndex < 0 || seatIndex >= Number(roomRow?.seat_count ?? 0)) {
      return json({ ok:false,error:"invalid_seat_index" }, { status:400 });
    }
    const locked = await db.prepare("SELECT locked FROM room_seat_controls WHERE room_id=? AND seat_index=?").bind(roomId,seatIndex).first();
    if (Number(locked?.locked ?? 0) === 1) return json({ ok:false,error:"seat_locked" }, { status:409 });
    const occupied = await db.prepare("SELECT 1 AS occupied FROM room_members WHERE room_id=? AND seat_index=?").bind(roomId,seatIndex).first();
    if (occupied) return json({ ok:false,error:"seat_occupied" }, { status:409 });
    await db.prepare(
      "INSERT INTO room_seat_requests(room_id,user_id,seat_index,created_at) VALUES(?,?,?,?) ON CONFLICT(room_id,user_id) DO UPDATE SET seat_index=excluded.seat_index,created_at=excluded.created_at"
    ).bind(roomId,userId,seatIndex,now()).run();
    return json({ ok:true, seat_index:seatIndex });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 5 && parts[3] === "seat-request" && parts[4] === "resolve" && request.method === "POST") {
    const roomId = parts[2];
    await ensureRoomControlTables(db, roomId);
    const body = await bodyJson(request);
    const actorId = String(body.user_id ?? "").trim();
    const targetId = String(body.target_user_id ?? "").trim();
    const authError = await requireSession(request, env, actorId);
    if (authError) return authError;
    const mod = await roomModeratorState(db, roomId, actorId);
    if (!mod.isOwner && !mod.isAdmin) return json({ ok:false,error:"room_moderator_required" }, { status:403 });
    const requestRow = await db.prepare("SELECT seat_index FROM room_seat_requests WHERE room_id=? AND user_id=?").bind(roomId,targetId).first();
    if (!requestRow) return json({ ok:false,error:"request_not_found" }, { status:404 });
    if (body.approved === true) {
      const seatIndex = Number(requestRow.seat_index);
      const locked = await db.prepare("SELECT locked FROM room_seat_controls WHERE room_id=? AND seat_index=?").bind(roomId,seatIndex).first();
      const occupied = await db.prepare("SELECT 1 AS occupied FROM room_members WHERE room_id=? AND seat_index=?").bind(roomId,seatIndex).first();
      if (Number(locked?.locked ?? 0) === 1 || occupied) return json({ ok:false,error:"seat_unavailable" }, { status:409 });
      await db.prepare(
        "UPDATE room_members SET seat_index=?,mic_muted=1,updated_at=? WHERE room_id=? AND user_id=?"
      ).bind(seatIndex,now(),roomId,targetId).run();
    }
    await db.prepare("DELETE FROM room_seat_requests WHERE room_id=? AND user_id=?").bind(roomId,targetId).run();
    return json({ ok:true, approved:body.approved===true });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "settings") {
    const roomId = parts[2];
    await ensureRoomSettingsTable(db);
    await ensureVipSchema(db);
    const room = await db.prepare(
      `SELECT r.id, r.owner_user_id, r.name, r.seat_count, r.locked,
              COALESCE(s.announcement, '') AS announcement, COALESCE(s.theme_id, 'dark') AS theme_id, COALESCE(s.group_pk_enabled, 0) AS group_pk_enabled,
              COALESCE(s.party_mode, 'Friends-making Party') AS party_mode,
              COALESCE(s.room_mode, 'voice') AS room_mode,
              COALESCE(s.seat_theme_id, 'royal-gold') AS seat_theme_id,
              CASE WHEN COALESCE(s.lock_password_hash, '') <> '' THEN 1 ELSE 0 END AS lock_password_set,
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
      const actorIsOwner = room.owner_user_id === userId;
      const adminRow = actorIsOwner ? { is_admin: 1 } : await db.prepare(
        "SELECT 1 AS is_admin FROM room_admins WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, userId).first();
      const actorIsAdmin = Number(adminRow?.is_admin ?? 0) === 1;
      if (!actorIsOwner && !actorIsAdmin) {
        return json({ ok: false, error: "room_admin_required" }, { status: 403 });
      }
      const name = actorIsOwner
        ? String(body.name ?? "").trim().slice(0, 80)
        : String(room.name ?? "").trim().slice(0, 80);
      const requestedSeatCount = Number(body.seat_count ?? room.seat_count);
      if (!Number.isSafeInteger(requestedSeatCount) || requestedSeatCount < 8 || requestedSeatCount > 42) {
        return json({ ok: false, error: "invalid_seat_count" }, { status: 400 });
      }
      const vipStatus = await getVipStatus(db, userId);
      if (!actorIsOwner && requestedSeatCount <= Number(room.seat_count)) {
        return json({ ok: false, error: "admin_can_only_increase_seats" }, { status: 403 });
      }
      const seatCount = requestedSeatCount;
      const locked = actorIsOwner ? (body.locked === true ? 1 : 0) : Number(room.locked ?? 0);
      const priorLock = await db.prepare(
        "SELECT COALESCE(lock_password_hash,'') AS lock_password_hash FROM room_settings WHERE room_id=?"
      ).bind(roomId).first();
      let lockPasswordHash = String(priorLock?.lock_password_hash ?? "");
      if (actorIsOwner) {
        if (locked === 1) {
          const suppliedPassword = String(body.lock_password ?? "").trim().slice(0, 64);
          if (suppliedPassword) {
            if (suppliedPassword.length < 4) {
              return json({ ok:false,error:"room_password_too_short" }, { status:400 });
            }
            lockPasswordHash = await sha256Hex(suppliedPassword);
          } else if (!lockPasswordHash) {
            return json({ ok:false,error:"room_password_required" }, { status:400 });
          }
        } else {
          lockPasswordHash = "";
        }
      }
      const announcement = actorIsOwner
        ? String(body.announcement ?? "").trim().slice(0, 500)
        : String(room.announcement ?? "").trim().slice(0, 500);
      const welcomeImageKey = actorIsOwner && Object.prototype.hasOwnProperty.call(body, "welcome_image_key")
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
      const themeId = actorIsOwner
        ? String(body.theme_id ?? room.theme_id ?? "dark")
        : String(room.theme_id ?? "dark");
      if (!allowedThemes.has(themeId)) return json({ ok: false, error: "invalid_theme" }, { status: 400 });
      if (themeId !== "dark" && themeId !== room.theme_id && !vipStatus.room_background_enabled) {
        return json({ ok: false, error: "vip3_required_for_room_background" }, { status: 403 });
      }
      const groupPkEnabled = actorIsOwner
        ? (body.group_pk_enabled === true ? 1 : 0)
        : Number(room.group_pk_enabled ?? 0);
      const requestedPartyMode = actorIsOwner
        ? String(body.party_mode ?? room.party_mode ?? "Friends-making Party").trim()
        : String(room.party_mode ?? "Friends-making Party");
      const partyMode = requestedPartyMode === "Event hosting mode" ? "Event hosting mode" : "Friends-making Party";
      const requestedRoomMode = actorIsOwner
        ? String(body.room_mode ?? room.room_mode ?? "voice").trim().toLowerCase()
        : String(room.room_mode ?? "voice").trim().toLowerCase();
      const allowedRoomModes = new Set(["voice", "game", "live"]);
      if (!allowedRoomModes.has(requestedRoomMode)) {
        return json({ ok: false, error: "invalid_room_mode" }, { status: 400 });
      }
      const roomMode = requestedRoomMode;
      const allowedSeatThemes = new Set(["royal-gold", "neon-blue", "rose-glow"]);
      const seatThemeId = actorIsOwner
        ? String(body.seat_theme_id ?? room.seat_theme_id ?? "royal-gold")
        : String(room.seat_theme_id ?? "royal-gold");
      if (!allowedSeatThemes.has(seatThemeId)) {
        return json({ ok: false, error: "invalid_seat_theme" }, { status: 400 });
      }
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
          "INSERT INTO room_settings (room_id, announcement, theme_id, group_pk_enabled, welcome_image_key, party_mode, room_mode, seat_theme_id, lock_password_hash, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(room_id) DO UPDATE SET announcement = excluded.announcement, theme_id = excluded.theme_id, group_pk_enabled = excluded.group_pk_enabled, welcome_image_key = excluded.welcome_image_key, party_mode = excluded.party_mode, room_mode = excluded.room_mode, seat_theme_id = excluded.seat_theme_id, lock_password_hash = excluded.lock_password_hash, updated_at = excluded.updated_at"
        ).bind(roomId, announcement, themeId, groupPkEnabled, welcomeImageKey, partyMode, roomMode, seatThemeId, lockPasswordHash, ts),
      ]);
      return json({ ok: true, settings: { ...room, name, seat_count: seatCount, locked, announcement, theme_id: themeId, group_pk_enabled: groupPkEnabled, welcome_image_key: welcomeImageKey, party_mode: partyMode, room_mode: roomMode, seat_theme_id: seatThemeId, lock_password_set: lockPasswordHash ? 1 : 0 } });
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
    let roomCreation = await ownerSetting(db, "feature.room_creation", { enabled: true });
    if (roomCreation.enabled === false) {
      await db.prepare(
        "CREATE TABLE IF NOT EXISTS app_migrations (id TEXT PRIMARY KEY, applied_at INTEGER NOT NULL)"
      ).run();
      const repairId = "20261013_room_creation_repair";
      const alreadyRepaired = await db.prepare(
        "SELECT 1 AS applied FROM app_migrations WHERE id = ? LIMIT 1"
      ).bind(repairId).first();
      if (!alreadyRepaired) {
        const repairTs = now();
        await db.batch([
          db.prepare(
            "UPDATE owner_settings SET value_json = ?, updated_at = ? WHERE key = ?"
          ).bind(JSON.stringify({ enabled: true }), repairTs, "feature.room_creation"),
          db.prepare(
            "INSERT OR IGNORE INTO app_migrations (id, applied_at) VALUES (?, ?)"
          ).bind(repairId, repairTs),
        ]);
        roomCreation = { enabled: true };
      }
    }
    if (roomCreation.enabled === false) return json({ ok: false, error: "room_creation_disabled" }, { status: 403 });
    const body = await bodyJson(request);
    const ownerId = String(body.owner_user_id ?? "").trim();
    const name = String(body.name ?? "").trim().slice(0, 80);
    const authError = await requireSession(request, env, ownerId);
    if (authError) return authError;
    const requestedSeatCount = Number(body.seat_count ?? 12);
    const requestedPartyMode = String(body.party_mode ?? "Friends-making Party").trim();
    const partyMode = requestedPartyMode === "Event hosting mode" ? "Event hosting mode" : "Friends-making Party";
    const requestedRoomMode = String(body.room_mode ?? "voice").trim().toLowerCase();
    if (!new Set(["voice", "live"]).has(requestedRoomMode)) {
      return json({ ok: false, error: "invalid_create_room_mode" }, { status: 400 });
    }
    const roomMode = requestedRoomMode;
    if (!ownerId || !name) return json({ ok: false, error: "owner_and_name_required" }, { status: 400 });
    if (!Number.isSafeInteger(requestedSeatCount) || requestedSeatCount < 8 || requestedSeatCount > 42) {
      return json({ ok: false, error: "invalid_seat_count" }, { status: 400 });
    }

    await ensureUser(db, ownerId, String(body.owner_name ?? "DarkVibeX User"));
    await ensureUserAllowed(db, ownerId);
    await ensureRoomSettingsTable(db);

    const seatCount = requestedSeatCount;
    const requestedRoomId = String(body.id ?? "").trim();
    let roomId = requestedRoomId;
    if (roomId) {
      const existing = await db.prepare("SELECT 1 AS found FROM rooms WHERE id = ? LIMIT 1").bind(roomId).first();
      if (existing) return json({ ok: false, error: "room_id_taken" }, { status: 409 });
    } else {
      for (let attempt = 0; attempt < 8; attempt += 1) {
        const candidate = String(Math.floor(100000 + Math.random() * 900000));
        const existing = await db.prepare("SELECT 1 AS found FROM rooms WHERE id = ? LIMIT 1").bind(candidate).first();
        if (!existing) {
          roomId = candidate;
          break;
        }
      }
      if (!roomId) return json({ ok: false, error: "room_id_unavailable" }, { status: 503 });
    }

    const ts = now();
    try {
      await db.batch([
        db.prepare(
          "INSERT INTO rooms (id, owner_user_id, name, seat_count, locked, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)"
        ).bind(roomId, ownerId, name, seatCount, ts, ts),
        db.prepare(
          "INSERT INTO room_settings (room_id, announcement, theme_id, group_pk_enabled, welcome_image_key, party_mode, room_mode, seat_theme_id, lock_password_hash, updated_at) VALUES (?, '', 'dark', 0, '', ?, ?, 'royal-gold', '', ?) ON CONFLICT(room_id) DO UPDATE SET party_mode = excluded.party_mode, room_mode = excluded.room_mode, updated_at = excluded.updated_at"
        ).bind(roomId, partyMode, roomMode, ts),
        db.prepare(
          "INSERT OR REPLACE INTO room_members (room_id, user_id, seat_index, mic_muted, joined_at, updated_at) VALUES (?, ?, NULL, 1, ?, ?)"
        ).bind(roomId, ownerId, ts, ts),
      ]);
    } catch (error) {
      console.error("Room creation storage failed", {
        ownerId,
        roomId,
        seatCount,
        roomMode,
        error: String(error?.message ?? error),
      });
      return json({ ok: false, error: "room_create_storage_failed" }, { status: 503 });
    }
    return json({ ok: true, room_id: roomId, party_mode: partyMode, room_mode: roomMode }, { status: 201 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "delete" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const room = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    if (String(room.owner_user_id) !== userId) {
      return json({ ok: false, error: "room_owner_required" }, { status: 403 });
    }
    await db.batch([
      db.prepare("DELETE FROM room_members WHERE room_id = ?").bind(roomId),
      db.prepare("DELETE FROM room_settings WHERE room_id = ?").bind(roomId),
      db.prepare("DELETE FROM rooms WHERE id = ?").bind(roomId),
    ]);
    return json({ ok: true });
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
    await ensureRoomSettingsTable(db);
    const roomAccess = await db.prepare(
      `SELECT r.owner_user_id,r.locked,COALESCE(s.lock_password_hash,'') AS lock_password_hash
         FROM rooms r
         LEFT JOIN room_settings s ON s.room_id=r.id
        WHERE r.id=?`
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
      const expectedHash = String(roomAccess.lock_password_hash ?? "");
      const suppliedPassword = String(body.password ?? "").trim().slice(0, 64);
      if (!expectedHash) {
        return json({ ok: false, error: "room_locked" }, { status: 403 });
      }
      if (!suppliedPassword) {
        return json({ ok: false, error: "room_password_required" }, { status: 403 });
      }
      const suppliedHash = await sha256Hex(suppliedPassword);
      if (suppliedHash !== expectedHash) {
        return json({ ok: false, error: "room_password_invalid" }, { status: 403 });
      }
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
    await ensureRoomControlTables(db, roomId);
    const room = await db.prepare("SELECT seat_count,owner_user_id FROM rooms WHERE id = ?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    const member = await db.prepare("SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?")
      .bind(roomId, userId).first();
    if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    if (seatIndex != null && (!Number.isSafeInteger(seatIndex) || seatIndex < 0 || seatIndex >= Number(room.seat_count))) {
      return json({ ok: false, error: "invalid_seat_index" }, { status: 400 });
    }
    const stayingOnSameSeat =
      seatIndex != null && Number(member.seat_index) === seatIndex;
    if (seatIndex != null) {
      const seatControl = await db.prepare(
        "SELECT locked,room_muted FROM room_seat_controls WHERE room_id=? AND seat_index=?"
      ).bind(roomId,seatIndex).first();
      if (Number(seatControl?.locked ?? 0) === 1 && !stayingOnSameSeat) {
        return json({ ok:false,error:"seat_locked" }, { status:409 });
      }
      const moderator = await roomModeratorState(db, roomId, userId);
      const roomSettings = await db.prepare(
        "SELECT COALESCE(mic_mode,'free') AS mic_mode FROM room_settings WHERE room_id=?"
      ).bind(roomId).first();
      if ((roomSettings?.mic_mode ?? "free") === "apply" && !stayingOnSameSeat && !moderator.isOwner && !moderator.isAdmin) {
        return json({ ok:false,error:"seat_request_required" }, { status:403 });
      }
      if (Number(seatControl?.room_muted ?? 0) === 1) {
        // Room moderation mute overrides a user's local unmute request.
        body.mic_muted = true;
      }
    }
    const effectiveMuted = body.mic_muted === false ? 0 : 1;
    await sampleLampMicProgress(db, roomId, now());
    const result = await db.prepare(
      `UPDATE room_members
          SET seat_index = ?, mic_muted = ?, updated_at = ?
        WHERE room_id = ? AND user_id = ?
          AND (? IS NULL OR NOT EXISTS (
            SELECT 1 FROM room_members other
             WHERE other.room_id = ? AND other.seat_index = ? AND other.user_id <> ?
          ))`
    ).bind(seatIndex, effectiveMuted, now(), roomId, userId, seatIndex, roomId, seatIndex, userId).run();
    if (Number(result.meta?.changes ?? 0) === 0) {
      const occupied = seatIndex == null ? null : await db.prepare(
        "SELECT 1 AS occupied FROM room_members WHERE room_id = ? AND seat_index = ? AND user_id <> ?"
      ).bind(roomId, seatIndex, userId).first();
      if (occupied) return json({ ok: false, error: "seat_occupied" }, { status: 409 });
      return json({ ok: false, error: "room_membership_required" }, { status: 403 });
    }
    if (seatIndex != null) await acceptPendingLampMicInvite(db, roomId, userId, now());
    return json({ ok: true, seat_index: seatIndex, mic_muted: Boolean(effectiveMuted) });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "gift-ranking" && request.method === "GET") {
    const roomId = parts[2];
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const member = await db.prepare(
      "SELECT 1 AS active FROM room_members WHERE room_id=? AND user_id=?"
    ).bind(roomId, String(session.sub)).first();
    if (!member) return json({ ok:false,error:"room_membership_required" }, { status:403 });
    const total = await db.prepare(
      "SELECT COALESCE(SUM(coin_cost),0) AS lifetime_total FROM gift_events WHERE room_id=?"
    ).bind(roomId).first();
    const ranking = await db.prepare(
      `SELECT g.sender_user_id AS user_id,
              COALESCE(u.display_name,'User') AS display_name,
              u.avatar_key,
              SUM(g.coin_cost) AS sent_coins,
              COUNT(*) AS gift_count
         FROM gift_events g
         LEFT JOIN users u ON u.id=g.sender_user_id
        WHERE g.room_id=?
        GROUP BY g.sender_user_id,u.display_name,u.avatar_key
        ORDER BY sent_coins DESC,gift_count DESC
        LIMIT 20`
    ).bind(roomId).all();
    return json({
      ok:true,
      lifetime_total:Number(total?.lifetime_total ?? 0),
      ranking:ranking.results ?? [],
    });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "messages") {
    const messagesFeature = await ownerSetting(db, "feature.messages", { enabled: true });
    if (messagesFeature.enabled === false) return json({ ok: false, error: "messages_disabled" }, { status: 403 });
    const roomId = parts[2];
    if (request.method === "GET") {
      await ensureVipSchema(db);
      await ensureImageTables(db);
      await ensureCosmeticsSchema(db);
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
                m.text, m.created_at, mi.image_key,
                (SELECT p.item_id FROM user_props p
                  WHERE p.user_id=m.user_id AND p.kind='bubble'
                    AND p.active=1 AND p.expires_at>?
                  LIMIT 1) AS active_bubble_id
           FROM room_messages m
           LEFT JOIN users u ON u.id = m.user_id
           LEFT JOIN user_vip v ON v.user_id = m.user_id
           LEFT JOIN room_message_images mi ON mi.message_id = m.id
          WHERE m.room_id = ?
          ORDER BY m.created_at DESC LIMIT 100`
      ).bind(now(), now(), roomId).all();
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
      await ensureRoomControlTables(db, roomId);
      const chatBan = await db.prepare(
        "SELECT 1 AS banned FROM room_chat_bans WHERE room_id=? AND user_id=?"
      ).bind(roomId,userId).first();
      if (chatBan) return json({ ok:false,error:"room_chat_banned" }, { status:403 });
      const roomControl = await db.prepare(
        "SELECT COALESCE(public_screen_enabled,1) AS public_screen_enabled FROM room_settings WHERE room_id=?"
      ).bind(roomId).first();
      if (Number(roomControl?.public_screen_enabled ?? 1) !== 1) {
        const mod = await roomModeratorState(db, roomId, userId);
        if (!mod.isOwner && !mod.isAdmin) {
          return json({ ok:false,error:"public_screen_owner_admin_only" }, { status:403 });
        }
      }
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
      await ensureRoomControlTables(db, roomId);
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
                CASE WHEN v.custom_id IS NOT NULL
                           AND (v.custom_id_expires_at IS NULL OR v.custom_id_expires_at > ?)
                     THEN v.custom_id ELSE m.user_id END AS public_id,
                (SELECT c.item_id FROM user_cosmetics c WHERE c.user_id = m.user_id AND c.kind = 'frame' AND c.active = 1 AND c.expires_at > ? LIMIT 1) AS active_frame_id,
                (SELECT c.item_id FROM user_cosmetics c WHERE c.user_id = m.user_id AND c.kind = 'vehicle' AND c.active = 1 AND c.expires_at > ? LIMIT 1) AS active_vehicle_id,
                (SELECT p.item_id FROM user_props p WHERE p.user_id = m.user_id AND p.kind = 'entry' AND p.active = 1 AND p.expires_at > ? LIMIT 1) AS active_entry_id,
                (SELECT p.item_id FROM user_props p WHERE p.user_id = m.user_id AND p.kind = 'bubble' AND p.active = 1 AND p.expires_at > ? LIMIT 1) AS active_bubble_id,
                (SELECT p.item_id FROM user_props p WHERE p.user_id = m.user_id AND p.kind = 'profile_card' AND p.active = 1 AND p.expires_at > ? LIMIT 1) AS active_profile_card_id,
                m.seat_index, m.mic_muted, m.joined_at, m.updated_at,
                CASE WHEN r.owner_user_id = m.user_id THEN 1 ELSE 0 END AS is_owner,
                CASE WHEN ra.user_id IS NULL THEN 0 ELSE 1 END AS is_admin,
                CASE WHEN cb.user_id IS NULL THEN 0 ELSE 1 END AS chat_banned
           FROM room_members m
           LEFT JOIN users u ON u.id = m.user_id
           LEFT JOIN user_vip v ON v.user_id = m.user_id
           LEFT JOIN rooms r ON r.id = m.room_id
           LEFT JOIN room_admins ra ON ra.room_id = m.room_id AND ra.user_id = m.user_id
           LEFT JOIN room_chat_bans cb ON cb.room_id = m.room_id AND cb.user_id = m.user_id
          WHERE m.room_id = ?
          ORDER BY CASE WHEN r.owner_user_id = m.user_id THEN 0 WHEN ra.user_id IS NOT NULL THEN 1 ELSE 2 END,
                   active_vip_level DESC,
                   CASE WHEN m.seat_index IS NULL THEN 1 ELSE 0 END, m.seat_index ASC, m.joined_at ASC
          LIMIT 200`
      ).bind(now(), now(), now(), now(), now(), now(), now(), now(), roomId).all();
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

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "blacklist") {
    const roomId = parts[2];
    await ensureRoomSafetyTables(db);
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const actorId = String(session.sub);
    const mod = await roomModeratorState(db, roomId, actorId);
    if (!mod.room) return json({ ok:false,error:"room_not_found" }, { status:404 });
    if (!mod.isOwner && !mod.isAdmin) {
      return json({ ok:false,error:"room_moderator_required" }, { status:403 });
    }
    if (request.method === "GET") {
      const rows = await db.prepare(
        `SELECT b.user_id,b.banned_by,b.created_at,
                COALESCE(u.display_name,'User') AS display_name,
                u.avatar_key
           FROM room_bans b
           LEFT JOIN users u ON u.id=b.user_id
          WHERE b.room_id=?
          ORDER BY b.created_at DESC
          LIMIT 200`
      ).bind(roomId).all();
      return json({ ok:true,blacklist:rows.results ?? [] });
    }
    if (request.method === "POST") {
      const body = await bodyJson(request);
      const targetId = String(body.target_user_id ?? "").trim();
      if (!targetId) return json({ ok:false,error:"target_required" }, { status:400 });
      const targetRole = await roomModeratorState(db, roomId, targetId);
      if (targetRole.isOwner || (!mod.isOwner && targetRole.isAdmin)) {
        return json({ ok:false,error:"moderation_target_protected" }, { status:403 });
      }
      await db.prepare("DELETE FROM room_bans WHERE room_id=? AND user_id=?")
        .bind(roomId,targetId).run();
      return json({ ok:true,target_user_id:targetId });
    }
    return json({ ok:false,error:"method_not_allowed" }, { status:405 });
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

  if (url.pathname === "/api/custom-gifts" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId || undefined);
    if (authError) return authError;
    await ensureCustomGiftSchema(db);
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const actor = String(session.sub);
    const rows = await db.prepare(
      `SELECT id,user_id,name,asset_key,coin_cost,status,created_at,updated_at
         FROM custom_gifts
        WHERE user_id=? OR status='approved'
        ORDER BY CASE WHEN user_id=? THEN 0 ELSE 1 END, updated_at DESC
        LIMIT 200`
    ).bind(actor, actor).all();
    return json({ ok: true, gifts: rows.results ?? [] });
  }

  if (url.pathname === "/api/custom-gifts" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureUserAllowed(db, userId);
    await ensureCustomGiftSchema(db);
    const name = String(body.name ?? "").trim().slice(0, 40);
    const assetKey = String(body.asset_key ?? "").trim();
    const coinCost = Math.max(100, Math.min(10000000, Math.trunc(Number(body.coin_cost ?? 5000))));
    if (!name || !assetKey.startsWith(`custom-gifts/${userId}/`) ||
        !/\.(jpg|jpeg|png|webp|mp4)$/i.test(assetKey) ||
        !Number.isSafeInteger(coinCost)) {
      return json({ ok: false, error: "invalid_custom_gift" }, { status: 400 });
    }
    const giftId = "custom-" + id();
    const ts = now();
    await db.prepare(
      "INSERT INTO custom_gifts (id,user_id,name,asset_key,coin_cost,status,created_at,updated_at) VALUES (?,?,?,?,?,'approved',?,?)"
    ).bind(giftId, userId, name, assetKey, coinCost, ts, ts).run();
    return json({
      ok: true,
      gift: {
        id: giftId,
        user_id: userId,
        name,
        asset_key: assetKey,
        coin_cost: coinCost,
        status: "approved",
        category: "custom",
      },
    }, { status: 201 });
  }

  if (url.pathname === "/api/recharge-providers" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const rows = await db.prepare(
      `SELECT u.id,u.display_name,u.avatar_key,u.role
         FROM users u
        WHERE u.role IN ('coin_seller','merchant')
        ORDER BY CASE u.role WHEN 'coin_seller' THEN 0 ELSE 1 END,
                 u.updated_at DESC
        LIMIT 200`
    ).all();
    return json({
      ok: true,
      providers: (rows.results ?? []).map((row) => ({
        user_id: row.id,
        display_name: row.display_name,
        avatar_key: row.avatar_key,
        role: row.role,
      })),
    });
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
    if (await usersBlockedEitherWay(db, sender, receiver)) {
      return json({ ok:false,error:"blocked_user" }, { status:403 });
    }
    await ensureTinniSocialSchema(db);
    const mutualFriend = await db.prepare(
      `SELECT
         EXISTS(SELECT 1 FROM user_follows WHERE follower_id=? AND target_id=?) AS a,
         EXISTS(SELECT 1 FROM user_follows WHERE follower_id=? AND target_id=?) AS b`
    ).bind(sender,receiver,receiver,sender).first();
    if (Number(mutualFriend?.a ?? 0) !== 1 ||
        Number(mutualFriend?.b ?? 0) !== 1) {
      return json({ ok:false,error:"friends_required" }, { status:403 });
    }
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
    await ensureCosmeticsSchema(db);
    const vip = await getVipStatus(db, userId, now());
    const retentionDays = vip.active ? Number(vip.message_retention_days ?? 0) : 0;
    const cutoff = retentionDays > 0 ? now() - retentionDays * 86400000 : 0;
    const rows = await db.prepare(
      `SELECT m.id, m.sender_user_id, m.receiver_user_id, m.text, m.created_at, m.read_at,
              i.image_key,
              (SELECT p.item_id FROM user_props p
                WHERE p.user_id=m.sender_user_id AND p.kind='bubble'
                  AND p.active=1 AND p.expires_at>?
                LIMIT 1) AS active_bubble_id
         FROM direct_messages m
         LEFT JOIN direct_message_images i ON i.message_id = m.id
        WHERE ((m.sender_user_id = ? AND m.receiver_user_id = ?)
           OR (m.sender_user_id = ? AND m.receiver_user_id = ?))
          AND (? = 0 OR m.created_at >= ?)
        ORDER BY m.created_at DESC
        LIMIT ?`
    ).bind(now(), userId, otherId, otherId, userId, cutoff, cutoff, retentionDays > 0 ? 2000 : 20).all();
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

  if (url.pathname === "/api/wallet/coins/history" && request.method === "GET") {
    const userId=String(url.searchParams.get("user_id") ?? "").trim();
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    const user=await ensureUser(db,userId);
    const gifts=await db.prepare(
      `SELECT g.id,g.gift_id,
              COALESCE(u.display_name,g.receiver_user_id) AS receiver_name,
              g.receiver_user_id,g.coin_cost AS coins,g.created_at
         FROM gift_events g
         LEFT JOIN users u ON u.id=g.receiver_user_id
        WHERE g.sender_user_id=?
        ORDER BY g.created_at DESC LIMIT 200`
    ).bind(userId).all();
    const sellerReceived=await db.prepare(
      `SELECT l.id,l.kind,l.amount AS coins,l.reference_id,l.created_at,
              CASE WHEN l.kind='merchant_received' THEN 'merchant' ELSE 'coin_seller' END AS wallet_type
         FROM wallet_ledger l
        WHERE l.user_id=? AND l.kind IN ('coin_seller_received','merchant_received')
        ORDER BY l.created_at DESC LIMIT 200`
    ).bind(userId).all();
    return json({
      ok:true,
      current_coins:Number(user?.coins ?? 0),
      gifts:gifts.results ?? [],
      seller_received:sellerReceived.results ?? [],
    });
  }

  if (url.pathname === "/api/wallet/diamonds/history" && request.method === "GET") {
    const userId=String(url.searchParams.get("user_id") ?? "").trim();
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    await ensureDiamondConversionTable(db);
    const user=await ensureUser(db,userId);
    const gifts=await db.prepare(
      `SELECT g.id,g.gift_id,
              COALESCE(u.display_name,g.sender_user_id) AS sender_name,
              g.sender_user_id,g.coin_cost AS diamonds,g.created_at
         FROM gift_events g
         LEFT JOIN users u ON u.id=g.sender_user_id
        WHERE g.receiver_user_id=?
        ORDER BY g.created_at DESC LIMIT 200`
    ).bind(userId).all();
    const conversions=await db.prepare(
      "SELECT id,diamonds,coins,rate,created_at FROM diamond_conversions WHERE user_id=? ORDER BY created_at DESC LIMIT 200"
    ).bind(userId).all();
    return json({
      ok:true,
      current_diamonds:Number(user?.diamonds ?? 0),
      gifts:gifts.results ?? [],
      conversions:conversions.results ?? [],
    });
  }

  if (url.pathname === "/api/wallet/diamonds/convert" && request.method === "POST") {
    const body=await bodyJson(request);
    const userId=String(body.user_id ?? "").trim();
    const diamonds=Number(body.diamonds ?? 0);
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    if(!Number.isSafeInteger(diamonds)||diamonds<=0){
      return json({ok:false,error:"invalid_diamond_amount"},{status:400});
    }
    await ensureDiamondConversionTable(db);
    const user=await ensureUser(db,userId);
    if(Number(user?.diamonds ?? 0)<diamonds){
      return json({ok:false,error:"insufficient_diamonds"},{status:409});
    }
    const policy=await ownerSetting(
      db,
      "economy.diamond_conversion",
      {coins_per_diamond:1},
    );
    const rate=Math.max(0,Number(policy?.coins_per_diamond ?? 1));
    const coins=Math.floor(diamonds*rate);
    if(!Number.isSafeInteger(coins)||coins<0){
      return json({ok:false,error:"invalid_conversion_policy"},{status:500});
    }
    const nextDiamonds=Number(user.diamonds)-diamonds;
    const nextCoins=Number(user.coins ?? 0)+coins;
    const conversionId=id();
    const ts=now();
    await db.batch([
      db.prepare("UPDATE users SET diamonds=?,coins=?,updated_at=? WHERE id=?")
        .bind(nextDiamonds,nextCoins,ts,userId),
      db.prepare(
        "INSERT INTO diamond_conversions(id,user_id,diamonds,coins,rate,created_at) VALUES(?,?,?,?,?,?)"
      ).bind(conversionId,userId,diamonds,coins,rate,ts),
      db.prepare(
        "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
      ).bind(id(),userId,"diamond_conversion",coins,nextCoins,conversionId,ts),
    ]);
    return json({
      ok:true,
      conversion_id:conversionId,
      diamonds,
      coins,
      current_diamonds:nextDiamonds,
      current_coins:nextCoins,
      rate,
    });
  }

  if (url.pathname === "/api/wallet/role-detail" && request.method === "GET") {
    const userId=String(url.searchParams.get("user_id") ?? "").trim();
    const walletType=String(url.searchParams.get("wallet_type") ?? "").trim();
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    try{
      return json({
        ok:true,
        wallet:await roleWalletDetail(db,userId,walletType,200,now()),
      });
    }catch(error){
      const code=String(error?.message ?? error);
      return json({ok:false,error:code},{status:code.endsWith("_role_required")?403:400});
    }
  }

  if (url.pathname === "/api/wallet/role-credential" && request.method === "POST") {
    const body=await bodyJson(request);
    const userId=String(body.user_id ?? "").trim();
    const walletType=String(body.wallet_type ?? "").trim();
    const credential=String(body.credential ?? "");
    const oldCredential=String(body.old_credential ?? "");
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    const valid=walletType==="coin_seller"
      ? /^\d{4}$/.test(credential)
      : credential.length>=6 && credential.length<=32;
    if(!valid){
      return json({
        ok:false,
        error:walletType==="coin_seller"
          ?"coin_seller_pin_must_be_4_digits"
          :"merchant_credential_invalid",
      },{status:400});
    }
    try{
      const detail=await roleWalletDetail(db,userId,walletType,1,now());
      if(detail.credential_set){
        if(!oldCredential) return json({ok:false,error:"old_credential_required"},{status:403});
        const oldHash=await sha256Hex(
          String(env.SESSION_SECRET ?? "")+"|"+userId+"|"+walletType+"|"+oldCredential
        );
        await verifyRoleWalletCredential(db,userId,walletType,oldHash,now());
      }
      const hash=await sha256Hex(
        String(env.SESSION_SECRET ?? "")+"|"+userId+"|"+walletType+"|"+credential
      );
      await setRoleWalletCredential(db,userId,walletType,hash,now());
      return json({ok:true,wallet_type:walletType});
    }catch(error){
      const code=String(error?.message ?? error);
      return json({ok:false,error:code},{status:403});
    }
  }

  if (url.pathname === "/api/wallet/role-coins/transfer" && request.method === "POST") {
    const body=await bodyJson(request);
    const userId=String(body.user_id ?? "").trim();
    const receiverId=String(body.receiver_user_id ?? "").trim();
    const walletType=String(body.wallet_type ?? "").trim();
    const credential=String(body.credential ?? "");
    const amount=Number(body.coins ?? 0);
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    await ensureUserAllowed(db,userId);
    await ensureUserAllowed(db,receiverId);
    const hash=await sha256Hex(
      String(env.SESSION_SECRET ?? "")+"|"+userId+"|"+walletType+"|"+credential
    );
    try{
      const result=await transferRoleCoins(db,{
        senderUserId:userId,
        walletType,
        receiverUserId:receiverId,
        coins:amount,
        credentialHash:hash,
        ts:now(),
      });
      let vipAward=null;
      if(walletType==="coin_seller"){
        vipAward=await awardSellerVipExp(db,receiverId,amount,now());
      }
      return json({ok:true,...result,vip_award:vipAward});
    }catch(error){
      const code=String(error?.message ?? error);
      const status=["invalid_wallet_credential","wallet_credential_not_set"].includes(code)?403:400;
      return json({ok:false,error:code},{status});
    }
  }

  if (url.pathname === "/api/wallet/role-dollars/withdraw" && request.method === "POST") {
    const body=await bodyJson(request);
    const userId=String(body.user_id ?? "").trim();
    const walletType=String(body.wallet_type ?? "").trim();
    const credential=String(body.credential ?? "");
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    const hash=await sha256Hex(
      String(env.SESSION_SECRET ?? "")+"|"+userId+"|"+walletType+"|"+credential
    );
    try{
      const result=await requestRoleDollarWithdrawal(db,{
        userId,
        walletType,
        destinationType:String(body.destination_type ?? ""),
        destinationValue:String(body.destination_value ?? ""),
        amountUsdCents:Number(body.amount_usd_cents ?? 0),
        credentialHash:hash,
        ts:now(),
      });
      return json({ok:true,...result});
    }catch(error){
      const code=String(error?.message ?? error);
      return json({ok:false,error:code},{status:400});
    }
  }

  if (url.pathname === "/api/wallet/coin-seller-transfer" && request.method === "POST") {
    const body=await bodyJson(request);
    const sellerId=String(body.seller_user_id ?? "").trim();
    const receiverId=String(body.receiver_user_id ?? "").trim();
    const pin=String(body.pin ?? "");
    const authError=await requireSession(request,env,sellerId);
    if(authError) return authError;
    if(!/^\d{4}$/.test(pin)){
      return json({ok:false,error:"coin_seller_pin_required"},{status:403});
    }
    const hash=await sha256Hex(
      String(env.SESSION_SECRET ?? "")+"|"+sellerId+"|coin_seller|"+pin
    );
    try{
      const result=await transferRoleCoins(db,{
        senderUserId:sellerId,
        walletType:"coin_seller",
        receiverUserId:receiverId,
        coins:Number(body.coins ?? 0),
        credentialHash:hash,
        ts:now(),
      });
      const vipAward=await awardSellerVipExp(db,receiverId,Number(body.coins ?? 0),now());
      return json({ok:true,...result,vip_award:vipAward});
    }catch(error){
      const code=String(error?.message ?? error);
      return json({ok:false,error:code},{status:400});
    }
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

  if (url.pathname === "/api/call-verifications/status" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureCallVerificationSchema(db);
    const user = await db.prepare(
      "SELECT gender,call_verified,call_verification_status,call_verified_at,call_verification_revoked_at FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    const latest = await db.prepare(
      "SELECT id,status,system_passed,created_at,reviewed_at,review_note FROM call_verification_submissions WHERE user_id=? ORDER BY created_at DESC LIMIT 1"
    ).bind(userId).first();
    return json({
      ok: true,
      verification: {
        gender: String(user?.gender ?? ""),
        verified: Number(user?.call_verified ?? 0) === 1,
        status: String(user?.call_verification_status ?? "unverified"),
        verified_at: user?.call_verified_at ?? null,
        revoked_at: user?.call_verification_revoked_at ?? null,
        latest_submission: latest ?? null,
      },
    });
  }

  if (url.pathname === "/api/call-verifications" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const gender = String(body.gender ?? "").trim().toLowerCase();
    const photos = Array.isArray(body.photo_keys)
      ? body.photo_keys.map((value) => String(value ?? "").trim()).filter(Boolean)
      : [];
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!["male", "female"].includes(gender)) {
      return json({ ok: false, error: "gender_required" }, { status: 400 });
    }
    if (photos.length !== 3 ||
        photos.some((key) =>
          !key.startsWith(`call-verifications/${userId}/`) ||
          !/\.(jpg|jpeg|png|webp)$/i.test(key))) {
      return json({ ok: false, error: "three_live_photos_required" }, { status: 400 });
    }
    await ensureCallVerificationSchema(db);
    const current = await db.prepare(
      "SELECT call_verified FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    if (Number(current?.call_verified ?? 0) === 1) {
      return json({ ok: true, already_verified: true, status: "verified" });
    }
    const submissionId = "verify-" + id();
    const ts = now();
    const systemPassed = body.system_passed === true ? 1 : 0;
    await db.batch([
      db.prepare(
        `INSERT INTO call_verification_submissions
          (id,user_id,status,system_passed,photo_front_key,photo_left_key,photo_right_key,created_at,reviewed_at,review_note)
         VALUES (?,?,'pending_owner',?,?,?,?,?,NULL,NULL)`
      ).bind(
        submissionId,
        userId,
        systemPassed,
        photos[0],
        photos[1],
        photos[2],
        ts,
      ),
      db.prepare(
        "UPDATE users SET gender=?,call_verified=0,call_verification_status='pending_owner',updated_at=? WHERE id=?"
      ).bind(gender, ts, userId),
    ]);
    return json({
      ok: true,
      already_verified: false,
      submission_id: submissionId,
      status: "pending_owner",
      system_passed: systemPassed === 1,
    }, { status: 201 });
  }

  if (url.pathname === "/api/calls/random" && request.method === "POST") {
    const body = await bodyJson(request);
    const callerId = String(body.user_id ?? "").trim();
    const gender = String(body.gender ?? "").trim().toLowerCase();
    const authError = await requireSession(request, env, callerId);
    if (authError) return authError;
    if (!["female", "male"].includes(gender)) {
      return json({ ok: false, error: "invalid_gender" }, { status: 400 });
    }
    await ensureDirectCallTable(db);
    await ensureCallVerificationSchema(db);
    await expireDirectCalls(db);
    const caller = await db.prepare(
      "SELECT coins FROM users WHERE id=? LIMIT 1"
    ).bind(callerId).first();
    const randomCost = 500000;
    if (Number(caller?.coins ?? 0) < randomCost) {
      return json(
        { ok: false, error: "insufficient_coins", required_coins: randomCost },
        { status: 409 },
      );
    }
    const candidates = await db.prepare(
      `SELECT u.id,u.display_name,u.avatar_key,u.gender,
              COALESCE(s.offers,0) AS offers,
              COALESCE(s.answered,0) AS answered,
              COALESCE(s.completed_calls,0) AS completed_calls,
              COALESCE(s.total_minutes,0) AS total_minutes,
              COALESCE(s.last_offer_at,0) AS last_offer_at
         FROM users u
         LEFT JOIN random_call_stats s ON s.user_id=u.id
        WHERE u.id<>?
          AND u.call_verified=1
          AND lower(u.gender)=?
          AND NOT EXISTS(
            SELECT 1 FROM direct_calls c
             WHERE c.state IN ('ringing','active')
               AND (c.caller_user_id=u.id OR c.receiver_user_id=u.id)
          )
        ORDER BY
          (COALESCE(s.completed_calls,0)*100 +
           COALESCE(s.answered,0)*20 +
           COALESCE(s.total_minutes,0)) DESC,
          COALESCE(s.last_offer_at,0) ASC
        LIMIT 30`
    ).bind(callerId, gender).all();

    let candidate = null;
    for (const row of candidates.results ?? []) {
      if (!(await usersBlockedEitherWay(db, callerId, String(row.id)))) {
        candidate = row;
        break;
      }
    }
    if (!candidate) {
      return json({
        ok: false,
        error: gender === "female"
          ? "no_verified_available_girl"
          : "no_verified_available_boy",
      }, { status: 404 });
    }

    const receiverId = String(candidate.id);
    const receiverReward = gender === "female" ? 400000 : 0;
    const callId = id();
    const ts = now();
    await db.batch([
      db.prepare(
        `INSERT INTO direct_calls
          (id,caller_user_id,receiver_user_id,state,created_at,answered_at,ended_at,updated_at,
           call_kind,cost_coins_per_minute,receiver_diamonds_per_minute,
           receiver_earning_eligible,billed_minutes,caller_cost_coins,receiver_reward_diamonds)
         VALUES (?,?,?,'ringing',?,NULL,NULL?,'random',?,?,?,0,0,0)`
      ),
    ]);
    await db.prepare(
      `INSERT INTO direct_calls
        (id,caller_user_id,receiver_user_id,state,created_at,answered_at,ended_at,updated_at,
         call_kind,cost_coins_per_minute,receiver_diamonds_per_minute,
         receiver_earning_eligible,billed_minutes,caller_cost_coins,receiver_reward_diamonds)
       VALUES (?,?,?,'ringing',?,NULL,NULL,?,'random',?,?,?,0,0,0)`
    ).bind(
      callId,
      callerId,
      receiverId,
      ts,
      ts,
      randomCost,
      receiverReward,
      gender === "female" ? 1 : 0,
    ).run();
    await db.prepare(
      `INSERT INTO random_call_stats
        (user_id,offers,answered,completed_calls,total_minutes,last_offer_at,updated_at)
       VALUES (?,1,0,0,0,?,?)
       ON CONFLICT(user_id) DO UPDATE SET
         offers=offers+1,last_offer_at=excluded.last_offer_at,updated_at=excluded.updated_at`
    ).bind(receiverId, ts, ts).run();
    return json({ ok: true, call: await directCallRow(db, callId) }, { status: 201 });
  }

  if (url.pathname === "/api/calls/start" && request.method === "POST") {
    const body = await bodyJson(request);
    const callerId = String(body.user_id ?? "").trim();
    const receiverId = String(body.receiver_user_id ?? "").trim();
    const authError = await requireSession(request, env, callerId);
    if (authError) return authError;
    if (!receiverId || receiverId === callerId) {
      return json({ ok: false, error: "invalid_call_target" }, { status: 400 });
    }
    await ensureDirectCallTable(db);
    await ensureCallVerificationSchema(db);
    await expireDirectCalls(db);
    if (await usersBlockedEitherWay(db, callerId, receiverId)) {
      return json({ ok:false,error:"blocked_user" }, { status:403 });
    }
    await ensureTinniSocialSchema(db);
    const mutual = await db.prepare(
      `SELECT
         EXISTS(SELECT 1 FROM user_follows WHERE follower_id=? AND target_id=?) AS a,
         EXISTS(SELECT 1 FROM user_follows WHERE follower_id=? AND target_id=?) AS b`
    ).bind(callerId,receiverId,receiverId,callerId).first();
    if (Number(mutual?.a ?? 0) !== 1 || Number(mutual?.b ?? 0) !== 1) {
      return json({ ok: false, error: "friends_required" }, { status: 403 });
    }
    const busy = await db.prepare(
      `SELECT id FROM direct_calls
        WHERE state IN ('ringing','active')
          AND (caller_user_id IN (?,?) OR receiver_user_id IN (?,?))
        LIMIT 1`
    ).bind(callerId,receiverId,callerId,receiverId).first();
    if (busy) return json({ ok: false, error: "user_busy" }, { status: 409 });

    const caller = await db.prepare(
      "SELECT coins FROM users WHERE id=? LIMIT 1"
    ).bind(callerId).first();
    const directCost = 400000;
    if (Number(caller?.coins ?? 0) < directCost) {
      return json(
        { ok: false, error: "insufficient_coins", required_coins: directCost },
        { status: 409 },
      );
    }
    const receiver = await db.prepare(
      "SELECT gender,call_verified FROM users WHERE id=? LIMIT 1"
    ).bind(receiverId).first();
    const femaleVerified =
      String(receiver?.gender ?? "").toLowerCase() === "female" &&
      Number(receiver?.call_verified ?? 0) === 1;
    const receiverReward = femaleVerified ? 320000 : 0;

    const callId = id();
    const createdAt = now();
    await db.prepare(
      `INSERT INTO direct_calls
        (id,caller_user_id,receiver_user_id,state,created_at,answered_at,ended_at,updated_at,
         call_kind,cost_coins_per_minute,receiver_diamonds_per_minute,
         receiver_earning_eligible,billed_minutes,caller_cost_coins,receiver_reward_diamonds)
       VALUES(?,?,?,'ringing',?,NULL,NULL?,'direct',?,?,?,0,0,0)`
    );
    await db.prepare(
      `INSERT INTO direct_calls
        (id,caller_user_id,receiver_user_id,state,created_at,answered_at,ended_at,updated_at,
         call_kind,cost_coins_per_minute,receiver_diamonds_per_minute,
         receiver_earning_eligible,billed_minutes,caller_cost_coins,receiver_reward_diamonds)
       VALUES(?,?,?,'ringing',?,NULL,NULL,?,'direct',?,?,?,0,0,0)`
    ).bind(
      callId,
      callerId,
      receiverId,
      createdAt,
      createdAt,
      directCost,
      receiverReward,
      femaleVerified ? 1 : 0,
    ).run();
    return json({ ok: true, call: await directCallRow(db, callId) }, { status: 201 });
  }

  if (url.pathname === "/api/calls/incoming" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await expireDirectCalls(db);
    const row = await db.prepare(
      `SELECT c.*,
              u.display_name AS caller_name,
              u.avatar_key AS caller_avatar_key
         FROM direct_calls c
         LEFT JOIN users u ON u.id=c.caller_user_id
        WHERE c.receiver_user_id=? AND c.state='ringing'
        ORDER BY c.created_at DESC LIMIT 1`
    ).bind(userId).first();
    return json({ ok: true, call: row ?? null });
  }

  if (url.pathname === "/api/calls/respond" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const callId = String(body.call_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureDirectCallTable(db);
    await ensureCallVerificationSchema(db);
    const call = await db.prepare(
      "SELECT * FROM direct_calls WHERE id=? AND receiver_user_id=? LIMIT 1"
    ).bind(callId,userId).first();
    if (!call) return json({ ok:false,error:"call_not_found" }, { status:404 });
    if (call.state !== "ringing") {
      return json({ ok:false,error:"call_not_ringing" }, { status:409 });
    }
    const accepted = body.accept === true;
    const ts = now();
    await db.prepare(
      accepted
        ? "UPDATE direct_calls SET state='active',answered_at=?,updated_at=? WHERE id=? AND state='ringing'"
        : "UPDATE direct_calls SET state='declined',ended_at=?,updated_at=? WHERE id=? AND state='ringing'"
    ).bind(ts,ts,callId).run();
    if (accepted) {
      if (String(call.call_kind ?? "") === "random") {
        await db.prepare(
          `INSERT INTO random_call_stats
            (user_id,offers,answered,completed_calls,total_minutes,last_offer_at,updated_at)
           VALUES (?,0,1,0,0,NULL,?)
           ON CONFLICT(user_id) DO UPDATE SET
             answered=answered+1,updated_at=excluded.updated_at`
        ).bind(userId, ts).run();
      }
      const billed = await settleDirectCallBilling(db, callId, ts);
      return json({ ok: true, call: billed });
    }
    return json({ ok:true,call:await directCallRow(db,callId) });
  }

  if (url.pathname === "/api/calls/status" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const callId = String(url.searchParams.get("call_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await expireDirectCalls(db);
    let call = await directCallRow(db,callId);
    if (!call || (call.caller_user_id !== userId && call.receiver_user_id !== userId)) {
      return json({ ok:false,error:"call_not_found" }, { status:404 });
    }
    if (call.state === "active") {
      call = await settleDirectCallBilling(db, callId, now());
    }
    return json({ ok:true,call });
  }

  if (url.pathname === "/api/calls/end" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const callId = String(body.call_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureDirectCallTable(db);
    let call = await db.prepare(
      "SELECT * FROM direct_calls WHERE id=? LIMIT 1"
    ).bind(callId).first();
    if (!call || (call.caller_user_id !== userId && call.receiver_user_id !== userId)) {
      return json({ ok:false,error:"call_not_found" }, { status:404 });
    }
    const ts = now();
    if (call.state === "active") {
      await settleDirectCallBilling(db, callId, ts);
      call = await db.prepare(
        "SELECT * FROM direct_calls WHERE id=? LIMIT 1"
      ).bind(callId).first();
    }
    await db.prepare(
      "UPDATE direct_calls SET state='ended',ended_at=?,updated_at=? WHERE id=? AND state IN ('ringing','active')"
    ).bind(ts,ts,callId).run();
    if (String(call?.call_kind ?? "") === "random") {
      await recordRandomCallCompletion(db, callId, ts);
    }
    return json({ ok:true, call:await directCallRow(db,callId) });
  }

  if (url.pathname === "/api/friends" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureTinniSocialSchema(db);
    const vip = await getVipStatus(db, userId, now());
    const friends = await db.prepare(
      `SELECT u.id,u.display_name,u.avatar_key,u.vip_level,
              MAX(a.created_at,b.created_at) AS created_at
         FROM user_follows a
         JOIN user_follows b
           ON b.follower_id=a.target_id
          AND b.target_id=a.follower_id
         JOIN users u ON u.id=a.target_id
        WHERE a.follower_id=?
        ORDER BY created_at DESC
        LIMIT 1000`
    ).bind(userId).all();
    return json({
      ok:true,
      friends:friends.results ?? [],
      friend_limit:vip.active ? null : 300,
    });
  }

  if (url.pathname === "/api/friends/add" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const friendId = String(body.friend_user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!friendId || friendId === userId) {
      return json({ ok:false,error:"invalid_friend" }, { status:400 });
    }
    if (await usersBlockedEitherWay(db,userId,friendId)) {
      return json({ ok:false,error:"blocked_user" }, { status:403 });
    }
    await ensureUser(db,userId);
    await ensureUser(db,friendId);
    await ensureTinniSocialSchema(db);
    const result = await followUser(db,userId,friendId,true);
    const mutual = await db.prepare(
      "SELECT 1 AS yes FROM user_follows WHERE follower_id=? AND target_id=?"
    ).bind(friendId,userId).first();
    return json({
      ok:true,
      following:true,
      friend:Boolean(mutual),
      compatibility_follow:true,
      ...result,
    });
  }

  if (url.pathname === "/api/friends/remove" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const friendId = String(body.friend_user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureTinniSocialSchema(db);
    await followUser(db,userId,friendId,false);
    return json({ ok:true, following:false, friend:false });
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

  if (url.pathname === "/api/unique-ids/catalog" && request.method === "GET") {
    const authError=await requireSession(request,env);
    if(authError) return authError;
    await ensureUniqueIdStoreSchema(db);
    return json({ok:true,unique_ids:await uniqueIdCatalog(db,now())});
  }

  if (url.pathname === "/api/unique-ids/purchase" && request.method === "POST") {
    const body=await bodyJson(request);
    const userId=String(body.user_id ?? "").trim();
    const publicId=String(body.public_id ?? "").trim();
    const authError=await requireSession(request,env,userId);
    if(authError) return authError;
    await ensureUser(db,userId);
    await ensureUserAllowed(db,userId);
    try{
      const result=await purchaseUniqueId(db,userId,publicId,now());
      return json({
        ok:true,
        ...result,
        vip:await getVipStatus(db,userId,now()),
      });
    }catch(error){
      const code=String(error?.message ?? error);
      const status=code==="insufficient_coins"||code==="unique_id_taken"?409:400;
      return json({ok:false,error:code},{status});
    }
  }

  if (url.pathname === "/api/rankings" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const kind = String(url.searchParams.get("kind") ?? "send").trim().toLowerCase();
    const period = String(url.searchParams.get("period") ?? "day").trim().toLowerCase();
    const windowMs = period === "month"
      ? 30 * 24 * 60 * 60 * 1000
      : period === "week"
        ? 7 * 24 * 60 * 60 * 1000
        : 24 * 60 * 60 * 1000;
    const cutoff = now() - windowMs;
    let rows;
    if (kind === "room") {
      rows = await db.prepare(
        `SELECT r.id AS room_id,
                r.name AS room_name,
                r.owner_user_id,
                COALESCE(u.display_name,'Owner') AS owner_name,
                u.avatar_key,
                r.seat_count,
                COALESCE((SELECT COUNT(*) FROM room_members m WHERE m.room_id=r.id),0) AS online,
                COALESCE((SELECT SUM(g.coin_cost) FROM gift_events g WHERE g.room_id=r.id AND g.created_at>=?),0) AS score
           FROM rooms r
           LEFT JOIN users u ON u.id=r.owner_user_id
          ORDER BY score DESC, online DESC, r.updated_at DESC
          LIMIT 100`
      ).bind(cutoff).all();
    } else if (kind === "charm") {
      rows = await db.prepare(
        `SELECT u.id AS user_id,
                COALESCE(u.display_name,'User') AS display_name,
                u.avatar_key,
                COALESCE(SUM(g.coin_cost),0) AS score,
                COUNT(*) AS gift_count
           FROM gift_events g
           JOIN users u ON u.id=g.receiver_user_id
          WHERE g.created_at>=?
          GROUP BY u.id,u.display_name,u.avatar_key
          ORDER BY score DESC,gift_count DESC
          LIMIT 100`
      ).bind(cutoff).all();
    } else if (kind === "game") {
      rows = await db.prepare(
        `SELECT u.id AS user_id,
                COALESCE(u.display_name,'User') AS display_name,
                u.avatar_key,
                COALESCE(SUM(b.payout),0) AS score,
                COALESCE(SUM(b.stake),0) AS wagered,
                COUNT(*) AS bet_count
           FROM game_bets b
           JOIN users u ON u.id=b.user_id
          WHERE b.created_at>=?
          GROUP BY u.id,u.display_name,u.avatar_key
          ORDER BY score DESC,bet_count DESC
          LIMIT 100`
      ).bind(cutoff).all();
    } else {
      rows = await db.prepare(
        `SELECT u.id AS user_id,
                COALESCE(u.display_name,'User') AS display_name,
                u.avatar_key,
                COALESCE(SUM(g.coin_cost),0) AS score,
                COUNT(*) AS gift_count
           FROM gift_events g
           JOIN users u ON u.id=g.sender_user_id
          WHERE g.created_at>=?
          GROUP BY u.id,u.display_name,u.avatar_key
          ORDER BY score DESC,gift_count DESC
          LIMIT 100`
      ).bind(cutoff).all();
    }
    return json({
      ok: true,
      kind,
      period,
      ranking: rows?.results ?? [],
    });
  }

  if (url.pathname === "/api/gifts/catalog" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const vip = await getVipStatus(db, userId, now());
    const darkVibeExtras = [
      { id: "basic-star", name: "Star", emoji: "⭐", coin_cost: 5000, vip_level: 0, category: "normal" },
      { id: "vip-rose", name: "VIP Rose", emoji: "🌹", coin_cost: 10000, vip_level: 3, category: "exclusive" },
      { id: "vip-crown", name: "Royal Crown", emoji: "👑", coin_cost: 50000, vip_level: 3, category: "exclusive" },
      { id: "vip-phoenix", name: "Golden Phoenix", emoji: "🔥", coin_cost: 100000, vip_level: 3, category: "exclusive" },
    ];
    await ensureCustomGiftSchema(db);
    const custom = await db.prepare(
      "SELECT id,name,asset_key,coin_cost FROM custom_gifts WHERE status='approved' ORDER BY updated_at DESC LIMIT 100"
    ).all();
    const customRows = (custom.results ?? []).map((row) => ({
      id: row.id,
      name: row.name,
      emoji: "🎁",
      coin_cost: Number(row.coin_cost),
      vip_level: 0,
      category: "custom",
      asset_key: row.asset_key,
    }));
    return json({
      ok: true,
      gifts: [
        ...BASE_GIFT_CATALOG,
        ...darkVibeExtras.filter((gift) =>
          gift.vip_level === 0 || (vip.active && vip.level >= gift.vip_level)),
        ...customRows,
      ],
    });
  }

  if (url.pathname === "/api/gifts/send" && request.method === "POST") {
    const giftsFeature = await ownerSetting(db, "feature.gifts", { enabled: true });
    if (giftsFeature.enabled === false) {
      return json({ ok: false, error: "gifts_disabled" }, { status: 403 });
    }
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const authError = await requireSession(request, env, sender);
    if (authError) return authError;
    const giftId = String(body.gift_id ?? "").trim().slice(0, 100);
    let gift = giftById(giftId);
    if (!gift) {
      const extras = {
        "basic-star": { coin_cost: 5000, vip_level: 0 },
        "vip-rose": { coin_cost: 10000, vip_level: 3 },
        "vip-crown": { coin_cost: 50000, vip_level: 3 },
        "vip-phoenix": { coin_cost: 100000, vip_level: 3 },
      };
      gift = extras[giftId] ?? null;
    }
    if (!gift && giftId.startsWith("custom-")) {
      await ensureCustomGiftSchema(db);
      const custom = await db.prepare(
        "SELECT coin_cost FROM custom_gifts WHERE id=? AND status='approved' LIMIT 1"
      ).bind(giftId).first();
      if (custom) gift = { coin_cost: Number(custom.coin_cost), vip_level: 0 };
    }
    if (!sender || !receiver || !gift) {
      return json({ ok: false, error: "invalid_gift" }, { status: 400 });
    }
    const vip = await getVipStatus(db, sender, now());
    const requiredVip = Number(gift.vip_level ?? 0);
    if (requiredVip > 0 && (!vip.active || vip.level < requiredVip)) {
      return json({ ok: false, error: "vip_required" }, { status: 403 });
    }
    const cost = Number(gift.coin_cost ?? 0);
    if (!Number.isSafeInteger(cost) || cost <= 0) {
      return json({ ok: false, error: "invalid_gift_cost" }, { status: 400 });
    }
    await ensureUser(db, sender);
    await ensureUser(db, receiver);
    await ensureUserAllowed(db, sender);
    await ensureUserAllowed(db, receiver);
    const eventId = id();
    const balance = await walletChange(db, sender, -cost, "gift_sent", eventId);
    await db.batch([
      db.prepare("UPDATE users SET diamonds = diamonds + ?, updated_at = ? WHERE id = ?")
        .bind(cost, now(), receiver),
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
    const extensions = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "video/mp4": "mp4" };
    const extension = key.split(".").pop()?.toLowerCase();
    if (!actor || !extensions[type] || extension !== extensions[type] ||
        key.includes("..") || key.startsWith("/") || !/^[a-zA-Z0-9._/-]+$/.test(key)) {
      return json({ ok: false, error: "invalid_image_upload" }, { status: 400 });
    }
    const userPrefix = `users/${actor}/`;
    const messagePrefix = `messages/${actor}/`;
    const customGiftPrefix = `custom-gifts/${actor}/`;
    const callVerificationPrefix = `call-verifications/${actor}/`;
    let authorizedKey = key.startsWith(userPrefix) || key.startsWith(messagePrefix) || key.startsWith(customGiftPrefix) || key.startsWith(callVerificationPrefix);
    const roomMatch = key.match(/^rooms\/([a-zA-Z0-9_-]+)\/avatar-[0-9]+\.(jpg|png|webp)$/i);
    if (roomMatch) {
      const room = await db.prepare("SELECT owner_user_id FROM rooms WHERE id = ?").bind(roomMatch[1]).first();
      authorizedKey = room?.owner_user_id === actor;
    }
    if (!authorizedKey) return json({ ok: false, error: "file_owner_required" }, { status: 403 });
    const maxFileBytes = type === "video/mp4" ? 20 * 1024 * 1024 : 5 * 1024 * 1024;
    const declaredLength = Number(request.headers.get("content-length") ?? 0);
    if (declaredLength > maxFileBytes) {
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
      if (size > maxFileBytes) {
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
    const isMp4 = bytes.length >= 12 && String.fromCharCode(...bytes.slice(4, 8)) === "ftyp";
    if ((type === "image/jpeg" && !isJpeg) || (type === "image/png" && !isPng) ||
        (type === "image/webp" && !isWebp) || (type === "video/mp4" && !isMp4)) {
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
  let membership = await db.prepare(
    "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ? LIMIT 1"
  ).bind(roomId, String(session.sub)).first();
  if (!membership && roomId.startsWith("call-")) {
    const callId = roomId.slice(5);
    await expireDirectCalls(db);
    const call = await db.prepare(
      `SELECT 1 AS active FROM direct_calls
        WHERE id=? AND state IN ('ringing','active')
          AND (caller_user_id=? OR receiver_user_id=?)
        LIMIT 1`
    ).bind(callId,String(session.sub),String(session.sub)).first();
    membership = call;
  }
  if (!membership) {
    return json({ ok: false, error: "room_membership_required" }, { status: 403 });
  }

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
            !/^(users|rooms|messages|custom-gifts|call-verifications)\/[a-zA-Z0-9._/-]+$/.test(key)) {
          return json({ ok: false, error: "invalid_file_key" }, { status: 400 });
        }
        if (key.startsWith("call-verifications/")) {
          const ownerToken = String(env.OWNER_ADMIN_TOKEN ?? "").trim();
          const bearer = bearerToken(request);
          const parts = key.split("/");
          const ownerAccess = ownerToken.isNotEmpty && bearer === ownerToken;
          let userAccess = false;
          if (!ownerAccess) {
            try {
              const session = await verifySessionToken(
                bearer,
                String(env.SESSION_SECRET),
              );
              userAccess = String(session.sub) === String(parts[1] ?? "");
            } catch (_) {}
          }
          if (!ownerAccess && !userAccess) {
            return json({ ok: false, error: "file_not_found" }, { status: 404 });
          }
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
