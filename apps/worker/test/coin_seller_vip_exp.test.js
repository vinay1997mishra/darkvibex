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
  sqlite.prepare("UPDATE users SET role='coin_seller',coins=1000000000 WHERE id='seller'").run();
  return { sqlite, request };
}

test("Coin Seller transfers have no monthly or per-transfer VIP EXP cap", async () => {
  const { sqlite, request } = await fixture();
  const transfer = (coins) => request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins },
  });

  const amounts = [10000, 20000, 30000, 100000000];
  const receiverCoinsBefore = sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins;
  for (const coins of amounts) {
    const result = await transfer(coins);
    assert.equal(result.status, 200);
    assert.equal(result.body.vip_award.awarded_exp, coins);
    assert.equal(result.body.vip_award.multiplier, 1);
    assert.equal("monthly_grants_remaining" in result.body.vip_award, false);
  }

  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='seller'").get().coins, 1000000000 - amounts.reduce((sum, n) => sum + n, 0));
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, receiverCoinsBefore + amounts.reduce((sum, n) => sum + n, 0));
  assert.equal(sqlite.prepare("SELECT total_received_coins FROM user_vip WHERE user_id='receiver'").get().total_received_coins, amounts.reduce((sum, n) => sum + n, 0));
  assert.equal(sqlite.prepare("SELECT SUM(exp_delta) AS total FROM vip_events WHERE user_id='receiver' AND kind='coin_seller_received'").get().total, amounts.reduce((sum, n) => sum + n, 0));
  sqlite.close();
});

test("VIP17 Coin Seller receipts still earn exactly one VIP EXP per coin", async () => {
  const { sqlite, request } = await fixture();
  sqlite.prepare("UPDATE users SET vip_level=17 WHERE id='receiver'").run();
  await request("/api/vip/receiver", { userId: "receiver" });
  sqlite.prepare("UPDATE user_vip SET level=17,active_until=? WHERE user_id='receiver'").run(Date.now() + 86400000);

  const coins = 40000;
  const result = await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.vip_award.multiplier, 1);
  assert.equal(result.body.vip_award.awarded_exp, coins);
  assert.equal(result.body.vip_award.vip.exp_multiplier, 1);
  sqlite.close();
});
