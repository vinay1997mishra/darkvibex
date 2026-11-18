import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom vehicle entry stays visible long enough for remote media', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains('final durationMs = (requestedMs > 0'));
    expect(source, contains('requestedMs.clamp(2000, 10000).toInt()'));
    expect(source, contains('(hasCustomMedia ? 6000 : (hasBuiltInVehicle ? 4800 : 2000))'));
    expect(source, contains('(hasCustomMedia ? 5000 : 0)'));
    expect(source, contains('Timer(Duration(milliseconds: durationMs)'));
  });

  test('arrival overlay uses the animal layout: 40% bottom for VIP5-15, full-screen for VIP16-18', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final playback =
        File('lib/widgets/custom_asset_effect_playback.dart').readAsStringSync();

    // The overlay rect comes from entryRectForVipLevel() (VIP5-15 bottom
    // 40%, VIP16-18 full-screen) — not a fixed 45% height for every level.
    expect(room, contains('entryRectForVipLevel('));
    expect(room, isNot(contains('height: MediaQuery.sizeOf(context).height * .45')));
    // The animal video plays direct from R2, never through /api/files.
    expect(room, contains('directVideoUrl:'));
    expect(room, contains('_directAnimalVideoUrlForMember('));
    expect(room, contains("'active_vehicle_video_key'"));
    final v2 = File('lib/widgets/vehicle_entry_effect_v2.dart').readAsStringSync();
    expect(v2, contains('bottomEntryHeightFraction = 0.40'));
    expect(v2, contains('isFullscreenVipLevel'));
    expect(playback, contains('directVideoUrl'));
    expect(playback, contains('prefetchDirectVideoUrl'));
    expect(playback, contains('fit: BoxFit.cover'));
  });
}
