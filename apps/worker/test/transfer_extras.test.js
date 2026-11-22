// Transfer extras (Vinay, 2026-11-23): a seller-wallet transfer counts
// as a recharge everywhere. Merchant transfers earn the same extras as
// Coin Seller transfers — VIP EXP for the receiver and the 5% referral
// dollars for the inviter. The inviter earns NO coins per recharge: coins
// come only once per invite (800,000 at bind); the old per-recharge coin
// commission was removed. End-to-end through the real worker fetch.
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
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: userId, exp: Math.floor(Date.now() / 1000) + 3600 })}`;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "transfer-extras-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  const now = Date.now();
  for (const [id, name] of [["inviter", "Inviter"], ["invitee", "Invitee"], ["seller", "Seller"]]) {
    sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(id, name, now, now);
  }
  sqlite.prepare(
    "INSERT INTO invite_bindings(invitee_user_id,inviter_user_id,invitation_code,bound_at) VALUES(?,?,?,?)"
  ).run("invitee", "inviter", "1234567", now);
  return { sqlite, DB, request };
}

async function setupWallet(sqlite, request, walletType) {
  // Coin Seller uses a 4-digit PIN; Merchant uses a 6-32 char
  // credential. The sender's users.role must match the wallet type.
  const credential = walletType === "coin_seller" ? "1234" : "merchant-pass";
  sqlite.prepare("UPDATE users SET role=? WHERE id='seller'").run(walletType);
  const credentialResult = await request("/api/wallet/role-credential", {
    method: "POST",
    body: { user_id: "seller", wallet_type: walletType, credential },
    userId: "seller",
  });
  assert.equal(credentialResult.status, 200, JSON.stringify(credentialResult.body));
  sqlite.prepare(
    "UPDATE role_wallets SET balance_coins=1000000000 WHERE user_id='seller' AND wallet_type=?"
  ).run(walletType);
  return credential;
}

function sendTransfer(request, walletType, credential, key, receiverUserId = "invitee") {
  return request("/api/wallet/role-coins/transfer", {
    method: "POST",
    body: {
      user_id: "seller",
      receiver_user_id: receiverUserId,
      wallet_type: walletType,
      coins: 8000000,
      credential,
      idempotency_key: key,
    },
    userId: "seller",
  });
}

test("coin seller transfer: VIP EXP + 5% dollars, no coins per recharge, no double-pay on retry", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "coin_seller");
  const result = await sendTransfer(request, "coin_seller", credential, "extras-key-1");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  // 8,000,000 coins = $1: 150 VIP EXP for the receiver.
  assert.equal(result.body.vip_award?.awarded_exp, 150);
  // No coins per recharge (Vinay, 2026-11-23): the old coin commission
  // is gone — the response carries no invite_commission at all.
  assert.equal(result.body.invite_commission, undefined);
  // 5% referral dollars: 5 cents on the $1 transfer.
  assert.equal(result.body.invite_dollar_commission?.applied, true);
  assert.equal(result.body.invite_dollar_commission?.recharge_usd_cents, 100);
  assert.equal(result.body.invite_dollar_commission?.commission_usd_cents, 5);
  assert.equal(
    sqlite.prepare("SELECT balance_usd_cents FROM invite_dollar_balances WHERE user_id='inviter'").get().balance_usd_cents,
    5,
  );

  const retry = await sendTransfer(request, "coin_seller", credential, "extras-key-1");
  assert.equal(retry.body.duplicate, true);
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM invite_dollar_commissions").get().n,
    1,
  );
});

test("merchant transfer: same extras as coin seller, no VIP bonus", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "merchant");
  const result = await sendTransfer(request, "merchant", credential, "extras-key-2");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(result.body.vip_award?.awarded_exp, 150);
  assert.equal(result.body.invite_commission, undefined);
  assert.equal(result.body.invite_dollar_commission?.applied, true);
  assert.equal(result.body.invite_dollar_commission?.commission_usd_cents, 5);
  // The receiver got exactly the transferred coins — the VIP purchase
  // bonus stays Coin Seller only.
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='invitee'").get().coins,
    8000000,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id='invitee' AND kind='vip_coins_bonus'").get().n,
    0,
  );
});

test("coin seller self-transfer: VIP EXP earned, no bonus, no dollars", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "coin_seller");
  const result = await sendTransfer(request, "coin_seller", credential, "extras-self-1", "seller");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  // VIP EXP is earned on self-transfer (Vinay, 2026-11-23): 150 EXP.
  assert.equal(result.body.vip_award?.awarded_exp, 150);
  // No VIP purchase bonus on self-transfer: the seller would otherwise
  // mint free platform coins out of their own balance.
  assert.equal(result.body.coins_bonus, 0);
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id='seller' AND kind='vip_coins_bonus'").get().n,
    0,
  );
  // The seller's own normal wallet got exactly the transferred coins,
  // and the seller wallet was debited exactly the same amount.
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='seller'").get().coins,
    8000000,
  );
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='coin_seller'").get().balance_coins,
    1000000000 - 8000000,
  );
  // No inviter can exist for a self-transfer (nobody can invite
  // themselves), so no referral dollars are recorded.
  assert.equal(result.body.invite_dollar_commission?.applied, false);
  assert.equal(result.body.invite_dollar_commission?.reason, "no_inviter");
});

test("merchant self-transfer: VIP EXP earned", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "merchant");
  const result = await sendTransfer(request, "merchant", credential, "extras-self-2", "seller");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(result.body.vip_award?.awarded_exp, 150);
  assert.equal(result.body.invite_dollar_commission?.applied, false);
  assert.equal(result.body.invite_dollar_commission?.reason, "no_inviter");
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='seller'").get().coins,
    8000000,
  );
});
