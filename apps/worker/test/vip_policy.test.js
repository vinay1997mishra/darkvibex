import test from "node:test";
import assert from "node:assert/strict";
import { vipCapabilities } from "../src/vip_policy.js";

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
