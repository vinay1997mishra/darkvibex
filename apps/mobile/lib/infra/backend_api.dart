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
    final maxBytes = contentType == 'video/mp4' ? 20 * 1024 * 1024 : 5 * 1024 * 1024;
    if (!configured || sessionToken == null || bytes.isEmpty || bytes.length > maxBytes) return null;
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

  Future<Map<String, dynamic>?> saveUserProfile({
    required String userId,
    required String displayName,
    required String dateOfBirth,
    String countryCode = '',
    String countryName = '',
    String flagEmoji = '',
    String gender = '',
    String language = '',
  }) =>
      _json(
        'POST',
        '/api/users/profile',
        body: <String, dynamic>{
          'user_id': userId,
          'display_name': displayName,
          'date_of_birth': dateOfBirth,
          if (countryCode.trim().isNotEmpty) 'country_code': countryCode.trim(),
          if (countryName.trim().isNotEmpty) 'country_name': countryName.trim(),
          if (flagEmoji.trim().isNotEmpty) 'flag_emoji': flagEmoji.trim(),
          if (gender.trim().isNotEmpty) 'gender': gender.trim(),
          if (language.trim().isNotEmpty) 'language': language.trim(),
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> setUserLanguage({
    required String userId,
    required String language,
  }) =>
      _json(
        'POST',
        '/api/users/language',
        body: <String, dynamic>{
          'user_id': userId,
          'language': language,
        },
        returnErrorBody: true,
      );

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

  Future<Map<String, dynamic>?> startEmailOtp({
    required String email,
    String purpose = 'signup',
  }) =>
      _json(
        'POST',
        '/api/session/email/start',
        body: <String, dynamic>{
          'email': email,
          'purpose': purpose,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> verifyEmailOtp({
    required String requestId,
    required String otp,
  }) =>
      _json(
        'POST',
        '/api/session/email/verify',
        body: <String, dynamic>{
          'request_id': requestId,
          'otp': otp,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> completeEmailPassword({
    required String setupToken,
    required String password,
    String? displayName,
    String? dateOfBirth,
  }) =>
      _json(
        'POST',
        '/api/session/email/complete',
        body: <String, dynamic>{
          'setup_token': setupToken,
          'password': password,
          if (displayName != null) 'display_name': displayName,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> startEmailSession({
    required String email,
    required String password,
  }) =>
      _json(
        'POST',
        '/api/session/email/login',
        body: <String, dynamic>{
          'email': email,
          'password': password,
        },
        returnErrorBody: true,
      );

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

  Future<Map<String, dynamic>?> bindGoogleIdentity({
    required String idToken,
  }) =>
      _json(
        'POST',
        '/api/account/bind-google',
        body: <String, dynamic>{'id_token': idToken},
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

  Future<Map<String, dynamic>?> drawRoomLuckyNumber({
    required String roomId,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/lucky-number',
      );

  Future<Map<String, dynamic>?> roomThemes({
    required String roomId,
  }) =>
      _json(
        'GET',
        '/api/rooms/${Uri.encodeComponent(roomId)}/themes',
      );

  Future<Map<String, dynamic>?> createRoomTheme({
    required String roomId,
    required String name,
    required String assetKey,
    bool policyConfirmed = true,
    int durationDays = 7,
    bool permanent = false,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/themes',
        returnErrorBody: true,
        body: <String, dynamic>{
          'name': name,
          'asset_key': assetKey,
          'policy_confirmed': policyConfirmed,
          'duration_days': durationDays,
          'permanent': permanent,
        },
      );

  Future<Map<String, dynamic>?> roomSettings({required String roomId}) =>
      _json('GET', '/api/rooms/${Uri.encodeComponent(roomId)}/settings');

  Future<Map<String, dynamic>?> roomControls({required String roomId}) =>
      _json('GET', '/api/rooms/${Uri.encodeComponent(roomId)}/controls');

  Future<Map<String, dynamic>?> setRoomControl({
    required String roomId,
    required String userId,
    required String action,
    int? seatIndex,
    String? targetUserId,
    bool? enabled,
    bool? locked,
    bool? muted,
    bool? banned,
    bool? accepted,
    String? micMode,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/controls',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'action': action,
          if (seatIndex != null) 'seat_index': seatIndex,
          if (targetUserId != null) 'target_user_id': targetUserId,
          if (enabled != null) 'enabled': enabled,
          if (locked != null) 'locked': locked,
          if (muted != null) 'muted': muted,
          if (banned != null) 'banned': banned,
          if (accepted != null) 'accepted': accepted,
          if (micMode != null) 'mic_mode': micMode,
        },
      );

  Future<Map<String, dynamic>?> requestRoomSeat({
    required String roomId,
    required String userId,
    required int seatIndex,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/seat-request',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'seat_index': seatIndex,
        },
      );

  Future<Map<String, dynamic>?> resolveRoomSeatRequest({
    required String roomId,
    required String userId,
    required String targetUserId,
    required bool approved,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/seat-request/resolve',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'target_user_id': targetUserId,
          'approved': approved,
        },
      );

  Future<Map<String, dynamic>?> saveRoomSettingsResult({
    required String roomId,
    required String userId,
    required String name,
    required int seatCount,
    required bool locked,
    required String announcement,
    String themeId = 'dark',
    bool groupPkEnabled = false,
    String welcomeImageKey = '',
    String partyMode = 'Friends-making Party',
    String roomMode = 'voice',
    String seatThemeId = 'royal-gold',
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/settings',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'name': name,
          'seat_count': seatCount,
          'locked': locked,
          'announcement': announcement,
          'theme_id': themeId,
          'group_pk_enabled': groupPkEnabled,
          'welcome_image_key': welcomeImageKey,
          'party_mode': partyMode,
          'room_mode': roomMode,
          'seat_theme_id': seatThemeId,
        },
      );

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
    String partyMode = 'Friends-making Party',
    String roomMode = 'voice',
    String seatThemeId = 'royal-gold',
  }) async {
    final value = await saveRoomSettingsResult(
      roomId: roomId,
      userId: userId,
      name: name,
      seatCount: seatCount,
      locked: locked,
      announcement: announcement,
      themeId: themeId,
      groupPkEnabled: groupPkEnabled,
      welcomeImageKey: welcomeImageKey,
      partyMode: partyMode,
      roomMode: roomMode,
      seatThemeId: seatThemeId,
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

  Future<Map<String, dynamic>?> createRoomResult({
    required String ownerUserId,
    required String ownerName,
    required String name,
    required int seatCount,
    String partyMode = 'Friends-making Party',
    String roomMode = 'voice',
  }) =>
      _json(
        'POST',
        '/api/rooms',
        returnErrorBody: true,
        body: <String, dynamic>{
          'owner_user_id': ownerUserId,
          'owner_name': ownerName,
          'name': name,
          'seat_count': seatCount,
          'party_mode': partyMode,
          'room_mode': roomMode,
        },
      );

  Future<String?> createRoom({
    required String ownerUserId,
    required String ownerName,
    required String name,
    required int seatCount,
    String partyMode = 'Friends-making Party',
    String roomMode = 'voice',
  }) async {
    final value = await createRoomResult(
      ownerUserId: ownerUserId,
      ownerName: ownerName,
      name: name,
      seatCount: seatCount,
      partyMode: partyMode,
      roomMode: roomMode,
    );
    return value?['room_id']?.toString();
  }

  Future<Map<String, dynamic>?> joinRoomResult({
    required String roomId,
    required String userId,
    required String displayName,
    String? password,
  }) =>
      _json(
        'POST',
        '/api/rooms/$roomId/join',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'display_name': displayName,
          if (password != null) 'password': password,
        },
      );

  Future<bool> joinRoom({
    required String roomId,
    required String userId,
    required String displayName,
    String? password,
  }) async {
    final value = await joinRoomResult(
      roomId: roomId,
      userId: userId,
      displayName: displayName,
      password: password,
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

  Future<List<Map<String, dynamic>>> globalRanking({
    required String kind,
    required String period,
  }) async {
    final value = await _json(
      'GET',
      '/api/rankings?kind=${Uri.encodeQueryComponent(kind)}'
      '&period=${Uri.encodeQueryComponent(period)}',
    );
    final rows = value?['ranking'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> roomGiftRanking({required String roomId}) =>
      _json(
        'GET',
        '/api/rooms/${Uri.encodeComponent(roomId)}/gift-ranking',
      );

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

  Future<List<Map<String, dynamic>>> roomBlacklist({
    required String roomId,
  }) async {
    final value = await _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/blacklist',
    );
    final rows = value?['blacklist'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<bool> unblockRoomMember({
    required String roomId,
    required String targetUserId,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/blacklist',
      body: <String, dynamic>{'target_user_id': targetUserId},
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

  Future<List<Map<String, dynamic>>> rechargeProviders() async {
    final value = await _json(
      'GET',
      '/api/recharge-providers',
      returnErrorBody: true,
    );
    final rows = value?['providers'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
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

  Future<Map<String, dynamic>?> coinsHistory({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/wallet/coins/history?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> diamondsHistory({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/wallet/diamonds/history?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> convertDiamonds({
    required String userId,
    required int diamonds,
  }) =>
      _json(
        'POST',
        '/api/wallet/diamonds/convert',
        body: <String, dynamic>{
          'user_id': userId,
          'diamonds': diamonds,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> roleWalletDetail({
    required String userId,
    required String walletType,
  }) =>
      _json(
        'GET',
        '/api/wallet/role-detail?user_id=${Uri.encodeQueryComponent(userId)}'
        '&wallet_type=${Uri.encodeQueryComponent(walletType)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> setRoleWalletCredential({
    required String userId,
    required String walletType,
    required String credential,
    String? oldCredential,
  }) =>
      _json(
        'POST',
        '/api/wallet/role-credential',
        body: <String, dynamic>{
          'user_id': userId,
          'wallet_type': walletType,
          'credential': credential,
          if (oldCredential != null) 'old_credential': oldCredential,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> roleWalletCoinTransfer({
    required String userId,
    required String walletType,
    required String receiverUserId,
    required int coins,
    required String credential,
  }) =>
      _json(
        'POST',
        '/api/wallet/role-coins/transfer',
        body: <String, dynamic>{
          'user_id': userId,
          'wallet_type': walletType,
          'receiver_user_id': receiverUserId,
          'coins': coins,
          'credential': credential,
        },
        returnErrorBody: true,
      );

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

  Future<List<Map<String, dynamic>>> customGifts({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/custom-gifts?user_id=${Uri.encodeQueryComponent(userId)}',
      returnErrorBody: true,
    );
    final rows = value?['gifts'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> createCustomGift({
    required String userId,
    required String name,
    required String assetKey,
    int coinCost = 5000,
  }) =>
      _json(
        'POST',
        '/api/custom-gifts',
        body: <String, dynamic>{
          'user_id': userId,
          'name': name,
          'asset_key': assetKey,
          'coin_cost': coinCost,
        },
        returnErrorBody: true,
      );

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

  Future<List<Map<String, dynamic>>> uniqueIdCatalog({
    required String userId,
  }) async {
    final value = await _json('GET', '/api/unique-ids/catalog');
    final rows = value?['unique_ids'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> purchaseUniqueId({
    required String userId,
    required String publicId,
  }) =>
      _json(
        'POST',
        '/api/unique-ids/purchase',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'public_id': publicId,
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
    required String pin,
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

  Future<Map<String, dynamic>?> ludoState({
    required String roomId,
  }) =>
      _json(
        'GET',
        '/api/rooms/${Uri.encodeComponent(roomId)}/ludo',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> ludoRoll({
    required String roomId,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/ludo/roll',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> ludoMove({
    required String roomId,
    required int tokenIndex,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/ludo/move',
        returnErrorBody: true,
        body: <String, dynamic>{'token_index': tokenIndex},
      );

  Future<Map<String, dynamic>?> ludoLeave({
    required String roomId,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/ludo/leave',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> ludoReset({
    required String roomId,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/ludo/reset',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> fruitPartyState() =>
      _json(
        'GET',
        '/api/games/fruit-party/state',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> fruitPartyBet({
    required String userId,
    required String fruitKey,
    required int amount,
    required String requestId,
  }) =>
      _json(
        'POST',
        '/api/games/fruit-party/bet',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'fruit_key': fruitKey,
          'amount': amount,
          'request_id': requestId,
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

  Future<List<Map<String, dynamic>>> followedRooms({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/rooms/following?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['rooms'];
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

  Future<Map<String, dynamic>?> startDirectCall({
    required String userId,
    required String receiverUserId,
  }) =>
      _json(
        'POST',
        '/api/calls/start',
        body: <String, dynamic>{
          'user_id': userId,
          'receiver_user_id': receiverUserId,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> incomingDirectCall({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/calls/incoming?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> respondDirectCall({
    required String userId,
    required String callId,
    required bool accept,
  }) =>
      _json(
        'POST',
        '/api/calls/respond',
        body: <String, dynamic>{
          'user_id': userId,
          'call_id': callId,
          'accept': accept,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> directCallStatus({
    required String userId,
    required String callId,
  }) =>
      _json(
        'GET',
        '/api/calls/status?user_id=${Uri.encodeQueryComponent(userId)}'
        '&call_id=${Uri.encodeQueryComponent(callId)}',
        returnErrorBody: true,
      );

  Future<bool> endDirectCall({
    required String userId,
    required String callId,
  }) async {
    final value = await _json(
      'POST',
      '/api/calls/end',
      body: <String, dynamic>{
        'user_id': userId,
        'call_id': callId,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> officialMessages() async {
    final value = await _json('GET', '/api/messages/official');
    final rows = value?['notices'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> activityMessages({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/messages/activity?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['activity'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, String?>> profileMedia({
    String? userId,
  }) async {
    final suffix = userId == null || userId.trim().isEmpty
        ? ''
        : '?user_id=${Uri.encodeQueryComponent(userId.trim())}';
    final value = await _json(
      'GET',
      '/api/profile-media$suffix',
      returnErrorBody: true,
    );
    final raw = value?['media'];
    if (raw is! Map) return const <String, String?>{};
    return raw.map(
      (key, item) => MapEntry(key.toString(), item?.toString()),
    );
  }

  Future<bool> saveProfileMedia({
    required String slot,
    required String assetKey,
  }) async {
    final value = await _json(
      'POST',
      '/api/profile-media',
      returnErrorBody: true,
      body: <String, dynamic>{
        'slot': slot,
        'asset_key': assetKey,
      },
    );
    return value?['ok'] == true;
  }

  Future<bool> deleteProfileMedia({
    required String slot,
  }) async {
    final value = await _json(
      'DELETE',
      '/api/profile-media',
      returnErrorBody: true,
      body: <String, dynamic>{
        'slot': slot,
        'confirm_remove': true,
      },
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> profileTrends({
    required String userId,
    int limit = 40,
  }) async {
    final value = await _json(
      'GET',
      '/api/profile/trends?user_id=${Uri.encodeQueryComponent(userId)}&limit=$limit',
      returnErrorBody: true,
    );
    final rows = value?['trends'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> addProfileTrend({
    required String userId,
    required String text,
  }) =>
      _json(
        'POST',
        '/api/profile/trends',
        body: <String, dynamic>{
          'user_id': userId,
          'text': text,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> socialStats({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/social/stats?user_id=${Uri.encodeQueryComponent(userId)}',
      );

  Future<bool> followStatus({
    required String userId,
    required String targetUserId,
  }) async {
    final value = await _json(
      'GET',
      '/api/social/follow?user_id=${Uri.encodeQueryComponent(userId)}'
      '&target_user_id=${Uri.encodeQueryComponent(targetUserId)}',
    );
    return value?['following'] == true;
  }

  Future<bool> setUserFollow({
    required String userId,
    required String targetUserId,
    required bool follow,
  }) async {
    final value = await _json(
      'POST',
      '/api/social/follow',
      body: <String, dynamic>{
        'user_id': userId,
        'target_user_id': targetUserId,
        'follow': follow,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true && value?['following'] == follow;
  }

  Future<List<Map<String, dynamic>>> blockedUsers({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/social/blocked?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['blocked'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<bool> setUserBlocked({
    required String userId,
    required String targetUserId,
    required bool blocked,
  }) async {
    final value = await _json(
      'POST',
      '/api/social/block',
      body: <String, dynamic>{
        'user_id': userId,
        'target_user_id': targetUserId,
        'blocked': blocked,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true && value?['blocked'] == blocked;
  }

  Future<List<Map<String, dynamic>>> followers({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/social/followers?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['followers'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> following({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/social/following?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['following'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> mineTasks({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/tasks?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['tasks'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>?> claimMineTask({
    required String userId,
    required String taskId,
  }) =>
      _json(
        'POST',
        '/api/tasks/claim',
        body: <String, dynamic>{
          'user_id': userId,
          'task_id': taskId,
        },
        returnErrorBody: true,
      );

  Future<List<Map<String, dynamic>>> feedbackHistory({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/feedback?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['feedback'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<bool> submitFeedback({
    required String userId,
    required String category,
    required String message,
  }) async {
    final value = await _json(
      'POST',
      '/api/feedback',
      body: <String, dynamic>{
        'user_id': userId,
        'category': category,
        'message': message,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> medals({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/medals?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['medals'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> familyList() async {
    final value = await _json('GET', '/api/family/list?limit=100');
    final rows = value?['families'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>?> familyState({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/family?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> createFamily({
    required String userId,
    required String name,
    required String tag,
  }) =>
      _json(
        'POST',
        '/api/family/create',
        body: <String, dynamic>{
          'user_id': userId,
          'name': name,
          'tag': tag,
        },
        returnErrorBody: true,
      );

  Future<bool> requestFamilyJoin({
    required String userId,
    required String familyId,
  }) async {
    final value = await _json(
      'POST',
      '/api/family/join-request',
      body: <String, dynamic>{
        'user_id': userId,
        'family_id': familyId,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<bool> resolveFamilyJoin({
    required String userId,
    required String targetUserId,
    required bool approve,
  }) async {
    final value = await _json(
      'POST',
      '/api/family/join-request/resolve',
      body: <String, dynamic>{
        'user_id': userId,
        'target_user_id': targetUserId,
        'approve': approve,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<bool> setFamilyAdmin({
    required String userId,
    required String targetUserId,
    required bool admin,
  }) async {
    final value = await _json(
      'POST',
      '/api/family/admin',
      body: <String, dynamic>{
        'user_id': userId,
        'target_user_id': targetUserId,
        'admin': admin,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<bool> removeFamilyMember({
    required String userId,
    required String targetUserId,
  }) async {
    final value = await _json(
      'POST',
      '/api/family/member/remove',
      body: <String, dynamic>{
        'user_id': userId,
        'target_user_id': targetUserId,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<bool> leaveFamily({
    required String userId,
  }) async {
    final value = await _json(
      'POST',
      '/api/family/leave',
      body: <String, dynamic>{'user_id': userId},
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<bool> updateFamilyNotice({
    required String userId,
    required String notice,
  }) async {
    final value = await _json(
      'POST',
      '/api/family/notice',
      body: <String, dynamic>{
        'user_id': userId,
        'notice': notice,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> familyWalletTransfers({
    int limit = 100,
  }) async {
    final value = await _json(
      'GET',
      '/api/family/wallet/transfers?limit=$limit',
      returnErrorBody: true,
    );
    final rows = value?['transfers'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> sendFamilyCoins({
    required String receiverUserId,
    required int coins,
  }) =>
      _json(
        'POST',
        '/api/family/wallet/send',
        returnErrorBody: true,
        body: <String, dynamic>{
          'receiver_user_id': receiverUserId,
          'coins': coins,
        },
      );

  Future<Map<String, dynamic>?> familyCheckIn({
    required String userId,
  }) =>
      _json(
        'POST',
        '/api/family/check-in',
        body: <String, dynamic>{'user_id': userId},
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> vsState({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/vs?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> vsRequest({
    required String userId,
    required String targetUserId,
  }) =>
      _json(
        'POST',
        '/api/vs/request',
        body: <String, dynamic>{
          'user_id': userId,
          'target_user_id': targetUserId,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> vsRespond({
    required String userId,
    required bool accept,
  }) =>
      _json(
        'POST',
        '/api/vs/respond',
        body: <String, dynamic>{
          'user_id': userId,
          'accept': accept,
        },
        returnErrorBody: true,
      );

  Future<bool> vsDisconnect({
    required String userId,
  }) async {
    final value = await _json(
      'POST',
      '/api/vs/disconnect',
      body: <String, dynamic>{'user_id': userId},
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> vsRanking() async {
    final value = await _json('GET', '/api/vs/ranking?limit=100');
    final rows = value?['ranking'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>?> cpState({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/cp?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> cpRequest({
    required String userId,
    required String targetUserId,
  }) =>
      _json(
        'POST',
        '/api/cp/request',
        body: <String, dynamic>{
          'user_id': userId,
          'target_user_id': targetUserId,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> cpRespond({
    required String userId,
    required bool accept,
  }) =>
      _json(
        'POST',
        '/api/cp/respond',
        body: <String, dynamic>{
          'user_id': userId,
          'accept': accept,
        },
        returnErrorBody: true,
      );

  Future<bool> cpDisconnect({
    required String userId,
  }) async {
    final value = await _json(
      'POST',
      '/api/cp/disconnect',
      body: <String, dynamic>{'user_id': userId},
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<Map<String, dynamic>?> cpSetRing({
    required String userId,
    String? ringId,
  }) =>
      _json(
        'POST',
        '/api/cp/ring',
        body: <String, dynamic>{
          'user_id': userId,
          'ring_id': ringId ?? '',
        },
        returnErrorBody: true,
      );

  Future<List<Map<String, dynamic>>> cpMemories({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/cp/memories?user_id=${Uri.encodeQueryComponent(userId)}',
    );
    final rows = value?['memories'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<bool> addCpMemory({
    required String userId,
    required String text,
  }) async {
    final value = await _json(
      'POST',
      '/api/cp/memories',
      body: <String, dynamic>{
        'user_id': userId,
        'text': text,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> cpRanking() async {
    final value = await _json('GET', '/api/cp/ranking?limit=100');
    final rows = value?['ranking'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
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
