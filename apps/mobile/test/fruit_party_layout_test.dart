import 'dart:ui' as ui;
import 'dart:io';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/fruit_party_screen.dart';
import 'package:darkvibex/vip/vip_visual_assets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppState> _openWithGame(
  WidgetTester tester,
  Map<String, dynamic> game,
) async {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = AppState();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFruitParty(context, state),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  final dynamic screen = tester.state(find.byType(FruitPartyScreen));
  screen.setState(() {
    screen.game = game;
    screen.loading = false;
  });
  await tester.pump();
  return state;
}

Future<void> _closeFruitParty(WidgetTester tester, AppState state) async {
  await tester.tap(find.byTooltip('Close Girls Party'));
  await tester.pumpAndSettle();
  expect(find.byType(FruitPartyScreen), findsNothing);
  await tester.pumpWidget(const SizedBox());
  state.dispose();
}

void main() {
  for (final size in [const Size(360, 640), const Size(412, 892)]) {
    testWidgets('Girls Party half-screen layout and Lucky rules at $size', (
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
      expect(find.text('Girls Party'), findsOneWidget);
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
      await tester.tap(find.byTooltip('Close Girls Party'));
      await tester.pumpAndSettle();
      expect(find.byType(FruitPartyScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }

  testWidgets('Girls Party winners strip shows top winners and gold timer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFruitParty(context, state),
              child: const Text('Open'),
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
          'phase': 'result_spin',
          'cycle_end': DateTime.now().millisecondsSinceEpoch + 8000,
        },
        'history': <Map<String, dynamic>>[
          {
            'round_id': 41,
            'fruit': {'key': 'cherry', 'emoji': '🍒'},
            'top_winners': [
              {'display_name': 'Jaya', 'winning_coins': 75000},
              {'display_name': 'Sam', 'winning_coins': 25000},
            ],
          },
        ],
        'my_bets': <String, dynamic>{},
        'wallet_balance': 2500000,
      };
      screen.loading = false;
    });
    await tester.pump();
    expect(find.byKey(const Key('fruit-party-winners-strip')), findsOneWidget);
    expect(find.text('Top winners'), findsOneWidget);
    expect(find.textContaining('Jaya · +75K'), findsOneWidget);
    expect(find.textContaining('Sam · +25K'), findsOneWidget);
    expect(
      find.text('You didn\'t select anything in this round.'),
      findsOneWidget,
    );
    expect(
      find.text('Select the amount of coins › Select kiss'),
      findsOneWidget,
    );
    expect(find.text('Coin Balance  2.5M'), findsOneWidget);
    expect(find.text('Profits of Today  0'), findsOneWidget);
    final timer = tester.widget<Text>(find.text('08'));
    expect(timer.style?.color, const Color(0xFFF5C542));
    expect(timer.style?.fontSize, 34);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close Girls Party'));
    await tester.pumpAndSettle();
    expect(find.byType(FruitPartyScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  testWidgets('Girls Party marquee lights spin continuously', (
    tester,
  ) async {
    final state = await _openWithGame(tester, <String, dynamic>{
      'round': {
        'round_id': 42,
        'phase': 'betting',
        'round_end': DateTime.now().millisecondsSinceEpoch + 21000,
      },
      'history': <Map<String, dynamic>>[],
      'wallet_balance': 2500000,
    });
    expect(
      find.byKey(const Key('fruit-party-lights-spinning')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fruit-party-lights')), findsNothing);
    final dynamic screen = tester.state(find.byType(FruitPartyScreen));
    screen.setState(() {
      screen.game = <String, dynamic>{
        'round': {
          'round_id': 42,
          'phase': 'result_spin',
          'cycle_end': DateTime.now().millisecondsSinceEpoch + 8000,
        },
        'history': <Map<String, dynamic>>[
          {
            'round_id': 41,
            'fruit': {'key': 'cherry', 'emoji': '🍒'},
            'top_winners': [],
          },
        ],
        'my_bets': <String, dynamic>{},
        'wallet_balance': 2500000,
      };
    });
    await tester.pump();
    expect(
      find.byKey(const Key('fruit-party-lights-spinning')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fruit-party-lights')), findsNothing);
    expect(find.text('Opening result: 08s'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _closeFruitParty(tester, state);
  });

  testWidgets(
    'Girls Party round-end popup shows the winning girl and top 3 winners',
    (tester) async {
      final state = await _openWithGame(tester, <String, dynamic>{
        'round': {
          'round_id': 42,
          'phase': 'result_spin',
          'cycle_end': DateTime.now().millisecondsSinceEpoch + 8000,
        },
        'history': <Map<String, dynamic>>[
          {
            'round_id': 41,
            'fruit': {'key': 'cherry', 'emoji': '🍒'},
            'top_winners': [
              {'display_name': 'Jaya', 'winning_coins': 75000},
              {'display_name': 'Sam', 'winning_coins': 25000},
            ],
          },
        ],
        'my_bets': <String, dynamic>{},
        'wallet_balance': 2500000,
      });
      expect(
        find.byKey(const Key('fruit-party-result-popup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('fruit-party-top3-winners')),
        findsOneWidget,
      );
      expect(find.text('WINNER'), findsOneWidget);
      expect(find.text('Cherry ×45'), findsOneWidget);
      expect(find.text('TOP 3 WINNERS'), findsOneWidget);
      expect(find.text('1. Jaya — +75K'), findsOneWidget);
      expect(find.text('2. Sam — +25K'), findsOneWidget);
      expect(find.text('Round #42 of Today'), findsOneWidget);
      expect(find.text('Opening result: 08s'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const Key('fruit-party-result-popup-close')),
      );
      await tester.pump();
      expect(find.byKey(const Key('fruit-party-result-popup')), findsNothing);
      await _closeFruitParty(tester, state);
    },
  );

  testWidgets('Girls Party grid has 8 girl tiles and 7 bet amounts incl 20M', (
    tester,
  ) async {
    final state = await _openWithGame(tester, <String, dynamic>{
      'round': {
        'round_id': 42,
        'phase': 'betting',
        'round_end': DateTime.now().millisecondsSinceEpoch + 21000,
      },
      'history': <Map<String, dynamic>>[],
      'wallet_balance': 2500000,
    });
    for (final key in [
      'lemon',
      'raspberry',
      'kiwi',
      'plum',
      'banana',
      'strawberry',
      'watermelon',
      'cherry',
    ]) {
      expect(
        find.byKey(Key('fruit-party-$key')),
        findsOneWidget,
        reason: key,
      );
    }
    for (final label in ['5K', '25K', '100K', '500K', '2M', '10M', '20M']) {
      expect(
        find.byKey(Key('fruit-party-bet-$label')),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.text('5 times'), findsNWidgets(4));
    expect(find.text('10 times'), findsOneWidget);
    expect(find.text('15 times'), findsOneWidget);
    expect(find.text('25 times'), findsOneWidget);
    expect(find.text('45 times'), findsOneWidget);
    expect(
      find.text('Select the amount of coins › Select kiss'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fruit-party-silver-lucky')), findsOneWidget);
    expect(find.byKey(const Key('fruit-party-gold-lucky')), findsOneWidget);
    expect(find.byKey(const Key('fruit-party-phase-tab')), findsOneWidget);
    expect(find.textContaining('Betting:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _closeFruitParty(tester, state);
  });

  test('Girls Party girls map one per fruit with distinct faces', () {
    expect(fruitPartyGirlForFruitKey('lemon'), 'purple');
    expect(fruitPartyGirlForFruitKey('raspberry'), 'blue');
    expect(fruitPartyGirlForFruitKey('kiwi'), 'red');
    expect(fruitPartyGirlForFruitKey('plum'), 'orange');
    expect(fruitPartyGirlForFruitKey('banana'), 'pink');
    expect(fruitPartyGirlForFruitKey('strawberry'), 'gold');
    expect(fruitPartyGirlForFruitKey('watermelon'), 'teal');
    expect(fruitPartyGirlForFruitKey('cherry'), 'green');
    expect(fruitPartyGirlForFruitKey('nope'), 'purple');
    final girls = [
      'lemon',
      'raspberry',
      'kiwi',
      'plum',
      'banana',
      'strawberry',
      'watermelon',
      'cherry',
    ].map(fruitPartyGirlForFruitKey).toSet();
    expect(girls.length, 8);
    expect(
      fruitPartyGirlKissUrl('blue'),
      contains('fruit-party/girls/blue-kiss.mp4'),
    );
    expect(
      fruitPartyGirlKissUrl('purple'),
      contains('greedy-girl/greedy-girl-kiss-emote.mp4'),
    );
    expect(
      fruitPartyGirlStillUrl('orange'),
      contains('fruit-party/girls/orange.jpg'),
    );
  });

  test('Girls Party uses the purple-gold palette, no deep blue', () {
    final source = File(
      'lib/screens/fruit_party_screen.dart',
    ).readAsStringSync();
    expect(source, contains('0xFFF5C542'));
    expect(source, contains('0xFF2A1155'));
    expect(source, contains('fruit-party-winners-strip'));
    expect(source, contains('Select the amount of coins › Select kiss'));
    expect(
      source,
      isNot(contains('Select the amount of coins › Select food')),
    );
    expect(source, contains('fruit-party-lights-spinning'));
    expect(source, contains('fruit-party-result-popup'));
    expect(source, contains('fruit-party-top3-winners'));
    expect(source, contains('fruitPartyGirlKissUrl'));
    expect(source, contains('20000000'));
    expect(source, contains('Opening result: '));
    expect(source, contains(' times'));
    expect(source, contains('fruit-party-bet-'));
    for (final banned in [
      '0xFF12224F',
      '0xFF0B1533',
      '0xFF1B3A6B',
      '0xFF85E7FF',
      '0xFF7BE7FF',
      '0xFF6258E8',
      '0xFF786CFF',
      '0xFF7662D5',
      '0xFF9A8CFF',
    ]) {
      expect(source, isNot(contains(banned)), reason: banned);
    }
  });
}
