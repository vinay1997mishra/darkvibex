import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";

// Follow/followers/visitors lists are private (Vinay, 2026-11-20): only the
// ID owner may open them. The follow/followers COUNTS stay visible to
// everyone (profile hero, room card) — only the lists are locked down.

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
  const secret = "profile-lists-private-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, request };
}

async function makeUser(fx, userId) {
  // Guest login is deleted permanently (Vinay 2026-11-20): test users are
  // created directly in SQLite instead of through the removed endpoint.
  fx.sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  return userId;
}

async function follow(fx, actor, target) {
  const result = await fx.request("/api/social/follow", {
    method: "POST",
    userId: actor,
    body: { user_id: actor, target_user_id: target, follow: true },
  });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true, JSON.stringify(result.body));
}

test("owner can list their own followers and following", async () => {
  const fx = await fixture();
  const a = await makeUser(fx, "list-owner-a");
  const b = await makeUser(fx, "list-owner-b");
  await follow(fx, a, b);

  const followers = await fx.request(`/api/social/followers?user_id=${b}`, { userId: b });
  assert.equal(followers.status, 200, JSON.stringify(followers.body));
  assert.equal(followers.body.ok, true);
  assert.ok(followers.body.followers.some((row) => row.id === a));

  const following = await fx.request(`/api/social/following?user_id=${a}`, { userId: a });
  assert.equal(following.status, 200, JSON.stringify(following.body));
  assert.equal(following.body.ok, true);
  assert.ok(following.body.following.some((row) => row.id === b));

  // No user_id param means "my own list" and still works.
  const ownFollowers = await fx.request("/api/social/followers", { userId: b });
  assert.equal(ownFollowers.status, 200);
  assert.ok(ownFollowers.body.followers.some((row) => row.id === a));
});

test("another user cannot list someone else's followers or following", async () => {
  const fx = await fixture();
  const a = await makeUser(fx, "list-other-a");
  const b = await makeUser(fx, "list-other-b");
  await follow(fx, a, b);

  const followers = await fx.request(`/api/social/followers?user_id=${b}`, { userId: a });
  assert.equal(followers.status, 403, JSON.stringify(followers.body));
  assert.equal(followers.body.error, "forbidden");

  const following = await fx.request(`/api/social/following?user_id=${a}`, { userId: b });
  assert.equal(following.status, 403, JSON.stringify(following.body));
  assert.equal(following.body.error, "forbidden");
});

test("another user cannot list someone else's visitors; the owner needs VIP1+ to see their own", async () => {
  const fx = await fixture();
  const a = await makeUser(fx, "list-visitors-a");
  const b = await makeUser(fx, "list-visitors-b");
  // The table is created by ensureVipSchema at runtime (vip_store.js);
  // the bare schema.sql fixture does not have it yet. The visitors query
  // also LEFT JOINs user_vip, which needs the same treatment.
  fx.sqlite.exec("CREATE TABLE IF NOT EXISTS profile_visitors (viewed_user_id TEXT NOT NULL, visitor_user_id TEXT NOT NULL, first_visited_at INTEGER NOT NULL, last_visited_at INTEGER NOT NULL, visit_count INTEGER NOT NULL DEFAULT 1, PRIMARY KEY (viewed_user_id, visitor_user_id))");
  fx.sqlite.exec("CREATE TABLE IF NOT EXISTS user_vip (user_id TEXT PRIMARY KEY, level INTEGER NOT NULL DEFAULT 0, exp_balance REAL NOT NULL DEFAULT 0, total_received_coins INTEGER NOT NULL DEFAULT 0, active_until INTEGER, custom_id TEXT UNIQUE, last_id_change_at INTEGER, id_change_level INTEGER NOT NULL DEFAULT 0, preferences_json TEXT NOT NULL DEFAULT '{}', free_say_hi_used INTEGER NOT NULL DEFAULT 0, free_say_hi_cycle TEXT NOT NULL DEFAULT '', exp_rate_version INTEGER NOT NULL DEFAULT 3, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)");

  const visitors = await fx.request(`/api/users/${b}/visitors`, { userId: a });
  assert.equal(visitors.status, 403, JSON.stringify(visitors.body));
  assert.equal(visitors.body.error, "forbidden");

  // View Visitors is a VIP1+ privilege: the owner (VIP0) is blocked too.
  const ownVisitorsBlocked = await fx.request(`/api/users/${b}/visitors`, { userId: b });
  assert.equal(ownVisitorsBlocked.status, 403, JSON.stringify(ownVisitorsBlocked.body));
  assert.equal(ownVisitorsBlocked.body.error, "vip_required");

  // Once the owner is an active VIP1, their own visitors list opens.
  // (The earlier visitors call already created B's user_vip row via
  // getVipStatus, so this is an UPDATE, not an INSERT.)
  fx.sqlite.prepare("UPDATE user_vip SET level=1,active_until=? WHERE user_id=?")
    .run(Date.now() + 86400000, b);
  const ownVisitors = await fx.request(`/api/users/${b}/visitors`, { userId: b });
  assert.equal(ownVisitors.status, 200, JSON.stringify(ownVisitors.body));
  assert.equal(ownVisitors.body.ok, true);
});

test("follow and unfollow stay owner-only", async () => {
  const fx = await fixture();
  const a = await makeUser(fx, "list-follow-a");
  const b = await makeUser(fx, "list-follow-b");

  // B cannot follow on A's behalf: the session must match the actor.
  const spoof = await fx.request("/api/social/follow", {
    method: "POST",
    userId: b,
    body: { user_id: a, target_user_id: b, follow: true },
  });
  assert.equal(spoof.status, 403, JSON.stringify(spoof.body));

  // The owner can follow and unfollow.
  await follow(fx, a, b);
  const unfollow = await fx.request("/api/social/follow", {
    method: "POST",
    userId: a,
    body: { user_id: a, target_user_id: b, follow: false },
  });
  assert.equal(unfollow.status, 200, JSON.stringify(unfollow.body));
});
