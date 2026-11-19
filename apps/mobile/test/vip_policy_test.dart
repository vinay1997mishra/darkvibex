import 'package:flutter_test/flutter_test.dart';

import '../lib/vip/vip_policy.dart';

void main() {
  test('DarkVibeX VIP has exactly 18 levels', () {
    expect(VipPolicy.levels.length, 18);
    expect(VipPolicy.maxLevel, 18);
    expect(VipPolicy.ruleFor(18)?.validityDays, 60);
  });

  test('Coin Seller VIP EXP boost grows with the VIP level', () {
    // EXP boost (Vinay, 2026-11-19): the EXP earned on a coin purchase
    // is multiplied by the level boost. Inactive VIPs earn at 1.0x.
    expect(VipPolicy.expMultiplier(0, active: false), 1.0);
    expect(VipPolicy.expMultiplier(0, active: true), 1.0);
    expect(VipPolicy.expMultiplier(1, active: true), 1.1);
    expect(VipPolicy.expMultiplier(4, active: true), 1.1);
    expect(VipPolicy.expMultiplier(5, active: true), 1.2);
    expect(VipPolicy.expMultiplier(10, active: true), 1.2);
    expect(VipPolicy.expMultiplier(11, active: true), 1.4);
    expect(VipPolicy.expMultiplier(15, active: true), 1.4);
    expect(VipPolicy.expMultiplier(16, active: true), 1.5);
    expect(VipPolicy.expMultiplier(17, active: true), 1.5);
    expect(VipPolicy.expMultiplier(18, active: true), 1.5);
    expect(VipPolicy.expMultiplier(18, active: false), 1.0);
  });

  test('coins bonus and gift discount rates grow with the VIP level', () {
    expect(VipPolicy.coinsBonusRate(4, active: true), 0);
    expect(VipPolicy.coinsBonusRate(5, active: true), 0.05);
    expect(VipPolicy.coinsBonusRate(10, active: true), 0.05);
    expect(VipPolicy.coinsBonusRate(11, active: true), 0.10);
    expect(VipPolicy.coinsBonusRate(15, active: true), 0.10);
    expect(VipPolicy.coinsBonusRate(16, active: true), 0.20);
    expect(VipPolicy.coinsBonusRate(18, active: true), 0.20);
    expect(VipPolicy.coinsBonusRate(18, active: false), 0);
    expect(VipPolicy.giftDiscountRate(7, active: true), 0);
    expect(VipPolicy.giftDiscountRate(8, active: true), 0.10);
    expect(VipPolicy.giftDiscountRate(13, active: true), 0.10);
    expect(VipPolicy.giftDiscountRate(14, active: true), 0.20);
    expect(VipPolicy.giftDiscountRate(17, active: true), 0.20);
    expect(VipPolicy.giftDiscountRate(18, active: true), 0.30);
    expect(VipPolicy.giftDiscountRate(18, active: false), 0);
  });

  test('55 privileges: friends limit removed, 15 new entries added', () {
    expect(VipPolicy.privileges.length, 55);
    final ids = VipPolicy.privileges.map((p) => p.id).toSet();
    // Friends Limit Expanded was removed (Vinay, 2026-11-19).
    expect(ids.contains('friends_limit'), false);
    // The 15 new privileges (Vinay, 2026-11-19).
    for (final id in <String>[
      'exp_boost_1_1x',
      'daily_rewards',
      'exp_boost_1_2x',
      'coins_bonus_5',
      'name_colour',
      'gift_discount_10',
      'priority_message',
      'vip_only_rooms',
      'exp_boost_1_4x',
      'coins_bonus_10',
      'anti_mute',
      'gift_discount_20',
      'exp_boost_1_5x',
      'coins_bonus_20',
      'gift_discount_30',
    ]) {
      expect(ids.contains(id), true, reason: '$id must be present');
    }
    // No duplicate privilege ids.
    expect(ids.length, VipPolicy.privileges.length);
  });

  test('unlockedAt is cumulative: only the level own privileges show', () {
    expect(VipPolicy.unlockedAt(1).length, 5);
    expect(VipPolicy.unlockedAt(2).length, 8);
    expect(VipPolicy.unlockedAt(3).length, 10);
    expect(VipPolicy.unlockedAt(4).length, 11);
    expect(VipPolicy.unlockedAt(5).length, 20);
    expect(VipPolicy.unlockedAt(6).length, 21);
    // 54, not 55: nickname_light is VIP8-17 only, so VIP18 does not
    // see it — every other privilege is unlocked at VIP18.
    expect(VipPolicy.unlockedAt(18).length, 54);
    // VIP6 does not see VIP7+ privileges at all.
    final vip6Ids = VipPolicy.unlockedAt(6).map((p) => p.id).toSet();
    expect(vip6Ids.contains('dynamic_avatar'), false);
    expect(vip6Ids.contains('gift_discount_30'), false);
    // Name Colour is a range: VIP5-18.
    final nameColour =
        VipPolicy.privileges.firstWhere((p) => p.id == 'name_colour');
    expect(nameColour.isUnlockedAt(4), false);
    expect(nameColour.isUnlockedAt(5), true);
    expect(nameColour.isUnlockedAt(18), true);
    // VIP1 sees its own 5 privileges only.
    final vip1Ids = VipPolicy.unlockedAt(1).map((p) => p.id).toSet();
    expect(
      vip1Ids,
      {'vip_logo', 'headframe', 'display_front', 'view_visitors', 'exp_boost_1_1x'},
    );
  });

  test('nickname light is only VIP8 through VIP17', () {
    final light = VipPolicy.privileges.firstWhere((p) => p.id == 'nickname_light');
    expect(light.isUnlockedAt(7), false);
    expect(light.isUnlockedAt(8), true);
    expect(light.isUnlockedAt(17), true);
    expect(light.isUnlockedAt(18), false);
  });

  test('room seats stay at 42 and show id follows VIP rules', () {
    expect(VipPolicy.maxRoomSeats(0), 42);
    expect(VipPolicy.maxRoomSeats(6), 42);
    expect(VipPolicy.maxRoomSeats(7), 42);
    expect(VipPolicy.maxRoomSeats(10), 42);
    expect(VipPolicy.maxRoomSeats(18), 42);
    expect(VipPolicy.showIdStyleLevel(14), 14);
    expect(VipPolicy.showIdStyleLevel(18), 14);
    final uniqueId = VipPolicy.privileges.firstWhere((p) => p.id == 'unique_id');
    expect(uniqueId.isUnlockedAt(14), false);
    expect(uniqueId.isUnlockedAt(15), true);
    expect(uniqueId.isUnlockedAt(18), true);
  });

  test('confirmed gift and mic emoticon perks are VIP gated', () {
    final gifts = VipPolicy.privileges.firstWhere((p) => p.id == 'exclusive_gifts');
    final mic = VipPolicy.privileges.firstWhere((p) => p.id == 'exclusive_mic_emoticon');
    expect(gifts.isUnlockedAt(2), false);
    expect(gifts.isUnlockedAt(3), true);
    expect(mic.isUnlockedAt(8), false);
    expect(mic.isUnlockedAt(9), true);
  });

  test('base friend limit and VIP unlimited friends', () {
    expect(VipPolicy.friendLimit(0, active: false), 300);
    expect(VipPolicy.friendLimit(3, active: true), isNull);
  });

  test('message roaming tiers are 30, 60 and 120 days', () {
    expect(VipPolicy.messageRetentionDays(5), 30);
    expect(VipPolicy.messageRetentionDays(8), 60);
    expect(VipPolicy.messageRetentionDays(12), 120);
  });

  test('removed incomplete privileges are not present', () {
    final ids = VipPolicy.privileges.map((p) => p.id).toSet();
    expect(ids.contains('exclusive_gifts'), true);
    expect(ids.contains('exclusive_game_room'), false);
    expect(ids.contains('hide_host_sign'), false);
    expect(ids.contains('exclusive_mic_emoticon'), true);
  });
}
