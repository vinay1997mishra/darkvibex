import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const workerSource = readFileSync(
  fileURLToPath(new URL("../src/index.js", import.meta.url)),
  "utf8",
);

test("room message POST returns the created message payload", () => {
  assert.ok(
    workerSource.includes("message: createdMessage ??"),
    "mobile must receive the just-created message without waiting for another poll",
  );
  assert.ok(workerSource.includes("created_at: createdAt"));
  assert.ok(workerSource.includes("active_bubble_id"));
});

test("room message history uses stable newest-first ordering", () => {
  assert.ok(
    workerSource.includes("ORDER BY m.created_at DESC, m.id DESC LIMIT 100"),
    "messages with the same timestamp still need deterministic ordering",
  );
});
