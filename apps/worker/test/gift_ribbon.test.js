import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  GIFT_RIBBON_TIERS,
  GIFT_RIBBON_TIER_ORDER,
  GIFT_RIBBON_BY_LEVEL,
  ribbonTierForVipLevel,
  ribbonForVipLevel,
  ribbonById,
  giftRibbonVisualForVipLevel,
  ribbonUrlForVipLevel,
  allRibbonUrls,
  giftRibbonForVipLevel,
} from "../src/gift_ribbon_catalog.js";
import { entryEffectUrlForVipLevel } from "../src/vip_entry_effect_catalog.js";

const R2_BASE = "https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev";

test("gift ribbon tiers cover VIP1-18: 4 tiers, boundaries at 1/5/11/16", () => {
  assert.deepEqual(GIFT_RIBBON_TIER_ORDER, [
    "basic",
    "premium",
    "royal",
    "super_premium",
  ]);
  assert.equal(GIFT_RIBBON_TIERS.basic.asset, "gift-ribbons/ribbon-sleek-gold.webp");
  assert.equal(GIFT_RIBBON_TIERS.premium.asset, "gift-ribbons/ribbon-purple-gold.webp");
  assert.equal(GIFT_RIBBON_TIERS.royal.asset, "gift-ribbons/ribbon-royal-gold.webp");
  assert.equal(GIFT_RIBBON_TIERS.super_premium.asset, "gift-ribbons/ribbon-dragon-super.webp");
  // Tier boundaries (min/max per tier).
  assert.equal(ribbonTierForVipLevel(1), "basic");
  assert.equal(ribbonTierForVipLevel(4), "basic");
  assert.equal(ribbonTierForVipLevel(5), "premium");
  assert.equal(ribbonTierForVipLevel(10), "premium");
  assert.equal(ribbonTierForVipLevel(11), "royal");
  assert.equal(ribbonTierForVipLevel(15), "royal");
  assert.equal(ribbonTierForVipLevel(16), "super_premium");
  assert.equal(ribbonTierForVipLevel(18), "super_premium");
  // Out of range: no tier (strict mapping — the gift flow falls back
  // to basic separately, see giftRibbonForVipLevel below).
  assert.equal(ribbonTierForVipLevel(0), null);
  assert.equal(ribbonTierForVipLevel(19), null);
  assert.equal(ribbonForVipLevel(0), null);
  assert.equal(ribbonForVipLevel(19), null);
  // Every level 1-18 has its own banner (one tier id per level).
  assert.equal(Object.keys(GIFT_RIBBON_BY_LEVEL).length, 18);
  for (let level = 1; level <= 18; level++) {
    assert.equal(
      GIFT_RIBBON_BY_LEVEL[level],
      ribbonForVipLevel(level).id,
    );
  }
  assert.equal(ribbonById("ribbon_royal_gold")?.name, "Royal Gold");
  assert.equal(ribbonById("ribbon_dragon_super")?.name, "Dragon Super Premium");
  assert.equal(ribbonById("nope"), null);
});

test("gift ribbon URLs point at the R2 gift-ribbons/ WebPs", () => {
  assert.equal(
    ribbonUrlForVipLevel(2),
    `${R2_BASE}/gift-ribbons/ribbon-sleek-gold.webp`,
  );
  assert.equal(
    ribbonUrlForVipLevel(7),
    `${R2_BASE}/gift-ribbons/ribbon-purple-gold.webp`,
  );
  assert.equal(
    ribbonUrlForVipLevel(13),
    `${R2_BASE}/gift-ribbons/ribbon-royal-gold.webp`,
  );
  assert.equal(
    ribbonUrlForVipLevel(17),
    `${R2_BASE}/gift-ribbons/ribbon-dragon-super.webp`,
  );
  assert.equal(ribbonUrlForVipLevel(0), null);
  assert.equal(ribbonUrlForVipLevel(19), null);
  assert.equal(allRibbonUrls().length, 4);
  assert.ok(allRibbonUrls().every((url) => url.startsWith(`${R2_BASE}/gift-ribbons/`)));
  assert.ok(allRibbonUrls().every((url) => url.endsWith(".webp")));
  const visual = giftRibbonVisualForVipLevel(13);
  assert.equal(visual.id, "ribbon_royal_gold");
  assert.equal(visual.kind, "gift_ribbon");
  assert.equal(visual.asset_key, "gift-ribbons/ribbon-royal-gold.webp");
  assert.equal(visual.video_key, "");
  assert.equal(giftRibbonVisualForVipLevel(0), null);
});

test("giftRibbonForVipLevel falls back to the basic tier for VIP0/no-VIP", () => {
  const vip0 = giftRibbonForVipLevel(0);
  assert.equal(vip0.tier, "basic");
  assert.equal(vip0.id, "ribbon_sleek_gold");
  assert.equal(vip0.vip_level, 0);
  assert.equal(vip0.url, `${R2_BASE}/gift-ribbons/ribbon-sleek-gold.webp`);
  assert.equal(vip0.kind, "gift_ribbon");
});

test("giftRibbonForVipLevel returns the entry effect for VIP1-18", () => {
  // Vinay (2026-11-19): "entry effect ko hi gift me bhi laga de" —
  // the gift banner IS the sender's entry effect for VIP1-18: same
  // entry-effects/vip<N>-entry.png the arrival overlay uses.
  for (let level = 1; level <= 18; level++) {
    const ribbon = giftRibbonForVipLevel(level);
    assert.equal(ribbon.kind, "entry_effect");
    assert.equal(ribbon.vip_level, level);
    assert.equal(ribbon.asset_key, `entry-effects/vip${level}-entry.png`);
    assert.equal(
      ribbon.url,
      `${R2_BASE}/entry-effects/vip${level}-entry.png`,
    );
    assert.equal(ribbon.url, entryEffectUrlForVipLevel(level));
    assert.equal(ribbon.id, `vip-entry-${level}`);
  }
  // Spot checks: tier is kept for the app's per-tier panel colours.
  const vip1 = giftRibbonForVipLevel(1);
  assert.equal(vip1.tier, "basic");
  assert.equal(vip1.name, "Cat Entry");
  const vip2 = giftRibbonForVipLevel(2);
  assert.equal(vip2.tier, "basic");
  assert.equal(vip2.name, "Swan Entry");
  const vip7 = giftRibbonForVipLevel(7);
  assert.equal(vip7.tier, "premium");
  assert.equal(vip7.name, "Eagle Entry");
  const vip13 = giftRibbonForVipLevel(13);
  assert.equal(vip13.tier, "royal");
  assert.equal(vip13.name, "Gorilla Entry");
  const vip17 = giftRibbonForVipLevel(17);
  assert.equal(vip17.tier, "super_premium");
  assert.equal(vip17.name, "Phoenix Entry");
});

test("gift send response includes the ribbon and sender/receiver/gift names", () => {
  const source = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  const start = source.indexOf('if (url.pathname === "/api/gifts/send"');
  const end = source.indexOf(
    'if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo"',
    start,
  );
  assert.ok(start >= 0 && end > start, "gift send endpoint must be present");
  const endpoint = source.slice(start, end);
  assert.ok(
    endpoint.includes("giftRibbonForVipLevel"),
    "send must attach the sender's ribbon",
  );
  assert.ok(endpoint.includes("gift_ribbon:"), "send response must carry gift_ribbon");
  assert.ok(endpoint.includes("sender_name:"), "send response must carry sender_name");
  assert.ok(endpoint.includes("receiver_name:"), "send response must carry receiver_name");
  assert.ok(endpoint.includes("gift_name:"), "send response must carry gift_name");
  assert.ok(endpoint.includes("sender_vip_level:"), "send response must carry sender_vip_level");
});

test("gift-events feed includes the ribbon and sender VIP level per event", () => {
  const source = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  const start = source.indexOf('parts[3] === "gift-events"');
  const end = source.indexOf('parts[3] === "messages"', start);
  assert.ok(start >= 0 && end > start, "gift-events endpoint must be present");
  const endpoint = source.slice(start, end);
  assert.ok(
    endpoint.includes("sender_vip_level"),
    "gift-events must select the sender VIP level",
  );
  assert.ok(
    endpoint.includes("giftRibbonForVipLevel"),
    "gift-events must attach the ribbon per event",
  );
  assert.ok(endpoint.includes("gift_ribbon:"), "gift-events must carry gift_ribbon");
  assert.ok(endpoint.includes("sender_name:"), "gift-events must carry sender_name");
  assert.ok(endpoint.includes("receiver_name:"), "gift-events must carry receiver_name");
});
