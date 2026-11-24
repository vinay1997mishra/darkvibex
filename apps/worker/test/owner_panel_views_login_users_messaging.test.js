// Owner Panel views — Overview / Users / Messaging / Notifications.
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
    `../src/owner_api.js?fresh-views-a-${++moduleCounter}`
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

async function makeUser(db, id, displayName = null) {
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO users(id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).bind(id, null, displayName ?? `User ${id}`, "user", 0, 0, 0, nowMs, nowMs).run();
}

// ---- Overview ----

test("Overview returns counts, treasury balance and top rooms", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1", "Ravi");
  await makeUser(db, "u2", "Priya");
  await db.prepare(
    "INSERT INTO rooms(id,owner_user_id,name,seat_count,locked,created_at,updated_at) VALUES(?,?,?,?,?,?,?)"
  ).bind("r1", "u1", "Star Room", 12, 0, Date.now(), Date.now()).run();

  const res = await call("/api/owner/overview", { token: OWNER_TOKEN });
  assert.equal(res.status, 200);
  // 2 users created here + the seeded darkvibex_official user.
  assert.equal(res.body.stats.users, 3);
  assert.equal(res.body.stats.rooms, 1);
  assert.equal(res.body.stats.treasury, 0);
  assert.equal(res.body.rooms.length, 1);

  const staff = await makeStaff(db, "s1", ["users.search"]);
  const denied = await call("/api/owner/overview", { token: staff });
  assert.equal(denied.status, 403);
});

// ---- Users list + detail ----

test("Users list searches by name and id; detail returns the full record", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1", "Ravi Kumar");
  await makeUser(db, "u2", "Priya");

  const listed = await call("/api/owner/users?q=Ravi", { token: OWNER_TOKEN });
  assert.equal(listed.status, 200);
  assert.equal(listed.body.users.length, 1);
  assert.equal(listed.body.users[0].id, "u1");

  const detail = await call("/api/owner/users/u1", { token: OWNER_TOKEN });
  assert.equal(detail.status, 200);
  assert.equal(detail.body.user.id, "u1");
  assert.equal(detail.body.user.display_name, "Ravi Kumar");
  assert.ok(Array.isArray(detail.body.user.wallet_ledger));

  const missing = await call("/api/owner/users/nope", { token: OWNER_TOKEN });
  assert.equal(missing.status, 404);
});

// ---- Moderation ----

test("Moderation suspends a user and the list reflects it", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");

  const res = await call("/api/owner/users/u1/moderation", {
    method: "POST", token: OWNER_TOKEN, body: { status: "suspended", note: "spam" },
  });
  assert.equal(res.status, 200);
  const row = await db.prepare("SELECT status, note FROM owner_user_controls WHERE user_id='u1'").first();
  assert.deepEqual([row.status, row.note], ["suspended", "spam"]);

  const listed = await call("/api/owner/users?q=u1", { token: OWNER_TOKEN });
  assert.equal(listed.body.users[0].status, "suspended");
});

// ---- Public ID ----

test("Public ID changes, rejects duplicates and bad formats", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  await makeUser(db, "u2");

  const changed = await call("/api/owner/users/u1/public-id", {
    method: "POST", token: OWNER_TOKEN, body: { public_id: "12345678" },
  });
  assert.equal(changed.status, 200);
  assert.equal(changed.body.public_id, "12345678");

  const taken = await call("/api/owner/users/u2/public-id", {
    method: "POST", token: OWNER_TOKEN, body: { public_id: "12345678" },
  });
  assert.equal(taken.status, 409);

  const bad = await call("/api/owner/users/u2/public-id", {
    method: "POST", token: OWNER_TOKEN, body: { public_id: "1234567890" },
  });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "public_id_must_be_1_to_999999999");

  // Short IDs are valid now (Mr. Wrong, 2026-11-24): even a single digit.
  const short = await call("/api/owner/users/u2/public-id", {
    method: "POST", token: OWNER_TOKEN, body: { public_id: "123" },
  });
  assert.equal(short.status, 200);
  assert.equal(short.body.public_id, "123");
});

// ---- Device ban ----

test("Device ban and unban work", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");

  const banned = await call("/api/owner/users/u1/device-ban", {
    method: "POST", token: OWNER_TOKEN, body: { device_key: "dev-1", banned: true },
  });
  assert.equal(banned.status, 200);
  const row = await db.prepare("SELECT banned FROM owner_device_bans WHERE device_key='dev-1'").first();
  assert.equal(row.banned, 1);

  const unbanned = await call("/api/owner/users/u1/device-ban", {
    method: "POST", token: OWNER_TOKEN, body: { device_key: "dev-1", banned: false },
  });
  assert.equal(unbanned.status, 200);
  const row2 = await db.prepare("SELECT banned FROM owner_device_bans WHERE device_key='dev-1'").first();
  assert.equal(row2.banned, 0);
});

// ---- Notifications (owner-only) ----

test("Notifications create, list, mark read and delete; staff is blocked", async () => {
  const { db, call } = await setup();
  const staff = await makeStaff(db, "s1", ["notifications.read", "notifications.write"]);

  const blocked = await call("/api/owner/notifications", { token: staff });
  assert.equal(blocked.status, 403);

  const created = await call("/api/owner/notifications", {
    method: "POST", token: OWNER_TOKEN,
    body: { title: "Maintenance", body: "Down at 2am", kind: "platform" },
  });
  assert.equal(created.status, 200);
  assert.ok(created.body.id);

  const listed = await call("/api/owner/notifications", { token: OWNER_TOKEN });
  assert.equal(listed.body.notifications.length, 1);
  assert.equal(listed.body.notifications[0].title, "Maintenance");

  const read = await call(`/api/owner/notifications/${created.body.id}/read`, {
    method: "POST", token: OWNER_TOKEN, body: {},
  });
  assert.equal(read.status, 200);
  const row = await db.prepare("SELECT read_at FROM owner_notifications WHERE id=?").bind(created.body.id).first();
  assert.ok(row.read_at);

  const deleted = await call(`/api/owner/notifications/${created.body.id}`, {
    method: "DELETE", token: OWNER_TOKEN,
  });
  assert.equal(deleted.status, 200);
  const gone = await call("/api/owner/notifications", { token: OWNER_TOKEN });
  assert.equal(gone.body.notifications.length, 0);
});

// ---- Tags ----

test("Role tags apply by user id or public ID, replace per user, list and remove", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  await makeUser(db, "u2");
  await db.prepare("UPDATE users SET public_id=? WHERE id=?").bind("1234567", "u1").run();

  // An old custom tag from before the role-tag switch must be wiped
  // the first time the owner tags API runs (Vinay: old custom tags
  // are gone).
  await db.prepare(
    "INSERT INTO owner_user_tags(user_id,tag_id,name,color,kind,designation,background_color,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).bind("u1", "old-custom", "Old Custom", "#FFD54F", "custom", "", "", Date.now(), Date.now()).run();

  const bad = await call("/api/owner/tags", {
    method: "POST", token: OWNER_TOKEN,
    body: { user_ids: ["u1"], role_tag: "super-admin" },
  });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "invalid_role_tag");

  const applied = await call("/api/owner/tags", {
    method: "POST", token: OWNER_TOKEN,
    body: { user_ids: ["u2"], public_ids: ["1234567"], role_tag: "coin-seller" },
  });
  assert.equal(applied.status, 200);
  assert.equal(applied.body.tagged, 2);
  assert.equal(applied.body.tag_id, "role-coin-seller");
  assert.equal(applied.body.role_tag, "coin-seller");

  // Tag lagte hi wallet automatic add hota hai: the coin-seller tag
  // sets users.role and creates the seller wallet for both IDs.
  assert.equal(applied.body.wallet_added, true);
  assert.equal(applied.body.role, "coin_seller");
  const u1 = await db.prepare("SELECT role FROM users WHERE id=?").bind("u1").first();
  assert.equal(u1.role, "coin_seller");
  const u1Wallet = await db.prepare("SELECT balance_coins,status FROM role_wallets WHERE user_id=? AND wallet_type=?").bind("u1", "coin_seller").first();
  assert.equal(u1Wallet.balance_coins, 0);
  assert.equal(u1Wallet.status, "active");
  const u2Wallet = await db.prepare("SELECT balance_coins,status FROM role_wallets WHERE user_id=? AND wallet_type=?").bind("u2", "coin_seller").first();
  assert.ok(u2Wallet);

  const listed = await call("/api/owner/tags", { token: OWNER_TOKEN });
  // The legacy custom row was wiped; only the two role tags remain.
  assert.equal(listed.body.tags.length, 2);
  assert.ok(listed.body.tags.every((t) => t.kind === "role_tag"));

  // Applying a different tag to the same ID replaces the old one —
  // one role tag per ID.
  const replaced = await call("/api/owner/tags", {
    method: "POST", token: OWNER_TOKEN,
    body: { user_ids: ["u1"], role_tag: "official" },
  });
  assert.equal(replaced.status, 200);
  const afterReplace = await call("/api/owner/tags", { token: OWNER_TOKEN });
  assert.equal(afterReplace.body.tags.length, 2);
  assert.equal(afterReplace.body.tags.find((t) => t.user_id === "u1").tag_id, "role-official");

  // Changing the tag to Official does NOT remove the wallet or the
  // role — the wallet holds money.
  const u1After = await db.prepare("SELECT role FROM users WHERE id=?").bind("u1").first();
  assert.equal(u1After.role, "coin_seller");
  const u1WalletAfter = await db.prepare("SELECT 1 AS one FROM role_wallets WHERE user_id=? AND wallet_type=?").bind("u1", "coin_seller").first();
  assert.ok(u1WalletAfter);

  // The merchant tag adds the merchant wallet the same way, and the
  // old seller wallet row stays (dormant) — wallets are never removed.
  const merchantApplied = await call("/api/owner/tags", {
    method: "POST", token: OWNER_TOKEN,
    body: { user_ids: ["u2"], role_tag: "merchant" },
  });
  assert.equal(merchantApplied.status, 200);
  assert.equal(merchantApplied.body.wallet_added, true);
  assert.equal(merchantApplied.body.role, "merchant");
  const u2After = await db.prepare("SELECT role FROM users WHERE id=?").bind("u2").first();
  assert.equal(u2After.role, "merchant");
  const u2MerchantWallet = await db.prepare("SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?").bind("u2", "merchant").first();
  assert.equal(u2MerchantWallet.balance_coins, 0);
  const u2SellerWallet = await db.prepare("SELECT 1 AS one FROM role_wallets WHERE user_id=? AND wallet_type=?").bind("u2", "coin_seller").first();
  assert.ok(u2SellerWallet);

  const removed = await call("/api/owner/tags/u1/role-official", {
    method: "DELETE", token: OWNER_TOKEN,
  });
  assert.equal(removed.status, 200);
  const after = await call("/api/owner/tags", { token: OWNER_TOKEN });
  assert.equal(after.body.tags.length, 1);
});

test("Staff with only tags.apply cannot mint a seller wallet via a tag", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  const staff = await makeStaff(db, "s1", ["tags.apply", "tags.view"]);
  const denied = await call("/api/owner/tags", {
    method: "POST", token: staff,
    body: { user_ids: ["u1"], role_tag: "coin-seller" },
  });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, "users_role_edit_required");
  // Nothing was applied — the role check runs before any tag row
  // is written.
  const listed = await call("/api/owner/tags", { token: OWNER_TOKEN });
  assert.equal(listed.body.tags.length, 0);
  const u1 = await db.prepare("SELECT role FROM users WHERE id=?").bind("u1").first();
  assert.equal(u1.role, "user");
});

// ---- Messaging: send to selected ----

test("Official message to selected users delivers only to them", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  await makeUser(db, "u2");
  await makeUser(db, "u3");

  const sent = await call("/api/owner/messages", {
    method: "POST", token: OWNER_TOKEN,
    body: { text: "Hello!", user_ids: ["u1", "u2"], all_users: false },
  });
  assert.equal(sent.status, 200);
  assert.equal(sent.body.sent, 2);
  const rows = await db.prepare(
    "SELECT receiver_user_id FROM direct_messages WHERE sender_user_id='darkvibex_official'"
  ).all();
  assert.deepEqual(rows.results.map((r) => r.receiver_user_id).sort(), ["u1", "u2"]);
});

// ---- Message inspection (owner-only) ----

test("Message inspection shows the inbox; staff is blocked", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");
  await makeUser(db, "u2");
  const staff = await makeStaff(db, "s1", ["users.detail"]);
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO direct_messages(id,sender_user_id,receiver_user_id,text,created_at,read_at) VALUES(?,?,?,?,?,NULL)"
  ).bind("m1", "u1", "u2", "hi there", nowMs).run();

  const blocked = await call("/api/owner/users/u1/messages", { token: staff });
  assert.equal(blocked.status, 403);

  const inbox = await call("/api/owner/users/u1/messages", { token: OWNER_TOKEN });
  assert.equal(inbox.status, 200);
  assert.equal(inbox.body.user.id, "u1");

  const thread = await call("/api/owner/users/u1/messages?other_user_id=u2", { token: OWNER_TOKEN });
  assert.equal(thread.status, 200);
  assert.equal(thread.body.messages.length, 1);
  assert.equal(thread.body.messages[0].text, "hi there");
});

// ---- Owner overrides: invisible + lock bypass (ban/freeze covered in wallet tests) ----

test("Owner overrides set invisible ID and locked-room bypass", async () => {
  const { db, call } = await setup();
  await makeUser(db, "u1");

  const res = await call("/api/owner/users/u1/owner-overrides", {
    method: "POST", token: OWNER_TOKEN,
    body: { invisible_id: true, locked_room_bypass: true },
  });
  assert.equal(res.status, 200);
  const row = await db.prepare(
    "SELECT invisible_id, locked_room_bypass FROM owner_user_overrides WHERE user_id='u1'"
  ).first();
  assert.deepEqual([row.invisible_id, row.locked_room_bypass], [1, 1]);
});
