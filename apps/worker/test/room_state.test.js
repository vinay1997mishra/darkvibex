// Combined room-state (Vinay, 2026-11-20): ONE call every 3s carrying
// members + messages + controls + gift events + settings, so the room stays
// instant while the Workers free-tier request count drops. GET
// /api/rooms/:id/state must return the exact shapes of the five standalone
// endpoints, 403 room_membership_required for non-members (the app's kick
// signal), the same message join-time + chat-clear cutoffs, and the same
// incremental gift-events cursor. The controls field embeds the full
// controls response object unchanged, including its ok field (the app's
// _applyRoomControls keeps the strict value['ok'] != true guard).
// Settings ride along too: ANY setting change (DP, background, name, lock,
// room chat off) must show to everyone in the room within 3s, and a
// settings failure must never fail the whole state call.
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
  const secret = "room-state-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, FILES: files, OWNER_ADMIN_TOKEN: "owner-test-token" };
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
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

async function makeRoom(fx, ownerId) {
  const { request } = fx;
  const created = await request("/api/rooms", { method: "POST", userId: ownerId, body: { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12 } });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return String(created.body.room_id);
}

async function joinRoom(fx, roomId, userId) {
  const joined = await fx.request(`/api/rooms/${roomId}/join`, { method: "POST", userId, body: { user_id: userId, display_name: userId } });
  assert.equal(joined.status, 200, JSON.stringify(joined.body));
  return joined;
}

async function leaveRoom(fx, roomId, userId) {
  const left = await fx.request(`/api/rooms/${roomId}/leave`, { method: "POST", userId, body: { user_id: userId } });
  assert.equal(left.status, 200, JSON.stringify(left.body));
  return left;
}

async function setAdmin(fx, roomId, ownerId, targetId) {
  const result = await fx.request(`/api/rooms/${roomId}/members`, { method: "POST", userId: ownerId, body: { user_id: ownerId, target_user_id: targetId, action: "set_admin" } });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  return result;
}

async function sendMessage(fx, roomId, userId, text) {
  const sent = await fx.request(`/api/rooms/${roomId}/messages`, { method: "POST", userId, body: { user_id: userId, text } });
  assert.equal(sent.status, 201, JSON.stringify(sent.body));
  return sent;
}

async function clearChat(fx, roomId, userId) {
  return fx.request(`/api/rooms/${roomId}/messages/clear`, { method: "POST", userId, body: { user_id: userId } });
}

async function getState(fx, roomId, userId, query = "") {
  return fx.request(`/api/rooms/${roomId}/state${query}`, { userId });
}

async function getSettings(fx, roomId, userId) {
  return fx.request(`/api/rooms/${roomId}/settings`, { userId });
}

async function updateSettings(fx, roomId, userId, body) {
  return fx.request(`/api/rooms/${roomId}/settings`, { method: "POST", userId, body: { user_id: userId, ...body } });
}

async function setRoomAvatar(fx, roomId, userId, avatarKey) {
  return fx.request(`/api/rooms/${roomId}/avatar`, { method: "POST", userId, body: { user_id: userId, avatar_key: avatarKey } });
}

function setMessagesFeature(fx, enabled) {
  fx.sqlite.prepare(
    "INSERT INTO owner_settings(key, value_json, updated_at) VALUES(?,?,?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json, updated_at=excluded.updated_at",
  ).run("feature.messages", JSON.stringify({ enabled }), Date.now());
}

let giftCounter = 0;
function insertGiftEvent(fx, roomId, senderId, receiverId, createdAt) {
  giftCounter += 1;
  const id = `evt-${String(giftCounter).padStart(3, "0")}`;
  fx.sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES(?,?,?,?,?,?,?)",
  ).run(id, roomId, senderId, receiverId, "rose", 100, createdAt);
  return { id, created_at: createdAt };
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

test("state returns members, messages, controls and events in one call for a member", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  await sendMessage(fx, roomId, "owner", "hello-room");
  const base = Date.now();
  const e1 = insertGiftEvent(fx, roomId, "owner", "member", base);
  const e2 = insertGiftEvent(fx, roomId, "member", "owner", base + 10);

  const state = await getState(fx, roomId, "member");
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.equal(state.body.ok, true);

  // Members: same rows as the standalone members endpoint.
  const memberIds = (state.body.members ?? []).map((m) => String(m.user_id));
  assert.ok(memberIds.includes("owner"), "owner must be listed");
  assert.ok(memberIds.includes("member"), "caller must be listed");
  const self = state.body.members.find((m) => String(m.user_id) === "member");
  assert.equal(String(self.display_name), "member");
  assert.ok("seat_index" in self && "joined_at" in self);

  // Messages: same rows as the standalone messages endpoint.
  assert.deepEqual(
    (state.body.messages ?? []).map((m) => String(m.text)),
    ["hello-room"],
  );

  // Controls: the FULL controls response object, including ok — the app's
  // _applyRoomControls keeps the strict value['ok'] != true guard, so a
  // flattened controls field without ok would silently never apply.
  const controls = state.body.controls ?? {};
  assert.equal(controls.ok, true, "controls must embed the full response with ok");
  assert.equal(controls.mic_mode, "free");
  assert.equal(controls.public_screen_enabled, true);
  assert.equal(controls.vip_only, 0);
  assert.deepEqual(controls.seat_controls, []);
  assert.deepEqual(controls.seat_requests, []);
  assert.equal(controls.chat_banned, false);
  assert.equal(controls.seat_invite, null);
  assert.equal(controls.is_owner, false, "member is not the owner");
  assert.equal(controls.is_admin, false);

  // Gift events: same rows as the standalone gift-events endpoint.
  assert.deepEqual(
    (state.body.events ?? []).map((e) => String(e.id)),
    [e1.id, e2.id],
  );
  const first = state.body.events[0];
  assert.equal(first.sender_user_id, "owner");
  assert.equal(first.receiver_user_id, "member");
  assert.equal(first.gift_id, "rose");
  assert.equal(first.coin_cost, 100);
  assert.equal(typeof first.gift_ribbon, "object");
  assert.notEqual(first.gift_ribbon, null);
  assert.equal(typeof first.gift_ribbon.tier, "string");

  // Events must be byte-identical to the standalone gift-events endpoint.
  const standaloneEvents = await fx.request(`/api/rooms/${roomId}/gift-events`, { userId: "member" });
  assert.equal(standaloneEvents.status, 200, JSON.stringify(standaloneEvents.body));
  assert.deepEqual(state.body.events, standaloneEvents.body.events);

  // Owner sees the same payload with owner flags.
  const ownerState = await getState(fx, roomId, "owner");
  assert.equal(ownerState.status, 200, JSON.stringify(ownerState.body));
  assert.equal(ownerState.body.controls.is_owner, true);
  assert.equal(ownerState.body.controls.ok, true);
});

test("state 403s room_membership_required for non-members and leavers", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  await makeUser(fx, "outsider");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  const outsider = await getState(fx, roomId, "outsider");
  assert.equal(outsider.status, 403);
  assert.equal(outsider.body.error, "room_membership_required");

  await leaveRoom(fx, roomId, "member");
  const leaver = await getState(fx, roomId, "member");
  assert.equal(leaver.status, 403);
  assert.equal(leaver.body.error, "room_membership_required");
});

test("state applies the join-time message cutoff", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "late");
  const roomId = await makeRoom(fx, "owner");

  await sendMessage(fx, roomId, "owner", "before-late-joined");
  await sleep(10);
  await joinRoom(fx, roomId, "late");

  const lateState = await getState(fx, roomId, "late");
  assert.equal(lateState.status, 200, JSON.stringify(lateState.body));
  assert.deepEqual(
    (lateState.body.messages ?? []).map((m) => String(m.text)),
    [],
    "late joiner must not see messages from before they joined",
  );

  await sleep(10);
  await sendMessage(fx, roomId, "late", "after-late-joined");
  const lateAfter = await getState(fx, roomId, "late");
  assert.deepEqual(
    (lateAfter.body.messages ?? []).map((m) => String(m.text)),
    ["after-late-joined"],
  );
  const ownerState = await getState(fx, roomId, "owner");
  assert.deepEqual(
    (ownerState.body.messages ?? []).map((m) => String(m.text)),
    ["before-late-joined", "after-late-joined"],
  );
});

test("state applies the admin-clear cutoff (owner still sees the old chat)", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "admin");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "admin");
  await joinRoom(fx, roomId, "member");
  await setAdmin(fx, roomId, "owner", "admin");

  await sendMessage(fx, roomId, "owner", "m1-owner");
  await sleep(10);
  await sendMessage(fx, roomId, "member", "m2-member");
  await sleep(10);

  const cleared = await clearChat(fx, roomId, "admin");
  assert.equal(cleared.status, 200, JSON.stringify(cleared.body));

  const adminState = await getState(fx, roomId, "admin");
  assert.deepEqual(adminState.body.messages ?? [], [], "admin must not see pre-clear chat");
  const memberState = await getState(fx, roomId, "member");
  assert.deepEqual(memberState.body.messages ?? [], [], "member must not see pre-clear chat");
  const ownerState = await getState(fx, roomId, "owner");
  assert.deepEqual(
    (ownerState.body.messages ?? []).map((m) => String(m.text)),
    ["m1-owner", "m2-member"],
    "owner still sees the old chat after an admin clear",
  );

  await sleep(10);
  await sendMessage(fx, roomId, "owner", "m3-after-clear");
  const memberAfter = await getState(fx, roomId, "member");
  assert.deepEqual(
    (memberAfter.body.messages ?? []).map((m) => String(m.text)),
    ["m3-after-clear"],
  );
});

test("state gift events are incremental: no duplicates, no gaps, id tiebreak", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  const base = Date.now();
  const e1 = insertGiftEvent(fx, roomId, "owner", "member", base);
  const e2 = insertGiftEvent(fx, roomId, "member", "owner", base + 10);
  const e3 = insertGiftEvent(fx, roomId, "owner", "member", base + 20);
  // Same created_at, different ids: the (created_at, id) cursor must still
  // order them and never return the first one twice.
  const e4 = insertGiftEvent(fx, roomId, "member", "owner", base + 20);
  assert.ok(e3.id < e4.id, "tiebreak fixture must sort e3 before e4");

  const full = await getState(fx, roomId, "owner");
  assert.equal(full.status, 200, JSON.stringify(full.body));
  assert.deepEqual(
    (full.body.events ?? []).map((e) => String(e.id)),
    [e1.id, e2.id, e3.id, e4.id],
  );

  const afterE2 = await getState(fx, roomId, "owner", `?after=${e2.created_at}&after_id=${e2.id}`);
  assert.deepEqual(
    (afterE2.body.events ?? []).map((e) => String(e.id)),
    [e3.id, e4.id],
    "cursor after e2 must return only the later events",
  );

  const afterE3 = await getState(fx, roomId, "owner", `?after=${e3.created_at}&after_id=${e3.id}`);
  assert.deepEqual(
    (afterE3.body.events ?? []).map((e) => String(e.id)),
    [e4.id],
    "same-timestamp tiebreak must not repeat e3 or skip e4",
  );

  const afterE4 = await getState(fx, roomId, "owner", `?after=${e4.created_at}&after_id=${e4.id}`);
  assert.deepEqual(afterE4.body.events ?? [], [], "cursor past the last event returns none");
});

test("state returns settings identical to the standalone settings endpoint", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  const state = await getState(fx, roomId, "member");
  assert.equal(state.status, 200, JSON.stringify(state.body));
  const settings = state.body.settings ?? {};
  assert.equal(settings.name, "owner room");
  assert.equal(settings.seat_count, 12);
  assert.equal(Number(settings.locked), 0);
  assert.equal(settings.lock_password_set, 0);
  assert.equal(settings.theme_id, "dark");
  assert.equal(settings.theme_asset_key, "");
  assert.equal(settings.party_mode, "Friends-making Party");
  assert.equal(settings.room_mode, "voice");
  assert.equal(settings.seat_theme_id, "royal-gold");
  assert.equal(settings.group_pk_enabled, 0);
  assert.equal(settings.announcement, "");
  assert.equal(settings.avatar_key, "");
  assert.equal(settings.welcome_image_key, "");
  assert.equal(settings.feature?.messages?.enabled, true, "chat is on by default");
  assert.ok(!("lock_code" in settings), "non-owner must not see the lock code");
  assert.ok(!("lock_password_code" in settings), "password code must never leak");

  // Same loader as the standalone GET: byte-identical settings objects.
  const standalone = await getSettings(fx, roomId, "member");
  assert.equal(standalone.status, 200, JSON.stringify(standalone.body));
  assert.deepEqual(state.body.settings, standalone.body.settings);

  // Non-member still 403s even though settings exist.
  await makeUser(fx, "outsider");
  const outsider = await getState(fx, roomId, "outsider");
  assert.equal(outsider.status, 403);
  assert.equal(outsider.body.error, "room_membership_required");
});

test("state reflects a settings change within one call (announcement, name, room DP)", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  const before = await getState(fx, roomId, "member");
  assert.equal(before.body.settings.announcement, "");
  assert.equal(before.body.settings.name, "owner room");
  assert.equal(before.body.settings.avatar_key, "");

  const updated = await updateSettings(fx, roomId, "owner", { name: "Renamed room", announcement: "new-announcement" });
  assert.equal(updated.status, 200, JSON.stringify(updated.body));
  const avatarKey = `rooms/${roomId}/avatar-999.jpg`;
  const avatar = await setRoomAvatar(fx, roomId, "owner", avatarKey);
  assert.equal(avatar.status, 200, JSON.stringify(avatar.body));

  // The very next 3s state call must carry the new values — no 60s wait.
  const after = await getState(fx, roomId, "member");
  assert.equal(after.status, 200, JSON.stringify(after.body));
  assert.equal(after.body.settings.announcement, "new-announcement");
  assert.equal(after.body.settings.name, "Renamed room");
  assert.equal(after.body.settings.avatar_key, avatarKey);
});

test("state shows room chat off via settings.feature.messages", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  await sendMessage(fx, roomId, "owner", "before-off");
  const onState = await getState(fx, roomId, "member");
  assert.deepEqual((onState.body.messages ?? []).map((m) => String(m.text)), ["before-off"]);
  assert.equal(onState.body.settings.feature.messages.enabled, true);

  // Owner turns room chat off: the next state call hides chat AND says so.
  setMessagesFeature(fx, false);
  const offState = await getState(fx, roomId, "member");
  assert.deepEqual(offState.body.messages ?? [], [], "chat off must hide messages");
  assert.equal(offState.body.settings.feature.messages.enabled, false);
  assert.notEqual(offState.body.settings, null, "settings must still load when chat is off");

  // Back on: chat flows again in the same 3s call.
  setMessagesFeature(fx, true);
  await sendMessage(fx, roomId, "owner", "after-on");
  const backOn = await getState(fx, roomId, "member");
  assert.deepEqual((backOn.body.messages ?? []).map((m) => String(m.text)), ["before-off", "after-on"]);
  assert.equal(backOn.body.settings.feature.messages.enabled, true);
});
