// /api/users/:id privacy (audit fix, Vinay 2026-11-20): any logged-in
// user could previously read anyone's coins, diamonds and date of birth.
// Now those fields are returned only to the user themself; other viewers
// get the public profile only.
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
  const secret = "profile-privacy-fields-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  const now = Date.now();
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run("alice", "Alice", now, now);
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run("bob", "Bob", now, now);
  sqlite.prepare("UPDATE users SET coins=?, diamonds=?, date_of_birth=?, bio=?, country_code=?, public_id=? WHERE id=?")
    .run(1234567, 89, "1995-06-15", "Hello world", "IN", "10000042", "alice");
  return { sqlite, request };
}

test("viewing another user's profile hides coins, diamonds and date of birth", async () => {
  const { request } = await fixture();
  const result = await request("/api/users/alice?record_visit=0", { userId: "bob" });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  const user = result.body.user;
  assert.equal(user.id, "alice");
  assert.equal(user.display_name, "Alice");
  assert.equal(user.bio, "Hello world");
  assert.equal(user.country_code, "IN");
  assert.equal(user.coins, undefined, "coins must not leak to other viewers");
  assert.equal(user.diamonds, undefined);
  assert.equal(user.date_of_birth, undefined);
  assert.equal(user.age_change_count, undefined);
  assert.equal(user.country_change_count, undefined);
  assert.equal(user.gender_change_count, undefined);
});

test("viewing your own profile still returns coins, diamonds and date of birth", async () => {
  const { request } = await fixture();
  const result = await request("/api/users/alice?record_visit=0", { userId: "alice" });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.user.coins, 1234567);
  assert.equal(result.body.user.diamonds, 89);
  assert.equal(result.body.user.date_of_birth, "1995-06-15");
});

test("looking another user up by public ID also hides the private fields", async () => {
  const { request } = await fixture();
  const result = await request("/api/users/10000042?record_visit=0", { userId: "bob" });
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.user.id, "alice");
  assert.equal(result.body.user.coins, undefined);
  assert.equal(result.body.user.diamonds, undefined);
  assert.equal(result.body.user.date_of_birth, undefined);
});
