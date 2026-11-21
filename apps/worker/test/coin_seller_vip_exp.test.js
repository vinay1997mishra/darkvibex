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

// Thresholds and upgrades are whole numbers in the 150 EXP per $1 scale,
// but awarded EXP can still be fractional for odd coin amounts (e.g.
// 1,000,000 coins = 18.75 EXP), so compare with a small epsilon instead
// of exact equality where floats are involved.
const approx = (actual, expected, message) => {
  assert.ok(Math.abs(actual - expected) < 1e-9, `${message ?? "EXP mismatch"}: got ${actual}, expected ${expected}`);
};

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
    // Guest login is deleted permanently (Vinay 2026-11-20): test users are
    // created directly in SQLite instead of through the removed endpoint.
    sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(id, name, Date.now(), Date.now());
  }
  sqlite.prepare("UPDATE users SET role='coin_seller',coins=1000000000 WHERE id='seller'").run();
  const credential = await request("/api/wallet/role-credential", {
    method: "POST",
    userId: "seller",
    body: {
      user_id: "seller",
      wallet_type: "coin_seller",
      credential: "1234",
    },
  });
  assert.equal(credential.status, 200);
  sqlite.prepare(
    "UPDATE role_wallets SET balance_coins=1000000000 WHERE user_id='seller' AND wallet_type='coin_seller'"
  ).run();
  return { sqlite, request };
}

test("Coin Seller purchases earn 150 VIP EXP per $1, with no cap", async () => {
  const { sqlite, request } = await fixture();
  const transfer = (coins) => request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins, pin: "1234" },
  });

  // $1 = 8,000,000 coins, so 8,000,000 coins = 150 EXP, 16,000,000 = 300
  // EXP and 80,000,000 ($10) = 1,500 base EXP. The third purchase
  // happens at VIP1, so the VIP1-4 EXP boost (1.1x, Vinay 2026-11-19)
  // applies: 1,500 * 1.1 = 1,650 EXP. Cumulative 2,100 EXP reaches
  // VIP2 (450 + 750 = 1,200) with 900 EXP left toward VIP3.
  const amounts = [8000000, 16000000, 80000000];
  const expectedAwarded = [150, 300, 1650];
  const receiverCoinsBefore = sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins;
  for (let i = 0; i < amounts.length; i++) {
    const result = await transfer(amounts[i]);
    assert.equal(result.status, 200);
    approx(result.body.vip_award.awarded_exp, expectedAwarded[i], "awarded EXP");
    assert.equal(result.body.vip_award.multiplier, 3 / 160000);
    assert.equal("monthly_grants_remaining" in result.body.vip_award, false);
  }

  assert.equal(
    sqlite.prepare(
      "SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='coin_seller'"
    ).get().balance_coins,
    1000000000 - amounts.reduce((sum, n) => sum + n, 0),
  );
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, receiverCoinsBefore + amounts.reduce((sum, n) => sum + n, 0));
  assert.equal(sqlite.prepare("SELECT total_received_coins FROM user_vip WHERE user_id='receiver'").get().total_received_coins, amounts.reduce((sum, n) => sum + n, 0));
  approx(sqlite.prepare("SELECT SUM(exp_delta) AS total FROM vip_events WHERE user_id='receiver' AND kind='coin_seller_received'").get().total, 2100, "total awarded EXP");
  const vip = sqlite.prepare("SELECT level, exp_balance FROM user_vip WHERE user_id='receiver'").get();
  assert.equal(vip.level, 2);
  approx(vip.exp_balance, 900, "EXP balance after VIP2");
  sqlite.close();
});

test("VIP EXP carries fractional amounts across purchases", async () => {
  const { sqlite, request } = await fixture();
  const transfer = (coins) => request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins, pin: "1234" },
  });

  // 1,000,000 coins ($0.125) = 18.75 EXP — fractions accumulate in the
  // balance instead of being floored away.
  const first = await transfer(1000000);
  assert.equal(first.status, 200);
  approx(first.body.vip_award.awarded_exp, 18.75, "first purchase EXP");
  approx(first.body.vip_award.vip.exp_balance, 18.75, "balance after first purchase");
  const second = await transfer(1000000);
  approx(second.body.vip_award.awarded_exp, 18.75, "second purchase EXP");
  approx(second.body.vip_award.vip.exp_balance, 37.5, "balance after second purchase");
  sqlite.close();
});

test("one large Coin Seller purchase can level up more than once", async () => {
  const { sqlite, request } = await fixture();
  sqlite.prepare("UPDATE users SET coins=100000000000 WHERE id='seller'").run();
  sqlite.prepare(
    "UPDATE role_wallets SET balance_coins=100000000000 WHERE user_id='seller' AND wallet_type='coin_seller'"
  ).run();
  const transfer = (coins) => request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins, pin: "1234" },
  });

  // 80,000,000,000 coins = $10,000 = 1,500,000 EXP = exactly VIP18's
  // cumulative threshold, so one purchase reaches VIP18 with a zero
  // balance and excess EXP carries through every level on the way.
  const result = await transfer(80000000000);
  assert.equal(result.status, 200);
  assert.equal(result.body.vip_award.awarded_exp, 1500000);
  assert.equal(result.body.vip_award.vip.level, 18);
  assert.equal(result.body.vip_award.vip.exp_balance, 0);
  assert.equal(result.body.vip_award.level_up, true);
  assert.equal(result.body.vip_award.new_level, 18);
  assert.equal(result.body.vip_award.previous_level, 0);
  sqlite.close();
});

test("spending coins on a gift earns no VIP EXP", async () => {
  const { sqlite, request } = await fixture();
  const transfer = await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins: 8000000, pin: "1234" },
  });
  assert.equal(transfer.status, 200);
  approx(transfer.body.vip_award.vip.exp_balance, 150, "EXP after purchase");

  // The receiver spends 100 coins on a Rose gift for the seller. The
  // gift commits (coins debited, diamonds credited) but EXP does not move.
  // DM gifts need mutual follow (Vinay, 2026-11-21), so the receiver and
  // seller follow each other first.
  const now = Date.now();
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("receiver", "seller", now);
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("seller", "receiver", now);
  const gift = await request("/api/gifts/send", {
    method: "POST", userId: "receiver",
    body: { sender_user_id: "receiver", receiver_user_id: "seller", gift_id: "rose" },
  });
  assert.equal(gift.status, 200);
  const vip = sqlite.prepare("SELECT exp_balance FROM user_vip WHERE user_id='receiver'").get();
  approx(vip.exp_balance, 150, "EXP after gift spend");
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM vip_events WHERE user_id='receiver'").get().n,
    1,
  );
  sqlite.close();
});

test("existing VIP balances migrate to the purchase-EXP scale", async () => {
  const { sqlite, request } = await fixture();
  await request("/api/vip/receiver", { userId: "receiver" });

  // Old rate version 0 (1 EXP per coin): 80,000 EXP = 80,000 coins
  // received = 80,000 / 400 = 200 v1 EXP = 200 x 3 / 400 = 1.5 EXP in
  // the v3 scale (80,000 coins = $0.01, and $0.01 x 150 = 1.5 EXP).
  sqlite.prepare("UPDATE user_vip SET exp_balance=80000,exp_rate_version=0 WHERE user_id='receiver'").run();
  const migrated0 = await request("/api/vip/receiver", { userId: "receiver" });
  assert.equal(migrated0.status, 200);
  approx(migrated0.body.vip.exp_balance, 1.5, "migrated v0 balance");
  assert.equal(sqlite.prepare("SELECT exp_rate_version FROM user_vip WHERE user_id='receiver'").get().exp_rate_version, 3);

  // Old rate version 1 (1 EXP per 400 coins): 60,000 EXP was exactly
  // VIP1's upgrade; in the v3 scale that is 60,000 x 3 / 400 = 450.
  sqlite.prepare("UPDATE user_vip SET exp_balance=60000,exp_rate_version=1,level=0,active_until=NULL WHERE user_id='receiver'").run();
  const migrated1 = await request("/api/vip/receiver", { userId: "receiver" });
  assert.equal(migrated1.status, 200);
  approx(migrated1.body.vip.exp_balance, 450, "migrated v1 balance");
  assert.equal(sqlite.prepare("SELECT exp_rate_version FROM user_vip WHERE user_id='receiver'").get().exp_rate_version, 3);

  // Rate version 2 (PR #128, 1.5 EXP per $1): 4.5 EXP was exactly VIP1's
  // total; in the v3 scale that is 4.5 x 100 = 450.
  sqlite.prepare("UPDATE user_vip SET exp_balance=4.5,exp_rate_version=2,level=0,active_until=NULL WHERE user_id='receiver'").run();
  const migrated2 = await request("/api/vip/receiver", { userId: "receiver" });
  assert.equal(migrated2.status, 200);
  approx(migrated2.body.vip.exp_balance, 450, "migrated v2 balance");
  assert.equal(sqlite.prepare("SELECT exp_rate_version FROM user_vip WHERE user_id='receiver'").get().exp_rate_version, 3);
  sqlite.close();
});
