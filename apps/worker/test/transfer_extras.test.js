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
  for (const [id, name] of [["inviter", "Inviter"], ["invitee", "Invitee"], ["seller", "Seller"], ["seller2", "Seller 2"], ["merchant2", "Merchant 2"]]) {
    sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(id, name, now, now);
  }
  // seller2 is a Coin Seller (a merchant can send into their seller
  // wallet); merchant2 is a Merchant (nobody can send into a merchant
  // wallet).
  sqlite.prepare("UPDATE users SET role='coin_seller' WHERE id='seller2'").run();
  sqlite.prepare("UPDATE users SET role='merchant' WHERE id='merchant2'").run();
  sqlite.prepare(
    "INSERT INTO invite_bindings(invitee_user_id,inviter_user_id,invitation_code,bound_at) VALUES(?,?,?,?)"
  ).run("invitee", "inviter", "1234567", now);
  const setVipLevel = async (userId, level) => {
    // The first read creates the user_vip schema/row; only then can the
    // level be set and settled (same pattern as vip_boosts.test.js).
    await request(`/api/vip/${userId}`, { userId });
    sqlite.prepare("DELETE FROM user_vip WHERE user_id=?").run(userId);
    sqlite.prepare("UPDATE users SET vip_level=? WHERE id=?").run(level, userId);
    const response = await request(`/api/vip/${userId}`, { userId });
    assert.equal(response.status, 200, JSON.stringify(response.body));
    assert.equal(response.body.vip.level, level);
  };
  return { sqlite, DB, request, setVipLevel };
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

function sendTransfer(request, walletType, credential, key, receiverUserId = "invitee", receiverWalletType = "normal") {
  return request("/api/wallet/role-coins/transfer", {
    method: "POST",
    body: {
      user_id: "seller",
      receiver_user_id: receiverUserId,
      wallet_type: walletType,
      receiver_wallet_type: receiverWalletType,
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

test("coin seller self-transfer: VIP EXP + VIP bonus earned, no dollars", async () => {
  const { sqlite, request, setVipLevel } = await fixture();
  const credential = await setupWallet(sqlite, request, "coin_seller");
  // VIP5: 1.2x EXP boost and a 5% purchase bonus on Coin Seller buys.
  await setVipLevel("seller", 5);
  const result = await sendTransfer(request, "coin_seller", credential, "extras-self-1", "seller");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  // VIP EXP is earned on self-transfer (Vinay, 2026-11-23): 150 EXP at
  // the 1.2x VIP5 boost = 180 EXP.
  assert.equal(result.body.vip_award?.awarded_exp, 180);
  assert.equal(result.body.vip_award?.exp_boost, 1.2);
  // VIP bonus is earned on self-transfer too (Vinay, 2026-11-23): 5%
  // of 8,000,000 = 400,000 free platform coins on top.
  assert.equal(result.body.coins_bonus, 400000);
  assert.equal(
    sqlite.prepare("SELECT amount FROM wallet_ledger WHERE user_id='seller' AND kind='vip_coins_bonus'").get().amount,
    400000,
  );
  // The seller's own normal wallet got the transferred coins + bonus,
  // and the seller wallet was debited exactly the purchased amount.
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='seller'").get().coins,
    8400000,
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

test("merchant can send into a coin seller's seller wallet (inventory, no extras)", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "merchant");
  const result = await sendTransfer(request, "merchant", credential, "extras-m2s-1", "seller2", "coin_seller");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(result.body.receiver_wallet_type, "coin_seller");
  assert.equal(result.body.receiver_role_coin_balance, 8000000);
  // The merchant wallet was debited exactly 8,000,000 and the coin
  // seller's seller wallet was credited exactly 8,000,000.
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='merchant'").get().balance_coins,
    1000000000 - 8000000,
  );
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller2' AND wallet_type='coin_seller'").get().balance_coins,
    8000000,
  );
  // The coin seller's NORMAL wallet is untouched.
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='seller2'").get().coins, 0);
  // Inventory, not a recharge: no VIP EXP, no referral dollars, no
  // bonus — those attach when the coins later reach a normal wallet,
  // never twice for the same coins.
  assert.equal(result.body.vip_award, null);
  assert.equal(result.body.invite_dollar_commission, null);
  assert.equal(result.body.coins_bonus, 0);
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM role_wallet_ledger WHERE user_id='seller2' AND wallet_type='coin_seller' AND kind='merchant_transfer_received' AND coin_amount=8000000").get().n,
    1,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM role_wallet_ledger WHERE user_id='seller' AND wallet_type='merchant' AND kind='coin_send' AND coin_amount=-8000000").get().n,
    1,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id='seller2'").get().n,
    0,
  );
});

test("merchant cannot send into a merchant wallet", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "merchant");
  const result = await sendTransfer(request, "merchant", credential, "extras-m2m-1", "merchant2", "merchant");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.ok, false);
  assert.equal(result.body.error, "invalid_receiver_wallet");
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='merchant'").get().balance_coins,
    1000000000,
  );
});

test("coin seller cannot send into a seller wallet", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "coin_seller");
  const result = await sendTransfer(request, "coin_seller", credential, "extras-s2s-1", "seller2", "coin_seller");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.ok, false);
  assert.equal(result.body.error, "invalid_receiver_wallet");
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='coin_seller'").get().balance_coins,
    1000000000,
  );
});

test("coin seller cannot send into a merchant wallet", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "coin_seller");
  const result = await sendTransfer(request, "coin_seller", credential, "extras-s2m-1", "merchant2", "merchant");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.ok, false);
  assert.equal(result.body.error, "invalid_receiver_wallet");
});

test("merchant cannot send into the seller wallet of a non-seller", async () => {
  const { sqlite, request } = await fixture();
  const credential = await setupWallet(sqlite, request, "merchant");
  // invitee is a plain user, not a Coin Seller.
  const result = await sendTransfer(request, "merchant", credential, "extras-m2s-2", "invitee", "coin_seller");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.ok, false);
  assert.equal(result.body.error, "receiver_not_coin_seller");
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='merchant'").get().balance_coins,
    1000000000,
  );
});
