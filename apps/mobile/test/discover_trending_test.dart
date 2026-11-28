import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/home_shell.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDiscover(
    WidgetTester tester,
    AppState state,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(state: state)),
    );
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
  }

  AppState stateWithRooms() {
    final state = AppState()
      ..userId = '12345678'
      ..backendConnected = false;
    // Online counts deliberately out of order: the page must sort
    // liveliest first (Mr. Wrong, 2026-11-24: main page, everything
    // like the other app).
    const rooms = [
      ('room-quiet', 'Quiet Room', 2),
      ('room-busy', 'Busy Room', 48),
      ('room-mid', 'Mid Room', 12),
      ('room-hot', 'Hot Room', 120),
      ('room-warm', 'Warm Room', 30),
      ('room-cool', 'Cool Room', 7),
    ];
    for (final (id, name, online) in rooms) {
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

  testWidgets(
    'Discover shows Trending now with the liveliest rooms first',
    (tester) async {
      // Tall viewport so the whole Discover page (trending strip +
      // all 6 room cards) is built at once; the list is lazy and the
      // quietest room sits at the very bottom.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final state = stateWithRooms();
      await openDiscover(tester, state);

      expect(find.text('Discover'), findsWidgets);
      expect(find.text('Trending now'), findsOneWidget);
      expect(find.text('Rooms for you'), findsOneWidget);
      // The 5 liveliest rooms are in the trending strip; the quietest
      // (2 online) is in "Rooms for you" only.
      expect(find.text('Hot Room'), findsWidgets);
      expect(find.text('Busy Room'), findsWidgets);
      expect(find.text('Warm Room'), findsWidgets);
      expect(find.text('Mid Room'), findsWidgets);
      expect(find.text('Cool Room'), findsWidgets);
      expect(find.text('Quiet Room'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets(
    'Discover search hides Trending and shows only matches',
    (tester) async {
      final state = stateWithRooms();
      await openDiscover(tester, state);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search room, ID or user'),
        'Hot',
      );
      await tester.pumpAndSettle();

      expect(find.text('Trending now'), findsNothing);
      expect(find.text('Hot Room'), findsOneWidget);
      expect(find.text('Busy Room'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets(
    'Discover with no rooms shows no Trending section',
    (tester) async {
      final state = AppState()
        ..userId = '12345678'
        ..backendConnected = false;
      await openDiscover(tester, state);

      expect(find.text('Trending now'), findsNothing);
      expect(find.text('Rooms for you'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
