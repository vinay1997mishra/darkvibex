// Top Families page (Mr. Wrong, 2026-11-24 — v9 design): the Local
// scope lists only families whose LEADER is in the viewer's country;
// Global lists all. The country comes from the users table.
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
  const secret = "family-list-country-test-secret";
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

function makeUser(sqlite, userId, countryCode) {
  const now = Date.now();
  sqlite.prepare(
    "INSERT INTO users(id,display_name,country_code,created_at,updated_at) VALUES(?,?,?,?,?)"
  ).run(userId, userId, countryCode, now, now);
}

function makeFamily(sqlite, { id, name, leaderId, experience }) {
  const now = Date.now();
  sqlite.prepare(
    "INSERT INTO families(id,name,tag,leader_user_id,notice,experience,wallet_coins,created_at,updated_at) VALUES(?,?,?,?,?,?,0,?,?)"
  ).run(id, name, name.toUpperCase().slice(0, 5), leaderId, "", experience, now, now);
  sqlite.prepare(
    "INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,?,?)"
  ).run(id, leaderId, "leader", now);
}

test("family list Local scope filters by the leader's country", async () => {
  const fx = await fixture();
  const { sqlite, request } = fx;
  makeUser(sqlite, "leader-in", "IN");
  makeUser(sqlite, "leader-us", "US");
  makeUser(sqlite, "viewer-in", "IN");
  makeFamily(sqlite, { id: "family-in", name: "TIGER FAMILY", leaderId: "leader-in", experience: 1000 });
  makeFamily(sqlite, { id: "family-us", name: "ASTRO", leaderId: "leader-us", experience: 2000 });

  // Global (no country): both families, ordered by EXP.
  const all = await request("/api/family/list", { userId: "viewer-in" });
  assert.equal(all.status, 200);
  assert.deepEqual(
    all.body.families.map((row) => row.id),
    ["family-us", "family-in"],
  );
  assert.equal(all.body.families[0].leader_country_code, "US");
  // 2000 EXP clears the 1500 threshold -> level 4; 1000 EXP -> level 3.
  assert.equal(all.body.families[0].level.level, 4);
  assert.equal(all.body.families[1].level.level, 3);

  // Local (country=IN): only the IN leader's family.
  const local = await request("/api/family/list?country=IN", { userId: "viewer-in" });
  assert.equal(local.status, 200);
  assert.deepEqual(
    local.body.families.map((row) => row.id),
    ["family-in"],
  );

  // The country match is case-insensitive.
  const localLower = await request("/api/family/list?country=us", { userId: "viewer-in" });
  assert.equal(localLower.status, 200);
  assert.deepEqual(
    localLower.body.families.map((row) => row.id),
    ["family-us"],
  );

  fx.sqlite.close();
});
