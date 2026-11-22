// Owner Panel views — Rooms / Roles / Banners / Games / Policies / Pricing.
// Behavioural tests for the controls the panel audit found untested
// (Vinay, 2026-11-22: every Owner Panel button and function must work
// 100%). Calls the real handleOwnerApi with an in-memory D1 mock.
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
    `../src/owner_api.js?fresh-views-${++moduleCounter}`
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

async function makeRoom(db, id, ownerId, name = "Star Room") {
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO rooms(id,owner_user_id,name,seat_count,locked,created_at,updated_at) VALUES(?,?,?,?,?,?,?)"
  ).bind(id, ownerId, name, 12, 0, nowMs, nowMs).run();
}

async function addMember(db, roomId, userId) {
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO room_members(room_id,user_id,seat_index,mic_muted,joined_at,updated_at) VALUES(?,?,?,?,?,?)"
  ).bind(roomId, userId, 0, 1, nowMs, nowMs).run();
}

// ---- Rooms ----

test("Rooms list and live investigation work", async () => {
  const { db, call } = await setup();
  await makeUser(db, "owner1");
  await makeUser(db, "u1");
  await makeRoom(db, "r1", "owner1");
  await addMember(db, "r1", "u1");

  const listed = await call("/api/owner/rooms", { token: OWNER_TOKEN });
  assert.equal(listed.status, 200);
  assert.equal(listed.body.rooms.length, 1);
  assert.equal(listed.body.rooms[0].name, "Star Room");
  assert.equal(listed.body.rooms[0].online, 1);

  const searched = await call("/api/owner/rooms?q=Star", { token: OWNER_TOKEN });
  assert.equal(searched.body.rooms.length, 1);
  const missed = await call("/api/owner/rooms?q=Nope", { token: OWNER_TOKEN });
  assert.equal(missed.body.rooms.length, 0);

  const live = await call("/api/owner/rooms/r1/live", { token: OWNER_TOKEN });
  assert.equal(live.status, 200);
  assert.equal(live.body.room.id, "r1");
  assert.equal(live.body.room.owner_name, "User owner1");
});

test("Room media and theme save work", async () => {
  const { db, call } = await setup();
  await makeUser(db, "owner1");
  await makeRoom(db, "r1", "owner1");

  const media = await call("/api/owner/rooms/r1/media", {
    method: "POST", token: OWNER_TOKEN,
    body: { image_key: "rooms/r1/dp.png", background_key: "rooms/r1/bg.png" },
  });
  assert.equal(media.status, 200);
  const image = await db.prepare("SELECT image_key FROM room_images WHERE room_id='r1'").first();
  assert.equal(image.image_key, "rooms/r1/dp.png");

  const theme = await call("/api/owner/rooms/r1/theme", {
    method: "POST", token: OWNER_TOKEN, body: { theme_id: "gold" },
  });
  assert.equal(theme.status, 200);
  assert.equal(theme.body.theme_id, "gold");
});

test("Room ban kicks members, lock and edit clamp seats to 8-42", async () => {
  const { db, call } = await setup();
  await makeUser(db, "owner1");
  await makeUser(db, "u1");
  await makeRoom(db, "r1", "owner1");
  await addMember(db, "r1", "u1");

  const banned = await call("/api/owner/rooms/r1/ban", {
    method: "POST", token: OWNER_TOKEN, body: { banned: true },
  });
  assert.equal(banned.status, 200);
  assert.equal(banned.body.banned, true);
  const members = await db.prepare("SELECT user_id FROM room_members WHERE room_id='r1'").all();
  assert.equal(members.results.length, 0);

  const locked = await call("/api/owner/rooms/r1", {
    method: "POST", token: OWNER_TOKEN, body: { locked: true },
  });
  assert.equal(locked.status, 200);

  const edited = await call("/api/owner/rooms/r1", {
    method: "POST", token: OWNER_TOKEN, body: { name: "New Name", seat_count: 100 },
  });
  assert.equal(edited.status, 200);
  const room = await db.prepare("SELECT name, seat_count, locked FROM rooms WHERE id='r1'").first();
  assert.deepEqual([room.name, room.seat_count, room.locked], ["New Name", 42, 1]);

  const staff = await makeStaff(db, "s1", ["rooms.view"]);
  const denied = await call("/api/owner/rooms/r1", {
    method: "POST", token: staff, body: { locked: false },
  });
  assert.equal(denied.status, 403);
});

// ---- Roles ----

test("Roles posts save, list and delete work", async () => {
  const { db, call } = await setup();
  const saved = await call("/api/owner/roles-posts?kind=role", {
    method: "POST", token: OWNER_TOKEN,
    body: { name: "Super Admin", enabled: true, sort_order: 1, data: { details: "top role" } },
  });
  assert.equal(saved.status, 200);
  assert.ok(saved.body.id);

  const listed = await call("/api/owner/roles-posts?kind=role", { token: OWNER_TOKEN });
  assert.equal(listed.body.items.length, 1);
  assert.equal(listed.body.items[0].name, "Super Admin");

  const deleted = await call(`/api/owner/roles-posts/${saved.body.id}?kind=role`, {
    method: "DELETE", token: OWNER_TOKEN,
  });
  assert.equal(deleted.status, 200);
  const gone = await call("/api/owner/roles-posts?kind=role", { token: OWNER_TOKEN });
  assert.equal(gone.body.items.length, 0);
});

// ---- Banners ----

test("Banners save, list and delete work", async () => {
  const { call } = await setup();
  const saved = await call("/api/owner/banners", {
    method: "POST", token: OWNER_TOKEN,
    body: { name: "Welcome", asset_key: "banners/w.png", link: "", enabled: true },
  });
  assert.equal(saved.status, 200);
  assert.ok(saved.body.id);

  const listed = await call("/api/owner/banners", { token: OWNER_TOKEN });
  assert.equal(listed.body.banners.length, 1);
  assert.equal(listed.body.banners[0].name, "Welcome");

  const deleted = await call(`/api/owner/banners/${saved.body.id}`, {
    method: "DELETE", token: OWNER_TOKEN,
  });
  assert.equal(deleted.status, 200);
  const gone = await call("/api/owner/banners", { token: OWNER_TOKEN });
  assert.equal(gone.body.banners.length, 0);
});

// ---- Games ----

test("Games list the base games and a saved config merges in", async () => {
  const { call } = await setup();
  const before = await call("/api/owner/games", { token: OWNER_TOKEN });
  assert.equal(before.status, 200);
  assert.ok(before.body.games.length >= 3);
  const ludoBefore = before.body.games.find((g) => g.id === "ludo");
  assert.ok(ludoBefore);

  const saved = await call("/api/owner/games", {
    method: "POST", token: OWNER_TOKEN,
    body: { id: "ludo", name: "Ludo", min_bet: 100, max_bet: 5000000, enabled: true },
  });
  assert.equal(saved.status, 200);

  const after = await call("/api/owner/games", { token: OWNER_TOKEN });
  const ludoAfter = after.body.games.find((g) => g.id === "ludo");
  assert.equal(ludoAfter.data.min_bet, 100);
  assert.equal(ludoAfter.data.max_bet, 5000000);
});

// ---- Policies: successful delete ----

test("Policy delete removes a real policy key", async () => {
  const { db, call } = await setup();
  const staff = await makeStaff(db, "s1", ["policies.save", "policies.view", "policies.delete"]);
  const saved = await call("/api/owner/policies", {
    method: "POST", token: staff, body: { key: "welcome_text", value: { text: "hi" } },
  });
  assert.equal(saved.status, 200);

  const deleted = await call("/api/owner/policies/policy.welcome_text", {
    method: "DELETE", token: staff,
  });
  assert.equal(deleted.status, 200);
  const row = await db.prepare("SELECT key FROM owner_settings WHERE key='policy.welcome_text'").first();
  assert.equal(row, null);
});

// ---- Pricing: the fixed gates (panel now requires pricing.save / pricing.delete) ----

test("Pricing overrides require pricing.save / pricing.delete, not policies.save", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  const pricingStaff = await makeStaff(db, "p1", ["pricing.view", "pricing.save", "pricing.delete"]);
  const policiesOnly = await makeStaff(db, "p2", ["pricing.view", "policies.save"]);

  const saved = await call("/api/owner/pricing-overrides", {
    method: "POST", token: pricingStaff,
    body: { user_id: "u1", kind: "gift", item_id: "*", price_coins: 1000, free: false, duration_days: 30 },
  });
  assert.equal(saved.status, 200);

  const deniedSave = await call("/api/owner/pricing-overrides", {
    method: "POST", token: policiesOnly,
    body: { user_id: "u1", kind: "gift", item_id: "*", price_coins: 1000, free: false, duration_days: 30 },
  });
  assert.equal(deniedSave.status, 403);

  const listed = await call("/api/owner/pricing-overrides?user_id=u1", { token: OWNER_TOKEN });
  assert.equal(listed.body.overrides.length, 1);

  const deniedDelete = await call("/api/owner/pricing-overrides/u1/gift/*", {
    method: "DELETE", token: policiesOnly,
  });
  assert.equal(deniedDelete.status, 403);

  const deleted = await call("/api/owner/pricing-overrides/u1/gift/*", {
    method: "DELETE", token: pricingStaff,
  });
  assert.equal(deleted.status, 200);
  const gone = await call("/api/owner/pricing-overrides?user_id=u1", { token: OWNER_TOKEN });
  assert.equal(gone.body.overrides.length, 0);
});
