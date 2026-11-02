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

  test('custom vehicle video is rendered in the lower half without cropping', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(source, contains('bottom: 0,'));
    expect(source, contains('height: MediaQuery.sizeOf(context).height * .50'));
    expect(source, contains("'active_vehicle_video_key'"));
    expect(source, contains('fit: BoxFit.contain'));
  });
}
