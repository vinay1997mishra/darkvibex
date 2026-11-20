import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import {
  dailyRewardCoinsForLevel,
  claimVipDailyReward,
  vipDailyRewardStatus,
  DAILY_REWARD_MIN_LEVEL,
} from "../src/vip_daily_rewards.js";

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
  const secret = "vip-daily-reward-test-secret";
  const env = { DB, SESSION_SECRET: "vip-daily-reward-test-secret" };  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, request };
}

async function makeVipUser(fixtureOut, userId, vipLevel) {
  const { sqlite, request } = fixtureOut;
  // Guest login is deleted permanently (Vinay 2026-11-20): test users are
  // created directly in SQLite instead of through the removed endpoint.
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  sqlite.prepare("UPDATE users SET vip_level=?, coins=1000 WHERE id=?").run(vipLevel, userId);
  return userId;
}

// 70% of the level $ value over 30 days, in coins at $1 = 8,000,000.
// VIP5 $150 -> 28,000,000/day ... VIP18 $10,000 -> 1,866,666,666/day.
const EXPECTED_DAILY = {
  5: 28000000,
  6: 74666666,
  7: 168000000,
  8: 280000000,
  9: 392000000,
  10: 522666666,
  11: 634666666,
  12: 765333333,
  13: 877333333,
  14: 1008000000,
  15: 1213333333,
  16: 1418666666,
  17: 1642666666,
  18: 1866666666,
};

test("daily reward amount is 70% of the VIP $ value over 30 days", () => {
  assert.equal(DAILY_REWARD_MIN_LEVEL, 5);
  for (const [level, coins] of Object.entries(EXPECTED_DAILY)) {
    assert.equal(dailyRewardCoinsForLevel(Number(level), 8000000), coins, `VIP${level}`);
  }
  for (const level of [0, 1, 2, 3, 4]) {
    assert.equal(dailyRewardCoinsForLevel(level, 8000000), 0, `VIP${level} gets nothing`);
  }
  assert.equal(dailyRewardCoinsForLevel(19, 8000000), 0);
  assert.equal(dailyRewardCoinsForLevel(5, 0), 0);
  assert.equal(dailyRewardCoinsForLevel(5, 4000000), 14000000);
});

test("VIP5 status is eligible with the daily amount, VIP4 is locked", async () => {
  const fx = await fixture();
  await makeVipUser(fx, "vip5", 5);
  await makeVipUser(fx, "vip4", 4);
  const status5 = await fx.request("/api/vip/vip5/daily-reward", { userId: "vip5" });
  assert.equal(status5.status, 200);
  assert.equal(status5.body.ok, true);
  assert.equal(status5.body.eligible, true);
  assert.equal(status5.body.level, 5);
  assert.equal(status5.body.amount_coins, 28000000);
  assert.equal(status5.body.claimed_today, false);
  const status4 = await fx.request("/api/vip/vip4/daily-reward", { userId: "vip4" });
  assert.equal(status4.status, 200);
  assert.equal(status4.body.eligible, false);
  assert.equal(status4.body.amount_coins, 0);
  fx.sqlite.close();
});

test("claim credits coins once per UTC day and never double-pays", async () => {
  const fx = await fixture();
  await makeVipUser(fx, "vip5", 5);
  const before = fx.sqlite.prepare("SELECT coins FROM users WHERE id='vip5'").get().coins;
  const first = await fx.request("/api/vip/vip5/daily-reward", { method: "POST", userId: "vip5" });
  assert.equal(first.status, 200);
  assert.equal(first.body.ok, true);
  assert.equal(first.body.duplicate, false);
  assert.equal(first.body.reward, 28000000);
  assert.equal(first.body.coin_balance, before + 28000000);
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id='vip5'").get().coins, before + 28000000);
  const ledger = fx.sqlite.prepare("SELECT kind,amount,reference_id FROM wallet_ledger WHERE user_id='vip5' AND kind='vip_daily_reward'").all();
  assert.equal(ledger.length, 1);
  assert.equal(ledger[0].amount, 28000000);
  assert.match(ledger[0].reference_id, /^vip-daily-reward:vip5:\d+$/);
  const second = await fx.request("/api/vip/vip5/daily-reward", { method: "POST", userId: "vip5" });
  assert.equal(second.status, 200);
  assert.equal(second.body.ok, true);
  assert.equal(second.body.duplicate, true);
  assert.equal(second.body.reward, 0);
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id='vip5'").get().coins, before + 28000000);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id='vip5' AND kind='vip_daily_reward'").get().n, 1);
  fx.sqlite.close();
});

test("VIP4 claim is locked and a non-VIP claim is inactive", async () => {
  const fx = await fixture();
  await makeVipUser(fx, "vip4", 4);
  await makeVipUser(fx, "plain", 0);
  const locked = await fx.request("/api/vip/vip4/daily-reward", { method: "POST", userId: "vip4" });
  assert.equal(locked.status, 200);
  assert.equal(locked.body.ok, false);
  assert.equal(locked.body.error, "vip_daily_reward_locked");
  assert.equal(fx.sqlite.prepare("SELECT coins FROM users WHERE id='vip4'").get().coins, 1000);
  const inactive = await fx.request("/api/vip/plain/daily-reward", { method: "POST", userId: "plain" });
  assert.equal(inactive.body.ok, false);
  assert.equal(inactive.body.error, "vip_inactive");
  fx.sqlite.close();
});

test("the next UTC day is claimable again", async () => {
  const fx = await fixture();
  await makeVipUser(fx, "vip5", 5);
  let n = 0;
  const newId = () => `test-id-${++n}`;
  const now = Date.now();
  const first = await claimVipDailyReward(fx.DB, "vip5", now, newId);
  assert.equal(first.ok, true);
  assert.equal(first.reward, 28000000);
  const sameDay = await claimVipDailyReward(fx.DB, "vip5", now + 1000, newId);
  assert.equal(sameDay.duplicate, true);
  const nextDay = await claimVipDailyReward(fx.DB, "vip5", now + 86400000, newId);
  assert.equal(nextDay.ok, true);
  assert.equal(nextDay.duplicate, false);
  assert.equal(nextDay.reward, 28000000);
  assert.equal(
    fx.sqlite.prepare("SELECT coins FROM users WHERE id='vip5'").get().coins,
    1000 + 28000000 * 2,
  );
  const status = await vipDailyRewardStatus(fx.DB, "vip5", now + 86400000);
  assert.equal(status.claimed_today, true);
  fx.sqlite.close();
});
