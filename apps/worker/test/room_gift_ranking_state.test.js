// Room gift ranking rides the 3s room state poll (Vinay, 2026-11-21):
// the state response always carries the lifetime total + the current
// month's top gifter, and the full top-99 list only when ?period= is
// passed (the ranking page polls with it). Periods are IST calendar
// windows: day changes at IST midnight, week every Monday 00:00 IST,
// month refreshes on the 1st. A day with no sending returns an empty
// day ranking. This room only — no other room's ranking.
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
  const secret = "room-gift-ranking-state-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, FILES: files, OWNER_ADMIN_TOKEN: "owner-test-token" };
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
async function makeUser(fx, userId, { coins = 100000, vipLevel = 0, country = "IN" } = {}) {
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, country_code=?, public_id=? WHERE id=?").run(vipLevel, coins, country, String(publicIdCounter), userId);
  return { userId, publicId: String(publicIdCounter) };
}

async function makeRoom(fx, ownerId) {
  const { request } = fx;
  const created = await request("/api/rooms", { method: "POST", userId: ownerId, body: { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12 } });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return String(created.body.room_id);
}

async function joinRoom(fx, roomId, userId) {
  const joined = await fx.request(`/api/rooms/${roomId}/join`, { method: "POST", userId, body: { user_id: userId, display_name: userId } });
  assert.equal(joined.status, 200, JSON.stringify(joined.body));
  return joined;
}

// IST calendar windows, mirroring the worker's istPeriodWindow.
const IST_OFFSET_MS = 5 * 60 * 60 * 1000 + 30 * 60 * 1000;
function istDayStart(nowMs) {
  const ist = new Date(nowMs + IST_OFFSET_MS);
  return Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()) - IST_OFFSET_MS;
}
function istWeekStart(nowMs) {
  const ist = new Date(nowMs + IST_OFFSET_MS);
  const mondayOffset = (ist.getUTCDay() + 6) % 7;
  return Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate() - mondayOffset) - IST_OFFSET_MS;
}
function istMonthStart(nowMs) {
  const ist = new Date(nowMs + IST_OFFSET_MS);
  return Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), 1) - IST_OFFSET_MS;
}

let giftCounter = 0;
function seedGift(fx, roomId, senderId, receiverId, coins, createdAt) {
  giftCounter += 1;
  fx.sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES(?,?,?,?,?,?,?)"
  ).run(`gift-${giftCounter}`, roomId, senderId, receiverId, "rose", coins, createdAt);
}

test("day ranking shows only today's senders; month top is the month's top sender; lifetime counts all (this room only)", async () => {
  const fx = await fixture();
  const host = await makeUser(fx, "rank-host");
  const alice = await makeUser(fx, "rank-alice");
  const bob = await makeUser(fx, "rank-bob");
  const roomId = await makeRoom(fx, host.userId);
  const otherHost = await makeUser(fx, "rank-other-host");
  const otherRoomId = await makeRoom(fx, otherHost.userId);
  await joinRoom(fx, roomId, host.userId);
  await joinRoom(fx, roomId, alice.userId);
  await joinRoom(fx, roomId, bob.userId);
  const now = Date.now();
  const todayStart = istDayStart(now);
  seedGift(fx, roomId, alice.userId, host.userId, 5000, now - 1000);
  seedGift(fx, roomId, bob.userId, host.userId, 3000, now - 2000);
  seedGift(fx, roomId, alice.userId, host.userId, 9000, todayStart - 3600_000);
  seedGift(fx, otherRoomId, alice.userId, host.userId, 99999, now - 1000);

  const day = await fx.request(`/api/rooms/${roomId}/state?period=day`, { userId: host.userId });
  assert.equal(day.status, 200, JSON.stringify(day.body));
  assert.equal(day.body.gift_period, "day");
  assert.deepEqual(
    day.body.gift_ranking.map((row) => [row.user_id, row.sent_coins]),
    [[alice.userId, 5000], [bob.userId, 3000]],
  );
  assert.equal(day.body.gift_ranking[0].public_id, alice.publicId);
  assert.equal(day.body.gift_lifetime_total, 17000);
  // Month top: alice sent 5000 today + 9000 yesterday (same month unless
  // today is the 1st, when yesterday is last month — still alice on top).
  assert.equal(day.body.gift_month_top.user_id, alice.userId);

  const noPeriod = await fx.request(`/api/rooms/${roomId}/state`, { userId: host.userId });
  assert.equal(noPeriod.status, 200, JSON.stringify(noPeriod.body));
  assert.equal(noPeriod.body.gift_period, "lifetime");
  assert.deepEqual(noPeriod.body.gift_ranking, []);
  assert.equal(noPeriod.body.gift_lifetime_total, 17000);
  assert.equal(noPeriod.body.gift_month_top.user_id, alice.userId);
});

test("a day with no sending returns an empty day ranking; an empty room has no month top", async () => {
  const fx = await fixture();
  const host = await makeUser(fx, "empty-host");
  const alice = await makeUser(fx, "empty-alice");
  const roomId = await makeRoom(fx, host.userId);
  await joinRoom(fx, roomId, host.userId);

  const empty = await fx.request(`/api/rooms/${roomId}/state?period=day`, { userId: host.userId });
  assert.equal(empty.status, 200, JSON.stringify(empty.body));
  assert.deepEqual(empty.body.gift_ranking, []);
  assert.equal(empty.body.gift_month_top, null);
  assert.equal(empty.body.gift_lifetime_total, 0);

  const now = Date.now();
  seedGift(fx, roomId, alice.userId, host.userId, 4000, istDayStart(now) - 3600_000);
  const day = await fx.request(`/api/rooms/${roomId}/state?period=day`, { userId: host.userId });
  assert.equal(day.status, 200, JSON.stringify(day.body));
  assert.deepEqual(day.body.gift_ranking, []);
  assert.equal(day.body.gift_lifetime_total, 4000);
});

test("week and month rankings follow IST calendar windows", async () => {
  const fx = await fixture();
  const host = await makeUser(fx, "cal-host");
  const alice = await makeUser(fx, "cal-alice");
  const bob = await makeUser(fx, "cal-bob");
  const weekRoomId = await makeRoom(fx, host.userId);
  const host2 = await makeUser(fx, "cal-host2");
  const monthRoomId = await makeRoom(fx, host2.userId);
  await joinRoom(fx, weekRoomId, host.userId);
  await joinRoom(fx, monthRoomId, host2.userId);
  const now = Date.now();
  const weekStart = istWeekStart(now);
  const monthStart = istMonthStart(now);
  seedGift(fx, weekRoomId, alice.userId, host.userId, 5000, weekStart + 3600_000);
  seedGift(fx, weekRoomId, bob.userId, host.userId, 8000, weekStart - 3600_000);
  seedGift(fx, monthRoomId, alice.userId, host.userId, 6000, monthStart + 3600_000);
  seedGift(fx, monthRoomId, bob.userId, host.userId, 9000, monthStart - 3600_000);

  const week = await fx.request(`/api/rooms/${weekRoomId}/state?period=week`, { userId: host.userId });
  assert.equal(week.status, 200, JSON.stringify(week.body));
  assert.equal(week.body.gift_period, "week");
  assert.deepEqual(
    week.body.gift_ranking.map((row) => [row.user_id, row.sent_coins]),
    [[alice.userId, 5000]],
  );

  const month = await fx.request(`/api/rooms/${monthRoomId}/state?period=month`, { userId: host2.userId });
  assert.equal(month.status, 200, JSON.stringify(month.body));
  assert.equal(month.body.gift_period, "month");
  assert.deepEqual(
    month.body.gift_ranking.map((row) => [row.user_id, row.sent_coins]),
    [[alice.userId, 6000]],
  );
});

test("top 99 cap: 105 senders today returns 99 rows, best first", async () => {
  const fx = await fixture();
  const host = await makeUser(fx, "cap-host");
  const roomId = await makeRoom(fx, host.userId);
  await joinRoom(fx, roomId, host.userId);
  const now = Date.now();
  for (let i = 0; i < 105; i++) {
    const user = await makeUser(fx, `cap-${i}`);
    seedGift(fx, roomId, user.userId, host.userId, (i + 1) * 100, now - 1000);
  }
  const day = await fx.request(`/api/rooms/${roomId}/state?period=day`, { userId: host.userId });
  assert.equal(day.status, 200, JSON.stringify(day.body));
  assert.equal(day.body.gift_ranking.length, 99);
  assert.equal(day.body.gift_ranking[0].user_id, "cap-104");
  assert.equal(day.body.gift_ranking[0].sent_coins, 10500);
  assert.equal(day.body.gift_ranking[98].user_id, "cap-6");
  assert.equal(day.body.gift_ranking[98].sent_coins, 700);
});
