// Session refresh expiry (audit fix, Vinay 2026-11-20): the refresh
// endpoint used to accept any correctly-signed token forever — a stolen
// token could be refreshed without limit. Now a session lives at most
// 30 days from the original login: refresh preserves the original iat,
// and past 30 days the user must log in again.
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
function decodePayload(token) {
  return JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8"));
}
async function mintToken(userId, secret, claims) {
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: userId, ...claims })}`;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "session-refresh-expiry-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const requestWithToken = async (path, token) => {
    const headers = new Headers();
    if (token) headers.set("authorization", `Bearer ${token}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method: "POST", headers }), env);
    return { status: response.status, body: await response.json() };
  };
  const now = Date.now();
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run("alice", "Alice", now, now);
  return { requestWithToken, secret };
}

const DAY = 24 * 3600;

test("a token issued more than 30 days ago cannot refresh", async () => {
  const fx = await fixture();
  const nowSeconds = Math.floor(Date.now() / 1000);
  const old = await mintToken("alice", fx.secret, {
    name: "Alice", provider: "google",
    iat: nowSeconds - 31 * DAY, exp: nowSeconds - 24 * DAY,
  });
  const result = await fx.requestWithToken("/api/session/refresh", old);
  assert.equal(result.status, 401, JSON.stringify(result.body));
  assert.equal(result.body.error, "session_expired");
  assert.equal(result.body.token, undefined);
});

test("a token issued 10 days ago refreshes and keeps its original iat", async () => {
  const fx = await fixture();
  const nowSeconds = Math.floor(Date.now() / 1000);
  const issuedAt = nowSeconds - 10 * DAY;
  const old = await mintToken("alice", fx.secret, {
    name: "Alice", provider: "google",
    iat: issuedAt, exp: nowSeconds - 3600,
  });
  const result = await fx.requestWithToken("/api/session/refresh", old);
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.ok(result.body.token);
  const payload = decodePayload(result.body.token);
  assert.equal(payload.iat, issuedAt, "refresh must not reset the 30-day clock");
  assert.ok(payload.exp > nowSeconds, "the new token is valid for 7 more days");
  assert.equal(payload.provider, "google");

  // The refreshed token can refresh again inside the window, still on
  // the original clock.
  const again = await fx.requestWithToken("/api/session/refresh", result.body.token);
  assert.equal(again.status, 200, JSON.stringify(again.body));
  assert.equal(decodePayload(again.body.token).iat, issuedAt);
});

test("a fresh token refreshes normally", async () => {
  const fx = await fixture();
  const nowSeconds = Math.floor(Date.now() / 1000);
  const fresh = await mintToken("alice", fx.secret, {
    name: "Alice", provider: "google",
    iat: nowSeconds, exp: nowSeconds + 7 * DAY,
  });
  const result = await fx.requestWithToken("/api/session/refresh", fresh);
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(decodePayload(result.body.token).iat, nowSeconds);
});
