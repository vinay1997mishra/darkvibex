// DarkVibeX — VIP Frame Catalog (ANIMAL set, VIP5-18)
//
// One transparent animated frame per VIP level 5-18. The artwork is the
// animal frame Vinay made for that level (roaring head on the ring, the
// level's own colour + superpower, 5 s animation, frame fixed, no zoom).
//
// TWO files exist per level on R2 (bucket "darkvibex-files"):
//   - video: frames/vip<N>-<animal>-transparent.webm  (VP9 WITH alpha)
//   - still: frames/vip<N>-<animal>-transparent.png   (transparent PNG)
// The still is the one the app displays TODAY (see below); the WebM is
// kept for a future player that preserves video alpha.
//
// WEBM-ALPHA LIMITATION (2026-11-18, verified): Flutter's video_player
// (ExoPlayer on Android) renders video to an opaque texture — it does NOT
// carry the VP9 alpha channel, so a transparent WebM played through it
// shows a BLACK box, not transparency. The app has no SVGA/Lottie/VAP
// player. So the frame IMAGE path (VipAnimatedFrame.assetUrl ->
// TransparentArtworkImage, which renders PNG alpha natively) is the
// display path, fed by asset_key (the PNG still). Do NOT wire the WebM
// through video_player expecting transparency. frameVideoUrlForVipLevel()
// exists so a future alpha-capable player (VAP/PAG/custom texture) can
// pick the animated version up without a catalog change.
// The PNG stills live in ~/workspace/darkvibex-vip-section/final-frames/
// (NOT in git — binary). Uploading them to R2 under frames/ needs Vinay's
// go-ahead; until then frameStillUrlForVipLevel() resolves to a URL that
// 404s and VipAnimatedFrame falls back to its painted ring.
//
// This catalog is deliberately NOT part of COSMETIC_CATALOG (which the
// cosmetics test pins at 29 frames). It mirrors vehicle_entry_animals.js:
// a separate level->asset catalog, consulted as a FALLBACK by
// vipVisualsForLevel() when the Owner has not configured a frame_id for
// the level, and only when the member has no equipped custom frame.
// Precedence: equipped custom frame > Owner vip_rule frame > animal frame.
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

export const VIP_FRAME_CATALOG = [
  { id: "vip-frame-5", kind: "frame", level: 5, animal: "deer", name: "Deer Frame", min_vip_level: 5, duration_days: 30, frame_key: "frames/vip5-deer-transparent.webm", still_key: "frames/vip5-deer-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-6", kind: "frame", level: 6, animal: "wolf", name: "Wolf Frame", min_vip_level: 6, duration_days: 30, frame_key: "frames/vip6-wolf-transparent.webm", still_key: "frames/vip6-wolf-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-7", kind: "frame", level: 7, animal: "eagle", name: "Eagle Frame", min_vip_level: 7, duration_days: 30, frame_key: "frames/vip7-eagle-transparent.webm", still_key: "frames/vip7-eagle-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-8", kind: "frame", level: 8, animal: "panther", name: "Panther Frame", min_vip_level: 8, duration_days: 30, frame_key: "frames/vip8-panther-transparent.webm", still_key: "frames/vip8-panther-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-9", kind: "frame", level: 9, animal: "cobra", name: "Cobra Frame", min_vip_level: 9, duration_days: 30, frame_key: "frames/vip9-cobra-transparent.webm", still_key: "frames/vip9-cobra-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-10", kind: "frame", level: 10, animal: "lion", name: "Lion Frame", min_vip_level: 10, duration_days: 30, frame_key: "frames/vip10-lion-transparent.webm", still_key: "frames/vip10-lion-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-11", kind: "frame", level: 11, animal: "tiger", name: "Tiger Frame", min_vip_level: 11, duration_days: 30, frame_key: "frames/vip11-tiger-transparent.webm", still_key: "frames/vip11-tiger-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-12", kind: "frame", level: 12, animal: "mammoth", name: "Mammoth Frame", min_vip_level: 12, duration_days: 30, frame_key: "frames/vip12-mammoth-transparent.webm", still_key: "frames/vip12-mammoth-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-13", kind: "frame", level: 13, animal: "gorilla", name: "Gorilla Frame", min_vip_level: 13, duration_days: 30, frame_key: "frames/vip13-gorilla-transparent.webm", still_key: "frames/vip13-gorilla-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-14", kind: "frame", level: 14, animal: "bear", name: "Bear Frame", min_vip_level: 14, duration_days: 30, frame_key: "frames/vip14-bear-transparent.webm", still_key: "frames/vip14-bear-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-15", kind: "frame", level: 15, animal: "kraken", name: "Kraken Frame", min_vip_level: 15, duration_days: 30, frame_key: "frames/vip15-kraken-transparent.webm", still_key: "frames/vip15-kraken-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-16", kind: "frame", level: 16, animal: "leviathan", name: "Leviathan Frame", min_vip_level: 16, duration_days: 30, frame_key: "frames/vip16-leviathan-transparent.webm", still_key: "frames/vip16-leviathan-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-17", kind: "frame", level: 17, animal: "phoenix", name: "Phoenix Frame", min_vip_level: 17, duration_days: 30, frame_key: "frames/vip17-phoenix-transparent.webm", still_key: "frames/vip17-phoenix-transparent.png", animation_ms: 5200 },
  { id: "vip-frame-18", kind: "frame", level: 18, animal: "dragon", name: "Dragon Frame", min_vip_level: 18, duration_days: 30, frame_key: "frames/vip18-dragon-transparent.webm", still_key: "frames/vip18-dragon-transparent.png", animation_ms: 5200 },
];

export function frameForVipLevel(level) {
  const vipLevel = Number(level) || 0;
  if (vipLevel < 5 || vipLevel > 18) return null;
  return VIP_FRAME_CATALOG.find((entry) => entry.level === vipLevel) ?? null;
}

export function frameById(id) {
  const key = String(id ?? "").trim();
  if (!key) return null;
  return VIP_FRAME_CATALOG.find((entry) => entry.id === key) ?? null;
}

/// Catalog item in the shape vipVisualsForLevel() returns for a frame:
/// asset_key is the transparent PNG still (the display path today),
/// video_key is the transparent WebM (for a future alpha-video player).
export function frameVisualForVipLevel(level) {
  const entry = frameForVipLevel(level);
  if (!entry) return null;
  return {
    id: entry.id,
    kind: "frame",
    name: entry.name,
    asset_key: entry.still_key,
    video_key: entry.frame_key,
    glb_key: "",
    media_type: "image",
    animation_type: "frame_loop",
    animation_ms: entry.animation_ms,
  };
}

export function frameVideoUrlForVipLevel(level) {
  const entry = frameForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.frame_key}`;
}

export function frameStillUrlForVipLevel(level) {
  const entry = frameForVipLevel(level);
  if (!entry || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${entry.still_key}`;
}

export function allFrameVideoUrls() {
  return VIP_FRAME_CATALOG.map((entry) => frameVideoUrlForVipLevel(entry.level));
}

export function allFrameStillUrls() {
  return VIP_FRAME_CATALOG.map((entry) => frameStillUrlForVipLevel(entry.level));
}
