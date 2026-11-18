// DarkVibeX — VIP Entry Effect Catalog (ANIMAL banners, VIP5-18)
//
// One wide entry banner per VIP level 5-18. Each banner is a horizontal
// strip with a transparent circular slot on the LEFT (the arriving user's
// DP shows through it) and the level animal on the right, plus a "VIP N"
// label. The banners are Vinay's own uploads, background made 100%
// transparent (inner colours kept exactly as uploaded).
//
// R2 (bucket "darkvibex-files"): entry-effects/vip<N>-entry.png
// (image/png, transparent background). The DP circle geometry was
// measured from the PNGs (2026-11-18) and lives in the Dart catalog
// (apps/mobile/lib/vip/vip_visual_assets.dart) as per-level fractions —
// the circle is NOT in the same place on every banner, so do not guess
// one position for all levels.
//
// This catalog is deliberately NOT part of COSMETIC_CATALOG. It mirrors
// vehicle_entry_animals.js: a separate level->asset catalog, consulted as
// a FALLBACK by vipVisualsForLevel() when the Owner has not configured an
// entry_effect_id for the level, and only when the member has no equipped
// custom entry. Precedence: equipped custom entry > Owner vip_rule entry
// > animal entry banner. The banner is the DEFAULT entry effect for
// VIP5-18; it shows at room entry (top banner of the arrival overlay)
// next to the vehicle video.
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

export const VIP_ENTRY_EFFECT_CATALOG = [
  { id: "vip-entry-5", kind: "entry", level: 5, animal: "deer", name: "Deer Entry", min_vip_level: 5, duration_days: 30, asset_key: "entry-effects/vip5-entry.png", animation_ms: 0 },
  { id: "vip-entry-6", kind: "entry", level: 6, animal: "wolf", name: "Wolf Entry", min_vip_level: 6, duration_days: 30, asset_key: "entry-effects/vip6-entry.png", animation_ms: 0 },
  { id: "vip-entry-7", kind: "entry", level: 7, animal: "eagle", name: "Eagle Entry", min_vip_level: 7, duration_days: 30, asset_key: "entry-effects/vip7-entry.png", animation_ms: 0 },
  { id: "vip-entry-8", kind: "entry", level: 8, animal: "panther", name: "Panther Entry", min_vip_level: 8, duration_days: 30, asset_key: "entry-effects/vip8-entry.png", animation_ms: 0 },
  { id: "vip-entry-9", kind: "entry", level: 9, animal: "cobra", name: "Cobra Entry", min_vip_level: 9, duration_days: 30, asset_key: "entry-effects/vip9-entry.png", animation_ms: 0 },
  { id: "vip-entry-10", kind: "entry", level: 10, animal: "lion", name: "Lion Entry", min_vip_level: 10, duration_days: 30, asset_key: "entry-effects/vip10-entry.png", animation_ms: 0 },
  { id: "vip-entry-11", kind: "entry", level: 11, animal: "tiger", name: "Tiger Entry", min_vip_level: 11, duration_days: 30, asset_key: "entry-effects/vip11-entry.png", animation_ms: 0 },
  { id: "vip-entry-12", kind: "entry", level: 12, animal: "mammoth", name: "Mammoth Entry", min_vip_level: 12, duration_days: 30, asset_key: "entry-effects/vip12-entry.png", animation_ms: 0 },
  { id: "vip-entry-13", kind: "entry", level: 13, animal: "gorilla", name: "Gorilla Entry", min_vip_level: 13, duration_days: 30, asset_key: "entry-effects/vip13-entry.png", animation_ms: 0 },
  { id: "vip-entry-14", kind: "entry", level: 14, animal: "bear", name: "Bear Entry", min_vip_level: 14, duration_days: 30, asset_key: "entry-effects/vip14-entry.png", animation_ms: 0 },
  { id: "vip-entry-15", kind: "entry", level: 15, animal: "kraken", name: "Kraken Entry", min_vip_level: 15, duration_days: 30, asset_key: "entry-effects/vip15-entry.png", animation_ms: 0 },
  { id: "vip-entry-16", kind: "entry", level: 16, animal: "leviathan", name: "Leviathan Entry", min_vip_level: 16, duration_days: 30, asset_key: "entry-effects/vip16-entry.png", animation_ms: 0 },
  { id: "vip-entry-17", kind: "entry", level: 17, animal: "phoenix", name: "Phoenix Entry", min_vip_level: 17, duration_days: 30, asset_key: "entry-effects/vip17-entry.png", animation_ms: 0 },
  { id: "vip-entry-18", kind: "entry", level: 18, animal: "dragon", name: "Dragon Entry", min_vip_level: 18, duration_days: 30, asset_key: "entry-effects/vip18-entry.png", animation_ms: 0 },
];

export function entryEffectForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 5 || vipLevel > 18) return null;
  return VIP_ENTRY_EFFECT_CATALOG.find((entry) => entry.level === vipLevel) ?? null;
}

export function entryEffectById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return VIP_ENTRY_EFFECT_CATALOG.find((entry) => entry.id === key) ?? null;
}

/// Catalog item in the shape vipVisualsForLevel() returns for an entry:
/// asset_key is the banner PNG (a still image — the banner has no video).
export function entryEffectVisualForVipLevel(level) {
  const entry = entryEffectForVipLevel(level);
  if (!entry) return null;
  return {
    id: entry.id,
    kind: "entry",
    name: entry.name,
    asset_key: entry.asset_key,
    video_key: "",
    glb_key: "",
    media_type: "image",
    animation_type: "",
    animation_ms: entry.animation_ms,
  };
}

export function entryEffectUrlForVipLevel(level) {
  const entry = entryEffectForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.asset_key}`;
}

export function allEntryEffectUrls() {
  return VIP_ENTRY_EFFECT_CATALOG.map((entry) => entryEffectUrlForVipLevel(entry.level));
}
