import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'per-effect toggles: every animation has its own off switch, per user',
    () {
      final roomSource = File(
        'lib/screens/room_screen.dart',
      ).readAsStringSync();
      final fruitSource = File(
        'lib/screens/fruit_party_screen.dart',
      ).readAsStringSync();

      // Gift Banner toggle exists in the Effects sheet.
      expect(roomSource, contains("title: const Text('Gift Banner')"));
      expect(
        roomSource,
        contains("'dvx.room.effects.gift_banner'"),
      );
      expect(roomSource, contains('bool giftBannerEnabled = true;'));

      // Game Banner toggle exists in the Effects sheet.
      expect(roomSource, contains("title: const Text('Game Banner')"));
      expect(
        roomSource,
        contains("'dvx.room.effects.game_banner'"),
      );
      expect(roomSource, contains('bool gameBannerEnabled = true;'));

      // Vehicle Effect and Rocket Banner are the user-facing labels.
      expect(roomSource, contains("title: const Text('Vehicle Effect')"));
      expect(roomSource, contains("title: const Text('Rocket Banner')"));
      expect(roomSource, isNot(contains("title: const Text('Car Effects')")));
      expect(
        roomSource,
        isNot(contains("title: const Text('Rocket Draw Notice')")),
      );

      // Gift Banner gates the gift ribbon (not Gift Effects any more).
      expect(
        roomSource,
        contains(
          'if (!mounted || !effectsEnabled || !giftBannerEnabled) return;\n'
          '    final int vipLevel = giftRibbonVipLevelFromEvent(event);',
        ),
      );
      expect(
        roomSource,
        contains(
          'if (activeGiftRibbon != null && effectsEnabled && giftBannerEnabled)',
        ),
      );

      // Gift Banner gates the Lucky win announcement.
      expect(
        roomSource,
        contains(
          'if (!mounted || !effectsEnabled || !giftBannerEnabled) return;\n'
          '    final winCoins =',
        ),
      );

      // Video/GLB gifts respect the Gift Effects toggle.
      expect(
        roomSource,
        contains(
          'if (!mounted || !effectsEnabled || !giftEffectsEnabled) return;\n'
          '    if (glbKey.trim().isEmpty) return;',
        ),
      );
      expect(
        roomSource,
        contains(
          'if (!mounted || !effectsEnabled || !giftEffectsEnabled) return;\n'
          '    gift_video.VideoPlayerController? controller;',
        ),
      );

      // Rocket Banner gates only the rocket launch overlay.
      expect(
        roomSource,
        contains(
          'if (!mounted || !effectsEnabled || !rocketBannerEnabled) return;',
        ),
      );

      // Rocket/Game Center buttons are navigation, not a banner: they
      // stay visible when Rocket Banner is off (master switch only).
      expect(roomSource, contains('if (!typingMode && effectsEnabled)'));
      expect(
        roomSource,
        isNot(
          contains(
            'if (!typingMode && rocketDrawNoticeEnabled && effectsEnabled)',
          ),
        ),
      );

      // Game Banner gates the Fruit Party round-end result popup.
      expect(fruitSource, contains('bool _gameBannerEnabled = true;'));
      expect(
        fruitSource,
        contains("'dvx.room.effects.game_banner'"),
      );
      expect(
        fruitSource,
        contains(
          'if (!_gameBannerEnabled) return const SizedBox.shrink();',
        ),
      );
    },
  );
}
