import test from "node:test";
import assert from "node:assert/strict";
import { vipCapabilities, vipRule } from "../src/vip_policy.js";
test("VIP EXP thresholds match the purchase-only EXP ladder", () => {
  // Levels are defined in EXP (Vinay, 2026-11-18): each level's total is
  // the CUMULATIVE EXP to reach it and equals the level's $ price x 150
  // (VIP1 $3 = 450 EXP ... VIP18 $10,000 = 1,500,000 EXP). Upgrade EXP is
  // the incremental total (total minus previous total) — NOT coins/400.
  // EXP is earned only by buying coins (150 EXP per $1), never by
  // spending. Must match the Dart client (VipPolicy.levels[].upgradeExp).
  const expected = [450,750,1800,4500,15000,37500,75000,90000,90000,105000,90000,105000,90000,105000,165000,165000,180000,180000];
  assert.deepEqual(expected.map((_,i)=>vipRule(i+1).upgrade),expected);
  assert.deepEqual(
    expected.map((_,i)=>{
      const rule=vipRule(i+1);
      const prev=i===0?0:vipRule(i).total;
      return rule.total-prev;
    }),
    expected,
  );
});

test("VIP EXP ladder matches Vinay's $ price x 150 thresholds", () => {
  const totals = [450,1200,3000,7500,22500,60000,135000,225000,315000,420000,510000,615000,705000,810000,975000,1140000,1320000,1500000];
  assert.deepEqual(totals.map((_,i)=>vipRule(i+1).total),totals);
  // $ prices: total / 150 — VIP1 $3 ... VIP18 $10,000.
  assert.deepEqual(totals.map((t)=>t/150),[3,8,20,50,150,400,900,1500,2100,2800,3400,4100,4700,5400,6500,7600,8800,10000]);
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
  assert.equal(vipCapabilities(17, true).exp_multiplier, 1.5);
  assert.equal(vipCapabilities(18, true).exp_multiplier, 1.5);
  assert.equal(vipCapabilities(5, true).exp_multiplier, 1.2);
  assert.equal(vipCapabilities(1, true).exp_multiplier, 1.1);
});

