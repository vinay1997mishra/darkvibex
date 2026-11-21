// DM gift (Vinay, 2026-11-21): pic and gift both send from inside the
// 1-to-1 DM chat. A gift sent with no room_id is a DM gift: it needs the
// same mutual-follow rule as a DM message, and it writes a kind='gift' DM
// row (same pattern as the red-envelope DM row) so the gift shows in the
// thread and the inbox for both sides. Room gifts write no DM row.
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
  const secret = "dm-gift-test-secret";
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

let publicIdCounter = 7670000;
async function makeUser(fx, userId, { coins = 50000000, vipLevel = 0, country = "IN" } = {}) {
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

function makeMutualFriends(fx, a, b) {
  const now = Date.now();
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(a, b, now);
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run(b, a, now);
}

async function sendGift(fx, from, to, { roomId, giftId = "basic-star", coinCost = 5000 } = {}) {
  const body = { sender_user_id: from, receiver_user_id: to, gift_id: giftId, coin_cost: coinCost };
  if (roomId != null) body.room_id = roomId;
  return fx.request("/api/gifts/send", { method: "POST", userId: from, body });
}

async function thread(fx, userId, otherId) {
  return fx.request(`/api/messages/thread?user_id=${userId}&other_user_id=${otherId}`, { userId });
}

function giftMessages(fx, from, to) {
  return fx.sqlite.prepare(
    "SELECT * FROM direct_messages WHERE sender_user_id=? AND receiver_user_id=? AND kind='gift' ORDER BY created_at ASC"
  ).all(from, to);
}

test("DM gift between mutual friends writes a kind='gift' DM row visible to both sides", async () => {
  const fx = await fixture();
  await makeUser(fx, "dm-a");
  await makeUser(fx, "dm-b");
  makeMutualFriends(fx, "dm-a", "dm-b");

  const result = await sendGift(fx, "dm-a", "dm-b");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);

  // Money moves exactly like a room gift: debit + diamonds at full cost.
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("dm-a").coins, 50000000 - 5000);
  assert.equal(fx.sqlite.prepare("SELECT diamonds FROM users WHERE id=?").get("dm-b").diamonds, 5000);

  // The gift event has no room.
  const events = fx.sqlite.prepare("SELECT * FROM gift_events WHERE sender_user_id=? AND receiver_user_id=?").all("dm-a", "dm-b");
  assert.equal(events.length, 1);
  assert.equal(events[0].room_id, null);
  assert.equal(events[0].gift_id, "basic-star");

  // Exactly one gift DM row, carrying the gift name and cost.
  const rows = giftMessages(fx, "dm-a", "dm-b");
  assert.equal(rows.length, 1, "exactly one gift DM must exist");
  assert.equal(rows[0].kind, "gift");
  assert.ok(String(rows[0].text).includes("Star"), rows[0].text);
  assert.ok(String(rows[0].text).includes("5000"), rows[0].text);

  // Both sides see the gift in the thread.
  for (const viewer of ["dm-a", "dm-b"]) {
    const other = viewer === "dm-a" ? "dm-b" : "dm-a";
    const threadResult = await thread(fx, viewer, other);
    assert.equal(threadResult.status, 200, JSON.stringify(threadResult.body));
    const gift = (threadResult.body.messages ?? []).find((row) => row.kind === "gift");
    assert.ok(gift, `thread for ${viewer} must carry the gift message`);
    assert.equal(gift.sender_user_id, "dm-a");
  }

  // The receiver's inbox previews the gift.
  const inbox = await fx.request("/api/messages/inbox?user_id=dm-b", { userId: "dm-b" });
  assert.equal(inbox.status, 200, JSON.stringify(inbox.body));
  const convo = (inbox.body.inbox ?? []).find((row) => row.id === "dm-a");
  assert.ok(convo, "inbox must list the conversation");
  assert.ok(String(convo.preview).includes("Star"), convo.preview);
});

test("DM gift to a non-friend is rejected with friends_required and writes nothing", async () => {
  const fx = await fixture();
  await makeUser(fx, "dm-a");
  await makeUser(fx, "dm-b");
  // No mutual follow: only a one-way follow.
  fx.sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("dm-a", "dm-b", Date.now());

  const result = await sendGift(fx, "dm-a", "dm-b");
  assert.equal(result.status, 403, JSON.stringify(result.body));
  assert.equal(result.body.error, "friends_required");

  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events").get().n, 0);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM direct_messages").get().n, 0);
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("dm-a").coins, 50000000);
});

test("Room gift writes no DM row", async () => {
  const fx = await fixture();
  await makeUser(fx, "dm-a");
  await makeUser(fx, "dm-b");
  const now = Date.now();
  fx.sqlite.prepare("INSERT INTO rooms(id,owner_user_id,name,created_at,updated_at) VALUES(?,?,?,?,?)").run("room-1", "dm-a", "Room 1", now, now);
  fx.sqlite.prepare("INSERT INTO room_members(room_id,user_id,joined_at,updated_at) VALUES(?,?,?,?)").run("room-1", "dm-a", now, now);
  fx.sqlite.prepare("INSERT INTO room_members(room_id,user_id,joined_at,updated_at) VALUES(?,?,?,?)").run("room-1", "dm-b", now, now);

  const result = await sendGift(fx, "dm-a", "dm-b", { roomId: "room-1" });
  assert.equal(result.status, 200, JSON.stringify(result.body));

  const events = fx.sqlite.prepare("SELECT * FROM gift_events WHERE sender_user_id=? AND receiver_user_id=?").all("dm-a", "dm-b");
  assert.equal(events.length, 1);
  assert.equal(events[0].room_id, "room-1");
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM direct_messages").get().n, 0);
});

test("room-less self-gift still works (self-gifting stays allowed)", async () => {
  const fx = await fixture();
  await makeUser(fx, "dm-a");

  const result = await sendGift(fx, "dm-a", "dm-a");
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.ok, true);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events").get().n, 1);
  assert.equal(giftMessages(fx, "dm-a", "dm-a").length, 1);
});

test("DM gift with insufficient coins fails and writes no DM row", async () => {
  const fx = await fixture();
  await makeUser(fx, "dm-a", { coins: 100 });
  await makeUser(fx, "dm-b");
  makeMutualFriends(fx, "dm-a", "dm-b");

  const result = await sendGift(fx, "dm-a", "dm-b");
  assert.equal(result.status, 409, JSON.stringify(result.body));
  assert.equal(result.body.error, "insufficient_coins");

  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events").get().n, 0);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM direct_messages").get().n, 0);
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get("dm-a").coins, 100);
});
