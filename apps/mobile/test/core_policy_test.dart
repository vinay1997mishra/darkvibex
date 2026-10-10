import 'package:darkvibex/core/role_policy.dart';
import 'package:darkvibex/core/seat_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy business hierarchy roles are rejected', () {
    expect(() => RolePolicy.parse('host'), throwsStateError);
    expect(() => RolePolicy.parse('agency'), throwsStateError);
    expect(() => RolePolicy.parse('bd'), throwsStateError);
  });

  test('supported DarkVibeX roles remain available', () {
    expect(RolePolicy.parse('user'), DarkVibeXRole.user);
    expect(RolePolicy.parse('room_owner'), DarkVibeXRole.roomOwner);
    expect(RolePolicy.parse('coin_seller'), DarkVibeXRole.coinSeller);
    expect(RolePolicy.parse('merchant'), DarkVibeXRole.merchant);
  });

  test('seat counts normalize inside the supported range', () {
    expect(normalizeSeatCount(1), 8);
    expect(normalizeSeatCount(12), 12);
    expect(normalizeSeatCount(100), 42);
  });
}
