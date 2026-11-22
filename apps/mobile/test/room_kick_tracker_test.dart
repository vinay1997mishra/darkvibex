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

  test('decideRoomRemoval: a failed kick-status check means stay', () {
    // The server could not be reached at all — nothing is known, so a
    // failed poll must never throw the user out (Vinay, 2026-11-22).
    expect(
      decideRoomRemoval(kicked: null, joined: null),
      RoomRemovalAction.stay,
    );
    expect(
      decideRoomRemoval(kicked: null, joined: {'ok': true}),
      RoomRemovalAction.stay,
    );
  });

  test('decideRoomRemoval: a real kick exits with the removed dialog', () {
    expect(
      decideRoomRemoval(kicked: true, joined: null),
      RoomRemovalAction.exitRemoved,
    );
  });

  test('decideRoomRemoval: no kick marker + re-join ok means stay', () {
    expect(
      decideRoomRemoval(kicked: false, joined: {'ok': true}),
      RoomRemovalAction.stay,
    );
  });

  test('decideRoomRemoval: no kick marker + join call failed means stay', () {
    expect(
      decideRoomRemoval(kicked: false, joined: null),
      RoomRemovalAction.stay,
    );
  });

  test('decideRoomRemoval: a ban (re-join room_blocked) exits removed', () {
    expect(
      decideRoomRemoval(
        kicked: false,
        joined: {'ok': false, 'error': 'room_blocked'},
      ),
      RoomRemovalAction.exitRemoved,
    );
  });

  test('decideRoomRemoval: a deleted room exits silently', () {
    expect(
      decideRoomRemoval(
        kicked: false,
        joined: {'ok': false, 'error': 'room_not_found'},
      ),
      RoomRemovalAction.exitSilently,
    );
  });

  test('decideRoomRemoval: other re-join failures mean stay', () {
    expect(
      decideRoomRemoval(
        kicked: false,
        joined: {'ok': false, 'error': 'room_password_required'},
      ),
      RoomRemovalAction.stay,
    );
    expect(
      decideRoomRemoval(
        kicked: false,
        joined: {'ok': false, 'error': 'room_country_mismatch'},
      ),
      RoomRemovalAction.stay,
    );
  });
}
