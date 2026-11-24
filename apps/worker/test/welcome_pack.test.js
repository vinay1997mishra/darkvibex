// Welcome pack (Vinay, 2026-11-24): every NEW user gets once, at
// signup — 500,000 coins (the starting balance) + VIP1 free for 15
// days. The trial is a temporary grant (same mechanism as the Play
// first-recharge grant): it never touches EXP, earns no EXP and never
// triggers the first-recharge double.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import { createVipGrant, getVipStatus, grantWelcomePack } from "../src/vip_store.js";

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
  const secret = "welcome-pack-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const call = async (path, { method = "GET", body, userId, headers = {} } = {}) => {
    const requestHeaders = new Headers(headers);
    if (body != null) requestHeaders.set("content-type", "application/json");
    if (userId) requestHeaders.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers: requestHeaders, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, env, call };
}

test("new user gets 500,000 coins + VIP1 trial for 15 days on signup", async () => {
  const { sqlite, DB, call } = await fixture();
  const before = Date.now();
  const upsert = await call("/api/users/upsert", {
    method: "POST",
    userId: "newbie",
    body: { user_id: "newbie", display_name: "Newbie" },
  });
  assert.equal(upsert.status, 200);
  assert.equal(upsert.body.ok, true);
  assert.equal(Number(upsert.body.user.coins), 500000);

  const vip = await call("/api/vip/newbie", { userId: "newbie" });
  assert.equal(vip.status, 200);
  assert.equal(vip.body.vip.level, 1);
  assert.equal(vip.body.vip.active, true);
  assert.equal(vip.body.vip.grant_source, "welcome_pack");
  assert.equal(vip.body.vip.grant_level, 1);
  const expiresAt = Number(vip.body.vip.grant_expires_at);
  assert.ok(expiresAt >= before + 15 * DAY_MS - 60000);
  assert.ok(expiresAt <= before + 15 * DAY_MS + 60000);

  const grants = sqlite.prepare("SELECT source, level FROM vip_grants WHERE user_id='newbie'").all()
    .map((row) => ({ source: row.source, level: row.level }));
  assert.deepEqual(grants, [{ source: "welcome_pack", level: 1 }]);
  const ledger = sqlite.prepare("SELECT kind, amount, balance_after FROM wallet_ledger WHERE user_id='newbie'").all()
    .map((row) => ({ kind: row.kind, amount: row.amount, balance_after: row.balance_after }));
  assert.deepEqual(ledger, [{ kind: "welcome_pack", amount: 500000, balance_after: 500000 }]);
  // No EXP from the free pack: the EXP row stays at level 0.
  const row = sqlite.prepare("SELECT level, exp_balance FROM user_vip WHERE user_id='newbie'").get();
  assert.equal(row.level, 0);
  assert.equal(Number(row.exp_balance), 0);
  void DB;
});

test("second login does not double-grant the pack", async () => {
  const { sqlite, call } = await fixture();
  await call("/api/users/upsert", {
    method: "POST",
    userId: "newbie",
    body: { user_id: "newbie", display_name: "Newbie" },
  });
  const again = await call("/api/users/upsert", {
    method: "POST",
    userId: "newbie",
    body: { user_id: "newbie", display_name: "Newbie" },
  });
  assert.equal(again.status, 200);
  assert.equal(Number(again.body.user.coins), 500000);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM vip_grants WHERE user_id='newbie'").get().n, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id='newbie' AND kind='welcome_pack'").get().n, 1);
});

test("welcome trial expires after 15 days and the level drops back", async () => {
  const { DB, call } = await fixture();
  const before = Date.now();
  await call("/api/users/upsert", {
    method: "POST",
    userId: "newbie",
    body: { user_id: "newbie", display_name: "Newbie" },
  });
  const active = await getVipStatus(DB, "newbie", before + 14 * DAY_MS);
  assert.equal(active.level, 1);
  assert.equal(active.active, true);
  const expired = await getVipStatus(DB, "newbie", before + 16 * DAY_MS);
  assert.equal(expired.level, 0);
  assert.equal(expired.active, false);
});

test("grantWelcomePack called twice grants only once", async () => {
  const { sqlite, DB } = await fixture();
  sqlite.prepare("INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES(?,?,?,?,?)").run("solo", "Solo", 500000, Date.now(), Date.now());
  await grantWelcomePack(DB, "solo");
  await grantWelcomePack(DB, "solo");
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM vip_grants WHERE user_id='solo'").get().n, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE user_id='solo' AND kind='welcome_pack'").get().n, 1);
});

test("first-recharge grant coexists with the welcome pack", async () => {
  const { sqlite, DB, call } = await fixture();
  await call("/api/users/upsert", {
    method: "POST",
    userId: "newbie",
    body: { user_id: "newbie", display_name: "Newbie" },
  });
  await createVipGrant(DB, "newbie", 1, 10, "play_first_recharge", "token-1");
  const sources = sqlite.prepare("SELECT source FROM vip_grants WHERE user_id='newbie' ORDER BY source").all().map((row) => row.source);
  assert.deepEqual(sources, ["play_first_recharge", "welcome_pack"]);
  const status = await getVipStatus(DB, "newbie");
  assert.equal(status.level, 1);
  assert.equal(status.active, true);
});
