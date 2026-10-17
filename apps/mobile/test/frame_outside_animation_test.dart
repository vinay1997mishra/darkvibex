import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frame DP stays full-size while only ornament layers animate', () {
    final source =
        File('lib/widgets/vip_animated_frame.dart').readAsStringSync();

    expect(source, contains('const frameScale = 1.86'));
    expect(source, contains('dimension: widget.size'));
    expect(source, contains('animation: _controller'));
    expect(source, contains('_FrameElementPainter'));
    expect(source, contains('_ButterflyFlightPainter'));
    expect(source, contains('_paintButterfly'));
    expect(source, contains('_paintCrownShine'));
    expect(source, contains('_paintHeartPulse'));
    expect(source, contains('_paintWingShimmer'));
    expect(source, contains('_paintRoseBloom'));
    expect(source, contains('_paintStarPulse'));
    expect(source, contains('_paintFlowerOrbit'));
    expect(source, contains('_paintNatureGlow'));
    expect(source, contains('photo does not look'));
    expect(source, isNot(contains('canvas.drawLine(')));
    expect(source, isNot(contains('0xFFFFD45A).withValues(alpha: .82')));
  });
}
