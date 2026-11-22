// Room poll resilience (Vinay, 2026-11-22): IDs were leaving rooms
// on their own. The server never deletes a member row on presence —
// but the 3s state poll used to fail as a whole when its inline
// housekeeping (heartbeat write, empty-room chat wipe) failed, and
// the app read any failed poll as a kick. These tests pin the
// server side: the wipe runs inside the poll and must never break it,
// and the heartbeat/wipe are best-effort.
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
  const secret = "room-poll-resilience-test-secret";
  const files = {
    deleted: [],
    async delete(key) { this.deleted.push(String(key)); },
    async put() { return { ok: true }; },
    async get() { return null; },
  };
  const env = { DB, SESSION_SECRET: secret, FILES: files };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, request, files };
}

async function makeUser(fx, userId) {
  fx.sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  fx.sqlite.prepare("UPDATE users SET country_code='IN' WHERE id=?").run(userId);
}

async function makeRoom(fx, ownerId) {
  const created = await fx.request("/api/rooms", { method: "POST", userId: ownerId, body: { owner_user_id: ownerId, owner_name: ownerId, name: `${ownerId} room`, seat_count: 12 } });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return String(created.body.room_id);
}

test("the 3s state poll answers while the empty-room wipe runs inside it", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner-a");
  await makeUser(fx, "member-a");
  await makeUser(fx, "owner-b");
  const roomA = await makeRoom(fx, "owner-a");
  const roomB = await makeRoom(fx, "owner-b");
  await fx.request(`/api/rooms/${roomA}/join`, { method: "POST", userId: "member-a", body: { user_id: "member-a", display_name: "member-a" } });
  // Room B gets a message, then becomes empty WITHOUT going through
  // the leave endpoint (which wipes the chat itself): insert the
  // message and drop the member row directly, so the next poll
  // anywhere wipes B's chat inline.
  fx.sqlite.prepare(
    "INSERT INTO room_messages(id,room_id,user_id,text,created_at) VALUES(?,?,?,?,?)",
  ).run("msg-b-1", roomB, "owner-b", "hello in B", Date.now());
  fx.sqlite.prepare("DELETE FROM room_members WHERE room_id=?").run(roomB);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_messages WHERE room_id=?").get(roomB).n, 1);

  // The member's state poll must answer 200 with the member list —
  // the wipe of room B running inside it must not break the poll.
  const state = await fx.request(`/api/rooms/${roomA}/state`, { userId: "member-a" });
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.equal(state.body.ok, true);
  assert.ok((state.body.members ?? []).some((m) => m.user_id === "member-a"));
  // And the wipe did run: room B's chat is gone.
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS n FROM room_messages WHERE room_id=?").get(roomB).n, 0);
  fx.sqlite.close();
});

test("the state poll still answers when the member row is the only thing left in a wiped room", async () => {
  const fx = await fixture();
  await makeUser(fx, "owner-a");
  await makeUser(fx, "member-a");
  const roomA = await makeRoom(fx, "owner-a");
  await fx.request(`/api/rooms/${roomA}/join`, { method: "POST", userId: "member-a", body: { user_id: "member-a", display_name: "member-a" } });
  const state = await fx.request(`/api/rooms/${roomA}/state`, { userId: "member-a" });
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.equal(state.body.ok, true);
  fx.sqlite.close();
});

test("heartbeat and empty-room wipe are best-effort inside the poll (source assertions)", () => {
  const index = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  // refreshRoomPresence: a failed wipe must never fail the caller.
  assert.match(index, /async function refreshRoomPresence[\s\S]*?try \{\s*await wipeChatOfEmptyRooms\(db, env\);[\s\S]*?\} catch \(_\) \{/);
  // checkRoomMemberPresence: a failed heartbeat write must never fail
  // the state poll — the membership SELECT below it still runs.
  assert.match(index, /async function checkRoomMemberPresence[\s\S]*?try \{\s*await db\.prepare\(\s*"UPDATE room_members SET updated_at=\? WHERE room_id=\? AND user_id=\?"\s*\)\.bind\(heartbeatTs, roomId, actorId\)\.run\(\);[\s\S]*?\} catch \(_\) \{/);
});
