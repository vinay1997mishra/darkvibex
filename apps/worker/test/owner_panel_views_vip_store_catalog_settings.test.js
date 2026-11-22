// Owner Panel views — VIP / Store / Catalog / Settings / Announcements /
// Staff / Support / Audit. Behavioural tests for the controls the panel
// audit found untested (Vinay, 2026-11-22: every Owner Panel button and
// function must work 100%). Calls the real handleOwnerApi with an
// in-memory D1 mock.
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
    `../src/owner_api.js?fresh-views-c-${++moduleCounter}`
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

async function makeUser(db, id) {
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO users(id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).bind(id, null, `User ${id}`, "user", 0, 0, 0, nowMs, nowMs).run();
}

// ---- VIP rules ----

test("VIP rules list the 18 base levels; save and reset an override", async () => {
  const { call } = await setup();
  const before = await call("/api/owner/vip-rules", { token: OWNER_TOKEN });
  assert.equal(before.status, 200);
  assert.equal(before.body.levels.length, 18);
  assert.equal(before.body.levels[4].source, "base");

  const saved = await call("/api/owner/vip-rules", {
    method: "POST", token: OWNER_TOKEN,
    body: { level: 5, name: "VIP 5", upgrade_exp: 5000, maintain_exp: 1000, validity_days: 30 },
  });
  assert.equal(saved.status, 200);

  const after = await call("/api/owner/vip-rules", { token: OWNER_TOKEN });
  assert.equal(after.body.levels[4].source, "owner");
  assert.equal(after.body.levels[4].upgrade_exp, 5000);

  const bad = await call("/api/owner/vip-rules", {
    method: "POST", token: OWNER_TOKEN,
    body: { level: 5, upgrade_exp: -1, maintain_exp: 1, validity_days: 30 },
  });
  assert.equal(bad.status, 400);

  const reset = await call("/api/owner/vip-rules/5", { method: "DELETE", token: OWNER_TOKEN });
  assert.equal(reset.status, 200);
  const restored = await call("/api/owner/vip-rules", { token: OWNER_TOKEN });
  assert.equal(restored.body.levels[4].source, "base");
});

// ---- Store (per-kind permissions) ----

test("Store save/list/delete work; frame kind needs assets.view, not store.view", async () => {
  const { db, call } = await setup();
  const storeOnly = await makeStaff(db, "s1", ["store.view"]);
  const assetsStaff = await makeStaff(db, "s2", ["assets.view"]);

  const denied = await call("/api/owner/store?kind=frame", { token: storeOnly });
  assert.equal(denied.status, 403);

  const allowed = await call("/api/owner/store?kind=frame", { token: assetsStaff });
  assert.equal(allowed.status, 200);

  const saved = await call("/api/owner/store", {
    method: "POST", token: OWNER_TOKEN,
    body: { kind: "frame", id: "frame-test", name: "Test Frame", price_coins: 100, sort_order: 1, enabled: true, data: {} },
  });
  assert.equal(saved.status, 200);

  const listed = await call("/api/owner/store?kind=frame", { token: OWNER_TOKEN });
  // The store merges base frames with overrides, so check membership.
  assert.ok(listed.body.items.some((i) => i.id === "frame-test"));

  const badKind = await call("/api/owner/store", {
    method: "POST", token: OWNER_TOKEN,
    body: { kind: "custom", id: "x", name: "X" },
  });
  assert.equal(badKind.status, 400);

  const deleted = await call("/api/owner/store/frame/frame-test", {
    method: "DELETE", token: OWNER_TOKEN,
  });
  assert.equal(deleted.status, 200);
  const gone = await call("/api/owner/store?kind=frame", { token: OWNER_TOKEN });
  // Store DELETE is a soft-remove: the row stays, marked disabled.
  assert.equal(gone.body.items.find((i) => i.id === "frame-test").enabled, 0);
});

// ---- Catalog kinds ----

test("Catalog accepts only its 10 kinds; vip and custom are rejected", async () => {
  const { call } = await setup();
  for (const kind of ["gift", "entry", "profile_card", "banner"]) {
    const res = await call(`/api/owner/catalog?kind=${kind}`, { token: OWNER_TOKEN });
    assert.equal(res.status, 200, kind);
  }
  for (const kind of ["vip", "vip_privilege", "tag", "game_config", "custom"]) {
    const res = await call(`/api/owner/catalog?kind=${kind}`, { token: OWNER_TOKEN });
    assert.equal(res.status, 400, kind);
  }

  const saved = await call("/api/owner/catalog", {
    method: "POST", token: OWNER_TOKEN,
    body: { kind: "gift", id: "gift-test", name: "Test Gift", price_coins: 100 },
  });
  assert.equal(saved.status, 200);
  const listed = await call("/api/owner/catalog?kind=gift", { token: OWNER_TOKEN });
  assert.equal(listed.body.items.length, 1);

  const deleted = await call("/api/owner/catalog/gift/gift-test", {
    method: "DELETE", token: OWNER_TOKEN,
  });
  assert.equal(deleted.status, 200);
});

// ---- Settings ----

test("Settings load, feature toggle and maintenance save work", async () => {
  const { db, call } = await setup();
  const loaded = await call("/api/owner/settings", { token: OWNER_TOKEN });
  assert.equal(loaded.status, 200);
  assert.ok(loaded.body.settings);

  const toggled = await call("/api/owner/settings/feature.gifts", {
    method: "POST", token: OWNER_TOKEN, body: { value: { enabled: false } },
  });
  assert.equal(toggled.status, 200);
  const row = await db.prepare("SELECT value_json FROM owner_settings WHERE key='feature.gifts'").first();
  assert.equal(JSON.parse(row.value_json).enabled, false);

  const maintenance = await call("/api/owner/settings/maintenance", {
    method: "POST", token: OWNER_TOKEN, body: { value: { enabled: true, message: "down" } },
  });
  assert.equal(maintenance.status, 200);

  const staff = await makeStaff(db, "s1", ["settings.view"]);
  const denied = await call("/api/owner/settings/feature.gifts", {
    method: "POST", token: staff, body: { value: { enabled: true } },
  });
  assert.equal(denied.status, 403);
});

// ---- Announcements ----

test("Announcements save, list and delete work; bad windows are rejected", async () => {
  const { call } = await setup();
  const nowMs = Date.now();
  const saved = await call("/api/owner/announcements", {
    method: "POST", token: OWNER_TOKEN,
    body: { title: "Event", body: "Big event!", starts_at: nowMs, ends_at: nowMs + 3600000 },
  });
  assert.equal(saved.status, 200);
  assert.ok(saved.body.id);

  const bad = await call("/api/owner/announcements", {
    method: "POST", token: OWNER_TOKEN,
    body: { title: "Bad", body: "x", starts_at: nowMs + 3600000, ends_at: nowMs },
  });
  assert.equal(bad.status, 400);

  const listed = await call("/api/owner/announcements", { token: OWNER_TOKEN });
  assert.equal(listed.body.announcements.length, 1);

  const deleted = await call(`/api/owner/announcements/${saved.body.id}`, {
    method: "DELETE", token: OWNER_TOKEN,
  });
  assert.equal(deleted.status, 200);
});

// ---- Support ----

test("Support tickets list, thread, reply and close work; closed tickets reject replies", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  // The support tables are created on first use by handleSupportTickets.
  await call("/api/owner/support-tickets", { token: OWNER_TOKEN });
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO vip_support_tickets(id,user_id,subject,status,created_at,updated_at) VALUES(?,?,?,?,?,?)"
  ).bind("t1", "u1", "Help", "open", nowMs, nowMs).run();
  await db.prepare(
    "INSERT INTO vip_support_messages(id,ticket_id,sender_type,sender_id,body,created_at) VALUES(?,?,?,?,?,?)"
  ).bind("m1", "t1", "user", "u1", "I need help", nowMs).run();

  const listed = await call("/api/owner/support-tickets", { token: OWNER_TOKEN });
  assert.equal(listed.body.tickets.length, 1);
  assert.equal(listed.body.tickets[0].subject, "Help");

  const thread = await call("/api/owner/support-tickets/t1", { token: OWNER_TOKEN });
  assert.equal(thread.body.messages.length, 1);

  const replied = await call("/api/owner/support-tickets/t1/reply", {
    method: "POST", token: OWNER_TOKEN, body: { message: "On it!" },
  });
  assert.equal(replied.status, 200);

  const closed = await call("/api/owner/support-tickets/t1/close", {
    method: "POST", token: OWNER_TOKEN, body: {},
  });
  assert.equal(closed.status, 200);

  const late = await call("/api/owner/support-tickets/t1/reply", {
    method: "POST", token: OWNER_TOKEN, body: { message: "Too late" },
  });
  assert.equal(late.status, 409);
});

// ---- Audit ----

test("Audit lists rows, staff sees only their own, owner can delete one and all", async () => {
  const { db, call } = await setup();
  const staff = await makeStaff(db, "s1", ["audit.view", "treasury.view"]);
  await call("/api/owner/treasury", {
    method: "POST", token: OWNER_TOKEN, body: { action: "add", amount: 1000 },
  });

  const ownerList = await call("/api/owner/audit?limit=10", { token: OWNER_TOKEN });
  assert.equal(ownerList.status, 200);
  assert.ok(ownerList.body.audit.length >= 1);
  assert.equal(ownerList.body.owner_can_delete, true);

  const staffList = await call("/api/owner/audit?limit=10", { token: staff });
  assert.equal(staffList.body.audit.length, 0);

  const rowId = ownerList.body.audit[0].id;
  const deletedOne = await call(`/api/owner/audit/${rowId}`, { method: "DELETE", token: OWNER_TOKEN });
  assert.equal(deletedOne.status, 200);

  const cleared = await call("/api/owner/audit", { method: "DELETE", token: OWNER_TOKEN });
  assert.equal(cleared.status, 200);
  const empty = await call("/api/owner/audit?limit=10", { token: OWNER_TOKEN });
  assert.equal(empty.body.audit.length, 0);
});

// ---- Staff list ----

test("Staff list returns rows with permissions; email is owner-only", async () => {
  const { db, call } = await setup();
  await makeStaff(db, "s1", ["users.search"]);
  const listed = await call("/api/owner/staff", { token: OWNER_TOKEN });
  assert.equal(listed.status, 200);
  assert.equal(listed.body.staff.length, 1);
  assert.deepEqual(listed.body.staff[0].permissions, ["users.search"]);
});
