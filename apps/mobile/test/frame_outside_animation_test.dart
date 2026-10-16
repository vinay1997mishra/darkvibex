import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted frame art stays outside a full-size DP and animates', () {
    final source =
        File('lib/widgets/vip_animated_frame.dart').readAsStringSync();

    expect(source, contains('const frameScale = 1.86'));
    expect(source, contains('dimension: widget.size'));
    expect(source, contains('animation: _controller'));
    expect(source, contains('final pulse ='));
    expect(source, contains('final isButterfly ='));
    expect(source, contains('Transform.scale('));
    expect(source, contains('Transform.rotate('));
  });
}
