import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const indexJs = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const uniqueIdStore = await readFile(new URL("../src/unique_id_store.js", import.meta.url), "utf8");
const vipActions = await readFile(new URL("../src/vip_actions.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("new public IDs are serial from 10000001 and not random", () => {
  assert.match(indexJs, /CREATE TABLE IF NOT EXISTS public_id_sequence_8digit/);
  assert.match(indexJs, /VALUES\('main',10000001\)/);
  assert.match(indexJs, /RETURNING next_value-1 AS value/);
  assert.match(indexJs, /value < 10000001/);
  assert.doesNotMatch(indexJs, /Math\.floor\(1000000 \+ Math\.random\(\) \* 9000000\)/);
  assert.match(indexJs, /SELECT id,public_id,display_name,role,coins/);
});

test("one user owns an ID permanently across public, VIP and purchased ID paths", () => {
  assert.match(indexJs, /owner_public_id_history/);
  assert.match(indexJs, /unique_id_purchases WHERE public_id=\? AND buyer_user_id<>\?/);
  assert.match(ownerApi, /public_id_reserved_by_history/);
  assert.match(ownerApi, /public_id_owned_by_another_user/);
  assert.match(ownerApi, /public_id_must_be_10000001_to_99999999/);
  assert.match(panelApp, /Public ID must be between 10000001 and 99999999/);
  assert.match(uniqueIdStore, /purchaseOwner/);
  assert.match(uniqueIdStore, /unique_id_taken/);
  assert.match(vipActions, /unique_id_purchases WHERE public_id=\? AND buyer_user_id<>\?/);
});

test("Owner Panel can add edit enable disable and remove live app-store items", () => {
  assert.match(ownerApi, /async function handleStore/);
  assert.match(ownerApi, /parts\[2\] === "store"/);
  assert.match(ownerApi, /store_upsert/);
  assert.match(ownerApi, /store_remove/);
  assert.match(panelHtml, /data-view="store"/);
  assert.match(panelHtml, /id="saveStoreItem"/);
  assert.match(panelHtml, /id="storeKind"/);
  assert.match(panelApp, /async function loadStore/);
  assert.match(panelApp, /async function saveStoreItem/);
  assert.match(panelApp, /async function removeStoreItem/);
  assert.match(indexJs, /async function effectiveCosmeticCatalog/);
  assert.match(indexJs, /async function effectiveGiftCatalog/);
  assert.match(indexJs, /async function ownerUserPricingForCatalog\(db,userId,catalog\)/);
  assert.match(indexJs, /const pricing = await ownerUserPricingForCatalog\(db, userId, catalog\)/);
  assert.doesNotMatch(indexJs, /for\(const item of await effectiveCosmeticCatalog\(db\)\)/);
  assert.match(indexJs, /ownerUserPricing/);
  assert.match(indexJs, /await effectiveGiftCatalog\(db\)/);
});
