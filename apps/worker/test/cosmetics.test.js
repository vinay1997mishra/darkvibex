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

  assert.equal(COSMETIC_CATALOG.filter((item) => item.kind === "frame").length, 19);
  assert.ok(
    COSMETIC_CATALOG.every((item) => item.price_coins === 0),
    "all current cosmetics should stay free until the owner sets prices",
  );
  const permanentFreeFrames = COSMETIC_CATALOG.filter(
    (item) =>
      item.kind === "frame" &&
      item.price_coins === 0 &&
      item.duration_days === 0,
  );
  assert.equal(permanentFreeFrames.length, 15);
  for (const frame of permanentFreeFrames) {
    assert.equal(frame.min_vip_level, 0);
  }
  assert.equal(COSMETIC_CATALOG.filter((item) => item.kind === "vehicle").length, 4);
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
