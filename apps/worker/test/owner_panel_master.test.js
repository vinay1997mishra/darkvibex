import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("DarkVibeX owner panel exposes Tinni-style master controls without legacy hierarchy routes", () => {
  assert.match(ownerApi, /owner_treasury/);
  assert.match(ownerApi, /handleTreasury/);
  assert.match(ownerApi, /treasury_send/);
  assert.match(panelHtml, /Wallets \/ Treasury/);
  assert.match(panelHtml, /Exact Permissions/);
  assert.match(panelHtml, /VIP \/ Gifts \/ Assets/);
  assert.match(panelApp, /staffPermissionOptions/);
  assert.match(panelApp, /treasuryAction/);
  assert.doesNotMatch(panelHtml, /data-view="hierarchy"/);
  assert.doesNotMatch(ownerApi, /parts\[2\] === "hierarchy"/);
});

test("owner treasury mint and deduct stay owner-only", () => {
  assert.match(ownerApi, /if \(actor\.type !== "owner"\) return json\(\{ ok: false, error: "owner_only" \}/);
});
