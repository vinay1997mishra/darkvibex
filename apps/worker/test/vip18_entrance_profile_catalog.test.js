import test from "node:test";
import assert from "node:assert/strict";
import { COSMETIC_CATALOG } from "../src/cosmetics.js";

test("DarkVibeX has 18 independently gated entrance nameplates and full profile cards", () => {
  for (const [kind, prefix] of [["entry", "entrance-vip-"], ["profile_card", "profile-vip-"]]) {
    const items = COSMETIC_CATALOG
      .filter((item) => item.kind === kind && item.id.startsWith(prefix))
      .sort((a, b) => a.min_vip_level - b.min_vip_level);
    assert.equal(items.length, 18, `expected 18 ${kind} cosmetics`);
    for (let level = 1; level <= 18; level += 1) {
      const item = items[level - 1];
      assert.equal(item.id, `${prefix}${String(level).padStart(2, "0")}`);
      assert.equal(item.min_vip_level, level);
      assert.equal(item.tier, level);
      assert.equal(item.duration_days, 30);
      assert.equal(item.price_coins, 0, "prices remain owner-configurable and free by default");
    }
  }
});
