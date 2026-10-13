import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../infra/backend_api.dart';
import '../vip/vip_policy.dart';

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerUserId,
    required this.online,
    this.seatCount = 12,
    this.avatarKey,
  });

  final String id;
  final String name;
  final String ownerName;
  final String ownerUserId;
  final int online;
  final int seatCount;
  final String? avatarKey;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.name,
    required this.preview,
    this.unread = 0,
    this.avatarKey,
  });

  final String id;
  final String name;
  final String preview;
  final int unread;
  final String? avatarKey;
}

class AppState extends ChangeNotifier {
  AppState();

  final BackendApi backend = const BackendApi();

  String userId = '91000001';
  String displayName = 'DarkVibeX User';
  String? avatarKey;
  String? sessionToken;
  String? authProvider;
  bool backendConnected = false;
  bool isInitializing = true;
  bool isAuthenticated = false;
  bool signingIn = false;
  bool googleSignInReady = false;
  String? authError;
  String? _googleWebClientId;

  int coins = 2500000;
  int diamonds = 120;
  int idLevel = 0;
  int idLevelExp = 0;
  int idLevelExpToNext = 10000;
  String? activeFrameId;
  String? activeVehicleId;
  int vipLevel = 0;
  int vipExpBalance = 0;
  int vipTotalReceivedCoins = 0;
  int vipFreeSayHiRemaining = VipPolicy.freeSayHiUses;
  DateTime? vipActiveUntil;
  String? customVipId;
  String? vipError;
  final Map<String, bool> vipPreferences = <String, bool>{};
  bool get vipAnonymousEverywhere =>
      hasVipPrivilege('anonymous_everywhere') &&
      (vipPreferences['anonymous_everywhere'] ?? false);

  bool get vipIsActive =>
      vipLevel > 0 &&
      (vipActiveUntil == null || vipActiveUntil!.isAfter(DateTime.now()));

  bool hasVipPrivilege(String id) {
    if (!vipIsActive) return false;
    for (final privilege in VipPolicy.privileges) {
      if (privilege.id == id) return privilege.isUnlockedAt(vipLevel);
    }
    return false;
  }

  final List<Map<String, dynamic>> walletLedger = <Map<String, dynamic>>[];

  final List<RoomSummary> rooms = <RoomSummary>[
    const RoomSummary(id: '100001', name: 'Dark Lounge', ownerName: 'Alex', ownerUserId: '92000001', online: 18, seatCount: 12),
    const RoomSummary(id: '100002', name: 'Music Night', ownerName: 'Mika', ownerUserId: '92000002', online: 9, seatCount: 10),
    const RoomSummary(id: '100003', name: 'Chill Zone', ownerName: 'Sara', ownerUserId: '92000003', online: 24, seatCount: 15),
  ];

  final List<DirectMessage> messages = <DirectMessage>[];

  Future<void> initialize() async {
    isInitializing = true;
    authError = null;
    notifyListeners();

    try {
      if (!backend.configured) {
        authError = 'Server is not configured.';
        return;
      }

      final config = await backend.googleAuthConfig();
      _googleWebClientId = config?['google_web_client_id']?.toString().trim();

      if (_googleWebClientId != null && _googleWebClientId!.isNotEmpty) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleWebClientId,
        );
        googleSignInReady = true;

        final lightweight = GoogleSignIn.instance.attemptLightweightAuthentication();
        if (lightweight != null) {
          final account = await lightweight;
          if (account != null) {
            await _completeGoogleSignIn(account, notify: false);
          }
        }
      }
    } on GoogleSignInException catch (error) {
      googleSignInReady = false;
      authError = _googleSignInErrorMessage(error);
      debugPrint(
        'DarkVibeX Google Sign-In initialization failed: '
        '${error.code} ${error.description ?? ''}',
      );
    } catch (error) {
      googleSignInReady = false;
      authError = 'Google Login could not be initialized. Please try again.';
      debugPrint('DarkVibeX Google Sign-In initialization failed: $error');
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    if (signingIn) return false;
    signingIn = true;
    authError = null;
    notifyListeners();

    try {
      if (!googleSignInReady) {
        final config = await backend.googleAuthConfig();
        _googleWebClientId = config?['google_web_client_id']?.toString().trim();
        if (_googleWebClientId == null || _googleWebClientId!.isEmpty) {
          authError = 'Google Login is not configured on the server yet.';
          return false;
        }
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleWebClientId,
        );
        googleSignInReady = true;
      }

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        authError = 'Google Login is not supported on this device.';
        return false;
      }

      final account = await GoogleSignIn.instance.authenticate();
      return await _completeGoogleSignIn(account);
    } on GoogleSignInException catch (error) {
      authError = _googleSignInErrorMessage(error);
      debugPrint(
        'DarkVibeX Google Sign-In failed: '
        '${error.code} ${error.description ?? ''}',
      );
      return false;
    } catch (error) {
      authError = 'Google Login failed. Please try again.';
      debugPrint('DarkVibeX Google Sign-In failed: $error');
      return false;
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  String _googleSignInErrorMessage(GoogleSignInException error) {
    final description = error.description?.trim();
    final detail = description == null || description.isEmpty
        ? ''
        : ' ($description)';

    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Google account was selected, but Android could not complete sign-in. '
        'Check the Android OAuth credential for package com.darkvibex.app and '
        'release SHA-1 15:43:D7:77:7C:86:A8:1B:79:6C:A4:22:23:77:B1:DA:4E:53:A8:BF$detail',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google Login Android OAuth configuration does not match this app build$detail',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google Sign-In service is unavailable or misconfigured on this device$detail',
      GoogleSignInExceptionCode.interrupted =>
        'Google Login was interrupted before it could finish$detail',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google Login UI could not be opened$detail',
      _ => 'Google Login failed$detail',
    };
  }

  Future<bool> continueAsGuest() async {
    if (signingIn) return false;
    signingIn = true;
    authError = null;
    notifyListeners();

    try {
      final session = await backend.startGuestSession(
        userId: userId,
        displayName: displayName,
      );
      return await _applySession(session, provider: 'guest');
    } catch (_) {
      authError = 'Could not connect to DarkVibeX.';
      return false;
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<bool> _completeGoogleSignIn(
    GoogleSignInAccount account, {
    bool notify = true,
  }) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      authError = 'Google did not return a valid sign-in token.';
      if (notify) notifyListeners();
      return false;
    }

    final session = await backend.startGoogleSession(idToken: idToken);
    final backendError = session?['error']?.toString().trim() ?? '';
    if (backendError.isNotEmpty) {
      debugPrint('DarkVibeX Google session rejected: $backendError');
      authError = switch (backendError) {
        'session_secret_not_configured' =>
          'Login server setup is incomplete. Please try again after the server update.',
        'google_auth_not_configured' =>
          'Google Login is not configured on the server yet.',
        'invalid_google_audience' =>
          'Google Login configuration does not match this app build.',
        'invalid_google_token' =>
          'Google sign-in token was rejected. Please sign in again.',
        'google_email_not_verified' =>
          'This Google account email is not verified.',
        _ => 'Google Login reached the server, but the session could not be created.',
      };
      if (notify) notifyListeners();
      return false;
    }
    return _applySession(session, provider: 'google', notify: notify);
  }

  Future<bool> _applySession(
    Map<String, dynamic>? session, {
    required String provider,
    bool notify = true,
  }) async {
    final token = session?['token']?.toString();
    final user = session?['user'];

    if (token == null || token.isEmpty || user is! Map) {
      authError = 'Login could not be completed.';
      backendConnected = false;
      isAuthenticated = false;
      if (notify) notifyListeners();
      return false;
    }

    sessionToken = token;
    BackendApi.sessionToken = token;
    authProvider = provider;
    backendConnected = true;
    isAuthenticated = true;

    userId = user['id']?.toString() ?? userId;
    displayName = user['display_name']?.toString() ?? displayName;
    avatarKey = user['avatar_key']?.toString();
    coins = int.tryParse(user['coins']?.toString() ?? '') ?? coins;
    diamonds = int.tryParse(user['diamonds']?.toString() ?? '') ?? diamonds;
    vipLevel = int.tryParse(user['vip_level']?.toString() ?? '') ?? vipLevel;

    await _loadRemoteData();
    if (notify) notifyListeners();
    return true;
  }

  Future<void> _loadRemoteData() async {
    await refreshWallet(notify: false);
    await refreshVip(notify: false);
    await refreshIdLevel(notify: false);
    await refreshCosmetics(notify: false);

    final remoteRooms = await backend.listRooms();
    if (remoteRooms.isNotEmpty) {
      rooms
        ..clear()
        ..addAll(remoteRooms.map((row) => RoomSummary(
              id: row['id']?.toString() ?? '',
              name: row['name']?.toString() ?? 'Room',
              ownerName: row['owner_name']?.toString() ?? '',
              ownerUserId: row['owner_user_id']?.toString() ?? '',
              online: int.tryParse(row['online']?.toString() ?? '') ?? 0,
              seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ?? 12,
              avatarKey: row['avatar_key']?.toString(),
            )));
    }

    await refreshInbox(notify: false);
  }

  Future<void> refreshRooms({bool notify = true}) async {
    if (!backendConnected) return;
    final remoteRooms = await backend.listRooms();
    if (remoteRooms.isNotEmpty) {
      rooms
        ..clear()
        ..addAll(remoteRooms.map((row) => RoomSummary(
              id: row['id']?.toString() ?? '',
              name: row['name']?.toString() ?? 'Room',
              ownerName: row['owner_name']?.toString() ?? '',
              ownerUserId: row['owner_user_id']?.toString() ?? '',
              online: int.tryParse(row['online']?.toString() ?? '') ?? 0,
              seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ?? 12,
              avatarKey: row['avatar_key']?.toString(),
            )));
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshInbox({bool notify = true}) async {
    if (!backendConnected) return;
    final remoteInbox = await backend.inbox(userId: userId);
    messages
      ..clear()
      ..addAll(remoteInbox.map((row) => DirectMessage(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? 'User',
            preview: row['preview']?.toString() ?? '',
            unread: int.tryParse(row['unread']?.toString() ?? '') ?? 0,
            avatarKey: row['avatar_key']?.toString(),
          )));
    if (notify) notifyListeners();
  }

  Future<void> signOut() async {
    if (authProvider == 'google') {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    sessionToken = null;
    BackendApi.sessionToken = null;
    authProvider = null;
    backendConnected = false;
    isAuthenticated = false;
    authError = null;
    userId = '91000001';
    displayName = 'DarkVibeX User';
    avatarKey = null;
    messages.clear();
    coins = 2500000;
    diamonds = 120;
    idLevel = 0;
    idLevelExp = 0;
    idLevelExpToNext = 10000;
    vipLevel = 0;
    vipExpBalance = 0;
    vipTotalReceivedCoins = 0;
    activeFrameId = null;
    activeVehicleId = null;
    vipFreeSayHiRemaining = VipPolicy.freeSayHiUses;
    vipActiveUntil = null;
    customVipId = null;
    vipError = null;
    vipPreferences.clear();
    walletLedger.clear();
    notifyListeners();
  }

  Future<void> refreshWallet({bool notify = true}) async {
    if (!backendConnected) return;
    final value = await backend.wallet(userId: userId);
    final wallet = value?['wallet'];
    if (wallet is Map) {
      coins = int.tryParse(wallet['coins']?.toString() ?? '') ?? coins;
      diamonds = int.tryParse(wallet['diamonds']?.toString() ?? '') ?? diamonds;
      vipLevel = int.tryParse(wallet['vip_level']?.toString() ?? '') ?? vipLevel;
    }
    final rows = value?['ledger'];
    if (rows is List) {
      walletLedger
        ..clear()
        ..addAll(
          rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row)),
        );
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshCosmetics({bool notify = true}) async {
    if (!backendConnected) return;
    final value = await backend.cosmetics(userId: userId);
    final rows = value?['owned'];
    if (rows is List) {
      activeFrameId = null;
      activeVehicleId = null;
      for (final row in rows.whereType<Map>()) {
        if (row['active'] != true && row['active']?.toString() != '1') continue;
        if (row['kind']?.toString() == 'frame') activeFrameId = row['item_id']?.toString();
        if (row['kind']?.toString() == 'vehicle') activeVehicleId = row['item_id']?.toString();
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshVip({bool notify = true}) async {
    if (!backendConnected) return;
    final value = await backend.vipStatus(userId: userId);
    final vip = value?['vip'];
    if (vip is Map) {
      vipLevel = int.tryParse(vip['level']?.toString() ?? '') ?? vipLevel;
      vipExpBalance =
          int.tryParse(vip['exp_balance']?.toString() ?? '') ?? vipExpBalance;
      vipTotalReceivedCoins =
          int.tryParse(vip['total_received_coins']?.toString() ?? '') ??
              vipTotalReceivedCoins;
      final activeUntilMs =
          int.tryParse(vip['active_until']?.toString() ?? '');
      vipActiveUntil = activeUntilMs == null || activeUntilMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(activeUntilMs);
      customVipId = vip['custom_id']?.toString();
      final prefs = vip['preferences'];
      vipFreeSayHiRemaining = int.tryParse(vip['free_say_hi_remaining']?.toString() ?? '') ?? vipFreeSayHiRemaining;
      if (prefs is Map) {
        vipPreferences
          ..clear()
          ..addEntries(
            prefs.entries.map(
              (entry) => MapEntry(
                entry.key.toString(),
                entry.value == true ||
                    entry.value == 1 ||
                    entry.value.toString() == 'true',
              ),
            ),
          );
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> refreshIdLevel({bool notify = true}) async {
    if (!backendConnected) return;
    final value = await backend.idLevelStatus(userId: userId);
    final level = value?['level'];
    if (level is Map) {
      idLevel = int.tryParse(level['level']?.toString() ?? '') ?? idLevel;
      idLevelExp = int.tryParse(level['exp']?.toString() ?? '') ?? idLevelExp;
      idLevelExpToNext = int.tryParse(level['exp_to_next']?.toString() ?? '') ?? idLevelExpToNext;
    }
    if (notify) notifyListeners();
  }

  bool vipPreference(String key) => vipPreferences[key] ?? false;

  Future<bool> setVipPreference(String key, bool enabled) async {
    vipError = null;
    if (!backendConnected) {
      vipPreferences[key] = enabled;
      notifyListeners();
      return true;
    }
    final result = await backend.updateVipPreference(
      userId: userId,
      key: key,
      enabled: enabled,
    );
    if (result?['ok'] != true) {
      vipError = result?['error']?.toString() ?? 'VIP setting could not be saved.';
      notifyListeners();
      return false;
    }
    vipPreferences[key] = enabled;
    notifyListeners();
    return true;
  }

  Future<bool> sendVipSayHi({required String receiverUserId, required String message}) async {
    vipError = null;
    if (!backendConnected || !hasVipPrivilege('free_say_hi')) {
      vipError = 'Active VIP5 is required for Free Say Hi.';
      notifyListeners();
      return false;
    }
    final result = await backend.sendVipSayHi(
      userId: userId,
      receiverUserId: receiverUserId,
      message: message,
    );
    if (result?['ok'] != true) {
      vipError = result?['error']?.toString() ?? 'Free Say Hi could not be sent.';
      notifyListeners();
      return false;
    }
    final usage = result?['usage'];
    if (usage is Map) {
      vipFreeSayHiRemaining = int.tryParse(usage['remaining']?.toString() ?? '') ?? vipFreeSayHiRemaining;
    }
    await refreshInbox(notify: false);
    notifyListeners();
    return true;
  }

  Future<bool> changeVipUniqueId(String value) async {
    vipError = null;
    final clean = value.trim();
    if (clean.isEmpty) return false;
    if (!backendConnected) {
      customVipId = clean;
      notifyListeners();
      return true;
    }
    final result = await backend.changeVipUniqueId(
      userId: userId,
      customId: clean,
    );
    if (result?['ok'] != true) {
      vipError = result?['error']?.toString() ?? 'Unique ID could not be changed.';
      notifyListeners();
      return false;
    }
    customVipId = result?['custom_id']?.toString() ?? clean;
    await refreshVip(notify: false);
    notifyListeners();
    return true;
  }

  void setAvatarKey(String? key) {
    avatarKey = key;
    notifyListeners();
  }

  void setRoomAvatarKey(String roomId, String key) {
    final index = rooms.indexWhere((room) => room.id == roomId);
    if (index < 0) return;
    final room = rooms[index];
    rooms[index] = RoomSummary(
      id: room.id, name: room.name, ownerName: room.ownerName,
      ownerUserId: room.ownerUserId, online: room.online,
      seatCount: room.seatCount, avatarKey: key,
    );
    notifyListeners();
  }

  Future<RoomSummary> createRoom(String name, {int seatCount = 12}) async {
    final cleanName = name.trim().isEmpty ? 'New Room' : name.trim();
    final allowedSeats =
        seatCount.clamp(8, VipPolicy.maxRoomSeats(vipLevel)).toInt();
    if (!backendConnected) {
      throw StateError('Server connection is required to create a room.');
    }
    final roomId = await backend.createRoom(
      ownerUserId: userId,
      ownerName: displayName,
      name: cleanName,
      seatCount: allowedSeats,
    );
    if (roomId == null || roomId.isEmpty) {
      throw StateError('The server could not create this room.');
    }

    final room = RoomSummary(
      id: roomId,
      name: cleanName,
      ownerName: displayName,
      ownerUserId: userId,
      online: 1,
      seatCount: allowedSeats,
    );
    rooms.insert(0, room);
    notifyListeners();
    return room;
  }

  bool spendCoins(int amount) {
    if (amount <= 0 || amount > coins) return false;
    coins -= amount;
    notifyListeners();
    return true;
  }

  void addCoins(int amount) {
    if (amount <= 0) return;
    coins += amount;
    notifyListeners();
  }

  void addDiamonds(int amount) {
    if (amount <= 0) return;
    diamonds += amount;
    notifyListeners();
  }

  void setCoinBalance(int value) {
    if (value < 0) return;
    coins = value;
    notifyListeners();
  }
}
