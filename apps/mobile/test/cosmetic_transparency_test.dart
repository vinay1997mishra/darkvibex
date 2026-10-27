import 'dart:convert';
import 'dart:ui' as ui;

import 'package:darkvibex/widgets/bubble_artwork_data.dart';
import 'package:darkvibex/widgets/frame_artwork_data.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _expectTransparentCorners(
  String id,
  String encoded,
) async {
  final codec = await ui.instantiateImageCodec(base64Decode(encoded));
  try {
    final decoded = await codec.getNextFrame();
    final image = decoded.image;
    try {
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(raw, isNotNull, reason: '$id must decode to pixels');

      final pixels = raw!;
      int alphaAt(int x, int y) =>
          pixels.getUint8(((y * image.width + x) * 4) + 3);

      final corners = <(int, int)>[
        (0, 0),
        (image.width - 1, 0),
        (0, image.height - 1),
        (image.width - 1, image.height - 1),
      ];
      for (final point in corners) {
        expect(
          alphaAt(point.$1, point.$2),
          lessThanOrEqualTo(8),
          reason: '$id must have transparent pixels at all four outside corners',
        );
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

void main() {
  test('every embedded bitmap frame has transparent outer corners',
      () async {
    expect(kFrameArtworkBase64, isNotEmpty);
    for (final entry in kFrameArtworkBase64.entries) {
      await _expectTransparentCorners(
        entry.key,
        entry.value,
      );
    }
  });

  test('all eight built-in chat bubbles have transparent outside corners',
      () async {
    expect(kBubbleArtworkBase64.length, 8);
    for (final entry in kBubbleArtworkBase64.entries) {
      await _expectTransparentCorners(entry.key, entry.value);
    }
  });
}
