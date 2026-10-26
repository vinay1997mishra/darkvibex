import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");
const shop = await readFile(new URL("../../mobile/lib/screens/cosmetics_shop_screen.dart", import.meta.url), "utf8");
const room = await readFile(new URL("../../mobile/lib/screens/room_screen.dart", import.meta.url), "utf8");
const mediaPreview = await readFile(new URL("../../mobile/lib/widgets/creator_asset_media_preview.dart", import.meta.url), "utf8");
const effectPlayback = await readFile(new URL("../../mobile/lib/widgets/creator_asset_effect_playback.dart", import.meta.url), "utf8");

test("creator uploads are permission-gated, capped and file-signature validated", () => {
  assert.match(ownerApi, /handleCreatorMediaUpload/);
  assert.match(ownerApi, /requirePermission\(actor, kind === "gift" \? "gifts\.save" : "assets\.save"\)/);
  assert.match(ownerApi, /creator-assets\//);
  assert.match(ownerApi, /11 \* 1024 \* 1024/);
  assert.match(ownerApi, /25 \* 1024 \* 1024/);
  assert.match(ownerApi, /ascii\(4, 8\) === "ftyp"/);
  assert.match(ownerApi, /bytes\[0\] === 0x1a && bytes\[1\] === 0x45 && bytes\[2\] === 0xdf && bytes\[3\] === 0xa3/);
  assert.match(ownerApi, /ascii\(0, 4\) === "glTF"/);
  assert.match(ownerApi, /env\.FILES\.put\(key, bytes/);
});

test("owner panel can upload and publish video, model and image assets", () => {
  assert.match(panelHtml, /id="creatorAssetFile"/);
  assert.match(panelHtml, /id="assetVideoKey"/);
  assert.match(panelHtml, /id="assetGlbKey"/);
  assert.match(panelHtml, /id="uploadCreatorAsset"/);
  assert.match(panelApp, /\/api\/owner\/creator-media/);
  assert.match(panelApp, /video_key:/);
  assert.match(panelApp, /glb_key:/);
  assert.match(panelApp, /media_type:/);
});

test("custom media metadata reaches room entry playback and R2 assets are publicly readable", () => {
  assert.match(worker, /creator-assets/);
  assert.match(worker, /active_vehicle_video_key/);
  assert.match(worker, /active_entry_video_key/);
  assert.match(worker, /active_vehicle_glb_key/);
  assert.match(worker, /active_entry_glb_key/);
  assert.match(room, /CreatorAssetEffectPlayback/);
  assert.match(room, /active_entry_video_key/);
  assert.match(effectPlayback, /VideoPlayerController\.networkUrl/);
  assert.match(effectPlayback, /ModelViewer\(/);
});

test("Store previews uploaded MP4/WebM and GLB assets with a procedural fallback", () => {
  assert.match(shop, /CreatorAssetMediaPreview/);
  assert.match(shop, /ModelViewer\(/);
  assert.match(shop, /glb_key/);
  assert.match(shop, /video_key/);
  assert.match(mediaPreview, /setLooping\(false\)/);
  assert.match(mediaPreview, /setVolume\(0\)/);
});
