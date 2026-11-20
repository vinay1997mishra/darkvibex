// Push-device + profile-media + device-mapping security (audit fix,
// Vinay 2026-11-20): a push token could be reassigned to whoever posted
// it last; any logged-in user could read anyone's profile media with
// ?user_id=; and any x-device-id header rebound that device to the
// caller. All three now respect first ownership.
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
  const secret = "push-device-media-security-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId, headers: extraHeaders } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    for (const [key, value] of Object.entries(extraHeaders ?? {})) headers.set(key, value);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  const now = Date.now();
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run("alice", "Alice", now, now);
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run("bob", "Bob", now, now);
  return { sqlite, request };
}

test("profile media is readable only by its owner", async () => {
  const { request } = await fixture();
  const saved = await request("/api/profile-media", {
    method: "POST", userId: "alice",
    body: { slot: "cover", asset_key: "users/alice/profile-media-cover-1.jpg" },
  });
  assert.equal(saved.status, 200, JSON.stringify(saved.body));

  const stranger = await request("/api/profile-media?user_id=alice", { userId: "bob" });
  assert.equal(stranger.status, 403, JSON.stringify(stranger.body));
  assert.equal(stranger.body.error, "forbidden");

  const own = await request("/api/profile-media?user_id=alice", { userId: "alice" });
  assert.equal(own.status, 200, JSON.stringify(own.body));
  assert.equal(own.body.media.cover, "users/alice/profile-media-cover-1.jpg");

  const ownDefault = await request("/api/profile-media", { userId: "alice" });
  assert.equal(ownDefault.status, 200, JSON.stringify(ownDefault.body));
  assert.equal(ownDefault.body.media.cover, "users/alice/profile-media-cover-1.jpg");
});

test("a push token cannot be stolen by another user", async () => {
  const { sqlite, request } = await fixture();
  const token = "fcm-token-alice-device-1234567890";
  const first = await request("/api/push/device", {
    method: "POST", userId: "alice",
    body: { user_id: "alice", token, platform: "android", device_key: "alice-phone" },
  });
  assert.equal(first.status, 200, JSON.stringify(first.body));

  const steal = await request("/api/push/device", {
    method: "POST", userId: "bob",
    body: { user_id: "bob", token, platform: "android", device_key: "bob-phone" },
  });
  assert.equal(steal.status, 409, JSON.stringify(steal.body));
  assert.equal(steal.body.error, "push_token_owned_by_another_user");
  assert.equal(
    sqlite.prepare("SELECT user_id FROM push_devices WHERE token=?").get(token).user_id,
    "alice",
    "the token must stay with its first owner",
  );

  const again = await request("/api/push/device", {
    method: "POST", userId: "alice",
    body: { user_id: "alice", token, platform: "android", device_key: "alice-phone" },
  });
  assert.equal(again.status, 200, JSON.stringify(again.body));
});

test("a device_key cannot be rebound to another user by sending its header", async () => {
  const { sqlite, request } = await fixture();
  const aliceCall = await request("/api/config", { userId: "alice", headers: { "x-device-id": "device-1" } });
  assert.equal(aliceCall.status, 200, JSON.stringify(aliceCall.body));
  assert.equal(
    sqlite.prepare("SELECT user_id FROM owner_user_devices WHERE device_key=?").get("device-1").user_id,
    "alice",
  );

  const bobCall = await request("/api/config", { userId: "bob", headers: { "x-device-id": "device-1" } });
  assert.equal(bobCall.status, 200, JSON.stringify(bobCall.body));
  assert.equal(
    sqlite.prepare("SELECT user_id FROM owner_user_devices WHERE device_key=?").get("device-1").user_id,
    "alice",
    "the device must stay mapped to its first owner",
  );

  const bobOwn = await request("/api/config", { userId: "bob", headers: { "x-device-id": "device-2" } });
  assert.equal(bobOwn.status, 200, JSON.stringify(bobOwn.body));
  assert.equal(
    sqlite.prepare("SELECT user_id FROM owner_user_devices WHERE device_key=?").get("device-2").user_id,
    "bob",
  );
});
