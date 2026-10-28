import test from "node:test";
import assert from "node:assert/strict";
import { COSMETIC_CATALOG } from "../src/cosmetics.js";

test("cosmetics shop has valid Tinni-style categories, VIP gates, and finite prices", () => {
  const ids = new Set();
  const allowedKinds = new Set([
    "frame",
    "vehicle",
    "profile_card",
    "ring",
    "profile_background",
    "entry",
    "bubble",
  ]);

  for (const item of COSMETIC_CATALOG) {
    assert.ok(!ids.has(item.id), `duplicate cosmetic ${item.id}`);
    ids.add(item.id);
    assert.ok(allowedKinds.has(item.kind), `unsupported cosmetic kind ${item.kind}`);
    assert.ok(Number.isSafeInteger(item.price_coins) && item.price_coins >= 0);
    assert.ok(
      Number.isSafeInteger(item.min_vip_level) &&
        item.min_vip_level >= 0 &&
        item.min_vip_level <= 18,
    );
    assert.ok(item.duration_days === 0 || item.duration_days === 30);
  }

  assert.equal(COSMETIC_CATALOG.filter((item) => item.kind === "frame").length, 29);
  assert.ok(
    COSMETIC_CATALOG.every((item) => item.price_coins === 0),
    "all current cosmetics should stay free until the owner sets prices",
  );
  const permanentFreeFrames = COSMETIC_CATALOG.filter(
    (item) =>
      item.kind === "frame" &&
      item.price_coins === 0 &&
      item.duration_days === 0 &&
      item.reward_only !== true,
  );
  assert.equal(permanentFreeFrames.length, 21);

  const zeroCoinBuyFrames = COSMETIC_CATALOG.filter((item) =>
    [
      "frame_crystal_aurora",
      "frame_neon_comet",
      "frame_rose_galaxy",
      "frame_solar_empress",
      "frame_emerald_dragon",
    ].includes(item.id),
  );
  assert.equal(zeroCoinBuyFrames.length, 5);
  assert.deepEqual(zeroCoinBuyFrames.map((item) => item.id), [
    "frame_crystal_aurora",
    "frame_neon_comet",
    "frame_rose_galaxy",
    "frame_solar_empress",
    "frame_emerald_dragon",
  ]);
  assert.ok(zeroCoinBuyFrames.every((item) =>
    item.kind === "frame" &&
    item.price_coins === 0 &&
    item.min_vip_level === 0 &&
    item.duration_days === 0 &&
    item.animation_ms === 2000 &&
    item.reward_only !== true
  ));

  const rocketFrames = COSMETIC_CATALOG.filter((item) => item.reward_only === true);
  assert.deepEqual(
    rocketFrames.map((item) => item.id),
    [
      "rocket_frame_aurora",
      "rocket_frame_neon_wings",
      "rocket_frame_golden_comet",
      "rocket_frame_purple_nova",
    ],
  );
  assert.ok(rocketFrames.every((item) =>
    item.kind === "frame" &&
    item.price_coins === 0 &&
    item.min_vip_level === 0 &&
    item.duration_days === 0 &&
    item.animation_ms === 2000
  ));
  for (const frame of permanentFreeFrames) {
    assert.equal(frame.min_vip_level, 0);
  }
  const vehicles = COSMETIC_CATALOG.filter((item) => item.kind === "vehicle");
  assert.equal(vehicles.length, 7);
  for (const id of [
    "vehicle_neon_comet",
    "vehicle_dragon_royal",
    "vehicle_celestial_phoenix",
  ]) {
    const vehicle = vehicles.find((item) => item.id === id);
    assert.ok(vehicle, `missing vehicle store item: ${id}`);
    assert.equal(vehicle.animation_ms, 4800);
    assert.equal(vehicle.duration_days, 30);
  }
  assert.ok(COSMETIC_CATALOG.some((item) => item.kind === "profile_card"));
  assert.ok(COSMETIC_CATALOG.some((item) => item.kind === "ring"));
  assert.ok(COSMETIC_CATALOG.some((item) => item.kind === "profile_background"));
  assert.ok(COSMETIC_CATALOG.some((item) => item.kind === "entry"));
  const bubbles = COSMETIC_CATALOG.filter((item) => item.kind === "bubble");
  assert.equal(bubbles.length, 8);
  assert.deepEqual(
    bubbles.map((item) => item.id),
    [
      "bubble-gold",
      "bubble-heart",
      "bubble-king",
      "bubble-dream",
      "bubble-nature",
      "bubble-dragon",
      "bubble-ice",
      "bubble-sakura",
    ],
  );
  assert.equal(
    COSMETIC_CATALOG.find((item) => item.id === "vehicle_king").min_vip_level,
    18,
  );
});
