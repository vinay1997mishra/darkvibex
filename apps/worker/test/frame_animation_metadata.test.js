import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const cosmeticsSource = readFileSync(
  fileURLToPath(new URL("../src/cosmetics.js", import.meta.url)),
  "utf8",
);

test("accepted frames expose per-element animation metadata", () => {
  assert.ok(cosmeticsSource.includes('animation_type: "butterfly_wings"'));
  assert.ok(cosmeticsSource.includes('animation_type: "crown_shine"'));
  assert.ok(cosmeticsSource.includes('animation_type: "heart_pulse"'));
  assert.ok(cosmeticsSource.includes('animation_type: "wing_shimmer"'));
  assert.ok(cosmeticsSource.includes('animation_type: "petal_sparkle"'));
  assert.ok(cosmeticsSource.includes("animation_ms: 2000"));
});
