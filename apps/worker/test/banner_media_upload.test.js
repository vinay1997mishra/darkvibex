import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");
const homeScreen = await readFile(new URL("../../mobile/lib/screens/home_shell.dart", import.meta.url), "utf8");

test("Owner Panel can upload and preview custom banner images", () => {
  assert.match(panelHtml, /id="bannerImageFile"[^>]*type="file"/);
  assert.match(panelHtml, /id="uploadBannerImage"/);
  assert.match(panelHtml, /id="bannerImagePreview"/);
  assert.match(panelApp, /async function uploadBannerImage\(\)/);
  assert.match(panelApp, /\/api\/owner\/banner-media/);
  assert.match(panelApp, /5\*1024\*1024/);
  assert.match(panelApp, /setBannerImagePreview\(data\.key/);
});

test("custom banner media uploads require banner-save permission and validate the image", () => {
  assert.match(ownerApi, /async function handleBannerMediaUpload\(request, env, db, actor\)/);
  assert.match(ownerApi, /requirePermission\(actor, "banners\.save"\)/);
  assert.match(ownerApi, /banner_image_max_5mb/);
  assert.match(ownerApi, /banner_image_type_invalid/);
  assert.match(ownerApi, /banner_image_invalid/);
  assert.match(ownerApi, /banners\/owner-panel\//);
  assert.match(ownerApi, /parts\[2\] === "banner-media"/);
  assert.match(ownerApi, /"x-banner-id"/);
});

test("users can manually change banners as well as wait for automatic swiping", () => {
  assert.match(homeScreen, /PageView\(\s*controller: _bannerPageController/);
  assert.match(homeScreen, /Duration\(seconds: 5\)/);
  assert.match(homeScreen, /GestureDetector\(\s*behavior: HitTestBehavior\.opaque,\s*onTap:/);
  assert.match(homeScreen, /_bannerPageController\.animateToPage\(\s*page,/);
});
