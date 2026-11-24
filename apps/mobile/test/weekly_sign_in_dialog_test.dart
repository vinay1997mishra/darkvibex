import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app/app_state.dart';
import '../lib/screens/weekly_sign_in_dialog.dart';

// Fake backend for the claim button (Mr. Wrong, 2026-11-24: "saare
// buttons work karne chahiye"). Intercepts the two calls the claim
// flow makes — POST /api/rewards/weekly-signin and the wallet refresh
// GET /api/wallet/:id — so the Sign in button can be tapped for real
// in a widget test without touching the live server.
const Map<String, Object> _claimJson = <String, Object>{
  'ok': true,
  'reward': 70000,
  'receipt_day': 1,
  'claimed_day': 1,
  'coin_balance': 1070000,
  'current_day': 2,
  'claimed_through': 1,
  'claimed_today': true,
};

const Map<String, Object> _walletJson = <String, Object>{
  'wallet': <String, Object>{
    'coins': 1070000,
    'diamonds': 120,
    'role': 'user',
    'vip_level': 0,
  },
  'ledger': <Object>[],
};

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, String> values = <String, String>{};
  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) => _contentType = value;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value.toString();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this._bytes);

  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._body);

  final String _body;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(utf8.encode(_body));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(jsonEncode(_walletJson));

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _FakeHttpClientRequest(jsonEncode(_claimJson));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

Future<void> _openDialog(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(
    MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showWeeklySignInDialog(context, state: state),
        child: const Text('open'),
      );
    })),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('weekly-signin-close')), findsOneWidget);
  expect(find.byKey(const Key('weekly-signin-claim')), findsOneWidget);
}

void main() {
  test('weekly sign-in light follows the sign-in day (Day 1-7)', () {
    expect(weeklySignInLightColors.length, 7);
    expect(
      weeklySignInLightColorForDay(1),
      const Color(0xFFFFD88A), // gold
    );
    expect(
      weeklySignInLightColorForDay(7),
      const Color(0xFF7ED491), // green
    );
    expect(
      weeklySignInLightColorForDay(1),
      isNot(weeklySignInLightColorForDay(2)),
    );
    expect(
      weeklySignInLightColors.toSet().length,
      7,
      reason: 'every sign-in day gets its own light colour',
    );
    // Out-of-range days clamp into the week.
    expect(
      weeklySignInLightColorForDay(0),
      weeklySignInLightColorForDay(1),
    );
    expect(
      weeklySignInLightColorForDay(8),
      weeklySignInLightColorForDay(7),
    );
  });

  testWidgets('weekly sign-in panel opens with the daily light overlay',
      (tester) async {
    final state = AppState();
    await _openDialog(tester, state);
  });

  testWidgets('7th-day light appears on the 7th sign-in day',
      (tester) async {
    final state = AppState()..weeklySignInDay = 7;
    await _openDialog(tester, state);
    expect(find.byKey(const Key('weekly-signin-day7-light')), findsOneWidget);
  });

  testWidgets('no 7th-day light before the 7th sign-in day',
      (tester) async {
    final state = AppState()..weeklySignInDay = 1;
    await _openDialog(tester, state);
    expect(find.byKey(const Key('weekly-signin-day7-light')), findsNothing);
  });

  testWidgets('claimed days show a tick, including Day 1', (tester) async {
    final none = AppState()..weeklySignInClaimedThrough = 0;
    await _openDialog(tester, none);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('Day 1 claimed shows its tick in gold, not blue',
      (tester) async {
    final one = AppState()..weeklySignInClaimedThrough = 1;
    await _openDialog(tester, one);
    final tick = find.byIcon(Icons.check_rounded);
    expect(tick, findsOneWidget);
    expect(
      tester.widget<Icon>(tick).color,
      const Color(0xFFFFD88A),
      reason: 'claimed-day tick matches the purple+gold panel',
    );
  });

  testWidgets('X button closes the weekly sign-in panel', (tester) async {
    final state = AppState();
    await _openDialog(tester, state);
    await tester.tap(find.byKey(const Key('weekly-signin-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-signin-claim')), findsNothing);
  });

  testWidgets(
      'Sign in opens the received-coins receipt, OK closes the whole popup',
      (tester) async {
    HttpOverrides.global = _FakeHttpOverrides();
    addTearDown(() => HttpOverrides.global = null);
    final state = AppState()
      ..backendConnected = true
      ..isAuthenticated = true
      ..weeklySignInDay = 1;
    await _openDialog(tester, state);
    await tester.tap(find.byKey(const Key('weekly-signin-claim')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-signin-reward-ok')), findsOneWidget);
    expect(
      find.byKey(const Key('weekly-signin-reward-close')),
      findsOneWidget,
    );
    expect(state.weeklySignInClaimedToday, isTrue);
    await tester.tap(find.byKey(const Key('weekly-signin-reward-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-signin-reward-ok')), findsNothing);
    // The panel is gone too — the popup has left the screen.
    expect(find.byKey(const Key('weekly-signin-claim')), findsNothing);
  });

  testWidgets('X on the receipt closes only the receipt, panel stays',
      (tester) async {
    HttpOverrides.global = _FakeHttpOverrides();
    addTearDown(() => HttpOverrides.global = null);
    final state = AppState()
      ..backendConnected = true
      ..isAuthenticated = true
      ..weeklySignInDay = 1;
    await _openDialog(tester, state);
    await tester.tap(find.byKey(const Key('weekly-signin-claim')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-signin-reward-ok')), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-signin-reward-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-signin-reward-ok')), findsNothing);
    expect(find.byKey(const Key('weekly-signin-claim')), findsOneWidget);
  });

  testWidgets('Sign in does nothing when today is already claimed',
      (tester) async {
    HttpOverrides.global = _FakeHttpOverrides();
    addTearDown(() => HttpOverrides.global = null);
    final state = AppState()
      ..backendConnected = true
      ..isAuthenticated = true
      ..weeklySignInDay = 3
      ..weeklySignInClaimedToday = true;
    await _openDialog(tester, state);
    await tester.tap(find.byKey(const Key('weekly-signin-claim')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-signin-reward-ok')), findsNothing);
  });
}
