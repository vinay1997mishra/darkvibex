// CP 20M pricing (Vinay, 2026-11-20): a CP request costs 20,000,000
// coins, breaking a CP costs another 20,000,000, and a rejected request
// is NOT refunded. The CP Invite gift is gone from the catalog.
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
  const secret = "cp-20m-cost-test-secret";
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

let publicIdCounter = 7660000;
async function makeUser(fx, userId, { coins = 100000, vipLevel = 0, country = "IN" } = {}) {
  const { sqlite, request } = fx;
  // Guest login is deleted permanently (Vinay 2026-11-20): test users are
  // created directly in SQLite instead of through the removed endpoint.
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

function makeMutualFriends(fx, a, b) {
  const now = Date.now();
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(a, b, now);
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(b, a, now);
}

function coins(fx, userId) {
  return fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get(userId).coins;
}

async function cpRequest(fx, from, to) {
  return fx.request("/api/cp/request", {
    method: "POST", userId: from,
    body: { user_id: from, target_user_id: to },
  });
}

async function cpRespond(fx, userId, accept) {
  return fx.request("/api/cp/respond", {
    method: "POST", userId,
    body: { user_id: userId, accept },
  });
}

async function cpDisconnectRequest(fx, userId) {
  return fx.request("/api/cp/disconnect/request", {
    method: "POST", userId, body: { user_id: userId },
  });
}

async function cpDisconnectRespond(fx, userId, accept) {
  return fx.request("/api/cp/disconnect/respond", {
    method: "POST", userId, body: { user_id: userId, accept },
  });
}

async function cpDisconnect(fx, userId) {
  return fx.request("/api/cp/disconnect", {
    method: "POST", userId, body: { user_id: userId },
  });
}

async function makeActiveCp(fx, a, b, coinsA = 50000000) {
  await makeUser(fx, a, { coins: coinsA });
  await makeUser(fx, b, { coins: 50000000 });
  makeMutualFriends(fx, a, b);
  const requested = await cpRequest(fx, a, b);
  assert.equal(requested.status, 201, JSON.stringify(requested.body));
  const accepted = await cpRespond(fx, b, true);
  assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
  assert.equal(accepted.body.cp?.state, "active", JSON.stringify(accepted.body));
}

test("CP request costs exactly 20,000,000 coins", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a", { coins: 50000000 });
  await makeUser(fx, "cp-b", { coins: 50000000 });
  makeMutualFriends(fx, "cp-a", "cp-b");
  const result = await cpRequest(fx, "cp-a", "cp-b");
  assert.equal(result.status, 201, JSON.stringify(result.body));
  assert.equal(result.body.coin_balance, 30000000);
  assert.equal(coins(fx, "cp-a"), 30000000);
  assert.equal(result.body.cp?.state, "pending");
  const row = fx.sqlite.prepare("SELECT * FROM cp_relationships WHERE user_a=? OR user_b=?").get("cp-a");
  assert.ok(row, "pending CP row must exist");
  const ledger = fx.sqlite.prepare(
    "SELECT * FROM wallet_ledger WHERE user_id=? AND kind=?"
  ).get("cp-a", "cp_connect");
  assert.ok(ledger, "cp_connect ledger entry must exist");
  assert.equal(ledger.amount, -20000000);
  assert.equal(ledger.balance_after, 30000000);
});

test("CP request fails with insufficient_coins below 20,000,000", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a", { coins: 19999999 });
  await makeUser(fx, "cp-b", { coins: 50000000 });
  makeMutualFriends(fx, "cp-a", "cp-b");
  const result = await cpRequest(fx, "cp-a", "cp-b");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.error, "insufficient_coins");
  assert.equal(coins(fx, "cp-a"), 19999999);
  const row = fx.sqlite.prepare("SELECT * FROM cp_relationships WHERE user_a=? OR user_b=?").get("cp-a");
  assert.equal(row, undefined);
});

test("Rejecting a CP request does not refund the 20,000,000", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a", { coins: 50000000 });
  await makeUser(fx, "cp-b", { coins: 50000000 });
  makeMutualFriends(fx, "cp-a", "cp-b");
  const requested = await cpRequest(fx, "cp-a", "cp-b");
  assert.equal(requested.status, 201, JSON.stringify(requested.body));
  const rejected = await cpRespond(fx, "cp-b", false);
  assert.equal(rejected.status, 200, JSON.stringify(rejected.body));
  assert.equal(coins(fx, "cp-a"), 30000000);
  const row = fx.sqlite.prepare("SELECT * FROM cp_relationships WHERE user_a=? OR user_b=?").get("cp-a");
  assert.equal(row, undefined);
});

test("Disconnect request costs 20,000,000 to the requester; accept ends the CP", async () => {
  const fx = await fixture();
  await makeActiveCp(fx, "cp-a", "cp-b");
  assert.equal(coins(fx, "cp-a"), 30000000);
  const requested = await cpDisconnectRequest(fx, "cp-a");
  assert.equal(requested.status, 200, JSON.stringify(requested.body));
  assert.equal(coins(fx, "cp-a"), 10000000);
  assert.equal(requested.body.cp?.disconnect_state, "requested");
  const ledger = fx.sqlite.prepare(
    "SELECT * FROM wallet_ledger WHERE user_id=? AND kind=?"
  ).get("cp-a", "cp_disconnect");
  assert.ok(ledger, "cp_disconnect ledger entry must exist");
  assert.equal(ledger.amount, -20000000);
  assert.equal(ledger.balance_after, 10000000);
  const accepted = await cpDisconnectRespond(fx, "cp-b", true);
  assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
  assert.equal(accepted.body.cp, null);
  const row = fx.sqlite.prepare("SELECT * FROM cp_relationships WHERE user_a=? OR user_b=?").get("cp-a");
  assert.equal(row, undefined);
  // The partner who accepted paid nothing.
  assert.equal(coins(fx, "cp-b"), 50000000);
});

test("Disconnect request fails with insufficient_coins and the CP stays active", async () => {
  const fx = await fixture();
  // Exactly 20M: the request takes it all, leaving nothing for the breakup.
  await makeActiveCp(fx, "cp-a", "cp-b", 20000000);
  assert.equal(coins(fx, "cp-a"), 0);
  const requested = await cpDisconnectRequest(fx, "cp-a");
  assert.equal(requested.status, 400, JSON.stringify(requested.body));
  assert.equal(requested.body.error, "insufficient_coins");
  const state = await fx.request("/api/cp?user_id=cp-a", { userId: "cp-a" });
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.equal(state.body.cp?.state, "active");
  assert.equal(state.body.cp?.disconnect_state, "none");
});

test("Direct disconnect costs 20,000,000 and costs nothing when there is no CP", async () => {
  const fx = await fixture();
  await makeActiveCp(fx, "cp-a", "cp-b");
  const result = await cpDisconnect(fx, "cp-a");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(coins(fx, "cp-a"), 10000000);
  const row = fx.sqlite.prepare("SELECT * FROM cp_relationships WHERE user_a=? OR user_b=?").get("cp-a");
  assert.equal(row, undefined);
  const again = await cpDisconnect(fx, "cp-a");
  assert.equal(again.status, 200, JSON.stringify(again.body));
  assert.equal(coins(fx, "cp-a"), 10000000);
});

test("CP Invite gift is gone from the catalog", async () => {
  const fx = await fixture();
  await makeUser(fx, "gift-a", { coins: 50000000 });
  await makeUser(fx, "gift-b", { coins: 50000000 });
  const created = await fx.request("/api/rooms", {
    method: "POST", userId: "gift-a",
    body: { owner_user_id: "gift-a", owner_name: "gift-a", name: "gift-a room", seat_count: 12 },
  });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  const roomId = String(created.body.room_id);
  const joined = await fx.request(`/api/rooms/${roomId}/join`, {
    method: "POST", userId: "gift-b",
    body: { user_id: "gift-b", display_name: "gift-b" },
  });
  assert.equal(joined.status, 200, JSON.stringify(joined.body));
  const sent = await fx.request("/api/gifts/send", {
    method: "POST", userId: "gift-a",
    body: { sender_user_id: "gift-a", receiver_user_id: "gift-b", gift_id: "cp-invite", coin_cost: 2222222, room_id: roomId },
  });
  assert.equal(sent.status, 400, JSON.stringify(sent.body));
  assert.equal(sent.body.error, "invalid_gift");
  assert.equal(coins(fx, "gift-a"), 50000000);
});
