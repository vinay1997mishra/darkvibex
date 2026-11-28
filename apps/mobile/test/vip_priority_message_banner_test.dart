import 'package:darkvibex/widgets/vip_priority_message_banner.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _message(String text, int vipLevel) =>
    <String, dynamic>{
      'display_name': 'Vinay',
      'text': text,
      'active_vip_level': vipLevel,
    };

void main() {
  test('latestPriorityMessage is null without a VIP9+ text message', () {
    expect(latestPriorityMessage([]), isNull);
    expect(
      latestPriorityMessage([_message('hello', 8)]),
      isNull,
    );
    expect(
      latestPriorityMessage([_message('', 13)]),
      isNull,
    );
    expect(
      latestPriorityMessage([_message('[panda:happy]', 13)]),
      isNull,
    );
  });

  test('latestPriorityMessage picks the newest VIP9+ text message', () {
    final first = _message('first', 9);
    final second = _message('second', 13);
    final chat = <Map<String, dynamic>>[
      _message('plain', 0),
      first,
      _message('not vip', 5),
      second,
      _message('after', 2),
    ];
    expect(latestPriorityMessage(chat), same(second));
  });

  testWidgets('priority banner shows the label, coloured name and text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: VipPriorityMessageBanner(
                message: _message('Hello room!', 9),
                onDismissed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('vip-priority-banner')), findsOneWidget);
    expect(find.text('PRIORITY'), findsOneWidget);
    expect(find.text('Vinay'), findsOneWidget);
    expect(find.text('Hello room!'), findsOneWidget);
    // VIP9 name colour is purple.
    final nameText = tester.widget<Text>(find.text('Vinay'));
    expect(nameText.style?.color, const Color(0xFF9B32FF));
    expect(tester.takeException(), isNull);
  });

  testWidgets('priority banner close button dismisses it', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: VipPriorityMessageBanner(
                message: _message('Hello room!', 10),
                onDismissed: () => dismissed = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('vip-priority-banner-close')));
    expect(dismissed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('priority banner with a long message does not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: VipPriorityMessageBanner(
                message: _message(
                  'A very long priority message that keeps going and going '
                  'across the room chat so the banner must wrap it safely',
                  18,
                ),
                onDismissed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('vip-priority-banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
