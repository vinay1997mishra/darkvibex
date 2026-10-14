import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_state.dart';

class MessagePushService {
  MessagePushService();

  static const MethodChannel _channel = MethodChannel('darkvibex/push');
  static const bool buildConfigured = bool.fromEnvironment(
    'DARKVIBEX_PUSH_CONFIGURED',
    defaultValue: false,
  );

  bool _syncing = false;
  String? _registeredUserId;
  String? _registeredToken;
  bool? _registeredEnabled;

  Future<void> sync(AppState state) async {
    if (_syncing) return;
    if (!buildConfigured ||
        !state.isAuthenticated ||
        !state.backendConnected ||
        state.userId.trim().isEmpty) {
      if (!state.isAuthenticated) {
        _registeredUserId = null;
        _registeredToken = null;
        _registeredEnabled = null;
      }
      return;
    }

    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool('dvx.notifications.messages') ?? true;

      if (!enabled) {
        if (_registeredUserId != state.userId ||
            _registeredEnabled != false) {
          await state.backend.setMessagePushEnabled(
            userId: state.userId,
            enabled: false,
          );
          _registeredUserId = state.userId;
          _registeredEnabled = false;
        }
        return;
      }

      final granted =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      if (!granted) {
        await state.backend.setMessagePushEnabled(
          userId: state.userId,
          enabled: false,
        );
        _registeredUserId = state.userId;
        _registeredEnabled = false;
        return;
      }

      final token =
          (await _channel.invokeMethod<String>('getToken'))?.trim() ?? '';
      if (token.isEmpty) return;

      if (_registeredUserId != state.userId ||
          _registeredToken != token ||
          _registeredEnabled != true) {
        final registered = await state.backend.registerPushDevice(
          userId: state.userId,
          token: token,
          enabled: true,
        );
        if (!registered) return;
        await state.backend.setMessagePushEnabled(
          userId: state.userId,
          enabled: true,
        );
        _registeredUserId = state.userId;
        _registeredToken = token;
        _registeredEnabled = true;
      }
    } on MissingPluginException {
      // Non-Android/test environments intentionally have no native push bridge.
    } on PlatformException catch (error) {
      debugPrint('DarkVibeX push registration failed: ${error.code}');
    } catch (error) {
      debugPrint('DarkVibeX push registration failed: $error');
    } finally {
      _syncing = false;
    }
  }
}
