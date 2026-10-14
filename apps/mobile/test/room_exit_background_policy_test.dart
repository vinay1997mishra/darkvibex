import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room Exit removes presence and tears down active room runtime', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(room, contains('Future<void> _leaveServerMembership()'));
    expect(room, contains('await widget.state.backend.leaveRoom('));
    expect(room, contains('Future<void> _disconnectRoomRuntime()'));
    expect(room, contains('await current?.setMicPublished(false)'));
    expect(room, contains('await current.setCameraPublished(false)'));
    expect(room, contains('await current?.leave()'));
    expect(room, contains('await roomForegroundService.stop()'));

    final leaveStart = room.indexOf('Future<void> _leaveRoom()');
    final leaveEnd = room.indexOf('Future<void> _openGames()', leaveStart);
    expect(leaveStart, greaterThanOrEqualTo(0));
    expect(leaveEnd, greaterThan(leaveStart));
    final leaveBlock = room.substring(leaveStart, leaveEnd);
    expect(leaveBlock, contains('await _leaveServerMembership()'));
    expect(leaveBlock, contains('await _disconnectRoomRuntime()'));
  });

  test('Android room foreground service cannot outlive a closed app task', () {
    final service = File(
      'android/app/src/main/kotlin/com/darkvibex/app/'
      'DarkVibeXRoomForegroundService.kt',
    ).readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(service, contains('return START_NOT_STICKY'));
    expect(service, contains('override fun onTaskRemoved'));
    expect(service, contains('stopSelf()'));
    expect(manifest, contains('android:stopWithTask="true"'));
  });

  test('message push uses notification-only FCM receiver, not room service', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final messaging = File(
      'android/app/src/main/kotlin/com/darkvibex/app/'
      'DarkVibeXMessagingService.kt',
    ).readAsStringSync();

    expect(manifest, contains('com.google.firebase.MESSAGING_EVENT'));
    expect(messaging, contains('FirebaseMessagingService'));
    expect(messaging, contains('type"] != "direct_message"'));
    expect(messaging, contains('NotificationManager'));
  });
}
