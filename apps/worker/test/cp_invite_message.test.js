// CP invite message + pop-up (Vinay, 2026-11-20): a CP request writes a
// PERMANENT cp_invite DM to the target (Accept/Reject on it), the pop-up
// reads the pending CP row, and Accept/Reject can be chosen only ONCE per
// invite — the DM keeps its verdict forever; a re-invite writes a new DM.
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
  const secret = "cp-invite-message-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, ALLOW_GUEST_SESSIONS: true, FILES: files };
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
async function makeUser(fx, userId, { coins = 50000000, vipLevel = 0, country = "IN" } = {}) {
  const { sqlite, request } = fx;
  const created = await request("/api/session/guest", { method: "POST", body: { user_id: userId, display_name: userId } });
  assert.equal(created.status, 200, JSON.stringify(created.body));
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

function makeMutualFriends(fx, a, b) {
  const now = Date.now();
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(a, b, now);
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(b, a, now);
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

async function thread(fx, userId, otherId) {
  return fx.request(`/api/messages/thread?user_id=${userId}&other_user_id=${otherId}`, { userId });
}

function inviteMessages(fx, from, to) {
  return fx.sqlite.prepare(
    "SELECT * FROM direct_messages WHERE sender_user_id=? AND receiver_user_id=? AND kind LIKE 'cp_invite%' ORDER BY created_at ASC"
  ).all(from, to);
}

test("CP request writes a permanent cp_invite DM to the target", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a");
  await makeUser(fx, "cp-b");
  makeMutualFriends(fx, "cp-a", "cp-b");
  const result = await cpRequest(fx, "cp-a", "cp-b");
  assert.equal(result.status, 201, JSON.stringify(result.body));

  const rows = inviteMessages(fx, "cp-a", "cp-b");
  assert.equal(rows.length, 1, "exactly one invite DM must exist");
  assert.equal(rows[0].kind, "cp_invite");
  assert.ok(String(rows[0].text).includes("CP invite from cp-a"), rows[0].text);

  // The thread endpoint returns the kind so the app can render the card.
  const threadResult = await thread(fx, "cp-b", "cp-a");
  assert.equal(threadResult.status, 200, JSON.stringify(threadResult.body));
  const invite = (threadResult.body.messages ?? []).find((row) => row.kind === "cp_invite");
  assert.ok(invite, "thread must carry the cp_invite message");
  assert.equal(invite.sender_user_id, "cp-a");

  // The inbox preview shows the invite text.
  const inbox = await fx.request("/api/messages/inbox?user_id=cp-b", { userId: "cp-b" });
  assert.equal(inbox.status, 200, JSON.stringify(inbox.body));
  const convo = (inbox.body.inbox ?? []).find((row) => row.id === "cp-a");
  assert.ok(convo, "inbox must list the conversation");
  assert.ok(String(convo.preview).includes("CP invite"), convo.preview);
});

test("Accepting marks the invite DM accepted and it can never be chosen again", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a");
  await makeUser(fx, "cp-b");
  makeMutualFriends(fx, "cp-a", "cp-b");
  assert.equal((await cpRequest(fx, "cp-a", "cp-b")).status, 201);

  const accepted = await cpRespond(fx, "cp-b", true);
  assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
  assert.equal(accepted.body.cp?.state, "active");
  const rows = inviteMessages(fx, "cp-a", "cp-b");
  assert.equal(rows.length, 1);
  assert.equal(rows[0].kind, "cp_invite_accepted");

  // Choose-once: a second respond fails — the invite is decided.
  const again = await cpRespond(fx, "cp-b", true);
  assert.equal(again.status, 400, JSON.stringify(again.body));
  assert.equal(again.body.error, "cp_request_not_found");
  assert.equal(inviteMessages(fx, "cp-a", "cp-b")[0].kind, "cp_invite_accepted");
});

test("Rejecting marks the invite DM rejected and keeps the 20M (no refund)", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a");
  await makeUser(fx, "cp-b");
  makeMutualFriends(fx, "cp-a", "cp-b");
  assert.equal((await cpRequest(fx, "cp-a", "cp-b")).status, 201);

  const rejected = await cpRespond(fx, "cp-b", false);
  assert.equal(rejected.status, 200, JSON.stringify(rejected.body));
  const rows = inviteMessages(fx, "cp-a", "cp-b");
  assert.equal(rows.length, 1);
  assert.equal(rows[0].kind, "cp_invite_rejected");
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("cp-a").coins, 30000000);

  const again = await cpRespond(fx, "cp-b", false);
  assert.equal(again.status, 400, JSON.stringify(again.body));
  assert.equal(again.body.error, "cp_request_not_found");
});

test("A re-invite after a reject writes a fresh DM; the old one stays rejected", async () => {
  const fx = await fixture();
  await makeUser(fx, "cp-a", { coins: 70000000 });
  await makeUser(fx, "cp-b");
  makeMutualFriends(fx, "cp-a", "cp-b");
  assert.equal((await cpRequest(fx, "cp-a", "cp-b")).status, 201);
  assert.equal((await cpRespond(fx, "cp-b", false)).status, 200);
  assert.equal((await cpRequest(fx, "cp-a", "cp-b")).status, 201);

  const rows = inviteMessages(fx, "cp-a", "cp-b");
  assert.equal(rows.length, 2, "old rejected invite + new live invite");
  assert.equal(rows[0].kind, "cp_invite_rejected");
  assert.equal(rows[1].kind, "cp_invite");
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("cp-a").coins, 30000000);
});
