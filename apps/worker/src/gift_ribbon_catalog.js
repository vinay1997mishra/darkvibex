// DarkVibeX — Gift Ribbon Catalog (VIP gift banner, VIP1-18)
//
// The gift ribbon is the banner shown in the room when a VIP sends a
// gift. It was the one missing VIP cosmetic (no "ribbon" kind in
// cosmetics.js). 4 tiers, colour and premium quality increase with the
// VIP level:
//   VIP1-4   = Sleek Gold (basic, gold-dominant)
//   VIP5-10  = Purple & Gold Ornate (premium)
//   VIP11-15 = Royal Gold (more premium, purple-dominant, big crown)
//   VIP16-18 = Dragon Super Premium (richest colours, purple fire)
// Every VIP level 1-18 gets its OWN banner: the tier base design plus
// the VIP level written BIG and bold at runtime ("VIP N" is the most
// prominent text on the banner), plus the sender name, the gift name
// and the receiver name (sender -> receiver, gift below). The runtime
// overlay layout (centre panel x 0.315-0.685, y 0.40-0.72 of the
// 2736x912 image) lives in the Dart widget
// (apps/mobile/lib/widgets/gift_ribbon_banner.dart) and mirrors
// ~/workspace/darkvibex-vip-section/gift-ribbons/make_previews.py.
//
// R2 (bucket "darkvibex-files", direct public base, image/webp):
//   gift-ribbons/ribbon-sleek-gold.webp   (VIP1-4)
//   gift-ribbons/ribbon-purple-gold.webp  (VIP5-10)
//   gift-ribbons/ribbon-royal-gold.webp   (VIP11-15, v2, purple-dominant)
//   gift-ribbons/ribbon-dragon-super.webp (VIP16-18)
// The ribbon is a full-width banner with its own background, so it does
// NOT need transparency — the black background is part of the banner.
//
// This catalog is deliberately NOT part of COSMETIC_CATALOG. It mirrors
// vip_entry_effect_catalog.js: a separate level->asset catalog. The
// gift flow (/api/gifts/send response + /api/rooms/:id/gift-events)
// attaches the ribbon for the SENDER's VIP level, so the room can show
// the banner without another lookup. A sender with no VIP (VIP0) falls
// back to the basic (Sleek Gold) tier — every gift gets a ribbon.
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

export const GIFT_RIBBON_TIERS = {
  basic: {
    id: "ribbon_sleek_gold",
    name: "Sleek Gold",
    min_vip: 1,
    max_vip: 4,
    asset: "gift-ribbons/ribbon-sleek-gold.webp",
    description: "Sleek gold ribbon with crown and purple gem",
  },
  premium: {
    id: "ribbon_purple_gold",
    name: "Purple & Gold Ornate",
    min_vip: 5,
    max_vip: 10,
    asset: "gift-ribbons/ribbon-purple-gold.webp",
    description: "Ornate black/gold frame, purple flames and purple gems",
  },
  royal: {
    id: "ribbon_royal_gold",
    name: "Royal Gold",
    min_vip: 11,
    max_vip: 15,
    asset: "gift-ribbons/ribbon-royal-gold.webp",
    description:
      "Purple-dominant royal ribbon, big gold crown, many purple gems",
  },
  super_premium: {
    id: "ribbon_dragon_super",
    name: "Dragon Super Premium",
    min_vip: 16,
    max_vip: 18,
    asset: "gift-ribbons/ribbon-dragon-super.webp",
    description: "Golden dragon wings with purple fire",
  },
};

export const GIFT_RIBBON_TIER_ORDER = [
  "basic",
  "premium",
  "royal",
  "super_premium",
];

export function ribbonTierForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 1 || vipLevel > 18) return null;
  if (vipLevel >= 16) return "super_premium";
  if (vipLevel >= 11) return "royal";
  if (vipLevel >= 5) return "premium";
  if (vipLevel >= 1) return "basic";
  return null;
}

export function ribbonForVipLevel(level) {
  const tier = ribbonTierForVipLevel(level);
  return tier ? GIFT_RIBBON_TIERS[tier] : null;
}

export function ribbonById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return (
    Object.values(GIFT_RIBBON_TIERS).find((tier) => tier.id === key) ?? null
  );
}

// Every VIP level 1-18 has a ribbon (sabke liye, alag alag).
export const GIFT_RIBBON_BY_LEVEL = {};
for (let level = 1; level <= 18; level++) {
  GIFT_RIBBON_BY_LEVEL[level] = ribbonForVipLevel(level).id;
}

/// Catalog item in the shape vipVisualsForLevel() returns for a visual:
/// asset_key is the tier WebP banner (a still image — the banner has no
/// video). The ribbon is keyed by TIER, not by level: all levels in a
/// tier share one base image, and the level is written on it at runtime.
export function giftRibbonVisualForVipLevel(level) {
  const tier = ribbonForVipLevel(level);
  if (!tier) return null;
  return {
    id: tier.id,
    kind: "gift_ribbon",
    name: tier.name,
    asset_key: tier.asset,
    video_key: "",
    glb_key: "",
    media_type: "image",
    animation_type: "",
    animation_ms: 0,
  };
}

export function ribbonUrlForVipLevel(level) {
  const tier = ribbonForVipLevel(level);
  if (!tier || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${tier.asset}`;
}

export function allRibbonUrls() {
  return GIFT_RIBBON_TIER_ORDER.map(
    (tier) => `${R2_PUBLIC_BASE_URL}/${GIFT_RIBBON_TIERS[tier].asset}`,
  );
}

/// The ribbon payload the gift flow attaches to a gift event/response.
/// { tier, id, name, asset_key, url, vip_level } — everything the app
/// needs to show the banner, with no extra lookup. VIP0 / no-VIP
/// falls back to the basic (Sleek Gold) tier so every gift gets a
/// ribbon; the vip_level carried is the sender's own level (0 when
/// they have no VIP), so the widget still writes the right "VIP N"
/// (or the basic banner with no level) for that sender.
export function giftRibbonForVipLevel(level) {
  const vipLevel = Math.max(0, Math.min(18, Number(level) || 0));
  const tier = ribbonForVipLevel(vipLevel) ?? GIFT_RIBBON_TIERS.basic;
  return {
    tier: ribbonTierForVipLevel(vipLevel) ?? "basic",
    id: tier.id,
    name: tier.name,
    asset_key: tier.asset,
    url: R2_PUBLIC_BASE_URL ? `${R2_PUBLIC_BASE_URL}/${tier.asset}` : null,
    vip_level: vipLevel,
  };
}
