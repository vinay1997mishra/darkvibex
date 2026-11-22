import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'top-of-room banner: one 2-line banner for every event, not scrolling',
    () {
      final roomSource = File(
        'lib/screens/room_screen.dart',
      ).readAsStringSync();
      final widgetSource = File(
        'lib/widgets/top_room_banner.dart',
      ).readAsStringSync();
      final homeSource = File(
        'lib/screens/home_shell.dart',
      ).readAsStringSync();

      // Every rocket level has its own banner design (Vinay,
      // 2026-11-22: "Rocket wale me har rocket ka alag banner hota
      // hai") — the gradient comes from the level, and the level
      // rides the banner queue item from both the in-room launch
      // and the cross-room feed.
      expect(widgetSource, contains('rocketGradientForLevel'));
      expect(widgetSource, contains('rocketLevel'));
      expect(roomSource, contains('rocketLevel: level'));
      expect(roomSource, contains("item['rocket_level']"));

      // Rocket banner shows the BUILT rocket (Vinay, 2026-11-22
      // 13:30 IST: "Inke Rocket bhi bani hui dikhni chahiye") — the
      // rocket medal for that level, not just a small icon.
      expect(widgetSource, contains('LevelMedal('));
      expect(widgetSource, contains('MedalSeries.rocket'));
      expect(widgetSource, contains('maxLines: 2'));
      expect(widgetSource, contains('enum TopBannerKind'));
      expect(widgetSource, contains('TopBannerKind.lucky'));
      expect(widgetSource, contains('TopBannerKind.game'));
      expect(widgetSource, contains('TopBannerKind.rocket'));
      expect(widgetSource, contains('kindGradients'));
      expect(widgetSource, contains("'WIN'"));
      expect(widgetSource, contains("key: const Key('top-room-banner')"));
      expect(widgetSource, contains('Icons.chevron_right_rounded'));

      // Ribbon-style banner (Vinay, 2026-11-22: "Thoda rebbon benner
      // hai to isme design bhi add kar ek dum simple mat rakh") —
      // ornate gold border, glossy highlight, ribbon fold + sparkle.
      expect(widgetSource, contains('Color(0xFFFFD700), width: 2'));
      expect(widgetSource, contains('Icons.bookmark_rounded'));
      expect(widgetSource, contains('Icons.auto_awesome_rounded'));
      expect(widgetSource, contains('BoxShadow'));

      // The room keeps a queue and rotates one message at a time.
      expect(roomSource, contains('_topBannerQueue'));
      expect(roomSource, contains('_enqueueTopBanner'));
      expect(roomSource, contains('_showNextTopBanner'));
      expect(
        roomSource,
        contains('Timer(const Duration(seconds: 4)'),
      );
      // The banner hides when the queue is empty.
      expect(roomSource, contains('_currentTopBanner = null'));

      // Slide animation (Oyaar video): the banner slides in from
      // the right and out to the left.
      expect(roomSource, contains('AnimatedSwitcher'));
      expect(roomSource, contains('SlideTransition'));

      // The banner sits below the header row, gated by the Game
      // Banner toggle (top-of-room banner) and the master switch.
      expect(roomSource, contains('TopRoomBanner('));
      expect(roomSource, contains('gameBannerEnabled &&'));
      expect(roomSource, contains("_currentTopBanner != null"));

      // Every event joins the queue: gift sends (Lucky Bag too),
      // Lucky wins, Rocket launches, VIP entries.
      expect(roomSource, contains("'🎁 \$senderName sent"));
      expect(roomSource, contains("'🎉 \$senderName won"));
      expect(roomSource, contains("'🚀 Rocket Lv.\$level launched"));
      expect(roomSource, contains("'👑 \$entryName (VIP\$entryVipLevel)"));

      // The Lucky win banner names who received the gift and the
      // room ID (Vinay, 2026-11-22 13:38 IST).
      expect(roomSource, contains('for \$receiverName in \${widget.room.name}'));
      expect(roomSource, contains('(Room ID: \${widget.room.id})'));

      // The VIP entry banner is the entry effect banner (Vinay,
      // 2026-11-22 13:43 IST: "Entry effect wala banner hi to hai")
      // — it shows the entering user's name AND their DP.
      expect(widgetSource, contains('avatarUrl'));
      expect(widgetSource, contains('CircleAvatar('));
      expect(roomSource, contains("member['avatar_key']"));
      expect(roomSource, contains('avatarUrl: entryAvatarKey.isEmpty'));
      expect(
        roomSource,
        isNot(contains('gameBannerEnabled &&\n              (carEffectsEnabled')),
      );
      // Game Banner subtitle names the 2-line top banner's events.
      expect(
        roomSource,
        contains(
          "'2-line banner at the top of the room (gift, Lucky win, Rocket, VIP entry).'",
        ),
      );

      // Cross-room feed: the room polls /api/banners/global with
      // its 3s state poll and enqueues other rooms' items with their
      // room id; its own room's items are skipped (they already
      // arrive via the room's own event paths).
      expect(roomSource, contains('_applyGlobalBanners'));
      expect(roomSource, contains('globalBanners()'));
      expect(roomSource, contains("if (roomId == widget.room.id) continue;"));

      // Tap-to-enter (Oyaar video): tapping a cross-room banner
      // asks "Enter this room?" (Cancel / Confirm) and only Confirm
      // leaves this room and pops with the target room id; the home
      // shell opens it. Game wins name no room, so they are not
      // tappable (room_id empty).
      expect(roomSource, contains('_onTopBannerTap'));
      expect(roomSource, contains("'Enter this room?'"));
      expect(roomSource, contains('Navigator.of(context).pop(roomId)'));
      expect(homeSource, contains('if (result is String && result.isNotEmpty'));
      expect(homeSource, contains('_openRoom(targets.first)'));
      expect(roomSource, contains("final isGameWin = kind == 'game';"));

      // The banner timer is cancelled on dispose.
      expect(roomSource, contains('_topBannerTimer?.cancel()'));
    },
  );
}
