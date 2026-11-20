// Email OTP security (audit fix, Vinay 2026-11-20): a verified OTP row
// used to stay in the table, so the same code could be re-verified
// without limit to mint more setup tokens; and the 5-attempt cap reset
// with every new request_id. Now the row is deleted on success
// (single-use) and at most 5 codes may be started per email per hour.
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
async function otpHash(secret, requestId, email, otp) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${requestId}|${email}|${otp}`));
  return base64url(new Uint8Array(signature));
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "email-otp-security-test-secret";
  const env = { DB, SESSION_SECRET: secret, RESEND_API_KEY: "test-key", EMAIL_FROM: "test@darkvibex.test" };
  const request = async (path, { method = "GET", body } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, env, request, secret };
}

async function seedOtp(fx, { requestId, email, otp, createdAt = Date.now() }) {
  // The OTP tables are created by ensureEmailAuthSchema inside the worker;
  // create them here first so the seed row can be inserted directly.
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS email_otp_requests (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL,
      purpose TEXT NOT NULL,
      otp_hash TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      verified INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )`);
  fx.sqlite.exec(`CREATE TABLE IF NOT EXISTS email_setup_tokens (
      token_hash TEXT PRIMARY KEY,
      email TEXT NOT NULL,
      purpose TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )`);
  const hash = await otpHash(fx.secret, requestId, email, otp);
  fx.sqlite.prepare(
    "INSERT INTO email_otp_requests(id,email,purpose,otp_hash,expires_at,attempts,verified,created_at) VALUES(?,?,?,?,?,0,0,?)"
  ).run(requestId, email, "signup", hash, createdAt + 10 * 60 * 1000, createdAt);
}

test("a correct OTP verifies once and cannot be verified again", async () => {
  const fx = await fixture();
  await seedOtp(fx, { requestId: "otp-test-1", email: "user@example.com", otp: "123456" });
  const first = await fx.request("/api/session/email/verify", {
    method: "POST", body: { request_id: "otp-test-1", otp: "123456" },
  });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.ok(first.body.setup_token, "a setup token must be issued");
  assert.equal(first.body.email, "user@example.com");

  assert.equal(
    fx.sqlite.prepare("SELECT id FROM email_otp_requests WHERE id=?").get("otp-test-1"),
    undefined,
    "the OTP row must be deleted on success",
  );
  assert.equal(
    fx.sqlite.prepare("SELECT COUNT(*) AS n FROM email_setup_tokens").get().n, 1,
    "exactly one setup token must exist",
  );

  const second = await fx.request("/api/session/email/verify", {
    method: "POST", body: { request_id: "otp-test-1", otp: "123456" },
  });
  assert.equal(second.status, 400);
  assert.equal(second.body.error, "otp_request_not_found");
  assert.equal(
    fx.sqlite.prepare("SELECT COUNT(*) AS n FROM email_setup_tokens").get().n, 1,
    "no second setup token may be minted from the same code",
  );
});

test("five wrong guesses lock the code, even for the right OTP after", async () => {
  const fx = await fixture();
  await seedOtp(fx, { requestId: "otp-test-2", email: "user@example.com", otp: "123456" });
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const wrong = await fx.request("/api/session/email/verify", {
      method: "POST", body: { request_id: "otp-test-2", otp: "000000" },
    });
    assert.equal(wrong.status, 400, JSON.stringify(wrong.body));
    assert.equal(wrong.body.error, "invalid_otp");
  }
  const locked = await fx.request("/api/session/email/verify", {
    method: "POST", body: { request_id: "otp-test-2", otp: "123456" },
  });
  assert.equal(locked.status, 400);
  assert.equal(locked.body.error, "otp_attempts_exceeded");
});

test("at most 5 codes may be started per email per hour", async () => {
  const fx = await fixture();
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({ id: "fake" }), { status: 200 });
  try {
    const now = Date.now();
    for (let i = 0; i < 5; i += 1) {
      await seedOtp(fx, { requestId: `otp-hour-${i}`, email: "busy@example.com", otp: "123456", createdAt: now - (10 + i * 10) * 60 * 1000 });
    }
    const blocked = await fx.request("/api/session/email/start", {
      method: "POST", body: { email: "busy@example.com", purpose: "signup" },
    });
    assert.equal(blocked.status, 400, JSON.stringify(blocked.body));
    assert.equal(blocked.body.error, "otp_too_many_requests");
  } finally {
    globalThis.fetch = realFetch;
  }
});

test("a start under the hourly cap succeeds", async () => {
  const fx = await fixture();
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({ id: "fake" }), { status: 200 });
  try {
    const now = Date.now();
    for (let i = 0; i < 4; i += 1) {
      await seedOtp(fx, { requestId: `otp-ok-${i}`, email: "calm@example.com", otp: "123456", createdAt: now - (10 + i * 10) * 60 * 1000 });
    }
    const started = await fx.request("/api/session/email/start", {
      method: "POST", body: { email: "calm@example.com", purpose: "signup" },
    });
    assert.equal(started.status, 201, JSON.stringify(started.body));
    assert.ok(started.body.request_id);
  } finally {
    globalThis.fetch = realFetch;
  }
});
