// Automatic crash reports (Mr. Wrong, 2026-11-24): uncaught Flutter
// errors and async zone errors are sent to POST /api/crash-report
// with the screen + device attached. Fire-and-forget and never throws;
// the same error is not re-sent within 60 seconds, so a crash loop
// cannot spam the owner or the server.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'backend_api.dart';
import 'device_info.dart';

class CrashReporter {
  static BackendApi? _backend;
  static String Function()? _userIdProvider;
  static bool _installed = false;
  static String _lastError = '';
  static DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  static void configure({
    required BackendApi backend,
    required String Function() userId,
  }) {
    _backend = backend;
    _userIdProvider = userId;
  }

  static void install() {
    if (_installed) return;
    _installed = true;
    FlutterError.onError = (details) {
      // Keep the default behaviour (red screen in debug, log in release).
      FlutterError.presentError(details);
      unawaited(report(details.exceptionAsString(), stack: details.stack));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(error.toString(), stack: stack));
      return true;
    };
  }

  static Future<bool> report(String error, {StackTrace? stack}) async {
    try {
      final backend = _backend;
      final userId = _userIdProvider?.call() ?? '';
      if (backend == null || userId.isEmpty) return false;
      final trimmed = error.trim();
      if (trimmed.length < 3) return false;
      final now = DateTime.now();
      if (trimmed == _lastError &&
          now.difference(_lastSentAt).inSeconds < 60) {
        return false;
      }
      _lastError = trimmed;
      _lastSentAt = now;
      final info = await collectDeviceInfo();
      return await backend.submitCrashReport(
        userId: userId,
        error: trimmed,
        stack: stack?.toString() ?? '',
        route: info['route'] ?? '',
        deviceInfo: deviceInfoSummary(info),
        appVersion: info['app_version'] ?? '',
      );
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _backend = null;
    _userIdProvider = null;
    _installed = false;
    _lastError = '';
    _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
