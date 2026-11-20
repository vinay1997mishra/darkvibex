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
  const secret = "room-block-by-id-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, request };
}

let publicIdCounter = 7654000;
async function makeUser(fx, userId, vipLevel = 0) {
  const { sqlite, request } = fx;
  // Guest login is deleted permanently (Vinay 2026-11-20): test users are
  // created directly in SQLite instead of through the removed endpoint.
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=1000, country_code='IN', public_id=? WHERE id=?").run(vipLevel, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

async function makeRoom(fx, ownerId) {
  const { request } = fx;
  const created = await request("/api/rooms", {
    method: "POST",
    userId: ownerId,
    body: { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12 },
  });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return String(created.body.room_id);
}

async function joinRoom(fx, roomId, userId) {
  return fx.request(`/api/rooms/${roomId}/join`, {
    method: "POST",
    userId,
    body: { user_id: userId, display_name: userId },
  });
}

async function leaveRoom(fx, roomId, userId) {
  return fx.request(`/api/rooms/${roomId}/leave`, {
    method: "POST",
    userId,
    body: { user_id: userId },
  });
}

async function blockMember(fx, roomId, actorId, targetId) {
  return fx.request(`/api/rooms/${roomId}/members`, {
    method: "POST",
    userId: actorId,
    body: { user_id: actorId, target_user_id: targetId, ban: true },
  });
}

async function kickMember(fx, roomId, actorId, targetId) {
  return fx.request(`/api/rooms/${roomId}/members`, {
    method: "POST",
    userId: actorId,
    body: { user_id: actorId, target_user_id: targetId },
  });
}

async function blacklist(fx, roomId, actorId) {
  return fx.request(`/api/rooms/${roomId}/blacklist`, { userId: actorId });
}

test("blocking a member adds them to the blacklist and keeps them out", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner1");
  const member = await makeUser(fx, "member1");
  const roomId = await makeRoom(fx, owner.userId);
  assert.equal((await joinRoom(fx, roomId, member.userId)).body.ok, true);
  const blocked = await blockMember(fx, roomId, owner.userId, member.userId);
  assert.equal(blocked.body.ok, true, JSON.stringify(blocked.body));
  const list = await blacklist(fx, roomId, owner.userId);
  assert.equal(list.body.blacklist.length, 1);
  assert.equal(list.body.blacklist[0].user_id, member.userId);
  const rejoin = await joinRoom(fx, roomId, member.userId);
  assert.equal(rejoin.status, 403);
  assert.equal(rejoin.body.error, "room_blocked");
});

test("blocking someone who already left the room works (block by ID)", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner2");
  const member = await makeUser(fx, "member2");
  const roomId = await makeRoom(fx, owner.userId);
  assert.equal((await joinRoom(fx, roomId, member.userId)).body.ok, true);
  assert.equal((await leaveRoom(fx, roomId, member.userId)).body.ok, true);
  const blocked = await blockMember(fx, roomId, owner.userId, member.userId);
  assert.equal(blocked.body.ok, true, JSON.stringify(blocked.body));
  const list = await blacklist(fx, roomId, owner.userId);
  assert.equal(list.body.blacklist.length, 1);
  const rejoin = await joinRoom(fx, roomId, member.userId);
  assert.equal(rejoin.status, 403);
  assert.equal(rejoin.body.error, "room_blocked");
});

test("kicking someone who already left still fails", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner3");
  const member = await makeUser(fx, "member3");
  const roomId = await makeRoom(fx, owner.userId);
  assert.equal((await joinRoom(fx, roomId, member.userId)).body.ok, true);
  assert.equal((await leaveRoom(fx, roomId, member.userId)).body.ok, true);
  const kicked = await kickMember(fx, roomId, owner.userId, member.userId);
  assert.equal(kicked.status, 404);
  assert.equal(kicked.body.error, "target_not_in_room");
});

test("blocking a user that does not exist fails", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner4");
  const roomId = await makeRoom(fx, owner.userId);
  const blocked = await blockMember(fx, roomId, owner.userId, "no-such-user");
  assert.equal(blocked.status, 404);
  assert.equal(blocked.body.error, "user_not_found");
});

test("blocking the room owner fails", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner5");
  const admin = await makeUser(fx, "admin5");
  const roomId = await makeRoom(fx, owner.userId);
  assert.equal((await joinRoom(fx, roomId, admin.userId)).body.ok, true);
  const made = await fx.request(`/api/rooms/${roomId}/members`, {
    method: "POST",
    userId: owner.userId,
    body: { user_id: owner.userId, target_user_id: admin.userId, action: "set_admin" },
  });
  assert.equal(made.body.ok, true, JSON.stringify(made.body));
  const blocked = await blockMember(fx, roomId, admin.userId, owner.userId);
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, "moderation_target_protected");
});

test("unblocking lets the user join again", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner6");
  const member = await makeUser(fx, "member6");
  const roomId = await makeRoom(fx, owner.userId);
  assert.equal((await joinRoom(fx, roomId, member.userId)).body.ok, true);
  assert.equal((await blockMember(fx, roomId, owner.userId, member.userId)).body.ok, true);
  const unblocked = await fx.request(`/api/rooms/${roomId}/blacklist`, {
    method: "POST",
    userId: owner.userId,
    body: { target_user_id: member.userId },
  });
  assert.equal(unblocked.body.ok, true, JSON.stringify(unblocked.body));
  assert.equal((await joinRoom(fx, roomId, member.userId)).body.ok, true);
});

test("by-public-id lookup resolves 7 and 8 digit spellings, unknown is 404", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner7");
  const member = await makeUser(fx, "member7");
  const seven = await fx.request(`/api/users/by-public-id?public_id=${member.publicId}`, { userId: owner.userId });
  assert.equal(seven.status, 200, JSON.stringify(seven.body));
  assert.equal(seven.body.user.user_id, member.userId);
  const eight = await fx.request(`/api/users/by-public-id?public_id=${member.publicId.padStart(8, "0")}`, { userId: owner.userId });
  assert.equal(eight.status, 200, JSON.stringify(eight.body));
  assert.equal(eight.body.user.user_id, member.userId);
  const missing = await fx.request("/api/users/by-public-id?public_id=99999999", { userId: owner.userId });
  assert.equal(missing.status, 404);
  assert.equal(missing.body.error, "user_not_found");
});
