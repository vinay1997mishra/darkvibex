import 'package:darkvibex/app/darkvibex_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('main navigation renders', (tester) async {
    await tester.pumpWidget(const DarkVibeXApp());
    await tester.pumpAndSettle();

    expect(find.text('DarkVibeX'), findsOneWidget);
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
  });
}
