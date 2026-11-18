import test from "node:test";
import assert from "node:assert/strict";
import {
  VIP_FRAME_CATALOG,
  frameForVipLevel,
  frameVisualForVipLevel,
  frameVideoUrlForVipLevel,
  frameStillUrlForVipLevel,
  frameVapUrlForVipLevel,
  allFrameVideoUrls,
  allFrameStillUrls,
  allFrameVapUrls,
} from "../src/vip_frame_catalog.js";
import {
  VIP_ENTRY_EFFECT_CATALOG,
  entryEffectForVipLevel,
  entryEffectVisualForVipLevel,
  entryEffectUrlForVipLevel,
} from "../src/vip_entry_effect_catalog.js";
import {
  VIP_TAG_CATALOG,
  tagForVipLevel,
  tagVisualForVipLevel,
  tagUrlForVipLevel,
} from "../src/vip_tag_catalog.js";

const R2_BASE = "https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev";

test("VIP frame catalog covers VIP5-18 with one animal frame per level", () => {
  assert.equal(VIP_FRAME_CATALOG.length, 14);
  assert.deepEqual(
    VIP_FRAME_CATALOG.map((entry) => entry.level),
    [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
  );
  assert.equal(new Set(VIP_FRAME_CATALOG.map((entry) => entry.id)).size, 14);
  assert.equal(frameForVipLevel(5)?.animal, "deer");
  assert.equal(frameForVipLevel(13)?.animal, "gorilla");
  assert.equal(frameForVipLevel(17)?.animal, "phoenix");
  assert.equal(frameForVipLevel(18)?.animal, "dragon");
  assert.equal(frameForVipLevel(4), null);
  assert.equal(frameForVipLevel(0), null);
  assert.equal(frameForVipLevel(19), null);
});

test("VIP frame URLs point at the R2 frames/ keys (WebM video + PNG still)", () => {
  assert.equal(
    frameVideoUrlForVipLevel(13),
    `${R2_BASE}/frames/vip13-gorilla-transparent.webm`,
  );
  assert.equal(
    frameStillUrlForVipLevel(13),
    `${R2_BASE}/frames/vip13-gorilla-transparent.png`,
  );
  assert.equal(frameVideoUrlForVipLevel(4), null);
  assert.equal(allFrameVideoUrls().length, 14);
  assert.ok(allFrameVideoUrls().every((url) => url.startsWith(`${R2_BASE}/frames/`)));
  assert.ok(allFrameStillUrls().every((url) => url.endsWith("-transparent.png")));
});

test("VIP frame visual uses the PNG still as the display asset", () => {
  // video_player cannot show VP9 alpha (opaque texture -> black box), so
  // the display path is the transparent PNG still (asset_key); the WebM
  // is carried as video_key for a future alpha-capable player.
  const visual = frameVisualForVipLevel(7);
  assert.equal(visual.id, "vip-frame-7");
  assert.equal(visual.kind, "frame");
  assert.equal(visual.asset_key, "frames/vip7-eagle-transparent.png");
  assert.equal(visual.video_key, "frames/vip7-eagle-transparent.webm");
});

test("VIP frame VAP URLs point at the R2 vap/ keys (Tencent VAP mp4)", () => {
  // VAP v1: H.264 MP4, alpha mask on the LEFT half, RGB on the RIGHT half
  // of each frame; played by flutter_vap_player with enableOldVersion.
  assert.equal(
    frameVapUrlForVipLevel(13),
    `${R2_BASE}/vap/vip13-gorilla.mp4`,
  );
  assert.equal(
    frameVapUrlForVipLevel(5),
    `${R2_BASE}/vap/vip5-deer.mp4`,
  );
  assert.equal(frameVapUrlForVipLevel(4), null);
  assert.equal(frameVapUrlForVipLevel(19), null);
  assert.equal(allFrameVapUrls().length, 14);
  assert.ok(allFrameVapUrls().every((url) => url.startsWith(`${R2_BASE}/vap/`)));
  assert.ok(allFrameVapUrls().every((url) => url.endsWith(".mp4")));
  assert.equal(frameVisualForVipLevel(7).vap_key, "vap/vip7-eagle.mp4");
  assert.equal(frameVisualForVipLevel(18).vap_key, "vap/vip18-dragon.mp4");
});

test("VIP entry-effect catalog covers VIP5-18 with R2 banner URLs", () => {
  assert.equal(VIP_ENTRY_EFFECT_CATALOG.length, 14);
  assert.equal(entryEffectForVipLevel(5)?.animal, "deer");
  assert.equal(entryEffectForVipLevel(10)?.animal, "lion");
  assert.equal(entryEffectForVipLevel(18)?.animal, "dragon");
  assert.equal(entryEffectForVipLevel(4), null);
  assert.equal(
    entryEffectUrlForVipLevel(10),
    `${R2_BASE}/entry-effects/vip10-entry.png`,
  );
  const visual = entryEffectVisualForVipLevel(13);
  assert.equal(visual.id, "vip-entry-13");
  assert.equal(visual.asset_key, "entry-effects/vip13-entry.png");
  assert.equal(visual.video_key, "");
});

test("VIP tag catalog covers VIP5-18 with R2 tag URLs", () => {
  assert.equal(VIP_TAG_CATALOG.length, 14);
  assert.equal(tagForVipLevel(5)?.animal, "deer");
  assert.equal(tagForVipLevel(17)?.animal, "phoenix");
  assert.equal(tagForVipLevel(18)?.animal, "dragon");
  assert.equal(tagForVipLevel(4), null);
  assert.equal(
    tagUrlForVipLevel(18),
    `${R2_BASE}/vip-tags/vip18-tag.png`,
  );
  const visual = tagVisualForVipLevel(6);
  assert.equal(visual.id, "vip-tag-6");
  assert.equal(visual.asset_key, "vip-tags/vip6-tag.png");
});
