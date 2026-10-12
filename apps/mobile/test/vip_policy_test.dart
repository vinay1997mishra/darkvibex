import 'package:flutter_test/flutter_test.dart';

import '../lib/vip/vip_policy.dart';

void main() {
  test('DarkVibeX VIP has exactly 18 levels', () {
    expect(VipPolicy.levels.length, 18);
    expect(VipPolicy.maxLevel, 18);
    expect(VipPolicy.ruleFor(18)?.validityDays, 45);
  });

  test('Coin Seller VIP EXP stays one-to-one at every VIP level', () {
    expect(VipPolicy.expMultiplier(16, active: true), 1.0);
    expect(VipPolicy.expMultiplier(17, active: true), 1.0);
    expect(VipPolicy.expMultiplier(18, active: true), 1.0);
    expect(VipPolicy.expMultiplier(18, active: false), 1.0);
  });

  test('nickname light is only VIP8 through VIP17', () {
    final light = VipPolicy.privileges.firstWhere((p) => p.id == 'nickname_light');
    expect(light.isUnlockedAt(7), false);
    expect(light.isUnlockedAt(8), true);
    expect(light.isUnlockedAt(17), true);
    expect(light.isUnlockedAt(18), false);
  });

  test('room seats and show id follow VIP rules', () {
    expect(VipPolicy.maxRoomSeats(6), 12);
    expect(VipPolicy.maxRoomSeats(7), 20);
    expect(VipPolicy.maxRoomSeats(10), 30);
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
