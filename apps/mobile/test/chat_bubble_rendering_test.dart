import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/widgets/cosmetic_store_previews.dart';
import 'package:darkvibex/widgets/transparent_artwork_image.dart';

Future<Uint8List> _transparentBubblePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = Paint()..color = const Color(0xFFFF4FA8);
  // Keep all four corners transparent, like a supported Owner Panel bubble.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 8, 144, 64),
      const Radius.circular(18),
    ),
    paint,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(160, 80);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  testWidgets('custom transparent bubble artwork gets an adaptive nine-slice',
      (tester) async {
    final bytes = await _transparentBubblePng();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: TransparentArtworkImage(
                imageProvider: MemoryImage(bytes),
                autoCenterSlice: true,
                fit: BoxFit.fill,
                fallback: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.centerSlice, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bubble text remains readable and long messages do not overflow',
      (tester) async {
    const message =
        'DarkVibeX User: this is a longer owner-added bubble message with multiple words and emoji ✨💗';
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: StretchableCosmeticBubble(
                styleId: 'bubble-dream',
                child: BubbleChatText(text: message),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.text(message));
    expect(text.style?.color, Colors.white);
    expect(text.style?.shadows, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
