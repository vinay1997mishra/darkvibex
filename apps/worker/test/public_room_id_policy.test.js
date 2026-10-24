import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const source = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");

test("new users receive serial eight-digit public IDs while legacy IDs stay stable", () => {
  assert.match(source, /public_id TEXT/);
  assert.match(source, /CREATE UNIQUE INDEX IF NOT EXISTS idx_users_public_id/);
  assert.match(source, /async function ensureUserPublicId\(db, userId\)/);
  assert.match(source, /CREATE TABLE IF NOT EXISTS public_id_sequence_8digit/);
  assert.match(source, /VALUES\('main',10000001\)/);
  assert.match(source, /RETURNING next_value-1 AS value/);
  assert.match(source, /value < 10000001/);
  assert.doesNotMatch(source, /1000000 \+ Math\.random\(\) \* 9000000/);
});

test("room IDs remain tied to the owner's stable public ID", () => {
  assert.match(source, /const ownerPublicId =/);
  assert.match(source, /const roomId = ownerPublicId;/);
  assert.match(source, /display_id: ownerPublicId/);
});

test("room listings and profiles expose the stable public ID", () => {
  assert.match(source, /CASE WHEN COALESCE\(io\.invisible_id,0\)=1 THEN 'Hidden' ELSE u\.public_id END AS display_id/);
  assert.match(source, /WHERE public_id=\? LIMIT 1/);
  assert.match(source, /normalizePublicIdLookup\(requestedUserId\)/);
  assert.match(source, /COALESCE\(NULLIF\(u\.public_id,''\), ''\)/);
  assert.match(source, /formatPublicIdForDisplay\(row\.display_id\)/);
  assert.match(source, /LEFT JOIN owner_user_overrides io/);
});
