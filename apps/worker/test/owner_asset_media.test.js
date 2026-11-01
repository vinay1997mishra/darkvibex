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
  assert.match(worker, /url\.pathname === "\/creator-studio" \|\| url\.pathname\.startsWith\("\/creator-studio\/"\)/);
  assert.match(worker, /status: 404/);
  assert.doesNotMatch(worker, /studioAssetUrl|assets\.local/);
});

test("Owner Panel custom asset uploads remain protected and validated", () => {
  assert.match(ownerApi, /handleAssetMediaUpload/);
  assert.match(ownerApi, /requirePermission\(actor, kind === "gift" \? "gifts\.save" : "assets\.save"\)/);
  assert.match(ownerApi, /custom-assets\//);
  assert.match(ownerApi, /11 \* 1024 \* 1024/);
  assert.match(ownerApi, /25 \* 1024 \* 1024/);
  assert.match(ownerApi, /ascii\(4, 8\) === "ftyp"/);
  assert.match(ownerApi, /ascii\(0, 4\) === "glTF"/);
  assert.match(ownerApi, /env\.FILES\.put\(key, bytes/);
  assert.match(ownerApi, /parts\[2\] === "asset-media"/);
});

test("Owner Panel custom asset controls upload media and publish catalog keys", () => {
  assert.match(panelHtml, /id="assetMediaFile"/);
  assert.match(panelHtml, /id="assetVideoKey"/);
  assert.match(panelHtml, /id="assetGlbKey"/);
  assert.match(panelHtml, /id="uploadAssetMedia"/);
  assert.match(panelApp, /\/api\/owner\/asset-media/);
  assert.match(panelApp, /video_key:/);
  assert.match(panelApp, /glb_key:/);
  assert.match(panelApp, /media_type:/);
  assert.doesNotMatch(panelHtml, /creatorStudioLink|Creator Studio/);
  assert.doesNotMatch(panelApp, /creatorStudioLink|Creator Studio/);
});

test("custom media metadata remains playable in room effects and Store previews", () => {
  assert.match(room, /CustomAssetEffectPlayback/);
  assert.match(room, /active_entry_video_key/);
  assert.match(room, /active_vehicle_video_key/);
  assert.match(shop, /CustomAssetMediaPreview/);
  assert.match(mediaPreview, /VideoPlayerController\.networkUrl/);
  assert.match(mediaPreview, /setLooping\(false\)/);
  assert.match(effectPlayback, /VideoPlayerController\.networkUrl/);
  assert.match(effectPlayback, /ModelViewer\(/);
});

test("frame and chat-bubble artwork still requires genuine transparency", () => {
  assert.match(ownerApi, /imageFileDeclaresTransparency/);
  assert.match(ownerApi, /asset_media_transparency_required/);
  assert.match(panelApp, /transparent PNG\/WebP|transparent PNG ya WebP/i);
  assert.match(transparentArtwork, /outsideClear/);
  assert.match(transparentArtwork, /alphaAt\(16, 16\)/);
  assert.match(transparentArtwork, /alphaValid = outsideClear && centreClear/);
  assert.match(frameWidget, /requireTransparentCenter: true/);
  assert.match(bubbleWidget, /_AnimatedBubbleEdgeEffect/);
});
