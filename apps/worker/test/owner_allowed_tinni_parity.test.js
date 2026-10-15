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
const vipStore = await readFile(new URL("../src/vip_store.js", import.meta.url), "utf8");
const vipPolicy = await readFile(new URL("../src/vip_policy.js", import.meta.url), "utf8");
const roleWallets = await readFile(new URL("../src/role_wallets.js", import.meta.url), "utf8");
const uniqueIdStore = await readFile(new URL("../src/unique_id_store.js", import.meta.url), "utf8");

test("allowed Tinni Owner Panel modules are exposed without excluded hierarchy or verification views", () => {
  for (const view of ["notifications","messaging","roles","banners","games","policies","vip","gifts","assets"]) {
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


test("every explicit Owner Panel button and form control is wired in panel JS", () => {
  const buttonIds=[...panelHtml.matchAll(/<button\b[^>]*\bid="([^"]+)"/g)].map((m)=>m[1]);
  const formIds=[...panelHtml.matchAll(/<(?:input|select|textarea)\b[^>]*\bid="([^"]+)"/g)].map((m)=>m[1]);
  for(const id of [...buttonIds,...formIds]){
    assert.ok(
      panelApp.includes("#"+id) || panelApp.includes('"'+id+'"') || panelApp.includes("'"+id+"'"),
      "unwired control: "+id,
    );
  }
});

test("excluded modules have no Owner Panel view or action", () => {
  assert.doesNotMatch(panelHtml, /data-view="hierarchy"/);
  assert.doesNotMatch(panelHtml, /data-view="verification"/);
  assert.doesNotMatch(panelHtml, /data-action="lucky-gift-config"/);
  assert.doesNotMatch(panelApp, /lucky-gift-config/);
});

test("VIP manager controls the real VIP1-VIP18 leveling rules", () => {
  assert.match(ownerApi, /async function handleVipRules/);
  assert.match(ownerApi, /VIP_LEVELS/);
  assert.match(panelApp, /async function loadVipRules/);
  assert.match(panelApp, /async function saveVipRule/);
  assert.match(vipStore, /export async function vipRuleForDb/);
  assert.match(vipStore, /await vipRuleForDb\(db,level\+1\)/);
  assert.match(vipStore, /next\.enabled===false/);
  for(const threshold of ["25000000","100000000","220000000","400000000","500000000000"]){
    assert.match(vipPolicy,new RegExp(threshold));
  }
});

test("dedicated Gifts and Assets managers feed live scheduled catalogs", () => {
  assert.match(panelApp, /async function loadGifts/);
  assert.match(panelApp, /async function saveGift/);
  assert.match(panelApp, /async function loadAssets/);
  assert.match(panelApp, /async function saveAsset/);
  assert.match(worker, /async function effectiveGiftCatalog/);
  assert.match(worker, /async function effectiveCosmeticCatalog/);
  assert.match(worker, /startsAt/);
  assert.match(worker, /endsAt/);
});

test("normal wallet, role wallet and room bans are independently enforced", () => {
  assert.match(worker, /owner_wallet_ban_guard/);
  assert.match(worker, /wallet_banned/);
  assert.match(ownerApi, /wallet_banned/);
  assert.match(roleWallets, /role_wallet_banned/);
  assert.match(ownerApi, /parts\[4\] === "ban"/);
  assert.match(worker, /owner_room_controls/);
  assert.match(worker, /room_banned/);
});

test("App Store supports multi-item edit and remove handlers", () => {
  assert.match(panelApp, /\$\$\("\[data-store-edit\]"\)/);
  assert.match(panelApp, /\$\$\("\[data-store-remove\]"\)/);
});


test("Owner Panel has no single-element selector used as a multi-element forEach", () => {
  const bad=[...panelApp.matchAll(/(?<!\$)\$\(([^)]*)\)\.forEach/g)].map((m)=>m[0]);
  assert.deepEqual(bad,[]);
});

test("per-user price free and validity policies are live-backed", () => {
  assert.match(ownerApi,/CREATE TABLE IF NOT EXISTS owner_user_price_overrides/);
  assert.match(ownerApi,/async function handlePricingOverrides/);
  assert.match(panelApp,/async function loadPricingOverrides/);
  assert.match(panelApp,/async function savePricingOverride/);
  assert.match(worker,/async function ownerUserPricing/);
  assert.match(worker,/owner_price_override:pricing\.overridden/);
  assert.match(worker,/db,sender,"gift"/);
  assert.match(worker,/db,userId,"unique_id"/);
  assert.match(worker,/db,actorId,"room_theme","upload"/);
  assert.match(uniqueIdStore,/pricing\?\.price_coins/);
});

test("all nine Master Feature Switches are seeded exposed and enforced", () => {
  const keys=[
    "feature.voice","feature.gifts","feature.games","feature.messages",
    "feature.room_creation","feature.aladdin_lamp","feature.red_pocket",
    "feature.friends_call","feature.visitors",
  ];
  for(const key of keys){
    assert.match(ownerApi,new RegExp(key.replace(".","\\.")));
    assert.match(worker,new RegExp(key.replace(".","\\.")));
  }
  assert.doesNotMatch(worker,/20261013_room_creation_repair/);
  assert.match(worker,/red_pocket_disabled/);
  assert.match(worker,/friends_call_disabled/);
  assert.match(worker,/visitors_disabled/);
});

test("scheduled announcements support edit windows and automatic expiry", () => {
  assert.match(ownerApi,/announcement_end_must_be_after_start/);
  assert.match(panelHtml,/id="announcementStart"/);
  assert.match(panelHtml,/id="announcementEnd"/);
  assert.match(panelApp,/localInputValue/);
  assert.match(panelApp,/clearAnnouncementForm/);
});

test("manual Owner VIP grants use the same enabled rule and validity as live leveling", () => {
  assert.match(ownerApi,/async function ownerVipRule/);
  assert.match(ownerApi,/vip_level_disabled/);
  assert.match(ownerApi,/exp_balance=0/);
  assert.match(ownerApi,/Number\(rule\.days/);
});

test("Games tab supports standalone user betting investigation", () => {
  assert.match(ownerApi,/user_investigation/);
  assert.match(ownerApi,/user_error/);
  assert.match(panelHtml,/id="gameInvestigationUser"/);
  assert.match(panelHtml,/id="gameUserStats"/);
  assert.match(panelApp,/gameInvestigationUser/);
  assert.match(panelApp,/Recent Bets/);
});

test("user investigation exposes sending receiving purchases value and game performance", () => {
  for(const token of [
    "sent_gift_coins","received_gift_coins","purchase_coins",
    "wallet_usd","game_wagered","game_payout","game_house_result","online_duration_ms",
  ]){
    assert.match(ownerApi,new RegExp(token));
  }
  assert.match(panelHtml,/id="userInvestigation"/);
  assert.match(panelApp,/Current room time/);
});

test("notifications are Owner-only and staff audit is scoped to its own panel", () => {
  assert.match(ownerApi,/owner_only_notifications/);
  assert.match(ownerApi,/owner_only_audit_delete/);
  assert.match(ownerApi,/actor_type='staff' AND actor_id=\?/);
  assert.match(panelApp,/state\.actor\?\.type!==\"owner\"/);
  assert.match(panelApp,/exportAuditCsv/);
});
