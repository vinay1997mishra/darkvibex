import 'package:darkvibex/widgets/level_medal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rocket medal chip renders the real rocket medal image',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileMedalChip(
            medal: <String, dynamic>{
              'id': 'rocket-6',
              'name': 'Rocket Lv.6 — Gold Rush',
              'color': '#69C9FF',
              'series': 'rocket',
              'level': 6,
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final medal = tester.widget<LevelMedal>(find.byType(LevelMedal));
    expect(medal.series, MedalSeries.rocket);
    expect(medal.level, 6);
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'Rocket Lv.6 — Gold Rush',
    );
    expect(find.byIcon(Icons.workspace_premium_rounded), findsNothing);
  });

  testWidgets('non-rocket medals keep the generic premium icon',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileMedalChip(
            medal: <String, dynamic>{
              'id': 'vip',
              'name': 'VIP',
              'color': '#D09A0A',
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LevelMedal), findsNothing);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'VIP',
    );
  });

  testWidgets('rocket medal with an out-of-range level falls back to the icon',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileMedalChip(
            medal: <String, dynamic>{
              'id': 'rocket-99',
              'name': 'Rocket Lv.99',
              'color': '#69C9FF',
              'series': 'rocket',
              'level': 99,
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LevelMedal), findsNothing);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
  });
}
