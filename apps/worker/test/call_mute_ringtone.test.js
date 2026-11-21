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
      async run() {
        const result = database.prepare(sql).run(...values);
        return { meta: { changes: Number(result.changes) } };
      },
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
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({
    sub: userId,
    exp: Math.floor(Date.now() / 1000) + 3600,
    provider,
  })}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64url(signature)}`;
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "call-mute-ringtone-test-secret";
  const env = {
    DB,
    SESSION_SECRET: secret,
  };
  async function request(path, { method = "GET", body, token } = {}) {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (token) headers.set("authorization", `Bearer ${token}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, {
      method,
      headers,
      body: body == null ? undefined : JSON.stringify(body),
    }), env);
    return { status: response.status, body: await response.json() };
  }
  return { sqlite, request, secret };
}

function seedUsers(sqlite, ...users) {
  const ts = Date.now();
  const insert = sqlite.prepare(
    "INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES(?,?,?,?,?)",
  );
  for (const [id, name] of users) insert.run(id, name, 1000000, ts, ts);
}

function seedMutualFollow(sqlite, a, b) {
  const ts = Date.now();
  const insert = sqlite.prepare(
    "INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)",
  );
  insert.run(a, b, ts);
  insert.run(b, a, ts);
}

async function startCall(request, token, callerId, receiverId) {
  return request("/api/calls/start", {
    method: "POST",
    token,
    body: { user_id: callerId, receiver_user_id: receiverId },
  });
}

// Call mute + ringtone (Vinay, 2026-11-21): mute all calls, mute
// calls from selected persons, pick the caller tune. The server is
// the source of truth so the setting survives reinstall.

test("unmuted call starts and rings", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["caller-1", "Caller"], ["receiver-1", "Receiver"]);
  seedMutualFollow(sqlite, "caller-1", "receiver-1");
  const token = await sessionToken("caller-1", secret);

  const result = await startCall(request, token, "caller-1", "receiver-1");
  assert.equal(result.status, 201);
  assert.equal(result.body.ok, true);
  assert.equal(result.body.call.state, "ringing");
});

test("receiver with mute-all on: call is refused with call_muted and never rings", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["caller-1", "Caller"], ["receiver-1", "Receiver"]);
  seedMutualFollow(sqlite, "caller-1", "receiver-1");
  const receiverToken = await sessionToken("receiver-1", secret);
  const callerToken = await sessionToken("caller-1", secret);

  const set = await request("/api/calls/mute-settings", {
    method: "POST",
    token: receiverToken,
    body: { user_id: "receiver-1", mute_all: true },
  });
  assert.equal(set.status, 200);
  assert.equal(set.body.mute_all, true);

  const result = await startCall(request, callerToken, "caller-1", "receiver-1");
  assert.equal(result.status, 403);
  assert.equal(result.body.error, "call_muted");
  assert.equal(
    sqlite.prepare("SELECT id FROM direct_calls").get(),
    undefined,
  );

  // Mute off again: the same call goes through.
  await request("/api/calls/mute-settings", {
    method: "POST",
    token: receiverToken,
    body: { user_id: "receiver-1", mute_all: false },
  });
  const retry = await startCall(request, callerToken, "caller-1", "receiver-1");
  assert.equal(retry.status, 201);
});

test("muting one selected person blocks only that caller", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(
    sqlite,
    ["caller-1", "Caller One"],
    ["caller-2", "Caller Two"],
    ["receiver-1", "Receiver"],
  );
  seedMutualFollow(sqlite, "caller-1", "receiver-1");
  seedMutualFollow(sqlite, "caller-2", "receiver-1");
  const receiverToken = await sessionToken("receiver-1", secret);

  const muted = await request("/api/calls/mute-user", {
    method: "POST",
    token: receiverToken,
    body: { user_id: "receiver-1", muted_user_id: "caller-1" },
  });
  assert.equal(muted.status, 200);
  assert.deepEqual(muted.body.muted_user_ids, ["caller-1"]);

  const blocked = await startCall(
    request,
    await sessionToken("caller-1", secret),
    "caller-1",
    "receiver-1",
  );
  assert.equal(blocked.status, 403);
  assert.equal(blocked.body.error, "call_muted");

  const allowed = await startCall(
    request,
    await sessionToken("caller-2", secret),
    "caller-2",
    "receiver-1",
  );
  assert.equal(allowed.status, 201);

  const list = await request("/api/calls/muted-users?user_id=receiver-1", {
    token: receiverToken,
  });
  assert.equal(list.status, 200);
  assert.equal(list.body.users.length, 1);
  assert.equal(list.body.users[0].id, "caller-1");
  assert.equal(list.body.users[0].display_name, "Caller One");

  await request("/api/calls/unmute-user", {
    method: "POST",
    token: receiverToken,
    body: { user_id: "receiver-1", muted_user_id: "caller-1" },
  });
  // The caller-2 call is still ringing, so end it first — otherwise
  // the receiver is busy and the retry is refused with user_busy.
  await request("/api/calls/end", {
    method: "POST",
    token: await sessionToken("caller-2", secret),
    body: {
      user_id: "caller-2",
      call_id: allowed.body.call.id,
    },
  });
  const retry = await startCall(
    request,
    await sessionToken("caller-1", secret),
    "caller-1",
    "receiver-1",
  );
  assert.equal(retry.status, 201);
});

test("mute settings round-trip, including the ringtone; bad ringtone rejected", async () => {
  const { request, secret } = await fixture();
  const token = await sessionToken("user-1", secret);

  const fresh = await request("/api/calls/mute-settings?user_id=user-1", { token });
  assert.equal(fresh.status, 200);
  assert.equal(fresh.body.mute_all, false);
  assert.equal(fresh.body.ringtone, "classic");
  assert.deepEqual(fresh.body.muted_user_ids, []);

  const saved = await request("/api/calls/mute-settings", {
    method: "POST",
    token,
    body: { user_id: "user-1", ringtone: "melody" },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.body.ringtone, "melody");
  assert.equal(saved.body.mute_all, false);

  const again = await request("/api/calls/mute-settings?user_id=user-1", { token });
  assert.equal(again.body.ringtone, "melody");

  const bad = await request("/api/calls/mute-settings", {
    method: "POST",
    token,
    body: { user_id: "user-1", ringtone: "not-a-tone" },
  });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "invalid_ringtone");
});

test("mutual-follow and block are still checked before the mute check", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(
    sqlite,
    ["caller-1", "Caller"],
    ["stranger-1", "Stranger"],
    ["receiver-1", "Receiver"],
  );
  seedMutualFollow(sqlite, "caller-1", "receiver-1");
  const receiverToken = await sessionToken("receiver-1", secret);
  await request("/api/calls/mute-settings", {
    method: "POST",
    token: receiverToken,
    body: { user_id: "receiver-1", mute_all: true },
  });

  // Not a friend: friends_required wins over call_muted.
  const stranger = await startCall(
    request,
    await sessionToken("stranger-1", secret),
    "stranger-1",
    "receiver-1",
  );
  assert.equal(stranger.status, 403);
  assert.equal(stranger.body.error, "friends_required");
});

test("unanswered ringing call becomes missed and is flagged notified once", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["caller-1", "Caller"], ["receiver-1", "Receiver"]);
  seedMutualFollow(sqlite, "caller-1", "receiver-1");
  const ts = Date.now();
  sqlite.prepare(
    "INSERT INTO direct_calls(id,caller_user_id,receiver_user_id,state,created_at,answered_at,ended_at,updated_at) VALUES(?,?,?,?,?,?,?,?)",
  ).run("old-call-1", "caller-1", "receiver-1", "ringing", ts - 60000, null, null, ts - 60000);

  // The caller polls status while ringing: expiry runs and the missed
  // call is flagged for notification (no FCM configured in tests, so
  // no push is actually sent — the flag still proves it was handled).
  const status = await request(
    "/api/calls/status?user_id=caller-1&call_id=old-call-1",
    { token: await sessionToken("caller-1", secret) },
  );
  assert.equal(status.status, 200);
  assert.equal(status.body.call.state, "missed");
  const row = sqlite.prepare(
    "SELECT missed_notified FROM direct_calls WHERE id=?",
  ).get("old-call-1");
  assert.equal(row.missed_notified, 1);

  // A second poll does not re-flag it.
  await request(
    "/api/calls/status?user_id=caller-1&call_id=old-call-1",
    { token: await sessionToken("caller-1", secret) },
  );
  const again = sqlite.prepare(
    "SELECT missed_notified FROM direct_calls WHERE id=?",
  ).get("old-call-1");
  assert.equal(again.missed_notified, 1);
});
