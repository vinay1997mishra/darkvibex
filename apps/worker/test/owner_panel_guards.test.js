// Owner Panel guards — audit fix 6 (2026-11-22), behavioural tests.
// F1: policies.save must never write/read/delete economy.* keys.
// F2: staff holding users.role.edit must not grant platform_owner.
// F4: a staffer may not edit/toggle/delete their own row or a row
//     holding a permission the staffer does not hold.
// These tests call the real handleOwnerApi with an in-memory D1 mock,
// authenticating as staff via owner_staff_sessions rows.
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
  // Fresh module instance per test: owner_api.js keeps a module-level
  // schemaReady flag, so a shared import would skip schema creation
  // on every test's fresh in-memory DB after the first test.
  const { handleOwnerApi } = await import(
    `../src/owner_api.js?fresh=${++moduleCounter}`
  );
  const db = new D1Mock(new DatabaseSync(":memory:"));
  const env = { DB: db, OWNER_ADMIN_TOKEN: OWNER_TOKEN };
  // One unauthenticated call first: handleOwnerApi creates the full
  // owner schema (users, owner_staff, sessions, settings, audit, …)
  // before any seeding happens.
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

async function makeUser(db, id) {
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO users(id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).bind(id, null, `User ${id}`, "user", 0, 0, 0, nowMs, nowMs).run();
}

async function userRole(db, id) {
  const row = await db.prepare("SELECT role FROM users WHERE id=?").bind(id).first();
  return row?.role;
}

async function coinRate(db) {
  const row = await db.prepare("SELECT value_json FROM owner_settings WHERE key='economy.coin_rate'").first();
  return JSON.parse(row?.value_json ?? "{}").coins_per_usd;
}

// ---- F1: policies.save bypasses economy.coin_rate.edit ----

test("F1: policies.save cannot write economy.coin_rate", async () => {
  const { db, env, call } = await setup();
  const staff = await makeStaff(db, "s1", ["policies.save", "policies.view", "policies.delete"]);
  // Seed the real rate through the owner-only economy endpoint.
  const seeded = await call("/api/owner/economy", { method: "POST", token: OWNER_TOKEN, body: { coins_per_usd: 8000000 } });
  assert.equal(seeded.status, 200);
  assert.equal(await coinRate(db), 8000000);

  const attempt = await call("/api/owner/policies", {
    method: "POST", token: staff, body: { key: "economy.coin_rate", value: { coins_per_usd: 1 } },
  });
  assert.equal(attempt.status, 400);
  assert.equal(await coinRate(db), 8000000);

  // The same key with the policy. prefix is also not a back door:
  // "economy.coin_rate" must never become a stored economy key.
  const attempt2 = await call("/api/owner/policies", {
    method: "POST", token: staff, body: { key: "economy", value: { coins_per_usd: 1 } },
  });
  assert.equal(attempt2.status, 200);
  assert.equal(await coinRate(db), 8000000);
});

test("F1: policies.save still writes real policy keys, and policies.view hides economy keys", async () => {
  const { db, env, call } = await setup();
  const staff = await makeStaff(db, "s1", ["policies.save", "policies.view", "policies.delete"]);
  await call("/api/owner/economy", { method: "POST", token: OWNER_TOKEN, body: { coins_per_usd: 8000000 } });

  const saved = await call("/api/owner/policies", {
    method: "POST", token: staff, body: { key: "welcome_text", value: { text: "hi" } },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.key, "policy.welcome_text");

  const listed = await call("/api/owner/policies", { token: staff });
  assert.equal(listed.status, 200);
  const keys = (listed.body.policies ?? []).map((p) => p.key);
  assert.ok(keys.includes("policy.welcome_text"));
  assert.ok(!keys.some((k) => k.startsWith("economy.")));
});

test("F1: policies.delete cannot delete economy.coin_rate", async () => {
  const { db, env, call } = await setup();
  const staff = await makeStaff(db, "s1", ["policies.save", "policies.view", "policies.delete"]);
  await call("/api/owner/economy", { method: "POST", token: OWNER_TOKEN, body: { coins_per_usd: 8000000 } });

  const attempt = await call("/api/owner/policies/economy.coin_rate", { method: "DELETE", token: staff });
  assert.equal(attempt.status, 400);
  assert.equal(await coinRate(db), 8000000);
});

// ---- F2: users.role.edit can grant platform_owner ----

test("F2: staff cannot grant platform_owner, but can grant moderator", async () => {
  const { db, env, call } = await setup();
  const staff = await makeStaff(db, "s1", ["users.role.edit"]);
  await makeUser(db, "u1");

  const blocked = await call("/api/owner/users/u1/profile", {
    method: "POST", token: staff, body: { role: "platform_owner" },
  });
  assert.equal(blocked.status, 403);
  assert.equal(await userRole(db, "u1"), "user");

  const allowed = await call("/api/owner/users/u1/profile", {
    method: "POST", token: staff, body: { role: "moderator" },
  });
  assert.equal(allowed.status, 200);
  assert.equal(await userRole(db, "u1"), "moderator");
});

test("F2: the platform owner can still grant platform_owner", async () => {
  const { db, env, call } = await setup();
  await makeUser(db, "u1");
  const granted = await call("/api/owner/users/u1/profile", {
    method: "POST", token: OWNER_TOKEN, body: { role: "platform_owner" },
  });
  assert.equal(granted.status, 200);
  assert.equal(await userRole(db, "u1"), "platform_owner");
});

// ---- F4: no staff hierarchy guard ----

test("F4: a staffer cannot edit a more-privileged staff row, but can edit a peer", async () => {
  const { db, env, call } = await setup();
  const junior = await makeStaff(db, "junior", ["staff.permissions.edit", "staff.toggle", "staff.delete"]);
  await makeStaff(db, "senior", ["staff.permissions.edit", "economy.coin_rate.edit"]);
  await makeStaff(db, "peer", ["staff.permissions.edit"]);

  const blocked = await call("/api/owner/staff/senior", {
    method: "POST", token: junior, body: { display_name: "Hacked" },
  });
  assert.equal(blocked.status, 403);

  const allowed = await call("/api/owner/staff/peer", {
    method: "POST", token: junior, body: { display_name: "Renamed Peer" },
  });
  assert.equal(allowed.status, 200);
  const peer = await db.prepare("SELECT display_name FROM owner_staff WHERE id='peer'").first();
  assert.equal(peer.display_name, "Renamed Peer");
});

test("F4: a staffer cannot edit their own row", async () => {
  const { db, env, call } = await setup();
  const junior = await makeStaff(db, "junior", ["staff.permissions.edit", "staff.toggle", "staff.delete"]);

  const blocked = await call("/api/owner/staff/junior", {
    method: "POST", token: junior, body: { display_name: "Self Rename" },
  });
  assert.equal(blocked.status, 403);
  const row = await db.prepare("SELECT display_name FROM owner_staff WHERE id='junior'").first();
  assert.equal(row.display_name, "Staff junior");
});

test("F4: a staffer cannot delete or disable a more-privileged staff row", async () => {
  const { db, env, call } = await setup();
  const junior = await makeStaff(db, "junior", ["staff.permissions.edit", "staff.toggle", "staff.delete"]);
  await makeStaff(db, "senior", ["staff.permissions.edit", "economy.coin_rate.edit"]);
  await makeStaff(db, "peer", ["staff.permissions.edit"]);

  const deleteBlocked = await call("/api/owner/staff/senior", { method: "DELETE", token: junior });
  assert.equal(deleteBlocked.status, 403);
  const senior = await db.prepare("SELECT id FROM owner_staff WHERE id='senior'").first();
  assert.ok(senior);

  const toggleBlocked = await call("/api/owner/staff/senior", {
    method: "POST", token: junior, body: { enabled: false },
  });
  assert.equal(toggleBlocked.status, 403);

  const deleteAllowed = await call("/api/owner/staff/peer", { method: "DELETE", token: junior });
  assert.equal(deleteAllowed.status, 200);
  const peer = await db.prepare("SELECT id FROM owner_staff WHERE id='peer'").first();
  assert.equal(peer, null);
});

// ---- Rule A (Vinay, 2026-11-22): staff never send coins ----

test("Rule A: the owner cannot grant coin-sending permissions to staff", async () => {
  const { call } = await setup();
  for (const permission of ["users.wallet.adjust", "users.role_wallet.adjust", "treasury.send"]) {
    const created = await call("/api/owner/staff", {
      method: "POST", token: OWNER_TOKEN,
      body: { display_name: "Coin Staff", role: "manager", email: "coinstaff@gmail.com", password: "Password123", permissions: [permission] },
    });
    assert.equal(created.status, 400);
    assert.equal(created.body.error, "invalid_staff_permission");
  }
  // A normal permission still grants fine.
  const ok = await call("/api/owner/staff", {
    method: "POST", token: OWNER_TOKEN,
    body: { display_name: "View Staff", role: "manager", email: "viewstaff@gmail.com", password: "Password123", permissions: ["users.search"] },
  });
  assert.equal(ok.status, 200);
});

test("Rule A: a legacy coin-sending grant is filtered from the session and all three send paths refuse", async () => {
  const { db, call } = await setup();
  const staff = await makeStaff(db, "legacy", ["users.wallet.adjust", "users.role_wallet.adjust", "treasury.send", "users.search"]);
  await makeUser(db, "u1");

  // The session is what the panel renders from: the coin permissions
  // are gone, so the wallet-adjust and treasury-send controls never
  // show in the staff panel (Rule B — only granted shows).
  const session = await call("/api/owner/session", { token: staff });
  assert.equal(session.status, 200);
  assert.deepEqual(session.body.actor.permissions, ["users.search"]);

  const wallet = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: staff, body: { coin_delta: 1000000 },
  });
  assert.equal(wallet.status, 403);

  const roleWallet = await call("/api/owner/users/u1/wallet", {
    method: "POST", token: staff, body: { role_wallet_type: "coin_seller", role_coin_delta: 1000000 },
  });
  assert.equal(roleWallet.status, 403);

  const treasury = await call("/api/owner/treasury", {
    method: "POST", token: staff, body: { action: "send", amount: 1000000, user_id: "u1" },
  });
  assert.equal(treasury.status, 403);

  const user = await db.prepare("SELECT coins FROM users WHERE id='u1'").first();
  assert.equal(user.coins, 0);
});
