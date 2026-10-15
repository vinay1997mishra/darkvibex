import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_state.dart';

class InviteReferralService {
  InviteReferralService(this.state);

  static const MethodChannel _channel =
      MethodChannel('darkvibex/invite_referral');
  static const String _pendingKey = 'darkvibex.pending_invite_code';

  final AppState state;
  bool _binding = false;
  bool _disposed = false;

  Future<void> initialize() async {
    await _channel.setMethodCallHandler((call) async {
      if (call.method == 'inviteCode') {
        await _capture(call.arguments?.toString());
      }
    });
    state.addListener(_onStateChanged);

    try {
      final code = await _channel.invokeMethod<String>('getInitialInviteCode');
      await _capture(code);
    } on PlatformException catch (error) {
      debugPrint('DarkVibeX invite referral unavailable: ${error.code}');
    } on MissingPluginException {
      // Non-Android/test builds can continue without native referral capture.
    }
    await _tryBindPending();
  }

  String? _validCode(String? value) {
    final code = value?.trim() ?? '';
    return RegExp(r'^[1-9]\d{6}$').hasMatch(code) ? code : null;
  }

  Future<void> _capture(String? raw) async {
    final code = _validCode(raw);
    if (code == null || _disposed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, code);
    await _tryBindPending();
  }

  void _onStateChanged() {
    unawaited(_tryBindPending());
  }

  Future<void> _tryBindPending() async {
    if (_disposed ||
        _binding ||
        !state.isAuthenticated ||
        !state.backendConnected) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final code = _validCode(prefs.getString(_pendingKey));
    if (code == null) return;

    // A user can never bind their own public ID as an invitation code.
    if (code == state.publicId.trim()) {
      await prefs.remove(_pendingKey);
      return;
    }

    _binding = true;
    try {
      final result = await state.backend.bindInvitationCode(
        userId: state.userId,
        invitationCode: code,
      );
      final error = result?['error']?.toString() ?? '';
      if (result?['ok'] == true ||
          error == 'cannot_invite_self' ||
          error == 'invitation_code_not_found') {
        await prefs.remove(_pendingKey);
      }
    } catch (error) {
      debugPrint('DarkVibeX automatic invitation bind failed: $error');
    } finally {
      _binding = false;
    }
  }

  void dispose() {
    _disposed = true;
    state.removeListener(_onStateChanged);
    unawaited(_channel.setMethodCallHandler(null));
  }
}
