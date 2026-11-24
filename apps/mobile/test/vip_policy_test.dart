import 'dart:ui';

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

  test('51 privileges: 4 removed (Vinay, 2026-11-24)', () {
    expect(VipPolicy.privileges.length, 51);
    final ids = VipPolicy.privileges.map((p) => p.id).toSet();
    // Friends Limit Expanded was removed (Vinay, 2026-11-19).
    expect(ids.contains('friends_limit'), false);
    // The 4 privileges Mr. Wrong ordered removed (2026-11-24):
    // Hide Last Online, Room With Many Seats, Display in News,
    // Recommend on Splash — none of them was ever built.
    for (final id in <String>[
      'hide_last_online',
      'many_seats',
      'vip_news',
      'splash_recommend',
    ]) {
      expect(ids.contains(id), false, reason: '$id must be gone');
    }
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
    // Card Background + Custom Avatar Frame are VIP1 (corrected 2026-11-22:
    // both show for any active VIP, so their old 16/17 levels were wrong),
    // so VIP1-6 each gain 2 over the old counts.
    expect(VipPolicy.unlockedAt(1).length, 7);
    // Daily Rewards moved to VIP5 (Vinay, 2026-11-20): VIP2-4 no
    // longer see it, so their counts drop by one each.
    // Hide Last Online removed (Mr. Wrong, 2026-11-24): VIP2-6 each
    // drop by one more.
    expect(VipPolicy.unlockedAt(2).length, 8);
    expect(VipPolicy.unlockedAt(3).length, 10);
    expect(VipPolicy.unlockedAt(4).length, 11);
    expect(VipPolicy.unlockedAt(5).length, 21);
    expect(VipPolicy.unlockedAt(6).length, 22);
    // 50, not 51: nickname_light is VIP8-17 only, so VIP18 does not
    // see it — every other privilege is unlocked at VIP18.
    expect(VipPolicy.unlockedAt(18).length, 50);
    // VIP6 does not see VIP7+ privileges at all.
    final vip6Ids = VipPolicy.unlockedAt(6).map((p) => p.id).toSet();
    expect(vip6Ids.contains('dynamic_avatar'), false);
    expect(vip6Ids.contains('gift_discount_30'), false);
    // Daily Rewards is VIP5+ only (Vinay, 2026-11-20): VIP1-4 get
    // no per-day coin claim; the claim starts at VIP5.
    final dailyRewards =
        VipPolicy.privileges.firstWhere((p) => p.id == 'daily_rewards');
    expect(dailyRewards.isUnlockedAt(4), false);
    expect(dailyRewards.isUnlockedAt(5), true);
    expect(dailyRewards.isUnlockedAt(18), true);
    // Name Colour is a range: VIP5-18.
    final nameColour =
        VipPolicy.privileges.firstWhere((p) => p.id == 'name_colour');
    expect(nameColour.isUnlockedAt(4), false);
    expect(nameColour.isUnlockedAt(5), true);
    expect(nameColour.isUnlockedAt(18), true);
    // VIP1 sees its own 7 privileges only (card_background +
    // custom_avatar_frame corrected to VIP1, 2026-11-22).
    final vip1Ids = VipPolicy.unlockedAt(1).map((p) => p.id).toSet();
    expect(
      vip1Ids,
      {'vip_logo', 'headframe', 'display_front', 'view_visitors', 'exp_boost_1_1x', 'custom_avatar_frame', 'card_background'},
    );
  });

  test('name colours are one distinct colour per VIP level (VIP5-18)', () {
    // Approved list (Vinay, 2026-11-20): gold at the bottom, rising
    // to a gold-to-red gradient at VIP18. Below VIP5 there is no colour.
    expect(VipPolicy.nameColours.length, 13);
    expect(VipPolicy.nameColours.values.toSet().length, 13);
    expect(VipPolicy.nameColourForLevel(0), isNull);
    expect(VipPolicy.nameColourForLevel(4), isNull);
    expect(VipPolicy.nameColourForLevel(5), const Color(0xFFFFD700));
    expect(VipPolicy.nameColourForLevel(6), const Color(0xFFFFB11B));
    expect(VipPolicy.nameColourForLevel(7), const Color(0xFFFF8C00));
    expect(VipPolicy.nameColourForLevel(8), const Color(0xFFC07DFF));
    expect(VipPolicy.nameColourForLevel(9), const Color(0xFF9B32FF));
    expect(VipPolicy.nameColourForLevel(10), const Color(0xFFA64DFF));
    expect(VipPolicy.nameColourForLevel(11), const Color(0xFF4DC3FF));
    expect(VipPolicy.nameColourForLevel(12), const Color(0xFF00E5FF));
    expect(VipPolicy.nameColourForLevel(13), const Color(0xFF3D7BFF));
    expect(VipPolicy.nameColourForLevel(14), const Color(0xFFFF5C8A));
    expect(VipPolicy.nameColourForLevel(15), const Color(0xFFFF2E4D));
    expect(VipPolicy.nameColourForLevel(16), const Color(0xFFFF2EA6));
    expect(VipPolicy.nameColourForLevel(17), const Color(0xFFFF4D00));
    // VIP18 has no single colour — it is the gold-to-red gradient.
    expect(VipPolicy.nameColourForLevel(18), isNull);
    expect(VipPolicy.nameColourForLevel(19), isNull);
    expect(
      VipPolicy.nameGradientForLevel(18),
      const <Color>[Color(0xFFFFD700), Color(0xFFFF2E4D)],
    );
    expect(VipPolicy.nameGradientForLevel(17), isNull);
    expect(VipPolicy.nameGradientForLevel(5), isNull);
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

  test('message roaming tiers are 30 and 45 days (capped at 45)', () {
    expect(VipPolicy.messageRetentionDays(5), 30);
    expect(VipPolicy.messageRetentionDays(8), 45);
    expect(VipPolicy.messageRetentionDays(12), 45);
  });

  test('removed incomplete privileges are not present', () {
    final ids = VipPolicy.privileges.map((p) => p.id).toSet();
    expect(ids.contains('exclusive_gifts'), true);
    expect(ids.contains('exclusive_game_room'), false);
    expect(ids.contains('hide_host_sign'), false);
    expect(ids.contains('exclusive_mic_emoticon'), true);
  });

  test('Anti-Mute applies only to active VIP13+ members', () {
    expect(VipPolicy.hasAntiMute(13, active: true), true);
    expect(VipPolicy.hasAntiMute(18, active: true), true);
    expect(VipPolicy.hasAntiMute(12, active: true), false);
    expect(VipPolicy.hasAntiMute(13, active: false), false);
    expect(VipPolicy.hasAntiMute(0, active: false), false);
  });

  test('VIP-only room entry follows the room threshold', () {
    // VIP 1+ rooms admit any active VIP.
    expect(
      VipPolicy.canEnterVipOnlyRoom(1, active: true, requiredLevel: 1),
      true,
    );
    expect(
      VipPolicy.canEnterVipOnlyRoom(18, active: true, requiredLevel: 1),
      true,
    );
    expect(
      VipPolicy.canEnterVipOnlyRoom(0, active: false, requiredLevel: 1),
      false,
    );
    // VIP 5+ rooms admit VIP5 and above only.
    expect(
      VipPolicy.canEnterVipOnlyRoom(5, active: true, requiredLevel: 5),
      true,
    );
    expect(
      VipPolicy.canEnterVipOnlyRoom(4, active: true, requiredLevel: 5),
      false,
    );
    expect(
      VipPolicy.canEnterVipOnlyRoom(5, active: false, requiredLevel: 5),
      false,
    );
    // Making a VIP-only room needs VIP10.
    expect(
      VipPolicy.canEnterVipOnlyRoom(10, active: true, requiredLevel: 10),
      true,
    );
    expect(
      VipPolicy.canEnterVipOnlyRoom(9, active: true, requiredLevel: 10),
      false,
    );
  });
}
