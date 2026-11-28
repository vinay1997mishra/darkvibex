// Top Families page (Mr. Wrong, 2026-11-24 — v9 design): the new main
// family page that PERMANENTLY REPLACES the old FamilyRankingScreen.
// Top-3 shields + rank rows + countdown + Local/Global scope + create /
// join for users who have not joined a family yet.
import 'dart:io';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/top_families_screen.dart';
import 'package:darkvibex/screens/create_family_screen.dart';
import 'package:darkvibex/screens/family_join_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFamilyBackend extends BackendApi {
  _FakeFamilyBackend({
    required this.rows,
    this.hasFamily = false,
    this.joinReturnsJoined = false,
  });

  final List<Map<String, dynamic>> rows;
  bool hasFamily;

  /// When true, requestFamilyJoin reports a direct join (open family)
  /// and flips hasFamily, like the server would.
  final bool joinReturnsJoined;

  /// The country each familyList() call asked for (null = Global).
  final List<String?> countryCalls = [];

  /// The family id each requestFamilyJoin() call asked for.
  final List<String> joinCalls = [];

  /// The (name, tag) each createFamily() call asked for.
  final List<(String, String)> createCalls = [];

  @override
  Future<List<Map<String, dynamic>>> familyList({String? country}) async {
    countryCalls.add(country);
    if (country == null || country.isEmpty) return rows;
    return rows
        .where(
          (row) =>
              (row['leader_country_code']?.toString().toUpperCase() ?? '') ==
              country.toUpperCase(),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> familyState({
    required String userId,
  }) async {
    return <String, dynamic>{
      'family': hasFamily
          ? <String, dynamic>{
              'id': 'family-1',
              'name': 'TIGER FAMILY',
              'tag': 'TIGER',
              'level': 7,
            }
          : null,
      'members': const [],
      'join_requests': const [],
      'available_families': const [],
    };
  }

  @override
  Future<Map<String, dynamic>?> createFamily({
    required String userId,
    required String name,
    required String tag,
    bool approvalRequired = true,
    String? logoKey,
  }) async {
    createCalls.add((name, tag));
    hasFamily = true;
    return <String, dynamic>{'ok': true, 'family_id': 'family-new'};
  }

  @override
  Future<({bool ok, bool joined})> requestFamilyJoin({
    required String userId,
    required String familyId,
  }) async {
    joinCalls.add(familyId);
    if (joinReturnsJoined) hasFamily = true;
    return (ok: true, joined: joinReturnsJoined);
  }

  @override
  Future<Map<String, dynamic>?> socialStats({
    required String userId,
  }) async =>
      <String, dynamic>{'wealth': <String, dynamic>{'level': 0}};
}

List<Map<String, dynamic>> _rows() => <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'family-1',
    'name': 'TIGER FAMILY',
    'tag': 'TIGER',
    'leader_user_id': 'leader-1',
    'leader_name': 'Tiger',
    'leader_avatar_key': '',
    'leader_country_code': 'IN',
    'member_count': 120,
    'experience': 58700000,
    'level': <String, dynamic>{'level': 7, 'next_exp': 150000},
  },
  <String, dynamic>{
    'id': 'family-2',
    'name': 'ASTRO',
    'tag': 'ASTRO',
    'leader_user_id': 'leader-2',
    'leader_name': 'Astro',
    'leader_avatar_key': '',
    'leader_country_code': 'IN',
    'member_count': 98,
    'experience': 34947000,
    'level': <String, dynamic>{'level': 6, 'next_exp': 50000},
  },
  <String, dynamic>{
    'id': 'family-3',
    'name': 'AS FAMILY',
    'tag': 'ASF',
    'leader_user_id': 'leader-3',
    'leader_name': 'As',
    'leader_avatar_key': '',
    'leader_country_code': 'US',
    'member_count': 87,
    'experience': 28768000,
    'level': <String, dynamic>{'level': 5, 'next_exp': 15000},
  },
  <String, dynamic>{
    'id': 'family-4',
    'name': 'Star Family',
    'tag': 'STAR',
    'leader_user_id': 'leader-4',
    'leader_name': 'Star',
    'leader_avatar_key': '',
    'leader_country_code': 'IN',
    'member_count': 64,
    'experience': 12000000,
    'level': <String, dynamic>{'level': 4, 'next_exp': 5000},
  },
  <String, dynamic>{
    'id': 'family-5',
    'name': 'Royal Family',
    'tag': 'ROYAL',
    'leader_user_id': 'leader-5',
    'leader_name': 'Royal',
    'leader_avatar_key': '',
    'leader_country_code': 'IN',
    'member_count': 55,
    'experience': 8000000,
    'level': <String, dynamic>{'level': 3, 'next_exp': 1500},
  },
  <String, dynamic>{
    'id': 'family-6',
    'name': 'Dream Family',
    'tag': 'DREAM',
    'leader_user_id': 'leader-6',
    'leader_name': 'Dream',
    'leader_avatar_key': '',
    'leader_country_code': 'US',
    'member_count': 41,
    'experience': 3000000,
    'level': <String, dynamic>{'level': 2, 'next_exp': 500},
  },
];

Future<void> _pumpPage(
  WidgetTester tester,
  AppState state,
  _FakeFamilyBackend backend,
) async {
  await tester.pumpWidget(
    MaterialApp(home: TopFamiliesScreen(state: state, backend: backend)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('top families shows shields, rows, countdown and join bar',
      (tester) async {
    final backend = _FakeFamilyBackend(rows: _rows());
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    // Top-3 shields (names + EXP on the plaques). Local (IN) filters
    // out the US family, so the shields are TIGER / ASTRO / Star.
    expect(find.text('TIGER FAMILY'), findsWidgets);
    expect(find.text('EXP 58.7M'), findsWidgets);
    expect(find.text('ASTRO'), findsWidgets);
    expect(find.text('Star Family'), findsOneWidget);
    expect(find.text('AS FAMILY'), findsNothing);
    expect(find.text('LV.4'), findsWidgets);
    // Rank 4+ rows: only Royal is left (rank 4). The shields are tall,
    // so the row is below the fold until scrolled to.
    await tester.scrollUntilVisible(
      find.byKey(const Key('top-family-row-4')),
      500,
    );
    await tester.pump();
    expect(find.byKey(const Key('top-family-row-4')), findsOneWidget);
    expect(find.text('Royal Family'), findsOneWidget);
    expect(find.text('LV.3'), findsWidgets);
    // Monthly countdown strip + Local scope + bottom bar.
    expect(find.byKey(const Key('top-family-countdown')), findsOneWidget);
    expect(find.textContaining('Countdown (UTC+3):'), findsOneWidget);
    expect(find.byKey(const Key('top-family-scope')), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.byKey(const Key('top-family-bottom-bar')), findsOneWidget);
    expect(find.byKey(const Key('top-family-create')), findsOneWidget);
    expect(find.byKey(const Key('top-family-join')), findsOneWidget);
    expect(
      find.text(
        'You have not joined the family yet. Please create or join it first',
      ),
      findsOneWidget,
    );
    // Local asked for the user's country.
    expect(backend.countryCalls, <String?>['IN']);
  });

  testWidgets('global scope reloads without a country', (tester) async {
    final backend = _FakeFamilyBackend(rows: _rows());
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    await tester.tap(find.byKey(const Key('top-family-scope-global')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.countryCalls, <String?>['IN', null]);
    expect(find.text('Global'), findsOneWidget);
    // Global shows the US family that Local filtered out.
    expect(find.text('AS FAMILY'), findsWidgets);
  });

  testWidgets('search filters the list by name', (tester) async {
    final backend = _FakeFamilyBackend(rows: _rows());
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    await tester.tap(find.byKey(const Key('top-family-search')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('top-family-search-field')),
      'royal',
    );
    await tester.pump();
    expect(find.text('Royal Family'), findsOneWidget);
    expect(find.text('Star Family'), findsNothing);
    expect(find.text('Dream Family'), findsNothing);
  });

  testWidgets('tapping a row opens the family dialog and joins',
      (tester) async {
    final backend = _FakeFamilyBackend(rows: _rows());
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    await tester.scrollUntilVisible(
      find.byKey(const Key('top-family-row-4')),
      500,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('top-family-row-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Royal Family'), findsWidgets);
    expect(find.text('Leader: Royal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('top-family-dialog-join')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.joinCalls, <String>['family-5']);
    expect(find.text('Join request sent'), findsOneWidget);
  });

  testWidgets('direct join (open family) says Joined, not request sent',
      (tester) async {
    // Mr. Wrong, 2026-11-24: Join dabane ke baad family me join nahi
    // dikh raha tha — the old bool-only return made every join look
    // like a request. An open family joins directly.
    final backend = _FakeFamilyBackend(
      rows: _rows(),
      joinReturnsJoined: true,
    );
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    await tester.scrollUntilVisible(
      find.byKey(const Key('top-family-row-4')),
      500,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('top-family-row-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('top-family-dialog-join')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.joinCalls, <String>['family-5']);
    expect(find.text('Joined the family!'), findsOneWidget);
    expect(find.text('Join request sent'), findsNothing);
  });

  testWidgets('joining from the Join page reloads Top Families as joined',
      (tester) async {
    // Mr. Wrong, 2026-11-24: Join page se join karke wapas aane par
    // bhi "not joined yet" dikh raha tha — the Join push never
    // reloaded on return. Now the Join page pops `true` on a direct
    // join and Top Families reloads (bottom bar goes away).
    final backend = _FakeFamilyBackend(
      rows: _rows(),
      joinReturnsJoined: true,
    );
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    expect(find.byKey(const Key('top-family-bottom-bar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('top-family-join')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FamilyJoinScreen), findsOneWidget);
    // ensureVisible, not scrollUntilVisible: the Join page has more
    // than one Scrollable and scrollUntilVisible fails "Too many
    // elements" (same lesson as the detail-page tests).
    await tester.ensureVisible(
      find.byKey(const Key('family-join-apply-family-1')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('family-join-apply-family-1')));
    await tester.pump();
    // The pop transition takes ~300ms: pump past it (not pumpAndSettle
    // — Top Families runs a 1s countdown timer, so it never settles).
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FamilyJoinScreen), findsNothing);
    expect(find.text('Joined the family!'), findsOneWidget);
    expect(find.byKey(const Key('top-family-bottom-bar')), findsNothing);
  });

  testWidgets('create opens the full create family page',
      (tester) async {
    final backend = _FakeFamilyBackend(rows: _rows());
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    await tester.tap(find.byKey(const Key('top-family-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The full Create Family page opens (the small dialog is superseded).
    expect(find.byType(CreateFamilyScreen), findsOneWidget);
    expect(find.byKey(const Key('create-family-submit')), findsOneWidget);
  });

  testWidgets('a user with a family sees no create/join bar',
      (tester) async {
    final backend = _FakeFamilyBackend(rows: _rows(), hasFamily: true);
    final state = AppState()
      ..userId = 'user-1'
      ..countryCode = 'IN';
    await _pumpPage(tester, state, backend);
    expect(find.byKey(const Key('top-family-bottom-bar')), findsNothing);
    expect(find.byKey(const Key('top-family-create')), findsNothing);
    expect(find.byKey(const Key('top-family-join')), findsNothing);
  });

  test('countdown is the time to the end of the month (UTC+3)', () {
    // 2026-11-23 19:00 UTC = 22:00 in UTC+3; November has 30 days, so
    // 7 days + 2 hours remain in the month.
    final remaining = TopFamiliesScreen.monthRemaining(
      DateTime.utc(2026, 11, 23, 19),
    );
    expect(remaining.inDays, 7);
    expect(remaining.inHours % 24, 2);
    expect(
      TopFamiliesScreen.formatCountdown(const Duration(days: 7, hours: 3, minutes: 20, seconds: 49)),
      '07 Day 03:20:49',
    );
  });

  test('compact formats EXP like the ranking screen', () {
    expect(TopFamiliesScreen.compact(58700000), '58.7M');
    expect(TopFamiliesScreen.compact(1200000), '1.2M');
    expect(TopFamiliesScreen.compact(5000), '5.0K');
    expect(TopFamiliesScreen.compact(999), '999');
  });

  test('family level is read from the list row map shape', () {
    // familyList() returns level as {level, next_exp} (tinni_social.js).
    // A plain int.parse of that map would fail and hide the LV pill.
    expect(
      TopFamiliesScreen.familyLevelOf(
        <String, dynamic>{'level': <String, dynamic>{'level': 7, 'next_exp': 150000}},
      ),
      7,
    );
    expect(
      TopFamiliesScreen.familyLevelOf(
        <String, dynamic>{'level': 4},
      ),
      4,
    );
  });

  test('Mine page Family tile opens the NEW Top Families page', () {
    // Mine > Family used to open the old FamilyScreen (dark, own create
    // dialog + ranking list). It now opens TopFamiliesScreen — the same
    // v9 page the Party tab opens (Mr. Wrong, 2026-11-24).
    final source = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(source, contains('TopFamiliesScreen(state: state)'));
    expect(source, isNot(contains('FamilyScreen(state: state)')));
  });
}
