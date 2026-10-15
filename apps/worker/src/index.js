import { normalizeRole } from "./role_policy.js";
import { awardIdLevelDaily, awardIdLevelGift, claimIdLevelReward, getIdLevelStatus } from "./id_level.js";
import { COSMETIC_CATALOG, ensureCosmeticsSchema, cosmeticUsesLegacyTable, ownedCosmetics } from "./cosmetics.js";
import { handleOwnerApi } from "./owner_api.js";
import { awardSellerVipExp, ensureVipSchema, getVipStatus } from "./vip_store.js";
import { changeVipUniqueId, consumeFreeSayHi, setVipPreference } from "./vip_actions.js";
import { ensureUniqueIdStoreSchema, uniqueIdCatalog, purchaseUniqueId } from "./unique_id_store.js";
import { ensureSupportSchema } from "./support_store.js";
import { BASE_GIFT_CATALOG, DARKVIBE_EXTRA_GIFTS, giftById } from "./gift_catalog.js";
import {
  roleWalletDetail,
  setRoleWalletCredential,
  verifyRoleWalletCredential,
  transferRoleCoins,
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
  familyTransferCoins,
  familyWalletTransfers,
  cpState,
  cpRequest,
  cpRespond,
  cpDisconnect,
  cpDisconnectRequest,
  cpDisconnectRespond,
  cpHeartbeat,
  cpAddMemory,
  cpMemories,
  cpRanking,
  recordCpGiftProgress,
  vsState,
  vsRequest,
  vsRespond,
  vsDisconnect,
  vsDisconnectRequest,
  vsDisconnectRespond,
  vsHeartbeat,
  vsRanking,
  recordVsGiftProgress,
  profileTrends,
  addProfileTrend,
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
  "access-control-allow-headers": "authorization,content-type,x-file-key,x-device-id",
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
  const deviceKey=String(request.headers.get("x-device-id") ?? "").trim().slice(0,500);
  if(deviceKey){
    try{
      const db=requireDb(env);
      await ensureOwnerControlSchema(db);
      await db.prepare(
        `INSERT INTO owner_user_devices(device_key,user_id,last_seen_at) VALUES(?,?,?)
         ON CONFLICT(device_key) DO UPDATE SET user_id=excluded.user_id,last_seen_at=excluded.last_seen_at`
      ).bind(deviceKey,actor,now()).run();
    }catch(error){
      console.error("DarkVibeX device identity mapping failed",String(error?.message ?? error));
    }
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

async function ensureOwnerControlSchema(db) {
  await ensureUsersSchema(db);
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_overrides (
      user_id TEXT PRIMARY KEY,
      invisible_id INTEGER NOT NULL DEFAULT 0,
      locked_room_bypass INTEGER NOT NULL DEFAULT 0,
      wallet_frozen INTEGER NOT NULL DEFAULT 0,
      wallet_banned INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_room_controls (
      room_id TEXT PRIMARY KEY,
      banned INTEGER NOT NULL DEFAULT 0,
      note TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_device_bans (
      device_key TEXT PRIMARY KEY,
      user_id TEXT,
      banned INTEGER NOT NULL DEFAULT 1,
      note TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_devices (
      device_key TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      last_seen_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_user_devices_user ON owner_user_devices(user_id,last_seen_at DESC)"),
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_notifications (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL DEFAULT 'platform',
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      user_id TEXT,
      read_at INTEGER,
      created_at INTEGER NOT NULL
    )`),
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
    db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_price_overrides (
      user_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      item_id TEXT NOT NULL DEFAULT '*',
      price_coins INTEGER,
      free INTEGER NOT NULL DEFAULT 0,
      duration_days INTEGER,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY(user_id,kind,item_id)
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_owner_user_price_override_kind ON owner_user_price_overrides(kind,user_id,updated_at DESC)"),
  ]);
  try {
    await db.prepare("ALTER TABLE owner_user_overrides ADD COLUMN wallet_banned INTEGER NOT NULL DEFAULT 0").run();
  } catch (_) {}
  await db.prepare(`CREATE TRIGGER IF NOT EXISTS owner_wallet_ban_guard
    BEFORE UPDATE OF coins, diamonds ON users
    WHEN (NEW.coins <> OLD.coins OR NEW.diamonds <> OLD.diamonds)
     AND EXISTS(
       SELECT 1 FROM owner_user_overrides o
        WHERE o.user_id=OLD.id AND o.wallet_banned=1
     )
    BEGIN
      SELECT RAISE(ABORT,'wallet_banned');
    END`).run();
}

async function ensureDeviceAllowed(db, deviceKey) {
  const key=String(deviceKey ?? "").trim();
  if(!key) return;
  await ensureOwnerControlSchema(db);
  const row=await db.prepare("SELECT banned FROM owner_device_bans WHERE device_key=? LIMIT 1").bind(key).first();
  if(Number(row?.banned ?? 0)===1) throw new Error("device_banned");
}

async function ensureWalletAllowed(db, userId) {
  await ensureOwnerControlSchema(db);
  const row=await db.prepare("SELECT wallet_frozen,wallet_banned FROM owner_user_overrides WHERE user_id=? LIMIT 1").bind(userId).first();
  if(Number(row?.wallet_banned ?? 0)===1) throw new Error("wallet_banned");
  if(Number(row?.wallet_frozen ?? 0)===1) throw new Error("wallet_frozen");
}

async function ownerUserPricing(db,userId,kind,itemId,basePrice,baseDuration=null) {
  await ensureOwnerControlSchema(db);
  const row=await db.prepare(
    `SELECT price_coins,free,duration_days,item_id
       FROM owner_user_price_overrides
      WHERE user_id=? AND kind=? AND item_id IN (?, '*')
      ORDER BY CASE WHEN item_id=? THEN 0 ELSE 1 END, updated_at DESC
      LIMIT 1`
  ).bind(userId,kind,itemId,itemId).first();
  const free=Number(row?.free ?? 0)===1;
  const rawPrice=row?.price_coins==null ? Number(basePrice ?? 0) : Number(row.price_coins);
  const price=free ? 0 : rawPrice;
  const rawDuration=row?.duration_days==null ? baseDuration : Number(row.duration_days);
  return {
    price_coins:Number.isSafeInteger(price)&&price>=0 ? price : Number(basePrice ?? 0),
    duration_days:rawDuration==null ? null : Number(rawDuration),
    free,
    overridden:Boolean(row),
    matched_item_id:row?.item_id ?? null,
  };
}

async function ownerIdentityMeta(db,userId) {
  await ensureOwnerControlSchema(db);
  const [override,tags]=await Promise.all([
    db.prepare("SELECT invisible_id,locked_room_bypass,wallet_frozen,wallet_banned FROM owner_user_overrides WHERE user_id=? LIMIT 1").bind(userId).first(),
    db.prepare("SELECT tag_id,name,color,kind,designation,background_color,created_at,updated_at FROM owner_user_tags WHERE user_id=? ORDER BY updated_at DESC").bind(userId).all(),
  ]);
  return {
    invisible_id:Number(override?.invisible_id ?? 0)===1,
    locked_room_bypass:Number(override?.locked_room_bypass ?? 0)===1,
    wallet_frozen:Number(override?.wallet_frozen ?? 0)===1,
    wallet_banned:Number(override?.wallet_banned ?? 0)===1,
    tags:tags.results ?? [],
  };
}

async function ownerGameConfig(db,gameId,defaults={}) {
  const fallback={
    enabled:defaults.enabled!==false,
    min_bet:Number(defaults.min_bet ?? 1),
    max_bet:Number(defaults.max_bet ?? 900000000000000),
  };
  try {
    const row=await db.prepare(
      "SELECT enabled,json_data FROM owner_catalog WHERE kind='game_config' AND id=? LIMIT 1"
    ).bind(gameId).first();
    if(!row)return fallback;
    let data={};
    try{data=JSON.parse(String(row.json_data ?? "{}"))||{};}catch(_){}
    return {
      enabled:Number(row.enabled ?? 1)!==0,
      min_bet:Number(data.min_bet ?? fallback.min_bet),
      max_bet:Number(data.max_bet ?? fallback.max_bet),
    };
  } catch(error) {
    if(String(error?.message ?? error).includes("no such table"))return fallback;
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
      `SELECT id,title,body,starts_at,ends_at,updated_at
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
      "SELECT kind,id,name,sort_order,price_coins,json_data,updated_at FROM owner_catalog WHERE kind = ? AND enabled = 1 ORDER BY sort_order ASC, updated_at DESC LIMIT 300"
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

const STORE_COSMETIC_KINDS = new Set([
  "frame","vehicle","entry","ring","bubble","profile_card","profile_background","theme"
]);

async function ownerStoreOverrides(db) {
  try {
    const rows = await db.prepare(
      "SELECT kind,id,name,enabled,sort_order,price_coins,json_data,updated_at FROM owner_catalog ORDER BY kind ASC,sort_order ASC,updated_at DESC LIMIT 1000"
    ).all();
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

async function effectiveCosmeticCatalog(db) {
  const map = new Map(COSMETIC_CATALOG.map((item) => [item.id, { ...item }]));
  for (const row of await ownerStoreOverrides(db)) {
    if (!STORE_COSMETIC_KINDS.has(String(row.kind))) continue;
    const itemId = String(row.id ?? "").trim();
    if (!itemId) continue;
    const startsAt=row.data?.starts_at==null?null:Number(row.data.starts_at);
    const endsAt=row.data?.ends_at==null?null:Number(row.data.ends_at);
    const ts=now();
    if (Number(row.enabled ?? 1) === 0 ||
        (startsAt!=null&&startsAt>0&&startsAt>ts) ||
        (endsAt!=null&&endsAt>0&&endsAt<ts)) {
      map.delete(itemId);
      continue;
    }
    const previous = map.get(itemId) ?? {};
    map.set(itemId, {
      ...previous,
      id: itemId,
      kind: String(row.kind),
      name: String(row.name ?? previous.name ?? itemId),
      price_coins: Number(row.price_coins ?? previous.price_coins ?? 0),
      min_vip_level: Number(row.data?.min_vip_level ?? row.data?.vip_level ?? previous.min_vip_level ?? 0),
      duration_days: Number(row.data?.duration_days ?? previous.duration_days ?? 30),
      tier: Number(row.data?.tier ?? previous.tier ?? 0),
      asset_key: String(row.data?.asset_key ?? row.data?.asset ?? previous.asset_key ?? ""),
      description: String(row.data?.description ?? previous.description ?? ""),
      starts_at: startsAt,
      ends_at: endsAt,
      sort_order: Number(row.sort_order ?? previous.sort_order ?? 0),
    });
  }
  return [...map.values()].sort((a,b)=>
    Number(a.sort_order ?? 0)-Number(b.sort_order ?? 0) ||
    String(a.name ?? "").localeCompare(String(b.name ?? ""))
  );
}

async function effectiveGiftCatalog(db) {
  const map = new Map(
    [...BASE_GIFT_CATALOG, ...DARKVIBE_EXTRA_GIFTS].map((item) => [item.id, { ...item }])
  );
  for (const row of await ownerStoreOverrides(db)) {
    if (String(row.kind) !== "gift") continue;
    const itemId = String(row.id ?? "").trim();
    if (!itemId) continue;
    const startsAt=row.data?.starts_at==null?null:Number(row.data.starts_at);
    const endsAt=row.data?.ends_at==null?null:Number(row.data.ends_at);
    const ts=now();
    if (Number(row.enabled ?? 1) === 0 ||
        (startsAt!=null&&startsAt>0&&startsAt>ts) ||
        (endsAt!=null&&endsAt>0&&endsAt<ts)) {
      map.delete(itemId);
      continue;
    }
    const previous = map.get(itemId) ?? {};
    map.set(itemId, {
      ...previous,
      id: itemId,
      name: String(row.name ?? previous.name ?? itemId),
      emoji: String(row.data?.emoji ?? previous.emoji ?? "🎁"),
      coin_cost: Number(row.price_coins ?? previous.coin_cost ?? 0),
      vip_level: Number(row.data?.min_vip_level ?? row.data?.vip_level ?? previous.vip_level ?? 0),
      category: String(row.data?.category ?? previous.category ?? "normal"),
      asset_key: String(row.data?.asset_key ?? row.data?.asset ?? previous.asset_key ?? ""),
      starts_at: startsAt,
      ends_at: endsAt,
      sort_order: Number(row.sort_order ?? previous.sort_order ?? 0),
    });
  }
  return [...map.values()].sort((a,b)=>
    Number(a.sort_order ?? 0)-Number(b.sort_order ?? 0) ||
    Number(a.coin_cost ?? 0)-Number(b.coin_cost ?? 0)
  );
}

const DARKVIBEX_SUPPORTED_LANGUAGES = new Set([
  "English",
  "Hindi",
  "Urdu",
  "Arabic",
  "Bengali",
  "Malayalam",
  "Filipino (Tagalog)",
  "Persian (Farsi)",
  "Kurdish",
  "Baluchi",
  "Chinese (Simplified)",
  "Chinese (Traditional)",
  "Korean",
]);

async function ensureUsersSchema(db) {
  // Worker deploys do not automatically apply schema.sql to D1. Make the
  // authentication path self-healing without issuing duplicate ALTER writes.
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      public_id TEXT,
      display_name TEXT NOT NULL DEFAULT '',
      avatar_key TEXT,
      date_of_birth TEXT,
      country_code TEXT,
      country_name TEXT,
      flag_emoji TEXT,
      gender TEXT,
      bio TEXT NOT NULL DEFAULT '',
      age_change_count INTEGER NOT NULL DEFAULT 0,
      country_change_count INTEGER NOT NULL DEFAULT 0,
      gender_change_count INTEGER NOT NULL DEFAULT 0,
      language TEXT NOT NULL DEFAULT 'English',
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
    ["public_id", "TEXT"],
    ["display_name", "TEXT NOT NULL DEFAULT ''"],
    ["avatar_key", "TEXT"],
    ["date_of_birth", "TEXT"],
    ["country_code", "TEXT"],
    ["country_name", "TEXT"],
    ["flag_emoji", "TEXT"],
    ["gender", "TEXT"],
    ["bio", "TEXT NOT NULL DEFAULT ''"],
    ["age_change_count", "INTEGER NOT NULL DEFAULT 0"],
    ["country_change_count", "INTEGER NOT NULL DEFAULT 0"],
    ["gender_change_count", "INTEGER NOT NULL DEFAULT 0"],
    ["language", "TEXT NOT NULL DEFAULT 'English'"],
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
  await db.prepare(
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_public_id ON users(public_id) WHERE public_id IS NOT NULL AND public_id <> ''"
  ).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS owner_public_id_history (
    user_id TEXT NOT NULL,
    public_id TEXT NOT NULL,
    changed_at INTEGER NOT NULL,
    changed_by TEXT NOT NULL,
    PRIMARY KEY (user_id, public_id)
  )`).run();
  await db.prepare(
    "CREATE INDEX IF NOT EXISTS idx_owner_old_public_id ON owner_public_id_history(public_id)"
  ).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS public_id_sequence (
    id TEXT PRIMARY KEY,
    next_value INTEGER NOT NULL CHECK(next_value BETWEEN 1000001 AND 10000000)
  )`).run();
  await db.prepare(
    "INSERT OR IGNORE INTO public_id_sequence(id,next_value) VALUES('main',1000001)"
  ).run();
}

async function publicIdOwnedByAnotherUser(db, candidate, userId) {
  const current = await db.prepare(
    "SELECT id FROM users WHERE public_id=? AND id<>? LIMIT 1"
  ).bind(candidate,userId).first();
  if (current) return true;

  const history = await db.prepare(
    "SELECT user_id FROM owner_public_id_history WHERE public_id=? AND user_id<>? LIMIT 1"
  ).bind(candidate,userId).first();
  if (history) return true;

  try {
    const custom = await db.prepare(
      "SELECT user_id FROM user_vip WHERE custom_id=? AND user_id<>? LIMIT 1"
    ).bind(candidate,userId).first();
    if (custom) return true;
  } catch (error) {
    if (!String(error?.message ?? error).includes("no such table")) throw error;
  }
  try {
    const purchased = await db.prepare(
      "SELECT buyer_user_id FROM unique_id_purchases WHERE public_id=? AND buyer_user_id<>? LIMIT 1"
    ).bind(candidate,userId).first();
    if (purchased) return true;
  } catch (error) {
    if (!String(error?.message ?? error).includes("no such table")) throw error;
  }
  return false;
}

async function ensureUserPublicId(db, userId) {
  const row = await db.prepare(
    "SELECT public_id FROM users WHERE id=? LIMIT 1"
  ).bind(userId).first();
  const current = String(row?.public_id ?? "").trim();
  if (/^\d{7}$/.test(current) && Number(current) >= 1000001) return current;

  for (let attempt = 0; attempt < 100000; attempt += 1) {
    const allocated = await db.prepare(
      "UPDATE public_id_sequence SET next_value=next_value+1 WHERE id='main' AND next_value<=9999999 RETURNING next_value-1 AS value"
    ).first();
    const value = Number(allocated?.value ?? 0);
    if (!Number.isSafeInteger(value) || value < 1000001 || value > 9999999) {
      throw new Error("public_id_sequence_exhausted");
    }
    const candidate = String(value);
    if (await publicIdOwnedByAnotherUser(db,candidate,userId)) continue;

    try {
      const update = await db.prepare(
        `UPDATE users
            SET public_id=?,updated_at=?
          WHERE id=?
            AND (public_id IS NULL OR public_id='' OR LENGTH(public_id)<>7 OR public_id GLOB '*[^0-9]*' OR substr(public_id,1,1)='0')`
      ).bind(candidate,now(),userId).run();
      if (Number(update.meta?.changes ?? 0) === 1) return candidate;

      const latest = await db.prepare(
        "SELECT public_id FROM users WHERE id=? LIMIT 1"
      ).bind(userId).first();
      const latestId = String(latest?.public_id ?? "").trim();
      if (/^\d{7}$/.test(latestId) && Number(latestId) >= 1000001) return latestId;
    } catch (error) {
      if (String(error?.message ?? error).toLowerCase().includes("unique")) continue;
      throw error;
    }
  }
  throw new Error("public_id_unavailable");
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
  await ensureUserPublicId(db, userId);
  return db.prepare(
    "SELECT id, public_id, display_name, role, coins, diamonds, vip_level, avatar_key, date_of_birth, country_code, country_name, flag_emoji, gender, bio, age_change_count, country_change_count, gender_change_count, language FROM users WHERE id = ?"
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
      country_code TEXT NOT NULL DEFAULT '',
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
    ["country_code", "TEXT NOT NULL DEFAULT ''"],
    ["created_at", "INTEGER NOT NULL DEFAULT 0"],
    ["updated_at", "INTEGER NOT NULL DEFAULT 0"],
  ];
  for (const [name, definition] of roomAdditions) {
    if (roomColumns.has(name)) continue;
    await db.prepare(`ALTER TABLE rooms ADD COLUMN ${name} ${definition}`).run();
  }
  await db.prepare(
    `UPDATE rooms
        SET country_code = COALESCE(
          NULLIF((SELECT country_code FROM users WHERE users.id = rooms.owner_user_id), ''),
          country_code,
          ''
        )
      WHERE COALESCE(country_code, '') = ''`
  ).run();

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
      lock_password_hash TEXT NOT NULL DEFAULT '',
      lock_password_code TEXT NOT NULL DEFAULT '',
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
  try {
    await db.prepare("ALTER TABLE room_settings ADD COLUMN lock_password_code TEXT NOT NULL DEFAULT ''").run();
  } catch (_) {}
}


async function ensureRoomCustomThemeTable(db) {
  await ensureRoomCoreSchema(db);
  await db.prepare(`CREATE TABLE IF NOT EXISTS room_custom_themes (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    owner_user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    asset_key TEXT NOT NULL,
    price_coins INTEGER NOT NULL DEFAULT 10000000,
    created_at INTEGER NOT NULL,
    expires_at INTEGER,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  await db.prepare(
    "CREATE INDEX IF NOT EXISTS idx_room_custom_themes_room_expiry ON room_custom_themes(room_id, expires_at)"
  ).run();
}

async function expireRoomCustomThemes(db, roomId, ts = now()) {
  await ensureRoomCustomThemeTable(db);
  const expired = await db.prepare(
    "SELECT id FROM room_custom_themes WHERE room_id=? AND expires_at IS NOT NULL AND expires_at<=?"
  ).bind(roomId, ts).all();
  const ids = (expired.results ?? []).map((row) => String(row.id ?? "")).filter(Boolean);
  if (ids.length === 0) return;
  for (const themeId of ids) {
    await db.batch([
      db.prepare("UPDATE room_settings SET theme_id='dark',updated_at=? WHERE room_id=? AND theme_id=?")
        .bind(ts, roomId, themeId),
      db.prepare("DELETE FROM room_custom_themes WHERE id=? AND room_id=?")
        .bind(themeId, roomId),
    ]);
  }
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

async function ensureProfileMediaTable(db) {
  await ensureUsersSchema(db);
  await db.prepare(`CREATE TABLE IF NOT EXISTS profile_media (
    user_id TEXT NOT NULL,
    slot TEXT NOT NULL,
    asset_key TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (user_id,slot),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
}

async function ensureRoomLuckyNumberTable(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS room_lucky_numbers (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    number_value INTEGER NOT NULL CHECK(number_value BETWEEN 1 AND 100),
    created_at INTEGER NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  await db.prepare(
    "CREATE INDEX IF NOT EXISTS idx_room_lucky_numbers_room_time ON room_lucky_numbers(room_id, created_at DESC)"
  ).run();
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

async function listRooms(db, viewerUserId) {
  await ensureOwnerControlSchema(db);
  await ensureImageTables(db);
  await ensureRoomSettingsTable(db);
  await ensureVipSchema(db);
  const viewer = await db.prepare(
    "SELECT country_code FROM users WHERE id=? LIMIT 1"
  ).bind(viewerUserId).first();
  const viewerCountry = String(viewer?.country_code ?? "").trim().toUpperCase();
  if (!viewerCountry) return [];
  const result = await db.prepare(
    `SELECT r.id, r.name, r.owner_user_id, r.seat_count, r.locked, r.country_code,
            CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS display_id,
            COALESCE(io.invisible_id,0) AS owner_invisible_id,
            ri.image_key AS avatar_key,
            COALESCE(rs.party_mode, 'Friends-making Party') AS party_mode,
            COALESCE(rs.room_mode, 'voice') AS room_mode,
            CASE WHEN ov.level >= 18 AND ov.active_until > ?
                       AND json_extract(ov.preferences_json, '$.anonymous_everywhere') = 1
                 THEN 'Anonymous' ELSE COALESCE(u.display_name, '') END AS owner_name,
            (SELECT COUNT(*) FROM room_members m WHERE m.room_id = r.id) AS online
       FROM rooms r
       LEFT JOIN users u ON u.id = r.owner_user_id
       LEFT JOIN owner_user_overrides io ON io.user_id = u.id
       LEFT JOIN owner_room_controls rc ON rc.room_id = r.id
       LEFT JOIN user_vip ov ON ov.user_id = r.owner_user_id
       LEFT JOIN room_images ri ON ri.room_id = r.id
       LEFT JOIN room_settings rs ON rs.room_id = r.id
      WHERE r.country_code = ? AND COALESCE(rc.banned,0)=0
      ORDER BY r.updated_at DESC
      LIMIT 100`
  ).bind(now(), viewerCountry).all();
  const rows = result.results ?? [];
  for (const row of rows) {
    const currentDisplayId = String(row.display_id ?? "").trim();
    if (Number(row.owner_invisible_id ?? 0) !== 1 && !/^[1-9]\d{6}$/.test(currentDisplayId)) {
      row.display_id = await ensureUserPublicId(db, String(row.owner_user_id ?? ""));
    }
    delete row.owner_invisible_id;
  }
  return rows;
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


function normalizeEmail(value) {
  const email=String(value ?? "").trim().toLowerCase();
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("invalid_email");
  return email.slice(0,254);
}

function randomOpaqueToken(byteCount=24) {
  const bytes=new Uint8Array(byteCount);
  crypto.getRandomValues(bytes);
  return base64UrlBytes(bytes);
}

async function derivePasswordHash(passwordValue,saltValue,iterations=100000) {
  const password=String(passwordValue ?? "");
  if(password.length<8||password.length>128) throw new Error("password_length");
  const salt=encoder.encode(String(saltValue));
  const material=await crypto.subtle.importKey(
    "raw",encoder.encode(password),"PBKDF2",false,["deriveBits"],
  );
  const bits=await crypto.subtle.deriveBits(
    {
      name:"PBKDF2",
      hash:"SHA-256",
      salt,
      iterations:Math.max(50000,Math.min(150000,Number(iterations)||100000)),
    },
    material,
    256,
  );
  return base64UrlBytes(new Uint8Array(bits));
}

async function ensureEmailAuthSchema(db) {
  await ensureUsersSchema(db);
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS email_credentials (
      email TEXT PRIMARY KEY,
      user_id TEXT NOT NULL UNIQUE,
      password_salt TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      iterations INTEGER NOT NULL DEFAULT 100000,
      credential_version INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS email_otp_requests (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL,
      purpose TEXT NOT NULL,
      otp_hash TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      verified INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )`),
    db.prepare("CREATE INDEX IF NOT EXISTS idx_email_otp_email_time ON email_otp_requests(email,created_at DESC)"),
    db.prepare(`CREATE TABLE IF NOT EXISTS email_setup_tokens (
      token_hash TEXT PRIMARY KEY,
      email TEXT NOT NULL,
      purpose TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )`),
  ]);
}

function randomSixDigitOtp() {
  const values=new Uint32Array(1);
  crypto.getRandomValues(values);
  return String(values[0] % 1000000).padStart(6,"0");
}

async function sendDarkVibeXOtp(env,email,otp,purpose) {
  if(!env.RESEND_API_KEY||!env.EMAIL_FROM) throw new Error("email_otp_not_configured");
  const label=purpose==="reset" ? "password reset" : "account verification";
  const response=await fetch("https://api.resend.com/emails",{
    method:"POST",
    headers:{
      "content-type":"application/json",
      authorization:"Bearer "+String(env.RESEND_API_KEY),
    },
    body:JSON.stringify({
      from:String(env.EMAIL_FROM),
      to:[email],
      subject:"DarkVibeX verification code",
      html:
        '<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px">'+
        '<h2>DarkVibeX</h2><p>Your '+label+' code is:</p>'+
        '<div style="font-size:32px;font-weight:800;letter-spacing:8px">'+otp+'</div>'+
        '<p>This code expires in 10 minutes. Do not share it.</p></div>',
    }),
  });
  if(!response.ok) throw new Error("email_send_failed");
}

async function startEmailOtp(db,env,emailValue,purposeValue) {
  await ensureEmailAuthSchema(db);
  const email=normalizeEmail(emailValue);
  const purpose=String(purposeValue ?? "signup")==="reset" ? "reset" : "signup";
  const existing=await db.prepare(
    "SELECT user_id FROM email_credentials WHERE email=? LIMIT 1"
  ).bind(email).first();
  if(purpose==="signup"&&existing) throw new Error("email_already_registered");
  if(purpose==="reset"&&!existing) throw new Error("email_account_not_found");

  const recent=await db.prepare(
    "SELECT created_at FROM email_otp_requests WHERE email=? ORDER BY created_at DESC LIMIT 1"
  ).bind(email).first();
  if(recent&&now()-Number(recent.created_at ?? 0)<60000) {
    throw new Error("otp_wait_before_resend");
  }

  const requestId="otp-"+id();
  const otp=randomSixDigitOtp();
  const secret=String(env.SESSION_SECRET ?? "");
  if(!secret) throw new Error("session_secret_not_configured");
  const otpHash=await hmacSignature(secret,requestId+"|"+email+"|"+otp);
  const createdAt=now();
  await db.prepare(
    "INSERT INTO email_otp_requests(id,email,purpose,otp_hash,expires_at,attempts,verified,created_at) VALUES(?,?,?,?,?,0,0,?)"
  ).bind(requestId,email,purpose,otpHash,createdAt+10*60*1000,createdAt).run();
  try {
    await sendDarkVibeXOtp(env,email,otp,purpose);
  } catch(error) {
    await db.prepare("DELETE FROM email_otp_requests WHERE id=?").bind(requestId).run();
    throw error;
  }
  return { request_id:requestId,email,purpose,expires_at:createdAt+10*60*1000 };
}

async function verifyEmailOtpRequest(db,env,requestIdValue,otpValue) {
  await ensureEmailAuthSchema(db);
  const requestId=String(requestIdValue ?? "").trim();
  const otp=String(otpValue ?? "").trim();
  if(!/^\d{6}$/.test(otp)) throw new Error("invalid_otp");
  const row=await db.prepare(
    "SELECT * FROM email_otp_requests WHERE id=? LIMIT 1"
  ).bind(requestId).first();
  if(!row) throw new Error("otp_request_not_found");
  if(Number(row.expires_at ?? 0)<now()) throw new Error("otp_expired");
  if(Number(row.attempts ?? 0)>=5) throw new Error("otp_attempts_exceeded");
  const secret=String(env.SESSION_SECRET ?? "");
  const expected=await hmacSignature(
    secret,requestId+"|"+String(row.email)+"|"+otp,
  );
  if(expected!==String(row.otp_hash)) {
    await db.prepare(
      "UPDATE email_otp_requests SET attempts=attempts+1 WHERE id=?"
    ).bind(requestId).run();
    throw new Error("invalid_otp");
  }
  const setupToken=randomOpaqueToken(32);
  const tokenHash=await sha256Hex(setupToken);
  const createdAt=now();
  await db.batch([
    db.prepare("UPDATE email_otp_requests SET verified=1 WHERE id=?").bind(requestId),
    db.prepare(
      "INSERT INTO email_setup_tokens(token_hash,email,purpose,expires_at,created_at) VALUES(?,?,?,?,?)"
    ).bind(tokenHash,row.email,row.purpose,createdAt+15*60*1000,createdAt),
  ]);
  return {
    email:String(row.email),
    purpose:String(row.purpose),
    setup_token:setupToken,
    expires_at:createdAt+15*60*1000,
  };
}

async function consumeEmailSetupToken(db,tokenValue) {
  await ensureEmailAuthSchema(db);
  const token=String(tokenValue ?? "").trim();
  if(!token) throw new Error("setup_token_required");
  const hash=await sha256Hex(token);
  const row=await db.prepare(
    "SELECT * FROM email_setup_tokens WHERE token_hash=? LIMIT 1"
  ).bind(hash).first();
  if(!row||Number(row.expires_at ?? 0)<now()) throw new Error("setup_token_expired");
  await db.prepare("DELETE FROM email_setup_tokens WHERE token_hash=?").bind(hash).run();
  return row;
}

async function setEmailPassword(db,email,userId,password) {
  const salt=randomOpaqueToken(18);
  const iterations=100000;
  const passwordHash=await derivePasswordHash(password,salt,iterations);
  const stamp=now();
  await db.prepare(
    `INSERT INTO email_credentials(
      email,user_id,password_salt,password_hash,iterations,credential_version,created_at,updated_at
    ) VALUES(?,?,?,?,?,1,?,?)
    ON CONFLICT(email) DO UPDATE SET
      user_id=excluded.user_id,
      password_salt=excluded.password_salt,
      password_hash=excluded.password_hash,
      iterations=excluded.iterations,
      credential_version=email_credentials.credential_version+1,
      updated_at=excluded.updated_at`
  ).bind(email,userId,salt,passwordHash,iterations,stamp,stamp).run();
}

async function emailPasswordLogin(db,emailValue,passwordValue) {
  await ensureEmailAuthSchema(db);
  const email=normalizeEmail(emailValue);
  const row=await db.prepare(
    "SELECT * FROM email_credentials WHERE email=? LIMIT 1"
  ).bind(email).first();
  if(!row) throw new Error("invalid_email_or_password");
  const actual=await derivePasswordHash(
    passwordValue,row.password_salt,Number(row.iterations ?? 100000),
  );
  if(actual!==String(row.password_hash)) throw new Error("invalid_email_or_password");
  return String(row.user_id);
}

function randomFiveDigitRoomCode() {
  const values=new Uint32Array(1);
  const limit=Math.floor(0x100000000 / 90000) * 90000;
  do {
    crypto.getRandomValues(values);
  } while(values[0]>=limit);
  return String(10000 + (values[0] % 90000));
}

const LUDO_COLORS = Object.freeze(["red", "green", "yellow", "blue"]);
const LUDO_OFFSETS = Object.freeze({ red: 0, green: 13, yellow: 26, blue: 39 });
const LUDO_SAFE_TRACK = new Set([0, 8, 13, 21, 26, 34, 39, 47]);

function ludoInitialState() {
  return {
    current_player: "red",
    rolled: null,
    winner: null,
    status: "RED starts. Roll the dice.",
    tokens: {
      red: [-1, -1, -1, -1],
      green: [-1, -1, -1, -1],
      yellow: [-1, -1, -1, -1],
      blue: [-1, -1, -1, -1],
    },
  };
}

function ludoTrackIndex(color, progress) {
  if (!(color in LUDO_OFFSETS) || progress < 0 || progress >= 52) return -1;
  return (LUDO_OFFSETS[color] + progress) % 52;
}

function ludoMovableIndexes(state) {
  const dice = Number(state?.rolled ?? 0);
  const color = String(state?.current_player ?? "red");
  const tokens = Array.isArray(state?.tokens?.[color]) ? state.tokens[color] : [];
  if (!dice || state?.winner) return [];
  const result = [];
  for (let index = 0; index < tokens.length; index += 1) {
    const progress = Number(tokens[index]);
    if (progress >= 57) continue;
    if (progress < 0) {
      if (dice === 6) result.push(index);
    } else if (progress + dice <= 57) {
      result.push(index);
    }
  }
  return result;
}

async function ensureLudoSchema(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS ludo_room_sessions (
      room_id TEXT PRIMARY KEY,
      state_json TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS ludo_room_players (
      room_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      color TEXT NOT NULL,
      joined_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, user_id),
      UNIQUE (room_id, color),
      FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
  ]);
}

async function requireLudoRoomMember(db, roomId, userId) {
  const room = await db.prepare(
    "SELECT id,owner_user_id FROM rooms WHERE id=? LIMIT 1"
  ).bind(roomId).first();
  if (room) {
    const member = await db.prepare(
      "SELECT 1 AS active FROM room_members WHERE room_id=? AND user_id=? LIMIT 1"
    ).bind(roomId, userId).first();
    if (!member) throw new Error("room_membership_required");
    return room;
  }

  await db.prepare(
    "CREATE TABLE IF NOT EXISTS game_rooms (id TEXT PRIMARY KEY, owner_user_id TEXT NOT NULL, name TEXT NOT NULL, shared_score INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)"
  ).run();
  await db.prepare(
    "CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))"
  ).run();
  const gameRoom = await db.prepare(
    "SELECT id,owner_user_id FROM game_rooms WHERE id=? LIMIT 1"
  ).bind(roomId).first();
  if (!gameRoom) throw new Error("room_not_found");
  const gameMember = await db.prepare(
    "SELECT 1 AS active FROM game_room_members WHERE room_id=? AND user_id=? LIMIT 1"
  ).bind(roomId, userId).first();
  if (!gameMember) throw new Error("room_membership_required");
  return gameRoom;
}

async function loadLudoState(db, roomId) {
  await ensureLudoSchema(db);
  let row = await db.prepare(
    "SELECT state_json,version,updated_at FROM ludo_room_sessions WHERE room_id=? LIMIT 1"
  ).bind(roomId).first();
  if (!row) {
    const state = ludoInitialState();
    const ts = now();
    await db.prepare(
      "INSERT OR IGNORE INTO ludo_room_sessions(room_id,state_json,version,updated_at) VALUES(?,?,1,?)"
    ).bind(roomId, JSON.stringify(state), ts).run();
    row = await db.prepare(
      "SELECT state_json,version,updated_at FROM ludo_room_sessions WHERE room_id=? LIMIT 1"
    ).bind(roomId).first();
  }
  let state;
  try {
    state = JSON.parse(String(row?.state_json ?? "{}"));
  } catch (_) {
    state = ludoInitialState();
  }
  for (const color of LUDO_COLORS) {
    if (!Array.isArray(state?.tokens?.[color]) || state.tokens[color].length !== 4) {
      state.tokens ??= {};
      state.tokens[color] = [-1, -1, -1, -1];
    }
  }
  return {
    state,
    version: Math.max(1, Number(row?.version ?? 1)),
    updated_at: Number(row?.updated_at ?? 0),
  };
}

async function saveLudoState(db, roomId, state, expectedVersion) {
  const ts = now();
  const result = await db.prepare(
    "UPDATE ludo_room_sessions SET state_json=?,version=version+1,updated_at=? WHERE room_id=? AND version=?"
  ).bind(JSON.stringify(state), ts, roomId, expectedVersion).run();
  if (Number(result?.meta?.changes ?? 0) !== 1) {
    throw new Error("game_state_changed");
  }
  return { state, version: expectedVersion + 1, updated_at: ts };
}

async function ludoOccupiedColors(db, roomId) {
  const rows = await db.prepare(
    "SELECT color FROM ludo_room_players WHERE room_id=? ORDER BY joined_at ASC"
  ).bind(roomId).all();
  return new Set((rows.results ?? []).map((row) => String(row.color)));
}

async function ludoAdvancePlayer(db, roomId, state, keepTurn = false) {
  const previousRoll = Number(state.rolled ?? 0);
  state.rolled = null;
  if (state.winner) return;
  if (keepTurn && previousRoll === 6) {
    state.status = String(state.current_player).toUpperCase() + " gets another roll.";
    return;
  }
  const occupied = await ludoOccupiedColors(db, roomId);
  const currentIndex = LUDO_COLORS.indexOf(String(state.current_player));
  for (let offset = 1; offset <= LUDO_COLORS.length; offset += 1) {
    const next = LUDO_COLORS[(Math.max(0, currentIndex) + offset) % LUDO_COLORS.length];
    if (occupied.has(next)) {
      state.current_player = next;
      state.status = next.toUpperCase() + " turn.";
      return;
    }
  }
  state.status = String(state.current_player).toUpperCase() + " turn.";
}

async function cleanupLudoPlayers(db, roomId) {
  const stale = await db.prepare(
    `SELECT p.user_id,p.color
       FROM ludo_room_players p
       LEFT JOIN room_members m
         ON m.room_id=p.room_id AND m.user_id=p.user_id
      WHERE p.room_id=? AND m.user_id IS NULL`
  ).bind(roomId).all();
  if (!(stale.results ?? []).length) return;
  const loaded = await loadLudoState(db, roomId);
  let changed = false;
  for (const row of stale.results ?? []) {
    const color = String(row.color);
    await db.prepare(
      "DELETE FROM ludo_room_players WHERE room_id=? AND user_id=?"
    ).bind(roomId, String(row.user_id)).run();
    if (loaded.state.tokens?.[color]) {
      loaded.state.tokens[color] = [-1, -1, -1, -1];
      changed = true;
    }
    if (loaded.state.current_player === color) {
      loaded.state.rolled = null;
      await ludoAdvancePlayer(db, roomId, loaded.state, false);
      changed = true;
    }
  }
  const remaining = await db.prepare(
    "SELECT 1 AS yes FROM ludo_room_players WHERE room_id=? LIMIT 1"
  ).bind(roomId).first();
  if (!remaining) {
    loaded.state = ludoInitialState();
    changed = true;
  }
  if (changed) {
    try {
      await saveLudoState(db, roomId, loaded.state, loaded.version);
    } catch (_) {}
  }
}

async function ensureLudoPlayer(db, roomId, userId) {
  await requireLudoRoomMember(db, roomId, userId);
  await cleanupLudoPlayers(db, roomId);
  let player = await db.prepare(
    "SELECT color,joined_at FROM ludo_room_players WHERE room_id=? AND user_id=? LIMIT 1"
  ).bind(roomId, userId).first();
  if (player) return String(player.color);
  for (const color of LUDO_COLORS) {
    const ts = now();
    await db.prepare(
      "INSERT OR IGNORE INTO ludo_room_players(room_id,user_id,color,joined_at) VALUES(?,?,?,?)"
    ).bind(roomId, userId, color, ts).run();
    player = await db.prepare(
      "SELECT color,joined_at FROM ludo_room_players WHERE room_id=? AND user_id=? LIMIT 1"
    ).bind(roomId, userId).first();
    if (player) return String(player.color);
  }
  return null;
}

async function publicLudoState(db, roomId, userId, loadedValue = null) {
  await db.prepare(
    "CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))"
  ).run();
  const loaded = loadedValue ?? await loadLudoState(db, roomId);
  const rows = await db.prepare(
    `SELECT p.user_id,p.color,p.joined_at,u.display_name,u.avatar_key,
            COALESCE(
              (SELECT m.seat_index FROM room_members m
                WHERE m.room_id=p.room_id AND m.user_id=p.user_id LIMIT 1),
              (SELECT gm.seat_index FROM game_room_members gm
                WHERE gm.room_id=p.room_id AND gm.user_id=p.user_id LIMIT 1)
            ) AS seat_index,
            COALESCE(
              (SELECT m.mic_muted FROM room_members m
                WHERE m.room_id=p.room_id AND m.user_id=p.user_id LIMIT 1),
              0
            ) AS mic_muted
       FROM ludo_room_players p
       JOIN users u ON u.id=p.user_id
      WHERE p.room_id=?
      ORDER BY p.joined_at ASC`
  ).bind(roomId).all();
  const players = (rows.results ?? []).map((row) => ({
    user_id: String(row.user_id),
    color: String(row.color),
    display_name: String(row.display_name ?? row.user_id),
    avatar_key: String(row.avatar_key ?? ""),
    joined_at: Number(row.joined_at ?? 0),
    seat_index: row.seat_index == null ? null : Number(row.seat_index),
    mic_muted: Number(row.mic_muted ?? 1) === 1,
  }));
  const mine = players.find((row) => row.user_id === userId) ?? null;
  return {
    ok: true,
    room_id: roomId,
    player_color: mine?.color ?? null,
    spectator: !mine,
    players,
    version: loaded.version,
    updated_at: loaded.updated_at,
    ...loaded.state,
    movable_indexes: ludoMovableIndexes(loaded.state),
  };
}

async function secureDieRoll() {
  const values = new Uint32Array(1);
  const accepted = Math.floor(0x100000000 / 6) * 6;
  do {
    crypto.getRandomValues(values);
  } while (values[0] >= accepted);
  return Number(values[0] % 6) + 1;
}

const FRUIT_PARTY_ROUND_MS = 21000;
const FRUIT_PARTY_RESULT_MS = 5000;
const FRUIT_PARTY_CYCLE_MS = FRUIT_PARTY_ROUND_MS + FRUIT_PARTY_RESULT_MS;
const FRUIT_PARTY_LUCKY_WINDOW_MS = 2 * 60 * 60 * 1000;
const FRUIT_PARTY_BET_AMOUNTS = Object.freeze([
  5000, 25000, 100000, 500000, 2000000, 10000000,
]);
const FRUIT_PARTY_FRUITS = Object.freeze([
  { key: "lemon", emoji: "🍋", label: "Lemon", multiplier: 5 },
  { key: "raspberry", emoji: "🫐", label: "Raspberry", multiplier: 5 },
  { key: "kiwi", emoji: "🥝", label: "Kiwi", multiplier: 5 },
  { key: "plum", emoji: "🍑", label: "Plum", multiplier: 5 },
  { key: "banana", emoji: "🍌", label: "Banana", multiplier: 10 },
  { key: "strawberry", emoji: "🍓", label: "Strawberry", multiplier: 15 },
  { key: "watermelon", emoji: "🍉", label: "Watermelon", multiplier: 25 },
  { key: "cherry", emoji: "🍒", label: "Cherry", multiplier: 45 },
]);
const FRUIT_PARTY_BY_KEY = new Map(
  FRUIT_PARTY_FRUITS.map((fruit) => [fruit.key, fruit]),
);

async function ensureWalletLedgerSchema(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS wallet_ledger (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    reference_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  await db.prepare(
    "CREATE INDEX IF NOT EXISTS idx_wallet_user_time ON wallet_ledger(user_id, created_at DESC)"
  ).run();
}
const FRUIT_PARTY_X5 = FRUIT_PARTY_FRUITS.filter((fruit) => fruit.multiplier === 5);
const FRUIT_PARTY_MID = FRUIT_PARTY_FRUITS.filter(
  (fruit) => fruit.multiplier === 10 ||
    fruit.multiplier === 15 ||
    fruit.multiplier === 25,
);
const FRUIT_PARTY_HIGH = FRUIT_PARTY_FRUITS.filter(
  (fruit) => fruit.multiplier === 45,
);

function secureIndex(length) {
  if (length <= 1) return 0;
  const values = new Uint32Array(1);
  const ceiling = Math.floor(0x100000000 / length) * length;
  do {
    crypto.getRandomValues(values);
  } while (values[0] >= ceiling);
  return values[0] % length;
}

function fruitPartyWeightedFruit() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  const roll = values[0] % 100;
  if (roll < 75) return FRUIT_PARTY_X5[secureIndex(FRUIT_PARTY_X5.length)];
  if (roll < 95) return FRUIT_PARTY_MID[secureIndex(FRUIT_PARTY_MID.length)];
  return FRUIT_PARTY_HIGH[secureIndex(FRUIT_PARTY_HIGH.length)];
}

function fruitPartyDistinctFruits(count) {
  const pool = [...FRUIT_PARTY_FRUITS];
  const picked = [];
  while (pool.length && picked.length < count) {
    picked.push(pool.splice(secureIndex(pool.length), 1)[0]);
  }
  return picked;
}

function fruitPartyRoundId(ts) {
  return Math.floor(ts / FRUIT_PARTY_CYCLE_MS);
}
function fruitPartyRoundStart(roundId) {
  return roundId * FRUIT_PARTY_CYCLE_MS;
}
function fruitPartyBetEnd(roundId) {
  return fruitPartyRoundStart(roundId) + FRUIT_PARTY_ROUND_MS;
}
function fruitPartyCycleEnd(roundId) {
  return fruitPartyRoundStart(roundId) + FRUIT_PARTY_CYCLE_MS;
}

async function ensureFruitPartySchema(db) {
  await ensureWalletLedgerSchema(db);
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS fruit_party_bets (
      id TEXT PRIMARY KEY,
      request_id TEXT NOT NULL,
      round_id INTEGER NOT NULL,
      user_id TEXT NOT NULL,
      fruit_key TEXT NOT NULL,
      amount INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(user_id, request_id),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS fruit_party_results (
      round_id INTEGER PRIMARY KEY,
      fruit_key TEXT NOT NULL,
      mode TEXT NOT NULL,
      bonus_fruits_json TEXT NOT NULL DEFAULT '[]',
      total_bet INTEGER NOT NULL DEFAULT 0,
      total_payout INTEGER NOT NULL DEFAULT 0,
      active_players INTEGER NOT NULL DEFAULT 0,
      top_winners_json TEXT NOT NULL DEFAULT '[]',
      settled_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS fruit_party_lucky_windows (
      window_id INTEGER PRIMARY KEY,
      rounds_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )`),
    db.prepare(
      "CREATE INDEX IF NOT EXISTS idx_fruit_party_bets_round ON fruit_party_bets(round_id)"
    ),
    db.prepare(
      "CREATE INDEX IF NOT EXISTS idx_fruit_party_results_time ON fruit_party_results(settled_at DESC)"
    ),
  ]);
}

async function fruitPartyLuckyRounds(db, roundId) {
  const windowId = Math.floor(
    fruitPartyRoundStart(roundId) / FRUIT_PARTY_LUCKY_WINDOW_MS,
  );
  let row = await db.prepare(
    "SELECT rounds_json FROM fruit_party_lucky_windows WHERE window_id=?"
  ).bind(windowId).first();
  if (!row) {
    const windowStart = windowId * FRUIT_PARTY_LUCKY_WINDOW_MS;
    const windowEnd = windowStart + FRUIT_PARTY_LUCKY_WINDOW_MS;
    const firstRound = Math.ceil(windowStart / FRUIT_PARTY_CYCLE_MS);
    const lastRound = Math.floor((windowEnd - 1) / FRUIT_PARTY_CYCLE_MS);
    const totalRounds = Math.max(1, lastRound - firstRound + 1);
    const count = 3 + secureIndex(2);
    const selected = new Set();
    while (selected.size < Math.min(count, totalRounds)) {
      selected.add(firstRound + secureIndex(totalRounds));
    }
    const rounds = [...selected].sort((a, b) => a - b);
    await db.prepare(
      "INSERT OR IGNORE INTO fruit_party_lucky_windows(window_id,rounds_json,created_at) VALUES(?,?,?)"
    ).bind(windowId, JSON.stringify(rounds), now()).run();
    row = await db.prepare(
      "SELECT rounds_json FROM fruit_party_lucky_windows WHERE window_id=?"
    ).bind(windowId).first();
  }
  try {
    const parsed = JSON.parse(String(row?.rounds_json ?? "[]"));
    return Array.isArray(parsed) ? parsed.map(Number) : [];
  } catch (_) {
    return [];
  }
}

async function settleFruitPartyRound(db, roundId) {
  const existing = await db.prepare(
    "SELECT round_id FROM fruit_party_results WHERE round_id=? LIMIT 1"
  ).bind(roundId).first();
  if (existing) return;

  const rows = await db.prepare(
    `SELECT b.user_id,b.fruit_key,b.amount,u.display_name,u.avatar_key
       FROM fruit_party_bets b
       JOIN users u ON u.id=b.user_id
      WHERE b.round_id=?
      ORDER BY b.created_at ASC`
  ).bind(roundId).all();
  const bets = rows.results ?? [];
  const luckyRounds = await fruitPartyLuckyRounds(db, roundId);
  const lucky11 = luckyRounds.includes(roundId);
  const luckyType = lucky11 ? (secureIndex(2) === 0 ? "silver" : "gold") : null;
  const bonus = luckyType === "silver" ? FRUIT_PARTY_FRUITS.slice(0, 4)
    : luckyType === "gold" ? FRUIT_PARTY_FRUITS.slice(4, 8) : [];
  let winner = lucky11 ? bonus[0] : fruitPartyWeightedFruit();

  if (!lucky11) {
    const previous = await db.prepare(
      "SELECT fruit_key FROM fruit_party_results WHERE round_id<? ORDER BY round_id DESC LIMIT 1"
    ).bind(roundId).first();
    if (previous && String(previous.fruit_key) === winner.key) {
      const alternatives = FRUIT_PARTY_FRUITS.filter(
        (fruit) => fruit.key !== String(previous.fruit_key),
      );
      winner = alternatives[secureIndex(alternatives.length)];
    }
  }

  const winningKeys = new Set(
    lucky11 ? bonus.map((fruit) => fruit.key) : [winner.key],
  );
  const payouts = new Map();
  const profiles = new Map();
  let totalBet = 0;
  for (const bet of bets) {
    const amount = Number(bet.amount ?? 0);
    totalBet += amount;
    profiles.set(String(bet.user_id), {
      display_name: String(bet.display_name ?? bet.user_id ?? "User"),
      avatar_key: String(bet.avatar_key ?? ""),
    });
    if (!winningKeys.has(String(bet.fruit_key))) continue;
    const fruit = FRUIT_PARTY_BY_KEY.get(String(bet.fruit_key));
    if (!fruit) continue;
    const payout = amount * fruit.multiplier;
    payouts.set(
      String(bet.user_id),
      Number(payouts.get(String(bet.user_id)) ?? 0) + payout,
    );
  }
  const totalPayout = [...payouts.values()].reduce(
    (sum, value) => sum + Number(value),
    0,
  );
  const topWinners = [...payouts.entries()]
    .filter(([, amount]) => Number(amount) > 0)
    .sort((a, b) => Number(b[1]) - Number(a[1]))
    .slice(0, 3)
    .map(([userId, amount]) => ({
      user_id: userId,
      display_name: profiles.get(userId)?.display_name ?? userId,
      avatar_key: profiles.get(userId)?.avatar_key ?? "",
      winning_coins: Number(amount),
    }));
  const ts = now();

  const statements = [
    db.prepare(
      `INSERT INTO fruit_party_results(
        round_id,fruit_key,mode,bonus_fruits_json,total_bet,total_payout,
        active_players,top_winners_json,settled_at
      ) VALUES(?,?,?,?,?,?,?,?,?)`
    ).bind(
      roundId,
      winner.key,
      lucky11 ? `lucky_11_${luckyType}` : "weighted_random",
      JSON.stringify(bonus.map((fruit) => fruit.key)),
      totalBet,
      totalPayout,
      new Set(bets.map((bet) => String(bet.user_id))).size,
      JSON.stringify(topWinners),
      ts,
    ),
  ];
  for (const [userId, payout] of payouts.entries()) {
    const reference = `fruit-party:${roundId}:${userId}`;
    statements.push(
      db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?")
        .bind(Number(payout), ts, userId),
      db.prepare(
        `INSERT INTO wallet_ledger(
          id,user_id,kind,amount,balance_after,reference_id,created_at
        )
        SELECT ?,u.id,'fruit_party_win',?,u.coins,?,?
          FROM users u WHERE u.id=?`
      ).bind(id(), Number(payout), reference, ts, userId),
    );
  }
  try {
    await db.batch(statements);
  } catch (error) {
    const after = await db.prepare(
      "SELECT round_id FROM fruit_party_results WHERE round_id=?"
    ).bind(roundId).first();
    if (!after) throw error;
  }

  await db.prepare(
    "DELETE FROM fruit_party_results WHERE round_id NOT IN (SELECT round_id FROM fruit_party_results ORDER BY round_id DESC LIMIT 100)"
  ).run();
  await db.prepare(
    "DELETE FROM fruit_party_bets WHERE round_id<?"
  ).bind(roundId - 120).run();
}

async function syncFruitParty(db, ts = now()) {
  await ensureFruitPartySchema(db);
  const currentRound = fruitPartyRoundId(ts);
  const eligible =
    ts >= fruitPartyBetEnd(currentRound) ? currentRound : currentRound - 1;
  const start = Math.max(0, eligible - 7);
  for (let round = start; round <= eligible; round++) {
    await settleFruitPartyRound(db, round);
  }
}

async function fruitPartyState(db, userId, ts = now()) {
  await syncFruitParty(db, ts);
  const roundId = fruitPartyRoundId(ts);
  const betEnd = fruitPartyBetEnd(roundId);
  const cycleEnd = fruitPartyCycleEnd(roundId);
  const inResultSpin = ts >= betEnd;
  const myRows = await db.prepare(
    "SELECT fruit_key,COALESCE(SUM(amount),0) AS amount FROM fruit_party_bets WHERE round_id=? AND user_id=? GROUP BY fruit_key"
  ).bind(roundId, userId).all();
  const myBets = Object.fromEntries(
    FRUIT_PARTY_FRUITS.map((fruit) => [fruit.key, 0]),
  );
  for (const row of myRows.results ?? []) {
    if (Object.prototype.hasOwnProperty.call(myBets, row.fruit_key)) {
      myBets[row.fruit_key] = Number(row.amount ?? 0);
    }
  }
  const totals = await db.prepare(
    "SELECT COALESCE(SUM(amount),0) AS total_bet,COUNT(DISTINCT user_id) AS active_players FROM fruit_party_bets WHERE round_id=?"
  ).bind(roundId).first();
  const historyRows = await db.prepare(
    `SELECT round_id,fruit_key,mode,bonus_fruits_json,total_bet,total_payout,
            active_players,top_winners_json,settled_at
       FROM fruit_party_results
      ORDER BY round_id DESC
      LIMIT 7`
  ).all();
  const history = (historyRows.results ?? []).map((row) => {
    let bonusKeys = [];
    let topWinners = [];
    try { bonusKeys = JSON.parse(String(row.bonus_fruits_json ?? "[]")); } catch (_) {}
    try { topWinners = JSON.parse(String(row.top_winners_json ?? "[]")); } catch (_) {}
    return {
      round_id: Number(row.round_id),
      fruit: FRUIT_PARTY_BY_KEY.get(String(row.fruit_key)) ?? null,
      mode: String(row.mode ?? ""),
      lucky11: String(row.mode ?? "").startsWith("lucky_11_"),
      lucky_type: row.mode === "lucky_11_silver" ? "silver" : row.mode === "lucky_11_gold" ? "gold" : null,
      bonus_fruits: bonusKeys
        .map((key) => FRUIT_PARTY_BY_KEY.get(String(key)))
        .filter(Boolean),
      total_bet: Number(row.total_bet ?? 0),
      total_payout: Number(row.total_payout ?? 0),
      active_players: Number(row.active_players ?? 0),
      top_winners: Array.isArray(topWinners) ? topWinners.slice(0, 3) : [],
      settled_at: Number(row.settled_at ?? 0),
    };
  });
  const wallet = await db.prepare(
    "SELECT coins FROM users WHERE id=? LIMIT 1"
  ).bind(userId).first();
  const dayStart = Math.floor(ts / 86400000) * 86400000;
  const winRow = await db.prepare(
    "SELECT COALESCE(SUM(amount),0) AS winnings FROM wallet_ledger WHERE user_id=? AND kind='fruit_party_win' AND created_at>=?"
  ).bind(userId, dayStart).first();

  return {
    ok: true,
    server_time: ts,
    round: {
      round_id: roundId,
      round_start: fruitPartyRoundStart(roundId),
      round_end: betEnd,
      cycle_end: cycleEnd,
      remaining_ms: Math.max(0, betEnd - ts),
      result_spin_remaining_ms: inResultSpin
        ? Math.max(0, cycleEnd - ts)
        : 0,
      result_spin_ms: FRUIT_PARTY_RESULT_MS,
      phase: inResultSpin ? "result_spin" : "betting",
      round_duration_ms: FRUIT_PARTY_ROUND_MS,
      round_cycle_ms: FRUIT_PARTY_CYCLE_MS,
      betting_open: !inResultSpin && betEnd > ts,
      total_bet: Number(totals?.total_bet ?? 0),
      active_players: Number(totals?.active_players ?? 0),
    },
    config: {
      bet_amounts: FRUIT_PARTY_BET_AMOUNTS,
      lucky_window_ms: FRUIT_PARTY_LUCKY_WINDOW_MS,
      lucky_rounds_min: 3,
      lucky_rounds_max: 4,
      lucky_fruit_count: 4,
      fruits: FRUIT_PARTY_FRUITS,
    },
    wallet_balance: Number(wallet?.coins ?? 0),
    today_winnings: Number(winRow?.winnings ?? 0),
    my_bets: myBets,
    history,
  };
}


const GREEDY_GIRL_ROUND_MS = 30000;
const GREEDY_GIRL_RESULT_MS = 5000;
const GREEDY_GIRL_CYCLE_MS = GREEDY_GIRL_ROUND_MS + GREEDY_GIRL_RESULT_MS;
const GREEDY_GIRL_BET_AMOUNTS = Object.freeze([
  100, 1000, 10000, 50000, 100000, 200000, 500000, 1000000, 5000000,
]);
const GREEDY_GIRL_FOODS = Object.freeze([
  { key: "tomato", emoji: "🍅", label: "Tomato", multiplier: 5 },
  { key: "broccoli", emoji: "🥦", label: "Broccoli", multiplier: 5 },
  { key: "cucumber", emoji: "🥒", label: "Cucumber", multiplier: 5 },
  { key: "carrot", emoji: "🥕", label: "Carrot", multiplier: 5 },
  { key: "hotdog", emoji: "🌭", label: "Hot dog", multiplier: 10 },
  { key: "corn", emoji: "🌽", label: "Corn", multiplier: 15 },
  { key: "lettuce", emoji: "🥬", label: "Lettuce", multiplier: 25 },
  { key: "skewer", emoji: "🍢", label: "Skewer", multiplier: 45 },
]);
const GREEDY_GIRL_BY_KEY = new Map(
  GREEDY_GIRL_FOODS.map((food) => [food.key, food]),
);
let greedyGirlSchemaReady = false;
const GREEDY_GIRL_X5 = GREEDY_GIRL_FOODS.filter(
  (food) => food.multiplier === 5,
);
const GREEDY_GIRL_MID = GREEDY_GIRL_FOODS.filter(
  (food) => food.multiplier === 10 ||
    food.multiplier === 15 ||
    food.multiplier === 25,
);
const GREEDY_GIRL_HIGH = GREEDY_GIRL_FOODS.filter(
  (food) => food.multiplier === 45,
);

function greedyGirlWeightedFood() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  const roll = values[0] % 100;
  if (roll < 75) return GREEDY_GIRL_X5[secureIndex(GREEDY_GIRL_X5.length)];
  if (roll < 95) return GREEDY_GIRL_MID[secureIndex(GREEDY_GIRL_MID.length)];
  return GREEDY_GIRL_HIGH[secureIndex(GREEDY_GIRL_HIGH.length)];
}

function greedyGirlRoundId(ts) {
  return Math.floor(ts / GREEDY_GIRL_CYCLE_MS);
}
function greedyGirlRoundStart(roundId) {
  return roundId * GREEDY_GIRL_CYCLE_MS;
}
function greedyGirlBetEnd(roundId) {
  return greedyGirlRoundStart(roundId) + GREEDY_GIRL_ROUND_MS;
}
function greedyGirlCycleEnd(roundId) {
  return greedyGirlRoundStart(roundId) + GREEDY_GIRL_CYCLE_MS;
}

async function ensureGreedyGirlSchema(db) {
  if (greedyGirlSchemaReady) return;
  await ensureWalletLedgerSchema(db);
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS greedy_girl_bets (
      id TEXT PRIMARY KEY,
      request_id TEXT NOT NULL,
      round_id INTEGER NOT NULL,
      user_id TEXT NOT NULL,
      food_key TEXT NOT NULL,
      amount INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      UNIQUE(user_id, request_id),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS greedy_girl_results (
      round_id INTEGER PRIMARY KEY,
      food_key TEXT NOT NULL,
      total_bet INTEGER NOT NULL DEFAULT 0,
      total_payout INTEGER NOT NULL DEFAULT 0,
      active_players INTEGER NOT NULL DEFAULT 0,
      top_winners_json TEXT NOT NULL DEFAULT '[]',
      settled_at INTEGER NOT NULL
    )`),
    db.prepare(
      "CREATE INDEX IF NOT EXISTS idx_greedy_girl_bets_round ON greedy_girl_bets(round_id)"
    ),
    db.prepare(
      "CREATE INDEX IF NOT EXISTS idx_greedy_girl_results_time ON greedy_girl_results(settled_at DESC)"
    ),
  ]);
  greedyGirlSchemaReady = true;
}

async function settleGreedyGirlRound(db, roundId) {
  const existing = await db.prepare(
    "SELECT round_id FROM greedy_girl_results WHERE round_id=? LIMIT 1"
  ).bind(roundId).first();
  if (existing) return;

  const rows = await db.prepare(
    `SELECT b.user_id,b.food_key,b.amount,u.display_name,u.avatar_key
       FROM greedy_girl_bets b
       JOIN users u ON u.id=b.user_id
      WHERE b.round_id=?
      ORDER BY b.created_at ASC`
  ).bind(roundId).all();
  const bets = rows.results ?? [];
  let winner = greedyGirlWeightedFood();

  const previous = await db.prepare(
    "SELECT food_key FROM greedy_girl_results WHERE round_id<? ORDER BY round_id DESC LIMIT 1"
  ).bind(roundId).first();
  if (previous && String(previous.food_key) === winner.key) {
    const alternatives = GREEDY_GIRL_FOODS.filter(
      (food) => food.key !== String(previous.food_key),
    );
    winner = alternatives[secureIndex(alternatives.length)];
  }

  const payouts = new Map();
  const profiles = new Map();
  let totalBet = 0;
  for (const bet of bets) {
    const amount = Number(bet.amount ?? 0);
    totalBet += amount;
    const userId = String(bet.user_id);
    profiles.set(userId, {
      display_name: String(bet.display_name ?? bet.user_id ?? "User"),
      avatar_key: String(bet.avatar_key ?? ""),
    });
    if (String(bet.food_key) !== winner.key) continue;
    const payout = amount * winner.multiplier;
    payouts.set(userId, Number(payouts.get(userId) ?? 0) + payout);
  }

  const totalPayout = [...payouts.values()].reduce(
    (sum, value) => sum + Number(value),
    0,
  );
  const topWinners = [...payouts.entries()]
    .filter(([, amount]) => Number(amount) > 0)
    .sort((a, b) => Number(b[1]) - Number(a[1]))
    .slice(0, 3)
    .map(([userId, amount]) => ({
      user_id: userId,
      display_name: profiles.get(userId)?.display_name ?? userId,
      avatar_key: profiles.get(userId)?.avatar_key ?? "",
      winning_coins: Number(amount),
    }));
  const ts = now();

  const statements = [
    db.prepare(
      `INSERT INTO greedy_girl_results(
        round_id,food_key,total_bet,total_payout,active_players,
        top_winners_json,settled_at
      ) VALUES(?,?,?,?,?,?,?)`
    ).bind(
      roundId,
      winner.key,
      totalBet,
      totalPayout,
      new Set(bets.map((bet) => String(bet.user_id))).size,
      JSON.stringify(topWinners),
      ts,
    ),
  ];

  for (const [userId, payout] of payouts.entries()) {
    const reference = `greedy-girl:${roundId}:${userId}`;
    statements.push(
      db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?")
        .bind(Number(payout), ts, userId),
      db.prepare(
        `INSERT INTO wallet_ledger(
          id,user_id,kind,amount,balance_after,reference_id,created_at
        )
        SELECT ?,u.id,'greedy_girl_win',?,u.coins,?,?
          FROM users u WHERE u.id=?`
      ).bind(id(), Number(payout), reference, ts, userId),
    );
  }

  try {
    await db.batch(statements);
  } catch (error) {
    const after = await db.prepare(
      "SELECT round_id FROM greedy_girl_results WHERE round_id=? LIMIT 1"
    ).bind(roundId).first();
    if (!after) throw error;
  }

  await db.prepare(
    "DELETE FROM greedy_girl_results WHERE round_id NOT IN (SELECT round_id FROM greedy_girl_results ORDER BY round_id DESC LIMIT 100)"
  ).run();
  await db.prepare(
    "DELETE FROM greedy_girl_bets WHERE round_id<?"
  ).bind(roundId - 120).run();
}

async function syncGreedyGirl(db, ts = now()) {
  await ensureGreedyGirlSchema(db);
  const currentRound = greedyGirlRoundId(ts);
  const eligible =
    ts >= greedyGirlBetEnd(currentRound) ? currentRound : currentRound - 1;
  const start = Math.max(0, eligible - 7);
  for (let round = start; round <= eligible; round++) {
    await settleGreedyGirlRound(db, round);
  }
}

async function greedyGirlState(db, userId, ts = now()) {
  await syncGreedyGirl(db, ts);
  const roundId = greedyGirlRoundId(ts);
  const betEnd = greedyGirlBetEnd(roundId);
  const cycleEnd = greedyGirlCycleEnd(roundId);
  const inResultSpin = ts >= betEnd;

  const myRows = await db.prepare(
    "SELECT food_key,COALESCE(SUM(amount),0) AS amount FROM greedy_girl_bets WHERE round_id=? AND user_id=? GROUP BY food_key"
  ).bind(roundId, userId).all();
  const myBets = Object.fromEntries(
    GREEDY_GIRL_FOODS.map((food) => [food.key, 0]),
  );
  for (const row of myRows.results ?? []) {
    if (Object.prototype.hasOwnProperty.call(myBets, row.food_key)) {
      myBets[row.food_key] = Number(row.amount ?? 0);
    }
  }

  const totals = await db.prepare(
    "SELECT COALESCE(SUM(amount),0) AS total_bet,COUNT(DISTINCT user_id) AS active_players FROM greedy_girl_bets WHERE round_id=?"
  ).bind(roundId).first();
  const historyRows = await db.prepare(
    `SELECT round_id,food_key,total_bet,total_payout,active_players,
            top_winners_json,settled_at
       FROM greedy_girl_results
      ORDER BY round_id DESC
      LIMIT 7`
  ).all();
  const history = (historyRows.results ?? []).map((row) => {
    let topWinners = [];
    try {
      topWinners = JSON.parse(String(row.top_winners_json ?? "[]"));
    } catch (_) {}
    return {
      round_id: Number(row.round_id),
      food: GREEDY_GIRL_BY_KEY.get(String(row.food_key)) ?? null,
      total_bet: Number(row.total_bet ?? 0),
      total_payout: Number(row.total_payout ?? 0),
      active_players: Number(row.active_players ?? 0),
      top_winners: Array.isArray(topWinners) ? topWinners.slice(0, 3) : [],
      settled_at: Number(row.settled_at ?? 0),
    };
  });

  const wallet = await db.prepare(
    "SELECT coins FROM users WHERE id=? LIMIT 1"
  ).bind(userId).first();
  const dayStart = Math.floor(ts / 86400000) * 86400000;
  const winRow = await db.prepare(
    "SELECT COALESCE(SUM(amount),0) AS winnings FROM wallet_ledger WHERE user_id=? AND kind='greedy_girl_win' AND created_at>=?"
  ).bind(userId, dayStart).first();

  return {
    ok: true,
    server_time: ts,
    round: {
      round_id: roundId,
      round_start: greedyGirlRoundStart(roundId),
      round_end: betEnd,
      cycle_end: cycleEnd,
      remaining_ms: Math.max(0, betEnd - ts),
      result_spin_remaining_ms: inResultSpin
        ? Math.max(0, cycleEnd - ts)
        : 0,
      result_spin_ms: GREEDY_GIRL_RESULT_MS,
      phase: inResultSpin ? "result_spin" : "betting",
      round_duration_ms: GREEDY_GIRL_ROUND_MS,
      round_cycle_ms: GREEDY_GIRL_CYCLE_MS,
      betting_open: !inResultSpin && betEnd > ts,
      total_bet: Number(totals?.total_bet ?? 0),
      active_players: Number(totals?.active_players ?? 0),
    },
    config: {
      bet_amounts: GREEDY_GIRL_BET_AMOUNTS,
      foods: GREEDY_GIRL_FOODS,
    },
    wallet_balance: Number(wallet?.coins ?? 0),
    today_winnings: Number(winRow?.winnings ?? 0),
    my_bets: myBets,
    history,
  };
}

let cachedFcmAccessToken = "";
let cachedFcmAccessTokenUntil = 0;
let cachedFcmProjectId = "";

function fcmBase64UrlBytes(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function fcmBase64UrlText(value) {
  return fcmBase64UrlBytes(new TextEncoder().encode(value));
}

function pemPkcs8Bytes(pem) {
  const body = String(pem ?? "")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  if (!body) throw new Error("fcm_private_key_missing");
  const binary = atob(body);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function fcmAccess(env) {
  const raw = String(env.FCM_SERVICE_ACCOUNT_JSON ?? "").trim();
  if (!raw) return null;

  const service = JSON.parse(raw);
  const projectId = String(service.project_id ?? "").trim();
  const clientEmail = String(service.client_email ?? "").trim();
  const privateKey = String(service.private_key ?? "");
  if (!projectId || !clientEmail || !privateKey) return null;

  const currentSeconds = Math.floor(Date.now() / 1000);
  if (
    cachedFcmAccessToken &&
    cachedFcmProjectId === projectId &&
    cachedFcmAccessTokenUntil > currentSeconds + 60
  ) {
    return {
      token: cachedFcmAccessToken,
      projectId: cachedFcmProjectId,
    };
  }

  const header = fcmBase64UrlText(JSON.stringify({
    alg: "RS256",
    typ: "JWT",
  }));
  const claim = fcmBase64UrlText(JSON.stringify({
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: currentSeconds,
    exp: currentSeconds + 3600,
  }));
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemPkcs8Bytes(privateKey),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const assertion = `${unsigned}.${fcmBase64UrlBytes(signature)}`;
  const tokenResponse = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "content-type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );
  if (!tokenResponse.ok) {
    throw new Error(`fcm_oauth_${tokenResponse.status}`);
  }
  const tokenBody = await tokenResponse.json();
  const accessToken = String(tokenBody.access_token ?? "").trim();
  const expiresIn = Number(tokenBody.expires_in ?? 3600);
  if (!accessToken) throw new Error("fcm_oauth_token_missing");

  cachedFcmAccessToken = accessToken;
  cachedFcmProjectId = projectId;
  cachedFcmAccessTokenUntil = currentSeconds + Math.max(300, expiresIn);
  return {
    token: accessToken,
    projectId,
  };
}

async function ensurePushTables(db) {
  await db.batch([
    db.prepare(`CREATE TABLE IF NOT EXISTS push_devices (
      token TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      platform TEXT NOT NULL DEFAULT 'android',
      enabled INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(`CREATE TABLE IF NOT EXISTS push_preferences (
      user_id TEXT PRIMARY KEY,
      message_enabled INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL
    )`),
    db.prepare(
      "CREATE INDEX IF NOT EXISTS idx_push_devices_user ON push_devices(user_id,enabled,updated_at DESC)"
    ),
  ]);
}

async function sendDirectMessagePush(
  env,
  db,
  {
    receiverUserId,
    senderUserId,
    messageId,
    preview,
  },
) {
  if (!String(env.FCM_SERVICE_ACCOUNT_JSON ?? "").trim()) return;
  await ensurePushTables(db);

  const preference = await db.prepare(
    "SELECT message_enabled FROM push_preferences WHERE user_id=? LIMIT 1"
  ).bind(receiverUserId).first();
  if (Number(preference?.message_enabled ?? 1) !== 1) return;

  const deviceRows = await db.prepare(
    `SELECT token
       FROM push_devices
      WHERE user_id=? AND enabled=1
      ORDER BY updated_at DESC
      LIMIT 8`
  ).bind(receiverUserId).all();
  const devices = deviceRows.results ?? [];
  if (!devices.length) return;

  const sender = await db.prepare(
    "SELECT display_name FROM users WHERE id=? LIMIT 1"
  ).bind(senderUserId).first();
  const senderName = String(sender?.display_name ?? "DarkVibeX user").slice(0, 80);
  const safePreview = String(preview ?? "").trim().slice(0, 180) || "You received a new message.";

  const auth = await fcmAccess(env);
  if (!auth) return;

  await Promise.all(
    devices.map(async (device) => {
      const token = String(device.token ?? "").trim();
      if (!token) return;
      try {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(auth.projectId)}/messages:send`,
          {
            method: "POST",
            headers: {
              authorization: `Bearer ${auth.token}`,
              "content-type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                data: {
                  type: "direct_message",
                  sender_user_id: String(senderUserId),
                  sender_name: senderName,
                  message_id: String(messageId),
                  preview: safePreview,
                },
                android: {
                  priority: "high",
                  ttl: "86400s",
                },
              },
            }),
          },
        );
        if (response.ok) return;
        const errorText = await response.text();
        if (
          errorText.includes("UNREGISTERED") ||
          errorText.includes("registration-token-not-registered")
        ) {
          await db.prepare(
            "DELETE FROM push_devices WHERE token=?"
          ).bind(token).run();
        }
        console.error("DarkVibeX FCM send failed", {
          receiverUserId,
          status: response.status,
          error: errorText.slice(0, 300),
        });
      } catch (error) {
        console.error("DarkVibeX FCM request failed", {
          receiverUserId,
          error: String(error?.message ?? error),
        });
      }
    }),
  );
}

async function handleApi(request, env, url) {
  const db = requireDb(env);
  const parts = url.pathname.split("/").filter(Boolean);
  try {
    await ensureDeviceAllowed(db, request.headers.get("x-device-id"));
  } catch (error) {
    if (String(error?.message ?? error)==="device_banned") {
      return json({ok:false,error:"device_banned"},{status:403});
    }
    throw error;
  }

  if (url.pathname === "/api/auth/config" && request.method === "GET") {
    return json({
      ok: true,
      google_web_client_id: String(env.GOOGLE_WEB_CLIENT_ID ?? ""),
      email_otp_configured: Boolean(env.RESEND_API_KEY && env.EMAIL_FROM),
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

  if (url.pathname === "/api/push/device" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const token = String(body.token ?? "").trim();
    const platform = String(body.platform ?? "android").trim().slice(0, 24) || "android";
    const deviceKey = String(body.device_key ?? request.headers.get("x-device-id") ?? token).trim().slice(0,500);
    const enabled = body.enabled !== false;
    if (!userId || token.length < 16 || token.length > 4096) {
      return json({ ok: false, error: "invalid_push_device" }, { status: 400 });
    }
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensurePushTables(db);
    await ensureDeviceAllowed(db,deviceKey);
    try {
      const info=await db.prepare("PRAGMA table_info(push_devices)").all();
      const cols=new Set((info.results ?? []).map(row=>String(row.name ?? "")));
      if(!cols.has("device_key")) await db.prepare("ALTER TABLE push_devices ADD COLUMN device_key TEXT NOT NULL DEFAULT ''").run();
    } catch (_) {}
    if (enabled) {
      await db.batch([
        db.prepare(
          `INSERT INTO push_devices(token,user_id,device_key,platform,enabled,updated_at)
           VALUES(?,?,?,?,?,?)
           ON CONFLICT(token) DO UPDATE SET
             user_id=excluded.user_id,
             device_key=excluded.device_key,
             platform=excluded.platform,
             enabled=excluded.enabled,
             updated_at=excluded.updated_at`
        ).bind(token, userId, deviceKey, platform, 1, now()),
        db.prepare(
          `INSERT INTO push_preferences(user_id,message_enabled,updated_at)
           VALUES(?,1,?)
           ON CONFLICT(user_id) DO NOTHING`
        ).bind(userId, now()),
      ]);
    } else {
      await db.prepare(
        "DELETE FROM push_devices WHERE token=? AND user_id=?"
      ).bind(token, userId).run();
    }
    return json({ ok: true, enabled });
  }

  if (url.pathname === "/api/push/preferences" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    if (!userId) {
      return json({ ok: false, error: "user_id_required" }, { status: 400 });
    }
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensurePushTables(db);
    const enabled = body.message_enabled !== false;
    await db.prepare(
      `INSERT INTO push_preferences(user_id,message_enabled,updated_at)
       VALUES(?,?,?)
       ON CONFLICT(user_id) DO UPDATE SET
         message_enabled=excluded.message_enabled,
         updated_at=excluded.updated_at`
    ).bind(userId, enabled ? 1 : 0, now()).run();
    return json({ ok: true, message_enabled: enabled });
  }

  if (url.pathname === "/api/profile-media" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    await ensureProfileMediaTable(db);
    const targetId = String(
      url.searchParams.get("user_id") ?? session.sub ?? "",
    ).trim();
    if (!targetId) return json({ ok:false,error:"user_id_required" }, { status:400 });
    const user = await db.prepare(
      "SELECT id,avatar_key FROM users WHERE id=? LIMIT 1"
    ).bind(targetId).first();
    if (!user) return json({ ok:false,error:"user_not_found" }, { status:404 });
    const rows = await db.prepare(
      "SELECT slot,asset_key,updated_at FROM profile_media WHERE user_id=?"
    ).bind(targetId).all();
    const media = {
      avatar: user.avatar_key ? String(user.avatar_key) : null,
      cover: null,
      life_1: null,
      life_2: null,
      life_3: null,
      travel: null,
    };
    for (const row of rows.results ?? []) {
      const slot = String(row.slot ?? "");
      if (Object.prototype.hasOwnProperty.call(media, slot)) {
        media[slot] = String(row.asset_key ?? "") || null;
      }
    }
    return json({ ok:true,user_id:targetId,media });
  }

  if (url.pathname === "/api/profile-media" && request.method === "POST") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const actorId = String(session.sub);
    const body = await bodyJson(request);
    const slot = String(body.slot ?? "").trim();
    const assetKey = String(body.asset_key ?? "").trim();
    const allowed = new Set(["cover","life_1","life_2","life_3","travel"]);
    if (!allowed.has(slot)) {
      return json({ ok:false,error:"invalid_profile_media_slot" }, { status:400 });
    }
    if (!assetKey.startsWith(`users/${actorId}/profile-media-`) ||
        !/\.(jpg|jpeg|png|webp)$/i.test(assetKey)) {
      return json({ ok:false,error:"invalid_profile_media_key" }, { status:400 });
    }
    await ensureProfileMediaTable(db);
    const previous = await db.prepare(
      "SELECT asset_key FROM profile_media WHERE user_id=? AND slot=?"
    ).bind(actorId,slot).first();
    await db.prepare(
      `INSERT INTO profile_media(user_id,slot,asset_key,updated_at)
       VALUES(?,?,?,?)
       ON CONFLICT(user_id,slot) DO UPDATE SET
         asset_key=excluded.asset_key,updated_at=excluded.updated_at`
    ).bind(actorId,slot,assetKey,now()).run();
    const oldKey = String(previous?.asset_key ?? "");
    if (oldKey && oldKey !== assetKey && env.FILES) {
      try { await env.FILES.delete(oldKey); } catch (_) {}
    }
    return json({ ok:true,slot,asset_key:assetKey });
  }

  if (url.pathname === "/api/profile-media" && request.method === "DELETE") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const actorId = String(session.sub);
    const body = await bodyJson(request);
    const slot = String(body.slot ?? "").trim();
    const allowed = new Set(["cover","life_1","life_2","life_3","travel"]);
    if (!allowed.has(slot) || body.confirm_remove !== true) {
      return json({ ok:false,error:"profile_media_remove_confirmation_required" }, { status:400 });
    }
    await ensureProfileMediaTable(db);
    const previous = await db.prepare(
      "SELECT asset_key FROM profile_media WHERE user_id=? AND slot=?"
    ).bind(actorId,slot).first();
    await db.prepare(
      "DELETE FROM profile_media WHERE user_id=? AND slot=?"
    ).bind(actorId,slot).run();
    const oldKey = String(previous?.asset_key ?? "");
    if (oldKey && env.FILES) {
      try { await env.FILES.delete(oldKey); } catch (_) {}
    }
    return json({ ok:true,slot });
  }

  if (url.pathname === "/api/profile/trends" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const targetId = userId || String(session.sub);
    const user = await db.prepare("SELECT id FROM users WHERE id=? LIMIT 1")
      .bind(targetId).first();
    if (!user) return json({ ok:false,error:"user_not_found" }, { status:404 });
    return json({
      ok:true,
      trends:await profileTrends(
        db,
        targetId,
        url.searchParams.get("limit") ?? 40,
      ),
    });
  }

  if (url.pathname === "/api/profile/trends" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({
        ok:true,
        trend:await addProfileTrend(db,userId,body.text),
      }, { status:201 });
    } catch (error) {
      return json(
        { ok:false,error:String(error?.message ?? error) },
        { status:400 },
      );
    }
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
      const result=await submitFeedback(db, userId, body.category, body.message);
      await ensureOwnerControlSchema(db);
      await db.prepare(
        "INSERT INTO owner_notifications(id,kind,title,body,user_id,read_at,created_at) VALUES(?,?,?,?,?,NULL,?)"
      ).bind(id(),"complaint","User feedback / complaint",String(body.category ?? "Feedback")+": "+String(body.message ?? "").slice(0,1600),userId,now()).run();
      return json(result, { status: 201 });
    } catch (error) {
      return json({ ok: false, error: String(error?.message ?? error) }, { status: 400 });
    }
  }

  if (url.pathname === "/api/medals" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env);
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

  if (url.pathname === "/api/family/wallet/transfers" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const limit = Number(url.searchParams.get("limit") ?? 100);
    return json({
      ok: true,
      transfers: await familyWalletTransfers(db, String(session.sub), limit),
    });
  }

  if (url.pathname === "/api/family/wallet/send" && request.method === "POST") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const body = await bodyJson(request);
    try {
      return json(
        await familyTransferCoins(
          db,
          String(session.sub),
          String(body.receiver_user_id ?? "").trim(),
          body.coins,
        ),
        { status: 201 },
      );
    } catch (error) {
      const message = String(error?.message ?? error ?? "family_transfer_failed");
      const status = message === "insufficient_coins" ? 409 : 400;
      return json({ ok:false,error:message }, { status });
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
    const authError = await requireSession(request, env);
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

  if (url.pathname === "/api/vs/disconnect/request" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok:true, vs:await vsDisconnectRequest(db,userId) });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
  }

  if (url.pathname === "/api/vs/disconnect/respond" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok:true, vs:await vsDisconnectRespond(db,userId,body.accept === true) });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
  }

  if (url.pathname === "/api/vs/heartbeat" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({
        ok:true,
        vs:await vsHeartbeat(db,userId,body.action,body.choice),
      });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
  }

  if (url.pathname === "/api/vs/disconnect" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json(await vsDisconnect(db, userId));
  }

  if (url.pathname === "/api/intimacy/cards" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    const authError = await requireSession(request, env);
    if (authError) return authError;
    if (!userId) return json({ ok:false,error:"user_id_required" }, { status:400 });
    try {
      return json({ ok:true, ...(await intimacyCardState(db,userId)) });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
  }

  if (url.pathname === "/api/intimacy/cards/unlock" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok:true, ...(await unlockIntimacyCard(db,userId)) });
    } catch (error) {
      const code = String(error?.message ?? error);
      return json({ ok:false,error:code }, { status: code === "insufficient_coins" ? 409 : 400 });
    }
  }

  if (url.pathname === "/api/intimacy/cards/bind" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({
        ok:true,
        ...(await bindIntimacyCard(
          db,
          userId,
          body.slot_index,
          body.target_user_id,
          body.relation_type,
        )),
      });
    } catch (error) {
      const code = String(error?.message ?? error);
      return json({ ok:false,error:code }, { status:400 });
    }
  }

  if (url.pathname === "/api/intimacy/cards/unbind" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({
        ok:true,
        ...(await unbindIntimacyCard(db,userId,body.slot_index)),
      });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
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
    const authError = await requireSession(request, env);
    if (authError) return authError;
    return json({ ok: true, cp: await cpState(db, userId) });
  }

  if (url.pathname === "/api/cp/request" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      const cp = await cpRequest(db, userId, String(body.target_user_id ?? ""));
      const wallet = await db.prepare(
        "SELECT coins FROM users WHERE id=? LIMIT 1"
      ).bind(userId).first();
      return json({
        ok: true,
        cp,
        coin_balance: Number(wallet?.coins ?? 0),
      }, { status: 201 });
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

  if (url.pathname === "/api/cp/disconnect/request" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok:true, cp:await cpDisconnectRequest(db,userId) });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
  }

  if (url.pathname === "/api/cp/disconnect/respond" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({ ok:true, cp:await cpDisconnectRespond(db,userId,body.accept === true) });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
  }

  if (url.pathname === "/api/cp/heartbeat" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    try {
      return json({
        ok:true,
        cp:await cpHeartbeat(db,userId,body.action,body.choice),
      });
    } catch (error) {
      return json({ ok:false,error:String(error?.message ?? error) }, { status:400 });
    }
  }

  if (url.pathname === "/api/cp/disconnect" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    return json(await cpDisconnect(db, userId));
  }

  if (url.pathname === "/api/cp/ring" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const ringId = String(body.ring_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const cp = await cpState(db, userId);
    if (!cp || cp.state !== "active") {
      return json({ ok:false,error:"cp_not_active" }, { status:409 });
    }
    if (!ringId) {
      await db.prepare(
        "UPDATE cp_relationships SET ring_id=NULL,updated_at=? WHERE user_a=? AND user_b=? AND state='active'"
      ).bind(now(),cp.user_a,cp.user_b).run();
      return json({ ok:true,cp:await cpState(db,userId) });
    }
    await ensureCosmeticsSchema(db);
    const product = (await effectiveCosmeticCatalog(db)).find(
      (item) => item.id === ringId && item.kind === "ring"
    );
    if (!product) {
      return json({ ok:false,error:"ring_not_found" }, { status:404 });
    }
    const owned = await db.prepare(
      "SELECT 1 AS owned FROM user_props WHERE user_id=? AND item_id=? AND kind='ring' AND expires_at>? LIMIT 1"
    ).bind(userId,ringId,now()).first();
    if (!owned) {
      return json({ ok:false,error:"ring_not_owned" }, { status:403 });
    }
    await db.prepare(
      "UPDATE cp_relationships SET ring_id=?,updated_at=? WHERE user_a=? AND user_b=? AND state='active'"
    ).bind(ringId,now(),cp.user_a,cp.user_b).run();
    return json({ ok:true,cp:await cpState(db,userId) });
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
    await ensureOwnerControlSchema(db);
    await ensureRoomSettingsTable(db);
    await ensureImageTables(db);
    const viewer = await db.prepare(
      "SELECT country_code FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    const viewerCountry = String(viewer?.country_code ?? "").trim().toUpperCase();
    if (!viewerCountry) return json({ ok:true,rooms:[] });
    const rows = await db.prepare(
      `SELECT r.id,r.name,
              CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS display_id,
              COALESCE(io.invisible_id,0) AS owner_invisible_id,
              COALESCE(u.display_name,'Owner') AS owner_name,
              r.owner_user_id,
              COALESCE((SELECT COUNT(*) FROM room_members m WHERE m.room_id=r.id),0) AS online,
              r.seat_count,
              ri.image_key AS avatar_key,
              r.country_code,
              COALESCE(s.party_mode,'Friends-making Party') AS party_mode,
              COALESCE(s.room_mode,'voice') AS room_mode,
              rf.followed_at
         FROM room_followers rf
         JOIN rooms r ON r.id=rf.room_id
         LEFT JOIN users u ON u.id=r.owner_user_id
         LEFT JOIN owner_user_overrides io ON io.user_id=u.id
         LEFT JOIN owner_room_controls rc ON rc.room_id=r.id
         LEFT JOIN room_images ri ON ri.room_id=r.id
         LEFT JOIN room_settings s ON s.room_id=r.id
        WHERE rf.user_id=? AND r.country_code=? AND COALESCE(rc.banned,0)=0
        ORDER BY rf.updated_at DESC LIMIT 100`
    ).bind(userId,viewerCountry).all();
    const followedRooms = rows.results ?? [];
    for (const room of followedRooms) {
      const currentDisplayId = String(room.display_id ?? "").trim();
      if (Number(room.owner_invisible_id ?? 0) !== 1 && !/^[1-9]\d{6}$/.test(currentDisplayId)) {
        room.display_id = await ensureUserPublicId(db, String(room.owner_user_id ?? ""));
      }
      delete room.owner_invisible_id;
    }
    return json({ ok:true,rooms:followedRooms });
  }

  if (url.pathname === "/api/banners" && request.method === "GET") {
    const authError=await requireSession(request,env);
    if(authError)return authError;
    let rows=[];
    try {
      const result=await db.prepare(
        "SELECT id,name,sort_order,json_data,updated_at FROM owner_catalog WHERE kind='banner' AND enabled=1 ORDER BY sort_order ASC,updated_at DESC LIMIT 100"
      ).all();
      const ts=now();
      rows=(result.results ?? []).map(row=>{
        let data={};
        try{data=JSON.parse(String(row.json_data ?? "{}"))||{};}catch(_){}
        return {
          id:String(row.id),
          name:String(row.name),
          asset_key:String(data.asset_key ?? ""),
          link:String(data.link ?? ""),
          starts_at:data.starts_at==null?null:Number(data.starts_at),
          ends_at:data.ends_at==null?null:Number(data.ends_at),
          sort_order:Number(row.sort_order ?? 0),
          updated_at:Number(row.updated_at ?? 0),
        };
      }).filter(item=>
        (item.starts_at==null || item.starts_at===0 || item.starts_at<=ts) &&
        (item.ends_at==null || item.ends_at===0 || item.ends_at>=ts)
      );
    } catch(error) {
      if(!String(error?.message ?? error).includes("no such table"))throw error;
    }
    return json({ok:true,banners:rows});
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
    return json({ ok: true, items: await effectiveCosmeticCatalog(db), owned });
  }

  if (url.pathname === "/api/cosmetics/purchase" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const recipientId = String(body.recipient_user_id ?? userId).trim();
    const itemId = String(body.item_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    const product = (await effectiveCosmeticCatalog(db)).find((item) => item.id === itemId);
    if (!product) return json({ ok:false,error:"cosmetic_not_found" }, { status:404 });
    await ensureUser(db,userId);
    if (!recipientId) return json({ ok:false,error:"recipient_required" }, { status:400 });
    if (recipientId !== userId) {
      const recipient = await db.prepare("SELECT id FROM users WHERE id=?").bind(recipientId).first();
      if (!recipient) return json({ ok:false,error:"recipient_not_found" }, { status:404 });
    }
    await ensureUserAllowed(db,userId);
    await ensureWalletAllowed(db,userId);
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
    const item=(await effectiveCosmeticCatalog(db)).find((product)=>product.id===itemId);
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

  if (url.pathname === "/api/session/email/start" && request.method === "POST") {
    const body=await bodyJson(request);
    try {
      return json({
        ok:true,
        ...(await startEmailOtp(db,env,body.email,body.purpose)),
      }, { status:201 });
    } catch(error) {
      const code=String(error?.message ?? error);
      const status=code==="email_otp_not_configured" ? 503 : 400;
      return json({ok:false,error:code},{status});
    }
  }

  if (url.pathname === "/api/session/email/verify" && request.method === "POST") {
    const body=await bodyJson(request);
    try {
      return json({
        ok:true,
        ...(await verifyEmailOtpRequest(db,env,body.request_id,body.otp)),
      });
    } catch(error) {
      return json({ok:false,error:String(error?.message ?? error)},{status:400});
    }
  }

  if (url.pathname === "/api/session/email/complete" && request.method === "POST") {
    const body=await bodyJson(request);
    try {
      const setup=await consumeEmailSetupToken(db,body.setup_token);
      const email=String(setup.email);
      const purpose=String(setup.purpose);
      let credential=await db.prepare(
        "SELECT user_id FROM email_credentials WHERE email=? LIMIT 1"
      ).bind(email).first();
      let userId=String(credential?.user_id ?? "");
      if(purpose==="signup") {
        if(userId) throw new Error("email_already_registered");
        const digest=await sha256Hex(email);
        userId="e_"+digest.slice(0,20);
        const displayName=String(body.display_name ?? "DarkVibeX User").trim().slice(0,60);
        await ensureUser(db,userId,displayName || "DarkVibeX User");
      } else if(!userId) {
        throw new Error("email_account_not_found");
      }
      await setEmailPassword(db,email,userId,body.password);
      await ensureAuthIdentityTable(db);
      await db.prepare(
        `INSERT INTO user_auth_identities(provider,subject,user_id,email,created_at,updated_at)
         VALUES('email',?,?,?,?,?)
         ON CONFLICT(provider,subject) DO UPDATE SET
           user_id=excluded.user_id,email=excluded.email,updated_at=excluded.updated_at`
      ).bind(email,userId,email,now(),now()).run();
      const user=await ensureUser(db,userId,String(body.display_name ?? "").trim());
      if(body.date_of_birth) {
        await db.prepare(
          "UPDATE users SET date_of_birth=?,updated_at=? WHERE id=?"
        ).bind(String(body.date_of_birth),now(),userId).run();
      }
      const latest=await db.prepare(
        "SELECT id,public_id,display_name,role,coins,diamonds,vip_level,avatar_key,date_of_birth,country_code,country_name,flag_emoji,gender,age_change_count,country_change_count,gender_change_count,language FROM users WHERE id=?"
      ).bind(userId).first();
      const token=await createSessionToken(env,userId,latest?.display_name ?? userId);
      return json({ok:true,token,user:latest,provider:"email"});
    } catch(error) {
      const code=String(error?.message ?? error);
      return json({ok:false,error:code},{status:400});
    }
  }

  if (url.pathname === "/api/session/email/login" && request.method === "POST") {
    const body=await bodyJson(request);
    try {
      const userId=await emailPasswordLogin(db,body.email,body.password);
      await ensureUserAllowed(db,userId);
      await ensureUsersSchema(db);
      await ensureUserPublicId(db,userId);
      const user=await db.prepare(
        "SELECT id,public_id,display_name,role,coins,diamonds,vip_level,avatar_key,date_of_birth,country_code,country_name,flag_emoji,gender,age_change_count,country_change_count,gender_change_count,language FROM users WHERE id=? LIMIT 1"
      ).bind(userId).first();
      if(!user) throw new Error("user_not_found");
      const token=await createSessionToken(env,userId,user.display_name);
      return json({ok:true,token,user,provider:"email"});
    } catch(error) {
      const code=String(error?.message ?? error);
      const status=code==="user_banned"||code==="user_suspended" ? 403 : 401;
      return json({ok:false,error:code},{status});
    }
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
    const hasDob = Object.prototype.hasOwnProperty.call(body, "date_of_birth");
    const hasCountry = Object.prototype.hasOwnProperty.call(body, "country_code") ||
      Object.prototype.hasOwnProperty.call(body, "country_name");
    const hasGender = Object.prototype.hasOwnProperty.call(body, "gender");
    const hasBio = Object.prototype.hasOwnProperty.call(body, "bio");
    const hasLanguage = Object.prototype.hasOwnProperty.call(body, "language");
    const dateOfBirth = String(body.date_of_birth ?? "").trim();
    const countryCode = String(body.country_code ?? "").trim().toUpperCase();
    const countryName = String(body.country_name ?? "").trim().slice(0, 80);
    const flagEmoji = String(body.flag_emoji ?? "").trim().slice(0, 24);
    const gender = String(body.gender ?? "").trim().toLowerCase();
    const bio = String(body.bio ?? "").trim().slice(0, 160);
    const language = String(body.language ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!userId) return json({ ok:false,error:"user_id_required" }, { status:400 });
    if (!displayName) return json({ ok:false,error:"display_name_required" }, { status:400 });
    if (hasDob && !/^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth)) {
      return json({ ok:false,error:"invalid_date_of_birth" }, { status:400 });
    }
    if (hasCountry && (!/^[A-Z]{2}$/.test(countryCode) || !countryName)) {
      return json({ ok:false,error:"country_incomplete" }, { status:400 });
    }
    if (hasGender && !new Set(["male","female"]).has(gender)) {
      return json({ ok:false,error:"invalid_gender" }, { status:400 });
    }
    if (hasLanguage && !DARKVIBEX_SUPPORTED_LANGUAGES.has(language)) {
      return json({ ok:false,error:"unsupported_language" }, { status:400 });
    }

    await ensureUsersSchema(db);
    await ensureRoomCoreSchema(db);
    const current = await db.prepare(
      `SELECT date_of_birth,country_code,country_name,flag_emoji,gender,bio,language,
              age_change_count,country_change_count,gender_change_count
         FROM users WHERE id=? LIMIT 1`
    ).bind(userId).first();
    if (!current) return json({ ok:false,error:"user_not_found" }, { status:404 });

    const oldDob = String(current.date_of_birth ?? "").trim();
    const oldCountry = String(current.country_code ?? "").trim().toUpperCase();
    const oldGender = String(current.gender ?? "").trim().toLowerCase();
    const nextDob = hasDob ? dateOfBirth : oldDob;
    const nextCountry = hasCountry ? countryCode : oldCountry;
    const nextCountryName = hasCountry ? countryName : String(current.country_name ?? "").trim();
    const nextFlag = hasCountry ? flagEmoji : String(current.flag_emoji ?? "").trim();
    const nextGender = hasGender ? gender : oldGender;
    const nextBio = hasBio ? bio : String(current.bio ?? "").trim();
    const nextLanguage = hasLanguage ? language : String(current.language ?? "English").trim();

    const ageChanged = Boolean(oldDob) && nextDob !== oldDob;
    const countryChanged = Boolean(oldCountry) && nextCountry !== oldCountry;
    const genderChanged = Boolean(oldGender) && nextGender !== oldGender;
    const ageChanges = Number(current.age_change_count ?? 0);
    const countryChanges = Number(current.country_change_count ?? 0);
    const genderChanges = Number(current.gender_change_count ?? 0);

    if (ageChanged && ageChanges >= 3) {
      return json({ ok:false,error:"age_change_limit_reached",remaining:0 }, { status:409 });
    }
    if (countryChanged && countryChanges >= 3) {
      return json({ ok:false,error:"country_change_limit_reached",remaining:0 }, { status:409 });
    }
    if (genderChanged && genderChanges >= 3) {
      return json({ ok:false,error:"gender_change_limit_reached",remaining:0 }, { status:409 });
    }

    const nextAgeCount = ageChanges + (ageChanged ? 1 : 0);
    const nextCountryCount = countryChanges + (countryChanged ? 1 : 0);
    const nextGenderCount = genderChanges + (genderChanged ? 1 : 0);
    const ts = now();
    const update = await db.prepare(
      `UPDATE users
          SET display_name=?,
              date_of_birth=?,
              country_code=?,
              country_name=?,
              flag_emoji=?,
              gender=?,
              bio=?,
              language=?,
              age_change_count=?,
              country_change_count=?,
              gender_change_count=?,
              updated_at=?
        WHERE id=?
          AND age_change_count=?
          AND country_change_count=?
          AND gender_change_count=?`
    ).bind(
      displayName,
      nextDob || null,
      nextCountry || null,
      nextCountryName || null,
      nextFlag || null,
      nextGender || null,
      nextBio,
      nextLanguage || "English",
      nextAgeCount,
      nextCountryCount,
      nextGenderCount,
      ts,
      userId,
      ageChanges,
      countryChanges,
      genderChanges,
    ).run();
    if (Number(update.meta?.changes ?? 0) !== 1) {
      return json({ ok:false,error:"profile_change_conflict_retry" }, { status:409 });
    }

    if (nextCountry && nextCountry !== oldCountry) {
      await db.prepare(
        "UPDATE rooms SET country_code=?,updated_at=? WHERE owner_user_id=?"
      ).bind(nextCountry,ts,userId).run();
      await db.prepare(
        `DELETE FROM room_members
          WHERE user_id=?
            AND room_id IN (
              SELECT id FROM rooms
               WHERE country_code<>? AND owner_user_id<>?
            )`
      ).bind(userId,nextCountry,userId).run();
      await db.prepare(
        `DELETE FROM room_members
          WHERE room_id IN (SELECT id FROM rooms WHERE owner_user_id=?)
            AND user_id<>?
            AND user_id IN (
              SELECT id FROM users WHERE COALESCE(country_code,'')<>?
            )`
      ).bind(userId,userId,nextCountry).run();
    } else if (nextCountry && !oldCountry) {
      await db.prepare(
        "UPDATE rooms SET country_code=?,updated_at=? WHERE owner_user_id=? AND COALESCE(country_code,'')=''"
      ).bind(nextCountry,ts,userId).run();
    }

    const user = await db.prepare(
      "SELECT id, public_id, display_name, role, coins, diamonds, vip_level, avatar_key, date_of_birth, country_code, country_name, flag_emoji, gender, bio, age_change_count, country_change_count, gender_change_count, language FROM users WHERE id = ?"
    ).bind(userId).first();
    return json({
      ok:true,
      user,
      change_limits:{
        age_remaining:Math.max(0,3-nextAgeCount),
        country_remaining:Math.max(0,3-nextCountryCount),
        gender_remaining:Math.max(0,3-nextGenderCount),
      },
    });
  }

  if (url.pathname === "/api/users/language" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const language = String(body.language ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!userId) return json({ ok:false,error:"user_id_required" }, { status:400 });
    if (!DARKVIBEX_SUPPORTED_LANGUAGES.has(language)) {
      return json({ ok:false,error:"unsupported_language" }, { status:400 });
    }
    await ensureUsersSchema(db);
    await db.prepare(
      "UPDATE users SET language=?,updated_at=? WHERE id=?"
    ).bind(language,now(),userId).run();
    return json({ ok:true, language });
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
    await ensureUsersSchema(db);
    let viewedUserId = requestedUserId;
    let user = await db.prepare(
      "SELECT id, public_id, display_name, role, coins, diamonds, vip_level, avatar_key, date_of_birth, country_code, country_name, flag_emoji, gender, bio, age_change_count, country_change_count, gender_change_count, language FROM users WHERE id = ?"
    ).bind(viewedUserId).first();
    if (!user && requestedUserId) {
      const byStablePublicId = await db.prepare(
        "SELECT id, public_id, display_name, role, coins, diamonds, vip_level, avatar_key, date_of_birth, country_code, country_name, flag_emoji, gender, bio, age_change_count, country_change_count, gender_change_count, language FROM users WHERE public_id=? LIMIT 1"
      ).bind(requestedUserId).first();
      if (byStablePublicId) {
        user = byStablePublicId;
        viewedUserId = String(byStablePublicId.id);
      }
    }
    if (!user && requestedUserId) {
      const byVipCustomId = await db.prepare(
        `SELECT u.id,u.public_id,u.display_name,u.role,u.coins,u.diamonds,u.vip_level,u.avatar_key,u.date_of_birth,u.country_code,u.country_name,u.flag_emoji,u.gender,u.bio,u.age_change_count,u.country_change_count,u.gender_change_count,u.language
           FROM user_vip v
           JOIN users u ON u.id=v.user_id
          WHERE v.custom_id=?
            AND (v.custom_id_expires_at IS NULL OR v.custom_id_expires_at>?)
          LIMIT 1`
      ).bind(requestedUserId,now()).first();
      if (byVipCustomId) {
        user = byVipCustomId;
        viewedUserId = String(byVipCustomId.id);
      }
    }
    if (user) {
      const targetVip = await getVipStatus(db, viewedUserId);
      user.active_vip_level = targetVip.active ? targetVip.level : 0;
      user.public_id = await ensureUserPublicId(db, viewedUserId);
      user.vip_custom_id = targetVip.custom_id || null;
      user.public_id_expires_at = null;
      const owned = await ownedCosmetics(db, viewedUserId, now());
      for (const prop of owned) {
        if (!(prop.active === true || Number(prop.active ?? 0) === 1)) continue;
        user["active_" + String(prop.kind) + "_id"] = String(prop.item_id ?? "");
      }
      user.privacy_protection_enabled = targetVip.active && targetVip.level >= 15 && targetVip.preferences.privacy_protection === true;
      const ownerIdentity=await ownerIdentityMeta(db,viewedUserId);
      user.owner_tags=ownerIdentity.tags;
      user.tags=ownerIdentity.tags;
      user.invisible_id=ownerIdentity.invisible_id;
      user.wallet_frozen=ownerIdentity.wallet_frozen;
      if(ownerIdentity.invisible_id && viewerId !== viewedUserId){
        user.public_id=null;
        user.vip_custom_id=null;
      }
    }
    if (user && viewerId !== viewedUserId && url.searchParams.get("record_visit") !== "0") {
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
      const allowedPouchCoins = {
        5: [100000, 500000, 1000000, 2000000, 5000000, 8000000, 10000000],
        20: [100000, 500000, 1000000, 2000000, 5000000, 8000000, 10000000],
        50: [500000, 1000000, 2000000, 5000000, 8000000, 10000000],
        100: [1000000, 2000000, 5000000, 8000000, 10000000],
        200: [1000000, 2000000, 5000000, 8000000, 10000000],
        500: [2000000, 5000000, 8000000, 10000000],
      };
      const allowedCoins = allowedPouchCoins[slots];
      if (!Number.isSafeInteger(totalCoins) ||
          !Number.isSafeInteger(slots) ||
          !Array.isArray(allowedCoins) ||
          !allowedCoins.includes(totalCoins) ||
          !requestId) {
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

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "lucky-number") {
    const roomId = parts[2];
    await ensureRoomCoreSchema(db);
    await ensureRoomLuckyNumberTable(db);
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const userId = String(session.sub);
    const room = await db.prepare("SELECT id FROM rooms WHERE id = ?").bind(roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    const member = await db.prepare(
      "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
    ).bind(roomId, userId).first();
    if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });

    if (request.method === "GET") {
      const rows = await db.prepare(
        `SELECT id,user_id,display_name,number_value AS number,created_at
           FROM room_lucky_numbers
          WHERE room_id = ?
          ORDER BY created_at DESC
          LIMIT 50`
      ).bind(roomId).all();
      return json({ ok: true, events: rows.results ?? [] });
    }

    if (request.method === "POST") {
      const user = await db.prepare(
        "SELECT display_name FROM users WHERE id = ? LIMIT 1"
      ).bind(userId).first();
      const max = 0x100000000;
      const accepted = Math.floor(max / 100) * 100;
      const raw = new Uint32Array(1);
      do {
        crypto.getRandomValues(raw);
      } while (raw[0] >= accepted);
      const number = Number(raw[0] % 100) + 1;
      const eventId = "lucky-" + id();
      const ts = now();
      const displayName = String(user?.display_name ?? "User").trim() || "User";
      await db.batch([
        db.prepare(
          "INSERT INTO room_lucky_numbers(id,room_id,user_id,display_name,number_value,created_at) VALUES(?,?,?,?,?,?)"
        ).bind(eventId, roomId, userId, displayName, number, ts),
        db.prepare(
          `DELETE FROM room_lucky_numbers
            WHERE room_id = ?
              AND id NOT IN (
                SELECT id FROM room_lucky_numbers
                 WHERE room_id = ?
                 ORDER BY created_at DESC
                 LIMIT 100
              )`
        ).bind(roomId, roomId),
      ]);
      const rows = await db.prepare(
        `SELECT id,user_id,display_name,number_value AS number,created_at
           FROM room_lucky_numbers
          WHERE room_id = ?
          ORDER BY created_at DESC
          LIMIT 50`
      ).bind(roomId).all();
      return json({
        ok: true,
        event: {
          id: eventId,
          user_id: userId,
          display_name: displayName,
          number,
          created_at: ts,
        },
        events: rows.results ?? [],
      }, { status: 201 });
    }

    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
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
        if (!mod.isOwner && !mod.isAdmin) {
          return json({ ok: false, error: "room_moderator_required" }, { status: 403 });
        }
        const seatIndex = Number(body.seat_index);
        const roomRow = await db.prepare(
          "SELECT seat_count,owner_user_id FROM rooms WHERE id=?"
        ).bind(roomId).first();
        if (!Number.isSafeInteger(seatIndex) ||
            seatIndex < 0 ||
            seatIndex >= Number(roomRow?.seat_count ?? 0)) {
          return json({ ok: false, error: "invalid_seat_index" }, { status: 400 });
        }

        const occupant = await db.prepare(
          "SELECT m.user_id, CASE WHEN ra.user_id IS NULL THEN 0 ELSE 1 END AS is_admin FROM room_members m LEFT JOIN room_admins ra ON ra.room_id=m.room_id AND ra.user_id=m.user_id WHERE m.room_id=? AND m.seat_index=?"
        ).bind(roomId, seatIndex).first();

        if (occupant && !mod.isOwner) {
          if (String(occupant.user_id) === String(mod.room.owner_user_id)) {
            return json({ ok: false, error: "owner_seat_protected" }, { status: 403 });
          }
          if (Number(occupant.is_admin) === 1) {
            return json({ ok: false, error: "admin_seat_protected" }, { status: 403 });
          }
        }

        if (action === "seat_lock") {
          const locked = body.locked === true ? 1 : 0;
          await db.prepare(
            "INSERT INTO room_seat_controls(room_id,seat_index,locked,room_muted,updated_at) VALUES(?,?,?,0,?) ON CONFLICT(room_id,seat_index) DO UPDATE SET locked=excluded.locked,updated_at=excluded.updated_at"
          ).bind(roomId, seatIndex, locked, now()).run();
          return json({ ok: true, seat_index: seatIndex, locked: Boolean(locked) });
        }

        if (action === "seat_down") {
          if (!occupant) {
            return json({ ok: false, error: "seat_empty" }, { status: 404 });
          }
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

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "themes") {
    const roomId = parts[2];
    await ensureRoomCustomThemeTable(db);
    await ensureRoomSettingsTable(db);
    await expireRoomCustomThemes(db, roomId, now());
    const room = await db.prepare(
      "SELECT owner_user_id FROM rooms WHERE id=? LIMIT 1"
    ).bind(roomId).first();
    if (!room) return json({ ok:false,error:"room_not_found" }, { status:404 });
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
    const actorId = String(session.sub);

    if (request.method === "GET") {
      const rows = await db.prepare(
        `SELECT id,name,asset_key,price_coins,created_at,expires_at
           FROM room_custom_themes
          WHERE room_id=? AND (expires_at IS NULL OR expires_at>?)
          ORDER BY created_at DESC
          LIMIT 100`
      ).bind(roomId, now()).all();
      let globalThemes=[];
      try {
        const globalRows=await db.prepare(
          "SELECT id,name,json_data,updated_at FROM owner_catalog WHERE kind='theme' AND enabled=1 ORDER BY sort_order ASC,updated_at DESC LIMIT 100"
        ).all();
        const ts=now();
        globalThemes=(globalRows.results ?? []).map(row=>{
          let data={};
          try{data=JSON.parse(String(row.json_data ?? "{}"))||{};}catch(_){}
          return {
            id:String(row.id),
            name:String(row.name),
            asset_key:String(data.asset_key ?? data.asset ?? ""),
            price_coins:0,
            created_at:Number(row.updated_at ?? ts),
            expires_at:data.ends_at==null||Number(data.ends_at)===0?null:Number(data.ends_at),
            starts_at:data.starts_at==null?null:Number(data.starts_at),
            owner_global:true,
            permanent:data.permanent===true || data.ends_at==null || Number(data.ends_at)===0,
          };
        }).filter(theme=>
          theme.asset_key &&
          (theme.starts_at==null || theme.starts_at<=ts) &&
          (theme.expires_at==null || theme.expires_at>=ts)
        );
      } catch(error) {
        if(!String(error?.message ?? error).includes("no such table")) throw error;
      }
      return json({
        ok:true,
        user_price_coins:10000000,
        user_duration_days:7,
        themes:[...globalThemes,...(rows.results ?? [])],
      });
    }

    if (request.method === "POST") {
      if (String(room.owner_user_id) !== actorId) {
        return json({ ok:false,error:"room_owner_required" }, { status:403 });
      }
      const body = await bodyJson(request);
      const name = String(body.name ?? "").trim().slice(0, 60);
      const assetKey = String(body.asset_key ?? "").trim();
      if (!name) return json({ ok:false,error:"theme_name_required" }, { status:400 });
      if (body.policy_confirmed !== true) {
        return json({ ok:false,error:"theme_policy_confirmation_required" }, { status:400 });
      }
      if (!assetKey.startsWith(`room-themes/${actorId}/`) ||
          !/\.(jpg|jpeg|png|webp)$/i.test(assetKey)) {
        return json({ ok:false,error:"invalid_theme_asset" }, { status:400 });
      }
      const actor = await db.prepare(
        "SELECT role,coins FROM users WHERE id=? LIMIT 1"
      ).bind(actorId).first();
      if (!actor) return json({ ok:false,error:"user_not_found" }, { status:404 });
      const platformOwner = String(actor.role ?? "") === "platform_owner";
      const price = platformOwner ? 0 : 10000000;
      if (Number(actor.coins ?? 0) < price) {
        return json({ ok:false,error:"insufficient_coins",required_coins:price }, { status:409 });
      }
      const themeId = "room-theme-" + id();
      const ts = now();
      const permanent = platformOwner && body.permanent === true;
      const requestedDays = Math.max(1, Math.min(3650, Math.trunc(Number(body.duration_days ?? 7))));
      const expiresAt = permanent ? null : ts + requestedDays * 86400000;
      if (price > 0) {
        await db.batch([
          db.prepare(
            `INSERT INTO room_custom_themes(
              id,room_id,owner_user_id,name,asset_key,price_coins,created_at,expires_at
            )
            SELECT ?,?,?,?,?,?,?,?
             WHERE EXISTS(
               SELECT 1 FROM users WHERE id=? AND coins>=?
             )`
          ).bind(themeId,roomId,actorId,name,assetKey,price,ts,expiresAt,actorId,price),
          db.prepare(
            "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM room_custom_themes WHERE id=?)"
          ).bind(price,ts,actorId,themeId),
          db.prepare(
            `INSERT INTO wallet_ledger(
              id,user_id,kind,amount,balance_after,reference_id,created_at
            )
            SELECT ?,u.id,'room_theme_purchase',?,u.coins,?,?
              FROM users u
             WHERE u.id=? AND EXISTS(SELECT 1 FROM room_custom_themes WHERE id=?)`
          ).bind(id(),-price,themeId,ts,actorId,themeId),
        ]);
      } else {
        await db.prepare(
          `INSERT INTO room_custom_themes(
            id,room_id,owner_user_id,name,asset_key,price_coins,created_at,expires_at
          ) VALUES(?,?,?,?,?,?,?,?)`
        ).bind(themeId,roomId,actorId,name,assetKey,price,ts,expiresAt).run();
      }
      const created = await db.prepare(
        "SELECT id,name,asset_key,price_coins,created_at,expires_at FROM room_custom_themes WHERE id=?"
      ).bind(themeId).first();
      if (!created) {
        return json({ ok:false,error:"insufficient_coins",required_coins:price }, { status:409 });
      }
      const balance = await db.prepare("SELECT coins FROM users WHERE id=?").bind(actorId).first();
      return json({
        ok:true,
        theme:created,
        coin_balance:Number(balance?.coins ?? 0),
      }, { status:201 });
    }

    return json({ ok:false,error:"method_not_allowed" }, { status:405 });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "settings") {
    const roomId = parts[2];
    await ensureRoomSettingsTable(db);
    await ensureRoomCustomThemeTable(db);
    await expireRoomCustomThemes(db, roomId, now());
    await ensureVipSchema(db);
    const room = await db.prepare(
      `SELECT r.id, r.owner_user_id, r.name, r.seat_count, r.locked,
              COALESCE(s.announcement, '') AS announcement, COALESCE(s.theme_id, 'dark') AS theme_id, COALESCE(s.group_pk_enabled, 0) AS group_pk_enabled,
              COALESCE(s.party_mode, 'Friends-making Party') AS party_mode,
              COALESCE(s.room_mode, 'voice') AS room_mode,
              COALESCE(s.seat_theme_id, 'royal-gold') AS seat_theme_id,
              COALESCE(ct.asset_key, '') AS theme_asset_key,
              COALESCE(s.lock_password_code, '') AS lock_password_code,
              CASE WHEN COALESCE(s.lock_password_hash, '') <> '' THEN 1 ELSE 0 END AS lock_password_set,
              CASE WHEN ov.level >= 5 AND ov.active_until > ? THEN COALESCE(s.welcome_image_key, '') ELSE '' END AS welcome_image_key
         FROM rooms r LEFT JOIN room_settings s ON s.room_id = r.id
         LEFT JOIN user_vip ov ON ov.user_id = r.owner_user_id
         LEFT JOIN room_custom_themes ct ON ct.id = s.theme_id
          AND ct.room_id = r.id AND (ct.expires_at IS NULL OR ct.expires_at > ?)
        WHERE r.id = ?`
    ).bind(now(), now(), roomId).first();
    if (!room) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    if (request.method === "GET") {
      const authError = await requireSession(request, env);
      if (authError) return authError;
      const session = await verifySessionToken(bearerToken(request), String(env.SESSION_SECRET));
      const member = await db.prepare(
        "SELECT 1 AS active FROM room_members WHERE room_id = ? AND user_id = ?"
      ).bind(roomId, String(session.sub)).first();
      if (!member) return json({ ok: false, error: "room_membership_required" }, { status: 403 });
      const settings = { ...room };
      delete settings.lock_password_code;
      if (String(session.sub) === String(room.owner_user_id) && Number(room.locked) === 1) {
        settings.lock_code = String(room.lock_password_code ?? "");
      }
      return json({ ok: true, settings });
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
        "SELECT COALESCE(lock_password_hash,'') AS lock_password_hash,COALESCE(lock_password_code,'') AS lock_password_code FROM room_settings WHERE room_id=?"
      ).bind(roomId).first();
      let lockPasswordHash = String(priorLock?.lock_password_hash ?? "");
      let lockPasswordCode = String(priorLock?.lock_password_code ?? "");
      if (actorIsOwner) {
        if (locked === 1) {
          if (Number(room.locked ?? 0) !== 1 || !lockPasswordHash || !/^\d{5}$/.test(lockPasswordCode)) {
            lockPasswordCode = randomFiveDigitRoomCode();
            lockPasswordHash = await sha256Hex(lockPasswordCode);
          }
        } else {
          lockPasswordHash = "";
          lockPasswordCode = "";
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
      let customTheme = null;
      if (!allowedThemes.has(themeId)) {
        customTheme = await db.prepare(
          "SELECT id FROM room_custom_themes WHERE id=? AND room_id=? AND (expires_at IS NULL OR expires_at>?) LIMIT 1"
        ).bind(themeId,roomId,now()).first();
        if (!customTheme) return json({ ok:false,error:"invalid_or_expired_theme" }, { status:400 });
      }
      if (allowedThemes.has(themeId) &&
          themeId !== "dark" &&
          themeId !== room.theme_id &&
          !vipStatus.room_background_enabled) {
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
          "INSERT INTO room_settings (room_id, announcement, theme_id, group_pk_enabled, welcome_image_key, party_mode, room_mode, seat_theme_id, lock_password_hash, lock_password_code, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(room_id) DO UPDATE SET announcement = excluded.announcement, theme_id = excluded.theme_id, group_pk_enabled = excluded.group_pk_enabled, welcome_image_key = excluded.welcome_image_key, party_mode = excluded.party_mode, room_mode = excluded.room_mode, seat_theme_id = excluded.seat_theme_id, lock_password_hash = excluded.lock_password_hash, lock_password_code = excluded.lock_password_code, updated_at = excluded.updated_at"
        ).bind(roomId, announcement, themeId, groupPkEnabled, welcomeImageKey, partyMode, roomMode, seatThemeId, lockPasswordHash, lockPasswordCode, ts),
      ]);
      return json({
        ok: true,
        settings: {
          ...room,
          name,
          seat_count: seatCount,
          locked,
          announcement,
          theme_id: themeId,
          group_pk_enabled: groupPkEnabled,
          welcome_image_key: welcomeImageKey,
          party_mode: partyMode,
          room_mode: roomMode,
          seat_theme_id: seatThemeId,
          lock_password_set: lockPasswordHash ? 1 : 0,
          ...(actorIsOwner && locked === 1 ? { lock_code: lockPasswordCode } : {}),
        },
      });
    }
    return json({ ok: false, error: "method_not_allowed" }, { status: 405 });
  }

  if (url.pathname === "/api/rooms" && request.method === "GET") {
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    return json({
      ok:true,
      rooms:await listRooms(db,String(session.sub)),
    });
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
    const ownerProfile = await db.prepare(
      "SELECT country_code,public_id FROM users WHERE id=? LIMIT 1"
    ).bind(ownerId).first();
    const ownerCountry = String(ownerProfile?.country_code ?? "").trim().toUpperCase();
    const ownerPublicId = /^[1-9]\d{6}$/.test(String(ownerProfile?.public_id ?? "").trim())
      ? String(ownerProfile.public_id).trim()
      : await ensureUserPublicId(db, ownerId);
    if (!ownerCountry) {
      return json({ ok:false,error:"country_required_for_room" }, { status:409 });
    }

    const seatCount = requestedSeatCount;
    const roomId = ownerPublicId;
    await ensureOwnerControlSchema(db);
    const existingRoomId = await db.prepare(
      "SELECT owner_user_id FROM rooms WHERE id=? LIMIT 1"
    ).bind(roomId).first();
    if (existingRoomId) {
      return json({ ok: false, error: "room_id_taken" }, { status: 409 });
    }
    await db.prepare("DELETE FROM owner_room_controls WHERE room_id=?").bind(roomId).run();

    const ts = now();
    try {
      await db.batch([
        db.prepare(
          "INSERT INTO rooms (id, owner_user_id, name, seat_count, locked, country_code, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?, ?)"
        ).bind(roomId, ownerId, name, seatCount, ownerCountry, ts, ts),
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
    return json({ ok: true, room_id: roomId, display_id: ownerPublicId, party_mode: partyMode, room_mode: roomMode }, { status: 201 });
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
    await ensureOwnerControlSchema(db);
    await ensureRoomSettingsTable(db);
    const roomAccess = await db.prepare(
      `SELECT r.owner_user_id,r.locked,r.country_code,
              COALESCE(rc.banned,0) AS owner_room_banned,
              COALESCE(s.lock_password_hash,'') AS lock_password_hash
         FROM rooms r
         LEFT JOIN room_settings s ON s.room_id=r.id
         LEFT JOIN owner_room_controls rc ON rc.room_id=r.id
        WHERE r.id=?`
    ).bind(roomId).first();
    if (!roomAccess) return json({ ok: false, error: "room_not_found" }, { status: 404 });
    if (Number(roomAccess.owner_room_banned ?? 0)===1) {
      return json({ok:false,error:"room_banned"},{status:403});
    }
    const userCountryRow = await db.prepare(
      "SELECT country_code FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    const userCountry = String(userCountryRow?.country_code ?? "").trim().toUpperCase();
    const roomCountry = String(roomAccess.country_code ?? "").trim().toUpperCase();
    if (!userCountry || !roomCountry || userCountry !== roomCountry) {
      return json({ ok:false,error:"room_country_mismatch" }, { status:403 });
    }
    await ensureRoomSafetyTables(db);
    const roomBan = await db.prepare(
      "SELECT 1 AS blocked FROM room_bans WHERE room_id = ? AND user_id = ?"
    ).bind(roomId, userId).first();
    if (roomBan && roomAccess.owner_user_id !== userId) {
      return json({ ok: false, error: "room_blocked" }, { status: 403 });
    }
    let ownerLockedBypass=false;
    try {
      await ensureOwnerControlSchema(db);
      const override=await db.prepare("SELECT locked_room_bypass FROM owner_user_overrides WHERE user_id=?").bind(userId).first();
      ownerLockedBypass=Number(override?.locked_room_bypass ?? 0)===1;
    } catch (_) {}
    if (Number(roomAccess.locked) === 1 && roomAccess.owner_user_id !== userId && !ownerLockedBypass) {
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
    // Exit is intentionally idempotent: if the member was already removed,
    // the client is still fully outside the room and should be allowed to close.
    return json({
      ok: true,
      left: Number(result.meta?.changes ?? 0) > 0,
    });
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
    const member = await db.prepare("SELECT seat_index FROM room_members WHERE room_id = ? AND user_id = ?")
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
      const moderator = await roomModeratorState(db, roomId, userId);
      if (Number(seatControl?.locked ?? 0) === 1 &&
          !stayingOnSameSeat &&
          !moderator.isOwner &&
          !moderator.isAdmin) {
        return json({ ok:false,error:"seat_locked" }, { status:409 });
      }
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
           LEFT JOIN owner_user_overrides io ON io.user_id = m.user_id
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
      await ensureOwnerControlSchema(db);
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
                CASE WHEN COALESCE(io.invisible_id,0)=1
                     THEN 'Hidden'
                     ELSE COALESCE(NULLIF(u.public_id,''), m.user_id)
                END AS public_id,
                COALESCE(io.invisible_id,0) AS owner_invisible_id,
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
           LEFT JOIN owner_user_overrides io ON io.user_id = m.user_id
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
    try {
      await sendDirectMessagePush(env, db, {
        receiverUserId: receiver,
        senderUserId: sender,
        messageId,
        preview: textValue || (imageKey ? "📷 Photo" : "You received a new message."),
      });
    } catch (error) {
      console.error("DarkVibeX message push failed", {
        receiver,
        messageId,
        error: String(error?.message ?? error),
      });
    }
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

  const gameRoomMatch = url.pathname.match(/^\/api\/game-rooms\/([^/]+)(?:\/(join|leave|tap|messages))?$/);
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

  if (gameRoomMatch && gameRoomMatch[2] === "leave" && request.method === "POST") {
    const roomId = decodeURIComponent(gameRoomMatch[1]);
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await db.prepare(
      "CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))"
    ).run();
    await db.prepare(
      "DELETE FROM game_room_members WHERE room_id=? AND user_id=?"
    ).bind(roomId,userId).run();
    await ensureLudoSchema(db);
    await db.prepare(
      "DELETE FROM ludo_room_players WHERE room_id=? AND user_id=?"
    ).bind(roomId,userId).run();
    return json({ ok:true });
  }

  if (gameRoomMatch && gameRoomMatch[2] === "messages") {
    const roomId = decodeURIComponent(gameRoomMatch[1]);
    await db.prepare(
      "CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))"
    ).run();
    await db.prepare(
      `CREATE TABLE IF NOT EXISTS game_room_messages (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )`
    ).run();
    await db.prepare(
      "CREATE INDEX IF NOT EXISTS idx_game_room_messages_room_time ON game_room_messages(room_id,created_at DESC)"
    ).run();

    if (request.method === "GET") {
      const userId = String(url.searchParams.get("user_id") ?? "").trim();
      const authError = await requireSession(request, env, userId);
      if (authError) return authError;
      const member = await db.prepare(
        "SELECT 1 AS active FROM game_room_members WHERE room_id=? AND user_id=? LIMIT 1"
      ).bind(roomId,userId).first();
      if (!member) return json({ ok:false,error:"room_membership_required" }, { status:403 });
      const rows = await db.prepare(
        `SELECT m.id,m.user_id,m.text,m.created_at,
                COALESCE(u.display_name,'User') AS display_name,
                u.avatar_key
           FROM game_room_messages m
           LEFT JOIN users u ON u.id=m.user_id
          WHERE m.room_id=?
          ORDER BY m.created_at DESC
          LIMIT 100`
      ).bind(roomId).all();
      return json({ ok:true,messages:[...(rows.results ?? [])].reverse() });
    }

    if (request.method === "POST") {
      const body = await bodyJson(request);
      const userId = String(body.user_id ?? "").trim();
      const textValue = String(body.text ?? "").trim().slice(0,500);
      const authError = await requireSession(request, env, userId);
      if (authError) return authError;
      if (!textValue) return json({ ok:false,error:"message_required" }, { status:400 });
      const member = await db.prepare(
        "SELECT 1 AS active FROM game_room_members WHERE room_id=? AND user_id=? LIMIT 1"
      ).bind(roomId,userId).first();
      if (!member) return json({ ok:false,error:"room_membership_required" }, { status:403 });
      const messageId = id();
      const createdAt = now();
      await db.prepare(
        "INSERT INTO game_room_messages(id,room_id,user_id,text,created_at) VALUES(?,?,?,?,?)"
      ).bind(messageId,roomId,userId,textValue,createdAt).run();
      return json({ ok:true,id:messageId,created_at:createdAt }, { status:201 });
    }

    return json({ ok:false,error:"method_not_allowed" }, { status:405 });
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

    const callId = id();
    const createdAt = now();
    await db.prepare(
      `INSERT INTO direct_calls
        (id,caller_user_id,receiver_user_id,state,created_at,answered_at,ended_at,updated_at,
         call_kind,cost_coins_per_minute,receiver_diamonds_per_minute,
         receiver_earning_eligible,billed_minutes,caller_cost_coins,receiver_reward_diamonds)
       VALUES(?,?,?,'ringing',?,NULL,NULL,?,'direct',400000,0,0,0,0,0)`
    ).bind(callId,callerId,receiverId,createdAt,createdAt).run();
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
    if (!accepted) {
      return json({ ok:true,call:await directCallRow(db,callId) });
    }
    return json({ ok:true,call:await settleDirectCallBilling(db, callId, ts) });
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
    }
    await db.prepare(
      "UPDATE direct_calls SET state='ended',ended_at=?,updated_at=? WHERE id=? AND state IN ('ringing','active')"
    ).bind(ts,ts,callId).run();
    return json({ ok:true,call:await directCallRow(db,callId) });
  }

  if (url.pathname === "/api/friends" && request.method === "GET") {
    const userId = String(url.searchParams.get("user_id") ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    await ensureTinniSocialSchema(db);
    const vip = await getVipStatus(db, userId, now());
    const friends = await db.prepare(
      `SELECT u.id,
              CASE WHEN COALESCE(io.invisible_id,0)=1 THEN 'Hidden' ELSE u.public_id END AS public_id,
              u.display_name,u.avatar_key,u.vip_level,
              MAX(a.created_at,b.created_at) AS created_at
         FROM user_follows a
         JOIN user_follows b
           ON b.follower_id=a.target_id
          AND b.target_id=a.follower_id
         JOIN users u ON u.id=a.target_id
         LEFT JOIN owner_user_overrides io ON io.user_id=u.id
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
    const authError = await requireSession(request, env);
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
    await ensureWalletAllowed(db,userId);
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
    await ensureRoomCoreSchema(db);
    await ensureOwnerControlSchema(db);
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const viewer = await db.prepare(
      "SELECT country_code FROM users WHERE id=? LIMIT 1"
    ).bind(String(session.sub)).first();
    const viewerCountry = String(viewer?.country_code ?? "").trim().toUpperCase();
    let rows;
    if (kind === "room") {
      if (!viewerCountry) return json({ ok:true,kind,period,ranking:[] });
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
           LEFT JOIN owner_room_controls rc ON rc.room_id=r.id
          WHERE r.country_code=? AND COALESCE(rc.banned,0)=0
          ORDER BY score DESC, online DESC, r.updated_at DESC
          LIMIT 100`
      ).bind(cutoff,viewerCountry).all();
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
        ...(await effectiveGiftCatalog(db)).filter((gift) =>
          Number(gift.vip_level ?? 0) === 0 || (vip.active && vip.level >= Number(gift.vip_level))),
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
    let gift = (await effectiveGiftCatalog(db)).find((item) => item.id === giftId) ?? null;
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
    await ensureWalletAllowed(db, sender);
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
    let cpProgress = null;
    let vsProgress = null;
    // DarkVibeX relation levels are partner-only, not gift-category-only.
    // Any real gift sent directly between the active CP pair can advance CP,
    // and any real gift sent directly between the active VS pair can advance VS.
    // Third-party gifts never match the relationship pair and therefore add 0.
    if (giftId !== "cp-invite") {
      cpProgress = await recordCpGiftProgress(
        db,
        sender,
        receiver,
        cost,
        eventId,
      );
      vsProgress = await recordVsGiftProgress(
        db,
        sender,
        receiver,
        cost,
        eventId,
      );
    }
    return json({
      ok: true,
      event_id: eventId,
      sender_coin_balance: balance,
      cp_progress: Number(cpProgress?.progress ?? 0),
      cp_state: cpProgress?.cp ?? null,
      vs_progress: Number(vsProgress?.progress ?? 0),
      vs_state: vsProgress?.vs ?? null,
    });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo") {
    const roomId = String(parts[2] ?? "").trim();
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const userId = String(session.sub);
    const gamesFeature = await ownerSetting(db, "feature.games", { enabled: true });
    const ludoConfig = await ownerGameConfig(db,"ludo",{enabled:true});
    if (gamesFeature.enabled === false || ludoConfig.enabled === false) {
      return json({ ok:false,error:"games_disabled" }, { status:403 });
    }

    try {
      await ensureLudoSchema(db);
      await requireLudoRoomMember(db, roomId, userId);

      if (parts.length === 4 && request.method === "GET") {
        const color = await ensureLudoPlayer(db, roomId, userId);
        const state = await publicLudoState(db, roomId, userId);
        if (!color) state.spectator = true;
        return json(state);
      }

      if (parts.length === 5 && parts[4] === "roll" && request.method === "POST") {
        const color = await ensureLudoPlayer(db, roomId, userId);
        if (!color) return json({ ok:false,error:"ludo_table_full" }, { status:409 });
        const loaded = await loadLudoState(db, roomId);
        if (loaded.state.winner) return json(await publicLudoState(db, roomId, userId, loaded));
        if (String(loaded.state.current_player) !== color) {
          return json({ ok:false,error:"not_your_turn",state:await publicLudoState(db,roomId,userId,loaded) }, { status:409 });
        }
        if (loaded.state.rolled != null) {
          return json(await publicLudoState(db, roomId, userId, loaded));
        }
        loaded.state.rolled = await secureDieRoll();
        loaded.state.status = color.toUpperCase() + " rolled " + loaded.state.rolled + ".";
        if (ludoMovableIndexes(loaded.state).length === 0) {
          await ludoAdvancePlayer(db, roomId, loaded.state, false);
        }
        const saved = await saveLudoState(
          db, roomId, loaded.state, loaded.version,
        );
        return json(await publicLudoState(db, roomId, userId, saved));
      }

      if (parts.length === 5 && parts[4] === "move" && request.method === "POST") {
        const color = await ensureLudoPlayer(db, roomId, userId);
        if (!color) return json({ ok:false,error:"ludo_table_full" }, { status:409 });
        const body = await bodyJson(request);
        const tokenIndex = Number(body.token_index);
        if (!Number.isInteger(tokenIndex) || tokenIndex < 0 || tokenIndex > 3) {
          return json({ ok:false,error:"invalid_ludo_token" }, { status:400 });
        }
        const loaded = await loadLudoState(db, roomId);
        if (loaded.state.winner) return json(await publicLudoState(db, roomId, userId, loaded));
        if (String(loaded.state.current_player) !== color) {
          return json({ ok:false,error:"not_your_turn",state:await publicLudoState(db,roomId,userId,loaded) }, { status:409 });
        }
        const dice = Number(loaded.state.rolled ?? 0);
        if (!dice) return json({ ok:false,error:"roll_dice_first" }, { status:409 });
        const movable = ludoMovableIndexes(loaded.state);
        if (!movable.includes(tokenIndex)) {
          return json({ ok:false,error:"token_cannot_move" }, { status:409 });
        }

        const tokens = loaded.state.tokens[color];
        const current = Number(tokens[tokenIndex]);
        const next = current < 0 ? 0 : current + dice;
        tokens[tokenIndex] = next;

        if (next < 52) {
          const sharedIndex = ludoTrackIndex(color, next);
          if (!LUDO_SAFE_TRACK.has(sharedIndex)) {
            for (const opponent of LUDO_COLORS) {
              if (opponent === color) continue;
              for (let index = 0; index < loaded.state.tokens[opponent].length; index += 1) {
                const progress = Number(loaded.state.tokens[opponent][index]);
                if (
                  progress >= 0 &&
                  progress < 52 &&
                  ludoTrackIndex(opponent, progress) === sharedIndex
                ) {
                  loaded.state.tokens[opponent][index] = -1;
                }
              }
            }
          }
        }

        if (loaded.state.tokens[color].every((progress) => Number(progress) >= 57)) {
          loaded.state.winner = color;
          loaded.state.rolled = null;
          loaded.state.status = color.toUpperCase() + " wins!";
        } else {
          loaded.state.status =
            color.toUpperCase() + " moved token " + (tokenIndex + 1) + ".";
          await ludoAdvancePlayer(db, roomId, loaded.state, dice === 6);
        }
        const saved = await saveLudoState(
          db, roomId, loaded.state, loaded.version,
        );
        return json(await publicLudoState(db, roomId, userId, saved));
      }

      if (parts.length === 5 && parts[4] === "leave" && request.method === "POST") {
        const player = await db.prepare(
          "SELECT color FROM ludo_room_players WHERE room_id=? AND user_id=? LIMIT 1"
        ).bind(roomId, userId).first();
        if (!player) return json({ ok:true });
        const color = String(player.color);
        await db.prepare(
          "DELETE FROM ludo_room_players WHERE room_id=? AND user_id=?"
        ).bind(roomId, userId).run();
        const loaded = await loadLudoState(db, roomId);
        loaded.state.tokens[color] = [-1, -1, -1, -1];
        if (loaded.state.current_player === color) {
          loaded.state.rolled = null;
          await ludoAdvancePlayer(db, roomId, loaded.state, false);
        }
        const any = await db.prepare(
          "SELECT 1 AS yes FROM ludo_room_players WHERE room_id=? LIMIT 1"
        ).bind(roomId).first();
        if (!any) loaded.state = ludoInitialState();
        try {
          await saveLudoState(db, roomId, loaded.state, loaded.version);
        } catch (_) {}
        return json({ ok:true });
      }

      if (parts.length === 5 && parts[4] === "reset" && request.method === "POST") {
        const room = await requireLudoRoomMember(db, roomId, userId);
        if (String(room.owner_user_id) !== userId) {
          return json({ ok:false,error:"room_owner_required" }, { status:403 });
        }
        const loaded = await loadLudoState(db, roomId);
        const state = ludoInitialState();
        const occupied = await ludoOccupiedColors(db, roomId);
        if (!occupied.has("red") && occupied.size > 0) {
          state.current_player = LUDO_COLORS.find((color) => occupied.has(color)) ?? "red";
          state.status = state.current_player.toUpperCase() + " starts. Roll the dice.";
        }
        const saved = await saveLudoState(db, roomId, state, loaded.version);
        return json(await publicLudoState(db, roomId, userId, saved));
      }

      return json({ ok:false,error:"method_not_allowed" }, { status:405 });
    } catch (error) {
      const message = String(error?.message ?? error ?? "ludo_error");
      const status = message === "room_not_found" ? 404 :
        message === "room_membership_required" ? 403 :
        message === "game_state_changed" ? 409 : 400;
      return json({ ok:false,error:message }, { status });
    }
  }

  if (url.pathname === "/api/games/fruit-party/state" && request.method === "GET") {
    const gamesFeature = await ownerSetting(db, "feature.games", { enabled: true });
    const gameConfig = await ownerGameConfig(db,"fruit-party",{enabled:true,min_bet:Math.min(...FRUIT_PARTY_BET_AMOUNTS),max_bet:Math.max(...FRUIT_PARTY_BET_AMOUNTS)});
    if (gamesFeature.enabled === false || gameConfig.enabled === false) {
      return json({ ok:false,error:"games_disabled" }, { status:403 });
    }
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const userId = String(session.sub);
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    return json(await fruitPartyState(db, userId, now()));
  }

  if (url.pathname === "/api/games/fruit-party/bet" && request.method === "POST") {
    const gamesFeature = await ownerSetting(db, "feature.games", { enabled: true });
    const gameConfig = await ownerGameConfig(db,"fruit-party",{enabled:true,min_bet:Math.min(...FRUIT_PARTY_BET_AMOUNTS),max_bet:Math.max(...FRUIT_PARTY_BET_AMOUNTS)});
    if (gamesFeature.enabled === false || gameConfig.enabled === false) {
      return json({ ok:false,error:"games_disabled" }, { status:403 });
    }
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const fruitKey = String(body.fruit_key ?? "").trim();
    const amount = Number(body.amount ?? 0);
    const requestId = String(body.request_id ?? "").trim();
    const compactResponse = body.compact_response === true;
    // Compact response is opt-in so older APKs keep the full Greedy Girl state contract.
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!FRUIT_PARTY_BY_KEY.has(fruitKey) ||
        !FRUIT_PARTY_BET_AMOUNTS.includes(amount) ||
        amount < gameConfig.min_bet || amount > gameConfig.max_bet ||
        !/^[a-zA-Z0-9_-]{16,96}$/.test(requestId)) {
      return json({ ok:false,error:"invalid_bet" }, { status:400 });
    }
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    await ensureWalletAllowed(db,userId);
    await ensureFruitPartySchema(db);
    const ts = now();
    await syncFruitParty(db, ts);
    const roundId = fruitPartyRoundId(ts);
    if (ts >= fruitPartyBetEnd(roundId)) {
      return json(
        { ok:false,error:"betting_locked",state:await fruitPartyState(db,userId,ts) },
        { status:409 },
      );
    }
    const betId = `fruit-party:${userId}:${requestId}`;
    const prior = await db.prepare(
      "SELECT id FROM fruit_party_bets WHERE user_id=? AND request_id=? LIMIT 1"
    ).bind(userId, requestId).first();
    if (prior) return json(await fruitPartyState(db, userId, ts));

    try {
      await db.batch([
        db.prepare(
          `INSERT INTO fruit_party_bets(
            id,request_id,round_id,user_id,fruit_key,amount,created_at
          )
          SELECT ?,?,?,?,?,?,?
           WHERE EXISTS(SELECT 1 FROM users WHERE id=? AND coins>=?)`
        ).bind(
          betId,requestId,roundId,userId,fruitKey,amount,ts,userId,amount,
        ),
        db.prepare(
          "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM fruit_party_bets WHERE id=?)"
        ).bind(amount,ts,userId,betId),
        db.prepare(
          `INSERT INTO wallet_ledger(
            id,user_id,kind,amount,balance_after,reference_id,created_at
          )
          SELECT ?,u.id,'fruit_party_bet',?,u.coins,?,?
            FROM users u
           WHERE u.id=? AND EXISTS(SELECT 1 FROM fruit_party_bets WHERE id=?)`
        ).bind(id(),-amount,betId,ts,userId,betId),
      ]);
    } catch (error) {
      const duplicate = await db.prepare(
        "SELECT id FROM fruit_party_bets WHERE user_id=? AND request_id=? LIMIT 1"
      ).bind(userId, requestId).first();
      if (!duplicate) throw error;
      return json(await fruitPartyState(db, userId, now()));
    }
    const accepted = await db.prepare(
      "SELECT id FROM fruit_party_bets WHERE id=? LIMIT 1"
    ).bind(betId).first();
    if (!accepted) {
      return json(
        { ok:false,error:"insufficient_coins",state:await fruitPartyState(db,userId,ts) },
        { status:409 },
      );
    }
    return json(await fruitPartyState(db, userId, now()), { status:201 });
  }


  if (url.pathname === "/api/games/greedy-girl/state" && request.method === "GET") {
    const gamesFeature = await ownerSetting(db, "feature.games", { enabled: true });
    const gameConfig = await ownerGameConfig(db,"greedy-girl",{enabled:true,min_bet:Math.min(...GREEDY_GIRL_BET_AMOUNTS),max_bet:Math.max(...GREEDY_GIRL_BET_AMOUNTS)});
    if (gamesFeature.enabled === false || gameConfig.enabled === false) {
      return json({ ok:false,error:"games_disabled" }, { status:403 });
    }
    const authError = await requireSession(request, env);
    if (authError) return authError;
    const session = await verifySessionToken(
      bearerToken(request),
      String(env.SESSION_SECRET),
    );
    const userId = String(session.sub);
    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    return json(await greedyGirlState(db, userId, now()));
  }

  if (url.pathname === "/api/games/greedy-girl/bet" && request.method === "POST") {
    const gamesFeature = await ownerSetting(db, "feature.games", { enabled: true });
    const gameConfig = await ownerGameConfig(db,"greedy-girl",{enabled:true,min_bet:Math.min(...GREEDY_GIRL_BET_AMOUNTS),max_bet:Math.max(...GREEDY_GIRL_BET_AMOUNTS)});
    if (gamesFeature.enabled === false || gameConfig.enabled === false) {
      return json({ ok:false,error:"games_disabled" }, { status:403 });
    }
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const foodKey = String(body.food_key ?? "").trim();
    const amount = Number(body.amount ?? 0);
    const requestId = String(body.request_id ?? "").trim();
    const authError = await requireSession(request, env, userId);
    if (authError) return authError;
    if (!GREEDY_GIRL_BY_KEY.has(foodKey) ||
        !GREEDY_GIRL_BET_AMOUNTS.includes(amount) ||
        amount < gameConfig.min_bet || amount > gameConfig.max_bet ||
        !/^[a-zA-Z0-9_-]{16,96}$/.test(requestId)) {
      return json({ ok:false,error:"invalid_bet" }, { status:400 });
    }

    await ensureUser(db, userId);
    await ensureUserAllowed(db, userId);
    await ensureWalletAllowed(db,userId);
    await ensureGreedyGirlSchema(db);
    const ts = now();
    const roundId = greedyGirlRoundId(ts);

    // Normal bet placement stays lightweight. Settle only the immediately
    // previous round here; full history/state reconciliation is handled by
    // the state endpoint and result phase.
    if (roundId > 0) {
      await settleGreedyGirlRound(db, roundId - 1);
    }
    if (ts >= greedyGirlBetEnd(roundId)) {
      return json(
        { ok:false,error:"betting_locked",state:await greedyGirlState(db,userId,ts) },
        { status:409 },
      );
    }

    const prior = await db.prepare(
      "SELECT round_id,food_key,amount FROM greedy_girl_bets WHERE user_id=? AND request_id=? LIMIT 1"
    ).bind(userId, requestId).first();
    if (prior) {
      if (!compactResponse) {
        return json(await greedyGirlState(db, userId, now()));
      }
      const wallet = await db.prepare(
        "SELECT coins FROM users WHERE id=? LIMIT 1"
      ).bind(userId).first();
      return json({
        ok:true,
        server_time:now(),
        wallet_balance:Number(wallet?.coins ?? 0),
        accepted_bet:{
          round_id:Number(prior.round_id),
          food_key:String(prior.food_key),
          amount:Number(prior.amount ?? 0),
        },
      });
    }

    const betId = `greedy-girl:${userId}:${requestId}`;
    try {
      await db.batch([
        db.prepare(
          `INSERT INTO greedy_girl_bets(
            id,request_id,round_id,user_id,food_key,amount,created_at
          )
          SELECT ?,?,?,?,?,?,?
           WHERE EXISTS(SELECT 1 FROM users WHERE id=? AND coins>=?)`
        ).bind(
          betId,requestId,roundId,userId,foodKey,amount,ts,userId,amount,
        ),
        db.prepare(
          "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM greedy_girl_bets WHERE id=?)"
        ).bind(amount,ts,userId,betId),
        db.prepare(
          `INSERT INTO wallet_ledger(
            id,user_id,kind,amount,balance_after,reference_id,created_at
          )
          SELECT ?,u.id,'greedy_girl_bet',?,u.coins,?,?
            FROM users u
           WHERE u.id=? AND EXISTS(SELECT 1 FROM greedy_girl_bets WHERE id=?)`
        ).bind(id(),-amount,betId,ts,userId,betId),
      ]);
    } catch (error) {
      const duplicate = await db.prepare(
        "SELECT round_id,food_key,amount FROM greedy_girl_bets WHERE user_id=? AND request_id=? LIMIT 1"
      ).bind(userId, requestId).first();
      if (!duplicate) throw error;
      if (!compactResponse) {
        return json(await greedyGirlState(db, userId, now()));
      }
      const wallet = await db.prepare(
        "SELECT coins FROM users WHERE id=? LIMIT 1"
      ).bind(userId).first();
      return json({
        ok:true,
        server_time:now(),
        wallet_balance:Number(wallet?.coins ?? 0),
        accepted_bet:{
          round_id:Number(duplicate.round_id),
          food_key:String(duplicate.food_key),
          amount:Number(duplicate.amount ?? 0),
        },
      });
    }

    const accepted = await db.prepare(
      "SELECT round_id,food_key,amount FROM greedy_girl_bets WHERE id=? LIMIT 1"
    ).bind(betId).first();
    if (!accepted) {
      return json(
        { ok:false,error:"insufficient_coins",state:await greedyGirlState(db,userId,ts) },
        { status:409 },
      );
    }
    if (!compactResponse) {
      return json(await greedyGirlState(db, userId, now()), { status:201 });
    }
    const wallet = await db.prepare(
      "SELECT coins FROM users WHERE id=? LIMIT 1"
    ).bind(userId).first();
    return json({
      ok:true,
      server_time:now(),
      wallet_balance:Number(wallet?.coins ?? 0),
      accepted_bet:{
        round_id:Number(accepted.round_id),
        food_key:String(accepted.food_key),
        amount:Number(accepted.amount ?? 0),
      },
    }, { status:201 });
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
    const roomThemePrefix = `room-themes/${actor}/`;
    let authorizedKey = key.startsWith(userPrefix) ||
      key.startsWith(messagePrefix) ||
      key.startsWith(customGiftPrefix) ||
      key.startsWith(roomThemePrefix);
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
  if (!membership) {
    await db.prepare(
      "CREATE TABLE IF NOT EXISTS game_room_members (room_id TEXT NOT NULL, user_id TEXT NOT NULL, seat_index INTEGER NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY(room_id,user_id), UNIQUE(room_id,seat_index))"
    ).run();
    membership = await db.prepare(
      "SELECT 1 AS active FROM game_room_members WHERE room_id = ? AND user_id = ? LIMIT 1"
    ).bind(roomId, String(session.sub)).first();
  }
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

const INTIMACY_CARD_UNLOCK_COST = 100000;
const INTIMACY_CARD_TOTAL_SLOTS = 20;
const INTIMACY_CARD_INITIAL_UNLOCKED = 3;

async function ensureIntimacyCardSchema(db) {
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS intimacy_card_state (
      owner_user_id TEXT PRIMARY KEY,
      unlocked_count INTEGER NOT NULL DEFAULT 3,
      updated_at INTEGER NOT NULL
    )`
  ).run();
  await db.prepare(
    `CREATE TABLE IF NOT EXISTS intimacy_card_bindings (
      owner_user_id TEXT NOT NULL,
      slot_index INTEGER NOT NULL,
      relation_type TEXT NOT NULL,
      target_user_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY(owner_user_id, slot_index),
      UNIQUE(owner_user_id, target_user_id)
    )`
  ).run();
}

async function intimacyCardState(db, userId) {
  await ensureIntimacyCardSchema(db);
  await ensureUser(db, userId);
  const ts = now();
  await db.prepare(
    `INSERT INTO intimacy_card_state(owner_user_id,unlocked_count,updated_at)
     VALUES(?,?,?)
     ON CONFLICT(owner_user_id) DO NOTHING`
  ).bind(userId, INTIMACY_CARD_INITIAL_UNLOCKED, ts).run();

  const state = await db.prepare(
    "SELECT unlocked_count FROM intimacy_card_state WHERE owner_user_id=? LIMIT 1"
  ).bind(userId).first();
  const unlockedCount = Math.max(
    INTIMACY_CARD_INITIAL_UNLOCKED,
    Math.min(INTIMACY_CARD_TOTAL_SLOTS, Number(state?.unlocked_count ?? INTIMACY_CARD_INITIAL_UNLOCKED)),
  );
  const rows = await db.prepare(
    `SELECT b.slot_index,b.relation_type,b.target_user_id,
            COALESCE(u.display_name,'User') AS display_name,
            u.avatar_key,u.public_id
       FROM intimacy_card_bindings b
       LEFT JOIN users u ON u.id=b.target_user_id
      WHERE b.owner_user_id=?
      ORDER BY b.slot_index ASC`
  ).bind(userId).all();

  return {
    unlocked_count: unlockedCount,
    total_slots: INTIMACY_CARD_TOTAL_SLOTS,
    next_unlock_cost: unlockedCount < INTIMACY_CARD_TOTAL_SLOTS
      ? INTIMACY_CARD_UNLOCK_COST
      : 0,
    cards: rows.results ?? [],
  };
}

async function unlockIntimacyCard(db, userId) {
  await ensureUser(db, userId);
  await ensureUserAllowed(db, userId);
  const state = await intimacyCardState(db, userId);
  if (state.unlocked_count >= INTIMACY_CARD_TOTAL_SLOTS) {
    throw new Error("all_intimacy_cards_unlocked");
  }
  const ts = now();
  const debit = await db.prepare(
    "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=?"
  ).bind(INTIMACY_CARD_UNLOCK_COST, ts, userId, INTIMACY_CARD_UNLOCK_COST).run();
  if (Number(debit.meta?.changes ?? 0) !== 1) {
    throw new Error("insufficient_coins");
  }
  await db.prepare(
    "UPDATE intimacy_card_state SET unlocked_count=unlocked_count+1,updated_at=? WHERE owner_user_id=?"
  ).bind(ts, userId).run();
  const wallet = await db.prepare(
    "SELECT coins FROM users WHERE id=? LIMIT 1"
  ).bind(userId).first();
  return {
    ...(await intimacyCardState(db, userId)),
    coin_balance: Number(wallet?.coins ?? 0),
  };
}

function normalizeIntimacyCardRelation(value) {
  const relation = String(value ?? "").trim().toLowerCase().replace(/[\s/-]+/g, "_");
  if (relation === "brother" || relation === "sister" || relation === "brother_sister") {
    return "brother_sister";
  }
  if (relation === "enemy") return "enemy";
  return "friend";
}

async function bindIntimacyCard(db, userId, slotIndexRaw, targetUserIdRaw, relationRaw) {
  await ensureUser(db, userId);
  await ensureUserAllowed(db, userId);
  await ensureTinniSocialSchema(db);
  await ensureIntimacyCardSchema(db);

  const slotIndex = Number(slotIndexRaw);
  const targetUserId = String(targetUserIdRaw ?? "").trim();
  if (!Number.isInteger(slotIndex) || slotIndex < 1 || slotIndex > INTIMACY_CARD_TOTAL_SLOTS) {
    throw new Error("invalid_intimacy_card_slot");
  }
  if (!targetUserId || targetUserId === userId) {
    throw new Error("invalid_intimacy_card_target");
  }

  const state = await intimacyCardState(db, userId);
  if (slotIndex > state.unlocked_count) {
    throw new Error("intimacy_card_locked");
  }

  const target = await db.prepare(
    "SELECT id FROM users WHERE id=? LIMIT 1"
  ).bind(targetUserId).first();
  if (!target) throw new Error("user_not_found");

  const mutual = await db.prepare(
    `SELECT 1 AS yes
       FROM user_follows a
       JOIN user_follows b
         ON b.follower_id=a.target_id
        AND b.target_id=a.follower_id
      WHERE a.follower_id=? AND a.target_id=?
      LIMIT 1`
  ).bind(userId, targetUserId).first();
  if (!mutual) throw new Error("mutual_friend_required");

  const relationType = slotIndex === 1
    ? "brother_sister"
    : normalizeIntimacyCardRelation(relationRaw);
  const ts = now();
  await db.prepare(
    `INSERT INTO intimacy_card_bindings(
       owner_user_id,slot_index,relation_type,target_user_id,created_at,updated_at
     ) VALUES(?,?,?,?,?,?)
     ON CONFLICT(owner_user_id,slot_index)
     DO UPDATE SET relation_type=excluded.relation_type,
                   target_user_id=excluded.target_user_id,
                   updated_at=excluded.updated_at`
  ).bind(userId, slotIndex, relationType, targetUserId, ts, ts).run();
  return intimacyCardState(db, userId);
}

async function unbindIntimacyCard(db, userId, slotIndexRaw) {
  await ensureIntimacyCardSchema(db);
  const slotIndex = Number(slotIndexRaw);
  if (!Number.isInteger(slotIndex) || slotIndex < 1 || slotIndex > INTIMACY_CARD_TOTAL_SLOTS) {
    throw new Error("invalid_intimacy_card_slot");
  }
  await db.prepare(
    "DELETE FROM intimacy_card_bindings WHERE owner_user_id=? AND slot_index=?"
  ).bind(userId, slotIndex).run();
  return intimacyCardState(db, userId);
}

// Game Room keeps its 15-seat layout while reusing voice/chat/game services.
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
        fcm_push_configured: Boolean(
          String(env.FCM_SERVICE_ACCOUNT_JSON ?? "").trim(),
        ),
      });
    }

    try {
      const requestDeviceKey=String(request.headers.get("x-device-id") ?? "").trim();
      if(requestDeviceKey){
        const requestDb=requireDb(env);
        try {
          await ensureDeviceAllowed(requestDb,requestDeviceKey);
        } catch(error) {
          if(String(error?.message ?? error)==="device_banned"){
            return json({ok:false,error:"device_banned"},{status:403});
          }
          throw error;
        }
      }
      if (url.pathname === "/api/files" && request.method === "GET") {
        if (!env.FILES) return json({ ok: false, error: "files_not_bound" }, { status: 503 });
        const key = String(url.searchParams.get("key") ?? "").trim();
        if (!key || key.includes("..") || key.startsWith("/") ||
            !/^(users|rooms|messages|custom-gifts|room-themes|banners)\/[a-zA-Z0-9._/-]+$/.test(key)) {
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
