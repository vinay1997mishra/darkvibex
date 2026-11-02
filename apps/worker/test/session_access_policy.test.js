import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
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
async function sessionToken(userId, secret, provider = "google") {
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({
    sub: userId,
    exp: Math.floor(Date.now() / 1000) + 3600,
    provider,
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

async function fixture({ allowGuests = false } = {}) {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "session-access-policy-test-secret";
  const env = {
    DB,
    SESSION_SECRET: secret,
    ...(allowGuests ? { ALLOW_GUEST_SESSIONS: true } : {}),
  };
  async function request(path, { method = "GET", body, token } = {}) {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (token) headers.set("authorization", `Bearer ${token}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, {
      method,
      headers,
      body: body == null ? undefined : JSON.stringify(body),
    }), env);
    return { status: response.status, body: await response.json() };
  }
  return { sqlite, request, secret };
}

test("guest login is disabled by default and cannot mint a token for a chosen user ID", async () => {
  const { sqlite, request } = await fixture();
  const result = await request("/api/session/guest", {
    method: "POST",
    body: { user_id: "victim-user", display_name: "Impersonation Attempt" },
  });
  assert.equal(result.status, 403);
  assert.equal(result.body.error, "guest_login_disabled");
  assert.equal(
    sqlite.prepare("SELECT id FROM users WHERE id=?").get("victim-user"),
    undefined,
  );
});

test("unauthenticated user upsert cannot create an account or award starting coins", async () => {
  const { sqlite, request } = await fixture();
  const result = await request("/api/users/upsert", {
    method: "POST",
    body: { user_id: "attacker-created-user", display_name: "Unauthenticated" },
  });
  assert.equal(result.status, 401);
  assert.equal(result.body.error, "unauthorized");
  assert.equal(
    sqlite.prepare("SELECT id FROM users WHERE id=?").get("attacker-created-user"),
    undefined,
  );
});

test("banned users are denied by the shared session guard on protected routes", async () => {
  const { sqlite, request, secret } = await fixture();
  sqlite.prepare(
    "INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)",
  ).run("banned-user", "Banned User", Date.now(), Date.now());
  sqlite.prepare(
    "INSERT INTO owner_user_controls(user_id,status,updated_at) VALUES(?,?,?)",
  ).run("banned-user", "banned", Date.now());

  const result = await request("/api/tasks?user_id=banned-user", {
    token: await sessionToken("banned-user", secret),
  });
  assert.equal(result.status, 403);
  assert.equal(result.body.error, "user_banned");
});

test("explicit test-only guest fixture flag preserves isolated integration test setup", async () => {
  const { request, sqlite } = await fixture({ allowGuests: true });
  const result = await request("/api/session/guest", {
    method: "POST",
    body: { user_id: "test-only-guest", display_name: "Test Guest" },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.provider, "guest");
  assert.ok(result.body.token);
  assert.equal(
    sqlite.prepare("SELECT id FROM users WHERE id=?").get("test-only-guest").id,
    "test-only-guest",
  );
});
