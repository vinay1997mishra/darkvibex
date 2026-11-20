// Combined room-state API (Vinay, 2026-11-20): one 3s poll carrying
// members + messages + controls + gift events, instead of four separate
// timers — same speed (members were 4s, messages 8s, controls 20s),
// fewer Workers requests. Poll-slowdown was rejected by Vinay ("room me
// msg turant dikhna chahiye"), so the refresh must NOT get slower.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the backend exposes the combined state call', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, contains('Future<Map<String, dynamic>?> roomStateOrNull('));
    expect(api, contains("required String roomId,"));
    expect(api, contains('/state'));
    expect(api, contains(r'after=$after&after_id='));
    expect(api, contains('if (value == null) return null;'));
  });

  test('the state call keeps the kick-safe null contract', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    final start = api.indexOf('/// Combined room state (members + messages');
    expect(start, isNot(-1));
    final method = api.substring(start, api.indexOf('/// Whether the server recorded', start));
    expect(method, contains('room_membership_required'));
    expect(method, contains('null here is the kick signal'));
    // A failed call returns null; it must NOT pass returnErrorBody,
    // or a 403 body would come back as a map instead of null.
    expect(method, isNot(contains('returnErrorBody')));
  });

  test('the room screen polls with ONE 3s timer, gated on the app being active', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Timer? roomStateTimer;'));
    expect(source, contains('roomStateTimer = Timer.periodic(const Duration(seconds: 3), (_) {'));
    expect(source, contains('if (appIsActive()) unawaited(_loadRoomState());'));
    expect(source, contains('roomStateTimer?.cancel();'));
  });

  test('the four separate polling timers are gone', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, isNot(contains('memberRefreshTimer')));
    expect(source, isNot(contains('messageRefreshTimer')));
    expect(source, isNot(contains('controlsRefreshTimer')));
    expect(source, isNot(contains('const Duration(seconds: 8)')));
    expect(source, isNot(contains('const Duration(seconds: 20)')));
  });

  test('the settings 60s timer stays separate', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Timer? settingsRefreshTimer;'));
    expect(source, contains('settingsRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {'));
    expect(source, contains('if (appIsActive()) unawaited(_loadRoomSettings());'));
  });

  test('the state loader applies all four sections', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _loadRoomState()');
    expect(start, isNot(-1));
    final end = source.indexOf('void didChangeAppLifecycleState', start);
    final loader = source.substring(start, end);
    expect(loader, contains('roomStateOrNull('));
    expect(loader, contains('after: _giftEventCursorMs,'));
    expect(loader, contains('afterId: _giftEventCursorId,'));
    expect(loader, contains('_applyRoomMembers('));
    expect(loader, contains('_applyRoomMessages('));
    expect(loader, contains('_applyRoomControls('));
    expect(loader, contains('_applyRoomGiftEvents('));
  });

  test('the state loader preserves kick detection exactly', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _loadRoomState()');
    final end = source.indexOf('void didChangeAppLifecycleState', start);
    final loader = source.substring(start, end);
    // Failure -> null -> one transient failure, two in a row = kicked.
    expect(loader, contains('if (state == null) {'));
    expect(loader, contains('if (_kickTracker.noteFetch(ok: false)) {'));
    expect(loader, contains('await _handleKickedFromRoom();'));
    expect(loader, contains('_kickTracker.noteFetch(ok: true);'));
    // An empty members list is a valid payload, not a kick: it is
    // applied when present, never checked for emptiness as a signal.
    expect(loader, contains('if (members is List) {'));
    expect(loader, isNot(contains('members.isEmpty')));
  });

  test('the old loaders stay for immediate post-action refreshes', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Future<void> _loadRoomMembers() async {'));
    expect(source, contains('Future<void> _loadRoomMessages() async {'));
    expect(source, contains('Future<void> _loadRoomGiftEvents() async {'));
    expect(source, contains('Future<void> _loadRoomControls() async {'));
    expect(source, contains('Future<void> _applyRoomMembers('));
    expect(source, contains('void _applyRoomMessages('));
    expect(source, contains('void _applyRoomGiftEvents('));
    expect(source, contains('void _applyRoomControls('));
  });

  test('the old endpoints stay on the backend', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, contains('/members'));
    expect(api, contains('/messages'));
    expect(api, contains('/controls'));
    expect(api, contains('/gift-events?after='));
    expect(api, contains('Future<List<Map<String, dynamic>>?> roomMembersOrNull('));
  });
}
