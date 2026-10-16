import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VIP entrance arrival effect lasts exactly two seconds', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(
      source,
      contains('Timer(const Duration(milliseconds: 2000)'),
    );
    expect(
      source,
      isNot(contains('Timer(const Duration(milliseconds: 5000)')),
    );
  });
}
