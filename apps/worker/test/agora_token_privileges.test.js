// Agora tokens — least privilege (audit 2026-11-22).
// The old token carried all four RTC privileges (join, publish audio,
// publish video, publish data) for everyone, so a seatless listener
// or a modified client could publish audio/video. Now a seatless
// party member gets join-only, the room owner (who speaks without a
// seat) and seated members keep the full token, a direct call —
// audio-only in the app — gets join + publish audio, and a game room
// member (always seated) keeps the full token. /agora/token also
// honours maintenance mode now, and the fetch-level device-ban check
// runs when the app sends x-device-id (the app fix sends it).
import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { inflateSync } from "node:zlib";
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

// Decode an Agora RTC token's privilege keys (1 = join, 2 = publish
// audio, 3 = publish video, 4 = publish data). The token is "007" +
// base64(deflate(packed)) and every integer is little-endian.
function decodeAgoraPrivileges(token) {
  const buf = inflateSync(Buffer.from(String(token).slice(3), "base64"));
  let off = 0;
  const u16 = () => { const v = buf.readUInt16LE(off); off += 2; return v; };
  const u32 = () => { const v = buf.readUInt32LE(off); off += 4; return v; };
  // (Do NOT write these as `off += u16()`: compound assignment reads
  // the old off before the call, so the +2 inside u16() is lost and
  // the cursor lands inside the signature.)
  const sigLen = u16();
  off += sigLen;
  const appIdLen = u16();
  off += appIdLen;
  u32(); // issue ts
  u32(); // expiry
  u32(); // salt
  u16(); // service count
  u16(); // service type (1 = RTC)
  const count = u16();
  const keys = [];
  for (let i = 0; i < count; i++) { keys.push(u16()); u32(); }
  return keys;
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "agora-token-privileges-test-secret";
  const env = {
    DB, SESSION_SECRET: secret,
    AGORA_APP_ID: "0123456789abcdef0123456789abcdef",
    AGORA_APP_CERTIFICATE: "abcdef0123456789abcdef0123456789",
  };
  async function request(path, { method = "GET", body, token, deviceKey } = {}) {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (token) headers.set("authorization", `Bearer ${token}`);
    if (deviceKey) headers.set("x-device-id", deviceKey);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  }
  const ts = Date.now();
  const insertUser = sqlite.prepare("INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES(?,?,?,?,?)");
  for (const id of ["owner", "seated", "listener", "caller", "receiver"]) {
    insertUser.run(id, id, 1000000, ts, ts);
  }
  sqlite.prepare(
    "INSERT INTO rooms(id,owner_user_id,name,seat_count,locked,vip_only,country_code,created_at,updated_at) VALUES(?,?,?,?,0,0,'IN',?,?)",
  ).run("room-1", "owner", "room 1", 12, ts, ts);
  const insertMember = sqlite.prepare(
    "INSERT INTO room_members(room_id,user_id,seat_index,mic_muted,joined_at,updated_at) VALUES(?,?,?,?,?,?)",
  );
  insertMember.run("room-1", "owner", null, 1, ts, ts);
  insertMember.run("room-1", "seated", 3, 1, ts, ts);
  insertMember.run("room-1", "listener", null, 1, ts, ts);
  sqlite.prepare(
    "INSERT INTO game_rooms(id,owner_user_id,name,created_at,updated_at) VALUES(?,?,?,?,?)",
  ).run("game-1", "owner", "game 1", ts, ts);
  sqlite.prepare(
    "INSERT INTO game_room_members(room_id,user_id,seat_index,joined_at) VALUES(?,?,?,?)",
  ).run("game-1", "seated", 2, ts);
  sqlite.prepare(
    "INSERT INTO direct_calls(id,caller_user_id,receiver_user_id,state,created_at,updated_at) VALUES(?,?,?,?,?,?)",
  ).run("call-1", "caller", "receiver", "active", ts, ts);
  const tokens = {};
  for (const id of ["owner", "seated", "listener", "caller", "receiver"]) {
    tokens[id] = await sessionToken(id, secret);
  }
  async function mintToken(userId, roomId, roomType) {
    const result = await request("/agora/token", {
      method: "POST", token: tokens[userId],
      body: { room_id: roomId, room_type: roomType },
    });
    assert.equal(result.status, 200, JSON.stringify(result.body));
    return result.body.token;
  }
  return { sqlite, request, tokens, mintToken };
}

test("a seatless party listener gets a join-only token", async () => {
  const { mintToken } = await fixture();
  const privileges = decodeAgoraPrivileges(await mintToken("listener", "room-1", "party"));
  assert.deepEqual(privileges, [1]);
});

test("a seated party member keeps the full token", async () => {
  const { mintToken } = await fixture();
  const privileges = decodeAgoraPrivileges(await mintToken("seated", "room-1", "party"));
  assert.deepEqual(privileges, [1, 2, 3, 4]);
});

test("a seatless room owner keeps the full token (the host speaks without a seat)", async () => {
  const { mintToken } = await fixture();
  const privileges = decodeAgoraPrivileges(await mintToken("owner", "room-1", "party"));
  assert.deepEqual(privileges, [1, 2, 3, 4]);
});

test("a direct call gets join + publish audio only, never video or data", async () => {
  const { mintToken } = await fixture();
  const privileges = decodeAgoraPrivileges(await mintToken("caller", "call-call-1", "call"));
  assert.deepEqual(privileges, [1, 2]);
});

test("a game room member keeps the full token (always seated)", async () => {
  const { mintToken } = await fixture();
  const privileges = decodeAgoraPrivileges(await mintToken("seated", "game-1", "game"));
  assert.deepEqual(privileges, [1, 2, 3, 4]);
});

test("a non-member still gets room_membership_required, not a listener token", async () => {
  const { request, tokens } = await fixture();
  const result = await request("/agora/token", {
    method: "POST", token: tokens.caller,
    body: { room_id: "room-1", room_type: "party" },
  });
  assert.equal(result.status, 403);
  assert.equal(result.body.error, "room_membership_required");
});

test("/agora/token honours maintenance mode like the rest of the API", async () => {
  const { sqlite, request, tokens } = await fixture();
  sqlite.prepare(
    "INSERT INTO owner_settings(key,value_json,updated_at) VALUES(?,?,?) ON CONFLICT(key) DO UPDATE SET value_json=excluded.value_json,updated_at=excluded.updated_at",
  ).run("maintenance", JSON.stringify({ enabled: true, message: "down for work" }), Date.now());
  const down = await request("/agora/token", {
    method: "POST", token: tokens.seated,
    body: { room_id: "room-1", room_type: "party" },
  });
  assert.equal(down.status, 503);
  assert.equal(down.body.error, "maintenance");
  sqlite.prepare("DELETE FROM owner_settings WHERE key=?").run("maintenance");
  const up = await request("/agora/token", {
    method: "POST", token: tokens.seated,
    body: { room_id: "room-1", room_type: "party" },
  });
  assert.equal(up.status, 200);
});

test("a banned device is blocked on the token fetch when it sends x-device-id", async () => {
  const { sqlite, request, tokens } = await fixture();
  sqlite.prepare(
    `CREATE TABLE IF NOT EXISTS owner_device_bans (
      device_key TEXT PRIMARY KEY,
      user_id TEXT,
      banned INTEGER NOT NULL DEFAULT 1,
      note TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL
    )`,
  ).run();
  sqlite.prepare(
    "INSERT INTO owner_device_bans(device_key,user_id,banned,note,updated_at) VALUES(?,?,?,?,?)",
  ).run("banned-device-1", "listener", 1, "", Date.now());
  const banned = await request("/agora/token", {
    method: "POST", token: tokens.listener, deviceKey: "banned-device-1",
    body: { room_id: "room-1", room_type: "party" },
  });
  assert.equal(banned.status, 403);
  assert.equal(banned.body.error, "device_banned");
  const allowed = await request("/agora/token", {
    method: "POST", token: tokens.listener, deviceKey: "some-other-device",
    body: { room_id: "room-1", room_type: "party" },
  });
  assert.equal(allowed.status, 200);
});
