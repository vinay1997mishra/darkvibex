// Agora audit fixes 2026-11-22 — source assertions.
// The token endpoint now mints least-privilege tokens (join-only for
// seatless listeners, audio-only for direct calls), so the app must
// send x-device-id on the token fetch, re-mint its token when its
// seat changes, and the incoming-call dialog must end when the
// server's 45s ring window ends.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('token fetch sends x-device-id so the server device-ban check runs', () {
    final source = File('lib/infra/agora_rtc.dart').readAsStringSync();
    expect(source, contains('final String deviceKey;'));
    expect(source, contains("this.deviceKey = '',"));
    expect(source, contains("request.headers.set('x-device-id', device);"));
    // The token fetch is the one place that builds its own request
    // (it bypasses BackendApi._json, which sets the header itself).
    expect(source, contains('deviceKey.trim()'));
  });

  test('the device key reaches the adapter from every voice entry point', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room, contains("deviceKey: BackendApi.deviceKey ?? '',"));
    final gameRoom = File('lib/screens/game_room_screen.dart').readAsStringSync();
    expect(gameRoom, contains("deviceKey: BackendApi.deviceKey ?? '',"));
    final call = File('lib/screens/direct_call_screen.dart').readAsStringSync();
    expect(call, contains("deviceKey: BackendApi.deviceKey ?? '',"));
  });

  test('the voice adapter can re-mint its token on demand', () {
    final realtime = File('lib/infra/realtime.dart').readAsStringSync();
    expect(realtime, contains('Future<void> refreshToken();'));
    expect(realtime, contains('Future<void> refreshToken() async {}'));
    final adapter = File('lib/infra/agora_rtc.dart').readAsStringSync();
    expect(adapter, contains('Future<void> refreshToken() => _renewToken();'));
  });

  test('a seat change re-mints the voice token (privileges follow the seat)', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('if (wasOnSeat != (mySeat != null)) {'));
    expect(source, contains('unawaited(rtc?.refreshToken());'));
    // The refresh sits in _applyRoomMembers, the one choke point for
    // every seat change — direct tap AND an approved seat request
    // arriving through the members poll.
    expect(source, contains('final wasOnSeat = mySeat != null;'));
  });

  test('the incoming-call dialog ends when the server ring window ends', () {
    final source = File('lib/screens/messages_screen.dart').readAsStringSync();
    // Remaining ring time comes from the call's created_at (the
    // server expires ringing calls after 45s), not a flat timer.
    expect(source, contains("call['created_at']"));
    expect(source, contains('(45000 - elapsedMs).clamp(5000, 45000)'));
    expect(source, contains('Timer(Duration(milliseconds: remainingMs), () {'));
    expect(source, contains('Navigator.pop(dialogContext, false);'));
    expect(source, contains('ringTimer?.cancel();'));
  });
}
