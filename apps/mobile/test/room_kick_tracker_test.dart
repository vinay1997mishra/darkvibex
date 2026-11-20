import 'package:flutter_test/flutter_test.dart';

import '../lib/utils/room_kick_tracker.dart';

void main() {
  test('one failed fetch is transient, two in a row means kicked', () {
    final tracker = RoomKickTracker();
    expect(tracker.noteFetch(ok: false), isFalse);
    expect(tracker.noteFetch(ok: false), isTrue);
  });

  test('a successful fetch resets the failure count', () {
    final tracker = RoomKickTracker();
    expect(tracker.noteFetch(ok: false), isFalse);
    expect(tracker.noteFetch(ok: true), isFalse);
    expect(tracker.noteFetch(ok: false), isFalse);
    expect(tracker.noteFetch(ok: false), isTrue);
  });

  test('successful fetches never report a kick', () {
    final tracker = RoomKickTracker();
    for (var i = 0; i < 5; i++) {
      expect(tracker.noteFetch(ok: true), isFalse);
    }
  });

  test('after a kick the tracker can fire again', () {
    final tracker = RoomKickTracker();
    expect(tracker.noteFetch(ok: false), isFalse);
    expect(tracker.noteFetch(ok: false), isTrue);
    expect(tracker.noteFetch(ok: false), isFalse);
    expect(tracker.noteFetch(ok: false), isTrue);
  });
}
