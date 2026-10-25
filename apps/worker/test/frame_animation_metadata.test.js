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
  for (const id of [
    "frame_blue_magic_butterfly",
    "frame_golden_butterfly_queen",
    "frame_purple_dream_butterfly",
    "frame_neon_butterfly",
    "frame_crystal_aurora",
    "frame_neon_comet",
    "frame_rose_galaxy",
    "frame_solar_empress",
    "frame_emerald_dragon",
  ]) {
    assert.ok(cosmeticsSource.includes(`id: "${id}"`), `missing catalog item ${id}`);
  }
  assert.ok(cosmeticsSource.includes('animation_type: "butterfly_wings_flight"'));
  for (const type of ["aurora_orbit", "comet_trail", "rose_orbit", "crown_radiance", "dragon_wings"]) {
    assert.ok(cosmeticsSource.includes(`animation_type: "${type}"`), `missing animation type ${type}`);
  }
});

// Deploy gate: frame animation metadata is live with the mobile motif renderer.
