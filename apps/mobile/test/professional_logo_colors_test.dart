import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/ui/tinni_style.dart';

void main() {
  test('feature logos use distinct semantic accent colours', () {
    final party = DarkVibeXIconPalette.forIcon(Icons.groups_rounded);
    final discover = DarkVibeXIconPalette.forIcon(Icons.explore_rounded);
    final inbox = DarkVibeXIconPalette.forIcon(Icons.mail_rounded);
    final profile = DarkVibeXIconPalette.forIcon(Icons.person_rounded);

    expect(party.primary, DarkVibeXIconPalette.cyan);
    expect(discover.primary, DarkVibeXIconPalette.violet);
    expect(inbox.primary, DarkVibeXIconPalette.electricBlue);
    expect(profile.primary, DarkVibeXIconPalette.pink);
    expect(
      <Color>{
        party.primary,
        discover.primary,
        inbox.primary,
        profile.primary,
      }.length,
      4,
    );
  });

  testWidgets('glow icon renders its semantic colour', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TinniGlowIcon(icon: Icons.favorite_rounded),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
    expect(icon.color, DarkVibeXIconPalette.pink);
  });
}
