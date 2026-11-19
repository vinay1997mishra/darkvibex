// DarkVibeX — VIP Medal Catalog (animal shield medals, VIP1-4)
//
// One shield medal image per VIP level 1-4: a black shield with a gold
// border, the level animal in the centre, the level's gems, and a gold
// "VIP N" at the bottom, transparent background. VIP1 (black cat +
// purple gems) and VIP2 (white pearl swan + teal gems) are Vinay's own
// uploads; VIP3/VIP4 (dolphin + blue gems) are generated in the same
// style (2026-11-19). NOTE: VIP3 and VIP4 are NOT the same animal:
// VIP3 = dolphin, VIP4 = fox (Vinay, 2026-11-19: "Vip 3 dolphin thik
// hai", "Vip 4 fox hai"). The baked-in "VIP N" distinguishes them.
// VIP5-18 have NO medal PNGs yet — the app still shows its bundled SVG
// medals (assets/medals/vip_XX.svg) for those levels.
//
// R2 (bucket "darkvibex-files"): vip-medals/vip<N>-medal.png
// (image/png, transparent background).
//
// MEDAL DISPLAY NOTE: the app's LevelMedal widget currently loads the
// bundled SVG per level and does NOT read this catalog yet — this
// catalog wires the PNG art server-side (vipVisualsForLevel returns it
// as vip_medal) so it is ready when the widget is switched to the R2
// art. Swapping the display from SVG to these PNGs is a follow-up
// decision (Vinay's approval), NOT part of this change.
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

export const VIP_MEDAL_CATALOG = [
  { id: "vip-medal-1", kind: "medal", level: 1, animal: "cat", name: "Cat Medal", min_vip_level: 1, asset_key: "vip-medals/vip1-medal.png" },
  { id: "vip-medal-2", kind: "medal", level: 2, animal: "swan", name: "Swan Medal", min_vip_level: 2, asset_key: "vip-medals/vip2-medal.png" },
  { id: "vip-medal-3", kind: "medal", level: 3, animal: "dolphin", name: "Dolphin Medal", min_vip_level: 3, asset_key: "vip-medals/vip3-medal.png" },
  { id: "vip-medal-4", kind: "medal", level: 4, animal: "fox", name: "Fox Medal", min_vip_level: 4, asset_key: "vip-medals/vip4-medal.png" },
];

export function medalForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 1 || vipLevel > 4) return null;
  return VIP_MEDAL_CATALOG.find((entry) => entry.level === vipLevel) ?? null;
}

export function medalById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return VIP_MEDAL_CATALOG.find((entry) => entry.id === key) ?? null;
}

/// Catalog item in the shape vipVisualsForLevel() returns for a medal.
export function medalVisualForVipLevel(level) {
  const entry = medalForVipLevel(level);
  if (!entry) return null;
  return {
    id: entry.id,
    kind: "medal",
    name: entry.name,
    asset_key: entry.asset_key,
    video_key: "",
    glb_key: "",
    media_type: "image",
    animation_type: "",
    animation_ms: 0,
  };
}

export function medalUrlForVipLevel(level) {
  const entry = medalForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.asset_key}`;
}

export function allMedalUrls() {
  return VIP_MEDAL_CATALOG.map((entry) => medalUrlForVipLevel(entry.level));
}
