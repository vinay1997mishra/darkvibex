import test from "node:test";
import assert from "node:assert/strict";
import { COSMETIC_CATALOG } from "../src/cosmetics.js";

test("cosmetics shop has distinct frame and vehicle tiers with finite coin prices", () => {
  const ids = new Set();
  for (const item of COSMETIC_CATALOG) {
    assert.ok(!ids.has(item.id), `duplicate cosmetic ${item.id}`);
    ids.add(item.id);
    assert.ok(["frame", "vehicle"].includes(item.kind));
    assert.ok(Number.isSafeInteger(item.price_coins) && item.price_coins > 0);
    assert.ok(Number.isSafeInteger(item.min_vip_level) && item.min_vip_level >= 1 && item.min_vip_level <= 18);
    assert.equal(item.duration_days, 30);
  }
  assert.equal(COSMETIC_CATALOG.filter((item) => item.kind === "frame").length, 4);
  assert.equal(COSMETIC_CATALOG.filter((item) => item.kind === "vehicle").length, 4);
  assert.equal(COSMETIC_CATALOG.find((item) => item.id === "vehicle_king").min_vip_level, 18);
});
