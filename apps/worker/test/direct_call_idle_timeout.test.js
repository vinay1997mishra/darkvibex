// Direct calls — active-call idle timeout (audit 2026-11-22).
// Before this fix an `active` call whose apps both died stayed
// `active` until the 45-day D1 retention delete, and the start
// route's user_busy check (state IN ringing/active) locked BOTH users
// out of every new call. Now the call screen's 2s status poll is a
// heartbeat (updated_at), expireDirectCalls ends an active call idle
// for 5 minutes, and the 5-minute cron runs the expiry even when
// nobody hits a call route.
import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
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
async function sessionToken(userId, secret, provider = "google") {
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: userId, exp: Math.floor(Date.now() / 1000) + 3600, provider })}`;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "direct-call-idle-timeout-test-secret";
  const env = {
    DB, SESSION_SECRET: secret,
    // Fake-but-valid-shaped Agora credentials so the token endpoint
    // gets past its 503 voice_not_configured check and reaches the
    // membership check (the token itself is pure HMAC, no network).
    AGORA_APP_ID: "0123456789abcdef0123456789abcdef",
    AGORA_APP_CERTIFICATE: "abcdef0123456789abcdef0123456789",
  };
  async function request(path, { method = "GET", body, token } = {}) {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (token) headers.set("authorization", `Bearer ${token}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  }
  const ts = Date.now();
  const insert = sqlite.prepare("INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES(?,?,?,?,?)");
  insert.run("caller", "Caller", 100000000, ts, ts);
  insert.run("receiver", "Receiver", 1000000, ts, ts);
  const follow = sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)");
  follow.run("caller", "receiver", ts);
  follow.run("receiver", "caller", ts);
  const callerToken = await sessionToken("caller", secret);
  const receiverToken = await sessionToken("receiver", secret);
  return { sqlite, request, callerToken, receiverToken };
}

async function startAndAcceptCall({ request, callerToken, receiverToken }) {
  const started = await request("/api/calls/start", {
    method: "POST", token: callerToken,
    body: { user_id: "caller", receiver_user_id: "receiver" },
  });
  assert.equal(started.status, 201);
  const callId = started.body.call.id;
  const accepted = await request("/api/calls/respond", {
    method: "POST", token: receiverToken,
    body: { user_id: "receiver", call_id: callId, accept: true },
  });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.call.state, "active");
  return callId;
}

test("an active call idle for 6 minutes is ended, and both users can call again", async () => {
  const { sqlite, request, callerToken, receiverToken } = await fixture();
  const callId = await startAndAcceptCall({ request, callerToken, receiverToken });
  // Simulate 10 live minutes already billed, then both apps go quiet
  // for 6 minutes: the last poll was 6 minutes ago.
  const now = Date.now();
  sqlite.prepare(
    "UPDATE direct_calls SET answered_at=?,billed_minutes=10,caller_cost_coins=4000000,updated_at=? WHERE id=?"
  ).run(now - 10 * 60 * 1000, now - 6 * 60 * 1000, callId);

  const status = await request(`/api/calls/status?user_id=caller&call_id=${callId}`, { token: callerToken });
  assert.equal(status.status, 200);
  assert.equal(status.body.call.state, "ended");
  assert.equal(status.body.call.end_reason, "idle_timeout");

  // The idle minutes were never billed: the caller paid only for the
  // 10 live minutes, and the balance did not move on expiry.
  const row = sqlite.prepare("SELECT * FROM direct_calls WHERE id=?").get(callId);
  assert.equal(row.billed_minutes, 10);
  assert.equal(row.caller_cost_coins, 4000000);
  assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='caller'").get().coins, 100000000 - 400000);

  // The lock is gone: a fresh call starts instead of 409 user_busy.
  const again = await request("/api/calls/start", {
    method: "POST", token: callerToken,
    body: { user_id: "caller", receiver_user_id: "receiver" },
  });
  assert.equal(again.status, 201);
  assert.equal(again.body.call.state, "ringing");
  sqlite.close();
});

test("a live active call stays active and the status poll refreshes updated_at", async () => {
  const { sqlite, request, callerToken, receiverToken } = await fixture();
  const callId = await startAndAcceptCall({ request, callerToken, receiverToken });
  const before = sqlite.prepare("SELECT updated_at FROM direct_calls WHERE id=?").get(callId).updated_at;
  // Age the heartbeat by 2 minutes — still inside the 5-minute
  // window — then poll: the call must survive and the poll must
  // refresh updated_at to ~now.
  sqlite.prepare("UPDATE direct_calls SET updated_at=? WHERE id=?").run(Date.now() - 2 * 60 * 1000, callId);
  const status = await request(`/api/calls/status?user_id=caller&call_id=${callId}`, { token: callerToken });
  assert.equal(status.status, 200);
  assert.equal(status.body.call.state, "active");
  const after = sqlite.prepare("SELECT updated_at FROM direct_calls WHERE id=?").get(callId).updated_at;
  assert.ok(after >= before, `heartbeat did not refresh updated_at: ${before} -> ${after}`);
  assert.ok(Date.now() - after < 5000, "updated_at was not refreshed to now");
  sqlite.close();
});

test("an idle active call no longer mints Agora tokens for the dead channel", async () => {
  const { sqlite, request, callerToken, receiverToken } = await fixture();
  const callId = await startAndAcceptCall({ request, callerToken, receiverToken });
  // While the call is live, the token endpoint mints a token.
  const live = await request("/agora/token", {
    method: "POST", token: callerToken,
    body: { room_id: `call-${callId}`, room_type: "call" },
  });
  assert.equal(live.status, 200);
  assert.equal(live.body.ok, true);
  assert.ok(live.body.token);
  // Both apps go quiet for 6 minutes: the call is orphaned, and the
  // token endpoint expires it before its membership check, so no
  // token can be minted for the dead channel any more.
  sqlite.prepare("UPDATE direct_calls SET updated_at=? WHERE id=?").run(Date.now() - 6 * 60 * 1000, callId);
  const dead = await request("/agora/token", {
    method: "POST", token: callerToken,
    body: { room_id: `call-${callId}`, room_type: "call" },
  });
  assert.equal(dead.status, 403);
  assert.equal(dead.body.error, "room_membership_required");
  sqlite.close();
});

test("the 5-minute cron runs the call expiry (source assertion)", () => {
  const index = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  assert.match(index, /DIRECT_CALL_IDLE_TIMEOUT_MS = 5 \* 60 \* 1000/);
  assert.match(index, /UPDATE direct_calls SET state='ended',ended_at=\?,end_reason='idle_timeout',updated_at=\? WHERE state='active' AND updated_at<\?/);
  assert.match(index, /async scheduled\(_controller, env, ctx\) \{[\s\S]*?expireDirectCallsAndNotify\(env, requireDb\(env\)\)/);
});
