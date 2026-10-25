import 'package:darkvibex/widgets/room_floating_logos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('room target rocket launches and finishes its animation',
      (tester) async {
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              RoomRocketLaunchEffect(
                level: 7,
                onFinished: () => finished = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byKey(const Key('room-rocket-launching-art')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump();

    expect(finished, isTrue);
  });
}
