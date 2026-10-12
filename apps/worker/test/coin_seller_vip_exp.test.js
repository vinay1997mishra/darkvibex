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
  const secret = "coin-seller-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  for (const [id, name] of [["seller", "Seller"], ["receiver", "Receiver"]]) {
    const response = await request("/api/session/guest", { method: "POST", body: { user_id: id, display_name: name } });
    assert.equal(response.status, 200);
  }
  sqlite.prepare("UPDATE users SET role='coin_seller',coins=100000 WHERE id='seller'").run();
  return { sqlite, request };
}

test("Coin Seller grants up to 10,000 VIP EXP twice per receiver per India calendar month", async () => {
  const { sqlite, request } = await fixture();
  const transfer = (coins) => request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins },
  });

  const first = await transfer(10000);
  assert.equal(first.status, 200);
  assert.equal(first.body.vip_award.awarded_exp, 10000);
  assert.equal(first.body.vip_award.monthly_grants_remaining, 1);

  const second = await transfer(20000);
  assert.equal(second.status, 200);
  assert.equal(second.body.vip_award.awarded_exp, 10000);
  assert.equal(second.body.vip_award.monthly_grants_remaining, 0);

  const sellerBefore = sqlite.prepare("SELECT coins FROM users WHERE id='seller'").get().coins;
  const receiverBefore = sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins;
  const third = await transfer(10000);
  assert.equal(third.status, 409);
  assert.equal(third.body.error, "vip_exp_monthly_limit_reached");
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='seller'").get().coins, sellerBefore);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, receiverBefore);
  assert.equal(sqlite.prepare("SELECT exp_balance FROM user_vip WHERE user_id='receiver'").get().exp_balance, 20000);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM vip_seller_exp_grants WHERE user_id='receiver'").get().n, 2);
  sqlite.close();
});

test("VIP17 1.5x remains subject to the 10,000 EXP grant cap", async () => {
  const { sqlite, request } = await fixture();
  sqlite.prepare("UPDATE users SET vip_level=17 WHERE id='receiver'").run();
  await request("/api/vip/receiver", { userId: "receiver" });
  sqlite.prepare("UPDATE user_vip SET level=17,active_until=? WHERE user_id='receiver'").run(Date.now() + 86400000);

  const result = await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins: 10000 },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.vip_award.multiplier, 1.5);
  assert.equal(result.body.vip_award.awarded_exp, 10000);
  sqlite.close();
});
