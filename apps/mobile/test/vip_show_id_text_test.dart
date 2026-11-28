import 'package:darkvibex/vip/vip_policy.dart';
import 'package:darkvibex/widgets/vip_show_id_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<Text> pumpId(WidgetTester tester, int vipLevel) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VipShowIdText(
            text: 'ID 123456',
            vipLevel: vipLevel,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<Text>(find.text('ID 123456'));
  }

  testWidgets('show-id skin: VIP5+ ID renders in the level colour, bold',
      (tester) async {
    for (final level in <int>[5, 10, 14]) {
      final text = await pumpId(tester, level);
      final colour = VipPolicy.nameColourForLevel(level)!;
      expect(text.style?.color, colour);
      expect(text.style?.fontWeight, FontWeight.w800);
    }
  });

  testWidgets('show-id skin: VIP15-18 keep the VIP14 style',
      (tester) async {
    for (final level in <int>[15, 18]) {
      final text = await pumpId(tester, level);
      final colour = VipPolicy.nameColourForLevel(14)!;
      expect(text.style?.color, colour);
      expect(text.style?.fontWeight, FontWeight.w800);
    }
  });

  testWidgets('show-id skin: below VIP5 the ID keeps the plain style',
      (tester) async {
    for (final level in <int>[0, 4]) {
      final text = await pumpId(tester, level);
      expect(text.style?.color, Colors.black54);
      expect(text.style?.fontWeight, isNot(FontWeight.w800));
    }
  });
}
