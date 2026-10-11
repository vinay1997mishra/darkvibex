import 'dart:convert';
import 'dart:io';

class BackendApi {
  const BackendApi();

  static const String origin = String.fromEnvironment(
    'DARKVIBEX_API_ORIGIN',
    defaultValue: 'https://darkvibex-api.mishrajii7991.workers.dev',
  );

  bool get configured => origin.trim().isNotEmpty;

  Future<Map<String, dynamic>?> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (!configured) return null;
    final client = HttpClient();
    try {
      final uri = Uri.parse('$origin$path');
      final request = switch (method) {
        'GET' => await client.getUrl(uri),
        'POST' => await client.postUrl(uri),
        'PUT' => await client.putUrl(uri),
        _ => await client.openUrl(method, uri),
      };
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (text.trim().isEmpty) {
        return response.statusCode >= 200 && response.statusCode < 300
            ? <String, dynamic>{'ok': true}
            : null;
      }
      final value = jsonDecode(text);
      if (value is! Map<String, dynamic>) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return value;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> health() =>
      _json('GET', '/health');

  Future<Map<String, dynamic>?> googleAuthConfig() =>
      _json('GET', '/api/auth/config');

  Future<Map<String, dynamic>?> startGoogleSession({
    required String idToken,
  }) =>
      _json(
        'POST',
        '/api/session/google',
        body: <String, dynamic>{
          'id_token': idToken,
        },
      );

  Future<Map<String, dynamic>?> startGuestSession({
    required String userId,
    required String displayName,
  }) =>
      _json(
        'POST',
        '/api/session/guest',
        body: <String, dynamic>{
          'user_id': userId,
          'display_name': displayName,
        },
      );

  Future<List<Map<String, dynamic>>> listRooms() async {
    final value = await _json('GET', '/api/rooms');
    final rows = value?['rooms'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<String?> createRoom({
    required String ownerUserId,
    required String ownerName,
    required String name,
    required int seatCount,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms',
      body: <String, dynamic>{
        'owner_user_id': ownerUserId,
        'owner_name': ownerName,
        'name': name,
        'seat_count': seatCount,
      },
    );
    return value?['room_id']?.toString();
  }

  Future<bool> joinRoom({
    required String roomId,
    required String userId,
    required String displayName,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/$roomId/join',
      body: <String, dynamic>{
        'user_id': userId,
        'display_name': displayName,
      },
    );
    return value?['ok'] == true;
  }

  Future<bool> setSeat({
    required String roomId,
    required String userId,
    required int? seatIndex,
    required bool micMuted,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/$roomId/seat',
      body: <String, dynamic>{
        'user_id': userId,
        'seat_index': seatIndex,
        'mic_muted': micMuted,
      },
    );
    return value?['ok'] == true;
  }

  Future<bool> sendRoomMessage({
    required String roomId,
    required String userId,
    required String text,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/$roomId/messages',
      body: <String, dynamic>{
        'user_id': userId,
        'text': text,
      },
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> inbox({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/messages/inbox?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['inbox'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> messageThread({
    required String userId,
    required String otherUserId,
  }) async {
    final value = await _json(
      'GET',
      '/api/messages/thread?user_id=${Uri.encodeQueryComponent(userId)}&other_user_id=${Uri.encodeQueryComponent(otherUserId)}',
    );
    final rows = value?['messages'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<bool> sendDirectMessage({
    required String senderUserId,
    required String receiverUserId,
    required String text,
  }) async {
    final value = await _json(
      'POST',
      '/api/messages/send',
      body: <String, dynamic>{
        'sender_user_id': senderUserId,
        'receiver_user_id': receiverUserId,
        'text': text,
      },
    );
    return value?['ok'] == true;
  }

  Future<Map<String, dynamic>?> wallet({
    required String userId,
  }) =>
      _json('GET', '/api/wallet/$userId');

  Future<Map<String, dynamic>?> sendGift({
    required String roomId,
    required String senderUserId,
    required String receiverUserId,
    required String giftId,
    required int coinCost,
  }) =>
      _json(
        'POST',
        '/api/gifts/send',
        body: <String, dynamic>{
          'room_id': roomId,
          'sender_user_id': senderUserId,
          'receiver_user_id': receiverUserId,
          'gift_id': giftId,
          'coin_cost': coinCost,
        },
      );

  Future<Map<String, dynamic>?> vipStatus({
    required String userId,
  }) =>
      _json('GET', '/api/vip/${Uri.encodeComponent(userId)}');

  Future<Map<String, dynamic>?> updateVipPreference({
    required String userId,
    required String key,
    required bool enabled,
  }) =>
      _json(
        'POST',
        '/api/vip/${Uri.encodeComponent(userId)}/preferences',
        body: <String, dynamic>{
          'key': key,
          'enabled': enabled,
        },
      );

  Future<Map<String, dynamic>?> changeVipUniqueId({
    required String userId,
    required String customId,
  }) =>
      _json(
        'POST',
        '/api/vip/${Uri.encodeComponent(userId)}/unique-id',
        body: <String, dynamic>{
          'custom_id': customId,
        },
      );

  Future<Map<String, dynamic>?> coinSellerTransfer({
    required String sellerUserId,
    required String receiverUserId,
    required int coins,
  }) =>
      _json(
        'POST',
        '/api/wallet/coin-seller-transfer',
        body: <String, dynamic>{
          'seller_user_id': sellerUserId,
          'receiver_user_id': receiverUserId,
          'coins': coins,
        },
      );

  Future<Map<String, dynamic>?> fruitPartyBet({
    required String userId,
    required int stake,
  }) =>
      _json(
        'POST',
        '/api/games/fruit-party/bet',
        body: <String, dynamic>{
          'user_id': userId,
          'stake': stake,
        },
      );
}
