// Lucky win (Vinay, 2026-11-22): a Lucky gift may win the SENDER a
// multiple of the gift cost in in-app coins. ONE shared chance table for
// ALL Lucky gifts — 0x (no win) 35%, 1x ~50%, up to 1000x = 1 in 15,000.
// Expected return ~2.0x the gift cost. Jackpots are random, never fixed
// to one person. Combo and Lucky Win are SEPARATE: the combo only sets
// the quantity; the win is one roll per gift event, on that event's
// total cost. The receiver still gets diamonds as usual, and the win
// does NOT inflate the Rocket total or ranking (those follow coin_cost).
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import { LUCKY_WIN_TABLE, rollLuckyWinMultiplier } from "../src/gift_catalog.js";

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
  const secret = "lucky-win-test-secret";
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

async function sendGift(fx, roomId, senderId, receiverId, { giftId = "glass-rose", count } = {}) {
  const body = { sender_user_id: senderId, receiver_user_id: receiverId, gift_id: giftId, room_id: roomId };
  if (count != null) body.count = count;
  return fx.request("/api/gifts/send", { method: "POST", userId: senderId, body });
}

function wallet(fx, userId) {
  return fx.sqlite.prepare("SELECT coins, diamonds FROM users WHERE id=?").get(userId);
}

const MULTIPLIERS = new Set(LUCKY_WIN_TABLE.map((entry) => entry.multiplier));

test("Lucky win table: 30 entries, chances sum to ~1, EV ~2.0x", () => {
  assert.equal(LUCKY_WIN_TABLE.length, 30);
  const sum = LUCKY_WIN_TABLE.reduce((total, entry) => total + entry.chance, 0);
  assert.ok(Math.abs(sum - 1) < 1e-6, `chances sum to ${sum}, expected ~1`);
  const ev = LUCKY_WIN_TABLE.reduce((total, entry) => total + entry.multiplier * entry.chance, 0);
  assert.ok(Math.abs(ev - 1.995) < 0.01, `expected return ${ev}x, expected ~1.995x`);
  // Vinay's numbers: no win 35%, 1x ~50%, 1000x = 1 in 15,000.
  const byMultiplier = new Map(LUCKY_WIN_TABLE.map((entry) => [entry.multiplier, entry.chance]));
  assert.equal(byMultiplier.get(0), 0.35);
  assert.ok(Math.abs(byMultiplier.get(1) - 0.5) < 0.001);
  assert.ok(Math.abs(byMultiplier.get(1000) - 1 / 15000) < 1e-6);
  assert.ok(Math.abs(byMultiplier.get(500) - 1 / 10000) < 1e-9);
  assert.ok(Math.abs(byMultiplier.get(750) - 1 / 12500) < 1e-9);
  // Tail is strictly monotonic: a bigger multiplier is never more likely.
  // (The 0x no-win bucket is separate — 1x is likelier than 0x by design:
  // Vinay set no-win 35% and 1x ~50%.)
  for (let i = 2; i < LUCKY_WIN_TABLE.length; i += 1) {
    assert.ok(
      LUCKY_WIN_TABLE[i].chance <= LUCKY_WIN_TABLE[i - 1].chance,
      `${LUCKY_WIN_TABLE[i].multiplier}x (${LUCKY_WIN_TABLE[i].chance}) is likelier than ${LUCKY_WIN_TABLE[i - 1].multiplier}x`,
    );
  }
});

test("rollLuckyWinMultiplier is deterministic for a given roll", () => {
  assert.equal(rollLuckyWinMultiplier(() => 0), 0);
  assert.equal(rollLuckyWinMultiplier(() => 0.34), 0);
  // 0.35 is the exact 0x/1x boundary: the 0x bucket is [0, 0.35).
  assert.equal(rollLuckyWinMultiplier(() => 0.35), 1);
  assert.equal(rollLuckyWinMultiplier(() => 0.5), 1);
  // 0.99995 is past every bucket but the last one (the 1000x bucket
  // starts at 0.999933).
  assert.equal(rollLuckyWinMultiplier(() => 0.99995), 1000);
  // A roll past the table total (chances sum to 0.99999967) still lands
  // on the rarest entry instead of returning undefined.
  assert.equal(rollLuckyWinMultiplier(() => 0.9999999), 1000);
  assert.equal(rollLuckyWinMultiplier(() => 1), 1000);
});

test("a normal (non-Lucky) gift never wins", async () => {
  const fx = await fixture();
  await makeUser(fx, "win-sender", { coins: 100000 });
  await makeUser(fx, "win-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "win-sender");
  await joinRoom(fx, roomId, "win-sender");
  await joinRoom(fx, roomId, "win-receiver");

  const sent = await sendGift(fx, roomId, "win-sender", "win-receiver", { giftId: "rose" });
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.ok, true);
  assert.equal(sent.body.lucky_multiplier, 0);
  assert.equal(sent.body.lucky_win_coins, 0);
  // Sender paid exactly the gift cost; no win credit, no win ledger row.
  assert.equal(wallet(fx, "win-sender").coins, 100000 - Number(sent.body.gift_total_cost));
  assert.equal(
    fx.sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id=? AND kind='lucky_win'").get("win-sender").n,
    0,
  );
  const event = fx.sqlite.prepare("SELECT lucky_multiplier, lucky_win_coins FROM gift_events WHERE room_id=?").get(roomId);
  assert.equal(event.lucky_multiplier, 0);
  assert.equal(event.lucky_win_coins, 0);
});

test("a Lucky gift's win is a table multiplier on the total cost, paid to the sender", async () => {
  const fx = await fixture();
  await makeUser(fx, "win-sender", { coins: 100000 });
  await makeUser(fx, "win-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "win-sender");
  await joinRoom(fx, roomId, "win-sender");
  await joinRoom(fx, roomId, "win-receiver");

  const sent = await sendGift(fx, roomId, "win-sender", "win-receiver", { giftId: "glass-rose" });
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.ok, true);
  const multiplier = Number(sent.body.lucky_multiplier);
  const win = Number(sent.body.lucky_win_coins);
  const total = Number(sent.body.gift_total_cost);
  assert.ok(MULTIPLIERS.has(multiplier), `multiplier ${multiplier} is not in the table`);
  assert.equal(win, total * multiplier);
  // Sender paid the total, then won the win back; receiver got the total
  // in diamonds — the win does not change what the receiver gets.
  assert.equal(wallet(fx, "win-sender").coins, 100000 - total + win);
  assert.equal(wallet(fx, "win-receiver").diamonds, total);
  // The event records the win, and its coin_cost stays the gift total
  // (the win never inflates the Rocket total or ranking).
  const event = fx.sqlite.prepare("SELECT coin_cost, lucky_multiplier, lucky_win_coins FROM gift_events WHERE room_id=?").get(roomId);
  assert.equal(event.coin_cost, total);
  assert.equal(event.lucky_multiplier, multiplier);
  assert.equal(event.lucky_win_coins, win);
  // The ledger has a lucky_win row exactly when the roll paid out.
  const ledger = fx.sqlite.prepare("SELECT amount FROM wallet_ledger WHERE user_id=? AND kind='lucky_win'").all("win-sender");
  if (win > 0) {
    assert.equal(ledger.length, 1);
    assert.equal(ledger[0].amount, win);
  } else {
    assert.equal(ledger.length, 0);
  }
});

test("a Lucky combo win is on the combo total, not the unit price", async () => {
  const fx = await fixture();
  await makeUser(fx, "win-sender", { coins: 100000 });
  await makeUser(fx, "win-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "win-sender");
  await joinRoom(fx, roomId, "win-sender");
  await joinRoom(fx, roomId, "win-receiver");

  const sent = await sendGift(fx, roomId, "win-sender", "win-receiver", { giftId: "glass-rose", count: 7 });
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.ok, true);
  const multiplier = Number(sent.body.lucky_multiplier);
  const win = Number(sent.body.lucky_win_coins);
  const total = Number(sent.body.gift_total_cost);
  assert.equal(total, Number(sent.body.gift_cost) * 7);
  assert.equal(win, total * multiplier);
  assert.equal(wallet(fx, "win-sender").coins, 100000 - total + win);
  assert.equal(wallet(fx, "win-receiver").diamonds, total);
});

test("the room gift-events feed returns the Lucky win fields", async () => {
  const fx = await fixture();
  await makeUser(fx, "win-sender", { coins: 100000 });
  await makeUser(fx, "win-receiver", { coins: 0 });
  const roomId = await makeRoom(fx, "win-sender");
  await joinRoom(fx, roomId, "win-sender");
  await joinRoom(fx, roomId, "win-receiver");

  const sent = await sendGift(fx, roomId, "win-sender", "win-receiver", { giftId: "glass-rose" });
  assert.equal(sent.body.ok, true);
  const feed = await fx.request(`/api/rooms/${roomId}/gift-events`, { userId: "win-receiver" });
  assert.equal(feed.status, 200, JSON.stringify(feed.body));
  assert.equal(feed.body.events.length, 1);
  assert.equal(feed.body.events[0].lucky_multiplier, Number(sent.body.lucky_multiplier));
  assert.equal(feed.body.events[0].lucky_win_coins, Number(sent.body.lucky_win_coins));
});
