// Room presence: no auto-remove (Vinay, 2026-11-21) — an ID leaves a
// room ONLY when the user leaves it himself, is kicked/banned, changes
// country, or joins another room. A backgrounded or quiet member is
// never pruned by any 30s timeout.
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
  const secret = "room-presence-no-auto-remove-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, FILES: files };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, request, files };
}

let publicIdCounter = 7670000;
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

function memberCount(fx, roomId) {
  return Number(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_members WHERE room_id=?").get(roomId)?.n ?? 0);
}

function memberIds(body) {
  return (body.members ?? []).map((member) => String(member.user_id));
}

test("a member quiet for over 30s still gets room state but is hidden until they poll again", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  // Member went quiet 60s ago (backgrounded app, polling stopped):
  // not online any more, so nobody sees them in the list — but the
  // row stays, so they are NOT removed from the room.
  fx.sqlite.prepare("UPDATE room_members SET updated_at=? WHERE room_id=? AND user_id=?").run(Date.now() - 60000, roomId, "member");
  const hidden = await fx.request(`/api/rooms/${roomId}/members?user_id=owner`, { userId: "owner" });
  assert.equal(hidden.status, 200, JSON.stringify(hidden.body));
  assert.equal(memberIds(hidden.body).includes("member"), false);
  assert.equal(memberCount(fx, roomId), 2);

  // The quiet member still gets the combined state — no 403, no kick.
  const state = await fx.request(`/api/rooms/${roomId}/state`, { userId: "member" });
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.equal(state.body.ok, true);
  // Their own state call heartbeats them, so they are online again
  // and reappear in the list at once.
  assert.equal(memberIds(state.body).includes("member"), true);
  const shown = await fx.request(`/api/rooms/${roomId}/members?user_id=owner`, { userId: "owner" });
  assert.equal(shown.status, 200, JSON.stringify(shown.body));
  assert.equal(memberIds(shown.body).includes("member"), true);
  assert.equal(memberCount(fx, roomId), 2);
});

test("a room list call never removes a backgrounded member", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "member");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "member");

  // Both members quiet (updated_at must stay > 0): the rows stay, but
  // nobody is online, so the member list shows only the caller once
  // their own fetch heartbeats them.
  fx.sqlite.prepare("UPDATE room_members SET updated_at = 1 WHERE room_id = ?").run(roomId);
  const listed = await fx.request("/api/rooms", { userId: "owner" });
  assert.equal(listed.status, 200, JSON.stringify(listed.body));
  assert.equal(memberCount(fx, roomId), 2);
  const members = await fx.request(`/api/rooms/${roomId}/members?user_id=owner`, { userId: "owner" });
  assert.equal(members.status, 200, JSON.stringify(members.body));
  assert.equal(memberIds(members.body).length, 1);
  assert.equal(memberIds(members.body).includes("owner"), true);
  assert.equal(memberIds(members.body).includes("member"), false);
});

test("leaving still removes the member and a kick still 403s with a marker", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner");
  await makeUser(fx, "leaver");
  await makeUser(fx, "victim");
  const roomId = await makeRoom(fx, "owner");
  await joinRoom(fx, roomId, "leaver");
  await joinRoom(fx, roomId, "victim");

  await leaveRoom(fx, roomId, "leaver");
  assert.equal(memberCount(fx, roomId), 2);
  const leftMembers = await fx.request(`/api/rooms/${roomId}/members?user_id=leaver`, { userId: "leaver" });
  assert.equal(leftMembers.status, 403, JSON.stringify(leftMembers.body));
  assert.equal(leftMembers.body.error, "room_membership_required");
  const leftStatus = await fx.request(`/api/rooms/${roomId}/kick-status?user_id=leaver`, { userId: "leaver" });
  assert.equal(leftStatus.body.kicked, false);

  const kicked = await fx.request(`/api/rooms/${roomId}/members`, {
    method: "POST", userId: "owner",
    body: { user_id: "owner", target_user_id: "victim" },
  });
  assert.equal(kicked.status, 200, JSON.stringify(kicked.body));
  assert.equal(memberCount(fx, roomId), 1);
  const victimMembers = await fx.request(`/api/rooms/${roomId}/members?user_id=victim`, { userId: "victim" });
  assert.equal(victimMembers.status, 403, JSON.stringify(victimMembers.body));
  assert.equal(victimMembers.body.error, "room_membership_required");
  const victimStatus = await fx.request(`/api/rooms/${roomId}/kick-status?user_id=victim`, { userId: "victim" });
  assert.equal(victimStatus.body.kicked, true);
});
