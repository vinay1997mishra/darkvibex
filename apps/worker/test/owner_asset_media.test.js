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

test("removed editor route is hard-blocked with HTTP 404", () => {
  assert.match(worker, /url\.pathname === "\/creator-studio" \|\| url\.pathname\.startsWith\("\/creator-studio\/"\)/);
  assert.match(worker, /status: 404/);
  assert.doesNotMatch(worker, /studioAssetUrl|assets\.local/);
});

test("Owner Panel custom asset upload and publish remain permission-gated", () => {
  assert.match(ownerApi, /handleAssetMediaUpload/);
  assert.match(ownerApi, /requirePermission\(actor, kind === "gift" \? "gifts\.save" : "assets\.save"\)/);
  assert.match(ownerApi, /custom-assets\//);
  assert.match(ownerApi, /parts\[2\] === "asset-media"/);
  assert.match(panelHtml, /id="assetMediaFile"/);
  assert.match(panelHtml, /id="uploadAssetMedia"/);
  assert.match(panelApp, /\/api\/owner\/asset-media/);
  assert.match(panelApp, /video_key:/);
  assert.match(panelApp, /glb_key:/);
});

test("app custom-media playback remains wired into Room and Store", () => {
  assert.match(room, /CustomAssetEffectPlayback/);
  assert.match(shop, /CustomAssetMediaPreview/);
});
