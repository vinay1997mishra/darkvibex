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
  const secret = "room-envelope-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  for (const userId of ["sender", "member", "outsider"]) {
    await request("/api/session/guest", { method: "POST", body: { user_id: userId, display_name: userId } });
  }
  const ts = Date.now();
  sqlite.prepare("INSERT INTO rooms (id,owner_user_id,name,seat_count,created_at,updated_at) VALUES ('room','sender','Room',15,?,?)").run(ts, ts);
  sqlite.prepare("INSERT INTO room_members (room_id,user_id,seat_index,joined_at,updated_at) VALUES ('room','sender',0,?,?),('room','member',1,?,?)").run(ts, ts, ts, ts);
  return { sqlite, env, request };
}

test("room envelope lasts 24 hours and each room member can claim it once", async () => {
  const { sqlite, request } = await fixture();
  const before = sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins;
  const created = await request("/api/rooms/room/lucky-pouch", {
    method: "POST", userId: "sender",
    body: { user_id: "sender", total_coins: 5000, request_id: "room-envelope-1" },
  });
  assert.equal(created.status, 200);
  assert.equal(created.body.eligible_room_members, 2);
  assert.ok(created.body.expires_at - Date.now() <= 86400000);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins, before - 5000);

  const outsider = await request("/api/rooms/room/lucky-pouch/claim", { method: "POST", userId: "outsider", body: { user_id: "outsider" } });
  assert.equal(outsider.status, 403);
  const first = await request("/api/rooms/room/lucky-pouch/claim", { method: "POST", userId: "member", body: { user_id: "member" } });
  assert.equal(first.status, 200);
  const duplicate = await request("/api/rooms/room/lucky-pouch/claim", { method: "POST", userId: "member", body: { user_id: "member" } });
  assert.equal(duplicate.body.duplicate, true);
  assert.equal(duplicate.body.amount, first.body.amount);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM room_lucky_pouch_claims WHERE user_id='member'").get().n, 1);
  sqlite.close();
});

test("expired room envelope refunds its unclaimed balance exactly once", async () => {
  const { sqlite, env, request } = await fixture();
  const before = sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins;
  const created = await request("/api/rooms/room/lucky-pouch", {
    method: "POST", userId: "sender",
    body: { user_id: "sender", total_coins: 5000, request_id: "room-envelope-expiry" },
  });
  assert.equal(created.status, 200);
  await request("/api/rooms/room/lucky-pouch/claim", { method: "POST", userId: "member", body: { user_id: "member" } });
  sqlite.prepare("UPDATE room_lucky_pouches SET expires_at=? WHERE id=?").run(Date.now() - 1, created.body.pouch_id);
  const scheduled = [];
  await worker.scheduled({}, env, { waitUntil: (promise) => scheduled.push(promise) });
  await Promise.all(scheduled);
  const pouch = sqlite.prepare("SELECT remaining_coins,status FROM room_lucky_pouches WHERE id=?").get(created.body.pouch_id);
  assert.equal(pouch.status, "refunded");
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins, before - 5000 + pouch.remaining_coins);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='room_lucky_pouch_refund'").get().n, 1);
  await worker.scheduled({}, env, { waitUntil: (promise) => scheduled.push(promise) });
  await Promise.all(scheduled.splice(0));
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='room_lucky_pouch_refund'").get().n, 1);
  sqlite.close();
});
