// Create Family page (Mr. Wrong, 2026-11-24 — approved pic): the full
// create page on the v9 light glass background, cost 90,000,000 coins,
// free for Wealth Level >= 30 or VIP Level >= 6, approval setting,
// live preview. Plus the FamilyScreen rename dialog (name/tag once a
// month, leader only).
import 'dart:typed_data';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/create_family_screen.dart';
import 'package:darkvibex/screens/top_families_screen.dart';
import 'package:darkvibex/screens/mine_social_screens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

// A 1x1 transparent PNG, enough for the logo picker to read as an image.
const _tinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// Gallery picker that always returns the tiny PNG, so the logo flow
/// (pick -> upload -> logo key) can be exercised in a widget test.
/// NOTE: XFile.fromData ignores `name` — the name comes from `path`,
/// so pass path 'logo.png' (no file I/O needed, bytes stay in memory).
class _FakeImagePickerPlatform extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      XFile.fromData(
        Uint8List.fromList(_tinyPng),
        path: 'logo.png',
        mimeType: 'image/png',
      );
}

class _FakeCreateBackend extends BackendApi {
  _FakeCreateBackend({
    this.wealthLevel = 0,
    this.familyForState,
  });

  final int wealthLevel;
  final Map<String, dynamic>? familyForState;

  final List<Map<String, dynamic>> createCalls = [];
  final List<Map<String, dynamic>> updateCalls = [];

  @override
  Future<Map<String, dynamic>?> socialStats({
    required String userId,
  }) async {
    return <String, dynamic>{
      'wealth': <String, dynamic>{'level': wealthLevel},
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
    createCalls.add(<String, dynamic>{
      'user_id': userId,
      'name': name,
      'tag': tag,
      'approval_required': approvalRequired,
      'logo_key': logoKey,
    });
    return <String, dynamic>{'ok': true, 'family_id': 'family-new'};
  }

  @override
  Future<String?> uploadImage({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async =>
      'family-logos/test-logo.png';

  @override
  Future<Map<String, dynamic>?> updateFamilyNameTag({
    required String userId,
    String? name,
    String? tag,
  }) async {
    updateCalls.add(<String, dynamic>{
      'user_id': userId,
      'name': name,
      'tag': tag,
    });
    return <String, dynamic>{
      'ok': true,
      'name': name ?? 'TIGER FAMILY',
      'tag': tag ?? 'TIGER',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> familyList({String? country}) async =>
      const <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> familyState({
    required String userId,
  }) async {
    final family = familyForState;
    if (family == null) {
      return <String, dynamic>{
        'family': null,
        'members': const [],
        'join_requests': const [],
        'available_families': const [],
      };
    }
    return <String, dynamic>{
      'family': family,
      'members': const [],
      'join_requests': const [],
      'available_families': const [],
    };
  }
}

Future<void> _pumpCreatePage(
  WidgetTester tester,
  AppState state,
  _FakeCreateBackend backend,
) async {
  // Phone-sized viewport (720x1565, like the approved pic) so the whole
  // page — including the create button — is on screen and tappable.
  tester.view.physicalSize = const Size(720, 1565);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: CreateFamilyScreen(state: state, backend: backend)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Picks the gallery logo (fake picker + fake upload) so the page holds
/// a logo key — logo is mandatory for creation (Mr. Wrong, 2026-11-24).
Future<void> _pickLogo(WidgetTester tester) async {
  final original = ImagePickerPlatform.instance;
  ImagePickerPlatform.instance = _FakeImagePickerPlatform();
  addTearDown(() {
    ImagePickerPlatform.instance = original;
  });
  await tester.tap(find.byKey(const Key('create-family-logo')));
  // The pick -> read -> upload chain is async; settle so the logo key
  // is set (and the create button enabled) before the test continues.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create family page shows every field from the approved pic',
      (tester) async {
    final backend = _FakeCreateBackend();
    final state = AppState()..userId = 'user-1';
    await _pumpCreatePage(tester, state, backend);
    expect(find.text('create'), findsWidgets);
    expect(find.text('Upload family logo'), findsOneWidget);
    expect(find.byKey(const Key('create-family-logo')), findsOneWidget);
    expect(find.byKey(const Key('create-family-name')), findsOneWidget);
    expect(find.text('0/20'), findsOneWidget);
    expect(
      find.text(
        '*Family names can only be changed once a month, please consider carefully',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('create-family-tag')), findsOneWidget);
    expect(find.text('0/10'), findsOneWidget);
    expect(
      find.text(
        '*It can only be revised once a month, please consider carefully',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('create-family-preview')), findsOneWidget);
    expect(find.text('Family name'), findsWidgets);
    expect(find.text('Family tag'), findsWidgets);
    expect(find.text('Application settings'), findsOneWidget);
    expect(
      find.text('Approval required to join the family'),
      findsOneWidget,
    );
    expect(
      find.text('No approval required, join the family directly'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('create-family-submit')), findsOneWidget);
    // Approved pic: the button shows 90000000 (no commas).
    expect(find.byKey(const Key('create-family-cost')), findsOneWidget);
    expect(find.text('90000000'), findsOneWidget);
    expect(
      find.text(
        'Free creation is available for users with Wealth Level ≥ 30 or VIP Level ≥ 6',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('if you do not log in for 15 days'),
      findsOneWidget,
    );
  });

  testWidgets('live preview follows the typed name and tag', (tester) async {
    final backend = _FakeCreateBackend();
    final state = AppState()..userId = 'user-1';
    await _pumpCreatePage(tester, state, backend);
    await tester.enterText(
      find.byKey(const Key('create-family-name')),
      'Tiger Family',
    );
    await tester.enterText(
      find.byKey(const Key('create-family-tag')),
      'tiger',
    );
    await tester.pump();
    expect(find.text('12/20'), findsOneWidget);
    expect(find.text('5/10'), findsOneWidget);
    // The preview shows the typed name and the uppercased tag.
    final preview = find.byKey(const Key('create-family-preview'));
    expect(
      find.descendant(of: preview, matching: find.text('Tiger Family')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: preview, matching: find.text('TIGER')),
      findsOneWidget,
    );
  });

  testWidgets('create button shows Free for VIP Level 6', (tester) async {
    final backend = _FakeCreateBackend();
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 6;
    await _pumpCreatePage(tester, state, backend);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('90000000'), findsNothing);
  });

  testWidgets('create button shows Free for Wealth Level 30',
      (tester) async {
    final backend = _FakeCreateBackend(wealthLevel: 30);
    final state = AppState()..userId = 'user-1';
    await _pumpCreatePage(tester, state, backend);
    expect(find.text('Free'), findsOneWidget);
  });

  testWidgets('no-approval radio reaches the create call', (tester) async {
    final backend = _FakeCreateBackend();
    // Enough coins to create (90,000,000); otherwise the button
    // stays disabled (Mr. Wrong, 2026-11-24).
    final state = AppState()
      ..userId = 'user-1'
      ..coins = 100000000;
    await _pumpCreatePage(tester, state, backend);
    await _pickLogo(tester);
    await tester.enterText(
      find.byKey(const Key('create-family-name')),
      'Tiger Family',
    );
    await tester.enterText(
      find.byKey(const Key('create-family-tag')),
      'TIGER',
    );
    await tester.tap(find.byKey(const Key('create-family-no-approval')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-family-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.createCalls.length, 1);
    expect(backend.createCalls.single['approval_required'], false);
    expect(backend.createCalls.single['name'], 'Tiger Family');
    expect(backend.createCalls.single['tag'], 'TIGER');
    expect(
      backend.createCalls.single['logo_key'],
      'family-logos/test-logo.png',
    );
  });

  testWidgets('short name or tag keeps the create button disabled',
      (tester) async {
    final backend = _FakeCreateBackend();
    final state = AppState()..userId = 'user-1';
    await _pumpCreatePage(tester, state, backend);
    // Logo + name/tag first, then the application setting (the
    // natural top-to-bottom order), so only the short name/tag
    // keeps the button disabled (button is disabled until every
    // detail is filled).
    await _pickLogo(tester);
    await tester.enterText(
      find.byKey(const Key('create-family-name')),
      'T',
    );
    await tester.enterText(
      find.byKey(const Key('create-family-tag')),
      'T',
    );
    await tester.tap(find.byKey(const Key('create-family-approval-required')));
    await tester.pump();
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('create-family-submit')),
    );
    expect(submit.onPressed, isNull);
    await tester.tap(find.byKey(const Key('create-family-submit')));
    await tester.pump();
    expect(backend.createCalls, isEmpty);
  });

  testWidgets('create button is disabled without a logo', (tester) async {
    final backend = _FakeCreateBackend();
    // Enough coins, so only the missing logo keeps the button disabled.
    final state = AppState()
      ..userId = 'user-1'
      ..coins = 100000000;
    await _pumpCreatePage(tester, state, backend);
    await tester.enterText(
      find.byKey(const Key('create-family-name')),
      'Tiger Family',
    );
    await tester.enterText(
      find.byKey(const Key('create-family-tag')),
      'TIGER',
    );
    // Without a logo the create button does not work at all
    // (Mr. Wrong, 2026-11-24: "Click hi nhi hoga").
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('create-family-submit')),
    );
    expect(submit.onPressed, isNull);
    await tester.tap(find.byKey(const Key('create-family-submit')));
    await tester.pump();
    expect(backend.createCalls, isEmpty);
  });

  testWidgets('create button is disabled until an application setting is chosen',
      (tester) async {
    final backend = _FakeCreateBackend();
    // Enough coins, so only the missing application setting keeps
    // the button disabled.
    final state = AppState()
      ..userId = 'user-1'
      ..coins = 100000000;
    await _pumpCreatePage(tester, state, backend);
    await _pickLogo(tester);
    await tester.enterText(
      find.byKey(const Key('create-family-name')),
      'Tiger Family',
    );
    await tester.enterText(
      find.byKey(const Key('create-family-tag')),
      'TIGER',
    );
    // Name + tag + logo are filled, but no application setting is
    // chosen yet — the button must not work (Mr. Wrong, 2026-11-24:
    // "Bina choose kiye na chale").
    final disabled = tester.widget<FilledButton>(
      find.byKey(const Key('create-family-submit')),
    );
    expect(disabled.onPressed, isNull);
    await tester.tap(find.byKey(const Key('create-family-submit')));
    await tester.pump();
    expect(backend.createCalls, isEmpty);
    // Choosing a setting enables the button.
    await tester.tap(find.byKey(const Key('create-family-no-approval')));
    await tester.pump();
    final enabled = tester.widget<FilledButton>(
      find.byKey(const Key('create-family-submit')),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('insufficient coins keeps the create button disabled',
      (tester) async {
    final backend = _FakeCreateBackend();
    // Only 1,000 coins — far below the 90,000,000 cost — so the
    // family must not be created at all (Mr. Wrong, 2026-11-24:
    // "Insufficient coins me create nhin honi chahiye").
    final state = AppState()
      ..userId = 'user-1'
      ..coins = 1000;
    await _pumpCreatePage(tester, state, backend);
    await _pickLogo(tester);
    await tester.enterText(
      find.byKey(const Key('create-family-name')),
      'Tiger Family',
    );
    await tester.enterText(
      find.byKey(const Key('create-family-tag')),
      'TIGER',
    );
    await tester.tap(find.byKey(const Key('create-family-approval-required')));
    await tester.pump();
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('create-family-submit')),
    );
    expect(submit.onPressed, isNull);
    await tester.tap(find.byKey(const Key('create-family-submit')));
    await tester.pump();
    expect(backend.createCalls, isEmpty);
  });

  testWidgets('top families create button opens the create page',
      (tester) async {
    final state = AppState()..userId = 'user-1';
    final backend = _FakeCreateBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: TopFamiliesScreen(state: state, backend: backend),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('top-family-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CreateFamilyScreen), findsOneWidget);
    expect(find.byKey(const Key('create-family-submit')), findsOneWidget);
  });

  testWidgets('leader rename dialog sends only the changed fields',
      (tester) async {
    final backend = _FakeCreateBackend(
      familyForState: <String, dynamic>{
        'id': 'family-1',
        'name': 'TIGER FAMILY',
        'tag': 'TIGER',
        'level': 7,
        'notice': 'Welcome',
        'my_role': 'leader',
        'name_changed_at': 0,
        'tag_changed_at': 0,
      },
    );
    final state = AppState()..userId = 'user-1';
    await tester.pumpWidget(
      MaterialApp(home: FamilyScreen(state: state, backend: backend)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('family-rename-open')), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-rename-open')));
    await tester.pumpAndSettle();
    expect(find.text('Edit name & tag'), findsWidgets);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'NEW NAME');
    await tester.tap(find.byKey(const Key('family-rename-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(backend.updateCalls.length, 1);
    // The tag did not change, so only the name is sent.
    expect(backend.updateCalls.single['name'], 'NEW NAME');
    expect(backend.updateCalls.single['tag'], isNull);
  });
}
