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
async function sessionToken(userId, secret) {
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({
    sub: userId,
    exp: Math.floor(Date.now() / 1000) + 3600,
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

async function fixture(userCount = 51) {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "rocket-reward-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const roomId = "rocket-test-room";
  const timestamp = Date.now();
  const insertUser = sqlite.prepare(
    "INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)",
  );
  const insertMember = sqlite.prepare(
    "INSERT INTO room_members(room_id,user_id,seat_index,mic_muted,joined_at,updated_at) VALUES(?,?,NULL,1,?,?)",
  );

  for (let i = 0; i < userCount; i++) {
    const userId = `rocket-user-${i}`;
    insertUser.run(userId, `Rocket User ${i}`, timestamp, timestamp);
  }
  sqlite.prepare(
    "INSERT INTO rooms(id,owner_user_id,name,seat_count,locked,country_code,created_at,updated_at) VALUES(?,?,?,12,0,'',?,?)",
  ).run(roomId, "rocket-user-0", "Rocket rewards test room", timestamp, timestamp);
  for (let i = 0; i < userCount; i++) {
    insertMember.run(roomId, `rocket-user-${i}`, timestamp, timestamp);
  }

  const insertGift = sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES(?,?,?,?,?,?,?)",
  );
  insertGift.run(
    "rocket-test-gift-1", roomId, "rocket-user-0", "rocket-user-1",
    "rocket-test-gift", 8_000_000, timestamp,
  );

  const tokenCache = new Map();
  const getToken = async (userId) => {
    if (!tokenCache.has(userId)) {
      tokenCache.set(userId, await sessionToken(userId, secret));
    }
    return tokenCache.get(userId);
  };
  const request = async (path, { method = "GET", body, userId = "rocket-user-0" } = {}) => {
    const headers = new Headers({
      authorization: `Bearer ${await getToken(userId)}`,
    });
    if (body != null) headers.set("content-type", "application/json");
    const response = await worker.fetch(
      new Request(`https://test.invalid${path}`, {
        method,
        headers,
        body: body == null ? undefined : JSON.stringify(body),
      }),
      env,
    );
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, roomId, request, insertGift, timestamp };
}

test("Rocket group awards 25 frame-only prizes, then credits coins exactly once", async () => {
  const { sqlite, roomId, request } = await fixture();
  const path = (level) => `/api/rooms/${roomId}/rocket-reward/claim`;
  const beforeFrameWinner = sqlite.prepare(
    "SELECT coins FROM users WHERE id='rocket-user-1'",
  ).get().coins;

  for (let i = 1; i <= 25; i++) {
    const result = await request(path(1), {
      method: "POST",
      userId: `rocket-user-${i}`,
      body: { rocket_level: 1 },
    });
    assert.equal(result.status, 200);
    assert.equal(result.body.ok, true);
    assert.equal(result.body.reward_type, "frame");
    assert.equal(result.body.coins, 0);
    assert.equal(result.body.frame_days, 1);
    assert.equal(result.body.frame_delivery_status, "delivered");
    assert.equal(result.body.frame_id, `rocket_frame_g1_${String(i).padStart(2, "0")}`);
  }
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='rocket-user-1'").get().coins,
    beforeFrameWinner,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='rocket_reward'").get().n,
    0,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM user_cosmetics WHERE kind='frame'").get().n,
    25,
  );
  const firstFrame = sqlite.prepare(
    "SELECT item_id,kind,active,expires_at,acquired_at FROM user_cosmetics WHERE user_id='rocket-user-1'",
  ).get();
  assert.equal(firstFrame.item_id, "rocket_frame_g1_01");
  assert.equal(firstFrame.kind, "frame");
  assert.equal(firstFrame.active, 0);
  assert.equal(firstFrame.expires_at - firstFrame.acquired_at, 86400000);

  for (let i = 26; i <= 50; i++) {
    const result = await request(path(1), {
      method: "POST",
      userId: `rocket-user-${i}`,
      body: { rocket_level: 1 },
    });
    assert.equal(result.status, 200);
    assert.equal(result.body.ok, true);
    assert.equal(result.body.reward_type, "coins");
    assert.ok(result.body.coins >= 10_000 && result.body.coins <= 20_000);
    const wallet = sqlite.prepare(
      "SELECT coins FROM users WHERE id=?",
    ).get(`rocket-user-${i}`);
    assert.equal(wallet.coins, result.body.coins);
  }

  const ledgerCount = sqlite.prepare(
    "SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='rocket_reward'",
  ).get().n;
  assert.equal(ledgerCount, 25);

  const duplicate = await request(path(1), {
    method: "POST",
    userId: "rocket-user-26",
    body: { rocket_level: 1 },
  });
  assert.equal(duplicate.status, 200);
  assert.equal(duplicate.body.already_claimed, true);
  assert.equal(duplicate.body.reward_type, "coins");
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='rocket_reward'").get().n,
    25,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM user_cosmetics WHERE kind='frame'").get().n,
    25,
  );

  const full = await request(path(1), {
    method: "POST",
    userId: "rocket-user-0",
    body: { rocket_level: 1 },
  });
  assert.equal(full.status, 409);
  assert.equal(full.body.error, "reward_claims_full");
  sqlite.close();
});

test("Rocket levels within the same reward tier share one 25-frame/total-winner pool", async () => {
  const { sqlite, roomId, request, insertGift, timestamp } = await fixture();
  for (let i = 1; i <= 50; i++) {
    const result = await request(`/api/rooms/${roomId}/rocket-reward/claim`, {
      method: "POST",
      userId: `rocket-user-${i}`,
      body: { rocket_level: 1 },
    });
    assert.equal(result.status, 200);
  }

  insertGift.run(
    "rocket-test-gift-2", roomId, "rocket-user-0", "rocket-user-1",
    "rocket-test-gift", 7_000_000, timestamp + 1,
  );

  const status = await request(
    `/api/rooms/${roomId}/rocket-reward?level=2`,
    { userId: "rocket-user-0" },
  );
  assert.equal(status.status, 200);
  assert.equal(status.body.tier.group, "1-3");
  assert.equal(status.body.target_coins, 15_000_000);
  assert.equal(status.body.reached, true);
  assert.equal(status.body.claimed_count, 50);
  assert.equal(status.body.remaining_winners, 0);
  assert.equal(status.body.can_claim, false);

  const full = await request(`/api/rooms/${roomId}/rocket-reward/claim`, {
    method: "POST",
    userId: "rocket-user-0",
    body: { rocket_level: 2 },
  });
  assert.equal(full.status, 409);
  assert.equal(full.body.error, "reward_claims_full");
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) AS n FROM rocket_reward_claims WHERE room_id=? AND reward_group='1-3'").get(roomId).n,
    50,
  );
  sqlite.close();
});
