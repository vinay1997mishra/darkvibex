import test from "node:test";
import assert from "node:assert/strict";
import {
  VEHICLE_ENTRY_CATALOG,
  BOTTOM_ENTRY_HEIGHT_FRACTION,
  FULLSCREEN_HEIGHT_FRACTION,
  SUPER_PREMIUM_MIN_VIP,
  layoutForVipLevel,
  isFullscreenVipLevel,
  vehicleForTier,
  vehicleForVipLevel,
  vehicleByStyleId,
  videoUrlForVipLevel,
  vehicleVisualForVipLevel,
  allVideoUrls,
} from "../src/vehicle_entry_animals.js";

const R2_BASE = "https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev";

test("animal vehicle catalog covers VIP5-18 with one animal per level", () => {
  assert.equal(VEHICLE_ENTRY_CATALOG.length, 14);
  assert.deepEqual(
    VEHICLE_ENTRY_CATALOG.map((entry) => entry.min_vip_level),
    [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
  );
  assert.deepEqual(
    VEHICLE_ENTRY_CATALOG.map((entry) => entry.tier),
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  );
  assert.deepEqual(
    VEHICLE_ENTRY_CATALOG.map((entry) => entry.style_id),
    [
      "deer", "wolf", "eagle", "panther", "cobra", "lion", "tiger",
      "mammoth", "gorilla", "bear", "kraken", "leviathan", "phoenix",
      "dragon",
    ],
  );
  assert.equal(new Set(VEHICLE_ENTRY_CATALOG.map((entry) => entry.id)).size, 14);
  assert.ok(VEHICLE_ENTRY_CATALOG.every((entry) => entry.kind === "vehicle"));
  assert.ok(VEHICLE_ENTRY_CATALOG.every((entry) => entry.price_coins === 0));
  assert.ok(VEHICLE_ENTRY_CATALOG.every((entry) => entry.duration_days === 30));
});

test("Phoenix is VIP17 and Dragon is VIP18 (not the old car tiers)", () => {
  assert.equal(vehicleForVipLevel(17)?.style_id, "phoenix");
  assert.equal(vehicleForVipLevel(17)?.id, "vehicle_phoenix");
  assert.equal(vehicleForVipLevel(18)?.style_id, "dragon");
  assert.equal(vehicleForVipLevel(12)?.style_id, "mammoth");
  assert.equal(vehicleForTier(13)?.min_vip_level, 17);
  assert.equal(vehicleByStyleId("phoenix")?.min_vip_level, 17);
  assert.equal(vehicleForVipLevel(4), null);
  assert.equal(vehicleForVipLevel(19), null);
  assert.equal(vehicleForTier(0), null);
  assert.equal(vehicleForTier(15), null);
});

test("vehicle video URLs point directly at the R2 vehicles/ keys", () => {
  assert.equal(videoUrlForVipLevel(5), `${R2_BASE}/vehicles/vip5-deer.mp4`);
  assert.equal(videoUrlForVipLevel(17), `${R2_BASE}/vehicles/vip17-phoenix.mp4`);
  assert.equal(videoUrlForVipLevel(18), `${R2_BASE}/vehicles/vip18-dragon.mp4`);
  assert.equal(videoUrlForVipLevel(4), null);
  assert.equal(allVideoUrls().length, 14);
  assert.ok(
    allVideoUrls().every((entry) => entry.video_url.startsWith(`${R2_BASE}/vehicles/vip`)),
  );
  assert.ok(
    allVideoUrls().every((entry) => entry.video_url.endsWith(".mp4")),
  );
});

test("vehicle layout is bottom 40% for VIP5-15 and full-screen for VIP16-18", () => {
  assert.equal(BOTTOM_ENTRY_HEIGHT_FRACTION, 0.40);
  assert.equal(FULLSCREEN_HEIGHT_FRACTION, 1.0);
  assert.equal(SUPER_PREMIUM_MIN_VIP, 16);
  for (let level = 5; level <= 15; level++) {
    assert.deepEqual(layoutForVipLevel(level), { anchor: "bottom", heightFraction: 0.40 });
    assert.equal(isFullscreenVipLevel(level), false);
  }
  for (let level = 16; level <= 18; level++) {
    assert.deepEqual(layoutForVipLevel(level), { anchor: "full", heightFraction: 1.0 });
    assert.equal(isFullscreenVipLevel(level), true);
  }
  assert.equal(layoutForVipLevel(4), null);
});

test("vehicle visual fallback returns the level animal video for vipVisualsForLevel", () => {
  const visual = vehicleVisualForVipLevel(17);
  assert.equal(visual.id, "vehicle_phoenix");
  assert.equal(visual.kind, "vehicle");
  assert.equal(visual.video_key, "vehicles/vip17-phoenix.mp4");
  assert.equal(visual.glb_key, "");
  assert.equal(visual.media_type, "video");
  assert.equal(visual.animation_ms, 10000);
  assert.equal(vehicleVisualForVipLevel(14).animation_ms, 8000);
  assert.equal(vehicleVisualForVipLevel(5).id, "vehicle_deer");
  assert.equal(vehicleVisualForVipLevel(4), null);
  assert.equal(vehicleVisualForVipLevel(19), null);
});
