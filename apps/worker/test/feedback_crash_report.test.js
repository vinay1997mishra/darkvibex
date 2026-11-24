// Report a Problem + automatic crash reports (Mr. Wrong, 2026-11-24):
// feedback carries auto device info + an optional private-bucket
// screenshot; the app sends uncaught crashes here on its own (max 5
// per user per hour); the owner lists both in the Owner Panel.
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

const OWNER_TOKEN = "owner-test-token";

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "feedback-crash-test-secret";
  const files = new Map();
  const env = {
    DB,
    SESSION_SECRET: "feedback-crash-test-secret",
    OWNER_ADMIN_TOKEN: OWNER_TOKEN,
    ID_FILES: {
      async get(key) {
        if (!files.has(key)) return null;
        return { body: files.get(key) };
      },
      async put(key, value) { files.set(key, value); },
    },
  };
  const call = async (path, { method = "GET", body, userId, token, headers = {} } = {}) => {
    const requestHeaders = new Headers(headers);
    if (body != null) requestHeaders.set("content-type", "application/json");
    if (userId) requestHeaders.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    if (token) requestHeaders.set("authorization", `Bearer ${token}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers: requestHeaders, body: body == null ? undefined : JSON.stringify(body) }), env);
    const text = await response.text();
    let parsed = null;
    try { parsed = JSON.parse(text); } catch (_) { /* non-JSON body */ }
    return { status: response.status, body: parsed, text };
  };
  return { sqlite, DB, env, files, call };
}

async function seedUser(call, userId) {
  const upsert = await call("/api/users/upsert", {
    method: "POST",
    userId,
    body: { user_id: userId, display_name: `User ${userId}` },
  });
  assert.equal(upsert.status, 200);
}

test("feedback stores device info + screenshot key, history returns them", async () => {
  const { sqlite, call } = await fixture();
  await seedUser(call, "reporter");
  const sent = await call("/api/feedback", {
    method: "POST",
    userId: "reporter",
    body: {
      user_id: "reporter",
      category: "Bug",
      message: "Spin button does nothing",
      device_info: "Pixel 8, Android 14, app 0.1.0",
      screenshot_key: "users/reporter/misc/feedback-abc123.jpg",
    },
  });
  assert.equal(sent.status, 201);
  assert.equal(sent.body.ok, true);
  const row = sqlite.prepare("SELECT category,message,device_info,screenshot_key FROM user_feedback WHERE user_id='reporter'").get();
  assert.equal(row.category, "Bug");
  assert.equal(row.message, "Spin button does nothing");
  assert.equal(row.device_info, "Pixel 8, Android 14, app 0.1.0");
  assert.equal(row.screenshot_key, "users/reporter/misc/feedback-abc123.jpg");
  const history = await call("/api/feedback?user_id=reporter", { userId: "reporter" });
  assert.equal(history.status, 200);
  assert.equal(history.body.feedback.length, 1);
  assert.equal(history.body.feedback[0].device_info, "Pixel 8, Android 14, app 0.1.0");
  assert.equal(history.body.feedback[0].screenshot_key, "users/reporter/misc/feedback-abc123.jpg");
});

test("feedback rejects a screenshot key outside the user's own misc folder", async () => {
  const { call } = await fixture();
  await seedUser(call, "reporter");
  const sent = await call("/api/feedback", {
    method: "POST",
    userId: "reporter",
    body: {
      user_id: "reporter",
      category: "Bug",
      message: "Bad key",
      screenshot_key: "users/other-user/dp/photo.jpg",
    },
  });
  assert.equal(sent.status, 400);
  assert.equal(sent.body.error, "invalid_screenshot_key");
});

test("crash report is stored with error, stack, route, device and version", async () => {
  const { sqlite, call } = await fixture();
  await seedUser(call, "crasher");
  const sent = await call("/api/crash-report", {
    method: "POST",
    userId: "crasher",
    body: {
      user_id: "crasher",
      error: "Null check operator used on a null value",
      stack: "#0 HomeScreen.build (home.dart:42)",
      route: "FamilyDetail",
      device_info: "Pixel 8, Android 14",
      app_version: "0.1.0",
    },
  });
  assert.equal(sent.status, 201);
  assert.equal(sent.body.ok, true);
  const row = sqlite.prepare("SELECT error,stack,route,device_info,app_version FROM crash_reports WHERE user_id='crasher'").get();
  assert.equal(row.error, "Null check operator used on a null value");
  assert.equal(row.stack, "#0 HomeScreen.build (home.dart:42)");
  assert.equal(row.route, "FamilyDetail");
  assert.equal(row.device_info, "Pixel 8, Android 14");
  assert.equal(row.app_version, "0.1.0");
  const notes = sqlite.prepare("SELECT COUNT(*) AS n FROM owner_notifications WHERE kind='crash'").get();
  assert.equal(notes.n, 1);
});

test("crash report needs a real error and a session", async () => {
  const { call } = await fixture();
  await seedUser(call, "crasher");
  const short = await call("/api/crash-report", {
    method: "POST",
    userId: "crasher",
    body: { user_id: "crasher", error: "x" },
  });
  assert.equal(short.status, 400);
  assert.equal(short.body.error, "crash_error_too_short");
  const anon = await call("/api/crash-report", {
    method: "POST",
    body: { user_id: "crasher", error: "Something broke badly" },
  });
  assert.equal(anon.status, 401);
});

test("crash reports are rate-limited to 5 per user per hour", async () => {
  const { call } = await fixture();
  await seedUser(call, "looper");
  for (let i = 0; i < 5; i++) {
    const sent = await call("/api/crash-report", {
      method: "POST",
      userId: "looper",
      body: { user_id: "looper", error: `Crash number ${i} boom` },
    });
    assert.equal(sent.status, 201);
  }
  const sixth = await call("/api/crash-report", {
    method: "POST",
    userId: "looper",
    body: { user_id: "looper", error: "Crash number 5 boom" },
  });
  assert.equal(sixth.status, 400);
  assert.equal(sixth.body.error, "crash_rate_limited");
});

test("owner lists feedback + crashes, and can open a feedback screenshot", async () => {
  const { files, call } = await fixture();
  await seedUser(call, "reporter");
  await call("/api/feedback", {
    method: "POST",
    userId: "reporter",
    body: {
      user_id: "reporter",
      category: "Bug",
      message: "Join button dead",
      device_info: "Pixel 8",
      screenshot_key: "users/reporter/misc/feedback-shot1.jpg",
    },
  });
  await call("/api/crash-report", {
    method: "POST",
    userId: "reporter",
    body: { user_id: "reporter", error: "Crash on join", route: "TopFamilies" },
  });
  const feedback = await call("/api/owner/feedback", { token: OWNER_TOKEN });
  assert.equal(feedback.status, 200);
  assert.equal(feedback.body.feedback.length, 1);
  assert.equal(feedback.body.feedback[0].message, "Join button dead");
  assert.equal(feedback.body.feedback[0].screenshot_key, "users/reporter/misc/feedback-shot1.jpg");
  const crashes = await call("/api/owner/crash-reports", { token: OWNER_TOKEN });
  assert.equal(crashes.status, 200);
  assert.equal(crashes.body.crashes.length, 1);
  assert.equal(crashes.body.crashes[0].error, "Crash on join");
  const anon = await call("/api/owner/feedback");
  assert.equal(anon.status, 401);
  await files.set("users/reporter/misc/feedback-shot1.jpg", "fake-image-bytes");
  const shot = await call("/api/owner/feedback-screenshot?key=users%2Freporter%2Fmisc%2Ffeedback-shot1.jpg", { token: OWNER_TOKEN });
  assert.equal(shot.status, 200);
  assert.equal(shot.text, "fake-image-bytes");
  const badKey = await call("/api/owner/feedback-screenshot?key=users%2Freporter%2Fdp%2Fphoto.jpg", { token: OWNER_TOKEN });
  assert.equal(badKey.status, 400);
  assert.equal(badKey.body.error, "invalid_feedback_screenshot_key");
});
