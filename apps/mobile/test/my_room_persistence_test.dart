import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('My room survives refreshes and repeated create taps', () {
    final app = File('lib/app/app_state.dart').readAsStringSync();
    final home = File('lib/screens/home_shell.dart').readAsStringSync();
    final api = File('lib/infra/backend_api.dart').readAsStringSync();

    expect(app, contains('darkvibex.owned_room.\$userId'));
    expect(app, contains('_readOwnedRoomCache'));
    expect(app, contains('_writeOwnedRoomCache'));
    expect(app, contains('final remoteRooms = await backend.listRooms();'));
    expect(app, contains('if (remoteRooms != null)'));
    expect(api, contains('Future<List<Map<String, dynamic>>?> listRooms()'));
    expect(api, contains("if (value?['ok'] != true) return null;'));
    expect(api, contains('if (rows is! List) return null;'));
    expect(app, contains('existing.ownerUserId == userId'));
    expect(home, contains('room.ownerUserId == state.userId'));
    expect(home, contains('_openRoom(room);'));
  });
}
