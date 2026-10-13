import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class BackendApi {
  const BackendApi();

  static String? sessionToken;

  static const String origin = String.fromEnvironment(
    'DARKVIBEX_API_ORIGIN',
    defaultValue: 'https://darkvibex-api.mishrajii7991.workers.dev',
  );

  bool get configured => origin.trim().isNotEmpty;

  Map<String, String> get fileHeaders {
    final bearer = sessionToken;
    return bearer == null || bearer.trim().isEmpty
        ? const <String, String>{}
        : <String, String>{HttpHeaders.authorizationHeader: 'Bearer ${bearer.trim()}'};
  }

  Future<Map<String, dynamic>?> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? authToken,
    bool returnErrorBody = false,
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
      final bearer = authToken ?? sessionToken;
      if (bearer != null && bearer.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${bearer.trim()}');
      }
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
      if (response.statusCode < 200 || response.statusCode >= 300) { return returnErrorBody ? value : null; }
      return value;
    } finally {
      client.close(force: true);
    }
  }

  String fileUrl(String key) => '$origin/api/files?key=${Uri.encodeQueryComponent(key)}';

  Future<String?> uploadImage({required String key, required Uint8List bytes, required String contentType}) async {
    if (!configured || sessionToken == null || bytes.isEmpty || bytes.length > 5 * 1024 * 1024) return null;
    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse('$origin/api/files'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${sessionToken!.trim()}');
      request.headers.set('x-file-key', key);
      request.headers.contentType = ContentType.parse(contentType);
      request.add(bytes);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value['key']?.toString() : null;
    } catch (_) { return null; } finally { client.close(force: true); }
  }

  Future<bool> setUserAvatar({required String userId, required String avatarKey}) async {
    final value = await _json('POST', '/api/users/avatar', body: {'user_id': userId, 'avatar_key': avatarKey});
    return value?['ok'] == true;
  }

  Future<bool> setRoomAvatar({required String roomId, required String userId, required String avatarKey}) async {
    final value = await _json('POST', '/api/rooms/${Uri.encodeComponent(roomId)}/avatar', body: {'user_id': userId, 'avatar_key': avatarKey});
    return value?['ok'] == true;
  }

  Future<Map<String, dynamic>?> health() =>
      _json('GET', '/health');

  Future<Map<String, dynamic>?> googleAuthConfig() =>
      _json('GET', '/api/auth/config');

  Future<Map<String, dynamic>?> userProfile({required String userId}) =>
      _json('GET', '/api/users/${Uri.encodeComponent(userId)}');

  Future<List<Map<String, dynamic>>> profileVisitors({required String userId}) async {
    final value = await _json('GET', '/api/users/${Uri.encodeComponent(userId)}/visitors');
    final rows = value?['visitors'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> vipSupportTickets({required String userId}) async {
    final value = await _json('GET', '/api/vip/${Uri.encodeComponent(userId)}/support-tickets');
    final rows = value?['tickets'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<String?> createVipSupportTicket({required String userId, required String subject, required String message}) async {
    final value = await _json('POST', '/api/vip/${Uri.encodeComponent(userId)}/support-tickets', body: {'subject': subject, 'message': message});
    return value?['ticket_id']?.toString();
  }

  Future<Map<String, dynamic>?> vipSupportTicket({required String userId, required String ticketId}) =>
      _json('GET', '/api/vip/${Uri.encodeComponent(userId)}/support-tickets/${Uri.encodeComponent(ticketId)}');

  Future<bool> replyVipSupportTicket({required String userId, required String ticketId, required String message}) async {
    final value = await _json('POST', '/api/vip/${Uri.encodeComponent(userId)}/support-tickets/${Uri.encodeComponent(ticketId)}/reply', body: {'message': message});
    return value?['ok'] == true;
  }

  Future<Map<String, dynamic>?> startGoogleSession({
    required String idToken,
  }) =>
      _json(
        'POST',
        '/api/session/google',
        body: <String, dynamic>{
          'id_token': idToken,
        },
        returnErrorBody: true,
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

  Future<Map<String, dynamic>?> roomLuckyPouch({required String roomId}) =>
      _json('GET', '/api/rooms/${Uri.encodeComponent(roomId)}/lucky-pouch');

  Future<Map<String, dynamic>?> createRoomLuckyPouch({
    required String roomId,
    required String userId,
    required int totalCoins,
    required int slots,
    required String requestId,
  }) =>
      _json('POST', '/api/rooms/${Uri.encodeComponent(roomId)}/lucky-pouch', body: {
        'user_id': userId, 'total_coins': totalCoins, 'slots': slots, 'request_id': requestId,
      });

  Future<Map<String, dynamic>?> claimRoomLuckyPouch({
    required String roomId,
    required String userId,
  }) =>
      _json('POST', '/api/rooms/${Uri.encodeComponent(roomId)}/lucky-pouch/claim', body: {
        'user_id': userId,
      });

  Future<Map<String, dynamic>?> roomSettings({required String roomId}) =>
      _json('GET', '/api/rooms/${Uri.encodeComponent(roomId)}/settings');

  Future<bool> saveRoomSettings({
    required String roomId,
    required String userId,
    required String name,
    required int seatCount,
    required bool locked,
    required String announcement,
    String themeId = 'dark',
    bool groupPkEnabled = false,
    String welcomeImageKey = '',
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/settings',
      body: {
        'user_id': userId,
        'name': name,
        'seat_count': seatCount,
        'locked': locked,
        'announcement': announcement,
        'theme_id': themeId,
        'group_pk_enabled': groupPkEnabled,
        'welcome_image_key': welcomeImageKey,
      },
    );
    return value?['ok'] == true;
  }

  Future<bool> legalConsentAccepted({required String version}) async {
    final value = await _json(
      'GET',
      '/api/legal/consent?version=${Uri.encodeQueryComponent(version)}',
    );
    return value?['accepted'] == true;
  }

  Future<bool> acceptLegalConsent({required String version}) async {
    final value = await _json(
      'POST',
      '/api/legal/consent',
      body: {'version': version},
    );
    return value?['ok'] == true;
  }

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

  Future<List<Map<String, dynamic>>> roomMessages({required String roomId}) async {
    final value = await _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/messages',
    );
    final rows = value?['messages'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<bool> leaveRoom({required String roomId, required String userId}) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/leave',
      body: {'user_id': userId},
    );
    return value?['ok'] == true;
  }

  Future<bool> setRoomAdmin({
    required String roomId,
    required String actorUserId,
    required String targetUserId,
    required bool admin,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/members',
      body: {
        'user_id': actorUserId,
        'target_user_id': targetUserId,
        'action': admin ? 'set_admin' : 'remove_admin',
      },
    );
    return value?['ok'] == true;
  }

  Future<bool> removeRoomMember({
    required String roomId,
    required String actorUserId,
    required String targetUserId,
    bool ban = false,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/members',
      body: {
        'user_id': actorUserId,
        'target_user_id': targetUserId,
        'ban': ban,
      },
    );
    return value?['ok'] == true;
  }

  Future<bool> reportRoom({
    required String roomId,
    required String userId,
    required String reason,
    required String details,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/report',
      body: {'user_id': userId, 'reason': reason, 'details': details},
    );
    return value?['ok'] == true;
  }

  Future<bool> sendRoomMessage({
    required String roomId,
    required String userId,
    String text = '',
    String? imageKey,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/$roomId/messages',
      body: <String, dynamic>{
        'user_id': userId,
        'text': text,
        if (imageKey != null) 'image_key': imageKey,
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
    String? imageKey,
  }) async {
    final value = await _json(
      'POST',
      '/api/messages/send',
      body: <String, dynamic>{
        'sender_user_id': senderUserId,
        'receiver_user_id': receiverUserId,
        'text': text,
        if (imageKey != null) 'image_key': imageKey,
      },
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> inboxRedEnvelopes({required String userId, required String otherUserId}) async {
    final value = await _json('GET', '/api/messages/red-envelopes?user_id=${Uri.encodeQueryComponent(userId)}&other_user_id=${Uri.encodeQueryComponent(otherUserId)}');
    final rows = value?['envelopes'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> sendInboxRedEnvelope({required String senderUserId, required String receiverUserId, required int amount}) =>
      _json('POST', '/api/messages/red-envelope', body: {'sender_user_id': senderUserId, 'receiver_user_id': receiverUserId, 'amount': amount});

  Future<Map<String, dynamic>?> claimInboxRedEnvelope({required String userId, required String envelopeId}) =>
      _json('POST', '/api/messages/red-envelope/${Uri.encodeComponent(envelopeId)}/claim', body: {'user_id': userId});

  Future<Map<String, dynamic>?> wallet({
    required String userId,
  }) =>
      _json('GET', '/api/wallet/$userId');

  Future<List<Map<String, dynamic>>> gameRooms({required String userId}) async {
    final value = await _json('GET', '/api/game-rooms?user_id=${Uri.encodeQueryComponent(userId)}');
    final rows = value?['rooms'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> createGameRoom({required String userId, required String name}) =>
      _json('POST', '/api/game-rooms', body: {'user_id': userId, 'name': name}, returnErrorBody: true);

  Future<Map<String, dynamic>?> gameRoom({required String roomId, required String userId}) =>
      _json('GET', '/api/game-rooms/${Uri.encodeComponent(roomId)}?user_id=${Uri.encodeQueryComponent(userId)}');

  Future<Map<String, dynamic>?> joinGameRoom({required String roomId, required String userId}) =>
      _json('POST', '/api/game-rooms/${Uri.encodeComponent(roomId)}/join', body: {'user_id': userId}, returnErrorBody: true);

  Future<Map<String, dynamic>?> tapGameRoom({required String roomId, required String userId}) =>
      _json('POST', '/api/game-rooms/${Uri.encodeComponent(roomId)}/tap', body: {'user_id': userId}, returnErrorBody: true);

  Future<List<Map<String, dynamic>>> friends({required String userId}) async {
    final value = await _json('GET', '/api/friends?user_id=${Uri.encodeQueryComponent(userId)}');
    final rows = value?['friends'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> addFriend({required String userId, required String friendUserId}) =>
      _json('POST', '/api/friends/add', body: {'user_id': userId, 'friend_user_id': friendUserId}, returnErrorBody: true);

  Future<bool> removeFriend({required String userId, required String friendUserId}) async {
    final value = await _json('POST', '/api/friends/remove', body: {'user_id': userId, 'friend_user_id': friendUserId});
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> giftCatalog({required String userId}) async {
    final value = await _json('GET', '/api/gifts/catalog?user_id=${Uri.encodeQueryComponent(userId)}');
    final rows = value?['gifts'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

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

  Future<Map<String, dynamic>?> cosmetics({required String userId}) =>
      _json('GET', '/api/cosmetics/${Uri.encodeComponent(userId)}');

  Future<Map<String, dynamic>?> purchaseCosmetic({required String userId, required String itemId, String? recipientUserId}) =>
      _json('POST', '/api/cosmetics/purchase', returnErrorBody: true, body: {
        'user_id': userId,
        'item_id': itemId,
        if (recipientUserId != null) 'recipient_user_id': recipientUserId,
      });

  Future<Map<String, dynamic>?> equipCosmetic({required String userId, required String itemId}) =>
      _json('POST', '/api/cosmetics/equip', returnErrorBody: true, body: {'user_id': userId, 'item_id': itemId});

  Future<Map<String, dynamic>?> idLevelStatus({required String userId}) =>
      _json('GET', '/api/id-level?user_id=${Uri.encodeQueryComponent(userId)}');

  Future<Map<String, dynamic>?> shareRoomForIdLevel({
    required String userId,
    required String roomId,
  }) =>
      _json('POST', '/api/id-level/room-share', body: {
        'user_id': userId,
        'room_id': roomId,
      }, returnErrorBody: true);

  Future<Map<String, dynamic>?> claimIdLevelReward({
    required String userId,
    required int level,
  }) =>
      _json('POST', '/api/id-level/rewards/claim', body: {
        'user_id': userId,
        'level': level,
      }, returnErrorBody: true);

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

  Future<Map<String, dynamic>?> sendVipSayHi({
    required String userId,
    required String receiverUserId,
    required String message,
  }) =>
      _json(
        'POST',
        '/api/vip/${Uri.encodeComponent(userId)}/say-hi',
        body: <String, dynamic>{
          'receiver_user_id': receiverUserId,
          'message': message,
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
        returnErrorBody: true,
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

  Future<List<Map<String, dynamic>>> roomMembers({
    required String roomId,
  }) async {
    final value = await _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/members',
    );
    final rows = value?['members'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<bool> roomFollowStatus({
    required String roomId,
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/follow?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    return value?['following'] == true;
  }

  Future<bool> setRoomFollow({
    required String roomId,
    required String userId,
    required bool follow,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/follow',
      body: <String, dynamic>{
        'user_id': userId,
        'follow': follow,
      },
    );
    return value?['following'] == follow;
  }

  Future<Map<String, dynamic>?> aladdinLampStatus({
    required String roomId,
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/rooms/${Uri.encodeComponent(roomId)}/lamp?user_id=${Uri.encodeQueryComponent(userId)}',
      );

  Future<Map<String, dynamic>?> claimAladdinLampTask({
    required String roomId,
    required String userId,
    required String taskId,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/lamp/claim',
        body: <String, dynamic>{
          'user_id': userId,
          'task_id': taskId,
        },
      );

  Future<bool> recordAladdinShare({
    required String roomId,
    required String userId,
    required String platform,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/lamp/share',
      body: <String, dynamic>{
        'user_id': userId,
        'platform': platform,
      },
    );
    return value?['ok'] == true;
  }

  Future<bool> inviteAladdinMic({
    required String roomId,
    required String hostUserId,
    required String inviteeUserId,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/lamp/invite',
      body: <String, dynamic>{
        'host_user_id': hostUserId,
        'invitee_user_id': inviteeUserId,
      },
    );
    return value?['ok'] == true;
  }

}
