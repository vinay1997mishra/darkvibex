import 'dart:io';
import 'dart:ui' as ui;

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/screens/home_shell.dart';
import 'package:darkvibex/ui/tinni_style.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Real screenshot of the new Discover page (Mr. Wrong, 2026-11-24:
// main page, everything like the other app). Run by name:
//   FAMILY_RENDER_DIR=/home/hatch/workspace flutter test
//     test/discover_page_render_test.dart --plain-name "discover page real screenshot 720x1565"
// One capture per run (a toImage capture parks the tester isolate).

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
  final boundary = tester.renderObject(find.byKey(Key(key)));
  expect(boundary, isA<RenderRepaintBoundary>());
  final image =
      await (boundary as RenderRepaintBoundary).toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('discover page real screenshot 720x1565', (tester) async {
    tester.view.physicalSize = const Size(720, 1565);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!await _loadRealFonts()) {
      markTestSkipped('Flutter SDK material fonts not found — render skipped');
      return;
    }
    final state = AppState()
      ..userId = '12345678'
      ..backendConnected = false;
    const rooms = [
      ('room-1', 'Midnight Melody', 120),
      ('room-2', 'Golden Voice Party', 96),
      ('room-3', 'Starlight Chat', 64),
      ('room-4', 'Desi Beats Room', 48),
      ('room-5', 'Chai Pe Charcha', 31),
      ('room-6', 'Quiet Corner', 4),
    ];
    for (final (id, name, online) in rooms) {
      state.rooms.add(
        RoomSummary(
          id: id,
          displayId: id,
          name: name,
          ownerName: 'Owner of $name',
          ownerUserId: 'owner-$id',
          online: online,
        ),
      );
    }
    final dir = Platform.environment['FAMILY_RENDER_DIR'];
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('render-discover'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTinniStyleTheme(),
          home: HomeShell(state: state),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    // Precache the light glass background so the pic shows it, not a
    // blank box (Mr. Wrong, 2026-11-24: purple+gold glass background).
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold).first);
      await precacheImage(
        const AssetImage('assets/images/family_bg_light.png'),
        context,
      );
    });
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (dir != null && dir.isNotEmpty) {
      await _capture(tester, 'render-discover', '$dir/discover-page-new.png');
    }
    state.dispose();
  });
}
