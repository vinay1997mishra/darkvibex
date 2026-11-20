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
  const secret = "vip-anti-mute-test-secret";
  const env = { DB, SESSION_SECRET: secret, ALLOW_GUEST_SESSIONS: true };
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
  const created = await request("/api/session/guest", { method: "POST", body: { user_id: userId, display_name: userId } });
  assert.equal(created.status, 200);
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=1000, country_code='IN', public_id=? WHERE id=?").run(vipLevel, String(publicIdCounter), userId);
  return userId;
}

async function makeRoom(fx, ownerId, vipOnly = 0) {
  const { request } = fx;
  const created = await request("/api/rooms", {
    method: "POST",
    userId: ownerId,
    body: { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12, vip_only: vipOnly },
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

async function takeSeat(fx, roomId, userId, seatIndex) {
  const seated = await fx.request(`/api/rooms/${roomId}/seat`, {
    method: "POST",
    userId,
    body: { user_id: userId, seat_index: seatIndex, mic_muted: false },
  });
  assert.equal(seated.status, 200, JSON.stringify(seated.body));
  assert.equal(seated.body.ok, true);
}

test("VIP-only room with VIP1+ lets any VIP in and keeps non-VIP out", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner1", 10);
  const roomId = await makeRoom(fx, owner, 1);
  const vip1 = await makeUser(fx, "vip1", 1);
  const plain = await makeUser(fx, "plain1", 0);
  assert.equal((await joinRoom(fx, roomId, vip1)).body.ok, true);
  const blocked = await joinRoom(fx, roomId, plain);
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, "room_vip_only");
});

test("VIP-only room with VIP5+ lets VIP5 in and keeps VIP4 out", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner2", 10);
  const roomId = await makeRoom(fx, owner, 5);
  const vip5 = await makeUser(fx, "vip5", 5);
  const vip4 = await makeUser(fx, "vip4", 4);
  assert.equal((await joinRoom(fx, roomId, vip5)).body.ok, true);
  const blocked = await joinRoom(fx, roomId, vip4);
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, "room_vip_only");
});

test("room owner can always re-enter their own VIP-only room", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner3", 10);
  const roomId = await makeRoom(fx, owner, 5);
  fx.sqlite.prepare("UPDATE users SET vip_level=0 WHERE id=?").run(owner);
  fx.sqlite.prepare("UPDATE user_vip SET level=0, active_until=NULL WHERE user_id=?").run(owner);
  const rejoined = await joinRoom(fx, roomId, owner);
  assert.equal(rejoined.body.ok, true);
});

test("creating a VIP-only room needs VIP10; other levels are rejected", async () => {
  const fx = await fixture();
  const plain = await makeUser(fx, "owner4", 0);
  const blocked = await fx.request("/api/rooms", {
    method: "POST",
    userId: plain,
    body: { owner_user_id: plain, owner_name: plain, name: "vip room", seat_count: 12, vip_only: 1 },
  });
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, "vip_only_requires_vip10");
  const bad = await fx.request("/api/rooms", {
    method: "POST",
    userId: await makeUser(fx, "owner5", 10),
    body: { owner_user_id: "owner5", owner_name: "owner5", name: "vip room", seat_count: 12, vip_only: 3 },
  });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "invalid_vip_only");
});

test("room owner can switch the VIP-only threshold from the controls", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner6", 10);
  const roomId = await makeRoom(fx, owner, 0);
  const set = await fx.request(`/api/rooms/${roomId}/controls`, {
    method: "POST",
    userId: owner,
    body: { user_id: owner, action: "vip_only", vip_only: 5 },
  });
  assert.equal(set.status, 200);
  assert.equal(set.body.vip_only, 5);
  const controls = await fx.request(`/api/rooms/${roomId}/controls`, { userId: owner });
  assert.equal(controls.body.vip_only, 5);
  const off = await fx.request(`/api/rooms/${roomId}/controls`, {
    method: "POST",
    userId: owner,
    body: { user_id: owner, action: "vip_only", vip_only: 0 },
  });
  assert.equal(off.body.vip_only, 0);
});

test("seat mute is blocked on an active VIP13+ member (Anti-Mute)", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner7", 10);
  const roomId = await makeRoom(fx, owner, 0);
  const vip13 = await makeUser(fx, "vip13", 13);
  await joinRoom(fx, roomId, vip13);
  await takeSeat(fx, roomId, vip13, 0);
  const blocked = await fx.request(`/api/rooms/${roomId}/controls`, {
    method: "POST",
    userId: owner,
    body: { user_id: owner, action: "seat_mute", seat_index: 0, muted: true },
  });
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, "vip_anti_mute");
  const row = fx.sqlite.prepare("SELECT mic_muted FROM room_members WHERE room_id=? AND user_id=?").get(roomId, vip13);
  assert.equal(Number(row.mic_muted), 0);
});

test("seat mute works on a VIP12 member and on your own seat", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "owner8", 10);
  const roomId = await makeRoom(fx, owner, 0);
  const vip12 = await makeUser(fx, "vip12", 12);
  await joinRoom(fx, roomId, vip12);
  await takeSeat(fx, roomId, vip12, 0);
  const muted = await fx.request(`/api/rooms/${roomId}/controls`, {
    method: "POST",
    userId: owner,
    body: { user_id: owner, action: "seat_mute", seat_index: 0, muted: true },
  });
  assert.equal(muted.status, 200);
  assert.equal(muted.body.room_muted, true);
  const row = fx.sqlite.prepare("SELECT mic_muted FROM room_members WHERE room_id=? AND user_id=?").get(roomId, vip12);
  assert.equal(Number(row.mic_muted), 1);
  // Muting your own seat is never blocked by Anti-Mute.
  const vip13owner = await makeUser(fx, "owner9", 13);
  const ownRoom = await makeRoom(fx, vip13owner, 0);
  await takeSeat(fx, ownRoom, vip13owner, 0);
  const self = await fx.request(`/api/rooms/${ownRoom}/controls`, {
    method: "POST",
    userId: vip13owner,
    body: { user_id: vip13owner, action: "seat_mute", seat_index: 0, muted: true },
  });
  assert.equal(self.status, 200);
  assert.equal(self.body.room_muted, true);
});
