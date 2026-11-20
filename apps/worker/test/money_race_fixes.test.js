// Money race fixes (full-app audit, 2026-11-20): lucky-pouch refunds,
// CP request/disconnect, room ban bypass and room-delete orphans.
// Sequential tests pin the money behaviour; the genuinely concurrent
// races are pinned by the source assertions at the bottom, because the
// single-threaded mock cannot interleave two requests.
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
  const secret = "money-race-fixes-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, FILES: files, OWNER_ADMIN_TOKEN: "owner-test-token" };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  // Raw bearer calls (owner-panel auth: the main-owner token, or a staff
  // session token) — the user JWT helper above cannot make these.
  const requestRaw = async (path, { method = "GET", body, token } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (token) headers.set("authorization", `Bearer ${token}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, request, requestRaw, files };
}

async function sha256Hex(text) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

let publicIdCounter = 7660000;
async function makeUser(fx, userId, { coins = 100000, vipLevel = 0, country = "IN" } = {}) {
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

async function makeRoom(fx, ownerId) {
  const { request } = fx;
  const body = { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12 };
  const created = await request("/api/rooms", { method: "POST", userId: ownerId, body });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return String(created.body.room_id);
}

function makeMutualFriends(fx, a, b) {
  const now = Date.now();
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(a, b, now);
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(b, a, now);
}

function coins(fx, userId) {
  return fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get(userId).coins;
}

async function cpRequest(fx, from, to) {
  return fx.request("/api/cp/request", {
    method: "POST", userId: from,
    body: { user_id: from, target_user_id: to },
  });
}

async function cpRespond(fx, userId, accept) {
  return fx.request("/api/cp/respond", {
    method: "POST", userId,
    body: { user_id: userId, accept },
  });
}

async function cpDisconnect(fx, userId) {
  return fx.request("/api/cp/disconnect", {
    method: "POST", userId, body: { user_id: userId },
  });
}

test("two expired lucky pouches refund exactly once each, with distinct ledger rows", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "pouch-owner", { coins: 100000 });
  const roomId = await makeRoom(fx, owner.userId);
  const now = Date.now();
  // The pouch tables are created on demand by the worker; seed them with
  // the same DDL the endpoint's ensure would create.
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS room_lucky_pouches (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    owner_user_id TEXT NOT NULL,
    total_coins INTEGER NOT NULL,
    total_slots INTEGER NOT NULL,
    remaining_coins INTEGER NOT NULL,
    remaining_slots INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'open',
    request_id TEXT NOT NULL,
    last_claim_key TEXT,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    UNIQUE (owner_user_id, request_id),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
  )`);
  // Two expired, still-open pouches owned by the same user.
  fx.sqlite.prepare(
    "INSERT INTO room_lucky_pouches(id,room_id,owner_user_id,total_coins,total_slots,remaining_coins,remaining_slots,status,request_id,created_at,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)"
  ).run("pouch-1", roomId, owner.userId, 10000, 5, 6000, 3, "open", "req-1", now - 60000, now - 1000);
  fx.sqlite.prepare(
    "INSERT INTO room_lucky_pouches(id,room_id,owner_user_id,total_coins,total_slots,remaining_coins,remaining_slots,status,request_id,created_at,expires_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)"
  ).run("pouch-2", roomId, owner.userId, 8000, 4, 4000, 2, "open", "req-2", now - 60000, now - 1000);
  // The pouch read triggers the expire pass.
  const first = await fx.request(`/api/rooms/${roomId}/lucky-pouch`, { userId: owner.userId });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(coins(fx, owner.userId), 110000);
  const statuses = fx.sqlite.prepare("SELECT status FROM room_lucky_pouches WHERE room_id=? ORDER BY id").all(roomId).map((r) => r.status);
  assert.deepEqual(statuses, ["expired_refunded", "expired_refunded"]);
  const ledger = fx.sqlite.prepare(
    "SELECT id, amount FROM wallet_ledger WHERE user_id=? AND kind='room_lucky_pouch_refund' ORDER BY amount"
  ).all(owner.userId);
  assert.equal(ledger.length, 2);
  assert.notEqual(ledger[0].id, ledger[1].id);
  assert.deepEqual(ledger.map((r) => r.amount), [4000, 6000]);
  // A second expire pass must not credit the same coins again.
  const second = await fx.request(`/api/rooms/${roomId}/lucky-pouch`, { userId: owner.userId });
  assert.equal(second.status, 200, JSON.stringify(second.body));
  assert.equal(coins(fx, owner.userId), 110000);
  assert.equal(fx.sqlite.prepare(
    "SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id=? AND kind='room_lucky_pouch_refund'"
  ).get(owner.userId).n, 2);
});

test("cancelling a pending CP invite costs nothing extra and kills the invite DM", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a", { coins: 50000000 });
  await makeUser(fx, "cp-b", { coins: 50000000 });
  makeMutualFriends(fx, "cp-a", "cp-b");
  const requested = await cpRequest(fx, "cp-a", "cp-b");
  assert.equal(requested.status, 201, JSON.stringify(requested.body));
  assert.equal(coins(fx, "cp-a"), 30000000);
  const cancelled = await cpDisconnect(fx, "cp-a");
  assert.equal(cancelled.status, 200, JSON.stringify(cancelled.body));
  // No second 20M charge: the requester's 20M stays paid, nothing more.
  assert.equal(coins(fx, "cp-a"), 30000000);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM cp_relationships").get().n, 0);
  const dm = fx.sqlite.prepare(
    "SELECT kind FROM direct_messages WHERE sender_user_id=? AND receiver_user_id=?"
  ).get("cp-a", "cp-b");
  assert.equal(dm?.kind, "cp_invite_rejected");
});

test("direct CP disconnect with insufficient coins returns 400, not 500", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a", { coins: 50000000 });
  await makeUser(fx, "cp-b", { coins: 50000000 });
  makeMutualFriends(fx, "cp-a", "cp-b");
  const requested = await cpRequest(fx, "cp-a", "cp-b");
  assert.equal(requested.status, 201, JSON.stringify(requested.body));
  const accepted = await cpRespond(fx, "cp-b", true);
  assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
  fx.sqlite.prepare("UPDATE users SET coins=? WHERE id=?").run(100, "cp-a");
  const result = await cpDisconnect(fx, "cp-a");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.error, "insufficient_coins");
  // The active CP is untouched.
  assert.equal(fx.sqlite.prepare("SELECT state FROM cp_relationships").get().state, "active");
});

test("a platform-banned room cannot be re-created", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "ban-owner", { coins: 100000 });
  const roomId = await makeRoom(fx, owner.userId);
  fx.sqlite.prepare(
    "INSERT INTO owner_room_controls(room_id,banned,note,updated_at) VALUES(?,?,?,?)"
  ).run(roomId, 1, "banned by owner panel", Date.now());
  const recreated = await fx.request("/api/rooms", {
    method: "POST", userId: owner.userId,
    body: { owner_user_id: owner.userId, owner_name: owner.userId, name: "ban-owner room", seat_count: 12 },
  });
  assert.equal(recreated.status, 403, JSON.stringify(recreated.body));
  assert.equal(recreated.body.error, "room_banned");
  // The ban row survives the attempt.
  assert.equal(fx.sqlite.prepare("SELECT banned FROM owner_room_controls WHERE room_id=?").get(roomId).banned, 1);
});

async function seedRoomForDelete(fx, owner, member) {
  const roomId = await makeRoom(fx, owner.userId);
  const now = Date.now();
  // Tables the worker creates on demand (same DDL as src).
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS room_admins (
    room_id TEXT NOT NULL, user_id TEXT NOT NULL, added_by TEXT NOT NULL,
    created_at INTEGER NOT NULL, PRIMARY KEY (room_id, user_id))`);
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS room_bans (
    room_id TEXT NOT NULL, user_id TEXT NOT NULL, banned_by TEXT NOT NULL,
    created_at INTEGER NOT NULL, PRIMARY KEY (room_id, user_id))`);
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS room_kick_events (
    room_id TEXT NOT NULL, user_id TEXT NOT NULL, kicked_at INTEGER NOT NULL,
    PRIMARY KEY (room_id, user_id))`);
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS room_custom_themes (
    id TEXT PRIMARY KEY, room_id TEXT NOT NULL, owner_user_id TEXT NOT NULL,
    name TEXT NOT NULL, asset_key TEXT NOT NULL, price_coins INTEGER NOT NULL DEFAULT 10000000,
    created_at INTEGER NOT NULL, expires_at INTEGER)`);
  fx.sqlite.prepare("INSERT INTO room_admins(room_id,user_id,added_by,created_at) VALUES(?,?,?,?)")
    .run(roomId, member.userId, owner.userId, now);
  fx.sqlite.prepare("INSERT INTO room_bans(room_id,user_id,banned_by,created_at) VALUES(?,?,?,?)")
    .run(roomId, member.userId, owner.userId, now);
  fx.sqlite.prepare("INSERT INTO room_kick_events(room_id,user_id,kicked_at) VALUES(?,?,?)")
    .run(roomId, member.userId, now);
  fx.sqlite.prepare("INSERT INTO room_custom_themes(id,room_id,owner_user_id,name,asset_key,created_at) VALUES(?,?,?,?,?,?)")
    .run("theme-1", roomId, owner.userId, "Gold", "themes/gold.png", now);
  fx.sqlite.prepare("INSERT INTO room_messages(id,room_id,user_id,text,created_at) VALUES(?,?,?,?,?)")
    .run("msg-1", roomId, member.userId, "hi", now);
  fx.sqlite.prepare("INSERT INTO room_message_images(message_id,image_key,created_at) VALUES(?,?,?)")
    .run("msg-1", "rooms/msg-1.png", now);
  return roomId;
}

function roomRowCounts(fx, roomId) {
  const count = (table) => fx.sqlite.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE room_id=?`).get(roomId).n;
  return {
    room: fx.sqlite.prepare("SELECT COUNT(*) AS n FROM rooms WHERE id=?").get(roomId).n,
    admins: count("room_admins"),
    bans: count("room_bans"),
    kickEvents: count("room_kick_events"),
    themes: count("room_custom_themes"),
    messages: count("room_messages"),
    messageImages: fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_message_images").get().n,
  };
}

// Room delete is owner-panel only (Vinay, 2026-11-20): the app user
// cannot delete their room, and neither can panel staff — only the
// platform owner deletes rooms, from the owner panel.
test("a user cannot delete their room from the app", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "del-owner", { coins: 100000 });
  const member = await makeUser(fx, "del-member", { coins: 100000 });
  const roomId = await seedRoomForDelete(fx, owner, member);
  const result = await fx.request(`/api/rooms/${roomId}/delete`, {
    method: "POST", userId: owner.userId, body: { user_id: owner.userId },
  });
  assert.equal(result.status, 403, JSON.stringify(result.body));
  assert.equal(result.body.error, "room_delete_owner_panel_only");
  // Nothing was deleted.
  assert.deepEqual(roomRowCounts(fx, roomId), {
    room: 1, admins: 1, bans: 1, kickEvents: 1, themes: 1, messages: 1, messageImages: 1,
  });
});

test("the platform owner deletes a room from the owner panel, with full teardown", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "del-owner", { coins: 100000 });
  const member = await makeUser(fx, "del-member", { coins: 100000 });
  const roomId = await seedRoomForDelete(fx, owner, member);
  const deleted = await fx.requestRaw(`/api/owner/rooms/${roomId}`, {
    method: "DELETE", token: "owner-test-token",
  });
  assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
  assert.deepEqual(roomRowCounts(fx, roomId), {
    room: 0, admins: 0, bans: 0, kickEvents: 0, themes: 0, messages: 0, messageImages: 0,
  });
  // The message image file was removed from R2 best-effort.
  assert.ok(fx.files.deleted.includes("rooms/msg-1.png"), JSON.stringify(fx.files.deleted));
});

test("panel staff cannot delete a room, even with every permission", async () => {
  const fx = await fixture();
  const owner = await makeUser(fx, "del-owner", { coins: 100000 });
  const member = await makeUser(fx, "del-member", { coins: 100000 });
  const roomId = await seedRoomForDelete(fx, owner, member);
  // Bootstrap the owner schema, then give a staff member a session with
  // the "*" permission (the strongest staff grant there is).
  const session = await fx.requestRaw("/api/owner/session", { token: "owner-test-token" });
  assert.equal(session.status, 200, JSON.stringify(session.body));
  const now = Date.now();
  const staffToken = "staff-test-token";
  const staffHash = await sha256Hex(staffToken);
  // The worker skips its owner-schema ensure on a second DB binding in
  // the same process (module-level schema-ready flag), so this test's
  // fresh DB needs the sessions table created explicitly.
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS owner_staff_sessions (
    token_hash TEXT PRIMARY KEY,
    staff_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES owner_staff(id) ON DELETE CASCADE
  )`);
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS owner_login_sessions (
    token_hash TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    last_used_at INTEGER NOT NULL
  )`);
  fx.sqlite.prepare(
    "INSERT INTO owner_staff(id,display_name,role,token_hash,permissions_json,enabled,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?)"
  ).run("staff-1", "Staff One", "admin", staffHash, JSON.stringify(["*"]), 1, now, now);
  fx.sqlite.prepare(
    "INSERT INTO owner_staff_sessions(token_hash,staff_id,created_at,expires_at,last_used_at) VALUES(?,?,?,?,?)"
  ).run(staffHash, "staff-1", now, now + 3600000, now);
  const result = await fx.requestRaw(`/api/owner/rooms/${roomId}`, {
    method: "DELETE", token: staffToken,
  });
  assert.equal(result.status, 403, JSON.stringify(result.body));
  assert.equal(result.body.error, "owner_only");
  assert.deepEqual(roomRowCounts(fx, roomId), {
    room: 1, admins: 1, bans: 1, kickEvents: 1, themes: 1, messages: 1, messageImages: 1,
  });
});

test("race guards are wired in source", async () => {
  const index = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  const social = readFileSync(new URL("../src/tinni_social.js", import.meta.url), "utf8");
  const roleWallets = readFileSync(new URL("../src/role_wallets.js", import.meta.url), "utf8");
  const ownerApi = readFileSync(new URL("../src/owner_api.js", import.meta.url), "utf8");
  const inviteRewards = readFileSync(new URL("../src/invite_rewards.js", import.meta.url), "utf8");
  const roomCleanup = readFileSync(new URL("../src/room_cleanup.js", import.meta.url), "utf8");
  // Call billing claims minutes before debiting them.
  assert.ok(index.includes("AND billed_minutes=?"), "call billing CAS claim missing");
  // walletChange debits atomically.
  assert.ok(index.includes("coins + ? >= 0"), "walletChange atomic guard missing");
  // Cosmetic purchase grants only when still unowned, and revokes on error.
  assert.ok(index.includes("WHERE NOT EXISTS"), "cosmetic guarded grant missing");
  assert.ok(index.includes("DELETE FROM ${table} WHERE user_id=? AND item_id=? AND acquired_at=?"), "cosmetic revoke missing");
  // CP request inserts only when no row exists for the pair.
  assert.ok(social.includes("SELECT 1 FROM cp_relationships WHERE user_a=? AND user_b=?"), "CP NOT EXISTS insert missing");
  // CP gift progress claims the event before counting it, then moves
  // progress relatively and levels up with a compare-and-swap.
  assert.ok(social.includes("INSERT OR IGNORE INTO cp_gift_progress"), "CP progress claim-first missing");
  assert.ok(social.includes("intimacy=intimacy+?"), "CP progress relative increment missing");
  assert.ok(social.includes("AND level=?"), "CP level-up CAS missing");
  // Role wallet and treasury moves are relative, not absolute SETs.
  assert.ok(roleWallets.includes("balance_coins=balance_coins-?"), "role wallet relative debit missing");
  assert.ok(roleWallets.includes("coins=coins+?"), "role wallet relative credit missing");
  assert.ok(ownerApi.includes("balance = balance - ?"), "treasury relative debit missing");
  assert.ok(ownerApi.includes("coins=coins+?,diamonds=diamonds+?"), "owner wallet relative update missing");
  // Owner room delete uses the shared teardown.
  assert.ok(ownerApi.includes("deleteRoomRows"), "owner room delete teardown missing");
  assert.ok(roomCleanup.includes("room_kick_events"), "room cleanup table list missing");
  // Invite rewards use the canonical $1 = 8,000,000 coins rate.
  assert.ok(inviteRewards.includes("COINS_PER_USD = 8_000_000"), "invite rate is not 8,000,000");
});

test("room delete is owner-panel only: no user endpoint, no staff permission", async () => {
  const index = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  const ownerApi = readFileSync(new URL("../src/owner_api.js", import.meta.url), "utf8");
  const panelApp = readFileSync(new URL("../../owner_panel/app.js", import.meta.url), "utf8");
  // The app user endpoint answers 403, it never deletes.
  assert.ok(index.includes("room_delete_owner_panel_only"), "user delete must answer room_delete_owner_panel_only");
  assert.ok(!index.includes("deleteRoomRows(db, roomId, env.FILES"), "user delete must not call the teardown");
  // The owner-panel delete is gated on the main owner, not a permission.
  assert.ok(!ownerApi.includes('requirePermission(actor, "rooms.delete")'), "rooms.delete permission must be gone");
  assert.ok(ownerApi.includes("deleteRoomRows"), "owner delete must use the shared teardown");
  // The panel no longer offers rooms.delete to staff, and hides the
  // Remove button from everyone except the main owner.
  assert.ok(!panelApp.includes('["rooms.delete","Rooms · remove room"]'), "panel must not offer rooms.delete to staff");
  assert.ok(!panelApp.includes('["[data-room-delete]",["rooms.delete"]]'), "Remove button must not be permission-gated");
  assert.ok(panelApp.includes('$$("[data-room-delete]").forEach(b=>{b.hidden=state.actor?.type!=="owner";})'), "Remove button must be owner-only");
});
