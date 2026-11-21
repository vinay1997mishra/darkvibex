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
  const secret = "message-mute-delete-test-secret";
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

async function sendMessage(request, token, senderId, receiverId, text, imageKey) {
  return request("/api/messages/send", {
    method: "POST",
    token,
    body: {
      sender_user_id: senderId,
      receiver_user_id: receiverId,
      text,
      ...(imageKey ? { image_key: imageKey } : {}),
    },
  });
}

async function inboxFor(request, token, userId) {
  return request(`/api/messages/inbox?user_id=${userId}`, { token });
}

// Inbox message mute / delete / unread count (Vinay, 2026-11-21):
// long-press a conversation in the inbox to mute its notifications
// or delete the whole chat. Muting only silences the push — the
// messages still arrive and still count as unread.

test("muting one person flags only that conversation as muted in the inbox", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["user-a", "User A"], ["user-b", "User B"], ["user-c", "User C"]);
  seedMutualFollow(sqlite, "user-a", "user-b");
  seedMutualFollow(sqlite, "user-a", "user-c");
  const tokenA = await sessionToken("user-a", secret);
  const tokenB = await sessionToken("user-b", secret);
  const tokenC = await sessionToken("user-c", secret);

  await sendMessage(request, tokenB, "user-b", "user-a", "hi from B");
  await sendMessage(request, tokenC, "user-c", "user-a", "hi from C");

  const before = await inboxFor(request, tokenA, "user-a");
  assert.equal(before.status, 200);
  assert.equal(before.body.inbox.length, 2);
  assert.equal(before.body.inbox.every((row) => row.muted === false), true);

  const muted = await request("/api/messages/mute-user", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", muted_user_id: "user-b" },
  });
  assert.equal(muted.status, 200);
  assert.deepEqual(muted.body.muted_user_ids, ["user-b"]);

  const list = await request("/api/messages/muted-users?user_id=user-a", { token: tokenA });
  assert.equal(list.status, 200);
  assert.equal(list.body.users.length, 1);
  assert.equal(list.body.users[0].id, "user-b");
  assert.equal(list.body.users[0].display_name, "User B");

  const after = await inboxFor(request, tokenA, "user-a");
  const rowB = after.body.inbox.find((row) => row.id === "user-b");
  const rowC = after.body.inbox.find((row) => row.id === "user-c");
  assert.equal(rowB.muted, true);
  assert.equal(rowC.muted, false);

  const unmuted = await request("/api/messages/unmute-user", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", muted_user_id: "user-b" },
  });
  assert.equal(unmuted.status, 200);
  assert.deepEqual(unmuted.body.muted_user_ids, []);

  const again = await inboxFor(request, tokenA, "user-a");
  assert.equal(again.body.inbox.find((row) => row.id === "user-b").muted, false);
});

test("muted chat still receives messages and counts them unread", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["user-a", "User A"], ["user-b", "User B"]);
  seedMutualFollow(sqlite, "user-a", "user-b");
  const tokenA = await sessionToken("user-a", secret);
  const tokenB = await sessionToken("user-b", secret);

  await request("/api/messages/mute-user", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", muted_user_id: "user-b" },
  });

  const first = await sendMessage(request, tokenB, "user-b", "user-a", "one");
  assert.equal(first.status, 201);
  const second = await sendMessage(request, tokenB, "user-b", "user-a", "two");
  assert.equal(second.status, 201);

  const inbox = await inboxFor(request, tokenA, "user-a");
  assert.equal(inbox.body.inbox.length, 1);
  assert.equal(inbox.body.inbox[0].muted, true);
  assert.equal(inbox.body.inbox[0].unread, 2);

  const thread = await request(
    "/api/messages/thread?user_id=user-a&other_user_id=user-b",
    { token: tokenA },
  );
  assert.equal(thread.status, 200);
  assert.equal(thread.body.messages.length, 2);

  // Opening the thread marks them read, so the inbox count clears —
  // the mute only ever silenced the notification, never the messages.
  const cleared = await inboxFor(request, tokenA, "user-a");
  assert.equal(cleared.body.inbox[0].unread, 0);
  assert.equal(cleared.body.inbox[0].muted, true);
});

test("message push is skipped for muted chats (server-enforced)", async () => {
  // No FCM is configured in tests, so no push can actually be sent.
  // This guards the choke point the same way
  // persisted_session_refresh.test.js guards the session restore:
  // the only place a DM push is sent must consult the mute list.
  const workerSource = readFileSync(
    new URL("../src/index.js", import.meta.url),
    "utf8",
  );
  const start = workerSource.indexOf("async function sendDirectMessagePush");
  const end = workerSource.indexOf("async function ensureCallMuteTables", start);
  assert.ok(start >= 0 && end > start);
  const fn = workerSource.slice(start, end);
  assert.ok(fn.includes("isMessageMutedFor(db, receiverUserId, senderUserId)"));
  // A deleted chat stays gone too: if the receiver deleted this
  // conversation, its new messages get no notification either.
  assert.ok(fn.includes("isConversationHiddenFor(db, receiverUserId, senderUserId)"));
});

test("delete conversation hides it only for the deleter; the other person keeps everything", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["user-a", "User A"], ["user-b", "User B"], ["user-c", "User C"]);
  seedMutualFollow(sqlite, "user-a", "user-b");
  seedMutualFollow(sqlite, "user-a", "user-c");
  const tokenA = await sessionToken("user-a", secret);
  const tokenB = await sessionToken("user-b", secret);
  const tokenC = await sessionToken("user-c", secret);

  await sendMessage(request, tokenB, "user-b", "user-a", "from B");
  await sendMessage(request, tokenA, "user-a", "user-b", "from A");
  await sendMessage(request, tokenB, "user-b", "user-a", "", "messages/user-b/pic.jpg");
  await sendMessage(request, tokenC, "user-c", "user-a", "from C stays");

  const before = await inboxFor(request, tokenA, "user-a");
  assert.equal(before.body.inbox.length, 2);
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM direct_message_images").get().n,
    1,
  );

  // Delete-for-me only: nothing is removed from the server — the
  // deleter just stops seeing the conversation.
  const deleted = await request("/api/messages/conversation/delete", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", other_user_id: "user-b" },
  });
  assert.equal(deleted.status, 200);
  assert.equal(deleted.body.deleted, 3);

  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM direct_messages").get().n,
    4,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM direct_message_images").get().n,
    1,
  );

  const after = await inboxFor(request, tokenA, "user-a");
  assert.equal(after.body.inbox.length, 1);
  assert.equal(after.body.inbox[0].id, "user-c");

  const thread = await request(
    "/api/messages/thread?user_id=user-a&other_user_id=user-b",
    { token: tokenA },
  );
  assert.equal(thread.body.messages.length, 0);

  // The other person is unaffected: their inbox and thread keep
  // every message, including the one they have not read yet.
  const otherInbox = await inboxFor(request, tokenB, "user-b");
  assert.equal(otherInbox.body.inbox.length, 1);
  assert.equal(otherInbox.body.inbox[0].id, "user-a");
  assert.equal(otherInbox.body.inbox[0].unread, 1);

  const otherThread = await request(
    "/api/messages/thread?user_id=user-b&other_user_id=user-a",
    { token: tokenB },
  );
  assert.equal(otherThread.body.messages.length, 3);

  // Deleting an already-hidden conversation with no new messages
  // hides nothing new — it is a no-op, not an error.
  const again = await request("/api/messages/conversation/delete", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", other_user_id: "user-b" },
  });
  assert.equal(again.status, 200);
  assert.equal(again.body.deleted, 0);
});

test("a new message after deletion does not bring the chat back for the deleter", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["user-a", "User A"], ["user-b", "User B"]);
  seedMutualFollow(sqlite, "user-a", "user-b");
  const tokenA = await sessionToken("user-a", secret);
  const tokenB = await sessionToken("user-b", secret);

  await sendMessage(request, tokenB, "user-b", "user-a", "one");
  await sendMessage(request, tokenA, "user-a", "user-b", "two");

  const deleted = await request("/api/messages/conversation/delete", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", other_user_id: "user-b" },
  });
  assert.equal(deleted.status, 200);
  assert.equal(deleted.body.deleted, 2);

  // The new message is stored and delivered, but the chat stays
  // gone for the deleter: no inbox row, no unread count. The flag
  // persists — nothing clears it on an incoming message.
  await new Promise((resolve) => setTimeout(resolve, 5));
  const arrived = await sendMessage(request, tokenB, "user-b", "user-a", "are you there?");
  assert.equal(arrived.status, 201);

  const inbox = await inboxFor(request, tokenA, "user-a");
  assert.equal(inbox.body.inbox.length, 0);

  // Opening the thread directly (e.g. from the profile) shows only
  // the messages sent after the deletion — the deleted ones stay
  // hidden forever.
  const thread = await request(
    "/api/messages/thread?user_id=user-a&other_user_id=user-b",
    { token: tokenA },
  );
  assert.equal(thread.body.messages.length, 1);
  assert.equal(thread.body.messages[0].text, "are you there?");

  // The other person sees the whole conversation, old and new.
  const otherThread = await request(
    "/api/messages/thread?user_id=user-b&other_user_id=user-a",
    { token: tokenB },
  );
  assert.equal(otherThread.body.messages.length, 3);

  // Even the deleter sending a message afterwards does not restore
  // the inbox row — nothing clears the hidden flag.
  const reply = await sendMessage(request, tokenA, "user-a", "user-b", "yes, here");
  assert.equal(reply.status, 201);

  const stillGone = await inboxFor(request, tokenA, "user-a");
  assert.equal(stillGone.body.inbox.length, 0);

  const threadAfterReply = await request(
    "/api/messages/thread?user_id=user-a&other_user_id=user-b",
    { token: tokenA },
  );
  assert.equal(threadAfterReply.body.messages.length, 2);
  assert.equal(threadAfterReply.body.messages[1].text, "yes, here");
});

test("mute and delete validate the caller and the target", async () => {
  const { sqlite, request, secret } = await fixture();
  seedUsers(sqlite, ["user-a", "User A"], ["user-b", "User B"]);
  seedMutualFollow(sqlite, "user-a", "user-b");
  const tokenA = await sessionToken("user-a", secret);
  const tokenB = await sessionToken("user-b", secret);

  // No session at all.
  const noAuth = await request("/api/messages/mute-user", {
    method: "POST",
    body: { user_id: "user-a", muted_user_id: "user-b" },
  });
  assert.equal(noAuth.status, 401);

  const noAuthDelete = await request("/api/messages/conversation/delete", {
    method: "POST",
    body: { user_id: "user-a", other_user_id: "user-b" },
  });
  assert.equal(noAuthDelete.status, 401);

  // Another user's session cannot mute or delete for user-a:
  // requireSession answers 403 forbidden for a mismatched user.
  const wrongUser = await request("/api/messages/mute-user", {
    method: "POST",
    token: tokenB,
    body: { user_id: "user-a", muted_user_id: "user-b" },
  });
  assert.equal(wrongUser.status, 403);
  assert.equal(wrongUser.body.error, "forbidden");

  const wrongUserDelete = await request("/api/messages/conversation/delete", {
    method: "POST",
    token: tokenB,
    body: { user_id: "user-a", other_user_id: "user-b" },
  });
  assert.equal(wrongUserDelete.status, 403);
  assert.equal(wrongUserDelete.body.error, "forbidden");

  // Cannot mute or delete yourself; missing target is rejected.
  const selfMute = await request("/api/messages/mute-user", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", muted_user_id: "user-a" },
  });
  assert.equal(selfMute.status, 400);
  assert.equal(selfMute.body.error, "invalid_mute_target");

  const selfDelete = await request("/api/messages/conversation/delete", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a", other_user_id: "user-a" },
  });
  assert.equal(selfDelete.status, 400);
  assert.equal(selfDelete.body.error, "invalid_conversation");

  const missingDelete = await request("/api/messages/conversation/delete", {
    method: "POST",
    token: tokenA,
    body: { user_id: "user-a" },
  });
  assert.equal(missingDelete.status, 400);
});
