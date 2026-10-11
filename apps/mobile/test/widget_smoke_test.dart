import 'package:darkvibex/app/darkvibex_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login screen renders', (tester) async {
    await tester.pumpWidget(const DarkVibeXApp());
    await tester.pumpAndSettle();

    expect(find.text('DarkVibeX'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });
}
