import 'dart:io';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/family_common.dart';
import 'package:darkvibex/screens/home_shell.dart';
import 'package:darkvibex/widgets/top_front_pill.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TopFrontPill (Vinay, 2026-11-23)', () {
    Widget pill({
      List<String> avatarUrls = const [],
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TopFrontPill(
            label: 'Top Rooms',
            gradientColors: const [Color(0xFFFFE9A8), Color(0xFFD09A0A)],
            textColor: const Color(0xFF3A2A00),
            avatarUrls: avatarUrls,
            avatarHeaders: const {},
            fallbackIcon: Icons.emoji_events_rounded,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    testWidgets('shows the label and the fallback icon with no avatars',
        (tester) async {
      await tester.pumpWidget(pill());
      expect(find.text('Top Rooms'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('tap calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(pill(onTap: () => tapped = true));
      await tester.tap(find.text('Top Rooms'));
      expect(tapped, isTrue);
    });

    testWidgets('shows up to 3 avatars, never more', (tester) async {
      await tester.pumpWidget(pill(avatarUrls: const [
        'https://example.invalid/a.png',
        'https://example.invalid/b.png',
        'https://example.invalid/c.png',
        'https://example.invalid/d.png',
      ]));
      await tester.pump();
      // The images fail to load in tests; errorBuilder shows the fallback,
      // but the Image widgets themselves are still built (max 3).
      expect(find.byType(Image), findsNWidgets(3));
    });
  });

  group('Party page fronts source (Vinay, 2026-11-23)', () {
    test('only Top Rooms + Top Family pills; old card row is gone', () {
      final source = File(
        'lib/screens/home_shell.dart',
      ).readAsStringSync();
      expect(source, contains("Key('party-top-rooms-pill')"));
      expect(source, contains("Key('party-top-family-pill')"));
      expect(source, contains("label: 'Top Rooms'"));
      expect(source, contains("label: 'Top Family'"));
      expect(source, isNot(contains('_QuickCard')));
      expect(source, isNot(contains("label: 'CP Ranking'")));
      // The pills open the same pages the old cards did.
      expect(source, contains('_openRankings(context, initialTab: 0)'));
      expect(source, contains('TopFamiliesScreen(state: state)'));
    });

    test('Party tab uses the light glass purple+gold background', () {
      final source = File(
        'lib/screens/home_shell.dart',
      ).readAsStringSync();
      // Both dark backgrounds of the Party tab are gone (the outer
      // _RoomsHome one and the inner _buildPartyPage one); the whole
      // tab sits on the FamilyBackground like Discover (Mr. Wrong,
      // 2026-11-24: purple+gold 3D background, like everywhere new).
      expect(source, isNot(contains('TinniBackground(')));
      expect(
        source,
        contains('the whole Party tab uses the same background'),
      );
      // Light-bg restyle: gold chips, dark count + tab labels.
      expect(source, contains('const Color(0xFFFFD54A)'));
      expect(source, contains('const Color(0xFF2A2140)'));
      // Vivid wash (Mr. Wrong, 2026-11-24): the pale glass alone
      // reads almost white on this page, so the Party tab asks for
      // the purple+gold gradient wash over the glass image.
      // (The call spans two lines: FamilyBackground( then vivid.)
      expect(source, contains('vivid: true'));
      // Banner = 15% of the screen height (Mr. Wrong, 2026-11-24:
      // "Screen ka 15% banner ke liye hona chahiye"), never below
      // 160 so the cards' content fits on a short screen.
      expect(
        source,
        contains('MediaQuery.sizeOf(context).height * 0.15'),
      );
      expect(source, contains('math.max('));
      expect(source, contains('160,'));
    });
  });

  group('Party page light background widget (Mr. Wrong, 2026-11-24)', () {
    AppState stateWithRooms() {
      final state = AppState()
        ..userId = '12345678'
        ..backendConnected = false;
      for (final (id, name, online) in [
        ('room-a', 'Room A', 48),
        ('room-b', 'Room B', 12),
      ]) {
        state.rooms.add(
          RoomSummary(
            id: id,
            displayId: id,
            name: name,
            ownerName: 'Owner of $name',
            ownerUserId: 'owner-$id',
            online: online,
          ),
        );
      }
      return state;
    }

    testWidgets('Party tab opens on the light glass background',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1565);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = stateWithRooms();
      await tester.pumpWidget(
        MaterialApp(home: HomeShell(state: state)),
      );
      await tester.pumpAndSettle();
      // Party is the default bottom tab: pills, chips and room count
      // render on the FamilyBackground (also used by Discover).
      expect(find.text('Top Rooms'), findsOneWidget);
      expect(find.text('🔥 Popular'), findsOneWidget);
      expect(find.text('2 rooms'), findsOneWidget);
      expect(find.byType(FamilyBackground), findsWidgets);
      // The Party tab asks for the vivid purple+gold wash: the pale
      // glass alone reads almost white on this page (Mr. Wrong,
      // 2026-11-24).
      final partyBackground = tester.widget<FamilyBackground>(
        find.byType(FamilyBackground).first,
      );
      expect(partyBackground.vivid, isTrue);
      // Banner = 15% of the screen height (Mr. Wrong, 2026-11-24);
      // the viewport here is 720x1565, so the banner box is 234.75.
      expect(
        find.ancestor(
          of: find.byType(PageView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.height == 1565 * 0.15,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Mine sub-tab renders its titles on the same light background.
      await tester.tap(find.text('Mine').first);
      await tester.pumpAndSettle();
      expect(find.text('My room'), findsOneWidget);
      expect(find.text('Recents'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  });
}
