// Owner panel fixes (full-app audit, 2026-11-20): catalog/store kind
// allowlist, legacy staff token expiry, staff login lockout, Send-to-All
// batching, lock-code disclosure, base games list, Gmail hash in env.
// One shared fixture for the whole file: ensureOwnerSchema runs once per
// process (module-level flag), so a fresh :memory: DB per test would miss
// the owner tables.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { pbkdf2Sync } from "node:crypto";
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

async function sha256Hex(text) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

const sqlite = new DatabaseSync(":memory:");
sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
const DB = new D1Mock(sqlite);
const files = {
  deleted: [],
  async delete(key) { this.deleted.push(String(key)); },
  async put() { return { ok: true }; },
  async get() { return null; },
};
const env = { DB, SESSION_SECRET: "owner-panel-fixes-test-secret", OWNER_ADMIN_TOKEN: "owner-test-token", FILES: files };
const ownerToken = "owner-test-token";

async function requestRaw(path, { method = "GET", body, token } = {}) {
  const headers = new Headers();
  if (body != null) headers.set("content-type", "application/json");
  if (token) headers.set("authorization", `Bearer ${token}`);
  const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
  return { status: response.status, body: await response.json() };
}
const owner = (path, opts = {}) => requestRaw(path, { ...opts, token: ownerToken });

function insertStaffRow(row) {
  sqlite.prepare(
    "INSERT INTO owner_staff(id,display_name,role,token_hash,permissions_json,enabled,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)"
  ).run(row.id, row.display_name, row.role, row.token_hash, row.permissions_json, row.enabled ? 1 : 0, Date.now(), Date.now());
}

// A password-less staff row with a real legacy token, seeded BEFORE the
// first owner call so the migration backfill (A2) can give it its 7-day
// grace window. Seeded at module load: the first test's owner call runs
// ensureOwnerSchema.
const legacyGraceToken = "legacy-grace-token-1";
const legacyGraceHash = await sha256Hex(legacyGraceToken);
insertStaffRow({
  id: "staff-legacy-grace", display_name: "Legacy Grace", role: "manager",
  token_hash: legacyGraceHash, permissions_json: JSON.stringify(["rooms.view"]), enabled: true,
});

test("legacy token of a password-less staff member gets a 7-day grace window, then works", async () => {
  const before = await owner("/api/owner/session");
  assert.equal(before.status, 200, JSON.stringify(before.body));
  const row = sqlite.prepare("SELECT token_expires_at FROM owner_staff WHERE id=?").get("staff-legacy-grace");
  assert.ok(Number(row.token_expires_at) > Date.now(), "grace expiry must be in the future");
  assert.ok(Number(row.token_expires_at) <= Date.now() + 7 * 24 * 60 * 60 * 1000 + 60000, "grace is 7 days, not forever");
  const authed = await requestRaw("/api/owner/session", { token: legacyGraceToken });
  assert.equal(authed.status, 200, JSON.stringify(authed.body));
  assert.equal(authed.body.actor?.type, "staff");
});

test("legacy tokens with a past expiry, or none at all, are rejected", async () => {
  const expiredHash = await sha256Hex("legacy-expired-token");
  const nullHash = await sha256Hex("legacy-null-token");
  sqlite.prepare(
    "INSERT INTO owner_staff(id,display_name,role,token_hash,permissions_json,enabled,created_at,updated_at,token_expires_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).run("staff-legacy-expired", "Legacy Expired", "manager", expiredHash, JSON.stringify(["rooms.view"]), 1, Date.now(), Date.now(), Date.now() - 1000);
  sqlite.prepare(
    "INSERT INTO owner_staff(id,display_name,role,token_hash,permissions_json,enabled,created_at,updated_at,token_expires_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).run("staff-legacy-null", "Legacy Null", "manager", nullHash, JSON.stringify(["rooms.view"]), 1, Date.now(), Date.now(), null);
  for (const token of ["legacy-expired-token", "legacy-null-token"]) {
    const res = await requestRaw("/api/owner/session", { token });
    assert.equal(res.status, 401, token + ": " + JSON.stringify(res.body));
  }
});

test("catalog.save cannot write vip_rule or game_config, store.save cannot either", async () => {
  for (const [path, kind] of [
    ["/api/owner/catalog", "vip_rule"],
    ["/api/owner/catalog", "game_config"],
    ["/api/owner/catalog", "vip"],
    ["/api/owner/catalog", "custom"],
    ["/api/owner/store", "vip_rule"],
    ["/api/owner/store", "game_config"],
  ]) {
    const res = await owner(path, { method: "POST", body: { kind, id: "1", name: "Should not save" } });
    assert.equal(res.status, 400, path + " " + kind + ": " + JSON.stringify(res.body));
    assert.equal(res.body.error, "kind_not_allowed");
  }
  const gift = await owner("/api/owner/catalog", { method: "POST", body: { kind: "gift", id: "test-gift-a1", name: "Test Gift" } });
  assert.equal(gift.status, 200, JSON.stringify(gift.body));
  const category = await owner("/api/owner/store", { method: "POST", body: { kind: "gift_category", id: "test-cat-a1", name: "Test Category" } });
  assert.equal(category.status, 200, JSON.stringify(category.body));
  const deleted = await owner("/api/owner/catalog/vip_rule/1", { method: "DELETE" });
  assert.equal(deleted.status, 400, JSON.stringify(deleted.body));
  assert.equal(deleted.body.error, "kind_not_allowed");
});

test("catalog GET without a kind never returns vip_rule or game_config rows", async () => {
  sqlite.prepare(
    "INSERT INTO owner_catalog(kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at) VALUES('vip_rule','1','VIP 1',1,0,0,'','{}',?)"
  ).run(Date.now());
  const all = await owner("/api/owner/catalog");
  assert.equal(all.status, 200, JSON.stringify(all.body));
  assert.ok(!(all.body.items ?? []).some((item) => item.kind === "vip_rule" || item.kind === "game_config"));
  assert.ok((all.body.items ?? []).some((item) => item.kind === "gift"));
  const filtered = await owner("/api/owner/catalog?kind=vip_rule");
  assert.equal(filtered.status, 400, JSON.stringify(filtered.body));
  assert.equal(filtered.body.error, "kind_not_allowed");
});

test("staff password login locks for 15 minutes after 5 wrong attempts", async () => {
  const saltHex = "0123456789abcdef0123456789abcdef";
  const passwordHash = pbkdf2Sync("correct-horse", Buffer.from(saltHex, "hex"), 120000, 32, "sha256").toString("hex");
  sqlite.prepare(
    "INSERT INTO owner_staff(id,display_name,role,token_hash,email,password_salt,password_hash,password_iterations,permissions_json,enabled,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)"
  ).run("staff-lock-test", "Lock Test", "manager", await sha256Hex("credential-only:staff-lock-test"), "locktest@gmail.com", saltHex, passwordHash, 120000, JSON.stringify([]), 1, Date.now(), Date.now());
  const login = (password, email = "locktest@gmail.com") => requestRaw("/api/owner/login", { method: "POST", body: { email, password } });
  for (let i = 0; i < 5; i++) {
    const wrong = await login("wrong-password");
    assert.equal(wrong.status, 401, "attempt " + (i + 1) + ": " + JSON.stringify(wrong.body));
  }
  const locked = await login("correct-horse");
  assert.equal(locked.status, 429, JSON.stringify(locked.body));
  assert.equal(locked.body.error, "too_many_attempts");
  assert.ok(Number(locked.body.retry_after_seconds) > 0 && Number(locked.body.retry_after_seconds) <= 900);
  // Another email is unaffected by the lock.
  const other = await login("whatever", "someone-else@gmail.com");
  assert.equal(other.status, 401, JSON.stringify(other.body));
});

test("a successful staff login clears the failure count", async () => {
  const saltHex = "fedcba9876543210fedcba9876543210";
  const passwordHash = pbkdf2Sync("let-me-in-please", Buffer.from(saltHex, "hex"), 120000, 32, "sha256").toString("hex");
  sqlite.prepare(
    "INSERT INTO owner_staff(id,display_name,role,token_hash,email,password_salt,password_hash,password_iterations,permissions_json,enabled,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)"
  ).run("staff-clear-test", "Clear Test", "manager", await sha256Hex("credential-only:staff-clear-test"), "cleartest@gmail.com", saltHex, passwordHash, 120000, JSON.stringify([]), 1, Date.now(), Date.now());
  const login = (password) => requestRaw("/api/owner/login", { method: "POST", body: { email: "cleartest@gmail.com", password } });
  assert.equal((await login("nope")).status, 401);
  assert.equal((await login("still-nope")).status, 401);
  const ok = await login("let-me-in-please");
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  assert.ok(String(ok.body.token ?? "").startsWith("dvxs_"));
  const row = sqlite.prepare("SELECT * FROM owner_staff_login_attempts WHERE email=?").get("cleartest@gmail.com");
  assert.equal(row, undefined);
});

test("Send to All delivers to 250 users and audits the send before and after", async () => {
  const ts = Date.now();
  const insert = sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)");
  for (let i = 0; i < 250; i++) insert.run("bulk-user-" + i, "Bulk " + i, ts, ts);
  const sent = await owner("/api/owner/messages", { method: "POST", body: { text: "Hello everyone", all_users: true } });
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.sent, 250);
  const count = sqlite.prepare("SELECT COUNT(*) AS value FROM direct_messages WHERE sender_user_id='darkvibex_official' AND text='Hello everyone'").get().value;
  assert.equal(count, 250);
  const audits = sqlite.prepare("SELECT action FROM owner_audit WHERE action LIKE 'official_message%' ORDER BY rowid ASC").all();
  assert.deepEqual(audits.map((row) => row.action), ["official_message_started", "official_message"]);
});

test("room lock code is visible to the owner only; staff only learn it is set", async () => {
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run("room-owner-a5", "Room Owner", Date.now(), Date.now());
  sqlite.prepare("INSERT INTO rooms(id,owner_user_id,name,seat_count,created_at,updated_at) VALUES(?,?,?,?,?,?)").run("room-a5", "room-owner-a5", "Locked Room", 12, Date.now(), Date.now());
  sqlite.prepare(
    "INSERT INTO room_settings(room_id,lock_password_code,updated_at) VALUES(?,?,?) ON CONFLICT(room_id) DO UPDATE SET lock_password_code=excluded.lock_password_code"
  ).run("room-a5", "12345", Date.now());
  const asOwner = await owner("/api/owner/rooms/room-a5/live");
  assert.equal(asOwner.status, 200, JSON.stringify(asOwner.body));
  assert.equal(asOwner.body.room.lock_code, "12345");
  assert.equal(asOwner.body.room.lock_code_set, true);

  sqlite.prepare(
    "INSERT INTO owner_staff(id,display_name,role,token_hash,permissions_json,enabled,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)"
  ).run("staff-live-a5", "Live Staff", "manager", await sha256Hex("credential-only:staff-live-a5"), JSON.stringify(["rooms.live"]), 1, Date.now(), Date.now());
  sqlite.prepare(
    "INSERT INTO owner_staff_sessions(token_hash,staff_id,created_at,expires_at,last_used_at) VALUES(?,?,?,?,?)"
  ).run(await sha256Hex("staff-live-token"), "staff-live-a5", Date.now(), Date.now() + 3600000, Date.now());
  const asStaff = await requestRaw("/api/owner/rooms/room-a5/live", { token: "staff-live-token" });
  assert.equal(asStaff.status, 200, JSON.stringify(asStaff.body));
  assert.equal(asStaff.body.room.lock_code, "");
  assert.equal(asStaff.body.room.lock_code_set, true);
});

test("Games view lists the three base games, merged with saved overrides", async () => {
  const before = await owner("/api/owner/games");
  assert.equal(before.status, 200, JSON.stringify(before.body));
  const ids = (before.body.games ?? []).map((game) => game.id);
  assert.ok(ids.includes("ludo") && ids.includes("fruit-party") && ids.includes("greedy-girl"));
  const ludo = before.body.games.find((game) => game.id === "ludo");
  assert.equal(Number(ludo.data?.min_bet ?? 0), 1);
  assert.equal(Number(ludo.data?.max_bet ?? 0), 1000000);
  sqlite.prepare(
    "INSERT INTO owner_catalog(kind,id,name,enabled,sort_order,price_coins,country,json_data,updated_at) VALUES('game_config','ludo','Ludo',1,0,0,'','{\"min_bet\":100,\"max_bet\":5000}',?)"
  ).run(Date.now());
  const after = await owner("/api/owner/games");
  const ludoAfter = after.body.games.find((game) => game.id === "ludo");
  assert.equal(Number(ludoAfter.data?.min_bet ?? 0), 100);
  assert.equal(Number(ludoAfter.data?.max_bet ?? 0), 5000);
});

const ownerApi = readFileSync(new URL("../src/owner_api.js", import.meta.url), "utf8");
const workerIndex = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const panelApp = readFileSync(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("source: allowlists, expiry, lockout, batching, lock-code and env hash are in place", () => {
  assert.match(ownerApi, /const CATALOG_KINDS = new Set\(/);
  assert.match(ownerApi, /const STORE_KINDS = new Set\(/);
  assert.match(ownerApi, /kind_not_allowed/);
  assert.match(ownerApi, /token_expires_at IS NOT NULL AND token_expires_at > /);
  assert.match(ownerApi, /MAX_STAFF_LOGIN_ATTEMPTS = 5/);
  assert.match(ownerApi, /STAFF_LOGIN_LOCK_MS = 15 \* 60 \* 1000/);
  assert.match(ownerApi, /too_many_attempts/);
  assert.match(ownerApi, /MESSAGE_BATCH_SIZE = 100/);
  assert.match(ownerApi, /official_message_started/);
  assert.match(ownerApi, /room\.lock_code_set = /);
  assert.match(ownerApi, /const BASE_GAMES = \[/);
  assert.match(ownerApi, /env\.OWNER_GMAIL_SHA256/);
  assert.doesNotMatch(ownerApi, /MAIN_OWNER_GMAIL_SHA256/);
  assert.doesNotMatch(ownerApi, /821a3b8e/);
  // Bet limits never go NaN: a garbage value falls back instead of
  // passing every bet.
  assert.match(workerIndex, /Number\.isFinite\(n\) \? n : Number\(fallback\)/);
  assert.doesNotMatch(workerIndex, /min_bet:Number\(data\.min_bet \?\? fallback\.min_bet\)/);
  assert.doesNotMatch(workerIndex, /max_bet:Number\(data\.max_bet \?\? fallback\.max_bet\)/);
  // Panel: the lock code renders only when the worker sent it; a staff
  // member sees "Lock code set" instead. The official-message selection
  // clears after sending.
  assert.match(panelApp, /Lock code set/);
  assert.match(panelApp, /state\.messageSelected\.clear\(\)/);
  assert.match(panelApp, /renderSelectedMessageUsers\(\)/);
});
