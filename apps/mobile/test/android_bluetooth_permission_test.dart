// Android Bluetooth gating (audit 2026-11-22) — source assertions.
// BLUETOOTH_CONNECT was only ever requested on the very first mic
// grant: hasVoiceRoomPermissions() checked RECORD_AUDIO alone and
// requestVoiceRoomPermissions() early-returned true once the mic was
// granted, so a user who granted the mic earlier was never re-prompted
// for Bluetooth on Android 12+ and Agora headset routing silently
// failed. Native Kotlin cannot run in flutter test, so the checks
// below assert on the MainActivity source itself.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'android/app/src/main/kotlin/com/darkvibex/app/MainActivity.kt',
  ).readAsStringSync();

  test('BLUETOOTH_CONNECT is checked on its own, not just via the mic', () {
    expect(source, contains('private fun hasBluetoothConnectPermission()'));
    expect(
      source,
      contains('Manifest.permission.BLUETOOTH_CONNECT'),
    );
    // Below Android 12 the permission does not exist: always granted.
    expect(
      source,
      contains('if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true'),
    );
  });

  test('the voice gate requires the mic AND Bluetooth', () {
    expect(
      source,
      contains('hasBluetoothConnectPermission()'),
    );
    // hasVoiceRoomPermissions must AND the two checks together.
    final gate = RegExp(
      r'private fun hasVoiceRoomPermissions\(\).*?\{.*?RECORD_AUDIO.*?&&\s*\n?\s*hasBluetoothConnectPermission\(\)',
      dotAll: true,
    );
    expect(gate.hasMatch(source), isTrue);
  });

  test('a re-request asks only for the permissions still missing', () {
    expect(
      source,
      contains('val missing = voiceRoomPermissions().filter {'),
    );
    expect(
      source,
      contains('requestPermissions(missing.toTypedArray(), voicePermissionRequest)'),
    );
    // The old whole-bundle request is gone.
    expect(
      source.contains(
        'requestPermissions(voiceRoomPermissions(), voicePermissionRequest)',
      ),
      isFalse,
    );
  });

  test('the voice request no longer bundles the notification permission', () {
    // POST_NOTIFICATIONS has its own flow on the push channel
    // (MessagePushService.requestPermission); the voice check must
    // not re-prompt for it, and the voice bundle must not list it.
    final voiceSection = source.substring(
      source.indexOf('private fun voiceRoomPermissions()'),
      source.indexOf('private fun hasBluetoothConnectPermission()'),
    );
    expect(voiceSection, contains('BLUETOOTH_CONNECT'));
    expect(voiceSection.contains('POST_NOTIFICATIONS'), isFalse);
    // The dedicated notification flow is untouched.
    expect(source, contains('private fun requestMessageNotificationPermission'));
  });

  test('the permission result still reports the full voice gate', () {
    expect(
      source,
      contains('pendingPermissionResult?.success(hasVoiceRoomPermissions())'),
    );
  });
}
