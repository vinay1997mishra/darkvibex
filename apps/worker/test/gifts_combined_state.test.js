// Combined gifts + diamonds + coins (Vinay, 2026-11-21 — "Har user ka alag
// combined API rakh"): ONE session-scoped call every 3s — GET
// /api/gifts/combined — carrying the full priced catalog (exactly the same
// gifts as GET /api/gifts/catalog) + this user's live coin/diamond balances
// + recent diamond/coin history, so gift UIs, the Diamond received view and
// the coin balance update together without separate calls. Per-user: the
// caller is the session user, so another user's balances and gift history
// must never appear. Histories are capped at 20 recent rows per section;
// the full 200-row histories stay on the standalone history endpoints.
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
  const secret = "gifts-combined-test-secret";
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

function seedUsers(sqlite) {
  sqlite.prepare(
    "INSERT INTO users(id,display_name,coins,diamonds,created_at,updated_at) VALUES(?,?,?,?,?,?)",
  ).run("alice", "Alice", 1000000, 5000, 1000, 1000);
  sqlite.prepare(
    "INSERT INTO users(id,display_name,coins,diamonds,created_at,updated_at) VALUES(?,?,?,?,?,?)",
  ).run("bob", "Bob", 2500000, 700, 1000, 1000);
}

function seedHistory(sqlite) {
  // Bob sent Alice a Rose (100 coins = 100 diamonds for Alice).
  sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES(?,?,?,?,?,?,?)",
  ).run("ge-1", null, "bob", "alice", "rose", 100, 2000);
  // Alice sent Bob a Crown (1000 coins).
  sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES(?,?,?,?,?,?,?)",
  ).run("ge-2", null, "alice", "bob", "crown", 1000, 3000);
  // Alice exchanged 100 diamonds for 60 coins. The table is created on
  // demand by ensureDiamondConversionTable (not in schema.sql), so the
  // test creates it first with the same DDL.
  sqlite.exec(`CREATE TABLE IF NOT EXISTS diamond_conversions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    diamonds INTEGER NOT NULL CHECK(diamonds>0),
    coins INTEGER NOT NULL CHECK(coins>=0),
    rate REAL NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
  )`);
  sqlite.prepare(
    "INSERT INTO diamond_conversions(id,user_id,diamonds,coins,rate,created_at) VALUES(?,?,?,?,?,?)",
  ).run("dc-1", "alice", 100, 60, 0.6, 4000);
  // Alice received coins as a coin seller.
  sqlite.prepare(
    "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)",
  ).run("wl-1", "alice", "coin_seller_received", 8000000, 9000000, null, 5000);
}

test("one combined call carries catalog + live balances + recent histories for the session user", async () => {
  const fx = await fixture();
  seedUsers(fx.sqlite);
  seedHistory(fx.sqlite);

  const res = await fx.request("/api/gifts/combined", { userId: "alice" });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const body = res.body;
  assert.equal(body.ok, true);
  assert.equal(typeof body.server_time, "number");
  // Full priced catalog, same as the standalone catalog endpoint.
  assert.ok(Array.isArray(body.gifts));
  const rose = body.gifts.find((gift) => gift.id === "rose");
  assert.ok(rose, "rose must be in the combined catalog");
  assert.equal(rose.coin_cost, 100);
  const catalog = await fx.request("/api/gifts/catalog?user_id=alice", { userId: "alice" });
  assert.equal(catalog.status, 200, JSON.stringify(catalog.body));
  assert.deepEqual(body.gifts, catalog.body.gifts);
  // Live balances — Alice's only.
  assert.equal(body.current_coins, 1000000);
  assert.equal(body.current_diamonds, 5000);
  assert.equal(body.wallet.coins, 1000000);
  assert.equal(body.wallet.diamonds, 5000);
  // Diamonds received: Bob's Rose to Alice; conversions ride along.
  assert.equal(body.diamonds.current_diamonds, 5000);
  assert.equal(body.diamonds.gifts.length, 1);
  assert.equal(body.diamonds.gifts[0].gift_id, "rose");
  assert.equal(body.diamonds.gifts[0].sender_user_id, "bob");
  assert.equal(body.diamonds.gifts[0].diamonds, 100);
  assert.equal(body.diamonds.conversions.length, 1);
  assert.equal(body.diamonds.conversions[0].diamonds, 100);
  assert.equal(body.diamonds.conversions[0].coins, 60);
  // Coins: Alice's sent Crown to Bob + her seller receipt.
  assert.equal(body.coins.current_coins, 1000000);
  assert.equal(body.coins.gifts.length, 1);
  assert.equal(body.coins.gifts[0].gift_id, "crown");
  assert.equal(body.coins.gifts[0].receiver_user_id, "bob");
  assert.equal(body.coins.gifts[0].coins, 1000);
  assert.equal(body.coins.seller_received.length, 1);
  assert.equal(body.coins.seller_received[0].coins, 8000000);
  fx.sqlite.close();
});

test("per-user isolation: another user's balances and history never appear", async () => {
  const fx = await fixture();
  seedUsers(fx.sqlite);
  seedHistory(fx.sqlite);

  const res = await fx.request("/api/gifts/combined", { userId: "bob" });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const body = res.body;
  assert.equal(body.current_coins, 2500000);
  assert.equal(body.current_diamonds, 700);
  // Bob received Alice's Crown; he never received the Rose.
  assert.equal(body.diamonds.gifts.length, 1);
  assert.equal(body.diamonds.gifts[0].gift_id, "crown");
  assert.equal(body.diamonds.conversions.length, 0);
  // Bob sent the Rose; Alice's seller receipt is not his.
  assert.equal(body.coins.gifts.length, 1);
  assert.equal(body.coins.gifts[0].gift_id, "rose");
  assert.equal(body.coins.seller_received.length, 0);
  fx.sqlite.close();
});

test("combined call requires a session (no user_id from the request is trusted)", async () => {
  const fx = await fixture();
  seedUsers(fx.sqlite);
  const res = await fx.request("/api/gifts/combined?user_id=alice");
  assert.notEqual(res.status, 200);
  assert.notEqual(res.body?.ok, true);
  fx.sqlite.close();
});

test("standalone catalog, diamonds history and coins history keep working (additive)", async () => {
  const fx = await fixture();
  seedUsers(fx.sqlite);
  seedHistory(fx.sqlite);

  const catalog = await fx.request("/api/gifts/catalog?user_id=alice", { userId: "alice" });
  assert.equal(catalog.status, 200, JSON.stringify(catalog.body));
  assert.ok(catalog.body.gifts.some((gift) => gift.id === "rose"));

  const diamonds = await fx.request("/api/wallet/diamonds/history?user_id=alice", { userId: "alice" });
  assert.equal(diamonds.status, 200, JSON.stringify(diamonds.body));
  assert.equal(diamonds.body.current_diamonds, 5000);
  assert.equal(diamonds.body.gifts.length, 1);

  const coins = await fx.request("/api/wallet/coins/history?user_id=alice", { userId: "alice" });
  assert.equal(coins.status, 200, JSON.stringify(coins.body));
  assert.equal(coins.body.current_coins, 1000000);
  assert.equal(coins.body.gifts.length, 1);
  fx.sqlite.close();
});
