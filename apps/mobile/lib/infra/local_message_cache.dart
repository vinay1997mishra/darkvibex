import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local message cache (Vinay, 2026-11-22: "App se delete nhi hone
/// chahiye") — messages are kept in the app forever, in
/// SharedPreferences, keyed per conversation / room. The server only
/// keeps the last 100 messages per thread/room past 45 days, so the
/// local cache is what lets the user scroll back further.
///
/// Merging is by message id (the server row wins on conflict); rows
/// without an id merge on a content key. Nothing here ever prunes by
/// age — the old VIP retention-days prune in the DM screen was
/// removed for the same reason: it deleted messages from the app.
///
/// Only rows with a real server id are persisted — the room welcome
/// pseudo-message and other local placeholders are display-only and
/// are rebuilt on every join.
class LocalMessageCache {
  static String dmKey(String userId, String otherUserId) =>
      'dvx_messages_${userId}_$otherUserId';
  static String roomKey(String roomId) => 'dvx_room_messages_$roomId';
  static String gameRoomKey(String roomId) =>
      'dvx_game_room_messages_$roomId';

  /// Merges cached + fresh rows: fresh wins on id conflict, result
  /// sorted oldest-first by created_at. Rows without an id dedup on
  /// a content key.
  static List<Map<String, dynamic>> merge(
    List<Map<String, dynamic>> cached,
    List<Map<String, dynamic>> fresh,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in [...cached, ...fresh]) {
      byId[messageKey(row)] = row;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) => _createdAt(a).compareTo(_createdAt(b)));
    return merged;
  }

  static String messageKey(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id != null && id.isNotEmpty) return 'id:$id';
    return 'c:${row['sender_user_id']}|${row['user_id']}|${row['created_at']}|${row['text']}|${row['image_key']}';
  }

  static int _createdAt(Map<String, dynamic> row) =>
      int.tryParse(row['created_at']?.toString() ?? '') ?? 0;

  /// Rows worth persisting: only real server messages (with an id).
  static List<Map<String, dynamic>> persistable(
    List<Map<String, dynamic>> messages,
  ) =>
      messages
          .where((row) =>
              (row['id']?.toString() ?? '').isNotEmpty)
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  static Future<List<Map<String, dynamic>>> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> save(
    String key,
    List<Map<String, dynamic>> messages,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(persistable(messages)));
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
