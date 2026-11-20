// Google Play Billing coin purchases (Vinay, 2026-11-20): pack catalog,
// server-side purchase verification, first-recharge double + VIP1 grant,
// and the RTDN refund webhook (revoke coins + permanent ID ban).
// The Google APIs are stubbed through globalThis.fetch; the service
// account key is a throwaway RSA key generated in this file only.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { generateKeyPairSync } from "node:crypto";
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

// Throwaway RSA key for the fake Play service account (never leaves the test).
const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const fakeServiceAccountJson = JSON.stringify({
  type: "service_account",
  project_id: "play-test-project",
  client_email: "play-verifier@play-test-project.iam.gserviceaccount.com",
  private_key: privateKey.export({ type: "pkcs8", format: "pem" }),
});

// Google API behaviour, reset per fixture.
const google = {
  purchaseState: 0,
  consumptionState: 0,
  getStatus: 200,
  consumeStatus: 204,
  getCalls: [],
  consumeCalls: [],
  oidcValid: true,
};

const realFetch = globalThis.fetch;
function installFetchStub() {
  google.purchaseState = 0;
  google.consumptionState = 0;
  google.getStatus = 200;
  google.consumeStatus = 204;
  google.getCalls = [];
  google.consumeCalls = [];
  google.oidcValid = true;
  globalThis.fetch = async (url, options = {}) => {
    const href = String(url);
    // NOTE: tokeninfo must be checked before the token endpoint — its
    // path starts with the same "token" prefix.
    if (href.startsWith("https://oauth2.googleapis.com/tokeninfo")) {
      if (!google.oidcValid) {
        return new Response(JSON.stringify({ error: "invalid_token" }), {
          status: 400, headers: { "content-type": "application/json" },
        });
      }
      return new Response(JSON.stringify({
        iss: "https://accounts.google.com",
        aud: "https://darkvibex-api.mishrajii7991.workers.dev/api/webhooks/google-play",
        exp: Math.floor(Date.now() / 1000) + 3600,
        email: "play-verifier@play-test-project.iam.gserviceaccount.com",
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
    if (href.startsWith("https://oauth2.googleapis.com/token")) {
      return new Response(JSON.stringify({ access_token: "play-access-token", expires_in: 3600, token_type: "Bearer" }), {
        status: 200, headers: { "content-type": "application/json" },
      });
    }
    if (href.includes("/purchases/products/")) {
      if (href.endsWith(":consume")) {
        google.consumeCalls.push(href);
        return new Response(null, { status: google.consumeStatus });
      }
      google.getCalls.push(href);
      if (google.getStatus !== 200) {
        return new Response(JSON.stringify({ error: { code: google.getStatus, status: "NOT_FOUND" } }), {
          status: google.getStatus, headers: { "content-type": "application/json" },
        });
      }
      const productId = href.match(/\/purchases\/products\/([^/]+)\/tokens\//)?.[1] ?? "coins_8000000";
      return new Response(JSON.stringify({
        kind: "androidpublisher#productPurchase",
        purchaseTimeMillis: String(Date.now()),
        purchaseState: google.purchaseState,
        consumptionState: google.consumptionState,
        orderId: "GPA.test-order",
        productId: decodeURIComponent(productId),
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
    throw new Error(`unexpected fetch in play_billing test: ${href}`);
  };
}

async function fixture() {
  installFetchStub();
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "play-billing-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, FILES: files, PLAY_SERVICE_ACCOUNT_JSON: fakeServiceAccountJson };
  const call = async (path, { method = "GET", body, userId, headers = {} } = {}) => {
    const requestHeaders = new Headers(headers);
    if (body != null) requestHeaders.set("content-type", "application/json");
    if (userId) requestHeaders.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers: requestHeaders, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, env, call };
}

let publicIdCounter = 7660000;
function makeUser(fx, userId, { coins = 0 } = {}) {
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET coins=?, public_id=? WHERE id=?").run(coins, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

function coins(fx, userId) {
  return fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get(userId).coins;
}

function ledgerKinds(fx, userId) {
  return fx.sqlite.prepare("SELECT kind, amount FROM wallet_ledger WHERE user_id=? ORDER BY rowid").all(userId)
    .map((row) => `${row.kind}:${row.amount}`);
}

function rtdnBody(notification) {
  return { message: { data: Buffer.from(JSON.stringify(notification)).toString("base64"), messageId: "msg-1", publishTime: new Date().toISOString() } };
}

const OIDC_BEARER = "Bearer oidc-test-token";
const WEBHOOK_PATH = "/api/webhooks/google-play";

test("packs list the 5 Play products and first-recharge availability", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const packs = await fx.call("/api/play/packs", { userId: "buyer-1" });
  assert.equal(packs.status, 200, JSON.stringify(packs.body));
  assert.equal(packs.body.ok, true);
  assert.deepEqual(packs.body.packs, [
    { product_id: "coins_8000000", coins: 8000000, usd_value: 1 },
    { product_id: "coins_16000000", coins: 16000000, usd_value: 2 },
    { product_id: "coins_40000000", coins: 40000000, usd_value: 5 },
    { product_id: "coins_80000000", coins: 80000000, usd_value: 10 },
    { product_id: "coins_400000000", coins: 400000000, usd_value: 50 },
  ]);
  assert.equal(packs.body.first_recharge_available, true);
  const unauthenticated = await fx.call("/api/play/packs");
  assert.equal(unauthenticated.status, 401);
});

test("first verify doubles coins, grants VIP1 for 10 days, EXP on the total", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const result = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-first" },
  });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(result.body.first_recharge, true);
  assert.equal(result.body.coins_credited, 8000000);
  assert.equal(result.body.bonus_coins, 8000000);
  // EXP on ALL 16,000,000 credited coins: 16,000,000 * 3 / 160,000 = 300
  // (VIP0 boost 1.0x). Below the VIP1 threshold of 450, so the VIP1
  // level here comes from the first-recharge grant, not EXP.
  assert.equal(result.body.exp_awarded, 300);
  assert.equal(result.body.vip_level, 1);
  assert.equal(coins(fx, "buyer-1"), 16000000);
  assert.deepEqual(ledgerKinds(fx, "buyer-1"), ["play_purchase:8000000", "play_purchase_bonus:8000000"]);
  const purchase = fx.sqlite.prepare("SELECT * FROM play_purchases WHERE purchase_token=?").get("tok-first");
  assert.equal(purchase.status, "granted");
  assert.equal(purchase.coins_credited, 8000000);
  assert.equal(purchase.bonus_coins, 8000000);
  assert.equal(purchase.exp_awarded, 300);
  assert.equal(purchase.first_recharge, 1);
  const grant = fx.sqlite.prepare("SELECT * FROM vip_grants WHERE user_id=?").get("buyer-1");
  assert.equal(grant.level, 1);
  assert.equal(grant.source, "play_first_recharge");
  assert.equal(grant.reference_id, "tok-first");
  assert.ok(grant.expires_at - grant.granted_at === 10 * 86400000, `grant lasts 10 days, got ${grant.expires_at - grant.granted_at}ms`);
  assert.equal(fx.sqlite.prepare("SELECT vip_level FROM users WHERE id=?").get("buyer-1").vip_level, 1);
  // The purchase was consumed on Google after granting.
  assert.equal(google.consumeCalls.length, 1);
  assert.ok(google.consumeCalls[0].includes("coins_8000000"));
  assert.ok(google.consumeCalls[0].includes("tok-first"));
  // First-recharge offer is spent now.
  const packs = await fx.call("/api/play/packs", { userId: "buyer-1" });
  assert.equal(packs.body.first_recharge_available, false);
});

test("duplicate verify returns the stored result without crediting again", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const first = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-dup" },
  });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(coins(fx, "buyer-1"), 16000000);
  const again = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-dup" },
  });
  assert.equal(again.status, 200, JSON.stringify(again.body));
  assert.equal(again.body.ok, true);
  assert.equal(again.body.duplicate, true);
  assert.equal(again.body.coins_credited, 8000000);
  assert.equal(again.body.bonus_coins, 8000000);
  assert.equal(again.body.exp_awarded, 300);
  assert.equal(again.body.first_recharge, true);
  assert.equal(coins(fx, "buyer-1"), 16000000);
  assert.deepEqual(ledgerKinds(fx, "buyer-1"), ["play_purchase:8000000", "play_purchase_bonus:8000000"]);
  // A token granted to one user cannot be replayed by another.
  makeUser(fx, "buyer-2");
  const replay = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-2",
    body: { productId: "coins_8000000", purchaseToken: "tok-dup" },
  });
  assert.equal(replay.status, 409);
  assert.equal(replay.body.error, "purchase_token_owner_mismatch");
  assert.equal(coins(fx, "buyer-2"), 0);
});

test("second purchase is not doubled and EXP keeps accumulating", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const first = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-one" },
  });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  const second = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_16000000", purchaseToken: "tok-two" },
  });
  assert.equal(second.status, 200, JSON.stringify(second.body));
  assert.equal(second.body.first_recharge, false);
  assert.equal(second.body.coins_credited, 16000000);
  assert.equal(second.body.bonus_coins, 0);
  assert.equal(second.body.exp_awarded, 300);
  assert.equal(coins(fx, "buyer-1"), 32000000);
  // EXP total is now 600: past the VIP1 threshold of 450, so the EXP
  // level itself is 1 (150 EXP banked toward VIP2).
  const vip = fx.sqlite.prepare("SELECT * FROM user_vip WHERE user_id=?").get("buyer-1");
  assert.equal(vip.level, 1);
  assert.equal(vip.exp_balance, 150);
  assert.equal(second.body.vip_level, 1);
  // Still exactly one first-recharge grant.
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM vip_grants WHERE user_id=?").get("buyer-1").n, 1);
});

test("VIP1 grant expires after 10 days and the mirror drops back", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const first = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-grant" },
  });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(first.body.vip_level, 1);
  // Fast-forward past the grant: the EXP level is still 0 (300 < 450).
  fx.sqlite.prepare("UPDATE vip_grants SET expires_at=? WHERE user_id=?").run(Date.now() - 1000, "buyer-1");
  const profile = await fx.call("/api/users/buyer-1", { userId: "buyer-1" });
  assert.equal(profile.status, 200, JSON.stringify(profile.body));
  // active_vip_level is computed by getVipStatus after the grant expired.
  assert.equal(profile.body.user.active_vip_level, 0);
  // The users.vip_level mirror is synced back down in the DB (the
  // profile response's vip_level field is read before that sync, so the
  // mirror is asserted from the row, not the response).
  assert.equal(fx.sqlite.prepare("SELECT vip_level FROM users WHERE id=?").get("buyer-1").vip_level, 0);
});

test("verify rejects bad products, bad tokens and non-purchased states", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const badProduct = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_999", purchaseToken: "tok-x" },
  });
  assert.equal(badProduct.status, 400);
  assert.equal(badProduct.body.error, "invalid_product");
  assert.equal(coins(fx, "buyer-1"), 0);

  google.getStatus = 404;
  const badToken = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-missing" },
  });
  assert.equal(badToken.status, 400);
  assert.equal(badToken.body.error, "purchase_verification_failed");
  assert.equal(coins(fx, "buyer-1"), 0);
  google.getStatus = 200;

  google.purchaseState = 1;
  const canceled = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-canceled" },
  });
  assert.equal(canceled.status, 400);
  assert.equal(canceled.body.error, "purchase_canceled");
  assert.equal(coins(fx, "buyer-1"), 0);

  google.purchaseState = 2;
  const pending = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-pending" },
  });
  assert.equal(pending.status, 400);
  assert.equal(pending.body.error, "purchase_not_completed");
  assert.equal(coins(fx, "buyer-1"), 0);
  google.purchaseState = 0;
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM play_purchases").get().n, 0);
});

test("verify without the Play service account returns 503", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  delete fx.env.PLAY_SERVICE_ACCOUNT_JSON;
  const result = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-nosecret" },
  });
  assert.equal(result.status, 503);
  assert.equal(result.body.error, "play_not_configured");
  assert.equal(coins(fx, "buyer-1"), 0);
});

test("refund webhook revokes coins, permanently bans, and is idempotent", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const verified = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-refund" },
  });
  assert.equal(verified.status, 200, JSON.stringify(verified.body));
  assert.equal(coins(fx, "buyer-1"), 16000000);
  // The user spends 6,000,000 coins before the refund lands: only the
  // 10,000,000 still in the wallet can be taken back (never below zero).
  fx.sqlite.prepare("UPDATE users SET coins=? WHERE id=?").run(10000000, "buyer-1");

  const cancelBody = rtdnBody({
    version: "1.0",
    packageName: "com.darkvibex.app",
    eventTimeMillis: String(Date.now()),
    oneTimeProductNotification: { version: "1.0", notificationType: 2, purchaseToken: "tok-refund", sku: "coins_8000000" },
  });
  const first = await fx.call(WEBHOOK_PATH, {
    method: "POST", body: cancelBody, headers: { authorization: OIDC_BEARER },
  });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(first.body.ok, true);
  assert.equal(first.body.revoked, true);
  assert.equal(first.body.coins_revoked, 10000000);
  assert.equal(coins(fx, "buyer-1"), 0);
  assert.deepEqual(
    ledgerKinds(fx, "buyer-1"),
    ["play_purchase:8000000", "play_purchase_bonus:8000000", "play_refund_revoke:-10000000"],
  );
  assert.equal(fx.sqlite.prepare("SELECT status FROM play_purchases WHERE purchase_token=?").get("tok-refund").status, "refunded");
  const control = fx.sqlite.prepare("SELECT * FROM owner_user_controls WHERE user_id=?").get("buyer-1");
  assert.equal(control.status, "banned");
  assert.equal(control.banned_until, null);
  // A banned user is 403 everywhere, including login-gated calls.
  const blocked = await fx.call("/api/play/packs", { userId: "buyer-1" });
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, "user_banned");

  // Duplicate RTDN delivery: nothing happens twice.
  const again = await fx.call(WEBHOOK_PATH, {
    method: "POST", body: cancelBody, headers: { authorization: OIDC_BEARER },
  });
  assert.equal(again.status, 200, JSON.stringify(again.body));
  assert.equal(again.body.revoked, false);
  assert.equal(again.body.reason, "already_refunded");
  assert.deepEqual(
    ledgerKinds(fx, "buyer-1"),
    ["play_purchase:8000000", "play_purchase_bonus:8000000", "play_refund_revoke:-10000000"],
  );
});

test("voided one-time purchase also revokes and bans", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const verified = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_16000000", purchaseToken: "tok-voided" },
  });
  assert.equal(verified.status, 200, JSON.stringify(verified.body));
  assert.equal(coins(fx, "buyer-1"), 32000000);
  const voidedBody = rtdnBody({
    version: "1.0",
    packageName: "com.darkvibex.app",
    eventTimeMillis: String(Date.now()),
    voidedPurchaseNotification: { purchaseToken: "tok-voided", orderId: "GPA.test-order", productType: 2, refundType: 1 },
  });
  const result = await fx.call(WEBHOOK_PATH, {
    method: "POST", body: voidedBody, headers: { authorization: OIDC_BEARER },
  });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.revoked, true);
  assert.equal(result.body.coins_revoked, 32000000);
  assert.equal(coins(fx, "buyer-1"), 0);
  assert.equal(fx.sqlite.prepare("SELECT status FROM owner_user_controls WHERE user_id=?").get("buyer-1").status, "banned");
});

test("webhook rejects a bad OIDC token and acks test notifications", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  google.oidcValid = false;
  const badAuth = await fx.call(WEBHOOK_PATH, {
    method: "POST", body: rtdnBody({ testNotification: { version: "1.0" } }), headers: { authorization: OIDC_BEARER },
  });
  assert.equal(badAuth.status, 401);
  assert.equal(badAuth.body.error, "webhook_unauthorized");
  google.oidcValid = true;

  const noAuth = await fx.call(WEBHOOK_PATH, {
    method: "POST", body: rtdnBody({ testNotification: { version: "1.0" } }),
  });
  assert.equal(noAuth.status, 401);

  const testNote = await fx.call(WEBHOOK_PATH, {
    method: "POST", body: rtdnBody({ version: "1.0", packageName: "com.darkvibex.app", testNotification: { version: "1.0" } }), headers: { authorization: OIDC_BEARER },
  });
  assert.equal(testNote.status, 200, JSON.stringify(testNote.body));
  assert.equal(testNote.body.ok, true);
  assert.equal(testNote.body.ignored, "test_notification");

  // A purchase RTDN is acknowledged only — granting stays with verify.
  const purchaseNote = await fx.call(WEBHOOK_PATH, {
    method: "POST",
    body: rtdnBody({
      version: "1.0",
      packageName: "com.darkvibex.app",
      oneTimeProductNotification: { version: "1.0", notificationType: 1, purchaseToken: "tok-app", sku: "coins_8000000" },
    }),
    headers: { authorization: OIDC_BEARER },
  });
  assert.equal(purchaseNote.status, 200, JSON.stringify(purchaseNote.body));
  assert.equal(purchaseNote.body.ignored, "purchase");
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM play_purchases").get().n, 0);
});

test("a pending claim returns 409 so the app retries", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  // Warm the Play schema first (a packs call creates the tables).
  await fx.call("/api/play/packs", { userId: "buyer-1" });
  // A verify that died mid-grant leaves a fresh pending row.
  fx.sqlite.prepare(
    "INSERT INTO play_purchases (purchase_token, user_id, product_id, coins_credited, bonus_coins, exp_awarded, first_recharge, status, created_at) VALUES (?, ?, ?, ?, 0, 0, 0, 'pending', ?)"
  ).run("tok-stuck", "buyer-1", "coins_8000000", 8000000, Date.now());
  const result = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-stuck" },
  });
  assert.equal(result.status, 409);
  assert.equal(result.body.error, "purchase_processing");
  assert.equal(coins(fx, "buyer-1"), 0);
});

test("stale pending claim resumes without double-crediting", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  // Warm the Play schema first (a packs call creates the tables).
  await fx.call("/api/play/packs", { userId: "buyer-1" });
  // A verify that died after the purchase credit but before marking the
  // row granted: the ledger already has the play_purchase row.
  fx.sqlite.prepare(
    "INSERT INTO play_purchases (purchase_token, user_id, product_id, coins_credited, bonus_coins, exp_awarded, first_recharge, status, created_at) VALUES (?, ?, ?, ?, 0, 0, 0, 'pending', ?)"
  ).run("tok-resume", "buyer-1", "coins_8000000", 8000000, Date.now() - 120000);
  fx.sqlite.prepare("UPDATE users SET coins=? WHERE id=?").run(8000000, "buyer-1");
  fx.sqlite.prepare(
    "INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
  ).run("ledger-1", "buyer-1", "play_purchase", 8000000, 8000000, "tok-resume", Date.now() - 120000);
  const result = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-resume" },
  });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.first_recharge, true);
  assert.equal(result.body.coins_credited, 8000000);
  assert.equal(result.body.bonus_coins, 8000000);
  assert.equal(result.body.exp_awarded, 300);
  // Only the missing bonus was credited on resume: 8M + 8M, not 8M twice.
  assert.equal(coins(fx, "buyer-1"), 16000000);
  assert.deepEqual(ledgerKinds(fx, "buyer-1"), ["play_purchase:8000000", "play_purchase_bonus:8000000"]);
  assert.equal(fx.sqlite.prepare("SELECT status FROM play_purchases WHERE purchase_token=?").get("tok-resume").status, "granted");
});

test("source assertions: Play Billing wiring", async () => {
  const workerSource = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  assert.match(workerSource, /\/api\/play\/packs/);
  assert.match(workerSource, /\/api\/play\/verify/);
  assert.match(workerSource, /\/api\/webhooks\/google-play/);
  const playSource = readFileSync(new URL("../src/play_billing.js", import.meta.url), "utf8");
  assert.match(playSource, /ONE_TIME_PRODUCT_CANCELED/);
  assert.match(playSource, /androidpublisher\.googleapis\.com\/androidpublisher\/v3/);
  assert.match(playSource, /play_purchase_bonus/);
  assert.match(playSource, /play_refund_revoke/);
  // The grant table + helpers live in vip_store.js (play_billing.js only
  // calls createVipGrant).
  const vipStoreSource = readFileSync(new URL("../src/vip_store.js", import.meta.url), "utf8");
  assert.match(vipStoreSource, /vip_grants/);
  assert.match(vipStoreSource, /activeVipGrant/);
  assert.match(vipStoreSource, /createVipGrant/);
  assert.doesNotMatch(playSource, /PLAY_SERVICE_ACCOUNT_JSON.*=.*\{/);
});

test("seller-transfer bonus still earns no EXP (Play rule only)", async () => {
  // The Play Billing change must not leak into the peer Coin Seller path:
  // vip_policy.js and role_wallets.js keep "bonus earns NO EXP".
  const policySource = readFileSync(new URL("../src/vip_policy.js", import.meta.url), "utf8");
  assert.match(policySource, /not itself eligible for[\s\S]{0,10}EXP/);
  const walletsSource = readFileSync(new URL("../src/role_wallets.js", import.meta.url), "utf8");
  assert.match(walletsSource, /bonus is NOT counted in[\s\S]{0,30}total_received_coins and earns NO EXP/);
});

test("refund revoke of a fully-spent wallet bans without going negative", async () => {
  const fx = await fixture();
  makeUser(fx, "buyer-1");
  const verified = await fx.call("/api/play/verify", {
    method: "POST", userId: "buyer-1",
    body: { productId: "coins_8000000", purchaseToken: "tok-spent" },
  });
  assert.equal(verified.status, 200, JSON.stringify(verified.body));
  // Every granted coin already spent: revoke deducts 0, balance stays 0.
  fx.sqlite.prepare("UPDATE users SET coins=0 WHERE id=?").run("buyer-1");
  const result = await fx.call(WEBHOOK_PATH, {
    method: "POST",
    body: rtdnBody({
      version: "1.0",
      packageName: "com.darkvibex.app",
      oneTimeProductNotification: { version: "1.0", notificationType: 2, purchaseToken: "tok-spent", sku: "coins_8000000" },
    }),
    headers: { authorization: OIDC_BEARER },
  });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.revoked, true);
  assert.equal(result.body.coins_revoked, 0);
  assert.equal(coins(fx, "buyer-1"), 0);
  assert.equal(fx.sqlite.prepare("SELECT status FROM owner_user_controls WHERE user_id=?").get("buyer-1").status, "banned");
  assert.deepEqual(
    ledgerKinds(fx, "buyer-1"),
    ["play_purchase:8000000", "play_purchase_bonus:8000000"],
  );
});
