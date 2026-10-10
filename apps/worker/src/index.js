import { normalizeRole } from "./role_policy.js";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET,POST,PUT,OPTIONS",
  "access-control-allow-headers": "content-type,x-file-key",
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

function bearerToken(request) {
  const value = String(request.headers.get("authorization") ?? "");
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
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

async function ensureUser(db, userId, displayName = "DarkVibeX User") {
  const ts = now();
  await db.prepare(
    `INSERT INTO users (id, display_name, role, coins, diamonds, vip_level, created_at, updated_at)
     VALUES (?, ?, 'user', 2500000, 120, 1, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       display_name = CASE WHEN excluded.display_name <> '' THEN excluded.display_name ELSE users.display_name END,
       updated_at = excluded.updated_at`
  ).bind(userId, displayName, ts, ts).run();
  return db.prepare(
    "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key FROM users WHERE id = ?"
  ).bind(userId).first();
}

async function listRooms(db) {
  const result = await db.prepare(
    `SELECT r.id, r.name, r.owner_user_id, r.seat_count, r.locked,
            COALESCE(u.display_name, '') AS owner_name,
            (SELECT COUNT(*) FROM room_members m WHERE m.room_id = r.id) AS online
       FROM rooms r
       LEFT JOIN users u ON u.id = r.owner_user_id
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

function ownerAuthorized(request, env) {
  const configured = String(env.OWNER_ADMIN_TOKEN ?? "").trim();
  if (!configured) return false;
  const supplied = String(request.headers.get("authorization") ?? "");
  return supplied === "Bearer " + configured;
}

async function handleOwnerApi(request, env, url) {
  if (!env.OWNER_ADMIN_TOKEN) {
    return json({ ok: false, error: "owner_token_not_configured" }, { status: 503 });
  }
  if (!ownerAuthorized(request, env)) {
    return json({ ok: false, error: "unauthorized" }, { status: 401 });
  }

  const db = requireDb(env);
  const parts = url.pathname.split("/").filter(Boolean);

  if (url.pathname === "/api/owner/overview" && request.method === "GET") {
    const [users, rooms, online, coins, roomRows] = await Promise.all([
      db.prepare("SELECT COUNT(*) AS value FROM users").first(),
      db.prepare("SELECT COUNT(*) AS value FROM rooms").first(),
      db.prepare("SELECT COUNT(*) AS value FROM room_members").first(),
      db.prepare("SELECT COALESCE(SUM(coins),0) AS value FROM users").first(),
      listRooms(db),
    ]);
    return json({
      ok: true,
      stats: {
        users: Number(users?.value ?? 0),
        rooms: Number(rooms?.value ?? 0),
        online: Number(online?.value ?? 0),
        coins: Number(coins?.value ?? 0),
      },
      rooms: roomRows,
    });
  }

  if (parts[0] === "api" && parts[1] === "owner" && parts[2] === "users" && parts.length === 4 && request.method === "GET") {
    const user = await db.prepare(
      "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key, created_at, updated_at FROM users WHERE id = ?"
    ).bind(parts[3]).first();
    return user ? json({ ok: true, user }) : json({ ok: false, error: "not_found" }, { status: 404 });
  }

  if (url.pathname === "/api/owner/room-lock" && request.method === "POST") {
    const body = await bodyJson(request);
    const roomId = String(body.room_id ?? "").trim();
    if (!roomId) return json({ ok: false, error: "room_id_required" }, { status: 400 });
    await db.prepare("UPDATE rooms SET locked = ?, updated_at = ? WHERE id = ?")
      .bind(body.locked === true ? 1 : 0, now(), roomId).run();
    return json({ ok: true });
  }

  return json({ ok: false, error: "not_found" }, { status: 404 });
}

async function handleApi(request, env, url) {
  const db = requireDb(env);
  const parts = url.pathname.split("/").filter(Boolean);

  if (url.pathname === "/api/roles/validate" && request.method === "POST") {
    const body = await bodyJson(request);
    return json({ ok: true, role: normalizeRole(body.role) });
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
    const seconds = Math.floor(Date.now() / 1000);
    const token = await signJwt(
      String(env.SESSION_SECRET),
      { alg: "HS256", typ: "JWT" },
      {
        sub: userId,
        name: user.display_name,
        iat: seconds,
        exp: seconds + 60 * 60 * 24 * 7,
      },
    );
    return json({ ok: true, token, user });
  }

  if (url.pathname === "/api/users/upsert" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    const user = await ensureUser(db, userId, String(body.display_name ?? "").trim());
    return json({ ok: true, user });
  }

  if (parts[0] === "api" && parts[1] === "users" && parts.length === 3 && request.method === "GET") {
    const user = await db.prepare(
      "SELECT id, display_name, role, coins, diamonds, vip_level, avatar_key FROM users WHERE id = ?"
    ).bind(parts[2]).first();
    return user ? json({ ok: true, user }) : json({ ok: false, error: "not_found" }, { status: 404 });
  }

  if (url.pathname === "/api/rooms" && request.method === "GET") {
    return json({ ok: true, rooms: await listRooms(db) });
  }

  if (url.pathname === "/api/rooms" && request.method === "POST") {
    const body = await bodyJson(request);
    const ownerId = String(body.owner_user_id ?? "").trim();
    const name = String(body.name ?? "").trim().slice(0, 80);
    const seatCount = Math.max(8, Math.min(42, Number(body.seat_count ?? 12)));
    if (!ownerId || !name) return json({ ok: false, error: "owner_and_name_required" }, { status: 400 });
    await ensureUser(db, ownerId, String(body.owner_name ?? "DarkVibeX User"));
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
    await ensureUser(db, userId, String(body.display_name ?? "DarkVibeX User"));
    const ts = now();
    await db.prepare(
      "INSERT INTO room_members (room_id, user_id, seat_index, mic_muted, joined_at, updated_at) VALUES (?, ?, NULL, 1, ?, ?) ON CONFLICT(room_id,user_id) DO UPDATE SET updated_at = excluded.updated_at"
    ).bind(roomId, userId, ts, ts).run();
    return json({ ok: true });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "seat" && request.method === "POST") {
    const roomId = parts[2];
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const seatIndex = body.seat_index == null ? null : Number(body.seat_index);
    const muted = body.mic_muted === false ? 0 : 1;
    if (!userId) return json({ ok: false, error: "user_id_required" }, { status: 400 });
    if (seatIndex != null) {
      const occupied = await db.prepare(
        "SELECT user_id FROM room_members WHERE room_id = ? AND seat_index = ? AND user_id <> ? LIMIT 1"
      ).bind(roomId, seatIndex, userId).first();
      if (occupied) return json({ ok: false, error: "seat_occupied" }, { status: 409 });
    }
    await db.prepare(
      "UPDATE room_members SET seat_index = ?, mic_muted = ?, updated_at = ? WHERE room_id = ? AND user_id = ?"
    ).bind(seatIndex, muted, now(), roomId, userId).run();
    return json({ ok: true, seat_index: seatIndex, mic_muted: Boolean(muted) });
  }

  if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "messages") {
    const roomId = parts[2];
    if (request.method === "GET") {
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
      const textValue = String(body.text ?? "").trim().slice(0, 500);
      if (!userId || !textValue) return json({ ok: false, error: "message_required" }, { status: 400 });
      const messageId = id();
      await db.prepare(
        "INSERT INTO room_messages (id, room_id, user_id, text, created_at) VALUES (?, ?, ?, ?, ?)"
      ).bind(messageId, roomId, userId, textValue, now()).run();
      return json({ ok: true, message_id: messageId }, { status: 201 });
    }
  }

  if (parts[0] === "api" && parts[1] === "wallet" && parts.length === 3 && request.method === "GET") {
    const user = await ensureUser(db, parts[2]);
    const ledger = await db.prepare(
      "SELECT id, kind, amount, balance_after, reference_id, created_at FROM wallet_ledger WHERE user_id = ? ORDER BY created_at DESC LIMIT 100"
    ).bind(parts[2]).all();
    return json({ ok: true, wallet: user, ledger: ledger.results ?? [] });
  }

  if (url.pathname === "/api/gifts/send" && request.method === "POST") {
    const body = await bodyJson(request);
    const sender = String(body.sender_user_id ?? "").trim();
    const receiver = String(body.receiver_user_id ?? "").trim();
    const giftId = String(body.gift_id ?? "gift").trim().slice(0, 80);
    const cost = Number(body.coin_cost ?? 0);
    if (!sender || !receiver || !Number.isInteger(cost) || cost <= 0) {
      return json({ ok: false, error: "invalid_gift" }, { status: 400 });
    }
    await ensureUser(db, sender);
    await ensureUser(db, receiver);
    const eventId = id();
    const balance = await walletChange(db, sender, -cost, "gift_sent", eventId);
    await db.batch([
      db.prepare("UPDATE users SET diamonds = diamonds + ?, updated_at = ? WHERE id = ?").bind(cost, now(), receiver),
      db.prepare(
        "INSERT INTO gift_events (id, room_id, sender_user_id, receiver_user_id, gift_id, coin_cost, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
      ).bind(eventId, body.room_id ?? null, sender, receiver, giftId, cost, now()),
    ]);
    return json({ ok: true, event_id: eventId, sender_coin_balance: balance });
  }

  if (url.pathname === "/api/games/fruit-party/bet" && request.method === "POST") {
    const body = await bodyJson(request);
    const userId = String(body.user_id ?? "").trim();
    const stake = Number(body.stake ?? 0);
    if (!userId || !Number.isInteger(stake) || stake <= 0) {
      return json({ ok: false, error: "invalid_bet" }, { status: 400 });
    }
    await ensureUser(db, userId);
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
    if (!env.FILES) return json({ ok: false, error: "files_not_bound" }, { status: 503 });
    const rawKey = String(request.headers.get("x-file-key") ?? "").trim();
    const key = rawKey.replace(/[^a-zA-Z0-9._/-]/g, "").replace(/^\/+/, "");
    if (!key || key.includes("..")) return json({ ok: false, error: "invalid_file_key" }, { status: 400 });
    await env.FILES.put(key, request.body, {
      httpMetadata: { contentType: request.headers.get("content-type") ?? "application/octet-stream" },
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
  const body = await bodyJson(request);
  const roomId = String(body.room_id ?? "").trim().slice(0, 100);
  if (!roomId) {
    return json({ ok: false, error: "room_id_required" }, { status: 400 });
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
