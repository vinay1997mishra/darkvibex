import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("staff panels use Gmail plus owner-created panel password", () => {
  assert.match(ownerApi, /normalizeStaffEmail/);
  assert.match(ownerApi, /deriveStaffPasswordHash/);
  assert.match(ownerApi, /owner_staff_sessions/);
  assert.match(ownerApi, /url\.pathname === "\/api\/owner\/login"/);
  assert.match(panelHtml, /id="loginEmail"/);
  assert.match(panelHtml, /id="loginPassword"/);
  assert.match(panelHtml, /id="staffEmail"/);
  assert.match(panelHtml, /id="staffPassword"/);
  assert.match(panelApp, /fetch\("\/api\/owner\/login"/);
});

test("only Main Owner can create or change staff login credentials", () => {
  assert.match(ownerApi, /owner_only_staff_credentials/);
  assert.match(ownerApi, /owner_only_staff_password_change/);
  assert.match(ownerApi, /credentialChange && actor\.type !== "owner"/);
  assert.match(panelHtml, /Only the Main Owner can create or change staff login credentials/);
  assert.match(panelApp, /Only the Main Owner can create staff Gmail\/password access/);
});

test("panel password is separate from Gmail account password", () => {
  assert.match(panelHtml, /Do not use your real Gmail\/Google account password here/);
  assert.match(panelHtml, /not the user's real Gmail password/);
  assert.doesNotMatch(ownerApi, /google.*password/i);
});


test("staff panel creation is capped at exactly 20", () => {
  assert.match(ownerApi, /SELECT COUNT\(\*\) AS value FROM owner_staff/);
  assert.match(ownerApi, /staffCount >= 20/);
  assert.match(ownerApi, /staff_panel_limit_20_reached/);
  assert.match(panelApp, /Maximum 20 staff panels can be created\./);
});
