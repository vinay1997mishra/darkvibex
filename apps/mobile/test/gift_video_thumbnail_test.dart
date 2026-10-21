import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gift videos render as small muted non-looping gift DPs in every gift grid', () {
    final festival = File('lib/screens/gifts_screen.dart').readAsStringSync();
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final preview =
        File('lib/widgets/gift_media_preview.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('video_player:'));
    expect(festival, contains("gift['video_key']"));
    expect(festival, contains('GiftMediaPreview('));
    for (final category in ['Normal', 'CP', 'VS', 'Luxury', 'Backpack', 'Exclusive', 'Custom']) {
      expect(festival, contains("'$category'"), reason: '$category category should be available in the mobile gift grid');
    }
    expect(room, contains("item['video_key']"));
    expect(room, contains('GiftMediaPreview('));
    expect(preview, contains('VideoPlayerController.networkUrl'));
    expect(preview, contains('setLooping(false)'));
    expect(preview, contains('setVolume(0)'));
    expect(preview, contains('controller.play()'));
  });
}
