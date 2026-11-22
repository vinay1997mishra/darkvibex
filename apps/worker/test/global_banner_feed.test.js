// Top-of-room banner feed (Vinay, 2026-11-22): GET /api/banners/global
// returns the cross-room banners every room's top banner shows —
// recent Rocket launches, big gifts (1,000,000+ coins), Lucky wins of
// 100x or more, and big game bet wins of 30,000,000+ coins ("Ravi win
// 30M in Greedy Girl"). One message at a time in the banner, not a
// scrolling marquee; tapping a cross-room banner asks "Enter this
// room?" and Confirm takes the user into that room.
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
  const secret = "global-banner-test-secret";
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
async function makeUser(fx, userId, { coins = 50000000 } = {}) {
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=0, coins=?, country_code='IN', public_id=? WHERE id=?").run(coins, String(publicIdCounter), userId);
  return userId;
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
}

async function sendGift(fx, roomId, senderId, receiverId, giftId) {
  return fx.request("/api/gifts/send", {
    method: "POST",
    userId: senderId,
    body: { sender_user_id: senderId, receiver_user_id: receiverId, gift_id: giftId, room_id: roomId },
  });
}

test("global banner feed: big gift and Rocket launch appear, small gift does not", async () => {
  const fx = await fixture();
  const sender = await makeUser(fx, "banner-sender");
  const receiver = await makeUser(fx, "banner-receiver");
  const roomId = await makeRoom(fx, sender);
  await joinRoom(fx, roomId, sender);
  await joinRoom(fx, roomId, receiver);

  // A small gift (glass-rose, 10 coins) must NOT appear in the feed.
  const small = await sendGift(fx, roomId, sender, receiver, "glass-rose");
  assert.equal(small.status, 200, JSON.stringify(small.body));

  // A Galaxy Celebration (12,000,000 coins) is a big gift AND pushes
  // the room's lifetime total past the first Rocket stage (12M), so
  // it must appear as a gift item AND a Rocket launch item.
  const big = await sendGift(fx, roomId, sender, receiver, "galaxy-celebration");
  assert.equal(big.status, 200, JSON.stringify(big.body));

  const feed = await fx.request("/api/banners/global", { userId: sender });
  assert.equal(feed.status, 200, JSON.stringify(feed.body));
  assert.equal(feed.body.ok, true);
  const items = feed.body.items;
  assert.ok(Array.isArray(items), "items must be an array");

  const giftItems = items.filter((item) => item.kind === "gift");
  assert.equal(giftItems.length, 1, `expected 1 gift item, got ${JSON.stringify(items)}`);
  assert.equal(giftItems[0].room_id, roomId);
  assert.match(giftItems[0].text, /Galaxy Celebration/);
  assert.match(giftItems[0].text, /banner-sender/);

  const rocketItems = items.filter((item) => item.kind === "rocket");
  assert.equal(rocketItems.length, 1, `expected 1 rocket item, got ${JSON.stringify(items)}`);
  assert.equal(rocketItems[0].room_id, roomId);
  assert.match(rocketItems[0].text, /Rocket Lv\.1/);
  // Every rocket level has its own banner design (Vinay, 2026-11-22)
  // — the level rides the feed item so the app can colour it.
  assert.equal(rocketItems[0].rocket_level, 1);

  // The small glass-rose must not appear as a GIFT item (its cost is
  // below the 1M threshold). Note: it may still appear as a LUCKY
  // item if its random Lucky roll paid out 100x or more — only 100x+
  // Lucky wins go cross-room (Vinay, 2026-11-22).
  assert.ok(
    !giftItems.some((item) => item.text.includes("Rose")),
    `small gift leaked into feed as a gift item: ${JSON.stringify(giftItems)}`,
  );
});

test("global banner feed: a 100x Lucky win appears, a 10x win does not", async () => {
  const fx = await fixture();
  const sender = await makeUser(fx, "lucky-sender");
  const receiver = await makeUser(fx, "lucky-receiver");
  const roomId = await makeRoom(fx, sender);
  await joinRoom(fx, roomId, sender);
  await joinRoom(fx, roomId, receiver);

  // Simulate Lucky wins (the roll itself is random, so the win rows
  // are inserted directly). Cross-room Lucky wins are 100x+ only
  // (Vinay, 2026-11-22): a 100x win must appear, a 10x win must not.
  const nowMs = Date.now();
  fx.sqlite.prepare(
    "INSERT INTO gift_events (id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,lucky_multiplier,lucky_win_coins,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
  ).run("lucky-event-100x", roomId, sender, receiver, "glass-rose", 10, 1, 100, 1000, nowMs);
  fx.sqlite.prepare(
    "INSERT INTO gift_events (id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,lucky_multiplier,lucky_win_coins,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
  ).run("lucky-event-10x", roomId, sender, receiver, "glass-rose", 10, 1, 10, 100, nowMs);

  const feed = await fx.request("/api/banners/global", { userId: sender });
  assert.equal(feed.status, 200, JSON.stringify(feed.body));
  const luckyItems = feed.body.items.filter((item) => item.kind === "lucky");
  assert.equal(luckyItems.length, 1, `expected 1 lucky item, got ${JSON.stringify(feed.body.items)}`);
  assert.equal(luckyItems[0].room_id, roomId);
  assert.match(luckyItems[0].text, /won 1000 coins/);
  assert.match(luckyItems[0].text, /100×/);
  // The Lucky banner names who received the gift and the room ID
  // (Vinay, 2026-11-22 13:38 IST).
  assert.match(luckyItems[0].text, /for lucky-receiver/);
  assert.match(luckyItems[0].text, new RegExp(`Room ID: ${roomId}`));
});

test("global banner feed: a 30M+ game win appears, a smaller win does not", async () => {
  const fx = await fixture();
  const sender = await makeUser(fx, "game-winner");
  const nowMs = Date.now();

  // The game results tables are created lazily by the game sync, so
  // the test creates the Greedy Girl table itself.
  fx.sqlite.exec(
    `CREATE TABLE IF NOT EXISTS greedy_girl_results (
      round_id INTEGER PRIMARY KEY,
      food_key TEXT NOT NULL,
      total_bet INTEGER NOT NULL DEFAULT 0,
      total_payout INTEGER NOT NULL DEFAULT 0,
      active_players INTEGER NOT NULL DEFAULT 0,
      top_winners_json TEXT NOT NULL DEFAULT '[]',
      settled_at INTEGER NOT NULL
    )`,
  );

  // Greedy Girl round: Ravi won 30,000,000 (must appear) and a
  // 5,000,000 winner (must not — below the 30M cross-room bar).
  fx.sqlite.prepare(
    "INSERT INTO greedy_girl_results (round_id,food_key,total_bet,total_payout,active_players,top_winners_json,settled_at) VALUES(?,?,?,?,?,?,?)",
  ).run(
    1704, "green", 100000000, 35000000, 12,
    JSON.stringify([
      { user_id: "game-winner", display_name: "Ravi", winning_coins: 30000000 },
      { user_id: "game-small", display_name: "Small", winning_coins: 5000000 },
    ]),
    nowMs,
  );

  const feed = await fx.request("/api/banners/global", { userId: sender });
  assert.equal(feed.status, 200, JSON.stringify(feed.body));
  const gameItems = feed.body.items.filter((item) => item.kind === "game");
  assert.equal(gameItems.length, 1, `expected 1 game item, got ${JSON.stringify(feed.body.items)}`);
  assert.match(gameItems[0].text, /Ravi win 30M in Greedy Girl/);
  // A game win names no room (games are global) — not tappable.
  assert.equal(gameItems[0].room_id, "");
});

test("global banner feed: requires a session", async () => {
  const fx = await fixture();
  const feed = await fx.request("/api/banners/global");
  assert.equal(feed.status, 401, JSON.stringify(feed.body));
});
