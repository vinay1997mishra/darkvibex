import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all seven gift categories are available in every mobile gift picker', () {
    final festival = File('lib/screens/gifts_screen.dart').readAsStringSync();
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final preview =
        File('lib/widgets/gift_media_preview.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('video_player:'));
    expect(festival, contains("gift['video_key']"));
    expect(festival, contains('GiftMediaPreview('));
    for (final category in [
      'Normal',
      'Lucky',
      'CP',
      'VS',
      'Country',
      'Luxury',
      'Backpack',
    ]) {
      expect(
        festival,
        contains("'$category'"),
        reason: '$category category should be available in the mobile gift grid',
      );
      expect(
        room,
        contains("'$category'"),
        reason: '$category category should be available in the room gift picker',
      );
    }
    expect(room, contains("item['video_key']"));
    expect(room, contains('GiftMediaPreview('));
    expect(preview, contains('VideoPlayerController.networkUrl'));
    expect(preview, contains('setLooping(false)'));
    expect(preview, contains('setVolume(0)'));
    expect(preview, contains('controller.play()'));
  });
}
