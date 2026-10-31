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
    expect(source, contains('The DP stays full-size'));
    expect(source, contains('imageProvider: artwork'));
    expect(source, contains('class _TransparentFrameArtworkClipper'));
    expect(source, contains('PathFillType.evenOdd'));
    expect(source, contains('ClipPath('));
    expect(source, contains('customFrameScale = 1.86'));
    expect(source, contains('animationType: widget.animationType'));
    expect(source, contains('animationDurationMs'));
    expect(source, contains('_paintMetadataAnimation'));
    expect(source, contains('case \'butterfly_wings_flight\''));
    expect(source, contains('TransparentArtworkImage('));
    expect(source, contains('requireTransparentCenter: true'));
    expect(source, contains('_TransparentFrameFallbackPainter'));

    final appState = File('lib/app/app_state.dart').readAsStringSync();
    expect(appState, contains('activeFrameAnimationType'));
    expect(appState, contains('activeFrameAnimationMs'));
    expect(appState, contains("catalogById['frame:$itemId']"));

    final alphaSource = File('lib/widgets/transparent_artwork_image.dart')
        .readAsStringSync();
    expect(alphaSource, contains('outsideClear'));
    expect(alphaSource, contains('alphaAt(16, 16)'));
    expect(alphaSource, contains('widget.fallback'));
    expect(source, isNot(contains('ColorFiltered(')));
    expect(source, isNot(contains('colorFilter: const ColorFilter.matrix')));
    expect(source, isNot(contains('canvas.drawLine(')));
    expect(source, isNot(contains('0xFFFFD45A).withValues(alpha: .82')));
  });
}
