import test from "node:test";
import assert from "node:assert/strict";
import { COSMETIC_CATALOG } from "../src/cosmetics.js";
import { effectiveCosmeticCatalog } from "../src/index.js";

function fakeDb(rows) {
  return {
    prepare() {
      return {
        async all() {
          return { results: rows };
        },
      };
    },
  };
}

test("a disabled row from another category cannot hide a built-in Store item", async () => {
  const catalog = await effectiveCosmeticCatalog(fakeDb([
    {
      kind: "theme",
      id: "frame_royal",
      name: "Unrelated theme",
      enabled: 0,
      sort_order: 0,
      price_coins: 0,
      json_data: "{}",
      updated_at: Date.now(),
    },
  ]));

  assert.ok(catalog.some((item) => item.id === "frame_royal" && item.kind === "frame"));
  assert.equal(catalog.length, COSMETIC_CATALOG.length);
});

test("Store falls back to canonical cosmetics if stale disabled rows empty the catalog", async () => {
  const rows = COSMETIC_CATALOG.map((item, index) => ({
    kind: item.kind,
    id: item.id,
    name: item.name,
    enabled: 0,
    sort_order: index,
    price_coins: item.price_coins,
    json_data: "{}",
    updated_at: Date.now(),
  }));

  const catalog = await effectiveCosmeticCatalog(fakeDb(rows));

  assert.equal(catalog.length, COSMETIC_CATALOG.length);
  assert.deepEqual(
    catalog.map((item) => item.id).sort(),
    COSMETIC_CATALOG.map((item) => item.id).sort(),
  );
});
