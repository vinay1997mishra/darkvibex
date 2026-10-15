import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const ownerApiUrl = new URL("../src/owner_api.js", import.meta.url);
const panelAppUrl = new URL("../../owner_panel/app.js", import.meta.url);
const panelHtmlUrl = new URL("../../owner_panel/index.html", import.meta.url);

const ownerApi = await readFile(ownerApiUrl, "utf8");
const panelApp = await readFile(panelAppUrl, "utf8");
const panelHtml = await readFile(panelHtmlUrl, "utf8");

test("Owner theme crop panel supports size, crop and R2 upload", () => {
  assert.match(panelHtml, /id="globalThemeFile"/);
  assert.match(panelHtml, /id="globalThemeWidth"/);
  assert.match(panelHtml, /id="globalThemeHeight"/);
  assert.match(panelHtml, /id="globalThemeZoom"/);
  assert.match(panelHtml, /id="globalThemeCropX"/);
  assert.match(panelHtml, /id="globalThemeCropY"/);
  assert.match(panelHtml, /id="globalThemeCropCanvas"/);
  assert.match(panelHtml, /Crop & Upload to R2/);
  assert.match(panelApp, /drawThemeCover/);
  assert.match(panelApp, /canvas\.toBlob\(resolve,"image\/webp"/);
  assert.match(panelApp, /\/api\/owner\/theme-media/);
  assert.match(panelApp, /output_width:width,output_height:height/);
});

test("Owner theme media endpoint stores validated images in R2", () => {
  assert.match(ownerApi, /handleThemeMediaUpload/);
  assert.match(ownerApi, /themes\.global\.save/);
  assert.match(ownerApi, /room-themes\/owner-panel/);
  assert.match(ownerApi, /env\.FILES\.put/);
  assert.match(ownerApi, /theme_image_max_8mb/);
  assert.match(ownerApi, /parts\[2\] === "theme-media"/);
});

test("Owner panel JavaScript remains syntactically valid", () => {
  execFileSync(process.execPath, ["--check", fileURLToPath(panelAppUrl)], {
    stdio: "pipe",
  });
});
