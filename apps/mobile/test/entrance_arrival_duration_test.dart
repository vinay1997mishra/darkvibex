import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VIP entrance effect uses bounded duration with custom media support', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('final durationMs = requestedMs > 0'));
    expect(source, contains('requestedMs.clamp(2000, 10000).toInt()'));
    expect(source, contains('Timer(Duration(milliseconds: durationMs)'));
    expect(source, contains('(hasCustomMedia ? 6000 : 2000)'));
  });
}
