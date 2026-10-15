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


test("owner panel manages public IDs and dedicated seller/merchant wallets", () => {
  assert.match(ownerApi, /owner_public_id_history/);
  assert.match(ownerApi, /parts\[4\] === "public-id"/);
  assert.match(panelHtml, /id="editPublicId"/);
  assert.match(panelHtml, /id="oldPublicIds"/);
  assert.match(panelHtml, /id="roleWalletType"/);
  assert.match(panelHtml, /id="applyRoleWallet"/);
  assert.match(panelApp, /savePublicId/);
  assert.match(panelApp, /applyRoleWallet/);
});


test("owner panel exposes dedicated unique-ID and master coin-rate controls", () => {
  assert.match(panelHtml, /data-view="economy"/);
  assert.match(panelHtml, /id="economyPublicId"/);
  assert.match(panelHtml, /id="coinRateCoinsPerUsd"/);
  assert.match(panelApp, /saveEconomyPublicId/);
  assert.match(panelApp, /saveCoinRate/);
  assert.match(ownerApi, /handleEconomy/);
  assert.match(ownerApi, /economy\.coin_rate/);
  assert.match(ownerApi, /coin_rate_update/);
  assert.match(ownerApi, /invalid_coins_per_usd/);
  assert.match(ownerApi, /public_id_reserved_by_history/);
});
