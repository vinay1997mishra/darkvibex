// Owner Panel wallet functions — end-to-end behavioural tests (Vinay,
// 2026-11-22: every wallet function and button must work 100%).
// Covers the whole wallet surface: treasury GET/add/deduct/send,
// treasury-funded wallet adjust, role wallets, owner overrides
// (wallet ban/freeze) and the coin rate. Calls the real handleOwnerApi
// with an in-memory D1 mock, like owner_panel_guards.test.js.
import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { DatabaseSync } from "node:sqlite";

let moduleCounter = 0;

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

const OWNER_TOKEN = "owner-secret-token";
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

async function setup() {
  const { handleOwnerApi } = await import(
    `../src/owner_api.js?fresh-wallet-${++moduleCounter}`
  );
  const db = new D1Mock(new DatabaseSync(":memory:"));
  const env = { DB: db, OWNER_ADMIN_TOKEN: OWNER_TOKEN };
  await handleOwnerApi(
    new Request("https://owner.test/api/owner/session"),
    env,
    new URL("https://owner.test/api/owner/session"),
  );

  async function call(path, { method = "GET", token = null, body = null } = {}) {
    const headers = {};
    if (token) headers.authorization = `Bearer ${token}`;
    const init = { method, headers };
    if (body != null) {
      headers["content-type"] = "application/json";
      init.body = JSON.stringify(body);
    }
    const response = await handleOwnerApi(
      new Request(`https://owner.test${path}`, init),
      env,
      new URL(`https://owner.test${path}`),
    );
    const text = await response.text();
    let parsed = null;
    try { parsed = JSON.parse(text); } catch (_) { /* non-JSON body */ }
    return { status: response.status, body: parsed, text };
  }

  return { db, env, call };
}

async function makeStaff(db, id, permissions) {
  const token = `staff-token-${id}`;
  const nowMs = Date.now();
  await db.prepare(
    `INSERT INTO owner_staff(id,display_name,role,token_hash,email,password_salt,password_hash,password_iterations,permissions_json,enabled,created_at,updated_at)
     VALUES(?,?,?,?,?,?,?,?,?,?,?,?)`
  ).bind(id, `Staff ${id}`, "admin", sha256(`legacy-${id}`), "", "", "", 120000, JSON.stringify(permissions), 1, nowMs, nowMs).run();
  await db.prepare(
    "INSERT INTO owner_staff_sessions(token_hash,staff_id,created_at,expires_at,last_used_at) VALUES(?,?,?,?,?)"
  ).bind(sha256(token), id, nowMs, nowMs + 7 * 24 * 60 * 60 * 1000, nowMs).run();
  return token;
}

async function makeUser(db, id, coins = 0, diamonds = 0, role = "user") {
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO users(id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).bind(id, null, `User ${id}`, role, coins, diamonds, 0, nowMs, nowMs).run();
}

async function treasuryBalance(db) {
  const row = await db.prepare("SELECT balance FROM owner_treasury WHERE id='main'").first();
  return Number(row?.balance ?? 0);
}

async function seedTreasury(db, amount) {
  await db.prepare("UPDATE owner_treasury SET balance=? WHERE id='main'").bind(amount).run();
}

async function userCoins(db, id) {
  const row = await db.prepare("SELECT coins, diamonds FROM users WHERE id=?").bind(id).first();
  return { coins: Number(row?.coins ?? 0), diamonds: Number(row?.diamonds ?? 0) };
}

// ---- Treasury: GET / add / deduct ----

test("Treasury GET returns the seeded balance and an empty ledger", async () => {
  const { call } = await setup();
  const res = await call("/api/owner/treasury", { token: OWNER_TOKEN });
  assert.equal(res.status, 200);
  assert.equal(res.body.treasury.balance, 0);
  assert.deepEqual(res.body.ledger, []);
});

test("Treasury add tops up and deduct takes back, never below zero", async () => {
  const { db, call } = await setup();
  const added = await call("/api/owner/treasury", {
    method: "POST", token: OWNER_TOKEN, body: { action: "add", amount: 5000000 },
  });
  assert.equal(added.status, 200);
  assert.equal(added.body.balance, 5000000);
  assert.equal(await treasuryBalance(db), 5000000);

  const deducted = await call("/api/owner/treasury", {
    method: "POST", token: OWNER_TOKEN, body: { action: "deduct", amount: 2000000 },
  });
  assert.equal(deducted.status, 200);
  assert.equal(deducted.body.balance, 3000000);

  const overdraw = await call("/api/owner/treasury", {
    method: "POST", token: OWNER_TOKEN, body: { action: "deduct", amount: 10000000 },
  });
  assert.equal(overdraw.status, 400);
  assert.equal(await treasuryBalance(db), 3000000);

  const ledger = await db.prepare(
    "SELECT kind, amount FROM owner_treasury_ledger ORDER BY rowid"
  ).all();
  assert.deepEqual(ledger.results.map((r) => [r.kind, r.amount]), [
    ["owner_topup", 5000000],
    ["owner_deduct", -2000000],
  ]);
});

test("Treasury add/deduct are owner-only", async () => {
  const { db, call } = await setup();
  const staff = await makeStaff(db, "s1", ["treasury.view"]);
  for (const action of ["add", "deduct"]) {
    const res = await call("/api/owner/treasury", {
      method: "POST", token: staff, body: { action, amount: 1000 },
    });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, "owner_only");
  }
  assert.equal(await treasuryBalance(db), 0);
});

// ---- Treasury: send ----

test("Treasury send debits the treasury and credits the user, with both ledger rows", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  await seedTreasury(db, 10000000);

  const sent = await call("/api/owner/treasury", {
    method: "POST", token: OWNER_TOKEN,
    body: { action: "send", amount: 3000000, user_id: "u1", idempotency_key: "send-1" },
  });
  assert.equal(sent.status, 200);
  assert.equal(sent.body.balance, 7000000);
  assert.equal(sent.body.user_balance, 3000000);
  assert.equal(await treasuryBalance(db), 7000000);
  assert.deepEqual(await userCoins(db, "u1"), { coins: 3000000, diamonds: 0 });

  const tLedger = await db.prepare(
    "SELECT kind, amount FROM owner_treasury_ledger WHERE kind='send_to_user'"
  ).first();
  assert.deepEqual([tLedger.kind, tLedger.amount], ["send_to_user", -3000000]);
  const wLedger = await db.prepare(
    "SELECT kind, amount FROM wallet_ledger WHERE user_id='u1' AND kind='owner_treasury'"
  ).first();
  assert.deepEqual([wLedger.kind, wLedger.amount], ["owner_treasury", 3000000]);

  // A short send is refused and moves nothing.
  const short = await call("/api/owner/treasury", {
    method: "POST", token: OWNER_TOKEN,
    body: { action: "send", amount: 20000000, user_id: "u1" },
  });
  assert.equal(short.status, 409);
  assert.equal(await treasuryBalance(db), 7000000);
  assert.deepEqual(await userCoins(db, "u1"), { coins: 3000000, diamonds: 0 });
});

// ---- Wallet adjust: funded by the treasury (Vinay, 2026-11-22) ----

test("Wallet adjust +coins is funded by the treasury", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  await seedTreasury(db, 5000000);

  const res = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN, body: { coin_delta: 1000000 },
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.coins, 1000000);
  assert.equal(res.body.treasury_balance, 4000000);
  assert.equal(await treasuryBalance(db), 4000000);
  assert.deepEqual(await userCoins(db, "u1"), { coins: 1000000, diamonds: 0 });

  const tLedger = await db.prepare(
    "SELECT kind, amount FROM owner_treasury_ledger WHERE kind='wallet_adjust'"
  ).first();
  assert.deepEqual([tLedger.kind, tLedger.amount], ["wallet_adjust", -1000000]);
  const wLedger = await db.prepare(
    "SELECT kind, amount FROM wallet_ledger WHERE user_id='u1' AND kind='owner_adjustment'"
  ).first();
  assert.deepEqual([wLedger.kind, wLedger.amount], ["owner_adjustment", 1000000]);
});

test("Wallet adjust +coins refuses when the treasury cannot cover it", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  await seedTreasury(db, 500000);

  const res = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN, body: { coin_delta: 1000000 },
  });
  assert.equal(res.status, 409);
  assert.equal(res.body.error, "insufficient_treasury_balance");
  assert.equal(await treasuryBalance(db), 500000);
  assert.deepEqual(await userCoins(db, "u1"), { coins: 0, diamonds: 0 });
  const tLedger = await db.prepare(
    "SELECT id FROM owner_treasury_ledger WHERE kind='wallet_adjust'"
  ).first();
  assert.equal(tLedger, null);
});

test("Wallet adjust -coins and diamonds-only do not touch the treasury", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1", 2000000, 0);
  await seedTreasury(db, 5000000);

  const taken = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN, body: { coin_delta: -500000 },
  });
  assert.equal(taken.status, 200);
  assert.equal(taken.body.coins, 1500000);
  assert.equal(taken.body.treasury_balance, undefined);
  assert.equal(await treasuryBalance(db), 5000000);

  const diamonds = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN, body: { diamond_delta: 100 },
  });
  assert.equal(diamonds.status, 200);
  assert.equal(diamonds.body.diamonds, 100);
  assert.equal(await treasuryBalance(db), 5000000);

  const empty = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN, body: {},
  });
  assert.equal(empty.status, 400);
});

// ---- Role wallets ----

test("Role wallet adjust and ban work", async () => {
  const { db, call } = await setup();
  // A role wallet only exists for a user whose role IS that wallet's
  // role (coin_seller / merchant) — a plain user gets 400.
  await makeUser(db, "u1", 0, 0, "coin_seller");

  const adjusted = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN,
    body: { role_wallet_type: "coin_seller", role_coin_delta: 500000 },
  });
  assert.equal(adjusted.status, 200);
  assert.equal(adjusted.body.role_wallet.balance_coins, 500000);

  const overdraw = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN,
    body: { role_wallet_type: "coin_seller", role_coin_delta: -600000 },
  });
  assert.equal(overdraw.status, 400);

  const banned = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: OWNER_TOKEN,
    body: { role_wallet_type: "coin_seller", role_wallet_banned: true },
  });
  assert.equal(banned.status, 200);
  const row = await db.prepare(
    "SELECT status FROM role_wallets WHERE user_id='u1' AND wallet_type='coin_seller'"
  ).first();
  assert.equal(row.status, "banned");
});

// ---- Owner overrides: wallet ban / freeze ----

test("Owner overrides set wallet ban and freeze", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");

  const res = await call("/api/owner/users/u1/owner-overrides", {
    method: "POST", token: OWNER_TOKEN,
    body: { wallet_banned: true, wallet_frozen: true },
  });
  assert.equal(res.status, 200);
  const row = await db.prepare(
    "SELECT wallet_banned, wallet_frozen FROM owner_user_overrides WHERE user_id='u1'"
  ).first();
  assert.deepEqual([row.wallet_banned, row.wallet_frozen], [1, 1]);

  const cleared = await call("/api/owner/users/u1/owner-overrides", {
    method: "POST", token: OWNER_TOKEN,
    body: { wallet_banned: false },
  });
  assert.equal(cleared.status, 200);
  const row2 = await db.prepare(
    "SELECT wallet_banned, wallet_frozen FROM owner_user_overrides WHERE user_id='u1'"
  ).first();
  assert.deepEqual([row2.wallet_banned, row2.wallet_frozen], [0, 1]);
});

// ---- Coin rate ----

test("Coin rate save and read work, staff without the edit permission cannot save", async () => {
  const { db, call } = await setup();
  const staff = await makeStaff(db, "s1", ["economy.view"]);

  const saved = await call("/api/owner/economy", {
    method: "POST", token: OWNER_TOKEN, body: { coins_per_usd: 9000000 },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.coins_per_usd, 9000000);

  const read = await call("/api/owner/economy", { token: OWNER_TOKEN });
  assert.equal(read.body.coins_per_usd, 9000000);

  const denied = await call("/api/owner/economy", {
    method: "POST", token: staff, body: { coins_per_usd: 1 },
  });
  assert.equal(denied.status, 403);
});
