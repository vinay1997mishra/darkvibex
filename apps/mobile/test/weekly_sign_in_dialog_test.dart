import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app/app_state.dart';
import '../lib/screens/weekly_sign_in_dialog.dart';

void main() {
  test('weekly sign-in light changes every day and repeats weekly', () {
    final day0 = DateTime.utc(2026, 11, 20);
    final day1 = DateTime.utc(2026, 11, 21);
    final day7 = DateTime.utc(2026, 11, 27);
    expect(weeklySignInLightColor(day0), isNot(weeklySignInLightColor(day1)));
    expect(weeklySignInLightColor(day0), weeklySignInLightColor(day7));
    expect(
      weeklySignInLightColor(DateTime.utc(2026, 11, 20, 23, 59)),
      weeklySignInLightColor(DateTime.utc(2026, 11, 20, 0, 1)),
    );
    expect(weeklySignInLightColors.length, 7);
  });

  testWidgets('weekly sign-in panel opens with the daily light overlay',
      (tester) async {
    final state = AppState();
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
  });
}
