// Family members page (Mr. Wrong, 2026-11-24): tapping the "N members"
// section on the Family Detail page opens the full members list, like in
// the reference video — leader first, then admins, then members, each
// with coins and last login.
import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/family_detail_screen.dart';
import 'package:darkvibex/screens/family_members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _member(
  String userId,
  String name, {
  String role = 'member',
  int coins = 0,
  int? lastSeenAt,
}) =>
    <String, dynamic>{
      'user_id': userId,
      'display_name': name,
      'avatar_key': '',
      'role': role,
      'received_coins': coins,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
    };

List<Map<String, dynamic>> _demoMembers() {
  final now = DateTime.now().millisecondsSinceEpoch;
  const day = 86400000;
  return <Map<String, dynamic>>[
    _member('user-reo', 'ReO',
        role: 'leader', coins: 8339840000, lastSeenAt: now),
    _member('user-sajid', 'Sajid',
        role: 'admin', coins: 1120720000, lastSeenAt: now),
    _member('user-akriti', 'akriti.',
        coins: 1542600000, lastSeenAt: now - day),
  ];
}

class _FakeDetailBackend extends BackendApi {
  @override
  Future<Map<String, dynamic>?> familyDetail({
    required String familyId,
  }) async =>
      <String, dynamic>{
        'ok': true,
        'family': <String, dynamic>{
          'id': familyId,
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
        },
        'members': _demoMembers(),
        'top_members': <String, dynamic>{
          'charm': _member('user-reo', 'ReO',
              role: 'leader', coins: 8339840000),
          'wealth': _member('user-akriti', 'akriti.',
              coins: 1542600000),
          'active': _member('user-reo', 'ReO',
              role: 'leader', coins: 8339840000),
        },
        'room': <String, dynamic>{
          'id': 'room-astro',
          'name': 'ASTROPHILE Family Room',
          'owner_user_id': 'user-reo',
          'live_count': 12,
          'seat_count': 12,
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
  Future<List<Map<String, dynamic>>> familyTrends({
    required String familyId,
    int limit = 50,
  }) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> familyLuckyDrawRecords({
    required String familyId,
    int limit = 100,
  }) async =>
      <Map<String, dynamic>>[];
}

void main() {
  testWidgets('members screen shows every member with role, coins and last login',
      (tester) async {
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 0;
    final backend = _FakeDetailBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyMembersScreen(
          state: state,
          familyId: '10087',
          familyName: 'ASTROPHILE',
          members: _demoMembers(),
          backend: backend,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('ReO'), findsOneWidget);
    expect(find.text('Leader • Coins: 8339.84M • Today'), findsOneWidget);
    expect(find.text('Sajid'), findsOneWidget);
    expect(find.text('Admin • Coins: 1120.72M • Today'), findsOneWidget);
    expect(find.text('akriti.'), findsOneWidget);
    expect(find.text('Member • Coins: 1542.60M • 1 day ago'), findsOneWidget);
  });

  testWidgets('tapping the detail member list opens the members screen',
      (tester) async {
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 0;
    final backend = _FakeDetailBackend();
    tester.view.physicalSize = const Size(720, 1565);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailScreen(
          state: state,
          familyId: '10087',
          backend: backend,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 members'), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-detail-member-list')));
    await tester.pumpAndSettle();
    // The members screen is on top now, showing the same members.
    expect(find.text('Leader • Coins: 8339.84M • Today'), findsOneWidget);
    expect(find.text('Admin • Coins: 1120.72M • Today'), findsOneWidget);
    expect(find.text('Member • Coins: 1542.60M • 1 day ago'), findsOneWidget);
  });
}
