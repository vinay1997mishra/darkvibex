import 'package:darkvibex/infra/local_message_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local message cache (Vinay, 2026-11-22: "App se delete nhi hone
// chahiye") — messages are kept in the app forever; the server only
// keeps the last 100 per thread/room past 45 days.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> msg(String id, int createdAt, [String text = 'hi']) =>
      <String, dynamic>{
        'id': id,
        'sender_user_id': 'a',
        'receiver_user_id': 'b',
        'text': text,
        'created_at': createdAt,
      };

  test('merge keeps cached old messages and lets server rows win', () {
    final cached = [msg('m1', 100), msg('m2', 200)];
    final fresh = [
      msg('m2', 200, 'edited'),
      msg('m3', 300),
    ];
    final merged = LocalMessageCache.merge(cached, fresh);
    expect(merged.map((row) => row['id']), ['m1', 'm2', 'm3']);
    expect(merged[1]['text'], 'edited');
  });

  test('merge sorts oldest-first and dedups id-less rows by content', () {
    final cached = [
      <String, dynamic>{
        'sender_user_id': 'a',
        'text': 'hello',
        'created_at': 50,
      },
    ];
    final fresh = [
      <String, dynamic>{
        'sender_user_id': 'a',
        'text': 'hello',
        'created_at': 50,
      },
      msg('m9', 10),
    ];
    final merged = LocalMessageCache.merge(cached, fresh);
    expect(merged.length, 2);
    expect(merged.first['id'], 'm9');
  });

  test('persistable keeps only rows with a server id', () {
    final rows = [
      msg('m1', 100),
      <String, dynamic>{'display_name': 'DarkVibeX', 'text': 'Welcome to the room 👋'},
    ];
    final kept = LocalMessageCache.persistable(rows);
    expect(kept.map((row) => row['id']), ['m1']);
  });

  test('keys are stable per conversation and room', () {
    expect(LocalMessageCache.dmKey('u1', 'u2'), 'dvx_messages_u1_u2');
    expect(LocalMessageCache.roomKey('r1'), 'dvx_room_messages_r1');
    expect(LocalMessageCache.gameRoomKey('g1'), 'dvx_game_room_messages_g1');
  });

  test('save + load round-trips messages, clear removes them', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    const key = 'dvx_messages_u1_u2';
    await LocalMessageCache.save(key, [msg('m1', 100), msg('m2', 200)]);
    final loaded = await LocalMessageCache.load(key);
    expect(loaded.map((row) => row['id']), ['m1', 'm2']);
    await LocalMessageCache.clear(key);
    expect(await LocalMessageCache.load(key), isEmpty);
  });

  test('load returns empty on corrupt stored JSON', () async {
    SharedPreferences.setMockInitialValues(
      const <String, Object>{'dvx_messages_u1_u2': 'not json {'},
    );
    expect(
      await LocalMessageCache.load('dvx_messages_u1_u2'),
      isEmpty,
    );
  });
}
