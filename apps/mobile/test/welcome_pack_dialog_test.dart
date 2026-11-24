import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/app/app_state.dart';
import '../lib/screens/welcome_pack_dialog.dart';

AppState _newUserState() {
  final state = AppState()
    ..vipLevel = 1
    ..vipActiveUntil = DateTime.now().add(const Duration(days: 15))
    ..welcomePackReady = true
    ..welcomePackExpiresAt = DateTime.now().add(const Duration(days: 15))
    ..welcomePackSeen = false;
  return state;
}

Future<void> _openDialog(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(
    MaterialApp(home: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showWelcomePackDialog(context, state: state),
        child: const Text('open'),
      );
    })),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome pack pop-up shows coins + VIP1 for 15 days',
      (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final state = _newUserState();
    await _openDialog(tester, state);
    expect(find.text('Welcome to DarkVibeX!'), findsOneWidget);
    expect(find.text('Your Welcome Pack is ready'), findsOneWidget);
    expect(find.text('+500,000 coins'), findsOneWidget);
    expect(find.text('VIP 1 FREE for 15 days'), findsOneWidget);
    expect(find.textContaining('until'), findsOneWidget);
    expect(find.text('Start Exploring'), findsOneWidget);
  });

  testWidgets('tapping Start Exploring dismisses and marks the pack seen',
      (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final state = _newUserState();
    await _openDialog(tester, state);
    await tester.tap(find.text('Start Exploring'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to DarkVibeX!'), findsNothing);
    expect(state.welcomePackSeen, isTrue);
  });
}
