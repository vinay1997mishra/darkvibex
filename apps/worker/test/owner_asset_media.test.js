import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const read = async (path) => readFile(new URL(path, import.meta.url), "utf8");
const worker = await read("../src/index.js");
const ownerApi = await read("../src/owner_api.js");
const panelHtml = await read("../../owner_panel/index.html");
const panelApp = await read("../../owner_panel/app.js");
const room = await read("../../mobile/lib/screens/room_screen.dart");
const shop = await read("../../mobile/lib/screens/cosmetics_shop_screen.dart");
const transparentArtwork = await read("../../mobile/lib/widgets/transparent_artwork_image.dart");
const frameWidget = await read("../../mobile/lib/widgets/vip_animated_frame.dart");
const bubbleWidget = await read("../../mobile/lib/widgets/cosmetic_store_previews.dart");
const mediaPreview = await read("../../mobile/lib/widgets/custom_asset_media_preview.dart");
const effectPlayback = await read("../../mobile/lib/widgets/custom_asset_effect_playback.dart");

test("removed editor route is hard-blocked with HTTP 404", () => {
  assert.ok(worker.includes('url.pathname === "/creator-studio"'));
  assert.ok(worker.includes('url.pathname.startsWith("/creator-studio/")'));
  assert.ok(worker.includes("status: 404"));
  assert.ok(!worker.includes("studioAssetUrl"));
  assert.ok(!worker.includes("assets.local"));
});

test("Owner Panel custom asset uploads remain protected and validated", () => {
  assert.ok(ownerApi.includes("handleAssetMediaUpload"));
  assert.ok(ownerApi.includes('requirePermission(actor, kind === "gift" ? "gifts.save" : "assets.save")'));
  assert.ok(ownerApi.includes('"custom-assets/"'));
  assert.ok(ownerApi.includes("11 * 1024 * 1024"));
  assert.ok(ownerApi.includes("25 * 1024 * 1024"));
  assert.ok(ownerApi.includes('ascii(4, 8) === "ftyp"'));
  assert.ok(ownerApi.includes('ascii(0, 4) === "glTF"'));
  assert.ok(ownerApi.includes("env.FILES.put(key, bytes"));
  assert.ok(ownerApi.includes('parts[2] === "asset-media"'));
});

test("Owner Panel custom asset controls upload media and publish catalog keys", () => {
  assert.ok(panelHtml.includes('id="assetMediaFile"'));
  assert.ok(panelHtml.includes('id="assetVideoKey"'));
  assert.ok(panelHtml.includes('id="assetGlbKey"'));
  assert.ok(panelHtml.includes('id="uploadAssetMedia"'));
  assert.ok(panelApp.includes("/api/owner/asset-media"));
  assert.ok(panelApp.includes("video_key:"));
  assert.ok(panelApp.includes("glb_key:"));
  assert.ok(panelApp.includes("media_type:"));
  assert.ok(!panelHtml.includes("Creator Studio"));
  assert.ok(!panelApp.includes("Creator Studio"));
});

test("custom media remains playable in room effects and Store previews", () => {
  assert.ok(room.includes("CustomAssetEffectPlayback"));
  assert.ok(room.includes("active_entry_video_key"));
  assert.ok(room.includes("active_vehicle_video_key"));
  assert.ok(shop.includes("CustomAssetMediaPreview"));
  assert.ok(mediaPreview.includes("VideoPlayerController.networkUrl"));
  assert.ok(mediaPreview.includes("setLooping(false)"));
  assert.ok(effectPlayback.includes("VideoPlayerController.networkUrl"));
  assert.ok(effectPlayback.includes("ModelViewer("));
});

test("frame and chat-bubble artwork still requires genuine transparency", () => {
  assert.ok(ownerApi.includes("imageFileDeclaresTransparency"));
  assert.ok(ownerApi.includes("asset_media_transparency_required"));
  assert.ok(panelApp.includes("transparent PNG/WebP"));
  assert.ok(transparentArtwork.includes("outsideClear"));
  assert.ok(transparentArtwork.includes("alphaAt(16, 16)"));
  assert.ok(transparentArtwork.includes("alphaValid = outsideClear && centreClear"));
  assert.ok(frameWidget.includes("requireTransparentCenter: true"));
  assert.ok(bubbleWidget.includes("_AnimatedBubbleEdgeEffect"));
});
