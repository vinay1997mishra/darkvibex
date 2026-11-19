// DarkVibeX — Medal Types Catalog (all medal series beyond VIP/Rocket)
//
// Every medal series in the app, with its levels, R2 keys and how it is
// earned. VIP medals (VIP 1-18) live in vip_medal_catalog.js (VIP1-4
// PNGs) / bundled SVGs; Rocket medals (Rocket 1-18) live in
// rocket_rewards.js (targets) and rocket-medals/ on R2. This file covers
// the NEW series Vinay approved 2026-11-19 ("Thik hai bana ke add kar
// de saare"):
//
//   Wealth      1-18  — total coins gifted (sent) by the user.
//   Fan Club    1-18  — gifting one host; shows WITH the user's name.
//   Achievement 6 medals x Lv.1-10 — completing feats (Active Star,
//               Wealth, Live Stream, Live Star, Top Gifter, Fan Power).
//   Family      1-10  — family points.
//   Host/Charm  1-18  — host popularity (gifts received + fans).
//   Noble       1-10  — noble rank (paid, like Poppo Noble).
//   Room        Top 1/2/3 — a room's top supporters (no levels).
//   Event       1 (no level) — taking part in a limited-time event.
//
// PK medals and Verified badges were REMOVED by Vinay 2026-11-19
// ("Pk madal hta de", "Verified ka bhi hta de") — they are NOT here.
//
// R2 (bucket "darkvibex-files"): medals/<key>.png (image/png,
// transparent background, ~512px). Medal art is displayed DIRECTLY
// from R2 by the app (LevelMedal widget + medal gallery), same as the
// Rocket medals — no worker route needed for display.
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL, R2_BUCKET } from "./vehicle_entry_animals.js";

export { R2_PUBLIC_BASE_URL, R2_BUCKET };

/// Level counts per series. Achievement is 6 medals x 10 levels.
/// Fan Club: the medal is earned by gifting a host, and it shows WITH
/// the user's name (Vinay, 2026-11-19: "Jisko madal milega uske name
/// ke sath rahega"). No separate Fan Club join page — just the medal.
export const MEDAL_TYPE_LEVELS = {
  wealth: 18,
  fanclub: 18,
  achievement: 10,
  family: 10,
  charm: 18,
  noble: 10,
  room: 3,
  event: 1,
};

/// The 6 achievement medals (Mico-style Medal Wall). PK Winner was
/// replaced by Top Gifter — Vinay removed everything PK-related.
export const ACHIEVEMENT_MEDALS = [
  { id: "active", name: "Active Star", slug: "active" },
  { id: "wealth", name: "Wealth", slug: "wealth" },
  { id: "live", name: "Live Stream", slug: "live" },
  { id: "livestar", name: "Live Star", slug: "livestar" },
  { id: "topgifter", name: "Top Gifter", slug: "topgifter" },
  { id: "fanpower", name: "Fan Power", slug: "fanpower" },
];

/// Human-readable series names for the gallery.
export const MEDAL_TYPE_NAMES = {
  wealth: "Wealth",
  fanclub: "Fan Club",
  achievement: "Achievement",
  family: "Family",
  charm: "Host Charm",
  noble: "Noble",
  room: "Room",
  event: "Event",
};

/// How each series is earned (display text, not enforced here).
export const MEDAL_TYPE_EARNED_BY = {
  wealth: "Total coins gifted",
  fanclub: "Gifting one host",
  achievement: "Completing feats",
  family: "Family points",
  charm: "Host popularity",
  noble: "Noble rank",
  room: "Top supporter in a room",
  event: "Taking part in an event",
};

// ---------------------------------------------------------------------------
// Validity: permanent vs days-based (Vinay, 2026-11-19)
// ---------------------------------------------------------------------------
//
// PERMANENT (once earned, stays in the collection forever):
//   Wealth, Achievement, Event, Rocket (rocket lives in rocket_rewards.js).
//   These are cumulative / one-time feats — the total never goes down.
//
// DAYS-BASED (expires, needs renewal / ongoing activity):
//   VIP  — 30 days (VIP1-15) / 60 days (VIP16-18), drops 1 level on
//          expiry if not levelled up (existing VIP rule, vip_policy.js).
//   Noble — 30 days (paid monthly, like VIP).
//   Fan Club — 30 days: keep gifting the host; 30 days inactive
//          drops 1 level (same drop-by-1 rule as VIP).
//   Family — 30 days: family points reset monthly; the medal follows
//          the current month's family level.
//   Charm — 30 days: rolling 30-day popularity (gifts received + fans);
//          the medal follows the current charm level.
//   Room — 7 days: weekly top supporters; a new week means new winners.

/// Validity per series: { kind: "permanent" } or
/// { kind: "days", days: N } (VIP is handled by vip_policy.js).
export const MEDAL_TYPE_VALIDITY = {
  wealth: { kind: "permanent" },
  fanclub: { kind: "days", days: 30 },
  achievement: { kind: "permanent" },
  family: { kind: "days", days: 30 },
  charm: { kind: "days", days: 30 },
  noble: { kind: "days", days: 30 },
  room: { kind: "days", days: 7 },
  event: { kind: "permanent" },
};

/// Display text for a series' validity ("Permanent" / "30 days" / "7 days").
export function medalTypeValidityText(type) {
  const series = String(type ?? "").trim().toLowerCase();
  const validity = MEDAL_TYPE_VALIDITY[series];
  if (!validity) return "";
  if (validity.kind === "permanent") return "Permanent";
  return `${validity.days} days`;
}

/// True when a series never expires.
export function medalTypeIsPermanent(type) {
  const series = String(type ?? "").trim().toLowerCase();
  return MEDAL_TYPE_VALIDITY[series]?.kind === "permanent";
}

/// R2 key of one medal image.
///
/// [type] is one of wealth/fanclub/achievement/family/charm/noble/room/
/// event. [level] is clamped to the series range. For achievement,
/// [achievement] is the achievement slug (active/wealth/live/livestar/
/// topgifter/fanpower). For room, [level] is the rank 1-3 (Top 1/2/3).
export function medalTypeKeyForLevel(type, level, achievement = null) {
  const series = String(type ?? "").trim().toLowerCase();
  if (!(series in MEDAL_TYPE_LEVELS)) return null;
  const max = MEDAL_TYPE_LEVELS[series];
  const safeLevel = Math.max(1, Math.min(max, Number(level) || 1));
  if (series === "room") {
    return `medals/room-top${safeLevel}.png`;
  }
  if (series === "event") {
    return "medals/event-base.png";
  }
  if (series === "achievement") {
    const slug = String(achievement ?? "active").trim().toLowerCase();
    const known = ACHIEVEMENT_MEDALS.find((m) => m.slug === slug);
    const safeSlug = known ? known.slug : "active";
    return `medals/achievement-${safeSlug}-lv${String(safeLevel).padStart(2, "0")}.png`;
  }
  return `medals/${series}-lv${String(safeLevel).padStart(2, "0")}.png`;
}

/// Direct R2 URL of one medal image, or null for an unknown series.
export function medalTypeUrlForLevel(type, level, achievement = null) {
  const key = medalTypeKeyForLevel(type, level, achievement);
  if (!key || !R2_PUBLIC_BASE_URL) return null;
  return `${R2_PUBLIC_BASE_URL}/${key}`;
}

/// Every R2 key in a series (achievement = all 6 medals x 10 levels).
export function allMedalTypeKeys(type) {
  const series = String(type ?? "").trim().toLowerCase();
  if (!(series in MEDAL_TYPE_LEVELS)) return [];
  if (series === "room") return [1, 2, 3].map((r) => medalTypeKeyForLevel("room", r));
  if (series === "event") return ["medals/event-base.png"];
  if (series === "achievement") {
    const keys = [];
    for (const medal of ACHIEVEMENT_MEDALS) {
      for (let level = 1; level <= 10; level++) {
        keys.push(medalTypeKeyForLevel("achievement", level, medal.slug));
      }
    }
    return keys;
  }
  const keys = [];
  for (let level = 1; level <= MEDAL_TYPE_LEVELS[series]; level++) {
    keys.push(medalTypeKeyForLevel(series, level));
  }
  return keys;
}

/// Every medal R2 key across all series (138 images).
export function allMedalTypeKeysAll() {
  return Object.keys(MEDAL_TYPE_LEVELS).flatMap((type) => allMedalTypeKeys(type));
}
