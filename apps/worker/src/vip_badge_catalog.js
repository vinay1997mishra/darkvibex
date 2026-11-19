// DarkVibeX — VIP Badge Video Catalog (VIP1-18)
//
// One premium 3D animated VIP level badge per level: a shield with the
// level animal, wings, and a gold "VIP N" banner on a pedestal, each
// level's own colour and superpower.
//
// SOURCES (Vinay, 2026-11-19): 11 of the 18 videos are Vinay's own
// uploads — VIP5 Deer, VIP6 Wolf, VIP8 Panther, VIP9 Cobra, VIP10
// Lion, VIP11 Tiger, VIP13 Gorilla, VIP15 Kraken, VIP16 Leviathan,
// VIP17 Phoenix (gold fire), VIP18 Dragon. They are portrait
// (720x1260 or 720x1080) and 5.184 s each, except VIP17 gold at
// 10.144 s. The other 7 — VIP1 Cat, VIP2 Swan, VIP3 Dolphin, VIP4
// Fox, VIP7 Eagle, VIP12 Mammoth, VIP14 Bear — were made by Ghost in
// the same style: landscape 1280x720, 10.000 s each.
//
// VIP17 PURPLE VARIANT (Vinay, 2026-11-19: "17 ye hai isko purple
// colour ka bana de"): the gold/orange phoenix recolored purple fire.
// It is a SEPARATE variant of the VIP17 entry (variant_video_key),
// NEVER the default — the canonical VIP17 badge stays gold.
//
// PLACEMENT (Vinay, 2026-11-19): the badge video plays on the VIP
// page hero card, on the RIGHT SIDE next to the "VIP N" text + EXP,
// BIG (~140-160px, replacing the 86px LevelMedal slot) — NOT a
// full-width background hero. Tapping a medal in the Medal Gallery
// plays that level's badge video in a dialog. The video plays ONCE
// (no loop) and the widget falls back to the LevelMedal SVG on
// completion/error — never a black box.
//
// R2 (bucket "darkvibex-files"): vip-badges/vip<N>-<animal>.mp4
// (video/mp4) + vip-badges/vip17-phoenix-purple.mp4 (variant).
// Videos play DIRECT from the R2 public URL — the Worker is NOT in
// the playback path (same decision as vehicle entry videos).
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

// animation_ms is the measured video duration: Vinay's portrait
// videos are 5.184 s (VIP17 gold is 10.144 s); Ghost's landscape
// videos are 10.000 s.
export const VIP_BADGE_CATALOG = [
  { id: "vip-badge-1", kind: "vip_badge", level: 1, animal: "cat", name: "Cat Badge", min_vip_level: 1, video_key: "vip-badges/vip1-cat.mp4", animation_ms: 10000 },
  { id: "vip-badge-2", kind: "vip_badge", level: 2, animal: "swan", name: "Swan Badge", min_vip_level: 2, video_key: "vip-badges/vip2-swan.mp4", animation_ms: 10000 },
  { id: "vip-badge-3", kind: "vip_badge", level: 3, animal: "dolphin", name: "Dolphin Badge", min_vip_level: 3, video_key: "vip-badges/vip3-dolphin.mp4", animation_ms: 10000 },
  { id: "vip-badge-4", kind: "vip_badge", level: 4, animal: "fox", name: "Fox Badge", min_vip_level: 4, video_key: "vip-badges/vip4-fox.mp4", animation_ms: 10000 },
  { id: "vip-badge-5", kind: "vip_badge", level: 5, animal: "deer", name: "Deer Badge", min_vip_level: 5, video_key: "vip-badges/vip5-deer.mp4", animation_ms: 5184 },
  { id: "vip-badge-6", kind: "vip_badge", level: 6, animal: "wolf", name: "Wolf Badge", min_vip_level: 6, video_key: "vip-badges/vip6-wolf.mp4", animation_ms: 5184 },
  { id: "vip-badge-7", kind: "vip_badge", level: 7, animal: "eagle", name: "Eagle Badge", min_vip_level: 7, video_key: "vip-badges/vip7-eagle.mp4", animation_ms: 10000 },
  { id: "vip-badge-8", kind: "vip_badge", level: 8, animal: "panther", name: "Panther Badge", min_vip_level: 8, video_key: "vip-badges/vip8-panther.mp4", animation_ms: 5184 },
  { id: "vip-badge-9", kind: "vip_badge", level: 9, animal: "cobra", name: "Cobra Badge", min_vip_level: 9, video_key: "vip-badges/vip9-cobra.mp4", animation_ms: 5184 },
  { id: "vip-badge-10", kind: "vip_badge", level: 10, animal: "lion", name: "Lion Badge", min_vip_level: 10, video_key: "vip-badges/vip10-lion.mp4", animation_ms: 5184 },
  { id: "vip-badge-11", kind: "vip_badge", level: 11, animal: "tiger", name: "Tiger Badge", min_vip_level: 11, video_key: "vip-badges/vip11-tiger.mp4", animation_ms: 5184 },
  { id: "vip-badge-12", kind: "vip_badge", level: 12, animal: "mammoth", name: "Mammoth Badge", min_vip_level: 12, video_key: "vip-badges/vip12-mammoth.mp4", animation_ms: 10000 },
  { id: "vip-badge-13", kind: "vip_badge", level: 13, animal: "gorilla", name: "Gorilla Badge", min_vip_level: 13, video_key: "vip-badges/vip13-gorilla.mp4", animation_ms: 5184 },
  { id: "vip-badge-14", kind: "vip_badge", level: 14, animal: "bear", name: "Bear Badge", min_vip_level: 14, video_key: "vip-badges/vip14-bear.mp4", animation_ms: 10000 },
  { id: "vip-badge-15", kind: "vip_badge", level: 15, animal: "kraken", name: "Kraken Badge", min_vip_level: 15, video_key: "vip-badges/vip15-kraken.mp4", animation_ms: 5184 },
  { id: "vip-badge-16", kind: "vip_badge", level: 16, animal: "leviathan", name: "Leviathan Badge", min_vip_level: 16, video_key: "vip-badges/vip16-leviathan.mp4", animation_ms: 5184 },
  { id: "vip-badge-17", kind: "vip_badge", level: 17, animal: "phoenix", name: "Phoenix Badge", min_vip_level: 17, video_key: "vip-badges/vip17-phoenix.mp4", animation_ms: 10144, variant_name: "Purple Phoenix Badge", variant_video_key: "vip-badges/vip17-phoenix-purple.mp4", variant_animation_ms: 10000 },
  { id: "vip-badge-18", kind: "vip_badge", level: 18, animal: "dragon", name: "Dragon Badge", min_vip_level: 18, video_key: "vip-badges/vip18-dragon.mp4", animation_ms: 5184 },
];

export function vipBadgeForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 1 || vipLevel > 18) return null;
  return VIP_BADGE_CATALOG.find((entry) => entry.level === vipLevel) ?? null;
}

export function vipBadgeById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return VIP_BADGE_CATALOG.find((entry) => entry.id === key) ?? null;
}

/// Catalog item in the shape vipVisualsForLevel() returns for a badge.
/// There is no still image for badges (asset_key is empty) — the app
/// falls back to the LevelMedal SVG when the video cannot play or
/// finishes. The video plays once (no loop). VIP17 carries its purple
/// variant as separate fields; the gold video_key stays canonical.
export function vipBadgeVisualForVipLevel(level) {
  const entry = vipBadgeForVipLevel(level);
  if (!entry) return null;
  const visual = {
    id: entry.id,
    kind: "vip_badge",
    name: entry.name,
    asset_key: "",
    video_key: entry.video_key,
    glb_key: "",
    media_type: "video",
    animation_type: "play_once",
    animation_ms: entry.animation_ms,
  };
  if (entry.variant_video_key) {
    visual.variant_name = entry.variant_name;
    visual.variant_video_key = entry.variant_video_key;
    visual.variant_animation_ms = entry.variant_animation_ms;
  }
  return visual;
}

export function vipBadgeUrlForVipLevel(level) {
  const entry = vipBadgeForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.video_key}`;
}

/// Direct R2 URL of the VIP17 purple phoenix variant, or null for any
/// other level (only VIP17 has a variant). The gold badge stays the
/// default for VIP17 — call this only when the purple variant is
/// explicitly requested.
export function vipBadgeVariantUrlForVipLevel(level) {
  const entry = vipBadgeForVipLevel(level);
  if (!entry || !entry.variant_video_key || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.variant_video_key}`;
}

export function allVipBadgeUrls() {
  return VIP_BADGE_CATALOG.map((entry) => vipBadgeUrlForVipLevel(entry.level));
}
