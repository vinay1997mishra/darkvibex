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

test("View Visitors is gated to active VIP1+: VIP1 sees the list, VIP0 gets 403 vip_required", async () => {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "vip-view-visitors-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    return worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
  };

  const now = Date.now();
  for (const userId of ["vip1", "regular", "visitor"]) {
    sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, now, now);
    await request(`/api/vip/${userId}`, { userId });
  }
  // VIP1: active level 1.
  sqlite.prepare("UPDATE user_vip SET level=1,active_until=?,preferences_json='{}' WHERE user_id='vip1'").run(now + 86400000);
  // One recorded visit to vip1's profile.
  sqlite.prepare("INSERT INTO profile_visitors(viewed_user_id,visitor_user_id,first_visited_at,last_visited_at,visit_count) VALUES(?,?,?,?,?)")
    .run("vip1", "visitor", now, now, 1);

  // VIP1 sees the visitor list.
  const okResponse = await request("/api/users/vip1/visitors", { userId: "vip1" });
  assert.equal(okResponse.status, 200);
  const okBody = await okResponse.json();
  assert.equal(okBody.ok, true);
  assert.equal(okBody.visitors.length, 1);
  assert.equal(okBody.visitors[0].user_id, "visitor");

  // VIP0 (regular) is blocked with vip_required, required_level 1.
  const deniedResponse = await request("/api/users/regular/visitors", { userId: "regular" });
  assert.equal(deniedResponse.status, 403);
  const deniedBody = await deniedResponse.json();
  assert.equal(deniedBody.ok, false);
  assert.equal(deniedBody.error, "vip_required");
  assert.equal(deniedBody.required_level, 1);

  sqlite.close();
});
