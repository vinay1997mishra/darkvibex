import test from "node:test";
import assert from "node:assert/strict";
import { vipCapabilities, vipRule } from "../src/vip_policy.js";
test("VIP EXP thresholds match the confirmed 400 coin schedule", () => {
  // Upgrade EXP is the incremental cumulative total / 400 (400 coins =
  // 1 VIP EXP), matching the Dart client (VipPolicy.levels[].upgradeExp).
  // The old table carried raw coin figures here (25,000,000 for VIP1),
  // which the worker compared against EXP balances and made VIP1 need
  // 10,000,000,000 coins instead of the advertised 35,000,000. The
  // ladder itself was repriced by Vinay on 2026-11-18 ($1 = 8,000,000
  // coins; VIP1 $3 = 24,000,000 coins ... VIP18 $10,000).
  const expected = [60000,100000,240000,600000,2000000,5000000,10000000,12000000,12000000,14000000,12000000,14000000,12000000,14000000,22000000,22000000,24000000,24000000];
  assert.deepEqual(expected.map((_,i)=>vipRule(i+1).upgrade),expected);
  assert.deepEqual(
    expected.map((_,i)=>{
      const rule=vipRule(i+1);
      const prev=i===0?0:vipRule(i).total;
      return (rule.total-prev)/400;
    }),
    expected,
  );
});

test("VIP pricing ladder matches Vinay's $1 = 8,000,000 coins prices", () => {
  const totals = [24000000,64000000,160000000,400000000,1200000000,3200000000,7200000000,12000000000,16800000000,22400000000,27200000000,32800000000,37600000000,43200000000,52000000000,60800000000,70400000000,80000000000];
  assert.deepEqual(totals.map((_,i)=>vipRule(i+1).total),totals);
  // $ prices: total / 8,000,000 — VIP1 $3 ... VIP18 $10,000.
  assert.deepEqual(totals.map((t)=>t/8000000),[3,8,20,50,150,400,900,1500,2100,2800,3400,4100,4700,5400,6500,7600,8800,10000]);
  // Validity: 30 days for VIP1-15, 60 days for VIP16-18.
  assert.deepEqual(totals.map((_,i)=>vipRule(i+1).days),[...Array(15).fill(30),60,60,60]);
  assert.equal(vipCapabilities(15, true).validity_days, 30);
  assert.equal(vipCapabilities(16, true).validity_days, 60);
  assert.equal(vipCapabilities(17, true).validity_days, 60);
  assert.equal(vipCapabilities(18, true).validity_days, 60);
});


test("VIP room and safety entitlements are active-only and level-gated", () => {
  assert.equal(vipCapabilities(2, true).room_background_enabled, false);
  assert.equal(vipCapabilities(3, true).room_background_enabled, true);
  assert.equal(vipCapabilities(4, true).picture_welcome_enabled, false);
  assert.equal(vipCapabilities(5, true).picture_welcome_enabled, true);
  assert.equal(vipCapabilities(5, true).red_envelope_enabled, false);
  assert.equal(vipCapabilities(6, true).red_envelope_enabled, true);
  assert.equal(vipCapabilities(18, false).red_envelope_enabled, false);
  assert.equal(vipCapabilities(8, true).customer_service_enabled, false);
  assert.equal(vipCapabilities(9, true).customer_service_enabled, true);
  assert.equal(vipCapabilities(18, false).customer_service_enabled, false);
  assert.equal(vipCapabilities(9, true).room_images_enabled, false);
  assert.equal(vipCapabilities(10, true).room_images_enabled, true);
  assert.equal(vipCapabilities(12, true).seat_protection_enabled, false);
  assert.equal(vipCapabilities(13, true).seat_protection_enabled, true);
  assert.equal(vipCapabilities(13, true).kick_protection_enabled, false);
  assert.equal(vipCapabilities(14, true).kick_protection_enabled, true);
  assert.equal(vipCapabilities(18, false).room_background_enabled, false);
  assert.equal(vipCapabilities(18, false).picture_welcome_enabled, false);
  assert.equal(vipCapabilities(18, false).room_images_enabled, false);
  assert.equal(vipCapabilities(18, false).seat_protection_enabled, false);
  assert.equal(vipCapabilities(18, false).kick_protection_enabled, false);
});

test("expired VIP capabilities return to base limits", () => {
  const expired = vipCapabilities(18, false);
  assert.equal(expired.room_seat_limit, 12);
  assert.equal(expired.friend_bonus, 0);
  assert.equal(expired.friend_limit, 300);
  assert.equal(expired.friends_unlimited, false);
  assert.equal(vipCapabilities(1, true).friend_limit, null);
  assert.equal(vipCapabilities(3, true).exclusive_gifts_enabled, true);
  assert.equal(vipCapabilities(8, true).exclusive_mic_emoticon_enabled, false);
  assert.equal(vipCapabilities(9, true).exclusive_mic_emoticon_enabled, true);
  assert.equal(vipCapabilities(18, true).honorary_title_enabled, true);
  assert.equal(expired.message_retention_days, 0);
  assert.equal(vipCapabilities(8, true).message_retention_days, 60);
  assert.equal(vipCapabilities(12, true).message_retention_days, 120);
  assert.equal(expired.show_id_style_level, 0);
  assert.equal(expired.entrance_vehicle_tier, 0);
  assert.equal(expired.exp_multiplier, 1);
  assert.equal(vipCapabilities(17, true).exp_multiplier, 1);
  assert.equal(vipCapabilities(18, true).exp_multiplier, 1);
});

