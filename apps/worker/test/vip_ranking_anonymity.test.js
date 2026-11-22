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
  const secret = "vip-ranking-anonymity-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, request };
}

async function makeUser(fx, userId, { vipLevel = 0, prefs = {} } = {}) {
  const { sqlite, request } = fx;
  const now = Date.now();
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, now, now);
  await request(`/api/vip/${userId}`, { userId });
  if (vipLevel > 0) {
    sqlite.prepare("UPDATE user_vip SET level=?,active_until=?,preferences_json=? WHERE user_id=?")
      .run(vipLevel, now + 86400000, JSON.stringify(prefs), userId);
  }
  return userId;
}

let giftCounter = 0;
function seedGift(fx, senderId, receiverId, coins) {
  giftCounter += 1;
  fx.sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES(?,?,?,?,?,?,?)"
  ).run(`gift-${giftCounter}`, "room1", senderId, receiverId, "rose", coins, Date.now());
}

test("Hide Charm (VIP10+) excludes the user from the Charm ranking; Anonymous Ranking (VIP11+) shows 'Anonymous'", async () => {
  const fx = await fixture();
  const { request } = fx;
  const hidden = await makeUser(fx, "charm-hidden", { vipLevel: 10, prefs: { hide_charm: true } });
  const anon = await makeUser(fx, "rank-anon", { vipLevel: 11, prefs: { anonymous_ranking: true } });
  const anon18 = await makeUser(fx, "rank-anon18", { vipLevel: 18, prefs: { anonymous_everywhere: true } });
  const plain = await makeUser(fx, "rank-plain");
  const viewer = await makeUser(fx, "rank-viewer");

  // Everyone receives gifts (charm ranking is by receiver).
  seedGift(fx, plain, hidden, 100000);
  seedGift(fx, plain, anon, 90000);
  seedGift(fx, plain, anon18, 80000);
  seedGift(fx, plain, plain, 70000);

  // Charm ranking: hide_charm user is excluded; anonymous users show
  // as 'Anonymous' with no avatar and a hidden public ID.
  const charm = await request("/api/rankings?kind=charm&period=day", { userId: viewer });
  assert.equal(charm.status, 200);
  const charmRows = charm.body.ranking;
  assert.equal(charmRows.some((row) => row.user_id === hidden), false, "hide_charm user must not appear in the Charm ranking");
  const anonRow = charmRows.find((row) => row.user_id === anon);
  assert.ok(anonRow, "anonymous_ranking user must still appear in the ranking");
  assert.equal(anonRow.display_name, "Anonymous");
  assert.equal(anonRow.avatar_key, null);
  assert.equal(anonRow.public_id, "Hidden");
  assert.equal(anonRow.is_anonymous, 1);
  const anon18Row = charmRows.find((row) => row.user_id === anon18);
  assert.equal(anon18Row.display_name, "Anonymous", "anonymous_everywhere (VIP18) also anonymizes rankings");
  const plainRow = charmRows.find((row) => row.user_id === plain);
  assert.equal(plainRow.display_name, "rank-plain");
  assert.equal(plainRow.is_anonymous, 0);

  // Send ranking: anonymous users show as 'Anonymous' there too.
  const send = await request("/api/rankings?kind=send&period=day", { userId: viewer });
  assert.equal(send.status, 200);
  const sendRows = send.body.ranking;
  assert.equal(sendRows[0].user_id, plain);
  assert.equal(sendRows[0].display_name, "rank-plain");

  fx.sqlite.close();
});

test("Room gift ranking shows anonymous senders as 'Anonymous'", async () => {
  const fx = await fixture();
  const { sqlite, request } = fx;
  const anon = await makeUser(fx, "room-anon", { vipLevel: 11, prefs: { anonymous_ranking: true } });
  const plain = await makeUser(fx, "room-plain");
  const now = Date.now();
  sqlite.prepare("INSERT INTO rooms (id,owner_user_id,name,created_at,updated_at) VALUES ('room1',?,?,?,?)").run(plain, "Test Room", now, now);
  sqlite.prepare("INSERT INTO room_members (room_id,user_id,seat_index,joined_at,updated_at) VALUES ('room1',?,1,?,?)").run(anon, now, now);
  sqlite.prepare("INSERT INTO room_members (room_id,user_id,seat_index,joined_at,updated_at) VALUES ('room1',?,2,?,?)").run(plain, now, now);
  seedGift(fx, anon, plain, 50000);
  seedGift(fx, plain, anon, 40000);

  const state = await request("/api/rooms/room1/state?period=day", { userId: plain });
  assert.equal(state.status, 200);
  const ranking = state.body.gift_ranking ?? [];
  const anonRow = ranking.find((row) => row.user_id === anon);
  assert.ok(anonRow, "anonymous sender must appear in the room gift ranking");
  assert.equal(anonRow.display_name, "Anonymous");
  assert.equal(anonRow.avatar_key, null);
  assert.equal(anonRow.is_anonymous, 1);

  fx.sqlite.close();
});
