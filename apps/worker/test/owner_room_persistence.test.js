import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const workerSource = readFileSync(
  fileURLToPath(new URL("../src/index.js", import.meta.url)),
  "utf8",
);

test("permanent room creation returns the existing owner's room", () => {
  const start = workerSource.indexOf('if (url.pathname === "/api/rooms" && request.method === "POST")');
  const end = workerSource.indexOf('if (parts[0] === "api" && parts[1] === "rooms" && parts.length === 4 && parts[3] === "delete"', start);
  assert.ok(start >= 0 && end > start, "room create route must remain present");
  const route = workerSource.slice(start, end);
  assert.ok(route.includes("existing: true"));
  assert.ok(route.includes('String(existingRoomId.owner_user_id ?? "") !== ownerId'));
  assert.ok(route.includes("room_id: roomId"));
  assert.ok(route.includes('WHERE r.id=? LIMIT 1'));
});

test("the permanent owner room remains visible without online users", () => {
  const start = workerSource.indexOf("async function listRooms(db, viewerUserId)");
  const end = workerSource.indexOf("\nasync function ", start + 12);
  assert.ok(start >= 0 && end > start, "room list function must remain present");
  const route = workerSource.slice(start, end);
  assert.ok(route.includes("r.owner_user_id = ?"));
  assert.ok(route.includes("OR ("));
});
