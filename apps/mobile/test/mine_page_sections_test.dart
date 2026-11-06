import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openMinePage(
    WidgetTester tester,
    AppState state,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(state: state)),
    );
    await tester.tap(find.widgetWithText(TextButton, 'Mine'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Mine page renders owned room, Recents and My followings without layout errors',
    (tester) async {
      final state = AppState()
        ..userId = '12345678'
        ..backendConnected = false;
      state.rooms.add(
        const RoomSummary(
          id: 'room-1',
          displayId: '12345678',
          name: 'My test room',
          ownerName: 'Room owner',
          ownerUserId: '12345678',
          online: 1,
        ),
      );

      await openMinePage(tester, state);

      expect(find.text('My room'), findsOneWidget);
      expect(find.text('My test room'), findsOneWidget);
      expect(find.text('Recents'), findsOneWidget);
      expect(find.text('My followings'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets(
    'Mine page keeps the create-room empty state and the other sections',
    (tester) async {
      final state = AppState()
        ..userId = '12345678'
        ..backendConnected = false;

      await openMinePage(tester, state);

      expect(find.text('Create my room'), findsOneWidget);
      expect(find.text('Recents'), findsOneWidget);
      expect(find.text('My followings'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
