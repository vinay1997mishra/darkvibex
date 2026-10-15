import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("Main Owner Google login is restricted to the configured Gmail hash", () => {
  assert.match(ownerApi, /MAIN_OWNER_GMAIL_SHA256/);
  assert.match(ownerApi, /owner_google_account_not_authorized/);
  assert.match(ownerApi, /\/api\/owner\/google-login/);
  assert.match(ownerApi, /owner_login_sessions/);
  assert.doesNotMatch(ownerApi, /mishrajii7991@gmail\.com/i);
});

test("Owner Panel exposes Google login without displaying the authorized Gmail", () => {
  assert.match(panelHtml, /id="googleOwnerButton"/);
  assert.match(panelHtml, /accounts\.google\.com\/gsi\/client/);
  assert.match(panelApp, /handleOwnerGoogleCredential/);
  assert.match(panelApp, /initOwnerGoogleLogin/);
  assert.match(panelApp, /\/api\/owner\/google-login/);
  assert.doesNotMatch(panelHtml + panelApp, /mishrajii7991@gmail\.com/i);
});

test("Owner Panel does not expose token recovery controls", () => {
  assert.doesNotMatch(panelHtml, /Owner access key|Private owner key|connectToken|id="token"/i);
  assert.doesNotMatch(panelApp, /connectOwnerToken|#token|connectToken/);
  assert.match(panelHtml, /Main Owner signs in only with the authorized Google account/);
});
