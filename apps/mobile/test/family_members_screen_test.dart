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

Map<String, dynamic> _request(String userId, String name) =>
    <String, dynamic>{
      'user_id': userId,
      'display_name': name,
      'avatar_key': '',
      'created_at': 0,
    };

/// Fake backend for the members-page controls: records every admin
/// action and answers familyDetail with the leader role + one pending
/// join request, so the screen can reload after an action.
class _FakeMembersBackend extends BackendApi {
  _FakeMembersBackend({this.myRole = 'leader'});

  final String? myRole;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>?> familyDetail({
    required String familyId,
  }) async => <String, dynamic>{
        'ok': true,
        'family': <String, dynamic>{
          'id': familyId,
          'name': 'ASTROPHILE',
          'tag': 'ASTRO',
          'my_role': myRole,
          'is_member': myRole != null,
        },
        'members': _demoMembers(),
        'join_requests': <Map<String, dynamic>>[
          _request('user-new', 'NewUser'),
        ],
      };

  @override
  Future<bool> resolveFamilyJoin({
    required String userId,
    required String targetUserId,
    required bool approve,
  }) async {
    calls.add('resolve:$targetUserId:${approve ? 'approve' : 'reject'}');
    return true;
  }

  @override
  Future<bool> setFamilyAdmin({
    required String userId,
    required String targetUserId,
    required bool admin,
  }) async {
    calls.add('admin:$targetUserId:${admin ? 'make' : 'remove'}');
    return true;
  }

  @override
  Future<bool> removeFamilyMember({
    required String userId,
    required String targetUserId,
  }) async {
    calls.add('remove:$targetUserId');
    return true;
  }

  @override
  Future<bool> leaveFamily({required String userId}) async {
    calls.add('leave');
    return true;
  }
}

/// Pumps the members screen on top of a home page, so Leave Family can
/// pop back to it.
Future<void> _openMembersScreen(
  WidgetTester tester, {
  required AppState state,
  required BackendApi backend,
  required List<Map<String, dynamic>> members,
  String? myRole,
  List<Map<String, dynamic>> joinRequests = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => FamilyMembersScreen(
                state: state,
                familyId: '10087',
                familyName: 'ASTROPHILE',
                members: members,
                myRole: myRole,
                joinRequests: joinRequests,
                backend: backend,
              ),
            ),
          ),
          child: const Text('open members'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open members'));
  await tester.pumpAndSettle();
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
    // "3 members" shows twice on the new detail page (cover hero +
    // members card header) — scope the check to the members card.
    expect(
      find.descendant(
        of: find.byKey(const Key('family-detail-member-list')),
        matching: find.text('3 members'),
      ),
      findsOneWidget,
    );
    // The new single-scroll page is long — the members card sits below
    // the fold, so scroll it into view before tapping.
    await tester.ensureVisible(
      find.byKey(const Key('family-detail-member-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-detail-member-list')));
    await tester.pumpAndSettle();
    // The members screen is on top now, showing the same members.
    expect(find.text('Leader • Coins: 8339.84M • Today'), findsOneWidget);
    expect(find.text('Admin • Coins: 1120.72M • Today'), findsOneWidget);
    expect(find.text('Member • Coins: 1542.60M • 1 day ago'), findsOneWidget);
  });

  testWidgets('leader can make a member admin from the members page',
      (tester) async {
    final state = AppState()
      ..userId = 'user-reo'
      ..vipLevel = 0;
    final backend = _FakeMembersBackend(myRole: 'leader');
    await _openMembersScreen(
      tester,
      state: state,
      backend: backend,
      members: <Map<String, dynamic>>[
        _member('user-reo', 'ReO', role: 'leader', coins: 8339840000),
        _member('user-akriti', 'akriti.', coins: 1542600000),
      ],
      myRole: 'leader',
    );
    // Only akriti (not the leader himself) gets the admin menu.
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('family-member-menu-user-akriti')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make admin'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('admin:user-akriti:make'));
  });

  testWidgets('leader can approve a join request from the members page',
      (tester) async {
    final state = AppState()
      ..userId = 'user-reo'
      ..vipLevel = 0;
    final backend = _FakeMembersBackend(myRole: 'leader');
    await _openMembersScreen(
      tester,
      state: state,
      backend: backend,
      members: _demoMembers(),
      myRole: 'leader',
      joinRequests: <Map<String, dynamic>>[_request('user-new', 'NewUser')],
    );
    expect(find.text('Join requests'), findsOneWidget);
    expect(find.text('NewUser'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('family-join-approve-user-new')),
    );
    await tester.pumpAndSettle();
    expect(backend.calls, contains('resolve:user-new:approve'));
  });

  testWidgets('member sees Leave Family but no admin menus',
      (tester) async {
    final state = AppState()
      ..userId = 'user-akriti'
      ..vipLevel = 0;
    final backend = _FakeMembersBackend(myRole: 'member');
    await _openMembersScreen(
      tester,
      state: state,
      backend: backend,
      members: _demoMembers(),
      myRole: 'member',
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Join requests'), findsNothing);
    expect(find.byKey(const Key('family-members-leave')), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-members-leave')));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('leave'));
    // Leaving pops back to the page underneath.
    expect(find.text('open members'), findsOneWidget);
  });

  testWidgets('outsider sees no controls on the members page',
      (tester) async {
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 0;
    final backend = _FakeMembersBackend(myRole: null);
    await _openMembersScreen(
      tester,
      state: state,
      backend: backend,
      members: _demoMembers(),
      myRole: null,
      joinRequests: const [],
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Join requests'), findsNothing);
    expect(find.byKey(const Key('family-members-leave')), findsNothing);
  });
}
