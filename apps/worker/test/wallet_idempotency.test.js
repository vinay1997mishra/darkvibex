// Wallet audit fixes (2026-11-22, H1–H5 + M2/M3/M6): idempotency,
// atomic batches, relative guarded updates, ban check on the legacy
// route, PIN throttling. Sequential tests pin the behaviour; the
// genuinely concurrent races are pinned by the source assertions at
// the bottom, because the single-threaded mock cannot interleave two
// requests.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import { awardSellerVipExp } from "../src/vip_store.js";

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
  const secret = "wallet-idempotency-test-secret";
  const env = { DB, SESSION_SECRET: secret, OWNER_ADMIN_TOKEN: "owner-test-token" };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  const requestRaw = async (path, { method = "GET", body, token } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (token) headers.set("authorization", `Bearer ${token}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  for (const [id, name] of [["seller", "Seller"], ["receiver", "Receiver"]]) {
    sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(id, name, Date.now(), Date.now());
  }
  sqlite.prepare("UPDATE users SET role='coin_seller',coins=1000000000 WHERE id='seller'").run();
  const credential = await request("/api/wallet/role-credential", {
    method: "POST",
    userId: "seller",
    body: { user_id: "seller", wallet_type: "coin_seller", credential: "1234" },
  });
  assert.equal(credential.status, 200);
  sqlite.prepare(
    "UPDATE role_wallets SET balance_coins=1000000000 WHERE user_id='seller' AND wallet_type='coin_seller'"
  ).run();
  return { sqlite, DB, request, requestRaw };
}

const approx = (actual, expected, message) => {
  assert.ok(Math.abs(actual - expected) < 1e-9, `${message ?? "EXP mismatch"}: got ${actual}, expected ${expected}`);
};

test("H1: a retried Coin Seller transfer returns the original result and moves coins once", async () => {
  const { sqlite, request } = await fixture();
  const body = { seller_user_id: "seller", receiver_user_id: "receiver", coins: 8000000, pin: "1234", idempotency_key: "transfer-key-1" };
  const first = await request("/api/wallet/coin-seller-transfer", { method: "POST", userId: "seller", body });
  assert.equal(first.status, 200);
  assert.equal(first.body.ok, true);
  assert.equal(first.body.duplicate, undefined);
  const transferId = first.body.transfer_id;
  assert.ok(transferId);

  const second = await request("/api/wallet/coin-seller-transfer", { method: "POST", userId: "seller", body });
  assert.equal(second.status, 200);
  assert.equal(second.body.ok, true);
  assert.equal(second.body.duplicate, true);
  assert.equal(second.body.transfer_id, transferId);

  // Balances moved exactly once.
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='coin_seller'").get().balance_coins,
    1000000000 - 8000000,
  );
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, 8000000);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM role_wallet_ledger WHERE reference_id=?").get(transferId).n, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE reference_id=? AND kind='coin_seller_received'").get(transferId).n, 1);
  // EXP was awarded once, not twice (H2: the award is keyed to the
  // stable transfer_id).
  approx(sqlite.prepare("SELECT exp_balance FROM user_vip WHERE user_id='receiver'").get().exp_balance, 150, "EXP after one transfer");
  sqlite.close();
});

test("H1: the newer role-coins route is idempotent too", async () => {
  const { sqlite, request } = await fixture();
  const body = { user_id: "seller", receiver_user_id: "receiver", wallet_type: "coin_seller", coins: 8000000, credential: "1234", idempotency_key: "role-key-1" };
  const first = await request("/api/wallet/role-coins/transfer", { method: "POST", userId: "seller", body });
  assert.equal(first.status, 200);
  const second = await request("/api/wallet/role-coins/transfer", { method: "POST", userId: "seller", body });
  assert.equal(second.status, 200);
  assert.equal(second.body.duplicate, true);
  assert.equal(second.body.transfer_id, first.body.transfer_id);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, 8000000);
  sqlite.close();
});

test("H1: a retried gift send returns the original event and debits once", async () => {
  const { sqlite, request } = await fixture();
  const now = Date.now();
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("receiver", "seller", now);
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("seller", "receiver", now);
  // The receiver needs coins to send a gift: fund them via a transfer.
  await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins: 8000000, pin: "1234", idempotency_key: "fund-key" },
  });
  const body = { sender_user_id: "receiver", receiver_user_id: "seller", gift_id: "rose", idempotency_key: "gift-key-1" };
  const first = await request("/api/gifts/send", { method: "POST", userId: "receiver", body });
  assert.equal(first.status, 200);
  assert.equal(first.body.ok, true);
  const eventId = first.body.event_id;
  assert.ok(eventId);
  const coinsAfterFirst = sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins;

  const second = await request("/api/gifts/send", { method: "POST", userId: "receiver", body });
  assert.equal(second.status, 200);
  assert.equal(second.body.ok, true);
  assert.equal(second.body.duplicate, true);
  assert.equal(second.body.event_id, eventId);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, coinsAfterFirst);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events WHERE idempotency_key='gift-key-1'").get().n, 1);
  sqlite.close();
});

test("H2/H3: the same EXP award reference returns the stored award; different references accumulate", async () => {
  const { sqlite, DB } = await fixture();
  const first = await awardSellerVipExp(DB, "receiver", 8000000, Date.now(), { referenceId: "exp-ref-1" });
  approx(first.awarded_exp, 150, "first award");
  assert.equal(first.duplicate, undefined);
  const second = await awardSellerVipExp(DB, "receiver", 8000000, Date.now(), { referenceId: "exp-ref-1" });
  assert.equal(second.duplicate, true);
  approx(second.awarded_exp, 150, "duplicate award returns the stored amount");
  approx(sqlite.prepare("SELECT exp_balance FROM user_vip WHERE user_id='receiver'").get().exp_balance, 150, "EXP after a duplicate award");

  const third = await awardSellerVipExp(DB, "receiver", 8000000, Date.now(), { referenceId: "exp-ref-2" });
  approx(third.awarded_exp, 150, "a different reference awards again");
  approx(sqlite.prepare("SELECT exp_balance FROM user_vip WHERE user_id='receiver'").get().exp_balance, 300, "EXP after two distinct awards");
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM vip_exp_awards").get().n, 2);
  sqlite.close();
});

test("H5: a banned seller cannot move coins through the legacy route", async () => {
  const { sqlite, request } = await fixture();
  sqlite.prepare(
    "INSERT INTO owner_user_controls(user_id,status,updated_at) VALUES(?,?,?)"
  ).run("seller", "banned", Date.now());
  const result = await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins: 8000000, pin: "1234" },
  });
  assert.equal(result.status, 403);
  assert.equal(result.body.error, "user_banned");
  // No coins moved.
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, 0);
  sqlite.close();
});

test("M6: five failed PIN attempts lock the PIN", async () => {
  const { sqlite, request } = await fixture();
  const body = { seller_user_id: "seller", receiver_user_id: "receiver", coins: 8000000, pin: "9999" };
  for (let i = 0; i < 4; i += 1) {
    const result = await request("/api/wallet/coin-seller-transfer", { method: "POST", userId: "seller", body });
    assert.equal(result.status, 403);
    assert.equal(result.body.error, "invalid_wallet_credential");
  }
  const fifth = await request("/api/wallet/coin-seller-transfer", { method: "POST", userId: "seller", body });
  assert.equal(fifth.status, 403);
  assert.equal(fifth.body.error, "wallet_credential_locked");
  // Even the right PIN is now locked out.
  const locked = await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { ...body, pin: "1234" },
  });
  assert.equal(locked.status, 403);
  assert.equal(locked.body.error, "pin_locked");
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, 0);
  sqlite.close();
});

test("H1: a retried treasury send pays the user once", async () => {
  const { sqlite, requestRaw } = await fixture();
  // Trigger the owner schema ensure (creates owner_treasury), then
  // fund it.
  await requestRaw("/api/owner/treasury", { token: "owner-test-token" });
  sqlite.prepare("UPDATE owner_treasury SET balance=100000000 WHERE id='main'").run();
  const body = { action: "send", amount: 5000000, user_id: "receiver", idempotency_key: "treasury-key-1" };
  const first = await requestRaw("/api/owner/treasury", { method: "POST", token: "owner-test-token", body });
  assert.equal(first.status, 200);
  assert.equal(first.body.ok, true);
  const second = await requestRaw("/api/owner/treasury", { method: "POST", token: "owner-test-token", body });
  assert.equal(second.status, 200);
  assert.equal(second.body.ok, true);
  assert.equal(second.body.duplicate, true);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, 5000000);
  assert.equal(sqlite.prepare("SELECT balance FROM owner_treasury WHERE id='main'").get().balance, 95000000);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM owner_treasury_ledger WHERE kind='send_to_user'").get().n, 1);
  sqlite.close();
});

test("H4: money moves ride a single db.batch (source assertions)", () => {
  const roleWallets = readFileSync(new URL("../src/role_wallets.js", import.meta.url), "utf8");
  const ownerApi = readFileSync(new URL("../src/owner_api.js", import.meta.url), "utf8");
  const playBilling = readFileSync(new URL("../src/play_billing.js", import.meta.url), "utf8");
  // transferRoleCoins: debit + credit + ledgers in one batch.
  assert.match(roleWallets, /const batchResults = await db\.batch\(\[/);
  assert.match(roleWallets, /UPDATE role_wallets SET balance_coins=balance_coins-\?,updated_at=\? WHERE user_id=\? AND wallet_type=\? AND balance_coins>=\?/);
  assert.match(roleWallets, /UPDATE users SET coins=coins\+\?,updated_at=\? WHERE id=\? AND changes\(\)=1/);
  // Treasury send: debit + credit + ledgers in one batch.
  assert.match(ownerApi, /const batchResults = await db\.batch\(\[/);
  assert.match(ownerApi, /UPDATE owner_treasury SET balance = balance - \?, updated_at = \? WHERE id = 'main' AND balance >= \?/);
  // Play credits: credit + ledger in one batch.
  assert.match(playBilling, /const batchResults = await db\.batch\(\[/);
  assert.match(playBilling, /UPDATE users SET coins = coins \+ \?, updated_at = \? WHERE id = \?/);
});

test("H3: no absolute-SET balance write remains in the fixed paths", () => {
  const vipStore = readFileSync(new URL("../src/vip_store.js", import.meta.url), "utf8");
  const inviteRewards = readFileSync(new URL("../src/invite_rewards.js", import.meta.url), "utf8");
  const aladdinLamp = readFileSync(new URL("../src/aladdin_lamp.js", import.meta.url), "utf8");
  const tinniSocial = readFileSync(new URL("../src/tinni_social.js", import.meta.url), "utf8");
  // The EXP award moves exp/total relatively and CAS-guards on the
  // pre-read (level, exp_balance).
  assert.match(vipStore, /exp_balance=exp_balance\+\?,total_received_coins=total_received_coins\+\?/);
  assert.match(vipStore, /WHERE user_id=\? AND level=\? AND exp_balance=\?/);
  assert.match(vipStore, /INSERT INTO vip_exp_awards\(reference_id/);
  // Invite commission: INSERT OR IGNORE + relative credit.
  assert.match(inviteRewards, /INSERT OR IGNORE INTO invite_commission_rewards/);
  assert.match(inviteRewards, /UPDATE users SET coins=coins\+\?,updated_at=\? WHERE id=\? AND changes\(\)=1/);
  // Aladdin lamp + task claim: relative credits.
  assert.match(aladdinLamp, /UPDATE users SET coins=coins\+\?,updated_at=\? WHERE id=\?/);
  assert.match(tinniSocial, /UPDATE users SET coins=coins\+\?,updated_at=\? WHERE id=\?/);
});
