import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class BackendApi {
  const BackendApi();

  /// Idempotency key (Wallet audit H1, 2026-11-22): one key per money
  /// attempt, so a retried transfer / gift send returns the original
  /// result instead of moving the money twice. Generated per call;
  /// callers that add their own retry must pass the SAME key again.
  static String _idempotencyKey() =>
      '${DateTime.now().millisecondsSinceEpoch}-'
      '${math.Random().nextInt(1 << 32)}-${math.Random().nextInt(1 << 32)}';

  static String? sessionToken;
  static String? deviceKey;

  /// Fired whenever the transport proves the server reachable (true) or
  /// unreachable (false). AppState subscribes so `backendConnected`
  /// flips the moment the network drops mid-session, instead of only
  /// at login/sign-out. Only called when the value actually changes is
  /// the subscriber's job; this just reports what _json observed.
  static void Function(bool connected)? onConnectivityChanged;

  /// One shared client for every request (full-app audit 2026-11-20):
  /// a fresh HttpClient + TLS handshake per call churned a connection
  /// on every 4s/5s/8s poll. Created lazily so tests that never hit
  /// the network never open one.
  static HttpClient? _sharedClient;
  static HttpClient get _client => _sharedClient ??= HttpClient();

  static const List<Map<String, Object>> _featuredRoomGifts =
      <Map<String, Object>>[
    <String, Object>{'id': 'marigold-garland', 'name': 'Marigold Garland', 'emoji': '🌼', 'coin_cost': 200000, 'vip_level': 0, 'category': 'normal'},
    <String, Object>{'id': 'matar-paneer', 'name': 'Matar Paneer', 'emoji': '🍲', 'coin_cost': 300000, 'vip_level': 0, 'category': 'backpack'},
    <String, Object>{'id': 'royal-lantern', 'name': 'Royal Lantern', 'emoji': '🏮', 'coin_cost': 500000, 'vip_level': 0, 'category': 'country'},
    <String, Object>{'id': 'garba-duet', 'name': 'Garba Duet', 'emoji': '💃', 'coin_cost': 1200000, 'vip_level': 0, 'category': 'cp'},
    <String, Object>{'id': 'kebab-platter', 'name': 'Kebab Platter', 'emoji': '🍢', 'coin_cost': 500000, 'vip_level': 0, 'category': 'backpack'},
    <String, Object>{'id': 'heart-crystal', 'name': 'Heart Crystal', 'emoji': '💗', 'coin_cost': 800000, 'vip_level': 0, 'category': 'normal'},
    <String, Object>{'id': 'diya-blessing', 'name': 'Diya Blessing', 'emoji': '🪔', 'coin_cost': 250000, 'vip_level': 0, 'category': 'normal'},
    <String, Object>{'id': 'royal-thali', 'name': 'Royal Thali', 'emoji': '🍽️', 'coin_cost': 900000, 'vip_level': 0, 'category': 'luxury'},
    <String, Object>{'id': 'magic-lamp', 'name': 'Magic Lamp', 'emoji': '🪔', 'coin_cost': 2000000, 'vip_level': 0, 'category': 'lucky'},
    <String, Object>{'id': 'rainbow-gemstones', 'name': 'Rainbow Gemstones', 'emoji': '💎', 'coin_cost': 600000, 'vip_level': 0, 'category': 'normal'},
    <String, Object>{'id': 'flower-swing', 'name': 'Flower Swing', 'emoji': '🌺', 'coin_cost': 1100000, 'vip_level': 0, 'category': 'cp'},
    <String, Object>{'id': 'crown-shower', 'name': 'Crown Shower', 'emoji': '👑', 'coin_cost': 2500000, 'vip_level': 0, 'category': 'luxury'},
    <String, Object>{'id': 'palace-feast', 'name': 'Palace Feast', 'emoji': '🍛', 'coin_cost': 3000000, 'vip_level': 0, 'category': 'luxury'},
    <String, Object>{'id': 'wedding-stage', 'name': 'Wedding Stage', 'emoji': '💒', 'coin_cost': 4000000, 'vip_level': 0, 'category': 'cp'},
    <String, Object>{'id': 'royal-elephant', 'name': 'Royal Elephant', 'emoji': '🐘', 'coin_cost': 6000000, 'vip_level': 0, 'category': 'country'},
    <String, Object>{'id': 'maharaja-carriage', 'name': 'Maharaja Carriage', 'emoji': '🎠', 'coin_cost': 8000000, 'vip_level': 0, 'category': 'luxury'},
    <String, Object>{'id': 'firework-celebration', 'name': 'Firework Celebration', 'emoji': '🎆', 'coin_cost': 10000000, 'vip_level': 0, 'category': 'lucky'},
    <String, Object>{'id': 'galaxy-celebration', 'name': 'Galaxy Celebration', 'emoji': '🌌', 'coin_cost': 12000000, 'vip_level': 0, 'category': 'lucky'},
  ];

  static const String origin = String.fromEnvironment(
    'DARKVIBEX_API_ORIGIN',
    defaultValue: 'https://darkvibex-api.mishrajii7991.workers.dev',
  );

  bool get configured => origin.trim().isNotEmpty;

  Map<String, String> get fileHeaders {
    final bearer = sessionToken;
    final headers = <String, String>{};
    if (bearer != null && bearer.trim().isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer ${bearer.trim()}';
    }
    final device = deviceKey?.trim() ?? '';
    if (device.isNotEmpty) headers['x-device-id'] = device;
    return headers;
  }

  Future<Map<String, dynamic>?> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? authToken,
    bool returnErrorBody = false,
  }) async {
    if (!configured) return null;
    // Transport failures return null instead of throwing (full-app
    // audit 2026-11-20): every poller and action handler calls _json,
    // and a SocketException mid-session used to escape as an unhandled
    // async error every tick. Callers already treat null as "no data /
    // not ok", so this is the single-point fix. A received HTTP
    // response (any status) proves the server is reachable.
    final client = _client;
    try {
      final uri = Uri.parse('$origin$path');
      final request = switch (method) {
        'GET' => await client.getUrl(uri),
        'POST' => await client.postUrl(uri),
        'PUT' => await client.putUrl(uri),
        _ => await client.openUrl(method, uri),
      };
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final device = deviceKey?.trim() ?? '';
      if (device.isNotEmpty) request.headers.set('x-device-id', device);
      final bearer = authToken ?? sessionToken;
      if (bearer != null && bearer.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${bearer.trim()}');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      onConnectivityChanged?.call(true);
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
    } on SocketException {
      onConnectivityChanged?.call(false);
      return null;
    } on HttpException {
      onConnectivityChanged?.call(false);
      return null;
    } on HandshakeException {
      onConnectivityChanged?.call(false);
      return null;
    }
  }

  /// True when [key] is a private user-info file key
  /// (users/<userId>/<id-number|dp|sms|misc>/<file>) — it lives in the
  /// private bucket and must never be fetched from /api/files.
  static bool isPrivateUserFileKey(String key) =>
      RegExp(r'^users/[^/]+/(id-number|dp|sms|misc)/[^/]+$')
          .hasMatch(key.trim());

  /// URL for any file key. Private user-info keys (a DP in the private
  /// bucket, an ID document, ...) go through the authenticated
  /// /api/user-files route; everything else keeps using /api/files.
  /// All avatar displays call this one method, so a DP that moved to
  /// the private bucket keeps showing everywhere without touching the
  /// 29 display sites.
  String fileUrl(String key) => isPrivateUserFileKey(key)
      ? userFileUrl(key)
      : '$origin/api/files?key=${Uri.encodeQueryComponent(key)}';

  /// URL of a private user-ID file (bucket "darkvibex-id-info"). The
  /// file is served ONLY through the Worker with the user's session —
  /// there is no public R2 URL for it. [key] must be the user's own
  /// user-info key (users/<userId>/<id-number|dp|sms|misc>/<file>).
  String userFileUrl(String key) => '$origin/api/user-files?key=${Uri.encodeQueryComponent(key)}';

  /// Uploads one user-info file (ID number document, ID DP, SMS file,
  /// or anything else) to the PRIVATE bucket. Mirrors [uploadImage]
  /// but targets /api/user-files; the Worker only accepts the caller's
  /// own users/<userId>/<category>/<file> keys. Returns the stored key
  /// or null on failure.
  Future<String?> uploadUserFile({required String key, required Uint8List bytes, required String contentType}) async {
    final maxBytes = contentType == 'video/mp4' ? 20 * 1024 * 1024 : 5 * 1024 * 1024;
    if (!configured || sessionToken == null || bytes.isEmpty || bytes.length > maxBytes) return null;
    final client = _client;
    try {
      final request = await client.putUrl(Uri.parse('$origin/api/user-files'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${sessionToken!.trim()}');
      final device = deviceKey?.trim() ?? '';
      if (device.isNotEmpty) request.headers.set('x-device-id', device);
      request.headers.set('x-file-key', key);
      request.headers.contentType = ContentType.parse(contentType);
      request.add(bytes);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value['key']?.toString() : null;
    } catch (_) { return null; }
  }

  Future<String?> uploadImage({required String key, required Uint8List bytes, required String contentType}) async {
    final maxBytes = contentType == 'video/mp4' ? 20 * 1024 * 1024 : 5 * 1024 * 1024;
    if (!configured || sessionToken == null || bytes.isEmpty || bytes.length > maxBytes) return null;
    final client = _client;
    try {
      final request = await client.putUrl(Uri.parse('$origin/api/files'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${sessionToken!.trim()}');
      final device = deviceKey?.trim() ?? '';
      if (device.isNotEmpty) request.headers.set('x-device-id', device);
      request.headers.set('x-file-key', key);
      request.headers.contentType = ContentType.parse(contentType);
      request.add(bytes);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value['key']?.toString() : null;
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>?> saveUserProfile({
    required String userId,
    required String displayName,
    required String dateOfBirth,
    String countryCode = '',
    String countryName = '',
    String flagEmoji = '',
    String gender = '',
    String bio = '',
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
          'bio': bio.trim(),
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

  Future<Map<String, dynamic>?> userProfile({
    required String userId,
    bool recordVisit = true,
  }) =>
      _json(
        'GET',
        '/api/users/${Uri.encodeComponent(userId)}${recordVisit ? '' : '?record_visit=0'}',
        returnErrorBody: true,
      );

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

  Future<Map<String, dynamic>?> refreshSession({required String token}) =>
      _json(
        'POST',
        '/api/session/refresh',
        authToken: token,
        body: const <String, dynamic>{},
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

  Future<List<Map<String, dynamic>>> activeBanners() async {
    final value = await _json('GET', '/api/banners');
    final rows = value?['banners'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

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
    int? vipOnly,
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
          if (vipOnly != null) 'vip_only': vipOnly,
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

  Future<List<Map<String, dynamic>>?> listRooms() async {
    final value = await _json('GET', '/api/rooms');
    // A failed request or malformed response is not an empty room list.
    // Return null so AppState can retain the last known rooms instead of
    // clearing Mine while the API is temporarily unavailable.
    if (value?['ok'] != true) return null;
    final rows = value?['rooms'];
    if (rows is! List) return null;
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
    int vipOnly = 0,
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
          'vip_only': vipOnly,
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

  Future<Map<String, dynamic>?> setSeatResult({
    required String roomId,
    required String userId,
    required int? seatIndex,
    required bool micMuted,
  }) =>
      _json(
        'POST',
        '/api/rooms/$roomId/seat',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'seat_index': seatIndex,
          'mic_muted': micMuted,
        },
      );

  Future<bool> setSeat({
    required String roomId,
    required String userId,
    required int? seatIndex,
    required bool micMuted,
  }) async {
    final value = await setSeatResult(
      roomId: roomId,
      userId: userId,
      seatIndex: seatIndex,
      micMuted: micMuted,
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

  Future<Map<String, dynamic>?> roomRocketRewardStatus({
    required String roomId,
    required int rocketLevel,
  }) =>
      _json(
        'GET',
        '/api/rooms/${Uri.encodeComponent(roomId)}/rocket-reward?level=$rocketLevel',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> claimRoomRocketReward({
    required String roomId,
    required int rocketLevel,
  }) =>
      _json(
        'POST',
        '/api/rooms/${Uri.encodeComponent(roomId)}/rocket-reward/claim',
        body: <String, dynamic>{'rocket_level': rocketLevel},
        returnErrorBody: true,
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

  Future<bool> clearRoomChat({
    required String roomId,
    required String userId,
  }) async {
    final value = await _json(
      'POST',
      '/api/rooms/${Uri.encodeComponent(roomId)}/messages/clear',
      body: <String, dynamic>{'user_id': userId},
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> roomGiftEvents({
    required String roomId,
    required int after,
    String afterId = '',
    String eventId = '',
  }) async {
    final eventQuery = eventId.isEmpty ? '' : '&event_id=${Uri.encodeQueryComponent(eventId)}';
    final value = await _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/gift-events?after=$after&after_id=${Uri.encodeQueryComponent(afterId)}$eventQuery',
      returnErrorBody: true,
    );
    final rows = value?['events'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
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

  /// Sends a room message and returns the raw server map, INCLUDING the
  /// error body when the send is rejected (e.g. `error:
  /// 'content_blocked' when the text trips the content filter). Null
  /// only means no response reached the app (offline / transport).
  /// Callers must check `result['ok'] == true` before reading
  /// `result['message']`.
  Future<Map<String, dynamic>?> sendRoomMessageResult({
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
      returnErrorBody: true,
    );
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  Future<bool> sendRoomMessage({
    required String roomId,
    required String userId,
    String text = '',
    String? imageKey,
  }) async {
    final value = await sendRoomMessageResult(
      roomId: roomId,
      userId: userId,
      text: text,
      imageKey: imageKey,
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

  /// Google Play Billing packs + the first-recharge flag for this
  /// user (worker: GET /api/play/packs). Null when the server cannot
  /// be reached; the Recharge screen then falls back to the static
  /// pack list and hides the first-recharge badge.
  Future<Map<String, dynamic>?> playPacks() =>
      _json('GET', '/api/play/packs');

  /// Verifies a Google Play purchase server-side and credits the
  /// coins (worker: POST /api/play/verify). The server verifies the
  /// purchase token with Google before crediting anything, so the
  /// caller must only complete (consume) the purchase when this
  /// returns ok. Null on transport failure.
  Future<Map<String, dynamic>?> verifyPlayPurchase({
    required String productId,
    required String purchaseToken,
  }) =>
      _json('POST', '/api/play/verify', body: {
        'productId': productId,
        'purchaseToken': purchaseToken,
      });

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

  /// Sends a direct message and returns the raw server map, INCLUDING
  /// the error body when the send is rejected (e.g. `error:
  /// 'content_blocked' when the text trips the content filter). Null
  /// only means no response reached the app (offline / transport).
  /// Callers must check `result['ok'] == true`.
  Future<Map<String, dynamic>?> sendDirectMessageResult({
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
      returnErrorBody: true,
    );
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  Future<bool> sendDirectMessage({
    required String senderUserId,
    required String receiverUserId,
    required String text,
    String? imageKey,
  }) async {
    final value = await sendDirectMessageResult(
      senderUserId: senderUserId,
      receiverUserId: receiverUserId,
      text: text,
      imageKey: imageKey,
    );
    return value?['ok'] == true;
  }

  Future<bool> registerPushDevice({
    required String userId,
    required String token,
    required bool enabled,
  }) async {
    final value = await _json(
      'POST',
      '/api/push/device',
      body: <String, dynamic>{
        'user_id': userId,
        'token': token,
        'platform': 'android',
        if ((deviceKey?.trim() ?? '').isNotEmpty) 'device_key': deviceKey!.trim(),
        'enabled': enabled,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<bool> setMessagePushEnabled({
    required String userId,
    required bool enabled,
  }) async {
    final value = await _json(
      'POST',
      '/api/push/preferences',
      body: <String, dynamic>{
        'user_id': userId,
        'message_enabled': enabled,
      },
      returnErrorBody: true,
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
          'idempotency_key': _idempotencyKey(),
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> weeklySignInStatus({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/rewards/weekly-signin?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> claimWeeklySignIn({
    required String userId,
  }) =>
      _json(
        'POST',
        '/api/rewards/weekly-signin',
        body: <String, dynamic>{'user_id': userId},
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

  Future<bool> leaveGameRoom({
    required String roomId,
    required String userId,
  }) async {
    final value = await _json(
      'POST',
      '/api/game-rooms/${Uri.encodeComponent(roomId)}/leave',
      body: <String, dynamic>{'user_id': userId},
      returnErrorBody: true,
    );
    return value?['ok'] == true;
  }

  Future<List<Map<String, dynamic>>> gameRoomMessages({
    required String roomId,
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/game-rooms/${Uri.encodeComponent(roomId)}/messages?user_id=${Uri.encodeQueryComponent(userId)}',
      returnErrorBody: true,
    );
    final rows = value?['messages'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Sends a game-room message and returns the raw server map,
  /// INCLUDING the error body when the send is rejected (e.g. `error:
  /// 'content_blocked' when the text trips the content filter). Null
  /// only means no response reached the app (offline / transport).
  /// Callers must check `result['ok'] == true`.
  Future<Map<String, dynamic>?> sendGameRoomMessageResult({
    required String roomId,
    required String userId,
    required String text,
  }) async {
    final value = await _json(
      'POST',
      '/api/game-rooms/${Uri.encodeComponent(roomId)}/messages',
      body: <String, dynamic>{
        'user_id': userId,
        'text': text,
      },
      returnErrorBody: true,
    );
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  Future<bool> sendGameRoomMessage({
    required String roomId,
    required String userId,
    required String text,
  }) async {
    final value = await sendGameRoomMessageResult(
      roomId: roomId,
      userId: userId,
      text: text,
    );
    return value?['ok'] == true;
  }

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
    final value = await _json(
      'GET',
      '/api/gifts/catalog?user_id=${Uri.encodeQueryComponent(userId)}',
      returnErrorBody: true,
    );
    final rows = value?['gifts'];
    final serverGifts = rows is List
        ? rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final featured = _featuredRoomGifts
        .map((gift) => Map<String, dynamic>.from(gift))
        .toList(growable: false);
    // The local featured list is only an offline fallback. When the Worker
    // returns a catalog (even an empty one), it is authoritative: this makes
    // Owner edits and deletes take effect rather than resurrecting local gifts.
    if (rows is List) return serverGifts;
    return featured;
  }

  /// Combined gifts + diamonds + coins (Vinay, 2026-11-21 — "Har user ka
  /// alag combined API rakh"): ONE session-scoped call every 3s carrying the
  /// full priced catalog + this user's live coin/diamond balances + recent
  /// histories. Same pattern as [fruitPartyState]/[greedyGirlState]: the
  /// server derives the user from the session, so no user_id is sent. The
  /// standalone [giftCatalog]/[diamondsHistory]/[coinsHistory] calls keep
  /// working unchanged (full histories on open); this is the live source.
  Future<Map<String, dynamic>?> giftsCombinedState() async {
    final value = await _json(
      'GET',
      '/api/gifts/combined',
      returnErrorBody: true,
    );
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
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

  // DM gift (Vinay, 2026-11-21): roomId is optional — a gift sent from
  // the 1-to-1 DM chat has no room, so the key is left out entirely and
  // the server records it as a DM gift (room_id null).
  Future<Map<String, dynamic>?> sendGift({
    String? roomId,
    required String senderUserId,
    required String receiverUserId,
    required String giftId,
    required int coinCost,
    int count = 1,
  }) =>
      _json(
        'POST',
        '/api/gifts/send',
        // Return server rejection codes so the room can show the actual reason.
        returnErrorBody: true,
        body: <String, dynamic>{
          if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
          'sender_user_id': senderUserId,
          'receiver_user_id': receiverUserId,
          'gift_id': giftId,
          'coin_cost': coinCost,
          'count': count,
          'idempotency_key': _idempotencyKey(),
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
      _json(
        'GET',
        '/api/cosmetics/${Uri.encodeComponent(userId)}',
        returnErrorBody: true,
      );

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

  Future<Map<String, dynamic>?> vipDailyRewardStatus({
    required String userId,
  }) =>
      _json('GET', '/api/vip/${Uri.encodeComponent(userId)}/daily-reward');

  Future<Map<String, dynamic>?> claimVipDailyReward({
    required String userId,
  }) =>
      _json(
        'POST',
        '/api/vip/${Uri.encodeComponent(userId)}/daily-reward',
        body: <String, dynamic>{},
        returnErrorBody: true,
      );

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
          'pin': pin,
          'idempotency_key': _idempotencyKey(),
        },
      );

  Future<Map<String, dynamic>?> ludoState({
    required String roomId,
    int? playerCount,
    String? colorPair,
  }) {
    // First joiner sets the table mode: ?player_count=2&color_pair=
    // red-yellow (or blue-green). 4-player sends no color_pair.
    final query = <String, String>{};
    if (playerCount != null) query['player_count'] = '$playerCount';
    if (colorPair != null && colorPair.isNotEmpty) {
      query['color_pair'] = colorPair;
    }
    final queryString = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/ludo'
          '${queryString.isEmpty ? '' : '?$queryString'}',
      returnErrorBody: true,
    );
  }

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

  /// Combined Girls Party state (round + timer + config + wallet +
  /// my bets + history) in ONE call. The screen polls this every 3s
  /// (Vinay, 2026-11-21) instead of separate state calls — same pattern
  /// as [roomStateOrNull]; the 250ms local clock keeps the countdown
  /// ticking between syncs and a poll only corrects it to server time.
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

  /// Combined Greedy Girl state (round + timer + config + wallet +
  /// my bets + history) in ONE call. The screen polls this every 3s
  /// (Vinay, 2026-11-21) instead of separate state calls — same pattern
  /// as [roomStateOrNull]; the 250ms local clock keeps the countdown
  /// ticking between syncs and a poll only corrects it to server time.
  Future<Map<String, dynamic>?> greedyGirlState() =>
      _json(
        'GET',
        '/api/games/greedy-girl/state',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> greedyGirlBet({
    required String userId,
    required String foodKey,
    required int amount,
    required String requestId,
  }) =>
      _json(
        'POST',
        '/api/games/greedy-girl/bet',
        returnErrorBody: true,
        body: <String, dynamic>{
          'user_id': userId,
          'food_key': foodKey,
          'amount': amount,
          'request_id': requestId,
          'compact_response': true,
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

  /// Members list, or null when the request failed. The worker answers
  /// 403 `room_membership_required` when the caller's own membership row
  /// is gone (kicked), so null here is the kick signal — unlike an empty
  /// list, which also happens when a 200-member room cuts the caller off
  /// (the worker caps the list at 200 rows). Used only by the room
  /// screen's self-kick detection; other callers keep [roomMembers].
  Future<List<Map<String, dynamic>>?> roomMembersOrNull({
    required String roomId,
  }) async {
    final value = await _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/members',
    );
    if (value == null) return null;
    final rows = value['members'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Combined room state (members + messages + controls + gift events),
  /// or null when the request failed. The worker answers 403
  /// `room_membership_required` when the caller's own membership row
  /// is gone (kicked), so null here is the kick signal — unlike an
  /// empty members list, which also happens when a 200-member room cuts
  /// the caller off (the worker caps the list at 200 rows). Mirrors
  /// the null-on-failure contract of [roomMembersOrNull]. The room
  /// screen polls this every 3s instead of the four separate
  /// members/messages/controls/gift-events calls; [after]/[afterId]
  /// are the gift-events incremental cursor, as in [roomGiftEvents].
  Future<Map<String, dynamic>?> roomStateOrNull({
    required String roomId,
    int after = 0,
    String afterId = '',
    String? period,
  }) async {
    final value = await _json(
      'GET',
      '/api/rooms/${Uri.encodeComponent(roomId)}/state'
      '?after=$after&after_id=${Uri.encodeQueryComponent(afterId)}'
      '${period == null ? '' : '&period=${Uri.encodeQueryComponent(period)}'}',
    );
    if (value == null) return null;
    return Map<String, dynamic>.from(value);
  }

  /// Top-of-room banner feed (Vinay, 2026-11-22): the cross-room
  /// banners every room's 2-line top banner shows — recent Rocket
  /// launches, big gifts and Lucky wins from any room. Returns null
  /// when the check itself fails (network/server error); the caller
  /// keeps the current banner queue.
  Future<List<Map<String, dynamic>>?> globalBanners() async {
    try {
      final value = await _json('GET', '/api/banners/global');
      if (value == null) return null;
      final items = value['items'];
      if (items is! List) return <Map<String, dynamic>>[];
      return items
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Whether the server recorded a kick marker for this user in this room.
  /// Returns null when the check itself fails (network/server error).
  /// (Room audit 2026-11-20 — distinguishes a real kick from a
  /// presence-timeout prune after the app was backgrounded >30s.)
  Future<bool?> roomKickStatus({
    required String roomId,
    required String userId,
  }) async {
    try {
      final value = await _json(
        'GET',
        '/api/rooms/${Uri.encodeComponent(roomId)}/kick-status'
        '?user_id=${Uri.encodeQueryComponent(userId)}',
      );
      if (value == null) return null;
      final kicked = value['kicked'];
      if (kicked is bool) return kicked;
      return kicked?.toString() == '1';
    } catch (_) {
      // A network drop is not a kick — the caller keeps the existing
      // poll behaviour instead of acting on an unknown state.
      return null;
    }
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

  /// Call mute + ringtone (Vinay, 2026-11-21): mute all incoming
  /// calls, mute calls from selected persons, pick the caller tune.
  /// Stored server-side so the setting survives reinstall.
  Future<Map<String, dynamic>?> callMuteSettings({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/calls/mute-settings?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> setCallMuteSettings({
    required String userId,
    bool? muteAll,
    String? ringtone,
  }) =>
      _json(
        'POST',
        '/api/calls/mute-settings',
        body: <String, dynamic>{
          'user_id': userId,
          if (muteAll != null) 'mute_all': muteAll,
          if (ringtone != null) 'ringtone': ringtone,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> muteCallUser({
    required String userId,
    required String mutedUserId,
  }) =>
      _json(
        'POST',
        '/api/calls/mute-user',
        body: <String, dynamic>{
          'user_id': userId,
          'muted_user_id': mutedUserId,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> unmuteCallUser({
    required String userId,
    required String mutedUserId,
  }) =>
      _json(
        'POST',
        '/api/calls/unmute-user',
        body: <String, dynamic>{
          'user_id': userId,
          'muted_user_id': mutedUserId,
        },
        returnErrorBody: true,
      );

  Future<List<Map<String, dynamic>>> mutedCallUsers({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/calls/muted-users?user_id=${Uri.encodeQueryComponent(userId)}',
      returnErrorBody: true,
    );
    final rows = value?['users'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Inbox message mute + delete (Vinay, 2026-11-21): mute messages
  /// from selected persons from the inbox long-press menu, and delete
  /// a whole conversation. Stored server-side so the setting survives
  /// reinstall — mirrors the call-mute methods above.
  Future<Map<String, dynamic>?> muteMessageUser({
    required String userId,
    required String mutedUserId,
  }) =>
      _json(
        'POST',
        '/api/messages/mute-user',
        body: <String, dynamic>{
          'user_id': userId,
          'muted_user_id': mutedUserId,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> unmuteMessageUser({
    required String userId,
    required String mutedUserId,
  }) =>
      _json(
        'POST',
        '/api/messages/unmute-user',
        body: <String, dynamic>{
          'user_id': userId,
          'muted_user_id': mutedUserId,
        },
        returnErrorBody: true,
      );

  Future<List<Map<String, dynamic>>> mutedMessageUsers({
    required String userId,
  }) async {
    final value = await _json(
      'GET',
      '/api/messages/muted-users?user_id=${Uri.encodeQueryComponent(userId)}',
      returnErrorBody: true,
    );
    final rows = value?['users'];
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>?> deleteConversation({
    required String userId,
    required String otherUserId,
  }) =>
      _json(
        'POST',
        '/api/messages/conversation/delete',
        body: <String, dynamic>{
          'user_id': userId,
          'other_user_id': otherUserId,
        },
        returnErrorBody: true,
      );

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

  Future<bool> markActivityMessagesRead({
    required String userId,
    required List<String> itemIds,
  }) async {
    if (itemIds.isEmpty) return true;
    final value = await _json(
      'POST',
      '/api/messages/activity/read',
      body: <String, dynamic>{
        'user_id': userId,
        'item_ids': itemIds,
      },
      returnErrorBody: true,
    );
    return value?['ok'] == true;
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

  /// Look a user up by the public ID shown on their profile, for Block by ID.
  /// Returns null when no (visible) user has that ID.
  Future<Map<String, dynamic>?> userByPublicId(String publicId) async {
    final value = await _json(
      'GET',
      '/api/users/by-public-id?public_id=${Uri.encodeQueryComponent(publicId)}',
    );
    if (value?['ok'] != true) return null;
    final user = value?['user'];
    return user is Map ? Map<String, dynamic>.from(user) : null;
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

  Future<Map<String, dynamic>?> cpDisconnectRequest({
    required String userId,
  }) =>
      _json(
        'POST',
        '/api/cp/disconnect/request',
        body: <String, dynamic>{'user_id': userId},
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> cpDisconnectRespond({
    required String userId,
    required bool accept,
  }) =>
      _json(
        'POST',
        '/api/cp/disconnect/respond',
        body: <String, dynamic>{
          'user_id': userId,
          'accept': accept,
        },
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> cpHeartbeat({
    required String userId,
    required String action,
    String? choice,
  }) =>
      _json(
        'POST',
        '/api/cp/heartbeat',
        body: <String, dynamic>{
          'user_id': userId,
          'action': action,
          if (choice != null) 'choice': choice,
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

  Future<Map<String, dynamic>?> inviteSummary({
    required String userId,
  }) =>
      _json(
        'GET',
        '/api/invite/summary?user_id=${Uri.encodeQueryComponent(userId)}',
        returnErrorBody: true,
      );

  Future<Map<String, dynamic>?> bindInvitationCode({
    required String userId,
    required String invitationCode,
  }) =>
      _json(
        'POST',
        '/api/invite/bind',
        body: <String, dynamic>{
          'user_id': userId,
          'invitation_code': invitationCode,
          // One device, one ID uses an invite code (Vinay, 2026-11-23):
          // the server rejects a second account binding from this device.
          if ((deviceKey?.trim() ?? '').isNotEmpty)
            'device_key': deviceKey!.trim(),
        },
        returnErrorBody: true,
      );

  /// Withdraw referral dollars to a coin seller / merchant (worker:
  /// POST /api/invite/withdraw). One fresh idempotency key per attempt
  /// so a retry of the same attempt returns the original withdrawal
  /// instead of paying twice.
  Future<Map<String, dynamic>?> withdrawInviteDollars({
    required String userId,
    required String providerUserId,
    required int amountUsdCents,
  }) =>
      _json(
        'POST',
        '/api/invite/withdraw',
        body: <String, dynamic>{
          'user_id': userId,
          'provider_user_id': providerUserId,
          'amount_usd_cents': amountUsdCents,
          'idempotency_key': _idempotencyKey(),
        },
        returnErrorBody: true,
      );


}
