import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Aladdin lamp banner shows the 3D gold-purple R2 image, painter is fallback only',
      () {
    final source =
        File('lib/screens/aladdin_lamp_screen.dart').readAsStringSync();

    // The banner loads the Vinay-approved realistic 3D lamp from R2
    // through the app's standard fileUrl path (Worker /api/files route).
    expect(
      source,
      contains("'aladdin-lamp/lamp-3d-gold-purple.png'"),
    );
    expect(source, contains('Image.network('));
    expect(source, contains('fileUrl('));
    // Contain, not cover: the image is a transparent lamp, so it must
    // never be cropped — the container's own purple gradient shows
    // through the transparency around it.
    expect(source, contains('BoxFit.contain'));
    expect(source, isNot(contains('BoxFit.cover')));

    // The banner's primary child is the image (clipped to the banner's
    // rounded corners), not the painted lamp.
    expect(source, contains('child: ClipRRect('));
    expect(source, isNot(contains('child: const CustomPaint(')));

    // The painted lamp stays only as the offline/error fallback, so a
    // failed image load still shows a lamp instead of an empty banner.
    expect(source, contains('errorBuilder'));
    expect(source, contains('painter: _MagicLampPainter()'));
    expect(
      source,
      contains('class _MagicLampPainter extends CustomPainter'),
    );
  });
}
