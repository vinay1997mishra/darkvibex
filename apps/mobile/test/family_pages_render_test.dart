// Family pages REAL screenshots (Mr. Wrong, 2026-11-24 01:38 IST:
// "Ban kaisa raha hai, pic dikha" + "Jab sab ready ho to mujhe pic
// bana ke dikha diyo"). Renders the real Family pages at 720x1565 with
// real Roboto + MaterialIcons fonts and writes the PNGs to the dir in
// FAMILY_RENDER_DIR (default /home/hatch/workspace):
//   family-detail-page-real.png, family-monthly-ranking-page-real.png,
//   family-weekly-rewards-page-real.png, family-join-page-real.png,
//   family-management-page-real.png
// When FAMILY_RENDER_DIR is not set, the test only verifies the pages
// render (so CI stays green).
// NOTE (same as create_family_screen_render_test.dart): in render mode
// the PNGs are written correctly, but the flutter_tester then stays
// alive until the 10-minute test timeout — the toImage/toByteData
// capture leaves the tester isolate parked. The PNGs on disk are the
// deliverable; do not "fix" the timeout by removing the capture.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/family_detail_screen.dart';
import 'package:darkvibex/screens/family_join_screen.dart';
import 'package:darkvibex/screens/family_monthly_ranking_screen.dart';
import 'package:darkvibex/screens/mine_social_screens.dart';
import 'package:darkvibex/ui/tinni_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _familyId = '10087';

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
      'weekly_gifts': coins,
      'value': value,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
    };

List<Map<String, dynamic>> _demoMembers() {
  final now = DateTime.now().millisecondsSinceEpoch;
  const day = 86400000;
  return <Map<String, dynamic>>[
    _member('user-reo', 'ReO',
        role: 'leader', coins: 8339840000, lastSeenAt: now, value: 1600950000),
    _member('user-sajid', 'Sajid',
        role: 'admin', coins: 1120720000, lastSeenAt: now, value: 578930000),
    _member('user-obito', 'OBiTO',
        role: 'admin', coins: 121720000, lastSeenAt: now - day, value: 0),
    _member('user-nyrox', 'Nyrox',
        role: 'admin', coins: 3321300000, lastSeenAt: now, value: 642010000),
    _member('user-void', 'Void',
        role: 'admin', coins: 1270460000, lastSeenAt: now, value: 704730000),
    _member('user-khan', 'KHAN',
        role: 'admin', coins: 737940000, lastSeenAt: now - day, value: 0),
    _member('user-akriti', 'akriti.',
        coins: 1542600000, lastSeenAt: now, value: 635100000),
    _member('user-selfish', 'SELFISH',
        coins: 783410000, lastSeenAt: now - 2 * day, value: 0),
    _member('user-expensive', 'ExPeNsIvE',
        coins: 4787560000, lastSeenAt: now, value: 1841920000),
    _member('user-calix', 'CALIX',
        coins: 913090000, lastSeenAt: now, value: 0),
  ];
}

Map<String, dynamic> _demoFamily() => <String, dynamic>{
      'id': _familyId,
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

class _RenderBackend extends BackendApi {
  @override
  Future<Map<String, dynamic>?> familyState({
    required String userId,
  }) async =>
      <String, dynamic>{
        'ok': true,
        'family': _demoFamily(),
        'members': _demoMembers(),
        'join_requests': const <Map<String, dynamic>>[],
        'available_families': const <Map<String, dynamic>>[],
      };

  @override
  Future<Map<String, dynamic>?> familyDetail({
    required String familyId,
  }) async =>
      <String, dynamic>{
        'ok': true,
        'family': _demoFamily(),
        'members': _demoMembers(),
        'top_members': <String, dynamic>{
          'charm': _member('user-expensive', 'ExPeNsIvE',
              coins: 4787560000, value: 1841920000),
          'wealth': _member('user-calix', 'CALIX',
              coins: 913090000, value: 913090000),
          'active': _member('user-expensive', 'ExPeNsIvE',
              coins: 4787560000, value: 15610),
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
          'draws_used': 3,
          'draws_left': 9,
          'has_spun': false,
          'spins_left': 1,
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
  Future<Map<String, dynamic>?> familyLuckyWheelSpin({
    required String userId,
    required String familyId,
  }) async =>
      <String, dynamic>{
        'ok': true,
        'coins': 58050,
        'draws_left': 8,
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
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'post-1',
          'display_name': 'ReO',
          'avatar_key': '',
          'text': 'I was born!',
          'like_count': 128,
          'comment_count': 12,
          'liked_by_me': false,
        },
        <String, dynamic>{
          'id': 'post-2',
          'display_name': 'Sajid',
          'avatar_key': '',
          'text': 'New vibe. New chapter. Same family.',
          'like_count': 96,
          'comment_count': 8,
          'liked_by_me': true,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> familyLuckyDrawRecords({
    required String familyId,
    int limit = 100,
  }) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{'display_name': 'NIYA', 'coins': 163200},
        <String, dynamic>{'display_name': 'Ani', 'coins': 1020000},
        <String, dynamic>{'display_name': 'BEAR', 'coins': 408000},
        <String, dynamic>{'display_name': 'Phoenix12', 'coins': 408000},
        <String, dynamic>{'display_name': 'Sajid', 'coins': 163200},
      ];

  @override
  Future<Map<String, dynamic>?> familyMonthlyRanking({
    required String familyId,
    required String kind,
  }) async =>
      <String, dynamic>{
        'ok': true,
        'members': <Map<String, dynamic>>[
          _member('user-expensive', 'ExPeNsIvE',
              coins: 4787560000, value: 1841920000),
          _member('user-reo', 'ReO',
              role: 'leader', coins: 8339840000, value: 1600950000),
          _member('user-rehan', 'REHAN', coins: 784450000, value: 784450000),
          _member('user-void', 'Void',
              role: 'admin', coins: 1270460000, value: 704730000),
          _member('user-nyrox', 'Nyrox',
              role: 'admin', coins: 3321300000, value: 642010000),
          _member('user-akriti', 'akriti.',
              coins: 1542600000, value: 635100000),
          _member('user-sajid', 'Sajid',
              role: 'admin', coins: 1120720000, value: 578930000),
        ],
      };

  @override
  Future<List<Map<String, dynamic>>> familyList({String? country}) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'fam-1',
          'name': 'POWER OF FRIENDS',
          'logo_key': '',
          'member_count': 44,
          'member_limit': 45,
          'notice': 'peace fully my family',
        },
        <String, dynamic>{
          'id': 'fam-2',
          'name': 'DUDE',
          'logo_key': '',
          'member_count': 81,
          'member_limit': 85,
          'notice': '',
        },
        <String, dynamic>{
          'id': 'fam-3',
          'name': 'HUM TUM HUM TUM',
          'logo_key': '',
          'member_count': 65,
          'member_limit': 85,
          'notice': '',
        },
        <String, dynamic>{
          'id': 'fam-4',
          'name': 'Mahadev ki duniya',
          'logo_key': '',
          'member_count': 77,
          'member_limit': 85,
          'notice': '',
        },
        <String, dynamic>{
          'id': 'fam-5',
          'name': 'my love India',
          'logo_key': '',
          'member_count': 85,
          'member_limit': 85,
          'notice': '',
        },
      ];

  @override
  Future<bool> requestFamilyJoin({
    required String userId,
    required String familyId,
  }) async =>
      true;

  @override
  Future<Map<String, dynamic>?> familyCheckIn({
    required String userId,
  }) async =>
      <String, dynamic>{'ok': true};

  @override
  Future<Map<String, dynamic>?> createFamilyTrendPost({
    required String userId,
    required String text,
  }) async =>
      <String, dynamic>{'ok': true};

  @override
  Future<Map<String, dynamic>?> likeFamilyTrendPost({
    required String userId,
    required String postId,
  }) async =>
      <String, dynamic>{'ok': true};
}

/// Loads the real Roboto + MaterialIcons fonts. Returns true when
/// loaded. Resolves the SDK portably via FLUTTER_ROOT (set by the
/// flutter tool for test processes, local + CI); falls back to this
/// machine's SDK path. Returns false when no fonts dir exists — the
/// caller skips the render instead of failing (these are screenshot
/// generators, not regression gates; a missing SDK path must never
/// turn CI red).
Future<bool> _loadRealFonts() async {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null &&
        Platform.environment['FLUTTER_ROOT']!.isNotEmpty)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    '/home/hatch/workspace/flutter-sdk/bin/cache/artifacts/material_fonts',
  ];
  final fontsDir = candidates.firstWhere(
    (dir) => Directory(dir).existsSync(),
    orElse: () => '',
  );
  if (fontsDir.isEmpty) return false;
  Future<ByteData> bytes(String name) async =>
      ByteData.view(File('$fontsDir/$name').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('Roboto-Regular.ttf'))
    ..addFont(bytes('Roboto-Bold.ttf'))
    ..addFont(bytes('Roboto-Medium.ttf'))
    ..addFont(bytes('Roboto-Black.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('MaterialIcons-Regular.otf'));
  await icons.load();
  return true;
}

Future<void> _capture(
  WidgetTester tester,
  String key,
  String outPath,
) async {
  print('RENDER: capturing $key -> $outPath');
  final boundary = tester.renderObject(find.byKey(Key(key)));
  expect(boundary, isA<RenderRepaintBoundary>());
  final image =
      await (boundary as RenderRepaintBoundary).toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
  print('RENDER: written $outPath (${bytes.lengthInBytes} bytes)');
}

void main() {
  // NOTE: one test per page, run by name (`flutter test --plain-name
  // "<name>"`). A toImage capture parks the tester isolate, so a second
  // capture in the same run never completes — each page gets its own
  // run (same as create_family_screen_render_test.dart).
  Future<void> renderOne(
    WidgetTester tester,
    String key,
    String fileName,
    AppState state,
    Widget page,
  ) async {
    tester.view.physicalSize = const Size(720, 1565);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!await _loadRealFonts()) {
      markTestSkipped('Flutter SDK material fonts not found — render skipped');
      return;
    }
    final dir = Platform.environment['FAMILY_RENDER_DIR'];
    await tester.pumpWidget(
      RepaintBoundary(
        key: Key(key),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // The real app theme (dark Tinni) — without it the default
          // (light) theme makes default-coloured text dark-on-dark on
          // the dark TinniPanel cards (management page).
          theme: buildTinniStyleTheme(),
          home: page,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      await precacheImage(
        const AssetImage('assets/images/family_bg_light.png'),
        context,
      );
      // New detail-page models (Mr. Wrong, 2026-11-24): precache so the
      // rendered pic shows the real cover / banner / badge / crystal /
      // wheel instead of blank boxes.
      for (final asset in <String>[
        'assets/images/family_cover_new.webp',
        'assets/images/family_banner_new.webp',
        'assets/images/family_level_badge.webp',
        'assets/images/family_exp_crystal.webp',
        'assets/images/family_lucky_wheel.webp',
      ]) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (dir != null && dir.isNotEmpty) {
      await _capture(tester, key, '$dir/$fileName');
    }
    state.dispose();
  }

  // NEW detail design (Mr. Wrong, 2026-11-24): new filename, so the
  // edited page never shows him a cached old pic (pic-caching lesson).
  // v2: Daily Tasks section added (Task stays, Trends goes).
  testWidgets('family detail page real screenshot 720x1565',
      (tester) async {
    final backend = _RenderBackend();
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 0;
    await renderOne(
      tester,
      'render-detail',
      'family-detail-page-new-v2.png',
      state,
      FamilyDetailScreen(
        state: state,
        familyId: _familyId,
        backend: backend,
      ),
    );
  });

  testWidgets('family monthly ranking page real screenshot 720x1565',
      (tester) async {
    final backend = _RenderBackend();
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 0;
    await renderOne(
      tester,
      'render-monthly',
      'family-monthly-ranking-page-real.png',
      state,
      FamilyMonthlyRankingScreen(
        state: state,
        familyId: _familyId,
        backend: backend,
      ),
    );
  });

  testWidgets('family join page real screenshot 720x1565', (tester) async {
    final backend = _RenderBackend();
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 0;
    await renderOne(
      tester,
      'render-join',
      'family-join-page-real.png',
      state,
      FamilyJoinScreen(
        state: state,
        backend: backend,
      ),
    );
  });

  testWidgets('family management page real screenshot 720x1565',
      (tester) async {
    final backend = _RenderBackend();
    final state = AppState()
      ..userId = 'user-reo'
      ..vipLevel = 0;
    await renderOne(
      tester,
      'render-management',
      'family-management-page-real.png',
      state,
      FamilyScreen(
        state: state,
        backend: backend,
      ),
    );
  });
}
