import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");
const backendApi = await readFile(new URL("../../mobile/lib/infra/backend_api.dart", import.meta.url), "utf8");
const appState = await readFile(new URL("../../mobile/lib/app/app_state.dart", import.meta.url), "utf8");
const profileScreen = await readFile(new URL("../../mobile/lib/screens/profile_screen.dart", import.meta.url), "utf8");
const homeShell = await readFile(new URL("../../mobile/lib/screens/home_shell.dart", import.meta.url), "utf8");
const socialStore = await readFile(new URL("../src/tinni_social.js", import.meta.url), "utf8");

test("allowed Tinni Owner Panel modules are exposed without excluded hierarchy or verification views", () => {
  for (const view of ["notifications","messaging","roles","banners","games","policies"]) {
    assert.match(panelHtml, new RegExp('data-view="' + view + '"'));
  }
  assert.doesNotMatch(panelHtml, /data-view="hierarchy"/);
  assert.doesNotMatch(panelHtml, /data-view="verification"/);
  assert.doesNotMatch(panelApp, /\["hierarchy\./);
  assert.doesNotMatch(panelApp, /\["verification\./);
});

test("owner backend has notifications official messaging tags and user overrides", () => {
  assert.match(ownerApi, /CREATE TABLE IF NOT EXISTS owner_notifications/);
  assert.match(ownerApi, /CREATE TABLE IF NOT EXISTS owner_user_overrides/);
  assert.match(ownerApi, /CREATE TABLE IF NOT EXISTS owner_device_bans/);
  assert.match(ownerApi, /CREATE TABLE IF NOT EXISTS owner_user_tags/);
  assert.match(ownerApi, /async function handleNotifications/);
  assert.match(ownerApi, /async function handleMessaging/);
  assert.match(ownerApi, /darkvibex_official/);
  assert.match(ownerApi, /parts\[4\] === "owner-overrides"/);
  assert.match(ownerApi, /parts\[4\] === "device-ban"/);
});

test("owner room investigation media and theme overrides are live-backed", () => {
  assert.match(ownerApi, /parts\[4\] === "live"/);
  assert.match(ownerApi, /parts\[4\] === "media"/);
  assert.match(ownerApi, /parts\[4\] === "theme"/);
  assert.match(ownerApi, /room_images/);
  assert.match(ownerApi, /room_custom_themes/);
  assert.match(panelApp, /async function openRoomInvestigation/);
  assert.match(panelApp, /async function saveOwnerRoomMedia/);
  assert.match(panelApp, /async function saveOwnerRoomTheme/);
});

test("device ban wallet freeze locked-room bypass and complaint notification are enforced by app APIs", () => {
  assert.match(worker, /x-device-id/);
  assert.match(worker, /device_banned/);
  assert.match(worker, /wallet_frozen/);
  assert.match(worker, /locked_room_bypass/);
  assert.match(worker, /User feedback \/ complaint/);
  assert.match(backendApi, /x-device-id/);
  assert.match(backendApi, /device_key/);
  assert.match(appState, /darkvibex\.device_key/);
  assert.match(appState, /Random\.secure\(\)/);
});

test("roles posts banners games and allowed policies have dedicated APIs and UI actions", () => {
  assert.match(ownerApi, /async function handleRolesPosts/);
  assert.match(ownerApi, /async function handleBanners/);
  assert.match(ownerApi, /async function handleGamesOwner/);
  assert.match(ownerApi, /async function handlePoliciesOwner/);
  assert.match(ownerApi, /invalid_or_excluded_policy/);
  assert.match(panelApp, /async function loadRolesPosts/);
  assert.match(panelApp, /async function loadBanners/);
  assert.match(panelApp, /async function loadGames/);
  assert.match(panelApp, /async function loadPolicies/);
  assert.match(panelApp, /async function sendOfficialMessage/);
  assert.match(panelApp, /async function applyOwnerTag/);
});


test("owner panel JS references only existing HTML element IDs", () => {
  const ids = new Set([...panelHtml.matchAll(/\\bid="([^"]+)"/g)].map((match) => match[1]));
  const refs = [...panelApp.matchAll(/\\$\\("#([A-Za-z][A-Za-z0-9_-]*)"\\)/g)].map((match) => match[1]);
  const missing = [...new Set(refs.filter((id) => !ids.has(id)))];
  assert.deepEqual(missing, []);
});

test("game controls and scheduled global themes affect app-facing routes", () => {
  assert.match(worker, /async function ownerGameConfig/);
  assert.match(worker, /amount < gameConfig\.min_bet/);
  assert.match(worker, /ownerGameConfig\(db,"ludo"/);
  assert.match(worker, /owner_global:true/);
  assert.match(worker, /kind='theme' AND enabled=1/);
  assert.match(panelApp, /async function saveGlobalTheme/);
});

test("owner tags and invisible ID reach the user profile response", () => {
  assert.match(worker, /user\.owner_tags=ownerIdentity\.tags/);
  assert.match(worker, /user\.tags=ownerIdentity\.tags/);
  assert.match(worker, /user\.invisible_id=ownerIdentity\.invisible_id/);
  assert.match(worker, /user\.public_id=null/);
});


test("invisible IDs stay hidden across profile social friends and room surfaces", () => {
  assert.match(worker, /THEN 'Hidden' ELSE u\.public_id/);
  assert.match(worker, /owner_invisible_id/);
  assert.match(socialStore, /THEN 'Hidden' ELSE u\.public_id/);
  assert.match(profileScreen, /return 'Hidden'/);
  assert.match(profileScreen, /_ownerTagWidgets/);
});

test("wallet freeze is global and device ban covers API boundary", () => {
  assert.match(worker, /CREATE TRIGGER IF NOT EXISTS owner_wallet_freeze_guard/);
  assert.match(worker, /SELECT RAISE\(ABORT,'wallet_frozen'\)/);
  assert.match(ownerApi, /CREATE TRIGGER IF NOT EXISTS owner_wallet_freeze_guard/);
  assert.match(worker, /requestDeviceKey/);
  assert.match(worker, /x-device-id/);
});

test("scheduled Owner banners are app-facing and rendered on Party home", () => {
  assert.match(worker, /url\.pathname === "\/api\/banners"/);
  assert.match(worker, /kind='banner' AND enabled=1/);
  assert.match(backendApi, /activeBanners/);
  assert.match(homeShell, /_OwnerBannerCard/);
  assert.match(homeShell, /ownerBanners/);
});
