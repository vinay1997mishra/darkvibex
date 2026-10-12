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
  const secret = "vip-privacy-test-secret";
  const FILES = {
    async get(key) {
      if (key !== "users/target/avatar-test.png") return null;
      return {
        body: new Uint8Array([1, 2, 3]),
        httpEtag: '"avatar"',
        writeHttpMetadata(headers) { headers.set("content-type", "image/png"); },
      };
    },
  };
  const env = { DB, FILES, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    return worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
  };
  for (const id of ["target", "visitor"]) {
    const response = await request("/api/session/guest", { method: "POST", body: { user_id: id, display_name: id } });
    assert.equal(response.status, 200);
  }
  sqlite.prepare("UPDATE users SET vip_level=15,avatar_key='users/target/avatar-test.png' WHERE id='target'").run();
  await request("/api/vip/target", { userId: "target" });
  sqlite.prepare("UPDATE user_vip SET level=15,active_until=?,preferences_json=? WHERE user_id='target'")
    .run(Date.now() + 86400000, JSON.stringify({ privacy_protection: true }));
  return { sqlite, request };
}

test("active VIP15 privacy protection blocks other users from downloading profile avatars", async () => {
  const { sqlite, request } = await fixture();
  const profile = await request("/api/users/target", { userId: "visitor" });
  assert.equal(profile.status, 200);
  assert.equal((await profile.json()).user.privacy_protection_enabled, true);

  const denied = await request("/api/files?key=users%2Ftarget%2Favatar-test.png", { userId: "visitor" });
  assert.equal(denied.status, 404);
  const allowed = await request("/api/files?key=users%2Ftarget%2Favatar-test.png", { userId: "target" });
  assert.equal(allowed.status, 200);
  assert.equal(allowed.headers.get("cache-control"), "private, no-store");
  sqlite.close();
});
