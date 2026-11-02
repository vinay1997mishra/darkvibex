import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const ownerPanelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");
const ownerPanelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");

test("regular app users cannot create custom gifts or upload their gift media", () => {
  const start = worker.indexOf('if (url.pathname === "/api/custom-gifts" && request.method === "POST")');
  const end = worker.indexOf('if (url.pathname === "/api/invite/summary"', start);
  assert.ok(start >= 0 && end > start, "custom-gift POST route must remain explicitly guarded");
  const route = worker.slice(start, end);
  assert.match(route, /owner_panel_required/);
  assert.doesNotMatch(route, /INSERT INTO custom_gifts/);

  const uploadStart = worker.indexOf('const userPrefix = `users/${actor}/`;');
  const uploadEnd = worker.indexOf('const maxFileBytes =', uploadStart);
  assert.ok(uploadStart >= 0 && uploadEnd > uploadStart, "generic app upload policy must be present");
  const uploadPolicy = worker.slice(uploadStart, uploadEnd);
  assert.doesNotMatch(uploadPolicy, /custom-gifts/);
});

test("Owner Panel remains the authorized gift creation and video upload path", () => {
  assert.match(ownerApi, /async function handleGiftMediaUpload/);
  assert.match(ownerApi, /requirePermission\(actor, "gifts\.save"\)/);
  assert.match(ownerApi, /custom-gifts\/owner-panel/);
  assert.match(ownerPanelApp, /async function saveGift\(\)/);
  assert.match(ownerPanelApp, /kind:"gift"/);
  assert.match(ownerPanelApp, /\/api\/owner\/gift-media/);
  assert.match(ownerPanelHtml, /id="giftVideoFile"/);
});
