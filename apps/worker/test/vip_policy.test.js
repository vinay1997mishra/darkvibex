import test from "node:test";
import assert from "node:assert/strict";
import { vipCapabilities } from "../src/vip_policy.js";

test("VIP room and safety entitlements are active-only and level-gated", () => {
  assert.equal(vipCapabilities(2, true).room_background_enabled, false);
  assert.equal(vipCapabilities(3, true).room_background_enabled, true);
  assert.equal(vipCapabilities(9, true).room_images_enabled, false);
  assert.equal(vipCapabilities(10, true).room_images_enabled, true);
  assert.equal(vipCapabilities(12, true).seat_protection_enabled, false);
  assert.equal(vipCapabilities(13, true).seat_protection_enabled, true);
  assert.equal(vipCapabilities(13, true).kick_protection_enabled, false);
  assert.equal(vipCapabilities(14, true).kick_protection_enabled, true);
  assert.equal(vipCapabilities(18, false).room_background_enabled, false);
  assert.equal(vipCapabilities(18, false).room_images_enabled, false);
  assert.equal(vipCapabilities(18, false).seat_protection_enabled, false);
  assert.equal(vipCapabilities(18, false).kick_protection_enabled, false);
});

test("expired VIP capabilities return to base limits", () => {
  const expired = vipCapabilities(18, false);
  assert.equal(expired.room_seat_limit, 12);
  assert.equal(expired.friend_bonus, 0);
  assert.equal(expired.message_retention_days, 0);
  assert.equal(expired.show_id_style_level, 0);
  assert.equal(expired.entrance_vehicle_tier, 0);
  assert.equal(expired.exp_multiplier, 1);
});
