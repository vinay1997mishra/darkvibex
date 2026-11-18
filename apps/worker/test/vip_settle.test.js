import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import { getVipStatus } from "../src/vip_store.js";

const DAY_MS = 86400000;

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

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const env = { DB, SESSION_SECRET: "vip-settle-test-secret", ALLOW_GUEST_SESSIONS: true };
  const response = await worker.fetch(new Request("https://test.invalid/api/session/guest", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ user_id: "receiver", display_name: "Receiver" }),
  }), env);
  assert.equal(response.status, 200);
  // Seed the user_vip row (level 0), then each test sets its own state.
  await getVipStatus(DB, "receiver");
  const setVip = (level, exp, activeUntil) => sqlite.prepare(
    "UPDATE user_vip SET level=?, exp_balance=?, active_until=? WHERE user_id='receiver'"
  ).run(level, exp, activeUntil);
  return { sqlite, DB, setVip };
}

test("expired VIP with enough EXP for the next level promotes at expiry", async () => {
  const { DB, setVip } = await fixture();
  const now = Date.now();
  // Level 1, expired yesterday, 100,000 EXP banked = exactly VIP2's upgrade.
  setVip(1, 100000, now - DAY_MS);
  const status = await getVipStatus(DB, "receiver", now);
  assert.equal(status.level, 2);
  assert.equal(status.exp_balance, 0);
  assert.equal(status.active, true);
  assert.ok(status.active_until > now + 29 * DAY_MS);
  assert.ok(status.active_until <= now + 30 * DAY_MS + 60000);
});

test("expired VIP with enough EXP to maintain keeps the level and extends", async () => {
  const { DB, setVip } = await fixture();
  const now = Date.now();
  // Level 1, expired yesterday, 75 EXP = VIP1's maintain target but
  // below VIP2's 100,000 upgrade, so the level is kept, not promoted.
  setVip(1, 75, now - DAY_MS);
  const status = await getVipStatus(DB, "receiver", now);
  assert.equal(status.level, 1);
  assert.equal(status.exp_balance, 0);
  assert.equal(status.active, true);
  assert.ok(status.active_until > now + 29 * DAY_MS);
  assert.ok(status.active_until <= now + 30 * DAY_MS + 60000);
});

test("expired VIP without maintenance EXP drops by exactly one level", async () => {
  const { sqlite, DB, setVip } = await fixture();
  const now = Date.now();
  // Level 2, expired yesterday, no EXP banked: drops to 1, not to 0.
  setVip(2, 0, now - DAY_MS);
  const status = await getVipStatus(DB, "receiver", now);
  assert.equal(status.level, 1);
  assert.equal(status.exp_balance, 0);
  assert.equal(status.active, true);
  assert.ok(status.active_until > now + 29 * DAY_MS);
  assert.equal(sqlite.prepare("SELECT vip_level FROM users WHERE id='receiver'").get().vip_level, 1);
  const event = sqlite.prepare(
    "SELECT kind, level_before, level_after FROM vip_events WHERE user_id='receiver' AND kind='expire_drop'"
  ).get();
  assert.equal(event.level_before, 2);
  assert.equal(event.level_after, 1);
});

test("promotion to VIP16 at expiry starts a 60-day validity", async () => {
  const { DB, setVip } = await fixture();
  const now = Date.now();
  // Level 15, expired yesterday, 22,000,000 EXP banked = VIP16's upgrade.
  setVip(15, 22000000, now - DAY_MS);
  const status = await getVipStatus(DB, "receiver", now);
  assert.equal(status.level, 16);
  assert.equal(status.exp_balance, 0);
  assert.equal(status.active, true);
  assert.ok(status.active_until > now + 59 * DAY_MS);
  assert.ok(status.active_until <= now + 60 * DAY_MS + 60000);
});

test("unexpired VIP is untouched by the expiry review", async () => {
  const { DB, setVip } = await fixture();
  const now = Date.now();
  const until = now + 10 * DAY_MS;
  setVip(1, 0, until);
  const status = await getVipStatus(DB, "receiver", now);
  assert.equal(status.level, 1);
  assert.equal(status.exp_balance, 0);
  assert.equal(status.active_until, until);
});
