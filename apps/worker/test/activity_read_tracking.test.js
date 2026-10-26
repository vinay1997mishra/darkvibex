import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const social = await readFile(new URL("../src/tinni_social.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");

test("activity feed exposes persistent per-user read state", () => {
  assert.match(social, /CREATE TABLE IF NOT EXISTS activity_read_receipts/);
  assert.match(social, /SELECT item_id FROM activity_read_receipts WHERE user_id=\?/);
  assert.match(social, /is_read: readItemIds\.has\(String\(item\.id\)\)/);
});

test("activity read endpoint accepts only visible activity IDs for the signed-in user", () => {
  assert.match(worker, /url\.pathname === "\/api\/messages\/activity\/read" && request\.method === "POST"/);
  assert.match(worker, /markActivityRead\(/);
  assert.match(social, /visibleIds = new Set\(\(await activityFeed\(db, userId\)\)\.map\(\(item\) => item\.id\)\)/);
  assert.match(social, /INSERT OR IGNORE INTO activity_read_receipts/);
});

test("activity read receipts are capped to a bounded recent history", () => {
  assert.match(social, /ORDER BY read_at DESC LIMIT 500/);
});
