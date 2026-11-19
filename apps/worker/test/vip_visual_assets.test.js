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
import {
  VIP_MEDAL_CATALOG,
  medalForVipLevel,
  medalVisualForVipLevel,
  medalUrlForVipLevel,
  allMedalUrls,
} from "../src/vip_medal_catalog.js";
import {
  VIP_SCENIC_BANNER_CATALOG,
  scenicBannerForVipLevel,
  scenicBannerVisualForVipLevel,
  scenicBannerUrlForVipLevel,
  allScenicBannerUrls,
} from "../src/vip_scenic_banner_catalog.js";

const R2_BASE = "https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev";

test("VIP frame catalog covers VIP1-18 with one animal frame per level", () => {
  assert.equal(VIP_FRAME_CATALOG.length, 18);
  assert.deepEqual(
    VIP_FRAME_CATALOG.map((entry) => entry.level),
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
  );
  assert.equal(new Set(VIP_FRAME_CATALOG.map((entry) => entry.id)).size, 18);
  assert.equal(frameForVipLevel(1)?.animal, "cat");
  assert.equal(frameForVipLevel(2)?.animal, "swan");
  assert.equal(frameForVipLevel(3)?.animal, "dolphin");
  assert.equal(frameForVipLevel(4)?.animal, "fox");
  assert.equal(frameForVipLevel(5)?.animal, "deer");
  assert.equal(frameForVipLevel(13)?.animal, "gorilla");
  assert.equal(frameForVipLevel(17)?.animal, "phoenix");
  assert.equal(frameForVipLevel(18)?.animal, "dragon");
  assert.equal(frameForVipLevel(0), null);
  assert.equal(frameForVipLevel(19), null);
});

test("VIP1-4 frames are static PNG stills (no WebM, no VAP)", () => {
  // VIP1-4 have no animated frame video: frame_key/vap_key are empty,
  // animation is "" and the app shows the PNG still only.
  for (const level of [1, 2, 3, 4]) {
    assert.equal(frameVideoUrlForVipLevel(level), null);
    assert.equal(frameVapUrlForVipLevel(level), null);
    const visual = frameVisualForVipLevel(level);
    assert.equal(visual.video_key, "");
    assert.equal(visual.vap_key, "");
    assert.equal(visual.animation_type, "");
    assert.equal(visual.animation_ms, 0);
    assert.ok(visual.asset_key.endsWith("-transparent.png"));
  }
  assert.equal(
    frameStillUrlForVipLevel(1),
    `${R2_BASE}/frames/vip1-cat-transparent.png`,
  );
  assert.equal(
    frameStillUrlForVipLevel(4),
    `${R2_BASE}/frames/vip4-fox-transparent.png`,
  );
  assert.equal(allFrameStillUrls().length, 18);
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
  assert.equal(frameVapUrlForVipLevel(1), null);
  assert.equal(frameVapUrlForVipLevel(4), null);
  assert.equal(frameVapUrlForVipLevel(19), null);
  assert.equal(allFrameVapUrls().length, 14);
  assert.ok(allFrameVapUrls().every((url) => url.startsWith(`${R2_BASE}/vap/`)));
  assert.ok(allFrameVapUrls().every((url) => url.endsWith(".mp4")));
  assert.equal(frameVisualForVipLevel(7).vap_key, "vap/vip7-eagle.mp4");
  assert.equal(frameVisualForVipLevel(18).vap_key, "vap/vip18-dragon.mp4");
});

test("VIP entry-effect catalog covers VIP1-18 with R2 banner URLs", () => {
  assert.equal(VIP_ENTRY_EFFECT_CATALOG.length, 18);
  assert.equal(entryEffectForVipLevel(1)?.animal, "cat");
  assert.equal(entryEffectForVipLevel(2)?.animal, "swan");
  assert.equal(entryEffectForVipLevel(3)?.animal, "dolphin");
  assert.equal(entryEffectForVipLevel(4)?.animal, "fox");
  assert.equal(entryEffectForVipLevel(5)?.animal, "deer");
  assert.equal(entryEffectForVipLevel(10)?.animal, "lion");
  assert.equal(entryEffectForVipLevel(18)?.animal, "dragon");
  assert.equal(entryEffectForVipLevel(0), null);
  assert.equal(entryEffectForVipLevel(19), null);
  assert.equal(
    entryEffectUrlForVipLevel(10),
    `${R2_BASE}/entry-effects/vip10-entry.png`,
  );
  assert.equal(
    entryEffectUrlForVipLevel(4),
    `${R2_BASE}/entry-effects/vip4-entry.png`,
  );
  const visual = entryEffectVisualForVipLevel(13);
  assert.equal(visual.id, "vip-entry-13");
  assert.equal(visual.asset_key, "entry-effects/vip13-entry.png");
  assert.equal(visual.video_key, "");
});

test("VIP tag catalog covers VIP1-18 with R2 tag URLs", () => {
  assert.equal(VIP_TAG_CATALOG.length, 18);
  assert.equal(tagForVipLevel(1)?.animal, "cat");
  assert.equal(tagForVipLevel(2)?.animal, "swan");
  assert.equal(tagForVipLevel(3)?.animal, "dolphin");
  assert.equal(tagForVipLevel(4)?.animal, "fox");
  assert.equal(tagForVipLevel(5)?.animal, "deer");
  assert.equal(tagForVipLevel(17)?.animal, "phoenix");
  assert.equal(tagForVipLevel(18)?.animal, "dragon");
  assert.equal(tagForVipLevel(0), null);
  assert.equal(tagForVipLevel(19), null);
  assert.equal(
    tagUrlForVipLevel(18),
    `${R2_BASE}/vip-tags/vip18-tag.png`,
  );
  assert.equal(
    tagUrlForVipLevel(4),
    `${R2_BASE}/vip-tags/vip4-tag.png`,
  );
  const visual = tagVisualForVipLevel(6);
  assert.equal(visual.id, "vip-tag-6");
  assert.equal(visual.asset_key, "vip-tags/vip6-tag.png");
});

test("VIP medal catalog covers VIP1-4 with R2 medal URLs", () => {
  assert.equal(VIP_MEDAL_CATALOG.length, 4);
  assert.deepEqual(
    VIP_MEDAL_CATALOG.map((entry) => entry.level),
    [1, 2, 3, 4],
  );
  assert.equal(medalForVipLevel(1)?.animal, "cat");
  assert.equal(medalForVipLevel(2)?.animal, "swan");
  assert.equal(medalForVipLevel(3)?.animal, "dolphin");
  assert.equal(medalForVipLevel(4)?.animal, "fox");
  assert.equal(medalForVipLevel(5), null);
  assert.equal(medalForVipLevel(0), null);
  assert.equal(
    medalUrlForVipLevel(1),
    `${R2_BASE}/vip-medals/vip1-medal.png`,
  );
  assert.equal(
    medalUrlForVipLevel(4),
    `${R2_BASE}/vip-medals/vip4-medal.png`,
  );
  const visual = medalVisualForVipLevel(2);
  assert.equal(visual.id, "vip-medal-2");
  assert.equal(visual.kind, "medal");
  assert.equal(visual.asset_key, "vip-medals/vip2-medal.png");
  assert.equal(visual.video_key, "");
  assert.equal(allMedalUrls().length, 4);
  assert.ok(allMedalUrls().every((url) => url.startsWith(`${R2_BASE}/vip-medals/`)));
});

test("VIP scenic banner catalog covers VIP1-4 with R2 banner URLs", () => {
  assert.equal(VIP_SCENIC_BANNER_CATALOG.length, 4);
  assert.deepEqual(
    VIP_SCENIC_BANNER_CATALOG.map((entry) => entry.level),
    [1, 2, 3, 4],
  );
  assert.equal(scenicBannerForVipLevel(1)?.animal, "cat");
  assert.equal(scenicBannerForVipLevel(2)?.animal, "swan");
  assert.equal(scenicBannerForVipLevel(3)?.animal, "dolphin");
  assert.equal(scenicBannerForVipLevel(4)?.animal, "fox");
  assert.equal(scenicBannerForVipLevel(5), null);
  assert.equal(scenicBannerForVipLevel(0), null);
  assert.equal(
    scenicBannerUrlForVipLevel(1),
    `${R2_BASE}/profile-banners/vip1-banner.png`,
  );
  assert.equal(
    scenicBannerUrlForVipLevel(2),
    `${R2_BASE}/profile-banners/vip2-scenic.png`,
  );
  assert.equal(
    scenicBannerUrlForVipLevel(4),
    `${R2_BASE}/profile-banners/vip4-scenic.png`,
  );
  const visual = scenicBannerVisualForVipLevel(3);
  assert.equal(visual.id, "vip-scenic-3");
  assert.equal(visual.kind, "scenic_banner");
  assert.equal(visual.asset_key, "profile-banners/vip3-scenic.png");
  assert.equal(allScenicBannerUrls().length, 4);
  assert.ok(allScenicBannerUrls().every((url) => url.startsWith(`${R2_BASE}/profile-banners/`)));
});
