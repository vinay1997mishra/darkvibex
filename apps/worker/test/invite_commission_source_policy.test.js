import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const inviteRewards = readFileSync(new URL("../src/invite_rewards.js", import.meta.url), "utf8");
const worker = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const inviteScreen = readFileSync(new URL("../../mobile/lib/screens/invite_share_screen.dart", import.meta.url), "utf8");

// Invite extras policy (Vinay, 2026-11-23): a seller-wallet transfer
// counts as a recharge everywhere. Merchant transfers earn the same
// extras as Coin Seller transfers — VIP EXP, the coin commission AND
// the 5% referral dollars on top — and the inviter's dollar
// commission is recorded with the transfer id as its dedup key.
test("transfer extras run for Coin Seller and Merchant transfers", () => {
  assert.match(inviteRewards, /walletType !== "coin_seller" && walletType !== "merchant"/);
  assert.match(inviteRewards, /reason: "ineligible_source"/);
  assert.doesNotMatch(inviteRewards, /Commission volume is strictly Coin Seller received coins/);
  // The extras live in the shared awardTransferExtras helper: it runs
  // for both seller wallet types, from both transfer routes, and
  // records the 5% referral dollars with the transfer id.
  assert.match(worker, /async function awardTransferExtras/);
  assert.match(worker, /if \(walletType !== "coin_seller" && walletType !== "merchant"\) \{\s*return \{ vipAward, inviteCommission, dollarCommission, warnings \};/);
  assert.match(worker, /inviteCommission = await recordCoinSellerInviteCommission\(db, \{/);
  assert.match(worker, /dollarCommission = await recordRechargeInviteCommission\(db, \{/);
  assert.match(worker, /purchaseToken: transferId,/);
});

test("invite UI explains eligible sources include Merchant transfers", () => {
  assert.match(inviteScreen, /Only coins received through eligible Coin Seller or Merchant transfers/);
  assert.match(inviteScreen, /Gifts, game winnings and other coin sources do not count/);
  assert.doesNotMatch(inviteScreen, /Merchant transfers, gifts, game winnings and other coin sources do not count/);
});
