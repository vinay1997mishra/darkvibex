import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/darkvibex_localization.dart';
import '../infra/backend_api.dart';
import '../vip/vip_policy.dart';

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerUserId,
    required this.online,
    this.displayId,
    this.seatCount = 12,
    this.avatarKey,
    this.partyMode = 'Friends-making Party',
    this.roomMode = 'voice',
  });

  final String id;
  final String? displayId;
  String get roomNumber =>
      displayId?.trim().isNotEmpty == true ? displayId!.trim() : id;
  final String name;
  final String ownerName;
  final String ownerUserId;
  final int online;
  final int seatCount;
  final String? avatarKey;
  final String partyMode;
  final String roomMode;
}

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.name,
    required this.preview,
    this.unread = 0,
    this.avatarKey,
    this.createdAt = 0,
  });

  final String id;
  final String name;
  final String preview;
  final int unread;
  final String? avatarKey;
  final int createdAt;
}

class AppState extends ChangeNotifier {
  AppState();

  // Persist the signed-in account so normal app restarts do not return to Login.
  static const String _sessionTokenKey = 'darkvibex.session_token';
  static const String _sessionProviderKey = 'darkvibex.session_provider';
  static const String _sessionUserIdKey = 'darkvibex.session_user_id';
  static const String _sessionDisplayNameKey = 'darkvibex.session_display_name';
  static const String _sessionDateOfBirthKey = 'darkvibex.session_date_of_birth';
  static const String _deviceKeyPref = 'darkvibex.device_key';

  final BackendApi backend = const BackendApi();

  String userId = '91000001';
  String publicId = '9100001';
  String displayName = 'DarkVibeX User';
  String userRole = 'user';
  String? avatarKey;
  String? dateOfBirth;
  String countryCode = '';
  String countryName = '';
  String flagEmoji = '';
  String gender = '';
  String bio = '';
  int ageChangeCount = 0;
  int countryChangeCount = 0;
  int genderChangeCount = 0;
  int get ageChangesRemaining => (3 - ageChangeCount).clamp(0, 3).toInt();
  int get countryChangesRemaining => (3 - countryChangeCount).clamp(0, 3).toInt();
  int get genderChangesRemaining => (3 - genderChangeCount).clamp(0, 3).toInt();
  final ValueNotifier<String> languagePreference = ValueNotifier<String>('English');
  String? sessionToken;
  String? authProvider;
  bool backendConnected = false;
  bool isInitializing = true;
  bool isAuthenticated = false;
  // True only when a signed-in account is missing required profile fields.
  // Existing complete profiles proceed straight to HomeShell.
  bool needsProfileSetup = false;
  bool signingIn = false;
  bool googleSignInReady = false;
  bool _googleInitialized = false;
  String? authError;
  String? _googleWebClientId;

  int coins = 0;
  int diamonds = 120;

  bool weeklySignInReady = false;
  bool weeklySignInLoading = false;
  bool weeklySignInClaimedToday = false;
  int weeklySignInDay = 1;
  int weeklySignInClaimedThrough = 0;
  int weeklySignInLastReward = 0;
  int weeklySignInLastClaimedDay = 0;
  String? weeklySignInError;
  int idLevel = 0;
  int idLevelExp = 0;
  int idLevelExpToNext = 10000;
  String? activeFrameId;
  String? activeVehicleId;
  final Map<String, String> activeCosmetics = <String, String>{};

  String? activeCosmetic(String kind) => activeCosmetics[kind];
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

  // Only server-confirmed rooms or the owner's cached room belong in live UI.
  // Starting with demo rooms can show fake people/rooms during network failures.
  final List<RoomSummary> rooms = <RoomSummary>[];

  RoomSummary? minimizedRoom;
  VoidCallback? minimizedRoomResume;
  Future<void> Function()? minimizedRoomClose;

  final List<DirectMessage> messages = <DirectMessage>[];

  void showMinimizedRoom({
    required RoomSummary room,
    required VoidCallback onResume,
    required Future<void> Function() onClose,
  }) {
    minimizedRoom = room;
    minimizedRoomResume = onResume;
    minimizedRoomClose = onClose;
    notifyListeners();
  }

  void clearMinimizedRoom({String? roomId}) {
    if (roomId != null && minimizedRoom?.id != roomId) return;
    minimizedRoom = null;
    minimizedRoomResume = null;
    minimizedRoomClose = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    isInitializing = true;
    authError = null;
    notifyListeners();

    try {
      await _ensureDeviceKey();
      if (!backend.configured) {
        authError = 'Server is not configured.';
        return;
      }

      // A temporary profile/API failure must not abort the rest of startup or
      // replace the real Google sign-in error with a generic restore error.
      try {
        final restored = await _restorePersistedSession();
        if (restored) return;
      } catch (error) {
        BackendApi.sessionToken = null;
        debugPrint('DarkVibeX persisted session could not be checked: $error');
      }

      if (await _ensureGoogleSignInInitialized()) {
        final lightweight =
            GoogleSignIn.instance.attemptLightweightAuthentication();
        if (lightweight != null) {
          final account = await lightweight;
          if (account != null) {
            await _completeGoogleSignIn(account, notify: false);
          }
        }
      }
    } on GoogleSignInException catch (error) {
      authError = _googleSignInErrorMessage(error);
      debugPrint(
        'DarkVibeX Google Sign-In initialization failed: '
        '${error.code} ${error.description ?? ''}',
      );
    } catch (error) {
      authError =
          'Could not connect to DarkVibeX. Check your internet connection and try again.';
      debugPrint('DarkVibeX startup/auth check failed: $error');
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _ensureDeviceKey() async {
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString(_deviceKeyPref)?.trim() ?? '';
    if (value.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(24, (_) => random.nextInt(256));
      value = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_deviceKeyPref, value);
    }
    BackendApi.deviceKey = value;
  }

  Future<bool> _restorePersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_sessionTokenKey)?.trim() ?? '';
    final provider = prefs.getString(_sessionProviderKey)?.trim() ?? '';
    final savedUserId = prefs.getString(_sessionUserIdKey)?.trim() ?? '';
    final savedDisplayName =
        prefs.getString(_sessionDisplayNameKey)?.trim() ?? 'DarkVibeX User';

    if (savedUserId.isEmpty || provider.isEmpty) return false;

    if (token.isNotEmpty) {
      BackendApi.sessionToken = token;

      // Refresh first so closing/reopening the app never turns a normal
      // 7-day access-token expiry into a logout or a new user ID.
      final refreshed = await backend.refreshSession(token: token);
      if (refreshed?['ok'] == true &&
          refreshed?['token'] is String &&
          refreshed?['user'] is Map) {
        return _applySession(
          <String, dynamic>{
            'token': refreshed!['token'],
            'user': Map<String, dynamic>.from(refreshed['user'] as Map),
          },
          provider: provider,
          notify: false,
        );
      }

      // If refresh is temporarily unreachable, an unexpired token may still
      // restore normally. Never erase the saved login for a network/API hiccup.
      final profile = await backend.userProfile(userId: savedUserId);
      final user = profile?['user'];
      if (profile?['ok'] == true && user is Map) {
        return _applySession(
          <String, dynamic>{
            'token': token,
            'user': Map<String, dynamic>.from(user),
          },
          provider: provider,
          notify: false,
        );
      }

      final refreshError = refreshed?['error']?.toString().trim() ?? '';
      final profileError = profile?['error']?.toString().trim() ?? '';
      const terminalErrors = <String>{
        'user_not_found',
        'invalid_session',
        'session_expired',
        'unauthorized',
        'forbidden',
        'user_banned',
        'user_suspended',
      };
      final refreshIsTerminal = terminalErrors.contains(refreshError);
      final profileIsTerminal = terminalErrors.contains(profileError);
      if (refreshed == null &&
          profile == null ||
          (!refreshIsTerminal && !profileIsTerminal)) {
        throw StateError('Session restore temporarily unavailable');
      }
      // Only a confirmed invalid/revoked account or token is cleared.
      BackendApi.sessionToken = null;
    }

    // Guest users should keep the same account across normal app restarts.
    // If the saved JWT expired, silently mint a new one for the same guest ID.
    if (provider == 'guest') {
      final refreshed = await backend.startGuestSession(
        userId: savedUserId,
        displayName: savedDisplayName,
      );
      if (refreshed?['token'] != null && refreshed?['user'] is Map) {
        return _applySession(
          refreshed,
          provider: 'guest',
          notify: false,
        );
      }
    }

    await _clearPersistedSession();
    return false;
  }

  Future<void> _persistSession() async {
    final token = sessionToken?.trim() ?? '';
    final provider = authProvider?.trim() ?? '';
    if (token.isEmpty || provider.isEmpty || userId.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, token);
    await prefs.setString(_sessionProviderKey, provider);
    await prefs.setString(_sessionUserIdKey, userId);
    await prefs.setString(_sessionDisplayNameKey, displayName);
    final dob = dateOfBirth?.trim() ?? '';
    if (dob.isEmpty) {
      await prefs.remove(_sessionDateOfBirthKey);
    } else {
      await prefs.setString(_sessionDateOfBirthKey, dob);
    }
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_sessionProviderKey);
    await prefs.remove(_sessionUserIdKey);
    await prefs.remove(_sessionDisplayNameKey);
    await prefs.remove(_sessionDateOfBirthKey);
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (signingIn) return false;
    signingIn = true;
    authError = null;
    notifyListeners();
    try {
      final session = await backend.startEmailSession(
        email: email,
        password: password,
      );
      final code = session?['error']?.toString();
      if (session?['ok'] != true) {
        authError = switch (code) {
          'invalid_email_or_password' => 'Email or DarkVibeX password is incorrect.',
          'user_banned' => 'This account is banned.',
          'user_suspended' => 'This account is suspended.',
          _ => 'Email login could not be completed.',
        };
        return false;
      }
      return await _applySession(session, provider: 'email');
    } catch (_) {
      authError = 'Email login could not connect to DarkVibeX.';
      return false;
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<bool> completeEmailSignup({
    required String setupToken,
    required String password,
    required String name,
    required String dateOfBirthValue,
  }) async {
    if (signingIn) return false;
    signingIn = true;
    authError = null;
    notifyListeners();
    try {
      final session = await backend.completeEmailPassword(
        setupToken: setupToken,
        password: password,
        displayName: name,
        dateOfBirth: dateOfBirthValue,
      );
      final code = session?['error']?.toString();
      if (session?['ok'] != true) {
        authError = switch (code) {
          'setup_token_expired' => 'Email verification expired. Verify the OTP again.',
          'email_already_registered' => 'This email already has a DarkVibeX ID.',
          'password_length' => 'Password must be at least 8 characters.',
          _ => 'Email account could not be created.',
        };
        return false;
      }
      return await _applySession(session, provider: 'email');
    } catch (_) {
      authError = 'Email account could not be created.';
      return false;
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    if (signingIn) return false;
    signingIn = true;
    authError = null;
    notifyListeners();

    try {
      if (!await _ensureGoogleSignInInitialized()) {
        return false;
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

  Future<bool> bindGoogleAccount() async {
    if (!isAuthenticated || signingIn) return false;
    signingIn = true;
    authError = null;
    notifyListeners();
    try {
      if (!await _ensureGoogleSignInInitialized()) return false;
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        authError = 'Google Login is not supported on this device.';
        return false;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        authError = 'Google did not return a valid sign-in token.';
        return false;
      }
      final result = await backend.bindGoogleIdentity(idToken: idToken);
      if (result?['ok'] != true) {
        final code = result?['error']?.toString();
        authError = switch (code) {
          'google_account_already_bound' =>
            'This Google account is already linked to another DarkVibeX ID.',
          'user_already_bound_to_google' =>
            'This DarkVibeX ID is already linked to another Google account.',
          'google_auth_not_configured' =>
            'Google Login is not configured on the server yet.',
          _ => 'Google account could not be linked.',
        };
        return false;
      }
      authProvider = 'google';
      await _persistSession();
      return true;
    } on GoogleSignInException catch (error) {
      authError = _googleSignInErrorMessage(error);
      return false;
    } catch (_) {
      authError = 'Google account could not be linked.';
      return false;
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<bool> _ensureGoogleSignInInitialized() async {
    if (_googleInitialized) {
      googleSignInReady = true;
      return true;
    }

    final config = await backend.googleAuthConfig();
    _googleWebClientId = config?['google_web_client_id']?.toString().trim();
    if (_googleWebClientId == null || _googleWebClientId!.isEmpty) {
      googleSignInReady = false;
      authError = 'Google Login is not configured on the server yet.';
      return false;
    }

    await GoogleSignIn.instance.initialize(
      serverClientId: _googleWebClientId,
    );
    _googleInitialized = true;
    googleSignInReady = true;
    return true;
  }

  String _googleSignInErrorMessage(GoogleSignInException error) {
    final description = error.description?.trim();
    final detail = description == null || description.isEmpty
        ? ''
        : ' ($description)';

    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Google Login could not be completed. Please try again$detail',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google Login is temporarily unavailable. Please try again later$detail',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google Login is temporarily unavailable on this device$detail',
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
        'google_identity_conflict' =>
          'This email ID is linked to a different Google account. Sign in with the original Google account or use Email / Gmail Login.',
        'google_email_not_verified' =>
          'This Google account email is not verified.',
        'google_session_storage_failed' =>
          'Login storage is being repaired on the server. Please try again.',
        'google_session_policy_failed' =>
          'Login reached the server but account checks could not finish.',
        'google_session_token_failed' =>
          'Login reached the server but the session token could not be created.',
        'user_banned' =>
          'This account is banned.',
        'user_suspended' =>
          'This account is suspended.',
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
    final incomingPublicId = user['public_id']?.toString().trim() ?? '';
    if ((incomingPublicId.length == 7 || incomingPublicId.length == 8) &&
        int.tryParse(incomingPublicId) != null &&
        !incomingPublicId.startsWith('0')) {
      // Keep the stored value canonical so legacy room references still resolve.
      publicId = incomingPublicId;
    }
    displayName = user['display_name']?.toString() ?? displayName;
    userRole = user['role']?.toString() ?? userRole;
    avatarKey = user['avatar_key']?.toString();
    dateOfBirth = user['date_of_birth']?.toString();
    countryCode = user['country_code']?.toString().trim() ?? '';
    countryName = user['country_name']?.toString().trim() ?? '';
    flagEmoji = user['flag_emoji']?.toString().trim() ?? '';
    gender = user['gender']?.toString().trim().toLowerCase() ?? '';
    bio = user['bio']?.toString().trim() ?? '';
    ageChangeCount =
        int.tryParse(user['age_change_count']?.toString() ?? '') ?? 0;
    countryChangeCount =
        int.tryParse(user['country_change_count']?.toString() ?? '') ?? 0;
    genderChangeCount =
        int.tryParse(user['gender_change_count']?.toString() ?? '') ?? 0;
    var restoredLanguage = user['language']?.toString().trim() ?? '';
    if (!darkVibeXIsSupportedLanguage(restoredLanguage)) {
      restoredLanguage =
          (await SharedPreferences.getInstance()).getString('dvx.language') ??
              'English';
    }
    setLanguagePreference(restoredLanguage);
    if (dateOfBirth == null || dateOfBirth!.trim().isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      dateOfBirth = prefs.getString(_sessionDateOfBirthKey);
    }
    needsProfileSetup =
        (dateOfBirth?.trim().isNotEmpty != true) ||
        countryCode.trim().isEmpty ||
        !const <String>{'male', 'female'}.contains(gender.trim().toLowerCase());
    coins = int.tryParse(user['coins']?.toString() ?? '') ?? coins;
    diamonds = int.tryParse(user['diamonds']?.toString() ?? '') ?? diamonds;
    vipLevel = int.tryParse(user['vip_level']?.toString() ?? '') ?? vipLevel;

    await _persistSession();
    // Core authentication should succeed even if an optional dashboard endpoint
    // (rooms, wallet, inbox) is temporarily unavailable.
    try {
      await _loadRemoteData();
    } catch (error) {
      debugPrint('DarkVibeX post-login refresh failed: $error');
    }
    if (notify) notifyListeners();
    return true;
  }

  Future<void> _loadRemoteData() async {
    // These are optional dashboard resources. One failed endpoint must not
    // prevent the remaining functions from refreshing after login/reconnect.
    Future<void> loadOptional(
      String resource,
      Future<void> Function() operation,
    ) async {
      try {
        await operation();
      } catch (error) {
        debugPrint('DarkVibeX $resource refresh failed: $error');
      }
    }

    // Keep requests sequential to avoid a startup burst against the Worker.
    await loadOptional('wallet', () => refreshWallet(notify: false));
    await loadOptional('weekly sign-in', () => refreshWeeklySignIn(notify: false));
    await loadOptional('VIP', () => refreshVip(notify: false));
    await loadOptional('ID level', () => refreshIdLevel(notify: false));
    await loadOptional('cosmetics', () => refreshCosmetics(notify: false));
    await loadOptional('rooms', () async {
      await _replaceRoomsFromRemote(await backend.listRooms());
    });
    await loadOptional('inbox', () => refreshInbox(notify: false));
  }

  Future<void> refreshRooms({bool notify = true}) async {
    if (!backendConnected) return;
    await _replaceRoomsFromRemote(await backend.listRooms());
    if (notify) notifyListeners();
  }

  Future<void> refreshInbox({bool notify = true}) async {
    if (!backendConnected) return;
    final remoteInbox = await backend.inbox(userId: userId);
    final latestFirst = remoteInbox
        .map((row) => DirectMessage(
              id: row['id']?.toString() ?? '',
              name: row['name']?.toString() ?? 'User',
              preview: row['preview']?.toString() ?? '',
              unread: int.tryParse(row['unread']?.toString() ?? '') ?? 0,
              avatarKey: row['avatar_key']?.toString(),
              createdAt:
                  int.tryParse(row['created_at']?.toString() ?? '') ?? 0,
            ))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    messages
      ..clear()
      ..addAll(latestFirst);
    if (notify) notifyListeners();
  }

  Future<bool> setMessagePushNotificationsEnabled(bool enabled) async {
    if (!backendConnected || !isAuthenticated) return false;
    final ok = await backend.setMessagePushEnabled(
      userId: userId,
      enabled: enabled,
    );
    notifyListeners();
    return ok;
  }

  Future<void> signOut() async {
    if (authProvider == 'google') {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    await _clearPersistedSession();
    sessionToken = null;
    BackendApi.sessionToken = null;
    authProvider = null;
    backendConnected = false;
    isAuthenticated = false;
    needsProfileSetup = false;
    authError = null;
    userId = '91000001';
    publicId = '9100001';
    displayName = 'DarkVibeX User';
    userRole = 'user';
    avatarKey = null;
    dateOfBirth = null;
    countryCode = '';
    countryName = '';
    flagEmoji = '';
    gender = '';
    bio = '';
    ageChangeCount = 0;
    countryChangeCount = 0;
    genderChangeCount = 0;
    languagePreference.value = 'English';
    messages.clear();
    minimizedRoom = null;
    minimizedRoomResume = null;
    minimizedRoomClose = null;
    coins = 0;
    diamonds = 120;
    weeklySignInReady = false;
    weeklySignInLoading = false;
    weeklySignInClaimedToday = false;
    weeklySignInDay = 1;
    weeklySignInClaimedThrough = 0;
    weeklySignInLastReward = 0;
    weeklySignInLastClaimedDay = 0;
    weeklySignInError = null;
    idLevel = 0;
    idLevelExp = 0;
    idLevelExpToNext = 10000;
    vipLevel = 0;
    vipExpBalance = 0;
    vipTotalReceivedCoins = 0;
    activeFrameId = null;
    activeVehicleId = null;
    activeCosmetics.clear();
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
      userRole = wallet['role']?.toString() ?? userRole;
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

  void _applyWeeklySignInStatus(Map<String, dynamic>? value) {
    if (value?['ok'] != true) {
      weeklySignInReady = false;
      weeklySignInError =
          value?['error']?.toString() ?? 'Weekly sign-in is unavailable.';
      return;
    }
    weeklySignInReady = true;
    weeklySignInError = null;
    weeklySignInDay =
        (int.tryParse(value?['current_day']?.toString() ?? '') ?? 1)
            .clamp(1, 7)
            .toInt();
    weeklySignInClaimedThrough =
        (int.tryParse(value?['claimed_through']?.toString() ?? '') ?? 0)
            .clamp(0, 7)
            .toInt();
    weeklySignInClaimedToday =
        value?['claimed_today'] == true ||
        value?['claimed_today']?.toString() == '1';
  }

  Future<void> refreshWeeklySignIn({bool notify = true}) async {
    if (!backendConnected || !isAuthenticated) {
      weeklySignInReady = false;
      if (notify) notifyListeners();
      return;
    }
    final value = await backend.weeklySignInStatus(userId: userId);
    _applyWeeklySignInStatus(value);
    if (notify) notifyListeners();
  }

  Future<bool> claimWeeklySignIn() async {
    if (!backendConnected ||
        !isAuthenticated ||
        weeklySignInLoading ||
        weeklySignInClaimedToday) {
      return false;
    }
    final requestedDay = weeklySignInDay;
    weeklySignInLoading = true;
    weeklySignInError = null;
    notifyListeners();
    try {
      final value = await backend.claimWeeklySignIn(userId: userId);
      if (value?['ok'] != true) {
        weeklySignInError = switch (value?['error']?.toString()) {
          'already_claimed_today' => 'Today\'s reward is already claimed.',
          _ => 'Weekly sign-in reward could not be claimed.',
        };
        return false;
      }
      weeklySignInLastReward =
          int.tryParse(value?['reward']?.toString() ?? '') ?? 0;
      weeklySignInLastClaimedDay =
          (int.tryParse(value?['receipt_day']?.toString() ?? '') ??
                  int.tryParse(value?['claimed_day']?.toString() ?? '') ??
                  requestedDay)
              .clamp(1, 7)
              .toInt();
      final balance =
          int.tryParse(value?['coin_balance']?.toString() ?? '');
      if (balance != null) coins = balance;
      _applyWeeklySignInStatus(value);
      await refreshWallet(notify: false);
      return true;
    } catch (_) {
      weeklySignInError = 'Weekly sign-in reward could not be claimed.';
      return false;
    } finally {
      weeklySignInLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCosmetics({bool notify = true}) async {
    if (!backendConnected) return;
    final value = await backend.cosmetics(userId: userId);
    final rows = value?['owned'];
    if (rows is List) {
      activeFrameId = null;
      activeVehicleId = null;
      activeCosmetics.clear();
      for (final row in rows.whereType<Map>()) {
        if (row['active'] != true && row['active']?.toString() != '1') {
          continue;
        }
        final kind = row['kind']?.toString() ?? '';
        final itemId = row['item_id']?.toString() ?? '';
        if (kind.isEmpty || itemId.isEmpty) continue;
        activeCosmetics[kind] = itemId;
        if (kind == 'frame') activeFrameId = itemId;
        if (kind == 'vehicle') activeVehicleId = itemId;
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

  Future<bool> completeLoginProfile({
    required String name,
    required String dateOfBirthValue,
    String? countryCodeValue,
    String? countryNameValue,
    String? flagEmojiValue,
    String? genderValue,
    String? bioValue,
    String? languageValue,
    Uint8List? avatarBytes,
    String avatarExtension = 'jpg',
    String avatarContentType = 'image/jpeg',
  }) async {
    if (!isAuthenticated || !backendConnected) return false;
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    final nextCountryCode = (countryCodeValue ?? countryCode).trim().toUpperCase();
    final nextCountryName = (countryNameValue ?? countryName).trim();
    final nextFlagEmoji = (flagEmojiValue ?? flagEmoji).trim();
    final nextGender = (genderValue ?? gender).trim().toLowerCase();
    final nextBio = (bioValue ?? bio).trim();
    final requestedLanguage =
        (languageValue ?? languagePreference.value).trim();
    final nextLanguage = darkVibeXIsSupportedLanguage(requestedLanguage)
        ? requestedLanguage
        : 'English';

    final profile = await backend.saveUserProfile(
      userId: userId,
      displayName: cleanName,
      dateOfBirth: dateOfBirthValue.trim(),
      countryCode: nextCountryCode,
      countryName: nextCountryName,
      flagEmoji: nextFlagEmoji,
      gender: nextGender,
      bio: nextBio,
      language: nextLanguage,
    );
    if (profile?['ok'] != true) {
      final code = profile?['error']?.toString() ?? '';
      authError = switch (code) {
        'age_change_limit_reached' =>
          'Age/date of birth can only be changed 3 times.',
        'country_change_limit_reached' =>
          'Country can only be changed 3 times.',
        'gender_change_limit_reached' =>
          'Gender can only be changed 3 times.',
        'profile_change_conflict_retry' =>
          'Profile changed elsewhere. Reopen profile and try again.',
        _ => code.isEmpty
            ? 'Profile details could not be saved.'
            : code.replaceAll('_', ' '),
      };
      notifyListeners();
      return false;
    }

    final returnedUser = profile?['user'];
    final previousCountry = countryCode;
    displayName = cleanName;
    dateOfBirth = dateOfBirthValue.trim();
    countryCode = nextCountryCode;
    countryName = nextCountryName;
    flagEmoji = nextFlagEmoji;
    gender = nextGender;
    bio = nextBio;
    if (returnedUser is Map) {
      dateOfBirth =
          returnedUser['date_of_birth']?.toString() ?? dateOfBirth;
      countryCode =
          returnedUser['country_code']?.toString().trim() ?? countryCode;
      countryName =
          returnedUser['country_name']?.toString().trim() ?? countryName;
      flagEmoji =
          returnedUser['flag_emoji']?.toString().trim() ?? flagEmoji;
      gender =
          returnedUser['gender']?.toString().trim().toLowerCase() ?? gender;
      bio = returnedUser['bio']?.toString().trim() ?? bio;
      ageChangeCount =
          int.tryParse(returnedUser['age_change_count']?.toString() ?? '') ??
              ageChangeCount;
      countryChangeCount =
          int.tryParse(returnedUser['country_change_count']?.toString() ?? '') ??
              countryChangeCount;
      genderChangeCount =
          int.tryParse(returnedUser['gender_change_count']?.toString() ?? '') ??
              genderChangeCount;
    }
    setLanguagePreference(nextLanguage);
    await (await SharedPreferences.getInstance())
        .setString('dvx.language', nextLanguage);

    if (avatarBytes != null && avatarBytes.isNotEmpty) {
      final ext = avatarExtension.toLowerCase() == 'jpeg'
          ? 'jpg'
          : avatarExtension.toLowerCase();
      final key = await backend.uploadImage(
        key: 'users/$userId/avatar-${DateTime.now().microsecondsSinceEpoch}.$ext',
        bytes: avatarBytes,
        contentType: avatarContentType,
      );
      if (key != null &&
          await backend.setUserAvatar(userId: userId, avatarKey: key)) {
        avatarKey = key;
      }
    }

    authError = null;
    needsProfileSetup = false;
    await _persistSession();
    if (previousCountry != countryCode) {
      await refreshRooms(notify: false);
    }
    notifyListeners();
    return true;
  }

  void setLanguagePreference(String value) {
    final normalized = value.trim();
    languagePreference.value =
        darkVibeXIsSupportedLanguage(normalized) ? normalized : 'English';
  }

  Future<bool> saveLanguagePreference(String value) async {
    final normalized = value.trim();
    if (!darkVibeXIsSupportedLanguage(normalized)) return false;
    if (!isAuthenticated || !backendConnected) return false;

    final result = await backend.setUserLanguage(
      userId: userId,
      language: normalized,
    );
    if (result?['ok'] != true) {
      authError = result?['error']?.toString() ??
          'Language preference could not be saved.';
      notifyListeners();
      return false;
    }

    setLanguagePreference(normalized);
    await (await SharedPreferences.getInstance())
        .setString('dvx.language', normalized);
    authError = null;
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
      id: room.id, displayId: room.displayId,
      name: room.name, ownerName: room.ownerName,
      ownerUserId: room.ownerUserId, online: room.online,
      seatCount: room.seatCount, avatarKey: key, partyMode: room.partyMode,
      roomMode: room.roomMode,
    );
    notifyListeners();
  }

  String get _ownedRoomCacheKey => 'darkvibex.owned_room.$userId';

  Future<RoomSummary?> _readOwnedRoomCache() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_ownedRoomCacheKey)?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final id = decoded['id']?.toString().trim() ?? '';
      final ownerId = decoded['ownerUserId']?.toString().trim() ?? '';
      if (id.isEmpty || ownerId != userId) return null;
      return RoomSummary(
        id: id,
        displayId: decoded['displayId']?.toString(),
        name: decoded['name']?.toString() ?? 'My Room',
        ownerName: decoded['ownerName']?.toString() ?? displayName,
        ownerUserId: ownerId,
        online: int.tryParse(decoded['online']?.toString() ?? '') ?? 0,
        seatCount: int.tryParse(decoded['seatCount']?.toString() ?? '') ?? 12,
        avatarKey: decoded['avatarKey']?.toString(),
        partyMode: decoded['partyMode']?.toString() ?? 'Friends-making Party',
        roomMode: decoded['roomMode']?.toString() ?? 'voice',
      );
    } catch (_) {
      await preferences.remove(_ownedRoomCacheKey);
      return null;
    }
  }

  Future<void> _writeOwnedRoomCache(RoomSummary room) async {
    if (room.id.trim().isEmpty || room.ownerUserId != userId) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _ownedRoomCacheKey,
      jsonEncode(<String, Object?>{
        'id': room.id,
        'displayId': room.displayId,
        'name': room.name,
        'ownerName': room.ownerName,
        'ownerUserId': room.ownerUserId,
        'online': room.online,
        'seatCount': room.seatCount,
        'avatarKey': room.avatarKey,
        'partyMode': room.partyMode,
        'roomMode': room.roomMode,
      }),
    );
  }

  Future<void> _replaceRoomsFromRemote(List<Map<String, dynamic>> rows) async {
    final cachedOwnedRoom = await _readOwnedRoomCache();
    final byId = <String, RoomSummary>{};
    for (final row in rows) {
      final room = RoomSummary(
        id: row['id']?.toString() ?? '',
        displayId: row['display_id']?.toString(),
        name: row['name']?.toString() ?? 'Room',
        ownerName: row['owner_name']?.toString() ?? '',
        ownerUserId: row['owner_user_id']?.toString() ?? '',
        online: int.tryParse(row['online']?.toString() ?? '') ?? 0,
        seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ?? 12,
        avatarKey: row['avatar_key']?.toString(),
        partyMode: row['party_mode']?.toString() ?? 'Friends-making Party',
        roomMode: row['room_mode']?.toString() ?? 'voice',
      );
      if (room.id.isEmpty ||
          (room.online <= 0 && room.ownerUserId != userId)) {
        continue;
      }
      byId[room.id] = room;
    }
    final hasOwnedRoom = byId.values.any((room) => room.ownerUserId == userId);
    if (!hasOwnedRoom && cachedOwnedRoom != null) {
      byId[cachedOwnedRoom.id] = cachedOwnedRoom;
    }
    rooms
      ..clear()
      ..addAll(byId.values);
    for (final room in rooms) {
      if (room.ownerUserId == userId) {
        await _writeOwnedRoomCache(room);
        break;
      }
    }
  }

  Future<RoomSummary> createRoom(
    String name, {
    int seatCount = 12,
    String partyMode = 'Friends-making Party',
    String roomMode = 'voice',
  }) async {
    final cleanName = name.trim().isEmpty ? 'New Room' : name.trim();
    final allowedSeats =
        seatCount.clamp(8, VipPolicy.maxRoomSeats(vipLevel)).toInt();
    if (!backendConnected) {
      throw StateError('Server connection is required to create a room.');
    }
    final result = await backend.createRoomResult(
      ownerUserId: userId,
      ownerName: displayName,
      name: cleanName,
      seatCount: allowedSeats,
      partyMode: partyMode,
      roomMode: roomMode,
    );
    final roomId = result?['room_id']?.toString() ?? '';
    if (roomId.isEmpty) {
      final code = result?['error']?.toString().trim() ?? '';
      final message = switch (code) {
        'unauthorized' || 'forbidden' =>
          'Your login session expired. Sign in again and create the room.',
        'room_creation_disabled' =>
          'Room creation is disabled on the server.',
        'invalid_seat_count' =>
          'Choose a room size between 8 and 42 seats.',
        'invalid_create_room_mode' =>
          'Choose Voice Room, Game Room or Live Room.',
        'owner_and_name_required' =>
          'Room name is required.',
        'country_required_for_room' =>
          'Select your country before creating a room.',
        'room_create_storage_failed' =>
          'Room storage could not save the room. The server is being repaired.',
        'room_id_taken' || 'room_id_unavailable' =>
          'A room ID could not be allocated. Please try again.',
        'user_banned' || 'user_suspended' =>
          'This account cannot create a room right now.',
        _ => code.isEmpty
            ? 'The server did not return a room ID. Please try again.'
            : 'The server could not create this room ($code).',
      };
      throw StateError(message);
    }

    final resolvedName = result?['name']?.toString().trim();
    final resolvedSeatCount =
        int.tryParse(result?['seat_count']?.toString() ?? '');
    final resolvedOnline =
        int.tryParse(result?['online']?.toString() ?? '');
    final room = RoomSummary(
      id: roomId,
      displayId: result?['display_id']?.toString() ?? publicId,
      name: resolvedName?.isNotEmpty == true ? resolvedName! : cleanName,
      ownerName: displayName,
      ownerUserId: userId,
      online: resolvedOnline ?? (result?['existing'] == true ? 0 : 1),
      seatCount: resolvedSeatCount ?? allowedSeats,
      partyMode: result?['party_mode']?.toString() ?? partyMode,
      roomMode: result?['room_mode']?.toString() ?? roomMode,
    );
    final existingIndex = rooms.indexWhere(
      (existing) => existing.id == room.id || existing.ownerUserId == userId,
    );
    if (existingIndex >= 0) {
      rooms[existingIndex] = room;
    } else {
      rooms.insert(0, room);
    }
    await _writeOwnedRoomCache(room);
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

  void setDiamondBalance(int value) {
    if (value < 0) return;
    diamonds = value;
    notifyListeners();
  }
}
