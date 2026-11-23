// Separate room polls (combined room-state removed 2026-11-23, Vinay:
// "combined API hta de, har jagah se"): members + messages + controls +
// gift events + settings + gift ranking each call their own endpoint
// every 3s on ONE timer, so one failing area never blanks the whole
// room. Any room setting change (room DP, background, name, lock, room
// chat off) still shows to everyone within 3s. Poll-slowdown was
// rejected by Vinay ("room me msg turant dikhna chahiye"), so the
// refresh must NOT get slower.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the backend exposes the separate room calls, no combined state call', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, isNot(contains('roomStateOrNull')));
    expect(api, isNot(contains('/state')));
    expect(api, contains('Future<List<Map<String, dynamic>>?> roomMembersOrNull('));
    expect(api, contains("required String roomId,"));
    expect(api, contains('/members'));
    expect(api, contains('/messages'));
    expect(api, contains('/controls'));
    expect(api, contains('/gift-events?after='));
    expect(api, contains('/gift-ranking'));
  });

  test('the members call keeps the kick-safe null contract', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    final start = api.indexOf('/// Members list, or null when the request failed');
    expect(start, isNot(-1));
    final method = api.substring(start, api.indexOf('/// Top-of-room banner feed', start));
    expect(method, contains('room_membership_required'));
    expect(method, contains('null here is the kick signal'));
    // A failed call returns null; it must NOT pass returnErrorBody,
    // or a 403 body would come back as a map instead of null.
    expect(method, isNot(contains('returnErrorBody')));
  });

  test('the room screen polls with ONE 3s timer, gated on the app being active', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Timer? roomPollTimer;'));
    expect(source, contains('roomPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {'));
    expect(source, contains('if (appIsActive()) _loadRoomSeparate();'));
    expect(source, contains('roomPollTimer?.cancel();'));
    expect(source, isNot(contains('_loadRoomState')));
    expect(source, isNot(contains('roomStateTimer')));
  });

  test('the four separate polling timers are gone', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, isNot(contains('memberRefreshTimer')));
    expect(source, isNot(contains('messageRefreshTimer')));
    expect(source, isNot(contains('controlsRefreshTimer')));
    expect(source, isNot(contains('const Duration(seconds: 8)')));
    expect(source, isNot(contains('const Duration(seconds: 20)')));
  });

  test('the 60s settings timer is gone — settings ride the 3s separate polls', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, isNot(contains('settingsRefreshTimer')));
    expect(source, isNot(contains('const Duration(seconds: 60)')));
    expect(source, isNot(contains('Settings change rarely, so they keep')));
  });

  test('the separate poll fires all six loaders', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('void _loadRoomSeparate()');
    expect(start, isNot(-1));
    final end = source.indexOf('Future<void> _applyGlobalBanners()', start);
    final loader = source.substring(start, end);
    expect(loader, contains('unawaited(_loadRoomMembers());'));
    expect(loader, contains('unawaited(_loadRoomMessages());'));
    expect(loader, contains('unawaited(_loadRoomControls());'));
    expect(loader, contains('unawaited(_loadRoomGiftEvents());'));
    expect(loader, contains('unawaited(_loadRoomSettings());'));
    expect(loader, contains('unawaited(_loadRoomGiftRanking());'));
    expect(loader, contains('unawaited(_applyGlobalBanners());'));
  });

  test('the settings loader stays for entry and post-action refreshes', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Future<void> _loadRoomSettings() async {'));
    expect(source, contains('unawaited(_loadRoomSettings());'));
    expect(source, contains('await _loadRoomSettings();'));
    expect(source, contains('void _applyRoomSettings('));
  });

  test('the settings applier covers the room settings fields', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('void _applyRoomSettings(');
    expect(start, isNot(-1));
    final end = source.indexOf('Future<void> _openRoomSettings()', start);
    final applier = source.substring(start, end);
    expect(applier, contains("settings['name']"));
    expect(applier, contains("settings['seat_count']"));
    expect(applier, contains("settings['locked']"));
    expect(applier, contains("settings['theme_asset_key']"));
    expect(applier, contains("settings['avatar_key']"));
    expect(applier, contains("settings['announcement']"));
    expect(applier, contains("settings['welcome_image_key']"));
    expect(applier, contains("settings['group_pk_enabled']"));
    expect(applier, contains('roomAvatarKey = avatarKey;'));
  });

  test('the members loader preserves kick detection exactly', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _loadRoomMembers()');
    expect(start, isNot(-1));
    final end = source.indexOf('/// Applies a members list', start);
    final loader = source.substring(start, end);
    // Failure -> null -> one transient failure, two in a row confirm
    // with the server instead of assuming a kick: a network drop, a
    // 500 or an exhausted free tier fail the poll exactly like a kick,
    // and a bare failure must never throw the user out (Vinay,
    // 2026-11-22).
    expect(loader, contains('if (rows == null) {'));
    expect(loader, contains('if (_kickTracker.noteFetch(ok: false)) {'));
    expect(loader, contains('await _handleFailedRoomFetch();'));
    expect(loader, isNot(contains('await _handleKickedFromRoom();')));
    expect(loader, contains('_kickTracker.noteFetch(ok: true);'));
    expect(loader, contains('await _applyRoomMembers(rows);'));
  });

  test('a failed fetch confirms the removal with the server before exiting', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> _handleFailedRoomFetch()');
    expect(start, isNot(-1));
    final end = source.indexOf('/// I was kicked out of the room', start);
    final helper = source.substring(start, end);
    // Kick marker first; a silent re-join only when there is no
    // marker; the decision lives in decideRoomRemoval.
    expect(helper, contains('roomKickStatus('));
    expect(helper, contains('joinRoomResult('));
    expect(helper, contains('decideRoomRemoval(kicked: kicked, joined: joined)'));
    expect(helper, contains('RoomRemovalAction.exitRemoved'));
    expect(helper, contains('RoomRemovalAction.exitSilently'));
    // Overlapping confirmations are guarded: the 3s poll keeps firing
    // while one runs.
    expect(helper, contains('_confirmingRemoval'));
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

  test('top bar shows the gold lamp image, not the painted lamp', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, isNot(contains('_MiniLampPainter')));
    expect(source, isNot(contains('CustomPaint(painter:')));
    expect(source, contains("'assets/images/gold_lamp.png'"));
    expect(source, contains("key: const Key('room-header-gold-lamp')"));
    expect(
      File('assets/images/gold_lamp.png').existsSync(),
      isTrue,
    );
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/images/gold_lamp.png'),
    );
  });

  test('top bar shows the gold trophy + coins, tap opens ranking', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf("key: const Key('room-header-total')");
    expect(start, isNot(-1));
    final end = source.indexOf("// Month's top-gifter ID pill removed", start);
    final pill = source.substring(start, end);
    // Real gold trophy image (same asset as the rocket page), not the
    // painted emoji_events icon; coins total beside it, no 'Ranking'
    // text (Vinay, 2026-11-23).
    expect(pill, contains("'assets/images/gold_trophy.png'"));
    expect(pill, contains("key: const Key('room-header-gold-trophy')"));
    expect(pill, contains('_compactRoomCoins(roomGiftLifetimeTotal)'));
    expect(pill, contains('onTap: _showRoomGiftRanking,'));
    expect(pill, isNot(contains("'Ranking'")));
    expect(pill, isNot(contains('emoji_events_rounded')));
    expect(pill, isNot(contains('monetization_on_rounded')));
    // The month-top-gifter ID pill is gone permanently (Vinay, 2026-11-23:
    // "hamesha ke liye hata de") — no top-gifter pill anywhere in the room.
    expect(source, isNot(contains("room-header-top-gifter")));
  });

  test('seat join lets the server decide the lock and moves seats directly', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _handleUserSeatTap(');
    expect(start, isNot(-1));
    final end = source.indexOf('Future<void> _tapSeat(', start);
    final tap = source.substring(start, end);
    // No client-side lock pre-block: the owner/admin must be able to
    // join his own locked seat — the server 409s seat_locked only for
    // non-moderators, and the app's own admin flag can lag the server.
    expect(tap, isNot(contains('lockedSeats.contains(seat)')));
    expect(tap, isNot(contains('Leave your current seat first')));
    // Moving seats leaves the current seat first, then takes the new
    // one — same as the owner/admin Take Seat tile.
    expect(tap, contains('if (mySeat != null && mySeat != seat) {'));
    expect(tap, contains('final left = await _leaveMySeat();'));
    expect(tap, contains('await _takeSeatDirect(seat);'));
    // The server's 409 still surfaces as 'This seat is locked.'
    expect(source, contains("error == 'seat_locked'"));
  });

  test('the old endpoints stay on the backend', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, contains('/members'));
    expect(api, contains('/messages'));
    expect(api, contains('/controls'));
    expect(api, contains('/gift-events?after='));
    expect(api, contains('Future<List<Map<String, dynamic>>?> roomMembersOrNull('));
    expect(api, contains('Future<Map<String, dynamic>?> roomGiftRanking('));
    expect(api, contains("String? period,"));
  });

  test('room chat welcome goes by the room owner: owner DP + name, the old DarkVibeX way is permanently gone (Vinay, 2026-11-23)',
      () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    // The old way is gone: no DarkVibeX welcome row, no logo DP, no
    // dragon frame on it, no welcomeFrameUrl plumbing.
    expect(source, isNot(contains("'display_name': 'DarkVibeX'")));
    expect(
      source,
      isNot(contains(
          "'avatar_asset': 'assets/branding/darkvibex_launcher.webp'")),
    );
    expect(
      source,
      isNot(contains("'frame_asset_url': vipFrameStillUrlForVipLevel(18)")),
    );
    expect(source, isNot(contains('welcomeFrameUrl')));
    // The welcome row is built from the room owner when the members
    // load: the owner's DP + VIP level, the owner's name (room's
    // ownerName as the fallback), inserted at the top of the chat.
    expect(source, contains('_applyWelcomeOwner()'));
    expect(
      source,
      contains(
          "member['user_id']?.toString() == widget.room.ownerUserId"),
    );
    expect(source, contains("'avatar_key': avatarKey"));
    expect(source, contains("'active_vip_level': vipLevel"));
    expect(source, contains('chat.insert(0, row)'));
    // The welcome row is identified by its text alone now (its sender
    // is the owner, not DarkVibeX), so it still vanishes once real
    // messages arrive.
    expect(source, contains("row['text'] == 'Welcome to the room 👋'"));
    expect(source, isNot(contains("row['display_name'] == 'DarkVibeX'")));
    // The sender header renders a bundled asset DP when one is given.
    final header =
        File('lib/widgets/room_chat_sender_header.dart').readAsStringSync();
    expect(header, contains('avatarAsset'));
    expect(header, contains('Image.asset('));
    // A just-sent message echoes with the sender's own DP + VIP level
    // at once, instead of the grey avatar until the next poll.
    expect(source, contains("message['avatar_key'] ??= widget.state.avatarKey"));
    expect(source, contains("message['active_vip_level'] ??= widget.state.vipLevel"));
    expect(source, contains("'avatar_key': widget.state.avatarKey"));
    expect(source, contains("'active_vip_level': widget.state.vipLevel"));
  });
}
