import 'package:darkvibex/widgets/level_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ID level pill colours change every 10 levels (Vinay, 2026-11-23)', () {
    // From Vinay's Level screenshots: silver, copper, blue, green,
    // purple, blue, orange, green, purple.
    expect(idLevelTagColor(2), const Color(0xFF7C8AA5));
    expect(idLevelTagColor(17), const Color(0xFFB4653A));
    expect(idLevelTagColor(25), const Color(0xFF3B82F6));
    expect(idLevelTagColor(33), const Color(0xFF22A06B));
    expect(idLevelTagColor(45), const Color(0xFF8B5CF6));
    expect(idLevelTagColor(66), const Color(0xFFF59E0B));
    // Bands repeat every 90 levels; the top level 200 is gold.
    expect(idLevelTagColor(92), const Color(0xFF7C8AA5));
    expect(idLevelTagColor(199), const Color(0xFFB4653A));
    expect(idLevelTagColor(200), const Color(0xFFD09A0A));
  });

  test('wealth tag colours change every 10 levels (Vinay, 2026-11-23)', () {
    // SVGA dollar-level pack: grey, green, teal, blue, purple, indigo,
    // pink, magenta, ice-blue, orange, red — then they repeat.
    expect(wealthTagColor(3), const Color(0xFF6B7280));
    expect(wealthTagColor(12), const Color(0xFF22A06B));
    expect(wealthTagColor(25), const Color(0xFF0D9488));
    expect(wealthTagColor(45), const Color(0xFF8B5CF6));
    expect(wealthTagColor(105), const Color(0xFFEF4444));
    expect(wealthTagColor(113), const Color(0xFF6B7280));
  });

  testWidgets('ID level pill shows Lv.N with a shield and a 3D glow',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: IdLevelTag(level: 2, fontSize: 11)),
        ),
      ),
    );

    expect(find.text('Lv.2'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    // 3D: a vertical gradient (gloss on top, shade at the bottom) and
    // a glow shadow in the pill's own colour.
    final container = tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient is LinearGradient,
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.boxShadow, isNotEmpty);
    expect(decoration.boxShadow!.first.color,
        idLevelTagColor(2).withValues(alpha: .55));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wealth tag shows the gold dollar coin and the level number',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: WealthTag(level: 12, fontSize: 11)),
        ),
      ),
    );

    expect(find.text('\$'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Lv.12'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both tags render nothing below level 1', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                IdLevelTag(level: 0),
                WealthTag(level: 0),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Lv.0'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('\$'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
