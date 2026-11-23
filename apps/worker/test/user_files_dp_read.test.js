// DP readable by any logged-in user (Vinay, 2026-11-23: "Real user dp
// dikhni chahiye"): a DP is the user's public identity — room chat,
// seats and profiles all show it — so GET /api/user-files serves another
// user's DP to any valid session. id-number/sms/misc stay owner-only.
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
  const secret = "user-files-dp-test-secret";
  const stored = new Map();
  const idFiles = {
    async get(key) {
      const body = stored.get(String(key));
      if (body == null) return null;
      return {
        body,
        httpEtag: '"dp-test-etag"',
        writeHttpMetadata() {},
      };
    },
    async put(key, value) { stored.set(String(key), value); },
  };
  const env = { DB, SESSION_SECRET: secret, FILES: { async get() { return null; } }, ID_FILES: idFiles, OWNER_ADMIN_TOKEN: "owner-test-token" };
  const request = async (path, { userId } = {}) => {
    const headers = new Headers();
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method: "GET", headers }), env);
    return { status: response.status, text: await response.text() };
  };
  return { request, idFiles };
}

test("another logged-in user can read a DP, but not id-number/sms/misc", async () => {
  const fx = await fixture();
  await fx.idFiles.put("users/alice/dp/123.jpg", "alice-dp-bytes");
  await fx.idFiles.put("users/alice/id-number/456.jpg", "alice-id-bytes");
  await fx.idFiles.put("users/alice/sms/789.jpg", "alice-sms-bytes");
  await fx.idFiles.put("users/alice/misc/012.jpg", "alice-misc-bytes");

  // The fix: bob sees alice's real DP in chat / on seats / on profiles.
  const dp = await fx.request("/api/user-files?key=users%2Falice%2Fdp%2F123.jpg", { userId: "bob" });
  assert.equal(dp.status, 200, JSON.stringify(dp));
  assert.equal(dp.text, "alice-dp-bytes");

  // Owner-only files stay owner-only for anyone else.
  for (const key of ["users/alice/id-number/456.jpg", "users/alice/sms/789.jpg", "users/alice/misc/012.jpg"]) {
    const other = await fx.request(`/api/user-files?key=${encodeURIComponent(key)}`, { userId: "bob" });
    assert.equal(other.status, 404, key);
  }

  // The owner still reads everything of their own.
  const ownId = await fx.request("/api/user-files?key=users%2Falice%2Fid-number%2F456.jpg", { userId: "alice" });
  assert.equal(ownId.status, 200, JSON.stringify(ownId));
  const ownDp = await fx.request("/api/user-files?key=users%2Falice%2Fdp%2F123.jpg", { userId: "alice" });
  assert.equal(ownDp.status, 200, JSON.stringify(ownDp));

  // No session at all: nothing is served, DP included.
  const anon = await fx.request("/api/user-files?key=users%2Falice%2Fdp%2F123.jpg", {});
  assert.notEqual(anon.status, 200, JSON.stringify(anon));
});
