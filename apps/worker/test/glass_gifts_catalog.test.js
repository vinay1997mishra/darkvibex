// Glass gifts in the Lucky panel (Vinay, 2026-11-22): 65 glass gifts, all
// 100% full 3D glass with a 100% transparent background, shown in the gift
// box Lucky panel. Each tile shows the gift image only (no square around
// it), a small name below, and the small coin price below the name.
// Prices are Vinay's final list: no price tier has a single gift.
import test from "node:test";
import assert from "node:assert/strict";
import { BASE_GIFT_CATALOG } from "../src/gift_catalog.js";

// (stem, price) — Vinay's final price list, 2026-11-22.
const EXPECTED = new Map([
  // 10 coins x7
  ["cherry", 10], ["balloon", 10], ["music-note", 10], ["tulip", 10],
  ["lotus", 10], ["cloud", 10], ["snowflake", 10],
  // 15 coins x6
  ["heart", 15], ["star", 15], ["moon", 15], ["lightning", 15],
  ["mushroom", 15], ["autumn-leaf", 15],
  // 25 coins x6
  ["cupcake", 25], ["ice-cream", 25], ["strawberry", 25], ["mango", 25],
  ["coral", 25], ["starfish", 25],
  // 30 coins x6
  ["rose", 30], ["butterfly", 30], ["bee", 30], ["sunflower", 30],
  ["jellyfish", 30], ["seahorse", 30],
  // 50 coins x6
  ["cat", 50], ["dog", 50], ["rabbit", 50], ["panda", 50],
  ["frog", 50], ["turtle", 50],
  // 100 coins x6
  ["pot", 100], ["rainbow", 100], ["fireworks", 100], ["guitar", 100],
  ["snowman", 100], ["crab", 100],
  // 150 coins x6
  ["car", 150], ["dolphin", 150], ["swan", 150], ["peacock", 150],
  ["octopus", 150], ["whale", 150],
  // 200 coins x6
  ["lion", 200], ["tiger", 200], ["elephant", 200], ["horse", 200],
  ["penguin", 200], ["owl", 200],
  // 300 coins x4
  ["fox", 300], ["deer", 300], ["koala", 300], ["dragon", 300],
  // 500 coins x4
  ["diamond", 500], ["crown", 500], ["crystal-ball", 500], ["magic-wand", 500],
  // 777 coins x2
  ["unicorn", 777], ["sun", 777],
  // 1000 coins x2
  ["hot-air-balloon", 1000], ["rocket", 1000],
  // 2500 coins x2
  ["treasure-chest", 2500], ["golden-key", 2500],
  // 5000 coins x2
  ["castle", 5000], ["phoenix", 5000],
]);

const glassGifts = BASE_GIFT_CATALOG.filter((g) => g.id.startsWith("glass-"));

test("Lucky panel has exactly 65 glass gifts", () => {
  assert.equal(glassGifts.length, 65);
  assert.equal(EXPECTED.size, 65);
});

test("every glass gift is in the lucky category with its R2 image", () => {
  for (const gift of glassGifts) {
    const stem = gift.id.slice("glass-".length);
    assert.ok(EXPECTED.has(stem), `unexpected glass gift ${gift.id}`);
    assert.equal(gift.category, "lucky", gift.id);
    assert.equal(gift.asset_key, `gifts/glass/${stem}.png`, gift.id);
    assert.equal(gift.coin_cost, EXPECTED.get(stem), gift.id);
    assert.equal(gift.vip_level, 0, gift.id);
    assert.ok(typeof gift.name === "string" && gift.name.length > 0, gift.id);
    assert.ok(typeof gift.emoji === "string" && gift.emoji.length > 0, gift.id);
  }
});

test("no price tier has a single glass gift", () => {
  const perPrice = new Map();
  for (const gift of glassGifts) {
    perPrice.set(gift.coin_cost, (perPrice.get(gift.coin_cost) ?? 0) + 1);
  }
  for (const [price, count] of perPrice) {
    assert.ok(count >= 2, `price ${price} has only ${count} gift(s)`);
  }
});

test("glass gift ids are unique and do not collide with other gifts", () => {
  const ids = BASE_GIFT_CATALOG.map((g) => g.id);
  assert.equal(new Set(ids).size, ids.length, "duplicate gift id in catalog");
});

// New golden models (Mr. Wrong, 2026-11-24: complete the 3 models):
// Phoenix + Treasure Chest keep their glass ids/prices, but the app
// shows the bundled golden WebP (local_asset) instead of the R2 glass PNG.
test("phoenix + treasure chest gifts use the new bundled golden models", () => {
  const byId = new Map(BASE_GIFT_CATALOG.map((g) => [g.id, g]));
  assert.equal(
    byId.get("glass-phoenix")?.local_asset,
    "assets/images/gift_phoenix_new.webp",
  );
  assert.equal(
    byId.get("glass-treasure-chest")?.local_asset,
    "assets/images/gift_treasure_chest_new.webp",
  );
  // Prices + R2 asset keys unchanged (the model is an art upgrade only).
  assert.equal(byId.get("glass-phoenix")?.coin_cost, 5000);
  assert.equal(byId.get("glass-treasure-chest")?.coin_cost, 2500);
  assert.equal(
    byId.get("glass-phoenix")?.asset_key,
    "gifts/glass/phoenix.png",
  );
  assert.equal(
    byId.get("glass-treasure-chest")?.asset_key,
    "gifts/glass/treasure-chest.png",
  );
});
