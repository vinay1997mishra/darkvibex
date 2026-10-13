import 'package:darkvibex/app/darkvibex_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login screen renders', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await tester.pumpWidget(const DarkVibeXApp());
    await tester.pumpAndSettle();

    expect(find.text('DarkVibeX'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });
}
