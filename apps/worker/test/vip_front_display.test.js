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

test("VIP display priority sorts active VIPs ahead of regular members while keeping owner first", async () => {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "vip-front-display-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    return worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
  };

  for (const userId of ["owner", "vip4", "vip17", "regular"]) {
    const response = await request("/api/session/guest", { method: "POST", body: { user_id: userId, display_name: userId } });
    assert.equal(response.status, 200);
    await request(`/api/vip/${userId}`, { userId });
  }

  const now = Date.now();
  sqlite.prepare("INSERT INTO rooms (id,owner_user_id,name,created_at,updated_at) VALUES ('room','owner','Test',?,?)").run(now, now);
  for (const [userId, seatIndex] of [["owner", null], ["vip4", 1], ["vip17", 2], ["regular", 3]]) {
    sqlite.prepare("INSERT INTO room_members (room_id,user_id,seat_index,joined_at,updated_at) VALUES ('room',?,?,?,?)").run(userId, seatIndex, now, now);
  }
  sqlite.prepare("UPDATE user_vip SET level=4,active_until=?,preferences_json='{}' WHERE user_id='vip4'").run(now + 86400000);
  sqlite.prepare("UPDATE user_vip SET level=17,active_until=?,preferences_json='{}' WHERE user_id='vip17'").run(now + 86400000);

  const response = await request("/api/rooms/room/members", { userId: "owner" });
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body.members.map((member) => member.user_id), ["owner", "vip17", "vip4", "regular"]);
  sqlite.close();
});
