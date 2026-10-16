import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const workerSource = readFileSync(
  fileURLToPath(new URL("../src/index.js", import.meta.url)),
  "utf8",
);
const appStateSource = readFileSync(
  fileURLToPath(
    new URL("../../mobile/lib/app/app_state.dart", import.meta.url),
  ),
  "utf8",
);
const homeSource = readFileSync(
  fileURLToPath(
    new URL("../../mobile/lib/screens/home_shell.dart", import.meta.url),
  ),
  "utf8",
);

test("public room discovery hides empty rooms but owner can recover own room", () => {
  assert.ok(
    workerSource.includes("r.owner_user_id = ?"),
    "owner must receive their own room even when presence is empty",
  );
  assert.ok(
    workerSource.includes(
      "SELECT 1 FROM room_members visible_member",
    ),
  );
  assert.ok(
    workerSource.includes(
      "WHERE visible_member.room_id = r.id",
    ),
  );
});

test("mobile state retains own empty room while public surfaces filter it", () => {
  const ownerAwareFilter =
    "return online > 0 || ownerId == userId;";
  assert.equal(
    appStateSource.split(ownerAwareFilter).length - 1,
    2,
    "initial load and refresh must preserve the viewer's own room",
  );
  assert.ok(
    homeSource.includes(".where((room) => room.online > 0)"),
    "Party/Discover/followed public surfaces must still hide empty rooms",
  );
});

test("creating an already-owned permanent room ID is idempotent", () => {
  assert.ok(
    workerSource.includes(
      'String(existingRoomId.owner_user_id ?? "") !== ownerId',
    ),
  );
  assert.ok(workerSource.includes("existing: true"));
  assert.ok(workerSource.includes("room_id: roomId"));
});

test("owner room is returned regardless of country/presence so My room never falls back to Create", () => {
  assert.ok(
    workerSource.includes("r.owner_user_id = ?"),
    "owner room must bypass public country/presence visibility rules",
  );
  assert.ok(
    workerSource.includes("ORDER BY CASE WHEN r.owner_user_id = ? THEN 0 ELSE 1 END"),
    "owner room should be prioritized in the room payload",
  );
  assert.equal(
    workerSource.includes("if (!viewerCountry) return [];"),
    false,
    "missing/changed country must not hide an already-created owner room",
  );
});
