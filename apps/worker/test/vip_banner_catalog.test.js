import test from "node:test";
import assert from "node:assert/strict";
import { effectiveCosmeticCatalog } from "../src/index.js";

function fakeDb(rows) {
  return {
    prepare() {
      return {
        async all() { return { results: rows }; },
      };
    },
  };
}

test("Owner-configured VIP banner is included in the live cosmetic catalog", async () => {
  const catalog = await effectiveCosmeticCatalog(fakeDb([
    {
      kind: "banner",
      id: "vip-banner-18-test",
      name: "Eternal Sovereign Banner",
      enabled: 1,
      sort_order: 1,
      price_coins: 1800000,
      json_data: JSON.stringify({
        asset_key: "vip/banners/eternal-sovereign.webp",
        min_vip_level: 18,
        duration_days: 30,
        description: "VIP18 banner",
      }),
      updated_at: Date.now(),
    },
  ]));

  const banner = catalog.find((item) => item.id === "vip-banner-18-test");
  assert.ok(banner, "banner should be returned by /api/cosmetics");
  assert.equal(banner.kind, "banner");
  assert.equal(banner.name, "Eternal Sovereign Banner");
  assert.equal(banner.price_coins, 1800000);
  assert.equal(banner.asset_key, "vip/banners/eternal-sovereign.webp");
  assert.equal(banner.min_vip_level, 18);
});

