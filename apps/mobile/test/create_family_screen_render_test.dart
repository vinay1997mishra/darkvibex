// Create Family page REAL screenshot (Mr. Wrong, 2026-11-24 01:38 IST:
// "Ban kaisa raha hai, pic dikha"). Renders the real page at 720x1565
// with real Roboto + MaterialIcons fonts and writes the PNG to the path
// in FAMILY_RENDER_OUT (e.g. ~/workspace/create-family-page-real.png).
// When FAMILY_RENDER_OUT is not set, the test only verifies the page
// renders (so CI stays green).
// NOTE (2026-11-24): in render mode the PNG is written correctly, but the
// flutter_tester then stays alive until the 10-minute test timeout — the
// toImage/toByteData capture leaves the tester isolate parked (verified:
// CI mode passes in ~10s, render mode writes the PNG then times out;
// image.dispose() does not release it; async writeAsBytes hangs the same
// way, so the sync write is used). The PNG on disk is the deliverable;
// do not "fix" the timeout by removing the capture.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/create_family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _RenderBackend extends BackendApi {
  @override
  Future<Map<String, dynamic>?> socialStats({
    required String userId,
  }) async {
    return <String, dynamic>{
      'wealth': <String, dynamic>{'level': 0},
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
    return <String, dynamic>{'ok': true, 'family_id': 'family-new'};
  }
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
    ..addFont(bytes('Roboto-Medium.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('MaterialIcons-Regular.otf'));
  await icons.load();
  return true;
}

void main() {
  testWidgets('create family page real screenshot 720x1565', (tester) async {
    tester.view.physicalSize = const Size(720, 1565);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!await _loadRealFonts()) {
      markTestSkipped('Flutter SDK material fonts not found — render skipped');
      return;
    }
    final state = AppState()
      ..userId = 'user-1'
      ..vipLevel = 0;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CreateFamilyScreen(state: state, backend: _RenderBackend()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    // The v9 background is an asset image: make sure it is decoded and
    // painted before capturing, otherwise the render comes out black.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(CreateFamilyScreen));
      await precacheImage(
        const AssetImage('assets/images/family_bg_light.png'),
        context,
      );
    });
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('create'), findsWidgets);
    expect(find.textContaining('90000000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final outPath = Platform.environment['FAMILY_RENDER_OUT'];
    if (outPath != null && outPath.isNotEmpty) {
      print('RENDER: looking up boundary');
      final boundary =
          tester.renderObject(find.byKey(const Key('preview')));
      expect(boundary, isA<RenderRepaintBoundary>());
      print('RENDER: calling toImage');
      final image =
          await (boundary as RenderRepaintBoundary).toImage(pixelRatio: 1);
      print('RENDER: image ${image.width}x${image.height}, toByteData');
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      print('RENDER: bytes ${bytes?.lengthInBytes}, writing $outPath');
      File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
      // Release the rasterized image, otherwise the tester isolate stays
      // alive holding the texture and the run times out at 10 minutes.
      image.dispose();
      print('RENDER: written');
    }
  });
}
