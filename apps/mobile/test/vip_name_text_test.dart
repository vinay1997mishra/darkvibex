import 'package:darkvibex/vip/vip_policy.dart';
import 'package:darkvibex/widgets/vip_name_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Text> pumpName(WidgetTester tester, int vipLevel) async {
    const baseStyle = TextStyle(fontSize: 16, color: Colors.white);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VipNameText(
            name: 'Rahul',
            vipLevel: vipLevel,
            style: baseStyle,
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<Text>(find.text('Rahul'));
  }

  testWidgets('nickname light: VIP8-17 names glow in their level colour',
      (tester) async {
    for (final level in <int>[8, 12, 17]) {
      final text = await pumpName(tester, level);
      final colour = VipPolicy.nameColourForLevel(level)!;
      expect(text.style?.color, colour);
      final shadows = text.style?.shadows ?? const <Shadow>[];
      expect(shadows, isNotEmpty,
          reason: 'VIP$level name should have a light-effect shadow');
      expect(shadows.any((s) => s.color == colour && s.blurRadius == 10),
          isTrue);
    }
  });

  testWidgets('nickname light: below VIP8 there is no glow',
      (tester) async {
    for (final level in <int>[0, 5, 7]) {
      final text = await pumpName(tester, level);
      final shadows = text.style?.shadows ?? const <Shadow>[];
      expect(shadows, isEmpty, reason: 'VIP$level name must not glow');
    }
  });

  testWidgets('nickname light: VIP18 gradient branch has no glow shadow',
      (tester) async {
    // VIP18 renders through a ShaderMask, not a plain Text.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VipNameText(
            name: 'Rahul',
            vipLevel: 18,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);
  });
}
