import 'dart:ui' as ui;
import 'dart:io';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/fruit_party_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(412, 892)]) {
    testWidgets('Fruit Party half-screen layout and Lucky rules at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('preview'),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showFruitParty(context, state),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final dynamic screen = tester.state(find.byType(FruitPartyScreen));
      screen.setState(() {
        screen.game = <String, dynamic>{
          'round': {
            'round_id': 42,
            'phase': 'betting',
            'round_end': DateTime.now().millisecondsSinceEpoch + 21000,
          },
          'history': <Map<String, dynamic>>[],
          'wallet_balance': 2500000,
        };
        screen.loading = false;
      });
      await tester.pump();
      expect(
        tester.getSize(find.byType(FruitPartyScreen)).height,
        size.height * .5,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Fruit Party'), findsOneWidget);
      final silver = find.byKey(const Key('fruit-party-silver-lucky'));
      final gold = find.byKey(const Key('fruit-party-gold-lucky'));
      expect(tester.getCenter(silver).dx, lessThan(tester.getCenter(gold).dx));
      expect(tester.getCenter(silver).dy, tester.getCenter(gold).dy);
      await tester.tap(silver);
      await tester.pump();
      expect(find.textContaining('Silver Lucky •'), findsOneWidget);
      expect(find.textContaining('Gold Lucky •'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back to game'));
      await tester.pump();
      // Optional local visual QA, excluded from CI artifacts.
      if (Platform.environment['FRUIT_PREVIEW'] == '1') {
        final boundary = tester.renderObject(find.byKey(const Key('preview')));
        if (boundary is RenderRepaintBoundary) {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/fruit-party-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        }
      }
      await tester.tap(find.byTooltip('Close Fruit Party'));
      await tester.pumpAndSettle();
      expect(find.byType(FruitPartyScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
}
