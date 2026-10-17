import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app/app_state.dart';
import '../lib/screens/login_screen.dart';

void main() {
  testWidgets('profile fields stay hidden before authentication', (tester) async {
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(state: state)),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byKey(const Key('create-id-country')), findsNothing);
    expect(find.byKey(const Key('complete-profile-button')), findsNothing);
    expect(find.text('Save Profile & Enter DarkVibeX'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('profile fields appear only after login when setup is required',
      (tester) async {
    final state = AppState()
      ..isAuthenticated = true
      ..needsProfileSetup = true;

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(state: state)),
    );

    expect(find.byKey(const Key('create-id-country')), findsOneWidget);
    expect(find.byKey(const Key('complete-profile-button')), findsOneWidget);
    expect(find.text('Save Profile & Enter DarkVibeX'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
