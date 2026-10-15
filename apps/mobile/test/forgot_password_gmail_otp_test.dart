import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forgot password is Gmail OTP only and never asks user for a token', () {
    final reset =
        File('lib/screens/reset_password_screen.dart').readAsStringSync();

    expect(reset, contains("purpose: 'reset'"));
    expect(reset, contains('6-digit OTP'));
    expect(reset, contains('Send OTP'));
    expect(reset, isNot(contains("labelText: 'Token'")));
    expect(reset, isNot(contains("labelText: 'Setup token'")));
    expect(reset, isNot(contains("labelText: 'Reset token'")));
  });
}
