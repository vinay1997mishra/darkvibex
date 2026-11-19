import test from "node:test";
import assert from "node:assert/strict";

import {
  PANDA_EMOTE_NAMES,
  PANDA_EMOTE_LABELS,
  isPandaEmoteName,
  pandaEmoteWebmKeyForName,
  pandaEmoteVapKeyForName,
  pandaEmoteVapUrlForName,
  pandaEmoteWebmUrlForName,
  pandaEmoteMarkerForName,
  pandaEmoteNameFromMarker,
  allPandaEmoteVapKeys,
  allPandaEmoteWebmKeys,
} from "../src/panda_emote_catalog.js";

test("panda emotes: exactly the 20 Vinay asked for", () => {
  assert.equal(PANDA_EMOTE_NAMES.length, 20);
  assert.equal(new Set(PANDA_EMOTE_NAMES).size, 20);
  for (const name of [
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
  ]) {
    assert.equal(PANDA_EMOTE_NAMES.includes(name), true, name);
    assert.equal(typeof PANDA_EMOTE_LABELS[name], "string", name);
  }
});

test("panda emotes: R2 keys follow the seat-emotes/panda layout", () => {
  assert.equal(
    pandaEmoteVapKeyForName("happy"),
    "seat-emotes/panda/vap/panda-happy.mp4",
  );
  assert.equal(
    pandaEmoteWebmKeyForName("happy"),
    "seat-emotes/panda/panda-happy-transparent.webm",
  );
  assert.equal(
    pandaEmoteVapKeyForName("party"),
    "seat-emotes/panda/vap/panda-party.mp4",
  );
  assert.equal(pandaEmoteVapKeyForName("dragon"), null);
  assert.equal(pandaEmoteWebmKeyForName(""), null);
  assert.equal(pandaEmoteVapKeyForName(null), null);
});

test("panda emotes: direct R2 URLs use the public base", () => {
  const url = pandaEmoteVapUrlForName("laughing");
  assert.equal(
    url,
    "https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev/seat-emotes/panda/vap/panda-laughing.mp4",
  );
  assert.equal(
    pandaEmoteWebmUrlForName("sad"),
    "https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev/seat-emotes/panda/panda-sad-transparent.webm",
  );
  assert.equal(pandaEmoteVapUrlForName("nope"), null);
});

test("panda emotes: marker round-trips through the parser", () => {
  assert.equal(pandaEmoteMarkerForName("happy"), "[panda:happy]");
  assert.equal(pandaEmoteMarkerForName("dragon"), null);
  assert.equal(pandaEmoteNameFromMarker("[panda:happy]"), "happy");
  assert.equal(pandaEmoteNameFromMarker("  [panda:party]  "), "party");
  assert.equal(pandaEmoteNameFromMarker("[panda:dragon]"), null);
  assert.equal(pandaEmoteNameFromMarker("😂"), null);
  assert.equal(pandaEmoteNameFromMarker("[panda:]"), null);
  assert.equal(pandaEmoteNameFromMarker("[Panda:happy]"), null);
  assert.equal(pandaEmoteNameFromMarker("hello [panda:happy]"), null);
  assert.equal(pandaEmoteNameFromMarker(null), null);
});

test("panda emotes: 20 VAP + 20 WebM keys, all unique", () => {
  const vap = allPandaEmoteVapKeys();
  const webm = allPandaEmoteWebmKeys();
  assert.equal(vap.length, 20);
  assert.equal(webm.length, 20);
  assert.equal(new Set(vap).size, 20);
  assert.equal(new Set(webm).size, 20);
  for (const key of vap) {
    assert.equal(key.startsWith("seat-emotes/panda/vap/panda-"), true, key);
    assert.equal(key.endsWith(".mp4"), true, key);
  }
  for (const key of webm) {
    assert.equal(
      key.startsWith("seat-emotes/panda/panda-"),
      true,
      key,
    );
    assert.equal(key.endsWith("-transparent.webm"), true, key);
  }
});

test("panda emotes: isPandaEmoteName only accepts the 20 names", () => {
  assert.equal(isPandaEmoteName("happy"), true);
  assert.equal(isPandaEmoteName("party"), true);
  assert.equal(isPandaEmoteName("Happy"), false);
  assert.equal(isPandaEmoteName("dragon"), false);
  assert.equal(isPandaEmoteName(""), false);
  assert.equal(isPandaEmoteName(null), false);
});
