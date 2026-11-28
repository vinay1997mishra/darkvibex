// Report a Problem + automatic crash reports (Mr. Wrong, 2026-11-24):
// the Mine page has a Report a Problem tile, the Feedback screen sends
// auto device info with every report, and uncaught errors go to the
// server on their own (deduped so one crash loop cannot spam).
import 'dart:io';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/infra/crash_reporter.dart';
import 'package:darkvibex/infra/device_info.dart';
import 'package:darkvibex/screens/mine_social_screens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReportBackend extends BackendApi {
  _FakeReportBackend({this.historyRows = const []});

  final List<Map<String, dynamic>> historyRows;

  final List<Map<String, dynamic>> submitCalls = [];
  final List<Map<String, dynamic>> crashCalls = [];

  @override
  Future<List<Map<String, dynamic>>> feedbackHistory({
    required String userId,
  }) async {
    return historyRows;
  }

  @override
  Future<bool> submitFeedback({
    required String userId,
    required String category,
    required String message,
    String? deviceInfo,
    String? screenshotKey,
  }) async {
    submitCalls.add(<String, dynamic>{
      'user_id': userId,
      'category': category,
      'message': message,
      'device_info': deviceInfo ?? '',
      'screenshot_key': screenshotKey ?? '',
    });
    return true;
  }

  @override
  Future<bool> submitCrashReport({
    required String userId,
    required String error,
    String stack = '',
    String route = '',
    String deviceInfo = '',
    String appVersion = '',
  }) async {
    crashCalls.add(<String, dynamic>{
      'user_id': userId,
      'error': error,
      'stack': stack,
      'route': route,
      'device_info': deviceInfo,
      'app_version': appVersion,
    });
    return true;
  }
}

class _ThrowingBackend extends BackendApi {
  @override
  Future<bool> submitCrashReport({
    required String userId,
    required String error,
    String stack = '',
    String route = '',
    String deviceInfo = '',
    String appVersion = '',
  }) async {
    throw StateError('network down');
  }
}

Future<void> _pumpFeedback(
  WidgetTester tester,
  AppState state,
  _FakeReportBackend backend,
) async {
  await tester.pumpWidget(
    MaterialApp(home: FeedbackScreen(state: state, backend: backend)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// package_info_plus has no plugin in widget tests, so its channel call
/// never completes and any submit waiting on device info hangs. Answer
/// the channel with fixed values instead.
void _mockPackageInfo() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'DarkVibeX',
          'packageName': 'com.darkvibex.app',
          'version': '0.1.0',
          'buildNumber': '1',
        };
      }
      return null;
    },
  );
}

void main() {
  test('Mine page has a Report a Problem tile opening Feedback', () {
    // The old Feedback tile (chat bubble, translated label) is now a
    // prominent red bug-report tile (Mr. Wrong, 2026-11-24).
    final source = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(source, contains("key: const Key('mine-report-problem')"));
    expect(source, contains("'Report a Problem'"));
    expect(source, contains('Icons.bug_report_rounded'));
    expect(source, contains('FeedbackScreen(state: state)'));
  });

  testWidgets('feedback submit sends auto device info with the report',
      (tester) async {
    _mockPackageInfo();
    final backend = _FakeReportBackend();
    final state = AppState()..userId = 'user-1';
    await _pumpFeedback(tester, state, backend);
    expect(find.byKey(const Key('feedback-attach-screenshot')),
        findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Spin button does nothing',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.submitCalls.length, 1);
    expect(backend.submitCalls.first['message'], 'Spin button does nothing');
    expect(backend.submitCalls.first['category'], 'General');
    // Auto info rides along even though the user typed nothing about
    // their phone (in tests the plugins are missing, so it falls back
    // to the dart:io values — still non-empty).
    expect(backend.submitCalls.first['device_info'] as String, isNotEmpty);
  });

  testWidgets('feedback history shows the report and its screenshot',
      (tester) async {
    final backend = _FakeReportBackend(historyRows: [
      <String, dynamic>{
        'category': 'Bug',
        'message': 'Join button dead',
        'device_info': 'Pixel 8, Android 14',
        'screenshot_key': 'users/user-1/misc/feedback-1.jpg',
        'status': 'submitted',
        'created_at': 1764000000000,
      },
    ]);
    final state = AppState()..userId = 'user-1';
    await _pumpFeedback(tester, state, backend);
    // The message sits in a multi-line subtitle (message + date), so
    // match it as a substring, not an exact Text.
    expect(find.textContaining('Join button dead'), findsOneWidget);
    // The screenshot thumbnail is an Image.network for the private
    // bucket key (with the session header).
    expect(find.byType(Image), findsOneWidget);
  });

  test('collectDeviceInfo never throws and always returns the keys', () async {
    final info = await collectDeviceInfo(route: 'FamilyDetail');
    expect(info['model'], isNotEmpty);
    expect(info['os'], isNotEmpty);
    expect(info['app_version'], isNotEmpty);
    expect(info['route'], 'FamilyDetail');
    expect(deviceInfoSummary(info), isNotEmpty);
  });

  test('crash reporter sends the error once, then dedupes repeats',
      () async {
    final backend = _FakeReportBackend();
    CrashReporter.resetForTest();
    CrashReporter.configure(
      backend: backend,
      userId: () => 'user-1',
    );
    expect(await CrashReporter.report('Null check on HomeScreen'), isTrue);
    expect(backend.crashCalls.length, 1);
    expect(backend.crashCalls.first['error'], 'Null check on HomeScreen');
    expect(backend.crashCalls.first['device_info'] as String, isNotEmpty);
    // Same error again within 60 seconds: not re-sent.
    expect(await CrashReporter.report('Null check on HomeScreen'), isFalse);
    expect(backend.crashCalls.length, 1);
    // A different error goes through.
    expect(await CrashReporter.report('Socket timeout on join'), isTrue);
    expect(backend.crashCalls.length, 2);
    CrashReporter.resetForTest();
  });

  test('crash reporter never throws when nothing is configured', () async {
    CrashReporter.resetForTest();
    expect(await CrashReporter.report('boom'), isFalse);
  });

  test('crash reporter never throws when the send itself fails', () async {
    CrashReporter.resetForTest();
    CrashReporter.configure(
      backend: _ThrowingBackend(),
      userId: () => 'user-1',
    );
    expect(await CrashReporter.report('boom'), isFalse);
    CrashReporter.resetForTest();
  });
}
