// DarkVibeX — Panda Seat Emote Catalog
//
// 20 full-body panda emotes for the room emoji panel (Vinay, 2026-11-19:
// "Panda wale me 20 emoji bana", "seat per dikhna chahiye", "room me
// emoji wale me alag section bana ke panda ka"). Each emote is a
// full-body cute panda that plays ON the mic seat, above the sender's
// DP — like the big animated emoji reactions in Bigo Live / QK Live,
// which appear over the avatar, not inside it.
//
// The emoji panel has two tabs: "Emoji" (the existing unicode emojis)
// and "Panda" (these 20). Tapping a panda emote sends the marker
// `[panda:<name>]` as a room message; the seat-reaction sync in
// room_screen.dart recognises the marker and plays the video on the
// sender's seat for 5 seconds. The marker text is never shown in the
// chat — the chat line renders as "sent a panda emote" instead.
//
// R2 (bucket "darkvibex-files"), direct public URLs, no Worker hop:
//   WebM (VP9 alpha, transparent): seat-emotes/panda/panda-<name>-transparent.webm
//   VAP v1 MP4 (alpha mask LEFT, RGB RIGHT, for flutter_vap_player —
//   Flutter video_player cannot show VP9 alpha):
//   seat-emotes/panda/vap/panda-<name>.mp4
//
// R2_PUBLIC_BASE_URL is imported from vehicle_entry_animals.js so the
// public base lives in exactly one place.

import { R2_PUBLIC_BASE_URL } from "./vehicle_entry_animals.js";

/// The 20 panda emotes, in panel order.
export const PANDA_EMOTE_NAMES = [
  "happy",
  "sad",
  "crying",
  "angry",
  "love",
  "laughing",
  "sleeping",
  "cool",
  "surprised",
  "winking",
  "kissing",
  "blushing",
  "hungry",
  "dancing",
  "waving",
  "clapping",
  "thinking",
  "scared",
  "silly",
  "party",
];

/// Display label for the panel grid (English, short).
export const PANDA_EMOTE_LABELS = {
  happy: "Happy",
  sad: "Sad",
  crying: "Crying",
  angry: "Angry",
  love: "Love",
  laughing: "Laughing",
  sleeping: "Sleeping",
  cool: "Cool",
  surprised: "Surprised",
  winking: "Winking",
  kissing: "Kissing",
  blushing: "Blushing",
  hungry: "Hungry",
  dancing: "Dancing",
  waving: "Waving",
  clapping: "Clapping",
  thinking: "Thinking",
  scared: "Scared",
  silly: "Silly",
  party: "Party",
};

/// True when [name] is one of the 20 panda emotes.
export function isPandaEmoteName(name) {
  return typeof name === "string" && PANDA_EMOTE_NAMES.includes(name);
}

/// R2 key of the transparent WebM for [name]. Null for unknown names.
export function pandaEmoteWebmKeyForName(name) {
  if (!isPandaEmoteName(name)) return null;
  return `seat-emotes/panda/panda-${name}-transparent.webm`;
}

/// R2 key of the VAP v1 MP4 for [name] (what the app plays on the
/// seat). Null for unknown names.
export function pandaEmoteVapKeyForName(name) {
  if (!isPandaEmoteName(name)) return null;
  return `seat-emotes/panda/vap/panda-${name}.mp4`;
}

/// Direct R2 URL of the VAP MP4 for [name]. Null for unknown names.
export function pandaEmoteVapUrlForName(name) {
  const key = pandaEmoteVapKeyForName(name);
  if (key == null) return null;
  return `${R2_PUBLIC_BASE_URL}/${key}`;
}

/// Direct R2 URL of the transparent WebM for [name]. Null for unknown
/// names.
export function pandaEmoteWebmUrlForName(name) {
  const key = pandaEmoteWebmKeyForName(name);
  if (key == null) return null;
  return `${R2_PUBLIC_BASE_URL}/${key}`;
}

/// The chat marker sent when a user taps a panda emote in the panel.
export function pandaEmoteMarkerForName(name) {
  if (!isPandaEmoteName(name)) return null;
  return `[panda:${name}]`;
}

/// Parses a chat message back into a panda emote name: "[panda:happy]"
/// -> "happy". Returns null for anything else (including plain text
/// emojis and other bracket text).
export function pandaEmoteNameFromMarker(text) {
  if (typeof text !== "string") return null;
  const trimmed = text.trim();
  const match = /^\[panda:([a-z]+)\]$/.exec(trimmed);
  if (match == null) return null;
  const name = match[1];
  return isPandaEmoteName(name) ? name : null;
}

/// All 20 VAP R2 keys (for upload verification).
export function allPandaEmoteVapKeys() {
  return PANDA_EMOTE_NAMES.map((name) => pandaEmoteVapKeyForName(name));
}

/// All 20 WebM R2 keys (for upload verification).
export function allPandaEmoteWebmKeys() {
  return PANDA_EMOTE_NAMES.map((name) => pandaEmoteWebmKeyForName(name));
}
