import test from "node:test";
import assert from "node:assert/strict";

import {
  MEDAL_TYPE_LEVELS,
  ACHIEVEMENT_MEDALS,
  MEDAL_TYPE_NAMES,
  MEDAL_TYPE_VALIDITY,
  medalTypeKeyForLevel,
  medalTypeUrlForLevel,
  allMedalTypeKeys,
  allMedalTypeKeysAll,
  medalTypeValidityText,
  medalTypeIsPermanent,
} from "../src/medal_types_catalog.js";

test("medal types: PK and Verified are NOT in the catalog", () => {
  assert.equal("pk" in MEDAL_TYPE_LEVELS, false);
  assert.equal("verified" in MEDAL_TYPE_LEVELS, false);
  assert.equal("pk" in MEDAL_TYPE_NAMES, false);
  assert.equal("verified" in MEDAL_TYPE_NAMES, false);
});

test("medal types: level counts match the approved plan", () => {
  assert.equal(MEDAL_TYPE_LEVELS.wealth, 18);
  assert.equal(MEDAL_TYPE_LEVELS.fanclub, 18);
  assert.equal(MEDAL_TYPE_LEVELS.achievement, 10);
  assert.equal(MEDAL_TYPE_LEVELS.family, 10);
  assert.equal(MEDAL_TYPE_LEVELS.charm, 18);
  assert.equal(MEDAL_TYPE_LEVELS.noble, 10);
  assert.equal(MEDAL_TYPE_LEVELS.room, 3);
  assert.equal(MEDAL_TYPE_LEVELS.event, 1);
});

test("medal types: 6 achievement medals, PK Winner replaced by Top Gifter", () => {
  assert.equal(ACHIEVEMENT_MEDALS.length, 6);
  const slugs = ACHIEVEMENT_MEDALS.map((m) => m.slug);
  assert.deepEqual(slugs, [
    "active",
    "wealth",
    "live",
    "livestar",
    "topgifter",
    "fanpower",
  ]);
  assert.equal(slugs.includes("pk"), false);
});

test("medal types: R2 keys are medals/<type>-lvNN.png", () => {
  assert.equal(medalTypeKeyForLevel("wealth", 1), "medals/wealth-lv01.png");
  assert.equal(medalTypeKeyForLevel("wealth", 18), "medals/wealth-lv18.png");
  assert.equal(medalTypeKeyForLevel("fanclub", 5), "medals/fanclub-lv05.png");
  assert.equal(medalTypeKeyForLevel("family", 10), "medals/family-lv10.png");
  assert.equal(medalTypeKeyForLevel("charm", 18), "medals/charm-lv18.png");
  assert.equal(medalTypeKeyForLevel("noble", 1), "medals/noble-lv01.png");
  assert.equal(medalTypeKeyForLevel("room", 1), "medals/room-top1.png");
  assert.equal(medalTypeKeyForLevel("room", 3), "medals/room-top3.png");
  assert.equal(medalTypeKeyForLevel("event", 1), "medals/event-base.png");
  assert.equal(
    medalTypeKeyForLevel("achievement", 1, "topgifter"),
    "medals/achievement-topgifter-lv01.png",
  );
  assert.equal(
    medalTypeKeyForLevel("achievement", 10, "active"),
    "medals/achievement-active-lv10.png",
  );
});

test("medal types: levels clamp to the series range", () => {
  assert.equal(medalTypeKeyForLevel("wealth", 0), "medals/wealth-lv01.png");
  assert.equal(medalTypeKeyForLevel("wealth", 99), "medals/wealth-lv18.png");
  assert.equal(medalTypeKeyForLevel("family", 99), "medals/family-lv10.png");
  assert.equal(medalTypeKeyForLevel("room", 99), "medals/room-top3.png");
  assert.equal(medalTypeKeyForLevel("unknown", 1), null);
});

test("medal types: URLs are direct R2 URLs", () => {
  const url = medalTypeUrlForLevel("wealth", 1);
  assert.ok(url.startsWith("https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev/"));
  assert.ok(url.endsWith("medals/wealth-lv01.png"));
  assert.equal(medalTypeUrlForLevel("unknown", 1), null);
});

test("medal types: 138 images in total", () => {
  // Wealth 18 + Fan Club 18 + Achievement 60 + Family 10 + Charm 18 +
  // Noble 10 + Room 3 + Event 1 = 138.
  assert.equal(allMedalTypeKeys("wealth").length, 18);
  assert.equal(allMedalTypeKeys("fanclub").length, 18);
  assert.equal(allMedalTypeKeys("achievement").length, 60);
  assert.equal(allMedalTypeKeys("family").length, 10);
  assert.equal(allMedalTypeKeys("charm").length, 18);
  assert.equal(allMedalTypeKeys("noble").length, 10);
  assert.equal(allMedalTypeKeys("room").length, 3);
  assert.equal(allMedalTypeKeys("event").length, 1);
  const all = allMedalTypeKeysAll();
  assert.equal(all.length, 138);
  assert.equal(new Set(all).size, 138, "all R2 keys must be unique");
});

test("medal types: permanent vs days-based validity", () => {
  assert.equal(medalTypeIsPermanent("wealth"), true);
  assert.equal(medalTypeIsPermanent("achievement"), true);
  assert.equal(medalTypeIsPermanent("event"), true);
  assert.equal(medalTypeIsPermanent("fanclub"), false);
  assert.equal(medalTypeIsPermanent("family"), false);
  assert.equal(medalTypeIsPermanent("charm"), false);
  assert.equal(medalTypeIsPermanent("noble"), false);
  assert.equal(medalTypeIsPermanent("room"), false);

  assert.equal(medalTypeValidityText("wealth"), "Permanent");
  assert.equal(medalTypeValidityText("achievement"), "Permanent");
  assert.equal(medalTypeValidityText("event"), "Permanent");
  assert.equal(medalTypeValidityText("fanclub"), "30 days");
  assert.equal(medalTypeValidityText("family"), "30 days");
  assert.equal(medalTypeValidityText("charm"), "30 days");
  assert.equal(medalTypeValidityText("noble"), "30 days");
  assert.equal(medalTypeValidityText("room"), "7 days");

  assert.equal(MEDAL_TYPE_VALIDITY.room.days, 7);
  assert.equal(MEDAL_TYPE_VALIDITY.fanclub.days, 30);
});
