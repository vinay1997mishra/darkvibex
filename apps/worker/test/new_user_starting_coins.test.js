import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");

test("new DarkVibeX IDs receive 500000 coins only on first creation", () => {
  assert.match(
    worker,
    /VALUES \(\?, \?, 'user', 500000, 120, 0, \?, \?\)/
  );
  assert.match(worker, /ON CONFLICT\(id\) DO UPDATE SET/);
  assert.doesNotMatch(
    worker,
    /ON CONFLICT\(id\) DO UPDATE SET[\s\S]{0,300}coins\s*=/
  );
});
