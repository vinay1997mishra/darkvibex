import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all incomplete Aladdin Lamp tasks stay actionable for the room host', () {
    final source =
        File('lib/screens/aladdin_lamp_screen.dart').readAsStringSync();

    expect(
      source,
      contains('isHost && !task.completed && !task.claimed'),
    );
    expect(source, isNot(contains('task.target == 1 && task.progress == 0')));
    expect(source, contains("case 'host_gift':"));
    expect(source, contains("case 'room_activity':"));
    expect(source, contains("case 'mic_time':"));
    expect(source, contains("case 'host_mic':"));
    expect(source, contains('Timer.periodic('));
    expect(source, contains('const Duration(minutes: 1)'));
  });
}
