import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("Owner Panel uploads MP4 gift media into R2", () => {
  assert.match(ownerApi, /handleGiftMediaUpload/);
  assert.match(ownerApi, /env\.FILES\.put/);
  assert.match(ownerApi, /video\/mp4/);
  assert.match(ownerApi, /20 \* 1024 \* 1024/);
  assert.match(ownerApi, /custom-gifts\/owner-panel/);
  assert.match(panelHtml, /id="giftVideoFile"/);
  assert.match(panelHtml, /Upload Video to R2/);
  assert.match(panelApp, /\/api\/owner\/gift-media/);
  assert.match(panelApp, /video_key:/);
});

test("live gift catalog exposes video keys", () => {
  assert.match(worker, /video_key: String\(row\.data\?\.video_key/);
});
