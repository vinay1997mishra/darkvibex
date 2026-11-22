import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const inviteRewards = readFileSync(new URL("../src/invite_rewards.js", import.meta.url), "utf8");
const worker = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
const inviteScreen = readFileSync(new URL("../../mobile/lib/screens/invite_share_screen.dart", import.meta.url), "utf8");

// Invite reward rule (Vinay, 2026-11-23): the inviter gets coins only
// ONCE per invite — 800,000 when the invite succeeds. On every recharge
// the inviter gets NO coins, only 5% of the recharge amount in dollars.
// The old per-recharge coin commission (3-5% tiers) was removed entirely.
test("no per-recharge coin commission remains anywhere", () => {
  assert.doesNotMatch(inviteRewards, /recordCoinSellerInviteCommission/);
  assert.doesNotMatch(inviteRewards, /invite_commission_rewards/);
  assert.doesNotMatch(inviteRewards, /DIRECT_INVITE_TIERS/);
  assert.doesNotMatch(inviteRewards, /tierFor/);
  assert.doesNotMatch(inviteRewards, /commission_coins/);
  assert.doesNotMatch(inviteRewards, /current_rate/);
  // The transfer extras helper awards VIP EXP + the 5% referral
  // dollars only — no coin commission call, no invite_commission field.
  assert.match(worker, /async function awardTransferExtras/);
  assert.match(worker, /dollarCommission = await recordRechargeInviteCommission\(db, \{/);
  assert.doesNotMatch(worker, /recordCoinSellerInviteCommission/);
  assert.doesNotMatch(worker, /invite_commission:/);
  assert.doesNotMatch(worker, /inviteCommission/);
});

test("invite UI shows no coin commission anywhere", () => {
  assert.match(inviteScreen, /800,000 coins per successful invite, plus 5% of every recharge/);
  assert.doesNotMatch(inviteScreen, /coin commission/i);
  assert.doesNotMatch(inviteScreen, /current_rate_percent/);
  assert.doesNotMatch(inviteScreen, /commission_coins/);
  assert.doesNotMatch(inviteScreen, /Coin Seller Coins/);
  assert.doesNotMatch(inviteScreen, /Reward level/);
  assert.doesNotMatch(inviteScreen, /_tierCard/);
});
