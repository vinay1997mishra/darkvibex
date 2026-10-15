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

test("public room discovery excludes rooms with no members", () => {
  const guard =
    "EXISTS (\n          SELECT 1 FROM room_members visible_member";
  assert.ok(workerSource.includes(guard));
  assert.ok(
    workerSource.includes(
      "WHERE visible_member.room_id = r.id",
    ),
  );
  assert.ok(
    workerSource.includes(
      "remoteRooms",
    ) === false,
    "worker should not contain mobile room list code",
  );
});

test("mobile room state defensively drops zero-online rooms", () => {
  const filter =
    "(int.tryParse(row['online']?.toString() ?? '') ?? 0) > 0";
  assert.equal(
    appStateSource.split(filter).length - 1,
    2,
    "initial load and refresh must both filter empty rooms",
  );
});
