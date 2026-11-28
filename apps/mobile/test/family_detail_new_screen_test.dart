// Family detail page — NEW design (Mr. Wrong, 2026-11-24): single-scroll
// page, spinnable Lucky Wheel, member search. The OLD tabbed page is
// removed, so these tests cover the new sections and the spin flow.
import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/family_detail_screen.dart';
import 'package:darkvibex/ui/tinni_style.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _member(
  String userId,
  String name, {
  String role = 'member',
  int coins = 0,
  int? lastSeenAt,
  int value = 0,
}) =>
    <String, dynamic>{
      'user_id': userId,
      'display_name': name,
      'avatar_key': '',
      'role': role,
      'received_coins': coins,
      'value': value,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
    };

class _FakeBackend extends BackendApi {
  _FakeBackend({this.hasSpun = false, this.drawsLeft = 9});

  final bool hasSpun;
  final int drawsLeft;
  int spinCalls = 0;

  Map<String, dynamic> _family() => <String, dynamic>{
        'id': '10087',
        'name': 'ASTROPHILE',
        'tag': 'ASTRO',
        'logo_key': '',
        'leader_name': 'ReO',
        'is_member': true,
        'experience': 98527071416,
        'level': 16,
        'next_exp': 104700000000,
        'rank': 'Silver III',
        'rank_progress': 1920789350,
        'rank_need': 7380000000,
        'notice': 'One Family • One Vibe • One Starsphere',
        'my_contributed_exp': 8339840000,
        'check_ins_today': 75,
        'wallet_coins': 24813200,
      };

  @override
  Future<Map<String, dynamic>?> familyDetail({
    required String familyId,
  }) async =>
      <String, dynamic>{
        'ok': true,
        'family': _family(),
        'members': <Map<String, dynamic>>[
          _member('user-reo', 'ReO', role: 'leader', coins: 8339840000),
          _member('user-sajid', 'Sajid', role: 'admin', coins: 1120720000),
          _member('user-zara', 'Zara Moon', coins: 500000),
        ],
        // Top members are different people from the member list, so
        // find.text on a member name matches exactly one widget.
        'top_members': <String, dynamic>{
          'charm': _member('user-luna', 'Luna Star', value: 1000),
          'wealth': _member('user-nova', 'NovaKing', value: 2000),
          'active': _member('user-celeste', 'Celeste', value: 3000),
        },
        'room': <String, dynamic>{
          'id': 'room-astro',
          'name': 'ASTROPHILE Family Room',
          'owner_user_id': 'user-reo',
          'live_count': 12,
          'seat_count': 12,
        },
        'wheel': <String, dynamic>{
          'draws_total': 12,
          'draws_used': 12 - drawsLeft,
          'draws_left': drawsLeft,
          'has_spun': hasSpun,
          'spins_left': hasSpun ? 0 : 1,
          'top_prize': 217688,
          'segments': <int>[
            34830,
            43538,
            58050,
            72563,
            87075,
            108845,
            145125,
            217688,
          ],
        },
      };

  @override
  Future<Map<String, dynamic>?> familyTasks() async => <String, dynamic>{
        'ok': true,
        'signed_in': false,
        'stay': <String, dynamic>{'minutes': 0, 'target': 20},
        'mic': <String, dynamic>{'minutes': 0, 'target': 10},
      };

  @override
  Future<List<Map<String, dynamic>>> familyLuckyDrawRecords({
    required String familyId,
    int limit = 100,
  }) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{'display_name': 'NIYA', 'coins': 163200},
        <String, dynamic>{'display_name': 'Ani', 'coins': 1020000},
      ];

  @override
  Future<Map<String, dynamic>?> familyLuckyWheelSpin({
    required String userId,
    required String familyId,
  }) async {
    spinCalls += 1;
    return <String, dynamic>{
      'ok': true,
      'coins': 58050,
      'draws_left': drawsLeft - 1,
      'draws_total': 12,
      'top_prize': 217688,
      'segments': <int>[
        34830,
        43538,
        58050,
        72563,
        87075,
        108845,
        145125,
        217688,
      ],
    };
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeBackend backend,
) async {
  final state = AppState()
    ..userId = 'user-1'
    ..vipLevel = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTinniStyleTheme(),
      home: FamilyDetailScreen(
        state: state,
        familyId: '10087',
        backend: backend,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
  state.dispose();
}

void main() {
  testWidgets('new detail page shows the wheel, records and search',
      (tester) async {
    final backend = _FakeBackend();
    await _pumpPage(tester, backend);
    expect(find.text('Daily Lucky Wheel'), findsOneWidget);
    expect(find.text('SPIN FREE'), findsOneWidget);
    expect(find.text('Lucky Draw Records'), findsOneWidget);
    expect(find.text('NIYA'), findsOneWidget);
    expect(find.text('Top members of the family'), findsOneWidget);
    expect(find.text('Charm Star'), findsOneWidget);
    expect(find.byKey(const Key('family-detail-member-search')),
        findsOneWidget);
    expect(find.text('ASTROPHILE Family Room'), findsOneWidget);
    expect(find.text('Level 16'), findsOneWidget);
    expect(find.text('Silver III'), findsWidgets);
    expect(find.text('One Family • One Vibe • One Starsphere'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SPIN FREE spins the wheel and shows the win',
      (tester) async {
    final backend = _FakeBackend();
    await _pumpPage(tester, backend);
    // The wheel is below the fold in the default 800x600 viewport —
    // scroll it into view before tapping, or the tap misses.
    // (ensureVisible, not scrollUntilVisible: the member search
    // TextField adds a second Scrollable, and scrollUntilVisible
    // fails on find.byType(Scrollable) matching more than one.)
    await tester.ensureVisible(find.byKey(const Key('family-detail-spin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-detail-spin')));
    // Let the 3.2s spin animation, the win pop, and the reload finish.
    // All animations on this page are one-shot, so pumpAndSettle ends.
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(backend.spinCalls, 1);
    // 58,050 formats as 58.05K (the app's number format).
    expect(find.textContaining('You won 58.05K coins!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel card writes out all 8 prize coin values',
      (tester) async {
    // Mr. Wrong, 2026-11-24: "Spin per coins bhi likhe nhi dikh rahe
    // hain" — the wheel artwork has no numbers on its segments, so
    // the 8 server-driven prize values are shown as chips under it.
    final backend = _FakeBackend();
    await _pumpPage(tester, backend);
    await tester.ensureVisible(find.byKey(const Key('family-wheel-prizes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-wheel-prizes')), findsOneWidget);
    expect(find.text('34.83K coins'), findsOneWidget);
    expect(find.text('217.69K coins'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the wheel itself spins it and lands on the win',
      (tester) async {
    // Mr. Wrong, 2026-11-24: "Wheel ghumna bhi chahiye" + "Random
    // coins amount win ke liye" — the wheel turns 5 rounds and stops
    // on the randomly-rolled prize segment, then shows the win.
    final backend = _FakeBackend();
    await _pumpPage(tester, backend);
    await tester.ensureVisible(find.byKey(const Key('family-wheel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-wheel')));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    expect(backend.spinCalls, 1);
    expect(find.textContaining('You won 58.05K coins!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member search filters the list', (tester) async {
    final backend = _FakeBackend();
    await _pumpPage(tester, backend);
    expect(find.text('Zara Moon'), findsOneWidget);
    expect(find.text('Sajid'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('family-detail-member-search')),
      'zara',
    );
    await tester.pump();
    expect(find.text('Zara Moon'), findsOneWidget);
    expect(find.text('Sajid'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('daily tasks section shows sign-in, stay, mic, gift, games',
      (tester) async {
    final backend = _FakeBackend();
    await _pumpPage(tester, backend);
    expect(find.text('Daily tasks'), findsOneWidget);
    expect(find.text('Stay in family room 20 min'), findsOneWidget);
    expect(find.text('Mic on 10 min'), findsOneWidget);
    expect(find.text('Send gift'), findsOneWidget);
    expect(find.text('Receive gift'), findsOneWidget);
    expect(find.text('Play games'), findsOneWidget);
    expect(find.text('405,000 EXP + 8,100 coins'), findsOneWidget);
    // No Trends on this page (Mr. Wrong, 2026-11-24: Trends goes).
    expect(find.text('Trends'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('already spun shows Come Back Tomorrow and cannot spin',
      (tester) async {
    final backend = _FakeBackend(hasSpun: true, drawsLeft: 8);
    await _pumpPage(tester, backend);
    await tester.ensureVisible(find.byKey(const Key('family-detail-spin')));
    await tester.pumpAndSettle();
    expect(find.text('Come Back Tomorrow'), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-detail-spin')));
    await tester.pump();
    expect(backend.spinCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
