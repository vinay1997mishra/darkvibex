// Gift combo count (Vinay, 2026-11-21): the gift box offers 1/7/77/177/777/7777
// copies in one send. The server debits the total (unit cost x count) and
// records ONE gift event with coin_cost = total and count = count, so the
// Rocket total, ranking and diamonds all follow the total while the room
// plays a single "xN" animation. The combo button re-sends the same batch
// (users x count) as many times as the user wants inside the 5s window.
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
  const secret = "gift-combo-test-secret";
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

async function makeRoom(fx, ownerId) {
  const created = await fx.request("/api/rooms", {
    method: "POST",
    userId: ownerId,
    body: { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12 },
  });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return String(created.body.room_id);
}

async function joinRoom(fx, roomId, userId) {
  const joined = await fx.request(`/api/rooms/${roomId}/join`, { method: "POST", userId, body: { user_id: userId, display_name: userId } });
  assert.equal(joined.status, 200, JSON.stringify(joined.body));
  return joined;
}

async function sendGift(fx, roomId, senderId, receiverId, { giftId = "rose", count } = {}) {
  const body = { sender_user_id: senderId, receiver_user_id: receiverId, gift_id: giftId, room_id: roomId };
  if (count != null) body.count = count;
  return fx.request("/api/gifts/send", { method: "POST", userId: senderId, body });
}

function wallet(fx, userId) {
  return fx.sqlite.prepare("SELECT coins, diamonds FROM users WHERE id=?").get(userId);
}

test("combo count sends N copies in one event and charges the total", async () => {
  const fx = await fixture();
  await makeUser(fx, "combo-sender", { coins: 100000 });
  await makeUser(fx, "combo-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "combo-sender");
  await joinRoom(fx, roomId, "combo-sender");
  await joinRoom(fx, roomId, "combo-receiver");

  const sent = await sendGift(fx, roomId, "combo-sender", "combo-receiver", { giftId: "rose", count: 7 });
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.ok, true);
  assert.equal(sent.body.gift_count, 7);
  const unit = Number(sent.body.gift_cost);
  assert.ok(unit > 0);
  assert.equal(sent.body.gift_total_cost, unit * 7);

  // One event, coin_cost = total, count = 7 — not 7 separate events.
  const events = fx.sqlite.prepare("SELECT coin_cost, count FROM gift_events WHERE room_id=?").all(roomId);
  assert.equal(events.length, 1);
  assert.equal(events[0].coin_cost, unit * 7);
  assert.equal(events[0].count, 7);

  // Sender paid the total once; receiver got the total in diamonds.
  assert.equal(wallet(fx, "combo-sender").coins, 100000 - unit * 7);
  assert.equal(wallet(fx, "combo-receiver").diamonds, unit * 7);
  const ledger = fx.sqlite.prepare("SELECT amount FROM wallet_ledger WHERE user_id=? AND kind='gift_sent'").all("combo-sender");
  assert.equal(ledger.length, 1);
  assert.equal(ledger[0].amount, -unit * 7);
});

test("combo count defaults to 1 and clamps to 7777", async () => {
  const fx = await fixture();
  await makeUser(fx, "combo-sender", { coins: 100000000 });
  await makeUser(fx, "combo-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "combo-sender");
  await joinRoom(fx, roomId, "combo-sender");
  await joinRoom(fx, roomId, "combo-receiver");

  const plain = await sendGift(fx, roomId, "combo-sender", "combo-receiver", { giftId: "rose" });
  assert.equal(plain.body.gift_count, 1);
  assert.equal(plain.body.gift_total_cost, Number(plain.body.gift_cost));

  const huge = await sendGift(fx, roomId, "combo-sender", "combo-receiver", { giftId: "rose", count: 99999 });
  assert.equal(huge.body.gift_count, 7777);
  assert.equal(huge.body.gift_total_cost, Number(huge.body.gift_cost) * 7777);
});

test("combo send fails when the wallet cannot afford the whole total", async () => {
  const fx = await fixture();
  await makeUser(fx, "combo-sender", { coins: 500 });
  await makeUser(fx, "combo-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "combo-sender");
  await joinRoom(fx, roomId, "combo-sender");
  await joinRoom(fx, roomId, "combo-receiver");

  const sent = await sendGift(fx, roomId, "combo-sender", "combo-receiver", { giftId: "rose", count: 7 });
  assert.equal(sent.body.ok, false);
  assert.equal(sent.body.error, "insufficient_coins");
  // Nothing was written: no event, no debit, no diamonds.
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM gift_events WHERE room_id=?").get(roomId).n, 0);
  assert.equal(wallet(fx, "combo-sender").coins, 500);
  assert.equal(wallet(fx, "combo-receiver").diamonds, 0);
});

test("room gift-events feed returns the combo count", async () => {
  const fx = await fixture();
  await makeUser(fx, "combo-sender", { coins: 100000 });
  await makeUser(fx, "combo-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "combo-sender");
  await joinRoom(fx, roomId, "combo-sender");
  await joinRoom(fx, roomId, "combo-receiver");

  const sent = await sendGift(fx, roomId, "combo-sender", "combo-receiver", { giftId: "rose", count: 7 });
  assert.equal(sent.body.ok, true);
  const feed = await fx.request(`/api/rooms/${roomId}/gift-events`, { userId: "combo-receiver" });
  assert.equal(feed.status, 200, JSON.stringify(feed.body));
  assert.equal(feed.body.events.length, 1);
  assert.equal(feed.body.events[0].count, 7);
  assert.equal(feed.body.events[0].coin_cost, Number(sent.body.gift_cost) * 7);
});
