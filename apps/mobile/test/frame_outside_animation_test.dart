import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted frame art stays static while motif elements animate', () {
    final source =
        File('lib/widgets/vip_animated_frame.dart').readAsStringSync();

    expect(source, contains('const frameScale = 1.86'));
    expect(source, contains('dimension: widget.size'));
    expect(source, contains('animation: _controller'));
    expect(source, contains('_FrameElementPainter'));
    expect(source, contains('_paintButterfly'));
    expect(source, contains('_paintCrownShine'));
    expect(source, contains('_paintHeartPulse'));
    expect(source, contains('_paintWingShimmer'));
    expect(source, contains('_paintPetalGlow'));
    expect(source, contains('frame body never shake or rotate'));
  });
}
