import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room sharing never exposes backend or personal infrastructure', () {
    final lamp = File('lib/screens/aladdin_lamp_screen.dart').readAsStringSync();

    expect(lamp, isNot(contains('BackendApi.origin')));
    expect(lamp, isNot(contains('workers.dev')));
    expect(lamp, isNot(contains('mishrajii')));
    expect(lamp, isNot(contains('darkvibex.app')));
    expect(lamp, contains('Room ID'));
  });

  test('user-facing Google errors do not reveal package or signing details', () {
    final state = File('lib/app/app_state.dart').readAsStringSync();

    expect(state, isNot(contains('release SHA-1')));
    expect(state, isNot(contains('15:43:D7:77')));
    expect(
      state,
      contains('Google Login is temporarily unavailable'),
    );
  });
}
