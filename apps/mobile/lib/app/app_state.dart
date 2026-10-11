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
  });

  final String id;
  final String name;
  final String ownerName;
  final String ownerUserId;
  final int online;
  final int seatCount;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.name,
    required this.preview,
    this.unread = 0,
  });

  final String id;
  final String name;
  final String preview;
  final int unread;
}

class AppState extends ChangeNotifier {
  AppState();

  final BackendApi backend = const BackendApi();

  String userId = '91000001';
  String displayName = 'DarkVibeX User';
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
  int vipLevel = 0;
  int vipExpBalance = 0;
  int vipTotalReceivedCoins = 0;
  DateTime? vipActiveUntil;
  String? customVipId;
  String? vipError;
  final Map<String, bool> vipPreferences = <String, bool>{};
  bool get vipAnonymousEverywhere =>
      vipPreferences['anonymous_everywhere'] ?? false;

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

  final List<DirectMessage> messages = <DirectMessage>[
    const DirectMessage(id: '90001', name: 'Mika', preview: 'See you in the room 👋', unread: 2),
    const DirectMessage(id: '90002', name: 'Sara', preview: 'Gift received, thanks!'),
  ];

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
    } catch (_) {
      googleSignInReady = false;
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
      if (error.code == GoogleSignInExceptionCode.canceled) {
        authError = null;
      } else {
        authError = 'Google Login failed. Please try again.';
      }
      return false;
    } catch (_) {
      authError = 'Google Login failed. Please try again.';
      return false;
    } finally {
      signingIn = false;
      notifyListeners();
    }
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
    authProvider = provider;
    backendConnected = true;
    isAuthenticated = true;

    userId = user['id']?.toString() ?? userId;
    displayName = user['display_name']?.toString() ?? displayName;
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
            )));
    }
  }

  Future<void> signOut() async {
    if (authProvider == 'google') {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    sessionToken = null;
    authProvider = null;
    backendConnected = false;
    isAuthenticated = false;
    authError = null;
    userId = '91000001';
    displayName = 'DarkVibeX User';
    coins = 2500000;
    diamonds = 120;
    vipLevel = 0;
    vipExpBalance = 0;
    vipTotalReceivedCoins = 0;
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

  Future<RoomSummary> createRoom(String name, {int seatCount = 12}) async {
    final cleanName = name.trim().isEmpty ? 'New Room' : name.trim();
    final allowedSeats =
        seatCount.clamp(8, VipPolicy.maxRoomSeats(vipLevel)).toInt();
    String roomId = (100000 + rooms.length + 1).toString();

    if (backendConnected) {
      final remoteId = await backend.createRoom(
        ownerUserId: userId,
        ownerName: displayName,
        name: cleanName,
        seatCount: allowedSeats,
      );
      if (remoteId != null && remoteId.isNotEmpty) roomId = remoteId;
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
