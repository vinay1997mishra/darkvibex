// DarkVibeX — VIP Scenic Banner Catalog (profile banners, VIP1-4)
//
// One wide scenic/profile banner per VIP level 1-4: a gold-framed
// picture with the level animal and a big gold "VIP N", transparent
// background OUTSIDE the frame (the picture inside the frame stays
// opaque by design — it is a picture, not a cutout). VIP1 (black cat
// peeking over an ornate gold frame, opaque black centre panel) and
// VIP2 (swan over a misty lake/mountains) are Vinay's own uploads;
// VIP3 (dolphin over an ocean sunset) and VIP4 (red fox in an autumn
// forest) are generated in the same style (2026-11-19). Theme map
// (Vinay, 2026-11-19): VIP1 = black cat, VIP2 = swan, VIP3 = dolphin,
// VIP4 = fox. VIP5-18 have NO scenic banners yet.
//
// R2 (bucket "darkvibex-files"): profile-banners/vip<N>-banner.png
// (VIP1) and profile-banners/vip<N>-scenic.png (VIP2-4), image/png.
//
// DISPLAY NOTE: the app's profile cards are currently painted glow
// effects (cosmetics.js profile_card items), not R2 images — there is
// no profile-background surface that reads this catalog yet. This
// catalog wires the art server-side (vipVisualsForLevel returns it as
// vip_scenic_banner) so it is ready when the profile screen is wired
// to show the level's scenic banner. That Dart wiring is a follow-up
// decision (Vinay's approval), NOT part of this change.
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

export const VIP_SCENIC_BANNER_CATALOG = [
  { id: "vip-scenic-1", kind: "scenic_banner", level: 1, animal: "cat", name: "Cat Banner", min_vip_level: 1, asset_key: "profile-banners/vip1-banner.png" },
  { id: "vip-scenic-2", kind: "scenic_banner", level: 2, animal: "swan", name: "Swan Scenic", min_vip_level: 2, asset_key: "profile-banners/vip2-scenic.png" },
  { id: "vip-scenic-3", kind: "scenic_banner", level: 3, animal: "dolphin", name: "Dolphin Scenic", min_vip_level: 3, asset_key: "profile-banners/vip3-scenic.png" },
  { id: "vip-scenic-4", kind: "scenic_banner", level: 4, animal: "fox", name: "Fox Scenic", min_vip_level: 4, asset_key: "profile-banners/vip4-scenic.png" },
];

export function scenicBannerForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 1 || vipLevel > 4) return null;
  return VIP_SCENIC_BANNER_CATALOG.find((entry) => entry.level === vipLevel) ?? null;
}

export function scenicBannerById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return VIP_SCENIC_BANNER_CATALOG.find((entry) => entry.id === key) ?? null;
}

/// Catalog item in the shape vipVisualsForLevel() returns for a banner.
export function scenicBannerVisualForVipLevel(level) {
  const entry = scenicBannerForVipLevel(level);
  if (!entry) return null;
  return {
    id: entry.id,
    kind: "scenic_banner",
    name: entry.name,
    asset_key: entry.asset_key,
    video_key: "",
    glb_key: "",
    media_type: "image",
    animation_type: "",
    animation_ms: 0,
  };
}

export function scenicBannerUrlForVipLevel(level) {
  const entry = scenicBannerForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.asset_key}`;
}

export function allScenicBannerUrls() {
  return VIP_SCENIC_BANNER_CATALOG.map((entry) => scenicBannerUrlForVipLevel(entry.level));
}
