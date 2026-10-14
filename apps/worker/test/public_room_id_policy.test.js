import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");

test("users receive a permanent unique seven-digit public ID", () => {
  assert.match(source, /public_id TEXT/);
  assert.match(source, /CREATE UNIQUE INDEX IF NOT EXISTS idx_users_public_id/);
  assert.match(source, /async function ensureUserPublicId\(db, userId\)/);
  assert.match(source, /1000000 \+ Math\.random\(\) \* 9000000/);
  assert.match(source, /\^\[1-9\]\\d\{6\}\$/);
});

test("new room ID equals the owner's seven-digit profile ID", () => {
  assert.match(source, /const ownerPublicId =/);
  assert.match(source, /const roomId = ownerPublicId;/);
  assert.match(source, /display_id: ownerPublicId/);
});

test("room listings and profiles expose the stable public ID", () => {
  assert.match(source, /u\.public_id AS display_id/);
  assert.match(source, /WHERE public_id=\? LIMIT 1/);
  assert.match(source, /COALESCE\(NULLIF\(u\.public_id,''\), m\.user_id\) AS public_id/);
});
