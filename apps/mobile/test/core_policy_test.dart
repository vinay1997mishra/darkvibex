import 'package:darkvibex/core/role_policy.dart';
import 'package:darkvibex/core/seat_policy.dart';
import 'package:darkvibex/room/seat_layout.dart';
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

  test('36 to 42 seats use compact six-row layout', () {
    expect(rowsForSeatCount(36), 6);
    expect(rowsForSeatCount(42), 6);

    final layout = SeatLayoutSpec.forCount(42);
    expect(layout.rows, 6);
    expect(layout.columns, 7);
    expect(layout.rowLengths, <int>[7, 7, 7, 7, 7, 7]);
    expect(layout.seatDiameter(352), inInclusiveRange(28, 36));
  });
}
