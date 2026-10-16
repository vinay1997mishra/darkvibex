import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keyboard typing mode keeps only composer and send action visible', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        'final typingMode = MediaQuery.viewInsetsOf(context).bottom > 0;',
      ),
    );
    expect(source, contains("key: const Key('room-chat-composer')"));
    expect(source, contains("key: const Key('room-chat-send-button')"));
    expect(source, contains('if (!typingMode) ...<Widget>['));
    expect(
      source,
      contains(
        'if (!typingMode && rocketDrawNoticeEnabled && effectsEnabled)',
      ),
    );
  });
}
