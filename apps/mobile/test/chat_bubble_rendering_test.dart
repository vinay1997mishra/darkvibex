import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/widgets/cosmetic_store_previews.dart';
import 'package:darkvibex/widgets/transparent_artwork_image.dart';

void main() {
  test('custom transparent bubble artwork gets an adaptive nine-slice', () {
    final slice = adaptiveArtworkCenterSlice(160, 80);
    expect(slice, isNotNull);
    expect(slice!.left, closeTo(54.4, 0.000001));
    expect(slice.top, closeTo(22.4, 0.000001));
    expect(slice.right, closeTo(105.6, 0.000001));
    expect(slice.bottom, closeTo(57.6, 0.000001));
    expect(adaptiveArtworkCenterSlice(8, 80), isNull);
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
