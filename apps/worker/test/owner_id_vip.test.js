// Owner Panel: Public ID of ANY length (1–9 digits) + Give VIP by ID
// (Mr. Wrong, 2026-11-24 — "apne man se agar 1 single digit id bhi
// active karni hai to ho jaani chahiye owner panel se"). A short ID
// must also survive the user's next login (ensureUser must not replace
// it with an auto 8-digit number) and show as it is in the app.
import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";

let moduleCounter = 0;

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

const OWNER_TOKEN = "owner-test-token";
const sha256 = (value) => createHash("sha256").update(String(value)).digest("hex");

async function ownerSetup() {
  const { handleOwnerApi } = await import(
    `../src/owner_api.js?fresh=${++moduleCounter}`
  );
  const db = new D1Mock(new DatabaseSync(":memory:"));
  const env = { DB: db, OWNER_ADMIN_TOKEN: OWNER_TOKEN };
  await handleOwnerApi(
    new Request("https://owner.test/api/owner/session"),
    env,
    new URL("https://owner.test/api/owner/session"),
  );

  async function call(path, { method = "GET", token = null, body = null } = {}) {
    const headers = {};
    if (token) headers.authorization = `Bearer ${token}`;
    const init = { method, headers };
    if (body != null) {
      headers["content-type"] = "application/json";
      init.body = JSON.stringify(body);
    }
    const response = await handleOwnerApi(
      new Request(`https://owner.test${path}`, init),
      env,
      new URL(`https://owner.test${path}`),
    );
    const text = await response.text();
    let parsed = null;
    try { parsed = JSON.parse(text); } catch (_) { /* non-JSON body */ }
    return { status: response.status, body: parsed, text };
  }

  return { db, env, call };
}

async function makeStaff(db, id, permissions) {
  const token = `staff-token-${id}`;
  const nowMs = Date.now();
  await db.prepare(
    `INSERT INTO owner_staff(id,display_name,role,token_hash,email,password_salt,password_hash,password_iterations,permissions_json,enabled,created_at,updated_at)
     VALUES(?,?,?,?,?,?,?,?,?,?,?,?)`
  ).bind(id, `Staff ${id}`, "admin", sha256(`legacy-${id}`), "", "", "", 120000, JSON.stringify(permissions), 1, nowMs, nowMs).run();
  await db.prepare(
    "INSERT INTO owner_staff_sessions(token_hash,staff_id,created_at,expires_at,last_used_at) VALUES(?,?,?,?,?)"
  ).bind(sha256(token), id, nowMs, nowMs + 7 * 24 * 60 * 60 * 1000, nowMs).run();
  return token;
}

async function seedUser(db, id, publicId) {
  const nowMs = Date.now();
  await db.prepare(
    "INSERT INTO users(id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)"
  ).bind(id, publicId, `User ${id}`, "user", 0, 0, 0, nowMs, nowMs).run();
}

async function publicIdOf(db, id) {
  const row = await db.prepare("SELECT public_id FROM users WHERE id=?").bind(id).first();
  return row?.public_id ?? null;
}

// ---- Public ID: any length 1–9 digits ----

test("owner can set a single-digit public ID", async () => {
  const { db, call } = await ownerSetup();
  await seedUser(db, "u1", "12345678");
  const changed = await call("/api/owner/users/u1/public-id", {
    method: "POST",
    token: OWNER_TOKEN,
    body: { public_id: "7" },
  });
  assert.equal(changed.status, 200);
  assert.equal(changed.body.public_id, "7");
  assert.equal(await publicIdOf(db, "u1"), "7");
  // The old ID stays in history, so it can never be re-used by another user.
  const history = await db.prepare("SELECT public_id FROM owner_public_id_history WHERE user_id='u1'").all();
  assert.deepEqual(history.results.map((r) => r.public_id), ["12345678"]);
});

test("owner can set a 9-digit public ID, leading zeros collapse to one ID", async () => {
  const { db, call } = await ownerSetup();
  await seedUser(db, "u1", "12345678");
  const nine = await call("/api/owner/users/u1/public-id", {
    method: "POST",
    token: OWNER_TOKEN,
    body: { public_id: "123456789" },
  });
  assert.equal(nine.status, 200);
  assert.equal(await publicIdOf(db, "u1"), "123456789");
  const padded = await call("/api/owner/users/u1/public-id", {
    method: "POST",
    token: OWNER_TOKEN,
    body: { public_id: "007" },
  });
  assert.equal(padded.status, 200);
  assert.equal(padded.body.public_id, "7");
  assert.equal(await publicIdOf(db, "u1"), "7");
});

test("public ID rejects zero, 10 digits and non-digits", async () => {
  const { db, call } = await ownerSetup();
  await seedUser(db, "u1", "12345678");
  for (const bad of ["0", "000", "1234567890", "12a34", ""]) {
    const res = await call("/api/owner/users/u1/public-id", {
      method: "POST",
      token: OWNER_TOKEN,
      body: { public_id: bad },
    });
    assert.equal(res.status, 400, bad);
    assert.equal(res.body.error, "public_id_must_be_1_to_999999999", bad);
  }
  assert.equal(await publicIdOf(db, "u1"), "12345678");
});

test("public ID change needs the permission and refuses taken IDs", async () => {
  const { db, call } = await ownerSetup();
  await seedUser(db, "u1", "12345678");
  await seedUser(db, "u2", "7");
  const staff = await makeStaff(db, "s1", ["users.search"]);
  const denied = await call("/api/owner/users/u1/public-id", {
    method: "POST",
    token: staff,
    body: { public_id: "9" },
  });
  assert.equal(denied.status, 403);
  const taken = await call("/api/owner/users/u1/public-id", {
    method: "POST",
    token: OWNER_TOKEN,
    body: { public_id: "7" },
  });
  assert.equal(taken.status, 409);
  assert.equal(taken.body.error, "public_id_already_used");
});

// ---- Give VIP by ID ----

test("owner can grant VIP to a user by public ID, and re-grant replaces it", async () => {
  const { db, call } = await ownerSetup();
  await seedUser(db, "u1", "7");
  const before = Date.now();
  const granted = await call("/api/owner/vip-grant", {
    method: "POST",
    token: OWNER_TOKEN,
    body: { public_id: "7", level: 3, days: 30 },
  });
  assert.equal(granted.status, 200);
  assert.equal(granted.body.user.id, "u1");
  assert.equal(granted.body.grant.level, 3);
  assert.equal(granted.body.grant.source, "owner_grant");
  assert.ok(granted.body.grant.expires_at >= before + 30 * 86400000 - 60000);
  const rows = await db.prepare("SELECT level, source FROM vip_grants WHERE user_id='u1'").all();
  assert.deepEqual(rows.results.map((r) => ({ level: r.level, source: r.source })), [{ level: 3, source: "owner_grant" }]);
  const mirror = await db.prepare("SELECT vip_level FROM users WHERE id='u1'").first();
  assert.equal(mirror.vip_level, 3);

  const regranted = await call("/api/owner/vip-grant", {
    method: "POST",
    token: OWNER_TOKEN,
    body: { public_id: "7", level: 5, days: 60 },
  });
  assert.equal(regranted.status, 200);
  assert.equal(regranted.body.grant.level, 5);
  const rowsAfter = await db.prepare("SELECT level, source FROM vip_grants WHERE user_id='u1'").all();
  assert.equal(rowsAfter.results.length, 1);
  assert.equal(rowsAfter.results[0].level, 5);
});

test("VIP grant validates the ID, level and days, and needs the permission", async () => {
  const { db, call } = await ownerSetup();
  await seedUser(db, "u1", "7");
  const staff = await makeStaff(db, "s1", ["users.search"]);
  const denied = await call("/api/owner/vip-grant", {
    method: "POST",
    token: staff,
    body: { public_id: "7", level: 3, days: 30 },
  });
  assert.equal(denied.status, 403);
  const unknown = await call("/api/owner/vip-grant", {
    method: "POST",
    token: OWNER_TOKEN,
    body: { public_id: "999", level: 3, days: 30 },
  });
  assert.equal(unknown.status, 404);
  assert.equal(unknown.body.error, "user_not_found");
  for (const [level, days, error] of [[0, 30, "vip_level_must_be_1_to_18"], [19, 30, "vip_level_must_be_1_to_18"], [3, 0, "vip_days_must_be_1_to_365"], [3, 366, "vip_days_must_be_1_to_365"]]) {
    const res = await call("/api/owner/vip-grant", {
      method: "POST",
      token: OWNER_TOKEN,
      body: { public_id: "7", level, days },
    });
    assert.equal(res.status, 400, `${level}/${days}`);
    assert.equal(res.body.error, error, `${level}/${days}`);
  }
});

// ---- A short ID survives the user's next login ----

const base64url = (bytes) => Buffer.from(bytes).toString("base64url");
async function sessionToken(userId, secret) {
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: userId, exp: Math.floor(Date.now() / 1000) + 3600 })}`;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

async function workerFixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const signingKey = "owner-id-vip-test-1234";
  const env = { DB, SESSION_SECRET: signingKey, OWNER_ADMIN_TOKEN: OWNER_TOKEN };
  const call = async (path, { method = "GET", body, userId, headers = {} } = {}) => {
    const requestHeaders = new Headers(headers);
    if (body != null) requestHeaders.set("content-type", "application/json");
    if (userId) requestHeaders.set("authorization", `Bearer ${await sessionToken(userId, signingKey)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers: requestHeaders, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, env, call };
}

test("a single-digit ID survives the next login; a new user still gets 8 digits", async () => {
  const { sqlite, call } = await workerFixture();
  const nowMs = Date.now();
  sqlite.prepare("INSERT INTO users(id,public_id,display_name,role,coins,diamonds,vip_level,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)").run("shorty", "7", "Shorty", "user", 0, 0, 0, nowMs, nowMs);
  const again = await call("/api/users/upsert", {
    method: "POST",
    userId: "shorty",
    body: { user_id: "shorty", display_name: "Shorty" },
  });
  assert.equal(again.status, 200);
  assert.equal(again.body.user.public_id, "7");
  assert.equal(sqlite.prepare("SELECT public_id FROM users WHERE id='shorty'").get().public_id, "7");

  const fresh = await call("/api/users/upsert", {
    method: "POST",
    userId: "newbie",
    body: { user_id: "newbie", display_name: "Newbie" },
  });
  assert.equal(fresh.status, 200);
  assert.match(fresh.body.user.public_id, /^\d{8}$/);
});
