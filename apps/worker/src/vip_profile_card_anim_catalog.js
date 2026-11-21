// DarkVibeX — VIP Profile Card Animation Catalog (v4, VIP4-18)
//
// One animated profile card per VIP level 4-18. Each animation is a
// 5-second MP4 (832x896 canvas, wide horizontal frame content inside)
// generated from the level's approved profile card frame design:
// the frame design stays EXACTLY as in the starting still, camera
// completely static, NO zoom, only the animal moves gently with its
// effect, and the animation ends calmly. Rules from Vinay
// (2026-11-19): animations run from VIP4 onwards, and NO design has
// a bottom line — every frame is open at the bottom, top and sides
// only. VIP5-18 are animated from their v3 designs (unique frame per
// level, no bottom line, no text anywhere — no "VIP N", no "Profile
// Card"). VIP4 (fox) has NO animation — still only, the new clean
// frame (its old video was built from an app screenshot; see the
// EXCEPTION note below).
//
// LAYOUT RULE (Vinay, 2026-11-19, approved): the profile card popup
// shows the reference layout in the FOREGROUND — DP top centre (in
// place of the frame's blue diamond), name + badges, medals, ID/Fans,
// bio, 4 buttons (Send gifts, Follow, Chat, Mention) — and this
// animation plays in the BACKGROUND behind all the text. The video
// is the background; it is never the content itself.
//
// VIP1-3 have NO profile card animation (v4 starts at VIP4), so the
// catalog returns null below VIP4.
//
// R2 (bucket "darkvibex-files"):
//   videos: profile-card-anims/vip<N>-<animal>.mp4 (video/mp4)
//   stills: profile-card-stills/vip<N>-<animal>.png (image/png)
// The still is the v3 design converted to PNG; the app shows it when
// the video cannot play. Videos play DIRECT from the R2 public URL —
// the Worker is NOT in the playback path (same decision as vehicle
// entry videos).
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

// EXCEPTION — VIP4 (fox): its old still/video were built from an app
// screenshot (cosmetics-shop UI behind the fox frame). The VIP4 entry
// below now points at the new clean frame instead —
//   asset_key: profile-card-frames/vip4-fox.webp (red-orange winged
//   gem + fox, dark background, no text, no UI; generated 2026-11-21)
// and VIP4 has NO video (video_key null, still only — VIP1-4 are
// still-only by the frame rule). The old screenshot files
// (profile-card-stills/vip4-fox.png, profile-card-anims/vip4-fox.mp4)
// are still on R2, only unreferenced — delete them separately.
export const VIP_PROFILE_CARD_ANIM_CATALOG = [
  { id: "vip-profile-card-anim-4", kind: "profile_card_anim", level: 4, animal: "fox", name: "Fox Profile Card", min_vip_level: 4, duration_days: 30, asset_key: "profile-card-frames/vip4-fox.webp", video_key: null, animation_ms: 5000 },
  { id: "vip-profile-card-anim-5", kind: "profile_card_anim", level: 5, animal: "deer", name: "Deer Profile Card", min_vip_level: 5, duration_days: 30, asset_key: "profile-card-stills/vip5-deer.png", video_key: "profile-card-anims/vip5-deer.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-6", kind: "profile_card_anim", level: 6, animal: "wolf", name: "Wolf Profile Card", min_vip_level: 6, duration_days: 30, asset_key: "profile-card-stills/vip6-wolf.png", video_key: "profile-card-anims/vip6-wolf.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-7", kind: "profile_card_anim", level: 7, animal: "eagle", name: "Eagle Profile Card", min_vip_level: 7, duration_days: 30, asset_key: "profile-card-stills/vip7-eagle.png", video_key: "profile-card-anims/vip7-eagle.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-8", kind: "profile_card_anim", level: 8, animal: "panther", name: "Panther Profile Card", min_vip_level: 8, duration_days: 30, asset_key: "profile-card-stills/vip8-panther.png", video_key: "profile-card-anims/vip8-panther.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-9", kind: "profile_card_anim", level: 9, animal: "cobra", name: "Cobra Profile Card", min_vip_level: 9, duration_days: 30, asset_key: "profile-card-stills/vip9-cobra.png", video_key: "profile-card-anims/vip9-cobra.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-10", kind: "profile_card_anim", level: 10, animal: "lion", name: "Lion Profile Card", min_vip_level: 10, duration_days: 30, asset_key: "profile-card-stills/vip10-lion.png", video_key: "profile-card-anims/vip10-lion.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-11", kind: "profile_card_anim", level: 11, animal: "tiger", name: "Tiger Profile Card", min_vip_level: 11, duration_days: 30, asset_key: "profile-card-stills/vip11-tiger.png", video_key: "profile-card-anims/vip11-tiger.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-12", kind: "profile_card_anim", level: 12, animal: "mammoth", name: "Mammoth Profile Card", min_vip_level: 12, duration_days: 30, asset_key: "profile-card-stills/vip12-mammoth.png", video_key: "profile-card-anims/vip12-mammoth.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-13", kind: "profile_card_anim", level: 13, animal: "gorilla", name: "Gorilla Profile Card", min_vip_level: 13, duration_days: 30, asset_key: "profile-card-stills/vip13-gorilla.png", video_key: "profile-card-anims/vip13-gorilla.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-14", kind: "profile_card_anim", level: 14, animal: "bear", name: "Bear Profile Card", min_vip_level: 14, duration_days: 30, asset_key: "profile-card-stills/vip14-bear.png", video_key: "profile-card-anims/vip14-bear.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-15", kind: "profile_card_anim", level: 15, animal: "kraken", name: "Kraken Profile Card", min_vip_level: 15, duration_days: 30, asset_key: "profile-card-stills/vip15-kraken.png", video_key: "profile-card-anims/vip15-kraken.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-16", kind: "profile_card_anim", level: 16, animal: "leviathan", name: "Leviathan Profile Card", min_vip_level: 16, duration_days: 60, asset_key: "profile-card-stills/vip16-leviathan.png", video_key: "profile-card-anims/vip16-leviathan.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-17", kind: "profile_card_anim", level: 17, animal: "phoenix", name: "Phoenix Profile Card", min_vip_level: 17, duration_days: 60, asset_key: "profile-card-stills/vip17-phoenix.png", video_key: "profile-card-anims/vip17-phoenix.mp4", animation_ms: 5000 },
  { id: "vip-profile-card-anim-18", kind: "profile_card_anim", level: 18, animal: "dragon", name: "Dragon Profile Card", min_vip_level: 18, duration_days: 60, asset_key: "profile-card-stills/vip18-dragon.png", video_key: "profile-card-anims/vip18-dragon.mp4", animation_ms: 5000 },
];

export function profileCardAnimForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 4 || vipLevel > 18) return null;
  return VIP_PROFILE_CARD_ANIM_CATALOG.find((entry) => entry.level === vipLevel) ?? null;
}

export function profileCardAnimById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return VIP_PROFILE_CARD_ANIM_CATALOG.find((entry) => entry.id === key) ?? null;
}

/// Catalog item in the shape vipVisualsForLevel() returns for a visual.
/// asset_key is the fallback still (shown when the video cannot play);
/// video_key is the 5-second background animation MP4, or null when the
/// level has no animation (VIP4: still only, clean frame). The app
/// plays the video once (no loop) as the card background, with the
/// DP/name/badges/medals/ID/buttons overlaid in the foreground.
export function profileCardAnimVisualForVipLevel(level) {
  const entry = profileCardAnimForVipLevel(level);
  if (!entry) return null;
  return {
    id: entry.id,
    kind: "profile_card_anim",
    name: entry.name,
    asset_key: entry.asset_key,
    video_key: entry.video_key,
    glb_key: "",
    media_type: entry.video_key ? "video" : "image",
    animation_type: entry.video_key ? "play_once" : "none",
    animation_ms: entry.animation_ms,
  };
}

export function profileCardAnimUrlForVipLevel(level) {
  const entry = profileCardAnimForVipLevel(level);
  if (!entry || !entry.video_key || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.video_key}`;
}

export function profileCardAnimStillUrlForVipLevel(level) {
  const entry = profileCardAnimForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.asset_key}`;
}

export function allProfileCardAnimUrls() {
  return VIP_PROFILE_CARD_ANIM_CATALOG.map((entry) => profileCardAnimUrlForVipLevel(entry.level)).filter((url) => url !== null);
}

export function allProfileCardAnimStillUrls() {
  return VIP_PROFILE_CARD_ANIM_CATALOG.map((entry) => profileCardAnimStillUrlForVipLevel(entry.level));
}
