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
  const secret = "red-envelope-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  for (const [id, name] of [["sender", "Sender"], ["receiver", "Receiver"], ["intruder", "Intruder"]]) {
    const response = await request("/api/session/guest", { method: "POST", body: { user_id: id, display_name: name } });
    assert.equal(response.status, 200);
  }
  sqlite.prepare("UPDATE users SET vip_level=6 WHERE id='sender'").run();
  await request("/api/vip/sender", { userId: "sender" });
  return { sqlite, DB, env, request };
}

test("VIP6 inbox envelope is single-claim, recipient-bound, and ledger-backed", async () => {
  const { sqlite, request } = await fixture();
  const senderBefore = sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins;
  const created = await request("/api/messages/red-envelope", {
    method: "POST", userId: "sender",
    body: { sender_user_id: "sender", receiver_user_id: "receiver", amount: 1234 },
  });
  assert.equal(created.status, 201);
  assert.equal(created.body.expires_at - Date.now() <= 86400000, true);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins, senderBefore - 1234);

  const wrongRecipient = await request(`/api/messages/red-envelope/${created.body.envelope_id}/claim`, {
    method: "POST", userId: "intruder", body: { user_id: "intruder" },
  });
  assert.equal(wrongRecipient.status, 409);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='intruder'").get().coins, 2500000);

  const claimed = await request(`/api/messages/red-envelope/${created.body.envelope_id}/claim`, {
    method: "POST", userId: "receiver", body: { user_id: "receiver" },
  });
  assert.equal(claimed.status, 200);
  assert.equal(claimed.body.amount, 1234);
  const duplicate = await request(`/api/messages/red-envelope/${created.body.envelope_id}/claim`, {
    method: "POST", userId: "receiver", body: { user_id: "receiver" },
  });
  assert.equal(duplicate.body.duplicate, true);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, 2501234);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='red_envelope_claim'").get().n, 1);
  sqlite.close();
});

test("expired unclaimed envelope is refunded exactly once and cannot be claimed", async () => {
  const { sqlite, env, request } = await fixture();
  const created = await request("/api/messages/red-envelope", {
    method: "POST", userId: "sender",
    body: { sender_user_id: "sender", receiver_user_id: "receiver", amount: 876 },
  });
  assert.equal(created.status, 201);
  sqlite.prepare("UPDATE inbox_red_envelopes SET expires_at=? WHERE id=?").run(Date.now() - 1, created.body.envelope_id);
  const scheduled = [];
  await worker.scheduled({}, env, { waitUntil: (promise) => scheduled.push(promise) });
  await Promise.all(scheduled);
  const balance = sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins;
  assert.equal(balance, 2500000);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='red_envelope_refund'").get().n, 1);
  await worker.scheduled({}, env, { waitUntil: (promise) => scheduled.push(promise) });
  await Promise.all(scheduled.splice(0));
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins, 2500000);
  const claim = await request(`/api/messages/red-envelope/${created.body.envelope_id}/claim`, {
    method: "POST", userId: "receiver", body: { user_id: "receiver" },
  });
  assert.equal(claim.status, 409);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins, 2500000);
  sqlite.close();
});

test("inactive VIP6 and insufficient wallet cannot create an envelope", async () => {
  const { sqlite, request } = await fixture();
  sqlite.prepare("UPDATE users SET coins=100 WHERE id='sender'").run();
  const insufficient = await request("/api/messages/red-envelope", {
    method: "POST", userId: "sender",
    body: { sender_user_id: "sender", receiver_user_id: "receiver", amount: 101 },
  });
  assert.equal(insufficient.status, 409);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM inbox_red_envelopes").get().n, 0);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins, 100);

  sqlite.prepare("UPDATE users SET coins=1000 WHERE id='sender'").run();
  sqlite.prepare("UPDATE user_vip SET active_until=? WHERE user_id='sender'").run(Date.now() - 1);
  const expiredVip = await request("/api/messages/red-envelope", {
    method: "POST", userId: "sender",
    body: { sender_user_id: "sender", receiver_user_id: "receiver", amount: 101 },
  });
  assert.equal(expiredVip.status, 403);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM inbox_red_envelopes").get().n, 0);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='sender'").get().coins, 1000);
  sqlite.close();
});
