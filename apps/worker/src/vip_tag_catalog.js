// DarkVibeX — VIP Tag Catalog (golden animal tags, VIP1-18)
//
// One golden tag image per VIP level 1-18: the level animal + "VIP N" on
// a gold ribbon, transparent background. VIP5-18 are Vinay's own uploads,
// split into 14 separate PNGs (background made transparent, inner colours
// kept). VIP1-4 are generated in the same style (2026-11-19): VIP1 black
// cat + purple gem, VIP2 white swan + teal drop, VIP3 dolphin +
// blue gem, VIP4 red fox + orange gem. Theme map (Vinay, 2026-11-19):
// VIP1 = black cat, VIP2 = swan, VIP3 = dolphin, VIP4 = fox.
//
// R2 (bucket "darkvibex-files"): vip-tags/vip<N>-tag.png (image/png).
// The tag is a pure level badge — it is never equipped, never bought,
// never configured per user. It shows wherever the VIP level is displayed
// (room chat sender name, seat name area, profile VIP badge), sized
// automatically to the text/row it sits next to.
//
// This catalog is deliberately NOT part of COSMETIC_CATALOG. It mirrors
// vehicle_entry_animals.js: a separate level->asset catalog. There is no
// Owner override for tags; vipVisualsForLevel() returns the level's tag
// unconditionally for VIP5-18 so the server-side visuals bundle is
// complete. The app resolves the tag from the VIP level directly
// (vipTagUrlForVipLevel), so chat messages — which carry only
// active_vip_level — can show it too.
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

export const VIP_TAG_CATALOG = [
  { id: "vip-tag-1", kind: "tag", level: 1, animal: "cat", name: "Cat Tag", min_vip_level: 1, asset_key: "vip-tags/vip1-tag.png" },
  { id: "vip-tag-2", kind: "tag", level: 2, animal: "swan", name: "Swan Tag", min_vip_level: 2, asset_key: "vip-tags/vip2-tag.png" },
  { id: "vip-tag-3", kind: "tag", level: 3, animal: "dolphin", name: "Dolphin Tag", min_vip_level: 3, asset_key: "vip-tags/vip3-tag.png" },
  { id: "vip-tag-4", kind: "tag", level: 4, animal: "fox", name: "Fox Tag", min_vip_level: 4, asset_key: "vip-tags/vip4-tag.png" },
  { id: "vip-tag-5", kind: "tag", level: 5, animal: "deer", name: "Deer Tag", min_vip_level: 5, asset_key: "vip-tags/vip5-tag.png" },
  { id: "vip-tag-6", kind: "tag", level: 6, animal: "wolf", name: "Wolf Tag", min_vip_level: 6, asset_key: "vip-tags/vip6-tag.png" },
  { id: "vip-tag-7", kind: "tag", level: 7, animal: "eagle", name: "Eagle Tag", min_vip_level: 7, asset_key: "vip-tags/vip7-tag.png" },
  { id: "vip-tag-8", kind: "tag", level: 8, animal: "panther", name: "Panther Tag", min_vip_level: 8, asset_key: "vip-tags/vip8-tag.png" },
  { id: "vip-tag-9", kind: "tag", level: 9, animal: "cobra", name: "Cobra Tag", min_vip_level: 9, asset_key: "vip-tags/vip9-tag.png" },
  { id: "vip-tag-10", kind: "tag", level: 10, animal: "lion", name: "Lion Tag", min_vip_level: 10, asset_key: "vip-tags/vip10-tag.png" },
  { id: "vip-tag-11", kind: "tag", level: 11, animal: "tiger", name: "Tiger Tag", min_vip_level: 11, asset_key: "vip-tags/vip11-tag.png" },
  { id: "vip-tag-12", kind: "tag", level: 12, animal: "mammoth", name: "Mammoth Tag", min_vip_level: 12, asset_key: "vip-tags/vip12-tag.png" },
  { id: "vip-tag-13", kind: "tag", level: 13, animal: "gorilla", name: "Gorilla Tag", min_vip_level: 13, asset_key: "vip-tags/vip13-tag.png" },
  { id: "vip-tag-14", kind: "tag", level: 14, animal: "bear", name: "Bear Tag", min_vip_level: 14, asset_key: "vip-tags/vip14-tag.png" },
  { id: "vip-tag-15", kind: "tag", level: 15, animal: "kraken", name: "Kraken Tag", min_vip_level: 15, asset_key: "vip-tags/vip15-tag.png" },
  { id: "vip-tag-16", kind: "tag", level: 16, animal: "leviathan", name: "Leviathan Tag", min_vip_level: 16, asset_key: "vip-tags/vip16-tag.png" },
  { id: "vip-tag-17", kind: "tag", level: 17, animal: "phoenix", name: "Phoenix Tag", min_vip_level: 17, asset_key: "vip-tags/vip17-tag.png" },
  { id: "vip-tag-18", kind: "tag", level: 18, animal: "dragon", name: "Dragon Tag", min_vip_level: 18, asset_key: "vip-tags/vip18-tag.png" },
];

export function tagForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 1 || vipLevel > 18) return null;
  return VIP_TAG_CATALOG.find((entry) => entry.level === vipLevel) ?? null;
}

export function tagById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return VIP_TAG_CATALOG.find((entry) => entry.id === key) ?? null;
}

/// Catalog item in the shape vipVisualsForLevel() returns for a tag.
export function tagVisualForVipLevel(level) {
  const entry = tagForVipLevel(level);
  if (!entry) return null;
  return {
    id: entry.id,
    kind: "tag",
    name: entry.name,
    asset_key: entry.asset_key,
    video_key: "",
    glb_key: "",
    media_type: "image",
    animation_type: "",
    animation_ms: 0,
  };
}

export function tagUrlForVipLevel(level) {
  const entry = tagForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.asset_key}`;
}

export function allTagUrls() {
  return VIP_TAG_CATALOG.map((entry) => tagUrlForVipLevel(entry.level));
}
