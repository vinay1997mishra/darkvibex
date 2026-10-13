import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room audience strip, lamp and seat invites stay Tinni-style', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains("_RoomLampButton(onTap: _openLamp)"));
    expect(source, contains("onTap: _openRoomMembers"));
    expect(source, contains("room-member-invite-"));
    expect(source, contains("room-seat-invite-"));
    expect(source, contains("Search ID in this room"));
    expect(source, contains("Invite an in-room off-seat user/admin to Seat No."));
    expect(source, contains("action: 'seat_invite'"));
    expect(source, contains("action: 'seat_invite_respond'"));
    expect(source, contains("title: const Text('Seat Invite')"));
    expect(source, isNot(contains("'Aladdin\\'s\\nLamp'")));
  });
}
