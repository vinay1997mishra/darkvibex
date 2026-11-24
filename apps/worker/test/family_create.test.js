// Create Family page (Mr. Wrong, 2026-11-24 — approved pic): creating a
// family costs 90,000,000 coins, free for Wealth Level >= 30 or VIP
// Level >= 6. The name and tag can each only be changed once a month
// (30 days, leader only). If the leader does not log in for 15 days,
// the leader position auto-transfers to the longest-joined admin, else
// the longest-joined member. A family with approval off lets anyone
// join directly; with approval on, joins stay pending requests.
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
  sqlite.exec(`CREATE TABLE IF NOT EXISTS owner_user_devices (
    device_key TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    last_seen_at INTEGER NOT NULL
  )`);
  const DB = new D1Mock(sqlite);
  const secret = "family-create-test-secret";
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
  return { sqlite, DB, request, files };
}

let publicIdCounter = 7660000;
async function makeUser(fx, userId, { coins = 100000, vipLevel = 0, country = "IN" } = {}) {
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

function coins(fx, userId) {
  return fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get(userId).coins;
}

function setLastSeen(fx, userId, daysAgo) {
  fx.sqlite.prepare(
    "INSERT INTO owner_user_devices(device_key,user_id,last_seen_at) VALUES(?,?,?)"
  ).run(`device-${userId}`, userId, Date.now() - daysAgo * 24 * 60 * 60 * 1000);
}

async function createFamily(fx, userId, overrides = {}) {
  return fx.request("/api/family/create", {
    method: "POST",
    userId,
    body: {
      user_id: userId,
      name: "TIGER FAMILY",
      tag: "TIGER",
      // Logo is mandatory (Mr. Wrong, 2026-11-24) — every test
      // family carries one unless the test overrides it away.
      logo_key: "family-logos/demo-logo.jpg",
      ...overrides,
    },
  });
}

async function familyState(fx, userId) {
  return fx.request(`/api/family?user_id=${encodeURIComponent(userId)}`, {
    method: "GET",
    userId,
  });
}

async function makeFamily(fx, leaderId, overrides = {}) {
  await makeUser(fx, leaderId, { coins: 200000000 });
  const created = await createFamily(fx, leaderId, overrides);
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return created.body.family_id;
}

test("family create costs exactly 90,000,000 coins", async () => {
  const fx = await fixture();
  await makeUser(fx, "fam-a", { coins: 100000000 });
  const result = await createFamily(fx, "fam-a", {
    approval_required: false,
    logo_key: "family-logos/fam-a-1.jpg",
  });
  assert.equal(result.status, 201, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(result.body.price_coins, 90000000);
  assert.equal(result.body.free, false);
  assert.equal(coins(fx, "fam-a"), 10000000);
  const ledger = fx.sqlite.prepare(
    "SELECT kind,amount,balance_after,reference_id FROM wallet_ledger WHERE user_id=?",
  ).get("fam-a");
  assert.equal(ledger?.kind, "family_create");
  assert.equal(ledger?.amount, -90000000);
  assert.equal(ledger?.balance_after, 10000000);
  assert.equal(ledger?.reference_id, result.body.family_id);
  const family = fx.sqlite.prepare(
    "SELECT name,tag,leader_user_id,approval_required,logo_key FROM families WHERE id=?",
  ).get(result.body.family_id);
  assert.equal(family?.name, "TIGER FAMILY");
  assert.equal(family?.tag, "TIGER");
  assert.equal(family?.leader_user_id, "fam-a");
  assert.equal(family?.approval_required, 0);
  assert.equal(family?.logo_key, "family-logos/fam-a-1.jpg");
  const member = fx.sqlite.prepare(
    "SELECT role FROM family_members WHERE family_id=? AND user_id=?",
  ).get(result.body.family_id, "fam-a");
  assert.equal(member?.role, "leader");
});

test("family create is free for VIP Level 6", async () => {
  const fx = await fixture();
  await makeUser(fx, "fam-vip", { coins: 1000, vipLevel: 6 });
  const result = await createFamily(fx, "fam-vip");
  assert.equal(result.status, 201, JSON.stringify(result.body));
  assert.equal(result.body.free, true);
  assert.equal(result.body.price_coins, 0);
  assert.equal(coins(fx, "fam-vip"), 1000);
});

test("family create is free for Wealth Level 30", async () => {
  const fx = await fixture();
  await makeUser(fx, "fam-rich", { coins: 1000 });
  await makeUser(fx, "fam-other", { coins: 1000 });
  const thresholds = Array.from({ length: 30 }, () => 1000);
  fx.sqlite.prepare(
    "INSERT INTO owner_settings(key,value_json,updated_at) VALUES(?,?,?)",
  ).run("wealth_level_thresholds", JSON.stringify(thresholds), Date.now());
  fx.sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,created_at) VALUES(?,?,?,?,?,?,?,?)",
  ).run("gift-1", null, "fam-rich", "fam-other", "rose", 1000000, 1, Date.now());
  const result = await createFamily(fx, "fam-rich");
  assert.equal(result.status, 201, JSON.stringify(result.body));
  assert.equal(result.body.free, true);
  assert.equal(result.body.price_coins, 0);
  assert.equal(coins(fx, "fam-rich"), 1000);
});

test("family create fails with insufficient_coins below 90,000,000", async () => {
  const fx = await fixture();
  await makeUser(fx, "fam-poor", { coins: 50000000 });
  const result = await createFamily(fx, "fam-poor");
  assert.equal(result.status, 400, JSON.stringify(result.body));
  assert.equal(result.body.error, "insufficient_coins");
  assert.equal(coins(fx, "fam-poor"), 50000000);
  const count = fx.sqlite.prepare("SELECT COUNT(*) AS n FROM families").get().n;
  assert.equal(count, 0);
});

test("family create blocks banned words in the name and tag", async () => {
  const fx = await fixture();
  await makeUser(fx, "fam-bad", { coins: 200000000 });
  const byName = await createFamily(fx, "fam-bad", { name: "chutiya family" });
  assert.equal(byName.status, 400, JSON.stringify(byName.body));
  assert.equal(byName.body.error, "content_blocked");
  const byTag = await createFamily(fx, "fam-bad", { tag: "chutiya" });
  assert.equal(byTag.status, 400, JSON.stringify(byTag.body));
  assert.equal(byTag.body.error, "content_blocked");
});

test("family create requires a logo", async () => {
  const fx = await fixture();
  await makeUser(fx, "fam-nologo", { coins: 200000000 });
  const noLogo = await createFamily(fx, "fam-nologo", { logo_key: "" });
  assert.equal(noLogo.status, 400, JSON.stringify(noLogo.body));
  assert.equal(noLogo.body.error, "logo_required");
  const missingLogo = await createFamily(fx, "fam-nologo", { logo_key: undefined });
  assert.equal(missingLogo.status, 400, JSON.stringify(missingLogo.body));
  assert.equal(missingLogo.body.error, "logo_required");
});

test("family create rejects a duplicate name or tag", async () => {
  const fx = await fixture();
  await makeFamily(fx, "fam-one");
  await makeUser(fx, "fam-two", { coins: 200000000 });
  const sameName = await createFamily(fx, "fam-two", { name: "tiger family" });
  assert.equal(sameName.status, 400, JSON.stringify(sameName.body));
  assert.equal(sameName.body.error, "family_name_or_tag_in_use");
  const sameTag = await createFamily(fx, "fam-two", { name: "OTHER", tag: "tiger" });
  assert.equal(sameTag.status, 400, JSON.stringify(sameTag.body));
  assert.equal(sameTag.body.error, "family_name_or_tag_in_use");
});

test("family create rejects a user already in a family", async () => {
  const fx = await fixture();
  await makeFamily(fx, "fam-dup");
  const again = await createFamily(fx, "fam-dup", { name: "SECOND", tag: "SEC" });
  assert.equal(again.status, 400, JSON.stringify(again.body));
  assert.equal(again.body.error, "already_in_family");
});

test("family join is direct when approval is not required", async () => {
  const fx = await fixture();
  const familyId = await makeFamily(fx, "fam-open", { approval_required: false });
  await makeUser(fx, "fam-joiner", { coins: 1000 });
  const joined = await fx.request("/api/family/join-request", {
    method: "POST",
    userId: "fam-joiner",
    body: { user_id: "fam-joiner", family_id: familyId },
  });
  assert.equal(joined.status, 200, JSON.stringify(joined.body));
  assert.equal(joined.body.joined, true);
  const state = await familyState(fx, "fam-joiner");
  assert.equal(state.body.family?.id, familyId);
  assert.equal(state.body.family?.my_role, "member");
});

test("family join stays a pending request when approval is required", async () => {
  const fx = await fixture();
  const familyId = await makeFamily(fx, "fam-closed");
  await makeUser(fx, "fam-waiter", { coins: 1000 });
  const requested = await fx.request("/api/family/join-request", {
    method: "POST",
    userId: "fam-waiter",
    body: { user_id: "fam-waiter", family_id: familyId },
  });
  assert.equal(requested.status, 200, JSON.stringify(requested.body));
  assert.equal(requested.body.joined, undefined);
  const state = await familyState(fx, "fam-closed");
  assert.equal(state.body.join_requests?.length, 1);
  assert.equal(state.body.join_requests[0]?.user_id, "fam-waiter");
});

test("family rename is blocked within 30 days, per field", async () => {
  const fx = await fixture();
  await makeFamily(fx, "fam-rename");
  const byName = await fx.request("/api/family/update", {
    method: "POST",
    userId: "fam-rename",
    body: { user_id: "fam-rename", name: "NEW NAME" },
  });
  assert.equal(byName.status, 400, JSON.stringify(byName.body));
  assert.equal(byName.body.error, "family_name_change_too_soon");
  const byTag = await fx.request("/api/family/update", {
    method: "POST",
    userId: "fam-rename",
    body: { user_id: "fam-rename", tag: "NEWTAG" },
  });
  assert.equal(byTag.status, 400, JSON.stringify(byTag.body));
  assert.equal(byTag.body.error, "family_tag_change_too_soon");
});

test("family rename works after 30 days and updates the timestamps", async () => {
  const fx = await fixture();
  const familyId = await makeFamily(fx, "fam-old");
  const old = Date.now() - 31 * 24 * 60 * 60 * 1000;
  fx.sqlite.prepare(
    "UPDATE families SET name_changed_at=?, tag_changed_at=? WHERE id=?",
  ).run(old, old, familyId);
  const renamed = await fx.request("/api/family/update", {
    method: "POST",
    userId: "fam-old",
    body: { user_id: "fam-old", name: "NEW NAME", tag: "NEWTAG" },
  });
  assert.equal(renamed.status, 200, JSON.stringify(renamed.body));
  assert.equal(renamed.body.ok, true);
  assert.equal(renamed.body.name, "NEW NAME");
  assert.equal(renamed.body.tag, "NEWTAG");
  const row = fx.sqlite.prepare(
    "SELECT name,tag,name_changed_at,tag_changed_at FROM families WHERE id=?",
  ).get(familyId);
  assert.equal(row?.name, "NEW NAME");
  assert.ok(Number(row?.name_changed_at) > old);
  assert.ok(Number(row?.tag_changed_at) > old);
});

test("family rename is leader-only", async () => {
  const fx = await fixture();
  const familyId = await makeFamily(fx, "fam-leader", { approval_required: false });
  await makeUser(fx, "fam-member", { coins: 1000 });
  await fx.request("/api/family/join-request", {
    method: "POST",
    userId: "fam-member",
    body: { user_id: "fam-member", family_id: familyId },
  });
  const old = Date.now() - 31 * 24 * 60 * 60 * 1000;
  fx.sqlite.prepare(
    "UPDATE families SET name_changed_at=? WHERE id=?",
  ).run(old, familyId);
  const renamed = await fx.request("/api/family/update", {
    method: "POST",
    userId: "fam-member",
    body: { user_id: "fam-member", name: "STOLEN" },
  });
  assert.equal(renamed.status, 400, JSON.stringify(renamed.body));
  assert.equal(renamed.body.error, "family_leader_required");
});

test("familyState returns rename timestamps, logo and approval", async () => {
  const fx = await fixture();
  await makeFamily(fx, "fam-state", {
    approval_required: false,
    logo_key: "family-logos/fam-state-1.jpg",
  });
  const state = await familyState(fx, "fam-state");
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.ok(Number(state.body.family?.name_changed_at) > 0);
  assert.ok(Number(state.body.family?.tag_changed_at) > 0);
  assert.equal(state.body.family?.logo_key, "family-logos/fam-state-1.jpg");
  assert.equal(state.body.family?.approval_required, 0);
});

test("inactive leader auto-transfers after 15 days", async () => {
  const fx = await fixture();
  const familyId = await makeFamily(fx, "fam-gone", { approval_required: false });
  await makeUser(fx, "fam-admin", { coins: 1000 });
  await makeUser(fx, "fam-member2", { coins: 1000 });
  for (const userId of ["fam-admin", "fam-member2"]) {
    await fx.request("/api/family/join-request", {
      method: "POST",
      userId,
      body: { user_id: userId, family_id: familyId },
    });
  }
  fx.sqlite.prepare(
    "UPDATE family_members SET role='admin' WHERE family_id=? AND user_id=?",
  ).run(familyId, "fam-admin");
  setLastSeen(fx, "fam-gone", 16);
  setLastSeen(fx, "fam-admin", 1);
  const state = await familyState(fx, "fam-admin");
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.equal(state.body.family?.leader_user_id, "fam-admin");
  assert.equal(state.body.family?.my_role, "leader");
  const oldLeader = fx.sqlite.prepare(
    "SELECT role FROM family_members WHERE family_id=? AND user_id=?",
  ).get(familyId, "fam-gone");
  assert.equal(oldLeader?.role, "member");
});

test("active leader does not transfer", async () => {
  const fx = await fixture();
  const familyId = await makeFamily(fx, "fam-here", { approval_required: false });
  await makeUser(fx, "fam-m2", { coins: 1000 });
  await fx.request("/api/family/join-request", {
    method: "POST",
    userId: "fam-m2",
    body: { user_id: "fam-m2", family_id: familyId },
  });
  setLastSeen(fx, "fam-here", 1);
  const state = await familyState(fx, "fam-m2");
  assert.equal(state.body.family?.leader_user_id, "fam-here");
});

test("no transfer when the leader is alone or has no device data", async () => {
  const fx = await fixture();
  await makeFamily(fx, "fam-alone");
  setLastSeen(fx, "fam-alone", 30);
  const alone = await familyState(fx, "fam-alone");
  assert.equal(alone.body.family?.leader_user_id, "fam-alone");
  assert.equal(alone.body.family?.my_role, "leader");
  const nodataId = await makeFamily(fx, "fam-nodata", {
    name: "SECOND FAMILY",
    tag: "SECOND",
    approval_required: false,
  });
  await makeUser(fx, "fam-m3", { coins: 1000 });
  await fx.request("/api/family/join-request", {
    method: "POST",
    userId: "fam-m3",
    body: { user_id: "fam-m3", family_id: nodataId },
  });
  // No owner_user_devices rows at all for fam-nodata: no transfer.
  const nodata = await familyState(fx, "fam-m3");
  assert.equal(nodata.body.family?.leader_user_id, "fam-nodata");
});
