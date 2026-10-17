import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('My room survives refreshes and repeated create taps', () {
    final app = File('lib/app/app_state.dart').readAsStringSync();
    final home = File('lib/screens/home_shell.dart').readAsStringSync();

    expect(app, contains('darkvibex.owned_room.\$userId'));
    expect(app, contains('_readOwnedRoomCache'));
    expect(app, contains('_writeOwnedRoomCache'));
    expect(app, contains('_replaceRoomsFromRemote(await backend.listRooms())'));
    expect(app, contains('existing.ownerUserId == userId'));
    expect(home, contains('room.ownerUserId == state.userId'));
    expect(home, contains('_openRoom(room);'));
  });
}
