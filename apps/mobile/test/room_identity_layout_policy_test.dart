import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room header and DP menu keep requested controls clean', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, isNot(contains('keyboard_arrow_down_rounded')));
    expect(source, contains('automaticallyImplyLeading: false'));
    expect(source, contains('widget.room.roomNumber'));

    final menuStart = source.indexOf('Future<void> _openRoomMenu()');
    final menuEnd = source.indexOf('Future<void> _shareRoom()', menuStart);
    expect(menuStart, greaterThanOrEqualTo(0));
    expect(menuEnd, greaterThan(menuStart));
    final menu = source.substring(menuStart, menuEnd);
    expect(menu, isNot(contains("room-share-menu")));
    expect(menu, isNot(contains("title: const Text('Share room')")));
    expect(menu, isNot(contains("title: const Text('Leave room')")));
  });

  test('official notice keeps only the legal body text', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final noticeStart = source.indexOf("key: const Key('official-announcement')");
    final noticeEnd = source.indexOf("key: const Key('room-owner-greeting')", noticeStart);
    expect(noticeStart, greaterThanOrEqualTo(0));
    expect(noticeEnd, greaterThan(noticeStart));
    final notice = source.substring(noticeStart, noticeEnd);

    expect(notice, contains('Be respectful. No harassment'));
    expect(notice, isNot(contains('Official Announcement')));
    expect(notice, isNot(contains("Text('Terms')")));
  });

  test('profile and room UI use stable seven-digit public IDs', () {
    final appState = File('lib/app/app_state.dart').readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final personal =
        File('lib/screens/personal_profile_screen.dart').readAsStringSync();

    expect(appState, contains("String publicId = '9100001'"));
    expect(appState, contains('String get roomNumber'));
    expect(appState, contains("row['display_id']"));
    expect(profile, contains('state.publicId'));
    expect(personal, contains('widget.state.publicId'));
  });

  test('36 to 42 seats use dense spacing while chat remains present', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('compactSeats = roomSeatCount >= 36'));
    expect(source, contains("key: const Key('room-chat-list')"));
    expect(source, contains('compactSeats ? 2 : (diameter < 48 ? 6 : 10)'));
  });
}
