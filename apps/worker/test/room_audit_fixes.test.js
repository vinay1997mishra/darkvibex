// Room audit fixes (Vinay, 2026-11-20): regression tests for the problems
// found by the four-slice room audit — Greedy Girl bet crash, Ludo in game
// rooms, room DP auto-delete, CP/VS cross-user reads, gift guards,
// tie-breaks, join gates, followed-room counts, re-create vip_only,
// seat-request resolve, room delete orphans, kick markers.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";

class D1Mock {
  constructor(database) { this.database = database; }
  prepare(sql) {
    const database = this.database;
    const makeStatement = (values = []) => ({
      bind(...bound) { return makeStatement(bound); },
      async run() { const result = database.prepare(sql).run(...values); return { meta: { changes: Number(result.changes) } }; },
      async first() { return database.prepare(sql).get(...values) ?? null; },
      async all() { return { results: database.prepare(sql).all(...values) }; },
    });
    return makeStatement();
  }
  async batch(statements) {
    this.database.exec("BEGIN");
    try {
      const results = [];
      for (const statement of statements) results.push(await statement.run());
      this.database.exec("COMMIT");
      return results;
    } catch (error) {
      this.database.exec("ROLLBACK");
      throw error;
    }
  }
}

const base64url = (bytes) => Buffer.from(bytes).toString("base64url");
async function sessionToken(userId, secret) {
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: userId, exp: Math.floor(Date.now() / 1000) + 3600 })}`;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "room-audit-fixes-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, ALLOW_GUEST_SESSIONS: true, FILES: files };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, request, files };
}

let publicIdCounter = 7660000;
async function makeUser(fx, userId, { coins = 100000, vipLevel = 0, country = "IN" } = {}) {
  const { sqlite, request } = fx;
  const created = await request("/api/session/guest", { method: "POST", body: { user_id: userId, display_name: userId } });
  assert.equal(created.status, 200, JSON.stringify(created.body));
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

async function makeRoom(fx, ownerId, { vipOnly } = {}) {
  const { request } = fx;
  const body = { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12 };
  if (vipOnly != null) body.vip_only = vipOnly;
  const created = await request("/api/rooms", { method: "POST", userId: ownerId, body });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return String(created.body.room_id);
}

async function joinRoom(fx, roomId, userId) {
  const joined = await fx.request(`/api/rooms/${roomId}/join`, { method: "POST", userId, body: { user_id: userId, display_name: userId } });
  assert.equal(joined.status, 200, JSON.stringify(joined.body));
  return joined;
}

async function sendGift(fx, roomId, senderId, receiverId, giftId = "rose") {
  return fx.request("/api/gifts/send", {
    method: "POST",
    userId: senderId,
    body: { sender_user_id: senderId, receiver_user_id: receiverId, gift_id: giftId, coin_cost: 100, room_id: roomId },
  });
}

// Bets run on a wall-clock round (30s bet window, 5s result phase), so a
// first attempt can land in the locked phase — retry with fresh request
// ids until the window opens.
async function placeBet(fx, path, userId, body) {
  for (let attempt = 0; attempt < 25; attempt++) {
    const requestId = `request-${String(attempt).padStart(16, "0")}`;
    const result = await fx.request(path, {
      method: "POST",
      userId,
      body: { ...body, request_id: requestId },
    });
    if (result.status !== 409 || result.body.error !== "betting_locked") return { result, requestId };
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error(`bet window never opened for ${path}`);
}

test("Greedy Girl bet succeeds over HTTP and a same-request retry does not double-spend", async () => {
  const fx = await fixture();
  await makeUser(fx, "gg-player", { coins: 100000 });
  const { result, requestId } = await placeBet(fx, "/api/games/greedy-girl/bet", "gg-player", {
    user_id: "gg-player", food_key: "tomato", amount: 1000,
  });
  assert.equal(result.status, 201, JSON.stringify(result.body));
  const bet = fx.sqlite.prepare("SELECT * FROM greedy_girl_bets WHERE user_id=? AND request_id=?").get("gg-player", requestId);
  assert.ok(bet, "bet row must exist");
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("gg-player").coins, 99000);

  // Retry with the same request id: the accepted bet comes back, no
  // second bet is placed and no coins are deducted again.
  const retry = await fx.request("/api/games/greedy-girl/bet", {
    method: "POST", userId: "gg-player",
    body: { user_id: "gg-player", food_key: "tomato", amount: 1000, request_id: requestId },
  });
  assert.equal(retry.status, 200, JSON.stringify(retry.body));
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM greedy_girl_bets WHERE user_id=?").get("gg-player").n, 1);
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("gg-player").coins, 99000);

  // Compact response (same fixture — the schema-ready flag is
  // module-level, so a second fixture would miss the tables).
  await makeUser(fx, "gg-compact", { coins: 100000 });
  const compact = await placeBet(fx, "/api/games/greedy-girl/bet", "gg-compact", {
    user_id: "gg-compact", food_key: "tomato", amount: 1000, compact_response: true,
  });
  // Bet creation is 201 either way; the compact flag only changes the body.
  assert.equal(compact.result.status, 201, JSON.stringify(compact.result.body));
  assert.equal(compact.result.body.ok, true);
  assert.equal(compact.result.body.accepted_bet.food_key, "tomato");
  assert.equal(compact.result.body.accepted_bet.amount, 1000);
});

test("Fruit Party bet succeeds over HTTP and a same-request retry is idempotent", async () => {
  const fx = await fixture();
  await makeUser(fx, "fp-player", { coins: 100000 });
  const { result, requestId } = await placeBet(fx, "/api/games/fruit-party/bet", "fp-player", {
    user_id: "fp-player", fruit_key: "lemon", amount: 5000,
  });
  assert.equal(result.status, 201, JSON.stringify(result.body));
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("fp-player").coins, 95000);
  const retry = await fx.request("/api/games/fruit-party/bet", {
    method: "POST", userId: "fp-player",
    body: { user_id: "fp-player", fruit_key: "lemon", amount: 5000, request_id: requestId },
  });
  assert.equal(retry.status, 200, JSON.stringify(retry.body));
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM fruit_party_bets WHERE user_id=?").get("fp-player").n, 1);
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("fp-player").coins, 95000);
});

test("Ludo in a game room holds 2+ players (cleanup must not prune game-room members)", async () => {
  const fx = await fixture();
  await makeUser(fx, "ludo-a");
  await makeUser(fx, "ludo-b");
  const created = await fx.request("/api/game-rooms", { method: "POST", userId: "ludo-a", body: { user_id: "ludo-a", name: "Game Room" } });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  const roomId = String(created.body.room_id);
  const joined = await fx.request(`/api/game-rooms/${roomId}/join`, { method: "POST", userId: "ludo-b", body: { user_id: "ludo-b" } });
  assert.equal(joined.status, 200, JSON.stringify(joined.body));

  const stateA = await fx.request(`/api/rooms/${roomId}/ludo`, { userId: "ludo-a" });
  assert.equal(stateA.status, 200, JSON.stringify(stateA.body));
  assert.equal(stateA.body.players.length, 1);
  const stateB = await fx.request(`/api/rooms/${roomId}/ludo`, { userId: "ludo-b" });
  assert.equal(stateB.status, 200, JSON.stringify(stateB.body));
  assert.equal(stateB.body.players.length, 2, "player B joining must not prune player A");
  const stateA2 = await fx.request(`/api/rooms/${roomId}/ludo`, { userId: "ludo-a" });
  assert.equal(stateA2.body.players.length, 2, "player A polling must not prune player B");
  assert.deepEqual(stateA2.body.players.map((p) => p.user_id).sort(), ["ludo-a", "ludo-b"]);
});

test("Ludo winner leaving clears the win so the rest can keep playing", async () => {
  const fx = await fixture();
  await makeUser(fx, "ludo-winner");
  await makeUser(fx, "ludo-other");
  const roomId = await makeRoom(fx, "ludo-winner");
  await joinRoom(fx, roomId, "ludo-winner");
  await joinRoom(fx, roomId, "ludo-other");
  const stateA = await fx.request(`/api/rooms/${roomId}/ludo`, { userId: "ludo-winner" });
  const stateB = await fx.request(`/api/rooms/${roomId}/ludo`, { userId: "ludo-other" });
  assert.equal(stateB.body.players.length, 2);
  const winnerColor = stateA.body.player_color;
  const row = fx.sqlite.prepare("SELECT state_json FROM ludo_room_sessions WHERE room_id=?").get(roomId);
  const stateJson = JSON.parse(String(row.state_json));
  stateJson.winner = winnerColor;
  fx.sqlite.prepare("UPDATE ludo_room_sessions SET state_json=? WHERE room_id=?").run(JSON.stringify(stateJson), roomId);

  const left = await fx.request(`/api/rooms/${roomId}/ludo/leave`, { method: "POST", userId: "ludo-winner", body: { user_id: "ludo-winner" } });
  assert.equal(left.status, 200, JSON.stringify(left.body));
  const after = await fx.request(`/api/rooms/${roomId}/ludo`, { userId: "ludo-other" });
  assert.equal(after.status, 200, JSON.stringify(after.body));
  assert.equal(after.body.winner, null, "winner must be cleared when the winner leaves");
  assert.equal(after.body.players.length, 1);
});

test("changing the room DP deletes the old R2 file at once", async () => {
  const fx = await fixture();
  await makeUser(fx, "dp-owner");
  const roomId = await makeRoom(fx, "dp-owner");
  const first = await fx.request(`/api/rooms/${roomId}/avatar`, {
    method: "POST", userId: "dp-owner",
    body: { user_id: "dp-owner", avatar_key: `rooms/${roomId}/avatar-111.jpg` },
  });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  const second = await fx.request(`/api/rooms/${roomId}/avatar`, {
    method: "POST", userId: "dp-owner",
    body: { user_id: "dp-owner", avatar_key: `rooms/${roomId}/avatar-222.jpg` },
  });
  assert.equal(second.status, 200, JSON.stringify(second.body));
  assert.deepEqual(fx.files.deleted, [`rooms/${roomId}/avatar-111.jpg`]);
  assert.equal(fx.sqlite.prepare("SELECT image_key FROM room_images WHERE room_id=?").get(roomId).image_key, `rooms/${roomId}/avatar-222.jpg`);
});

test("room settings return the current room avatar key", async () => {
  const fx = await fixture();
  await makeUser(fx, "settings-owner");
  const roomId = await makeRoom(fx, "settings-owner");
  await joinRoom(fx, roomId, "settings-owner");
  await fx.request(`/api/rooms/${roomId}/avatar`, {
    method: "POST", userId: "settings-owner",
    body: { user_id: "settings-owner", avatar_key: `rooms/${roomId}/avatar-999.jpg` },
  });
  const settings = await fx.request(`/api/rooms/${roomId}/settings?user_id=settings-owner`, { userId: "settings-owner" });
  assert.equal(settings.status, 200, JSON.stringify(settings.body));
  assert.equal(settings.body.settings.avatar_key, `rooms/${roomId}/avatar-999.jpg`);
});

test("CP and VS state are readable by another logged-in user, not by guests", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-actor");
  await makeUser(fx, "cp-target");
  const cp = await fx.request("/api/cp?user_id=cp-target", { userId: "cp-actor" });
  assert.equal(cp.status, 200, JSON.stringify(cp.body));
  assert.equal(cp.body.ok, true);
  const vs = await fx.request("/api/vs?user_id=cp-target", { userId: "cp-actor" });
  assert.equal(vs.status, 200, JSON.stringify(vs.body));
  assert.equal(vs.body.ok, true);
  const anon = await fx.request("/api/cp?user_id=cp-target", {});
  assert.equal(anon.status, 401);
});

test("a blocked user cannot gift the person who blocked them", async () => {
  const fx = await fixture();
  await makeUser(fx, "gift-blocker");
  await makeUser(fx, "gift-blocked");
  const roomId = await makeRoom(fx, "gift-blocker");
  await joinRoom(fx, roomId, "gift-blocker");
  await joinRoom(fx, roomId, "gift-blocked");
  const blocked = await fx.request("/api/social/block", {
    method: "POST", userId: "gift-blocker",
    body: { user_id: "gift-blocker", target_user_id: "gift-blocked" },
  });
  assert.equal(blocked.status, 200, JSON.stringify(blocked.body));
  const sent = await sendGift(fx, roomId, "gift-blocked", "gift-blocker");
  assert.equal(sent.status, 403, JSON.stringify(sent.body));
  assert.equal(sent.body.error, "blocked_user");
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events").get().n, 0);
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("gift-blocked").coins, 100000);
});

test("a gift from outside the room is rejected, a game-room gift is allowed", async () => {
  const fx = await fixture();
  await makeUser(fx, "gift-outsider");
  await makeUser(fx, "gift-insider");
  const roomId = await makeRoom(fx, "gift-insider");
  await joinRoom(fx, roomId, "gift-insider");
  const outside = await sendGift(fx, roomId, "gift-outsider", "gift-insider");
  assert.equal(outside.status, 403, JSON.stringify(outside.body));
  assert.equal(outside.body.error, "gift_not_in_room");
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events").get().n, 0);

  const created = await fx.request("/api/game-rooms", { method: "POST", userId: "gift-insider", body: { user_id: "gift-insider", name: "Game Room" } });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  const gameRoomId = String(created.body.room_id);
  await fx.request(`/api/game-rooms/${gameRoomId}/join`, { method: "POST", userId: "gift-outsider", body: { user_id: "gift-outsider" } });
  const inside = await sendGift(fx, gameRoomId, "gift-outsider", "gift-insider");
  assert.equal(inside.status, 200, JSON.stringify(inside.body));
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events").get().n, 1);
});

test("gift ranking tie-break is deterministic (sender id ascending)", async () => {
  const fx = await fixture();
  await makeUser(fx, "aaa-gifter");
  await makeUser(fx, "bbb-gifter");
  await makeUser(fx, "gift-host");
  const roomId = await makeRoom(fx, "gift-host");
  await joinRoom(fx, roomId, "gift-host");
  await joinRoom(fx, roomId, "aaa-gifter");
  await joinRoom(fx, roomId, "bbb-gifter");
  const sentB = await sendGift(fx, roomId, "bbb-gifter", "gift-host");
  assert.equal(sentB.status, 200, JSON.stringify(sentB.body));
  const sentA = await sendGift(fx, roomId, "aaa-gifter", "gift-host");
  assert.equal(sentA.status, 200, JSON.stringify(sentA.body));
  const ranking = await fx.request(`/api/rooms/${roomId}/gift-ranking?user_id=gift-host`, { userId: "gift-host" });
  assert.equal(ranking.status, 200, JSON.stringify(ranking.body));
  const top = ranking.body.ranking.slice(0, 2).map((row) => row.user_id);
  assert.deepEqual(top, ["aaa-gifter", "bbb-gifter"]);
});

test("an owner who changed country can still enter their own room; others cannot", async () => {
  const fx = await fixture();
  await makeUser(fx, "country-owner", { country: "IN" });
  await makeUser(fx, "country-stranger", { country: "US" });
  const roomId = await makeRoom(fx, "country-owner");
  fx.sqlite.prepare("UPDATE users SET country_code='US' WHERE id=?").run("country-owner");
  const ownerJoin = await joinRoom(fx, roomId, "country-owner");
  assert.equal(ownerJoin.status, 200, JSON.stringify(ownerJoin.body));
  const stranger = await fx.request(`/api/rooms/${roomId}/join`, {
    method: "POST", userId: "country-stranger",
    body: { user_id: "country-stranger", display_name: "country-stranger" },
  });
  assert.equal(stranger.status, 403, JSON.stringify(stranger.body));
  assert.equal(stranger.body.error, "room_country_mismatch");
});

test("followed rooms count only fresh members and hide rooms with none", async () => {
  const fx = await fixture();
  await makeUser(fx, "follow-owner");
  await makeUser(fx, "follow-fan");
  const roomId = await makeRoom(fx, "follow-owner");
  await joinRoom(fx, roomId, "follow-owner");
  await joinRoom(fx, roomId, "follow-fan");
  const followed = await fx.request(`/api/rooms/${roomId}/follow`, {
    method: "POST", userId: "follow-fan", body: { user_id: "follow-fan", follow: true },
  });
  assert.equal(followed.status, 200, JSON.stringify(followed.body));
  const fresh = await fx.request("/api/rooms/following?user_id=follow-fan", { userId: "follow-fan" });
  assert.equal(fresh.status, 200, JSON.stringify(fresh.body));
  const freshRoom = fresh.body.rooms.find((row) => row.id === roomId);
  assert.ok(freshRoom, "fresh room must be listed");
  assert.equal(freshRoom.online, 2);
  // Stale members: last heartbeat 60s ago (older than the 30s presence
  // TTL, but > 0 so the pruner sees them as stale rows).
  fx.sqlite.prepare("UPDATE room_members SET updated_at=? WHERE room_id=?").run(Date.now() - 60000, roomId);
  const stale = await fx.request("/api/rooms/following?user_id=follow-fan", { userId: "follow-fan" });
  assert.equal(stale.status, 200, JSON.stringify(stale.body));
  assert.equal(stale.body.rooms.find((row) => row.id === roomId), undefined, "a room with only stale members must not be listed");
});

test("re-creating an owned room without vip_only reports the stored value", async () => {
  const fx = await fixture();
  await makeUser(fx, "vip-owner", { vipLevel: 10 });
  const first = await fx.request("/api/rooms", {
    method: "POST", userId: "vip-owner",
    body: { owner_user_id: "vip-owner", owner_name: "vip-owner", name: "VIP room", seat_count: 12, vip_only: 1 },
  });
  assert.equal(first.status, 201, JSON.stringify(first.body));
  assert.equal(first.body.vip_only, 1);
  const again = await fx.request("/api/rooms", {
    method: "POST", userId: "vip-owner",
    body: { owner_user_id: "vip-owner", owner_name: "vip-owner", name: "VIP room", seat_count: 12 },
  });
  assert.equal(again.status, 200, JSON.stringify(again.body));
  assert.equal(again.body.vip_only, 1, "stored VIP-only value must be reported, not the requested default 0");
});

test("resolving a seat request for a user who left returns target_not_in_room", async () => {
  const fx = await fixture();
  await makeUser(fx, "seat-owner");
  await makeUser(fx, "seat-wanter");
  const roomId = await makeRoom(fx, "seat-owner");
  await joinRoom(fx, roomId, "seat-owner");
  await joinRoom(fx, roomId, "seat-wanter");
  const mode = await fx.request(`/api/rooms/${roomId}/controls`, {
    method: "POST", userId: "seat-owner",
    body: { user_id: "seat-owner", action: "mic_mode", mic_mode: "apply" },
  });
  assert.equal(mode.status, 200, JSON.stringify(mode.body));
  const requested = await fx.request(`/api/rooms/${roomId}/seat-request`, {
    method: "POST", userId: "seat-wanter",
    body: { user_id: "seat-wanter", seat_index: 1 },
  });
  assert.equal(requested.status, 200, JSON.stringify(requested.body));
  const left = await fx.request(`/api/rooms/${roomId}/leave`, {
    method: "POST", userId: "seat-wanter", body: { user_id: "seat-wanter" },
  });
  assert.equal(left.status, 200, JSON.stringify(left.body));
  const resolved = await fx.request(`/api/rooms/${roomId}/seat-request/resolve`, {
    method: "POST", userId: "seat-owner",
    body: { user_id: "seat-owner", target_user_id: "seat-wanter", approved: true },
  });
  assert.equal(resolved.status, 404, JSON.stringify(resolved.body));
  assert.equal(resolved.body.error, "target_not_in_room");
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_seat_requests WHERE room_id=?").get(roomId).n, 0);
});

test("deleting a room removes its image, follower rows and the R2 avatar", async () => {
  const fx = await fixture();
  await makeUser(fx, "delete-owner");
  await makeUser(fx, "delete-fan");
  const roomId = await makeRoom(fx, "delete-owner");
  await joinRoom(fx, roomId, "delete-owner");
  await fx.request(`/api/rooms/${roomId}/avatar`, {
    method: "POST", userId: "delete-owner",
    body: { user_id: "delete-owner", avatar_key: `rooms/${roomId}/avatar-777.jpg` },
  });
  await fx.request(`/api/rooms/${roomId}/follow`, {
    method: "POST", userId: "delete-fan", body: { user_id: "delete-fan", follow: true },
  });
  const deleted = await fx.request(`/api/rooms/${roomId}/delete`, {
    method: "POST", userId: "delete-owner", body: { user_id: "delete-owner" },
  });
  assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_images WHERE room_id=?").get(roomId).n, 0);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_followers WHERE room_id=?").get(roomId).n, 0);
  assert.deepEqual(fx.files.deleted, [`rooms/${roomId}/avatar-777.jpg`]);
});

test("a kick records a marker, re-join clears it, a prune leaves none", async () => {
  const fx = await fixture();
  await makeUser(fx, "kick-owner");
  await makeUser(fx, "kick-victim");
  await makeUser(fx, "prune-victim");
  const roomId = await makeRoom(fx, "kick-owner");
  await joinRoom(fx, roomId, "kick-owner");
  await joinRoom(fx, roomId, "kick-victim");
  await joinRoom(fx, roomId, "prune-victim");
  const kicked = await fx.request(`/api/rooms/${roomId}/members`, {
    method: "POST", userId: "kick-owner",
    body: { user_id: "kick-owner", target_user_id: "kick-victim" },
  });
  assert.equal(kicked.status, 200, JSON.stringify(kicked.body));
  assert.equal(kicked.body.ok, true);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_kick_events WHERE room_id=? AND user_id=?").get(roomId, "kick-victim").n, 1);
  const status = await fx.request(`/api/rooms/${roomId}/kick-status?user_id=kick-victim`, { userId: "kick-victim" });
  assert.equal(status.status, 200, JSON.stringify(status.body));
  assert.equal(status.body.kicked, true);
  await joinRoom(fx, roomId, "kick-victim");
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_kick_events WHERE room_id=? AND user_id=?").get(roomId, "kick-victim").n, 0);
  const statusAfter = await fx.request(`/api/rooms/${roomId}/kick-status?user_id=kick-victim`, { userId: "kick-victim" });
  assert.equal(statusAfter.body.kicked, false);

  // A presence-timeout prune (not a kick) leaves no marker.
  fx.sqlite.prepare("UPDATE room_members SET updated_at=? WHERE room_id=? AND user_id=?").run(Date.now() - 60000, roomId, "prune-victim");
  const polled = await fx.request(`/api/rooms/${roomId}/members?user_id=kick-owner`, { userId: "kick-owner" });
  assert.equal(polled.status, 200, JSON.stringify(polled.body));
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_members WHERE room_id=? AND user_id=?").get(roomId, "prune-victim").n, 0);
  const pruneStatus = await fx.request(`/api/rooms/${roomId}/kick-status?user_id=prune-victim`, { userId: "prune-victim" });
  assert.equal(pruneStatus.status, 200, JSON.stringify(pruneStatus.body));
  assert.equal(pruneStatus.body.kicked, false);
});
