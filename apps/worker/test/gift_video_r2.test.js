import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("Owner Panel uploads supported gift video containers into R2", () => {
  assert.match(ownerApi, /handleGiftMediaUpload/);
  assert.match(ownerApi, /env\.FILES\.put/);
  for (const type of ["video/mp4", "video/webm", "video/x-matroska", "video/3gpp", "video/mp2t", "video/mpeg"]) {
    assert.ok(ownerApi.includes(type), "missing backend MIME support for " + type);
  }
  for (const ext of ["mp4", "webm", "mkv", "m4v", "3gp", "ts", "m2ts", "mts", "mpg", "mpeg", "mpe"]) {
    assert.ok(ownerApi.includes(ext), "missing backend extension support for " + ext);
    assert.ok(panelApp.includes(ext), "missing Owner Panel extension support for " + ext);
  }
  assert.match(ownerApi, /11 \* 1024 \* 1024/);
  assert.match(ownerApi, /gift_video_max_11mb/);
  assert.match(ownerApi, /gift_video_format_unsupported/);
  assert.match(ownerApi, /custom-gifts\/owner-panel/);
  assert.match(panelHtml, /id="giftVideoFile"/);
  assert.match(panelHtml, /accept="video\//);
  assert.match(panelHtml, /id="giftVideoType"/);
  assert.match(panelHtml, /Upload Video to R2/);
  assert.match(panelApp, /\/api\/owner\/gift-media/);
  assert.match(panelApp, /media_type:/);
  assert.match(panelApp, /video_key:/);
});

test("live gift catalog exposes uploaded video keys and media types", () => {
  assert.match(worker, /video_key: String\(row\.data\?\.video_key/);
  assert.match(worker, /media_type: String\(row\.data\?\.media_type/);
});
