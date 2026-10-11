import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../infra/backend_api.dart';

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
  bool facebookSignInReady = false;
  String? authError;
  String? _googleWebClientId;

  int coins = 2500000;
  int diamonds = 120;
  int vipLevel = 1;
  final List<Map<String, dynamic>> walletLedger = <Map<String, dynamic>>[];
  final List<String> recentRoomIds = <String>[];

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

      final config = await backend.authConfig();
      _googleWebClientId = config?['google_web_client_id']?.toString().trim();
      facebookSignInReady = config?['facebook_enabled'] == true;

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
        final config = await backend.authConfig();
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

  Future<bool> signInWithFacebook() async {
    if (signingIn) return false;
    signingIn = true;
    authError = null;
    notifyListeners();

    try {
      final config = await backend.authConfig();
      facebookSignInReady = config?['facebook_enabled'] == true;
      if (!facebookSignInReady) {
        authError = 'Facebook Login is not configured on the server yet.';
        return false;
      }

      final result = await FacebookAuth.instance.login(
        permissions: const <String>['public_profile'],
        loginBehavior: LoginBehavior.nativeWithFallback,
        loginTracking: LoginTracking.enabled,
      );
      if (result.status == LoginStatus.cancelled) {
        authError = null;
        return false;
      }
      final accessToken = result.accessToken?.tokenString;
      if (result.status != LoginStatus.success ||
          accessToken == null ||
          accessToken.isEmpty) {
        authError = result.message?.trim().isNotEmpty == true
            ? result.message
            : 'Facebook Login failed. Please try again.';
        return false;
      }

      final session =
          await backend.startFacebookSession(accessToken: accessToken);
      return await _applySession(session, provider: 'facebook');
    } catch (_) {
      authError = 'Facebook Login failed. Please try again.';
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
    if (authProvider == 'facebook') {
      try {
        await FacebookAuth.instance.logOut();
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
    vipLevel = 1;
    walletLedger.clear();
    recentRoomIds.clear();
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

  Future<RoomSummary> createRoom(String name, {int seatCount = 12}) async {
    final cleanName = name.trim().isEmpty ? 'New Room' : name.trim();
    String roomId = (100000 + rooms.length + 1).toString();

    if (backendConnected) {
      final remoteId = await backend.createRoom(
        ownerUserId: userId,
        ownerName: displayName,
        name: cleanName,
        seatCount: seatCount,
      );
      if (remoteId != null && remoteId.isNotEmpty) roomId = remoteId;
    }

    final room = RoomSummary(
      id: roomId,
      name: cleanName,
      ownerName: displayName,
      ownerUserId: userId,
      online: 1,
      seatCount: seatCount,
    );
    rooms.insert(0, room);
    notifyListeners();
    return room;
  }

  void markRoomVisited(String roomId) {
    if (roomId.isEmpty) return;
    recentRoomIds.remove(roomId);
    recentRoomIds.insert(0, roomId);
    if (recentRoomIds.length > 10) {
      recentRoomIds.removeRange(10, recentRoomIds.length);
    }
    notifyListeners();
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
