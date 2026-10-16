import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const inviteRewards = readFileSync(new URL("../src/invite_rewards.js", import.meta.url), "utf8");
const worker = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const inviteScreen = readFileSync(new URL("../../mobile/lib/screens/invite_share_screen.dart", import.meta.url), "utf8");

test("ongoing invite commission is restricted to Coin Seller received coins", () => {
  assert.match(inviteRewards, /walletType !== "coin_seller"/);
  assert.match(inviteRewards, /reason: "ineligible_source"/);
  assert.doesNotMatch(inviteRewards, /\["coin_seller",\s*"merchant"\]/);
  assert.match(worker, /if\(walletType==="coin_seller"\)\s*\{\s*try\s*\{\s*inviteCommission=await recordCoinSellerInviteCommission/);
  assert.doesNotMatch(worker, /if\(walletType==="coin_seller" \|\| walletType==="merchant"\)/);
});

test("invite UI explains eligible sources and excludes Merchant transfers", () => {
  assert.match(inviteScreen, /Only coins received through eligible Coin Seller transfers/);
  assert.match(inviteScreen, /Merchant transfers, gifts, game winnings and other coin sources do not count/);
  assert.doesNotMatch(inviteScreen, /Coin Seller and Merchant transfers both count/);
});
