import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");

function quotedValuesBetween(source, startText, endText) {
  const start = source.indexOf(startText);
  assert.notEqual(start, -1, "start block not found: " + startText);
  const end = source.indexOf(endText, start);
  assert.notEqual(end, -1, "end block not found: " + endText);
  return [...source.slice(start, end).matchAll(/"([^"]+)"/g)].map((m) => m[1]);
}

test("staff roles are labels and empty permissions do not inherit defaults", () => {
  assert.doesNotMatch(ownerApi, /defaultPermissions\(/);
  assert.match(ownerApi, /const permissions = Array\.isArray\(explicit\) \? explicit\.map\(String\)/);
  assert.match(ownerApi, /const permissions = sanitizeStaffPermissions\(actor, body\.permissions\)/);
  assert.match(panelHtml, /Role is only a label\. It does not grant any permission automatically\./);
  assert.match(panelHtml, /Unchecked means no access/);
  assert.doesNotMatch(panelApp, /Role defaults/);
  assert.doesNotMatch(panelApp, /Comma-separated permissions/);
  assert.doesNotMatch(panelApp, /Use \* for full access/);
});

test("frontend exact permission choices match backend assignable permission set", () => {
  const backend = new Set(quotedValuesBetween(
    ownerApi,
    "const STAFF_ASSIGNABLE_PERMISSIONS = new Set([",
    "]);",
  ));
  const optionStart = panelApp.indexOf("const staffPermissionOptions = [");
  const optionEnd = panelApp.indexOf("];", optionStart);
  assert.notEqual(optionStart, -1);
  assert.notEqual(optionEnd, -1);
  const frontend = new Set(
    [...panelApp.slice(optionStart, optionEnd).matchAll(/^\s*\["([^"]+)","/gm)].map((m) => m[1]),
  );
  assert.deepEqual([...frontend].sort(), [...backend].sort());
  assert.equal(frontend.has("*"), false);
});

test("user Full ID actions have separate backend permissions", () => {
  for (const permission of [
    "users.search","users.detail","users.name.edit","users.role.edit","users.vip.edit",
    "users.public_id.change","users.moderation","users.wallet.adjust","users.role_wallet.adjust",
    "users.role_wallet.ban","users.override.invisible","users.override.lock_bypass",
    "users.wallet.ban","users.wallet.freeze","users.device.ban",
  ]) {
    assert.match(ownerApi, new RegExp(permission.replaceAll(".", "\\.")));
    assert.match(panelApp, new RegExp(permission.replaceAll(".", "\\.")));
  }
  assert.match(panelApp, /if\(can\("users\.name\.edit"\)\)payload\.display_name/);
  assert.match(panelApp, /if\(can\("users\.role\.edit"\)\)payload\.role/);
  assert.match(panelApp, /if\(can\("users\.vip\.edit"\)\)payload\.vip_level/);
  assert.match(panelApp, /if\(can\("users\.wallet\.freeze"\)\)payload\.wallet_frozen/);
});

test("room and content child actions are independently permissioned", () => {
  for (const permission of [
    "rooms.view","rooms.edit","rooms.lock","rooms.delete","rooms.ban","rooms.live","rooms.media","rooms.theme",
    "themes.global.view","themes.global.save","themes.global.remove",
    "roles.view","roles.save","roles.delete","banners.view","banners.save","banners.delete",
    "games.view","games.configure","policies.view","policies.save","policies.delete",
    "pricing.view","pricing.save","pricing.delete","vip.view","vip.save","vip.reset",
    "gifts.view","gifts.save","gifts.remove","assets.view","assets.save","assets.remove",
    "store.view","store.save","store.remove","catalog.view","catalog.save","catalog.remove",
  ]) {
    assert.match(ownerApi, new RegExp(permission.replaceAll(".", "\\.")));
  }
  assert.match(ownerApi, /function storePermissionForKind/);
  assert.match(ownerApi, /return "gifts\."\+action/);
  assert.match(ownerApi, /return "themes\.global\."\+action/);
  assert.match(ownerApi, /return "assets\."\+action/);
});

test("each master setting toggle has its own permission", () => {
  for (const permission of [
    "settings.feature.voice","settings.feature.gifts","settings.feature.games","settings.feature.messages",
    "settings.feature.room_creation","settings.feature.aladdin_lamp","settings.feature.red_pocket",
    "settings.feature.friends_call","settings.feature.visitors","settings.maintenance",
  ]) {
    assert.match(ownerApi, new RegExp(permission.replaceAll(".", "\\.")));
    assert.match(panelApp, new RegExp(permission.replaceAll(".", "\\.")));
  }
  assert.match(ownerApi, /selectedKeys=.*settingPermissions/s);
  assert.match(panelApp, /element\.closest\("label"\)\.hidden=!can\("settings\."\+key\)/);
});

test("staff panel renders only selected tabs and actions", () => {
  assert.match(panelApp, /const viewPermissionMap = \{/);
  assert.match(panelApp, /const selectorPermissionRules = \[/);
  assert.match(panelApp, /const dynamicPermissionRules = \[/);
  assert.match(panelApp, /btn\.hidden=!allowed/);
  assert.match(panelApp, /permissionTarget\(element,mode\)\.hidden=!canAny\(permissions\)/);
  assert.match(panelApp, /new MutationObserver\(\(\)=>applyActionPermissions\(\)\)/);
  assert.match(panelApp, /renderStaffPermissionEditor\(item\.permissions\|\|\[\]\)/);
  assert.match(panelApp, /permissions=\$\$\("#staffPermissions input:checked"\)\.map/);
  assert.match(panelApp, /const payload=\{display_name:name,role:\$\("#staffRole"\)\.value,permissions\}/);
});

test("private Full ID message inspection remains main-Owner-only", () => {
  assert.match(ownerApi, /async function ownerUserMessageInspection/);
  assert.match(ownerApi, /if\(actor\.type!=="owner"\)/);
  assert.match(ownerApi, /owner_only_message_inspection/);
  assert.match(ownerApi, /owner_message_inbox_view/);
  assert.match(ownerApi, /owner_message_thread_view/);
  assert.match(panelApp, /state\.actor\?\.type==="owner"/);
  const backend = new Set(quotedValuesBetween(
    ownerApi,
    "const STAFF_ASSIGNABLE_PERMISSIONS = new Set([",
    "]);",
  ));
  for (const permission of backend) {
    assert.equal(/private|message.*inspect|inbox.*inspect/i.test(permission), false);
  }
});

test("excluded DarkVibeX modules are still absent from staff permissions and navigation", () => {
  const forbidden = ["hierarchy","verification","agency","guardian","host","lucky-gift"];
  const lower = (panelHtml + "\n" + panelApp.slice(0, panelApp.indexOf("function authHeaders()"))).toLowerCase();
  for (const value of forbidden) {
    assert.equal(lower.includes('data-view="' + value + '"'), false);
    assert.equal(lower.includes('["' + value + "."), false);
  }
});
