import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global galaxy background is registered and applied at app root', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final theme = File('lib/ui/tinni_style.dart').readAsStringSync();
    final app = File('lib/app/darkvibex_app.dart').readAsStringSync();

    expect(
      pubspec,
      contains('assets/images/darkvibex_global_bg.webp'),
    );
    expect(theme, contains('class DarkVibeXGlobalBackground'));
    expect(theme, contains("AssetImage(assetPath)"));
    expect(theme, contains('scaffoldBackgroundColor: Colors.transparent'));
    expect(app, contains('DarkVibeXGlobalBackground('));
  });

  test('major routed pages no longer use an opaque black scaffold', () {
    const pages = <String>[
      'lib/screens/home_shell.dart',
      'lib/screens/messages_screen.dart',
      'lib/screens/app_settings_screen.dart',
      'lib/screens/cosmetics_shop_screen.dart',
      'lib/screens/game_room_screen.dart',
      'lib/screens/login_screen.dart',
      'lib/screens/ranking_screen.dart',
      'lib/screens/recharge_screen.dart',
      'lib/screens/sharing_screen.dart',
      'lib/screens/wallet_screen.dart',
    ];

    for (final path in pages) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('backgroundColor: TinniPalette.black,')),
        reason: '$path should reveal the global DarkVibeX background',
      );
    }
  });
}
