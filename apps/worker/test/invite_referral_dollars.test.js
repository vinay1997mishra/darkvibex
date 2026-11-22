// Invite / referral rewards (Vinay, 2026-11-23): 800,000 coins per
// completed invite, 5% of every invitee recharge in dollars for 3
// months from the bind, Share-page dollars, $3 withdrawal to a coin
// seller / merchant who then gets 11,000,000 coins per $1 into their
// SELLER wallet (never the normal wallet). End-to-end through the real
// worker fetch, like dm_gift.test.js; the commission functions are also
// exercised directly for the window and dedupe cases.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import {
  recordRechargeInviteCommission,
  reverseRechargeInviteCommission,
} from "../src/invite_rewards.js";
import { ensurePlayBillingSchema } from "../src/play_billing.js";

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
  const secret = "invite-referral-test-secret";
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
  const rawRequest = async (path, { method = "GET", userId } = {}) => {
    const headers = new Headers();
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    return worker.fetch(new Request(`https://test.invalid${path}`, { method, headers }), env);
  };
  return { sqlite, DB, env, request, rawRequest };
}

let publicIdCounter = 7680000;
function makeUser(fx, userId, { coins = 0, role = "user" } = {}) {
  const { sqlite } = fx;
  publicIdCounter += 1;
  const publicId = String(publicIdCounter);
  sqlite.prepare(
    "INSERT INTO users(id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).run(userId, publicId, `User ${userId}`, role, coins, 0, 0, Date.now(), Date.now());
  return { userId, publicId };
}

function userCoins(fx, userId) {
  return fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get(userId).coins;
}

function dollarBalance(fx, userId) {
  const row = fx.sqlite.prepare(
    "SELECT balance_usd_cents FROM invite_dollar_balances WHERE user_id=?"
  ).get(userId);
  return Number(row?.balance_usd_cents ?? 0);
}

function sellerBalance(fx, userId, walletType) {
  // The role_wallets table is created lazily by ensureRoleWallet, so a
  // rejected withdrawal leaves no table at all — that is also a 0.
  const exists = fx.sqlite.prepare(
    "SELECT 1 AS yes FROM sqlite_master WHERE type='table' AND name='role_wallets'"
  ).get();
  if (!exists) return 0;
  const row = fx.sqlite.prepare(
    "SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).get(userId, walletType);
  return Number(row?.balance_coins ?? 0);
}

async function bind(fx, inviteeId, code, deviceKey) {
  const body = { user_id: inviteeId, invitation_code: code };
  if (deviceKey) body.device_key = deviceKey;
  return fx.request("/api/invite/bind", {
    method: "POST",
    userId: inviteeId,
    body,
  });
}

async function summary(fx, userId) {
  return fx.request(`/api/invite/summary?user_id=${userId}`, { userId });
}

async function withdraw(fx, userId, providerUserId, amountUsdCents, key) {
  return fx.request("/api/invite/withdraw", {
    method: "POST",
    userId,
    body: {
      user_id: userId,
      provider_user_id: providerUserId,
      amount_usd_cents: amountUsdCents,
      idempotency_key: key,
    },
  });
}

// ---- Invite reward: 800,000 coins on bind ----

test("bind pays the inviter 800,000 coins once, with a ledger row", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");

  const result = await bind(fx, "invitee-1", inviter.publicId);
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(result.body.binding.already_bound, false);
  assert.equal(result.body.binding.fixed_reward_coins, 800000);
  assert.equal(userCoins(fx, "inviter-1"), 800000);

  const ledger = fx.sqlite.prepare(
    "SELECT * FROM wallet_ledger WHERE user_id=? AND kind='invite_success_reward'"
  ).all("inviter-1");
  assert.equal(ledger.length, 1);
  assert.equal(ledger[0].amount, 800000);
  const rewards = fx.sqlite.prepare(
    "SELECT * FROM invite_success_rewards WHERE inviter_user_id=?"
  ).all("inviter-1");
  assert.equal(rewards.length, 1);
  assert.equal(rewards[0].reward_coins, 800000);
});

test("nobody can use their own invite code, on any phone", async () => {
  const fx = await fixture();
  const user = makeUser(fx, "self-user");

  // The user's own public ID is their own invitation code: entering it
  // must fail (Vinay, 2026-11-23) — no binding, no reward, for any user.
  const result = await bind(fx, "self-user", user.publicId);
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.ok, false);
  assert.equal(result.body.error, "cannot_invite_self");
  assert.equal(
    fx.sqlite.prepare("SELECT COUNT(*) AS n FROM invite_bindings").get().n,
    0,
  );
  assert.equal(
    fx.sqlite.prepare("SELECT COUNT(*) AS n FROM invite_success_rewards").get().n,
    0,
  );
  assert.equal(userCoins(fx, "self-user"), 0);
});

test("binding twice pays only once (already_bound, no second reward)", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");

  const first = await bind(fx, "invitee-1", inviter.publicId);
  assert.equal(first.status, 200);
  const second = await bind(fx, "invitee-1", inviter.publicId);
  assert.equal(second.status, 200, JSON.stringify(second.body));
  assert.equal(second.body.binding.already_bound, true);
  assert.equal(userCoins(fx, "inviter-1"), 800000);
  const ledger = fx.sqlite.prepare(
    "SELECT * FROM wallet_ledger WHERE user_id=? AND kind='invite_success_reward'"
  ).all("inviter-1");
  assert.equal(ledger.length, 1);
});

test("summary backfills an old unrewarded bind at 800,000, never twice", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  // A binding from before the reward existed: no success-reward row.
  fx.sqlite.prepare(
    "INSERT INTO invite_bindings(invitee_user_id,inviter_user_id,invitation_code,bound_at) VALUES(?,?,?,?)"
  ).run("invitee-1", "inviter-1", inviter.publicId, Date.now() - 1000);

  const first = await summary(fx, "inviter-1");
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(first.body.successful_invite_reward_coins, 800000);
  assert.equal(userCoins(fx, "inviter-1"), 800000);

  const second = await summary(fx, "inviter-1");
  assert.equal(second.body.successful_invite_reward_coins, 800000);
  assert.equal(userCoins(fx, "inviter-1"), 800000);
});

// ---- Invite landing page ----

test("GET /invite/<code> serves the landing page with both app links", async () => {
  const fx = await fixture();
  const response = await fx.rawRequest("/invite/7680001");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /text\/html/);
  const html = await response.text();
  assert.ok(html.includes("7680001"), "code is shown");
  assert.ok(
    html.includes("intent://invite/7680001#Intent;scheme=darkvibex"),
    "intent:// link opens the app",
  );
  assert.ok(
    html.includes("darkvibex://invite/7680001"),
    "direct custom-scheme link is offered for in-app browsers",
  );
  assert.ok(html.includes("play.google.com"), "Play Store fallback is linked");
});

test("GET /invite/<bad code> is not a landing page", async () => {
  const fx = await fixture();
  const response = await fx.rawRequest("/invite/not-a-code");
  assert.equal(response.status, 404);
});

// ---- Recharge commission: 5% in dollars, 3-month window ----

test("each recharge inside 3 months pays 5% in dollars; same token never pays twice", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  await bind(fx, "invitee-1", inviter.publicId);

  const first = await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-1",
    usdCents: 100,
  });
  assert.equal(first.applied, true);
  assert.equal(first.commission_usd_cents, 5);
  assert.equal(first.rate_percent, 5);
  assert.equal(dollarBalance(fx, "inviter-1"), 5);

  const second = await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-2",
    usdCents: 1000,
  });
  assert.equal(second.applied, true);
  assert.equal(second.commission_usd_cents, 50);
  assert.equal(dollarBalance(fx, "inviter-1"), 55);

  const duplicate = await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-1",
    usdCents: 100,
  });
  assert.equal(duplicate.applied, false);
  assert.equal(duplicate.duplicate, true);
  assert.equal(dollarBalance(fx, "inviter-1"), 55);
  const rows = fx.sqlite.prepare(
    "SELECT * FROM invite_dollar_commissions WHERE inviter_user_id=?"
  ).all("inviter-1");
  assert.equal(rows.length, 2);
});

test("recharge after the 3-month window pays no commission", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  await bind(fx, "invitee-1", inviter.publicId);
  // Move the bind 91 days back.
  fx.sqlite.prepare(
    "UPDATE invite_bindings SET bound_at=? WHERE invitee_user_id=?"
  ).run(Date.now() - 91 * 24 * 60 * 60 * 1000, "invitee-1");

  const result = await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-late",
    usdCents: 1000,
  });
  assert.equal(result.applied, false);
  assert.equal(result.reason, "window_expired");
  assert.equal(dollarBalance(fx, "inviter-1"), 0);
});

test("recharge with no inviter pays no commission", async () => {
  const fx = await fixture();
  makeUser(fx, "invitee-1");
  const result = await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-nobody",
    usdCents: 1000,
  });
  assert.equal(result.applied, false);
  assert.equal(result.reason, "no_inviter");
});

// ---- Summary dollars ----

test("summary shows the dollar balance, rate, window, commissions and withdrawals", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  const invitee = makeUser(fx, "invitee-1");
  await bind(fx, "invitee-1", inviter.publicId);
  await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-1",
    usdCents: 1000,
  });

  const res = await summary(fx, "inviter-1");
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal(res.body.referral_dollar_balance_usd_cents, 50);
  assert.equal(res.body.referral_dollar_commission_usd_cents, 50);
  assert.equal(res.body.referral_commission_rate_percent, 5);
  assert.equal(res.body.referral_commission_window_days, 90);
  assert.equal(res.body.referral_withdrawal_min_usd_cents, 300);
  assert.equal(res.body.referral_withdrawal_coins_per_usd, 11000000);
  assert.equal(res.body.referral_dollar_commissions.length, 1);
  assert.equal(res.body.referral_dollar_commissions[0].commission_usd_cents, 50);
  assert.equal(res.body.referral_dollar_commissions[0].recharge_usd_cents, 1000);
  assert.deepEqual(res.body.referral_dollar_withdrawals, []);
  const invitedRow = res.body.invited_users.find(
    (row) => row.user_id === "invitee-1",
  );
  assert.equal(invitedRow.referral_commission_usd_cents, 50);
  assert.equal(invitedRow.public_id, invitee.publicId);
});

// ---- Withdrawal: $3 minimum, seller wallet credit ----

async function seedBalance(fx, inviterId, inviteeId, cents) {
  // cents must be a multiple of 5 (5% of a whole-cent recharge).
  const rechargeCents = cents * 20;
  const result = await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: inviteeId,
    purchaseToken: `tok-seed-${cents}-${Date.now()}`,
    usdCents: rechargeCents,
  });
  assert.equal(result.applied, true, JSON.stringify(result));
}

test("withdrawal sends dollars to the seller and 11M coins per $1 to their seller wallet", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  const seller = makeUser(fx, "seller-1", { role: "coin_seller" });
  await bind(fx, "invitee-1", inviter.publicId);
  await seedBalance(fx, "inviter-1", "invitee-1", 350);

  const result = await withdraw(fx, "inviter-1", "seller-1", 300, "wd-key-1");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(result.body.withdrawal.amount_usd_cents, 300);
  assert.equal(result.body.withdrawal.coins_credited, 33000000);
  assert.equal(result.body.withdrawal.provider_role, "coin_seller");
  // Inviter keeps the remaining $0.50; the sender gets nothing extra.
  assert.equal(dollarBalance(fx, "inviter-1"), 50);
  assert.equal(userCoins(fx, "inviter-1"), 800000);
  // Seller wallet (role wallet) credited, NOT the normal user wallet.
  assert.equal(sellerBalance(fx, "seller-1", "coin_seller"), 33000000);
  assert.equal(userCoins(fx, "seller-1"), 0);
  const ledger = fx.sqlite.prepare(
    "SELECT * FROM role_wallet_ledger WHERE user_id=? AND kind='invite_dollar_withdrawal'"
  ).all("seller-1");
  assert.equal(ledger.length, 1);
  assert.equal(ledger[0].coin_amount, 33000000);
  assert.equal(ledger[0].coin_balance_after, 33000000);
  assert.equal(ledger[0].counterparty_user_id, "inviter-1");
  const withdrawals = fx.sqlite.prepare(
    "SELECT * FROM invite_dollar_withdrawals WHERE user_id=?"
  ).all("inviter-1");
  assert.equal(withdrawals.length, 1);
  assert.equal(withdrawals[0].provider_user_id, "seller-1");
  assert.equal(withdrawals[0].idempotency_key, "wd-key-1");

  // The withdrawal shows on the summary.
  const res = await summary(fx, "inviter-1");
  assert.equal(res.body.referral_dollar_balance_usd_cents, 50);
  assert.equal(res.body.referral_dollar_withdrawals.length, 1);
  assert.equal(res.body.referral_dollar_withdrawals[0].amount_usd_cents, 300);
  assert.equal(res.body.referral_dollar_withdrawals[0].coins_credited, 33000000);
  assert.equal(res.body.referral_dollar_withdrawals[0].provider_public_id, seller.publicId);
});

test("withdrawal to a merchant credits the merchant seller wallet", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "merchant-1", { role: "merchant" });
  await bind(fx, "invitee-1", inviter.publicId);
  await seedBalance(fx, "inviter-1", "invitee-1", 300);

  const result = await withdraw(fx, "inviter-1", "merchant-1", 300, "wd-key-m");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.withdrawal.provider_role, "merchant");
  assert.equal(sellerBalance(fx, "merchant-1", "merchant"), 33000000);
  assert.equal(userCoins(fx, "merchant-1"), 0);
  assert.equal(dollarBalance(fx, "inviter-1"), 0);
});

test("withdrawal below $3 is rejected and moves nothing", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "seller-1", { role: "coin_seller" });
  await bind(fx, "invitee-1", inviter.publicId);
  await seedBalance(fx, "inviter-1", "invitee-1", 350);

  const result = await withdraw(fx, "inviter-1", "seller-1", 299, "wd-key-low");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.error, "withdrawal_below_minimum");
  assert.equal(dollarBalance(fx, "inviter-1"), 350);
  assert.equal(sellerBalance(fx, "seller-1", "coin_seller"), 0);
});

test("withdrawal above the balance is rejected and moves nothing", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "seller-1", { role: "coin_seller" });
  await bind(fx, "invitee-1", inviter.publicId);
  await seedBalance(fx, "inviter-1", "invitee-1", 300);

  const result = await withdraw(fx, "inviter-1", "seller-1", 305, "wd-key-over");
  assert.equal(result.status, 409, JSON.stringify(result.body));
  assert.equal(result.body.error, "insufficient_referral_dollar_balance");
  assert.equal(dollarBalance(fx, "inviter-1"), 300);
  assert.equal(sellerBalance(fx, "seller-1", "coin_seller"), 0);
});

test("withdrawal to a normal user is rejected", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "plain-1", { role: "user" });
  await bind(fx, "invitee-1", inviter.publicId);
  await seedBalance(fx, "inviter-1", "invitee-1", 300);

  const result = await withdraw(fx, "inviter-1", "plain-1", 300, "wd-key-plain");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.error, "provider_not_seller_or_merchant");
  assert.equal(dollarBalance(fx, "inviter-1"), 300);
});

test("withdrawal to self is rejected", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  await bind(fx, "invitee-1", inviter.publicId);
  await seedBalance(fx, "inviter-1", "invitee-1", 300);

  const result = await withdraw(fx, "inviter-1", "inviter-1", 300, "wd-key-self");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.error, "cannot_withdraw_to_self");
});

test("retrying a withdrawal with the same key returns the original, no double credit", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "seller-1", { role: "coin_seller" });
  await bind(fx, "invitee-1", inviter.publicId);
  await seedBalance(fx, "inviter-1", "invitee-1", 300);

  const first = await withdraw(fx, "inviter-1", "seller-1", 300, "wd-key-dup");
  assert.equal(first.status, 200, JSON.stringify(first.body));
  const second = await withdraw(fx, "inviter-1", "seller-1", 300, "wd-key-dup");
  assert.equal(second.status, 200, JSON.stringify(second.body));
  assert.equal(second.body.withdrawal.duplicate, true);
  assert.equal(
    second.body.withdrawal.withdrawal_id,
    first.body.withdrawal.withdrawal_id,
  );
  assert.equal(dollarBalance(fx, "inviter-1"), 0);
  assert.equal(sellerBalance(fx, "seller-1", "coin_seller"), 33000000);
  const withdrawals = fx.sqlite.prepare(
    "SELECT * FROM invite_dollar_withdrawals WHERE user_id=?"
  ).all("inviter-1");
  assert.equal(withdrawals.length, 1);
});

// ---- Refund reversal ----

test("reversing a commission claws back only the balance still held", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "seller-1", { role: "coin_seller" });
  await bind(fx, "invitee-1", inviter.publicId);
  await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-rev",
    usdCents: 1000,
  });
  assert.equal(dollarBalance(fx, "inviter-1"), 50);

  const reversed = await reverseRechargeInviteCommission(fx.DB, {
    purchaseToken: "tok-rev",
  });
  assert.equal(reversed.applied, true);
  assert.equal(reversed.clawed_back_usd_cents, 50);
  assert.equal(dollarBalance(fx, "inviter-1"), 0);
  const row = fx.sqlite.prepare(
    "SELECT status FROM invite_dollar_commissions WHERE source_purchase_token=?"
  ).get("tok-rev");
  assert.equal(row.status, "reversed");

  const again = await reverseRechargeInviteCommission(fx.DB, {
    purchaseToken: "tok-rev",
  });
  assert.equal(again.applied, false);
  assert.equal(again.reason, "already_reversed");
});

test("reversal after a withdrawal takes only what is left, never below zero", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "seller-1", { role: "coin_seller" });
  await bind(fx, "invitee-1", inviter.publicId);
  await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-rev-2",
    usdCents: 1000,
  });
  await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-rev-3",
    usdCents: 1000,
  });
  await recordRechargeInviteCommission(fx.DB, {
    inviteeUserId: "invitee-1",
    purchaseToken: "tok-rev-4",
    usdCents: 10000,
  });
  assert.equal(dollarBalance(fx, "inviter-1"), 600);
  const ok = await withdraw(fx, "inviter-1", "seller-1", 300, "wd-key-rev-2");
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  assert.equal(dollarBalance(fx, "inviter-1"), 300);

  // One $0.50 commission is reversed after $3 already left: only the
  // $0.50 still held is clawed back, the withdrawn dollars stay gone.
  const reversed = await reverseRechargeInviteCommission(fx.DB, {
    purchaseToken: "tok-rev-2",
  });
  assert.equal(reversed.applied, true);
  assert.equal(reversed.clawed_back_usd_cents, 50);
  assert.equal(dollarBalance(fx, "inviter-1"), 250);
});

// ---- Invited-users table: total recharge per invitee (Vinay, 2026-11-23) ----

test("summary shows each invitee's total recharge in dollars; refunded and pending do not count", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "invitee-2");
  await bind(fx, "invitee-1", inviter.publicId);
  await bind(fx, "invitee-2", inviter.publicId);

  await ensurePlayBillingSchema(fx.DB);
  const now = Date.now();
  const insert = fx.sqlite.prepare(
    "INSERT INTO play_purchases (purchase_token, user_id, product_id, coins_credited, bonus_coins, exp_awarded, first_recharge, status, created_at) VALUES (?,?,?,?,0,0,0,?,?)"
  );
  insert.run("tok-1", "invitee-1", "coins_8000000", 8000000, "granted", now);
  insert.run("tok-2", "invitee-1", "coins_80000000", 80000000, "granted", now);
  insert.run("tok-3", "invitee-1", "coins_40000000", 40000000, "refunded", now);
  insert.run("tok-4", "invitee-1", "coins_16000000", 16000000, "pending", now);
  insert.run("tok-5", "invitee-1", "coins_unknown", 0, "granted", now);

  // Seller-wallet transfers into the normal wallet also count as
  // recharge (Vinay, 2026-11-23), valued at $1 = 8,000,000 coins.
  // The VIP purchase bonus is free platform coins, not a recharge.
  const ledger = fx.sqlite.prepare(
    "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
  );
  ledger.run(crypto.randomUUID(), "invitee-1", "coin_seller_received", 8000000, 8000000, "ref-1", now);
  ledger.run(crypto.randomUUID(), "invitee-1", "merchant_received", 4000000, 12000000, "ref-2", now);
  ledger.run(crypto.randomUUID(), "invitee-1", "vip_coins_bonus", 400000, 12400000, "ref-1", now);

  const result = await summary(fx, "inviter-1");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  const users = result.body.invited_users;
  assert.equal(users.length, 2);
  const first = users.find((u) => u.user_id === "invitee-1");
  // $1 + $10 granted = 1100 cents; the refunded $5, pending $2 and the
  // unknown product count for nothing. Seller transfers add $1.00 +
  // $0.50 = 150 cents; the 400,000-coin VIP bonus is not a recharge.
  assert.equal(first.total_recharge_usd_cents, 1250);
  const second = users.find((u) => u.user_id === "invitee-2");
  assert.equal(second.total_recharge_usd_cents, 0);
});

// ---- Unlimited invites (Vinay, 2026-11-23): no cap on how many people ----
// ---- one user can invite; the Share-page table shows 5, rest scroll. ----

test("invites are unlimited: the summary lists every invitee, not just 100", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  const now = Date.now();
  for (let i = 0; i < 105; i++) {
    const inviteeId = `invitee-${i}`;
    makeUser(fx, inviteeId);
    fx.sqlite.prepare(
      "INSERT INTO invite_bindings(invitee_user_id,inviter_user_id,invitation_code,bound_at) VALUES(?,?,?,?)"
    ).run(inviteeId, "inviter-1", inviter.publicId, now - i * 1000);
  }

  const result = await summary(fx, "inviter-1");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.invite_count, 105);
  assert.equal(result.body.invited_users.length, 105);
  // The backfill pays the 800,000 reward for every one of them.
  assert.equal(result.body.successful_invite_reward_coins, 105 * 800000);
  assert.equal(userCoins(fx, "inviter-1"), 105 * 800000);
});

// ---- One device, one ID (Vinay, 2026-11-23) ----

test("one device can use an invite code for one ID only", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  makeUser(fx, "invitee-1");
  makeUser(fx, "invitee-2");
  makeUser(fx, "invitee-3");

  // The first account on the device binds fine.
  const first = await bind(fx, "invitee-1", inviter.publicId, "device-abc");
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(userCoins(fx, "inviter-1"), 800000);

  // A second account on the SAME device cannot use any invite code.
  const second = await bind(fx, "invitee-2", inviter.publicId, "device-abc");
  assert.equal(second.status, 400, JSON.stringify(second.body));
  assert.equal(second.body.error, "device_already_used_invite");
  assert.equal(userCoins(fx, "inviter-1"), 800000);

  // The same account re-binding is still already_bound, not a device error.
  const again = await bind(fx, "invitee-1", inviter.publicId, "device-abc");
  assert.equal(again.status, 200, JSON.stringify(again.body));
  assert.equal(again.body.binding.already_bound, true);

  // A different device binds fine; no device key at all also binds (old clients).
  const third = await bind(fx, "invitee-2", inviter.publicId, "device-xyz");
  assert.equal(third.status, 200, JSON.stringify(third.body));
  const fourth = await bind(fx, "invitee-3", inviter.publicId);
  assert.equal(fourth.status, 200, JSON.stringify(fourth.body));
  assert.equal(userCoins(fx, "inviter-1"), 3 * 800000);
});

// ---- 48-hour invite window (Vinay, 2026-11-23) ----

test("invite code must be entered within 48 hours of the ID being created", async () => {
  const fx = await fixture();
  const inviter = makeUser(fx, "inviter-1");
  const now = Date.now();

  // A fresh account binds fine.
  makeUser(fx, "invitee-1");
  const ok = await bind(fx, "invitee-1", inviter.publicId);
  assert.equal(ok.status, 200, JSON.stringify(ok.body));

  // An account created 49 hours ago: the window has closed.
  makeUser(fx, "invitee-2");
  fx.sqlite.prepare("UPDATE users SET created_at=? WHERE id=?").run(
    now - 49 * 60 * 60 * 1000,
    "invitee-2",
  );
  const late = await bind(fx, "invitee-2", inviter.publicId);
  assert.equal(late.status, 400, JSON.stringify(late.body));
  assert.equal(late.body.error, "invite_window_expired");
  assert.equal(userCoins(fx, "inviter-1"), 800000);

  // The summary reports the window: open for the fresh account, closed
  // for the old one, with the 48-hour length.
  const fresh = await summary(fx, "invitee-1");
  assert.equal(fresh.body.invite_window_open, true);
  assert.equal(fresh.body.invite_window_hours, 48);
  const old = await summary(fx, "invitee-2");
  assert.equal(old.body.invite_window_open, false);
  assert.ok(old.body.invite_window_ends_at > 0);
});
