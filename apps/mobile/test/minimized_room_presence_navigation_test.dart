import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minimized room uses global draggable DP bubble', () {
    final app = File('lib/app/darkvibex_app.dart').readAsStringSync();
    final home = File('lib/screens/home_shell.dart').readAsStringSync();
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(app, contains('MinimizedRoomBubble('));
    expect(home, contains("Key('mini-room-bubble')"));
    expect(home, contains('onPanUpdate:'));
    expect(home, contains("fileUrl(room.avatarKey!)"));
    expect(room, contains('widget.state.showMinimizedRoom('));
    expect(room, contains('navigator.popUntil((route) => route == roomRoute)'));
  });

  test('public profile Room badge opens the active room', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(profile, contains("Key('public-profile-room-online')"));
    expect(profile, contains('onTap: _openCurrentRoom'));
    expect(profile, contains('Future<void> _openCurrentRoom()'));
    expect(profile, contains('builder: (_) => RoomScreen('));
  });
}
