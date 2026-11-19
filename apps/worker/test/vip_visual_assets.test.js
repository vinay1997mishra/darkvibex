import test from "node:test";
import assert from "node:assert/strict";
import {
  VIP_FRAME_CATALOG,
  frameForVipLevel,
  frameById,
  frameVisualForVipLevel,
  frameVisualById,
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
import {
  VIP_PROFILE_CARD_ANIM_CATALOG,
  profileCardAnimForVipLevel,
  profileCardAnimVisualForVipLevel,
  profileCardAnimUrlForVipLevel,
  profileCardAnimStillUrlForVipLevel,
  allProfileCardAnimUrls,
  allProfileCardAnimStillUrls,
} from "../src/vip_profile_card_anim_catalog.js";

const R2_BASE = "https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev";

test("VIP frame catalog covers VIP1-18 with one animal frame per level plus the VIP13 second frame", () => {
  assert.equal(VIP_FRAME_CATALOG.length, 19);
  assert.deepEqual(
    VIP_FRAME_CATALOG.map((entry) => entry.level),
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 13, 14, 15, 16, 17, 18],
  );
  assert.equal(new Set(VIP_FRAME_CATALOG.map((entry) => entry.id)).size, 19);
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
  assert.equal(allFrameStillUrls().length, 19);
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
  assert.equal(allFrameVideoUrls().length, 15);
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
  assert.equal(allFrameVapUrls().length, 15);
  assert.ok(allFrameVapUrls().every((url) => url.startsWith(`${R2_BASE}/vap/`)));
  assert.ok(allFrameVapUrls().every((url) => url.endsWith(".mp4")));
  assert.equal(frameVisualForVipLevel(7).vap_key, "vap/vip7-eagle.mp4");
  assert.equal(frameVisualForVipLevel(18).vap_key, "vap/vip18-dragon.mp4");
});

test("VIP13 second frame is reachable by id and leaves the original frame the level default", () => {
  // The level lookup still returns the ORIGINAL gorilla frame (first match).
  assert.equal(frameForVipLevel(13)?.id, "vip-frame-13");
  assert.equal(frameVisualForVipLevel(13)?.id, "vip-frame-13");
  assert.equal(
    frameStillUrlForVipLevel(13),
    `${R2_BASE}/frames/vip13-gorilla-transparent.png`,
  );
  // The second frame (Vinay's own design) is selected by id only.
  const second = frameById("vip-frame-13-second");
  assert.equal(second?.level, 13);
  assert.equal(second?.animal, "gorilla");
  assert.equal(second?.name, "Gorilla Frame II");
  assert.equal(second?.min_vip_level, 13);
  assert.equal(second?.duration_days, 30);
  assert.equal(second?.frame_key, "frames/vip13-gorilla-second-frame-transparent.webm");
  assert.equal(second?.vap_key, "vap/vip13-gorilla-second-frame.mp4");
  assert.equal(second?.still_key, "frames/vip13-gorilla-second-frame-transparent.png");
  assert.equal(second?.animation_ms, 5200);
  const visual = frameVisualById("vip-frame-13-second");
  assert.equal(visual?.id, "vip-frame-13-second");
  assert.equal(visual?.kind, "frame");
  assert.equal(visual?.asset_key, "frames/vip13-gorilla-second-frame-transparent.png");
  assert.equal(visual?.video_key, "frames/vip13-gorilla-second-frame-transparent.webm");
  assert.equal(visual?.vap_key, "vap/vip13-gorilla-second-frame.mp4");
  assert.equal(visual?.animation_type, "frame_loop");
  assert.equal(visual?.animation_ms, 5200);
  assert.equal(frameVisualById("vip-frame-13")?.id, "vip-frame-13");
  assert.equal(frameVisualById("no-such-frame"), null);
  assert.equal(frameVisualById(""), null);
  // The per-entry URL lists include the second frame's files, no duplicates.
  assert.ok(allFrameStillUrls().includes(`${R2_BASE}/frames/vip13-gorilla-second-frame-transparent.png`));
  assert.ok(allFrameVideoUrls().includes(`${R2_BASE}/frames/vip13-gorilla-second-frame-transparent.webm`));
  assert.ok(allFrameVapUrls().includes(`${R2_BASE}/vap/vip13-gorilla-second-frame.mp4`));
  assert.equal(new Set(allFrameVapUrls()).size, allFrameVapUrls().length);
  assert.equal(new Set(allFrameStillUrls()).size, allFrameStillUrls().length);
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

test("VIP profile card animation catalog covers VIP4-18 only, no bottom line in any design", () => {
  // v4 animations run from VIP4 onwards; VIP1-3 have no profile card
  // animation at all. Every design is open at the bottom (no bottom
  // line) and carries no text.
  assert.equal(VIP_PROFILE_CARD_ANIM_CATALOG.length, 15);
  assert.deepEqual(
    VIP_PROFILE_CARD_ANIM_CATALOG.map((entry) => entry.level),
    [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
  );
  assert.equal(new Set(VIP_PROFILE_CARD_ANIM_CATALOG.map((entry) => entry.id)).size, 15);
  assert.equal(profileCardAnimForVipLevel(4)?.animal, "fox");
  assert.equal(profileCardAnimForVipLevel(5)?.animal, "deer");
  assert.equal(profileCardAnimForVipLevel(10)?.animal, "lion");
  assert.equal(profileCardAnimForVipLevel(16)?.animal, "leviathan");
  assert.equal(profileCardAnimForVipLevel(18)?.animal, "dragon");
  assert.equal(profileCardAnimForVipLevel(1), null);
  assert.equal(profileCardAnimForVipLevel(2), null);
  assert.equal(profileCardAnimForVipLevel(3), null);
  assert.equal(profileCardAnimForVipLevel(0), null);
  assert.equal(profileCardAnimForVipLevel(19), null);
  assert.equal(profileCardAnimVisualForVipLevel(1), null);
  assert.equal(profileCardAnimVisualForVipLevel(3), null);
});

test("VIP profile card animation URLs point at the R2 profile-card-anims/ keys", () => {
  assert.equal(
    profileCardAnimUrlForVipLevel(4),
    `${R2_BASE}/profile-card-anims/vip4-fox.mp4`,
  );
  assert.equal(
    profileCardAnimUrlForVipLevel(5),
    `${R2_BASE}/profile-card-anims/vip5-deer.mp4`,
  );
  assert.equal(
    profileCardAnimUrlForVipLevel(18),
    `${R2_BASE}/profile-card-anims/vip18-dragon.mp4`,
  );
  assert.equal(profileCardAnimUrlForVipLevel(3), null);
  assert.equal(profileCardAnimUrlForVipLevel(1), null);
  assert.equal(allProfileCardAnimUrls().length, 15);
  assert.ok(allProfileCardAnimUrls().every((url) => url.startsWith(`${R2_BASE}/profile-card-anims/`)));
  assert.ok(allProfileCardAnimUrls().every((url) => url.endsWith(".mp4")));
});

test("VIP profile card animation visual plays once as background, still is the fallback", () => {
  // The video is the card BACKGROUND (reference layout renders over
  // it); it plays once and ends calmly. asset_key is the v3 still PNG,
  // shown when the video cannot play.
  const visual = profileCardAnimVisualForVipLevel(5);
  assert.equal(visual.id, "vip-profile-card-anim-5");
  assert.equal(visual.kind, "profile_card_anim");
  assert.equal(visual.asset_key, "profile-card-stills/vip5-deer.png");
  assert.equal(visual.video_key, "profile-card-anims/vip5-deer.mp4");
  assert.equal(visual.media_type, "video");
  assert.equal(visual.animation_type, "play_once");
  assert.equal(visual.animation_ms, 5000);
  assert.equal(
    profileCardAnimStillUrlForVipLevel(5),
    `${R2_BASE}/profile-card-stills/vip5-deer.png`,
  );
  assert.equal(
    profileCardAnimStillUrlForVipLevel(18),
    `${R2_BASE}/profile-card-stills/vip18-dragon.png`,
  );
  assert.equal(profileCardAnimStillUrlForVipLevel(2), null);
  assert.equal(allProfileCardAnimStillUrls().length, 15);
  assert.ok(allProfileCardAnimStillUrls().every((url) => url.startsWith(`${R2_BASE}/profile-card-stills/`)));
  assert.ok(allProfileCardAnimStillUrls().every((url) => url.endsWith(".png")));
});
