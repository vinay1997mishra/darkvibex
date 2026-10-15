import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/index.js", import.meta.url), "utf8");

test("live room polling advances Aladdin mic-time tasks for the host", () => {
  const membersRoute = source.indexOf('parts[3] === "members"');
  assert.notEqual(membersRoute, -1);
  const snippet = source.slice(membersRoute, membersRoute + 7000);
  assert.match(snippet, /SELECT owner_user_id FROM rooms/);
  assert.match(snippet, /String\(lampOwner\?\.owner_user_id \?\? ""\) === actorId/);
  assert.match(snippet, /sampleLampMicProgress\(db, roomId, now\(\)\)/);
});
