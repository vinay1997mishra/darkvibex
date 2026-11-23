import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Aladdin lamp banner shows the 3D gold-purple R2 image, gold lamp on error — no paint anywhere (Vinay, 2026-11-23)',
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

    // The painted lamp is gone permanently (Vinay, 2026-11-23: "paint
    // wale ko permanent remove kar de") — a failed image load shows the
    // bundled gold lamp, never a painting.
    expect(source, contains('errorBuilder'));
    expect(source, contains('Image.asset('));
    expect(source, contains("'assets/images/gold_lamp.png'"));
    expect(source, isNot(contains('_MagicLampPainter')));
    expect(source, isNot(contains('CustomPaint(')));
  });
}
