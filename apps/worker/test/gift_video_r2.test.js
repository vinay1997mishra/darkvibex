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
  const giftCatalogStart = worker.indexOf('async function effectiveGiftCatalog(db)');
  const giftCatalogEnd = worker.indexOf('// Resolve the visual bundle', giftCatalogStart);
  assert.ok(giftCatalogStart >= 0 && giftCatalogEnd > giftCatalogStart);
  const giftCatalog = worker.slice(giftCatalogStart, giftCatalogEnd);
  assert.match(giftCatalog, /row\.data\?\.poster_key/);
  assert.match(giftCatalog, /row\.data\?\.image_key/);
  assert.match(giftCatalog, /row\.data\?\.dp_key/);
  assert.match(giftCatalog, /row\.data\?\.animation_key/);
  assert.match(giftCatalog, /asset_key: String\(/);
  assert.match(giftCatalog, /video_key: String\(/);
  assert.match(giftCatalog, /media_type: String\(row\.data\?\.media_type/);
});
