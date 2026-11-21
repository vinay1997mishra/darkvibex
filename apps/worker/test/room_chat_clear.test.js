// Room chat clear (Vinay, 2026-11-20): "Chat clear" lives in the 4-Box
// menu for the room owner/admin only. An admin clear hides the old chat
// from everyone except the owner; an owner clear hides it from everyone.
// Entering a room shows no old chat (only messages after joined_at), and
// the moment a room has no members left its chat is deleted — no backup
// anywhere.
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
  const secret = "room-chat-clear-test-secret";
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

async function getMessages(fx, roomId, userId) {
  const result = await fx.request(`/api/rooms/${roomId}/messages`, { userId });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  return (result.body.messages ?? []).map((message) => String(message.text ?? ""));
}

async function clearChat(fx, roomId, userId) {
  return fx.request(`/api/rooms/${roomId}/messages/clear`, { method: "POST", userId, body: { user_id: userId } });
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function messageCount(fx, roomId) {
  return Number(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_messages WHERE room_id=?").get(roomId)?.n ?? 0);
}

test("regular member cannot clear, non-member cannot clear", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  await makeUser(fx, "outsider");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  const memberClear = await clearChat(fx, roomId, "member");
  assert.equal(memberClear.status, 403);
  assert.equal(memberClear.body.error, "room_clear_owner_admin_only");

  const outsiderClear = await clearChat(fx, roomId, "outsider");
  assert.equal(outsiderClear.status, 403);
  assert.equal(outsiderClear.body.error, "room_membership_required");
});

test("admin clear hides old chat from everyone except the owner", async () => {
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
  await sendMessage(fx, roomId, "admin", "m2-admin");
  await sleep(10);
  await sendMessage(fx, roomId, "member", "m3-member");
  await sleep(10);

  const cleared = await clearChat(fx, roomId, "admin");
  assert.equal(cleared.status, 200, JSON.stringify(cleared.body));
  assert.equal(cleared.body.ok, true);

  assert.deepEqual(await getMessages(fx, roomId, "owner"), ["m1-owner", "m2-admin", "m3-member"]);
  assert.deepEqual(await getMessages(fx, roomId, "admin"), []);
  assert.deepEqual(await getMessages(fx, roomId, "member"), []);

  await sleep(10);
  await sendMessage(fx, roomId, "owner", "m4-after-admin-clear");
  assert.deepEqual(await getMessages(fx, roomId, "owner"), ["m1-owner", "m2-admin", "m3-member", "m4-after-admin-clear"]);
  assert.deepEqual(await getMessages(fx, roomId, "admin"), ["m4-after-admin-clear"]);
  assert.deepEqual(await getMessages(fx, roomId, "member"), ["m4-after-admin-clear"]);
});

test("owner clear hides old chat from everyone including the owner", async () => {
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
  await sendMessage(fx, roomId, "admin", "m2-admin");
  await sleep(10);
  // An earlier admin clear must not resurrect anything for the owner
  // once the owner clears: the owner clear hides everything before it.
  await clearChat(fx, roomId, "admin");
  await sleep(10);
  await sendMessage(fx, roomId, "member", "m3-after-admin-clear");
  await sleep(10);

  const cleared = await clearChat(fx, roomId, "owner");
  assert.equal(cleared.status, 200, JSON.stringify(cleared.body));

  assert.deepEqual(await getMessages(fx, roomId, "owner"), []);
  assert.deepEqual(await getMessages(fx, roomId, "admin"), []);
  assert.deepEqual(await getMessages(fx, roomId, "member"), []);

  await sleep(10);
  await sendMessage(fx, roomId, "member", "m4-after-owner-clear");
  assert.deepEqual(await getMessages(fx, roomId, "owner"), ["m4-after-owner-clear"]);
  assert.deepEqual(await getMessages(fx, roomId, "admin"), ["m4-after-owner-clear"]);
  assert.deepEqual(await getMessages(fx, roomId, "member"), ["m4-after-owner-clear"]);
});

test("a member only sees messages sent after they joined", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "late");
  const roomId = await makeRoom(fx, "owner");

  await sendMessage(fx, roomId, "owner", "before-late-joined");
  await sleep(10);
  await joinRoom(fx, roomId, "late");
  assert.deepEqual(await getMessages(fx, roomId, "late"), []);

  await sleep(10);
  await sendMessage(fx, roomId, "late", "after-late-joined");
  assert.deepEqual(await getMessages(fx, roomId, "owner"), ["before-late-joined", "after-late-joined"]);
  assert.deepEqual(await getMessages(fx, roomId, "late"), ["after-late-joined"]);
});

test("leaving and re-entering hides the old chat", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "rejoiner");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "rejoiner");

  await sendMessage(fx, roomId, "owner", "m1-first-stay");
  await sleep(10);
  await sendMessage(fx, roomId, "rejoiner", "m2-first-stay");
  await sleep(10);
  assert.deepEqual(await getMessages(fx, roomId, "rejoiner"), ["m1-first-stay", "m2-first-stay"]);

  await leaveRoom(fx, roomId, "rejoiner");
  await sleep(10);
  await joinRoom(fx, roomId, "rejoiner");
  assert.deepEqual(await getMessages(fx, roomId, "rejoiner"), []);

  await sleep(10);
  await sendMessage(fx, roomId, "owner", "m3-second-stay");
  assert.deepEqual(await getMessages(fx, roomId, "rejoiner"), ["m3-second-stay"]);
});

test("when the last member leaves, the room chat is deleted", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  await sendMessage(fx, roomId, "owner", "m1");
  await sleep(10);
  await sendMessage(fx, roomId, "member", "m2");
  assert.equal(messageCount(fx, roomId), 2);

  await leaveRoom(fx, roomId, "owner");
  assert.equal(messageCount(fx, roomId), 2, "chat stays while a member remains");
  assert.deepEqual(await getMessages(fx, roomId, "member"), ["m1", "m2"]);

  await leaveRoom(fx, roomId, "member");
  assert.equal(messageCount(fx, roomId), 0, "chat is gone the moment the room closes");

  await makeUser(fx, "fresh");
  await joinRoom(fx, roomId, "fresh");
  assert.deepEqual(await getMessages(fx, roomId, "fresh"), []);
});

test("stale members stay in the room and the chat is wiped only when the last member leaves", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  await sendMessage(fx, roomId, "owner", "m1");
  await sleep(10);
  await sendMessage(fx, roomId, "member", "m2");
  assert.equal(messageCount(fx, roomId), 2);

  // Both members went quiet: their presence rows are older than the
  // 30s TTL. Since 2026-11-21 (Vinay) there is no presence prune, so
  // the next room list must NOT remove them and must NOT wipe the
  // chat — but only online members are SHOWN, so the quiet member is
  // hidden from the list until they poll again. (updated_at must stay
  // > 0: rows that never heartbeated are a different case.)
  fx.sqlite.prepare("UPDATE room_members SET updated_at = 1 WHERE room_id = ?").run(roomId);
  const listed = await fx.request("/api/rooms", { userId: "owner" });
  assert.equal(listed.status, 200, JSON.stringify(listed.body));
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_members WHERE room_id=?").get(roomId).n, 2);
  assert.equal(messageCount(fx, roomId), 2);
  const members = await fx.request(`/api/rooms/${roomId}/members?user_id=owner`, { userId: "owner" });
  assert.equal(members.status, 200, JSON.stringify(members.body));
  assert.equal((members.body.members ?? []).length, 1);

  // The chat is wiped only when the room genuinely empties: both
  // members leave for real.
  await leaveRoom(fx, roomId, "member");
  assert.equal(messageCount(fx, roomId), 2);
  await leaveRoom(fx, roomId, "owner");
  assert.equal(messageCount(fx, roomId), 0);
});
