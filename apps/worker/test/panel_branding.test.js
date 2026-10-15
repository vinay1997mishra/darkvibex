import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("panel branding changes by authenticated access type", () => {
  assert.match(panelHtml, /id="panelBrandLabel"/);
  assert.match(panelHtml, /id="loginPanelTitle"/);
  assert.match(panelApp, /isOwner\?"DarkVibeX Owner Panel":"DarkVibeX Panel"/);
  assert.match(panelApp, /document\.title=title/);
  assert.match(panelApp, /actorCard\(\).*applyPanelBranding/s);
});
