// Gift combo (Vinay, 2026-11-21).
//
// - Gift box bottom-right offers the copy count 1/7/77/177/777/7777. The
//   number is how many copies go to EACH selected user in one send
//   (4 users x combo 7 = 28 sends in one go). The total is gift cost x
//   users x combo, and the send only starts if the wallet affords it.
// - As soon as a gift is sent from the gift box, a combo button shows
//   below the Rocket (slightly right, slightly bigger circle) with the
//   count above it. Touching it re-sends the same gift to the same users
//   (same batch, as many times as wanted). It has a 5s timer: untouched
//   for 5s and the bubble disappears; every touch restarts the timer.
// - To change users, re-select from the gift box (a new gift-box send
//   replaces the combo).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gift box offers the combo copy count at the bottom right', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final pickerStart =
        source.indexOf('Future<void> _sendGiftToSeatUser(String receiverId)');
    final pickerEnd =
        source.indexOf('Future<void> _showSeatMemberProfile', pickerStart);
    final picker = source.substring(pickerStart, pickerEnd);

    expect(picker, contains('var selectedComboCount = 1;'));
    expect(picker, contains("Key('room-gift-combo-\$count')"));
    expect(picker, contains('const <int>[1, 7, 77, 177, 777, 7777]'));
    expect(picker, contains('selectedComboCount == count'));
    expect(picker, contains('() => selectedComboCount = count'));
    // The total charges copies x users x combo.
    expect(picker, contains('selectedReceiverIds.length *\n                selectedComboCount;'));
    // The combo count leaves the sheet with the selection.
    expect(picker, contains("'_selected_combo_count':"));
    expect(picker, contains('selectedComboCount,'));
  });

  test('bulk send uses the combo count and shows the combo button', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final consumerStart =
        source.indexOf("if (recipientIds.isEmpty || selectedGifts.isEmpty) return;");
    final consumerEnd = source.indexOf('Future<void> _openRoomUserProfile', consumerStart);
    final consumer = source.substring(consumerStart, consumerEnd);

    expect(consumer, contains("selection['_selected_combo_count']"));
    expect(consumer, contains('.clamp(1, 7777)'));
    expect(consumer, contains('recipientIds.length *\n        comboCount;'));
    expect(
      consumer,
      contains('final sent = await _sendGiftByDefinition(\n          gift,\n          id,\n          count: comboCount,\n          playEffect: !isFlyGift,\n        );'),
    );
    expect(consumer, contains('_giftComboGifts = selectedGifts'));
    expect(consumer, contains('_giftComboRecipientIds = List<String>.from(recipientIds)'));
    expect(consumer, contains('_giftComboCount = comboCount;'));
    expect(consumer, contains('_giftComboTotal = sentCopies;'));
    expect(consumer, contains('_startGiftComboTimer();'));
  });

  test('combo button re-sends the same gift to the same users with a 5s timer', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    // State + 5s ring timer (Bigo reference: the ring drains over 5s;
    // a new key restarts it, and onEnd hides the bubble).
    expect(source, contains('List<Map<String, dynamic>>? _giftComboGifts;'));
    expect(source, contains('List<String>? _giftComboRecipientIds;'));
    expect(source, contains('int _giftComboCount = 1;'));
    expect(source, contains('int _giftComboTotal = 0;'));
    expect(source, contains('int _giftComboTimerKey = 0;'));
    expect(source, contains('TweenAnimationBuilder<double>('));
    expect(source, contains('duration: const Duration(seconds: 5),'));
    expect(source, contains('onEnd: _hideGiftCombo,'));
    expect(source, contains('CircularProgressIndicator('));

    // The combo send re-uses the same gifts, recipients and count, and
    // grows the total by the copies actually sent.
    expect(source, contains('Future<void> _sendGiftCombo() async {'));
    expect(
      source,
      contains('final sent = await _sendGiftByDefinition(\n          gift,\n          id,\n          count: _giftComboCount,\n          playEffect: !isFlyGift,\n        );'),
    );
    expect(source, contains('setState(() => _giftComboTotal += sentCopies);'));

    // The button: below the Rocket, slightly right, a BIG circle (Bigo's
    // large red "Combo" button), with the count above it and a 5s ring.
    expect(source, contains("Key('room-gift-combo-button')"));
    expect(source, contains("Key('room-gift-combo-count')"));
    expect(source, contains("'x\$_giftComboTotal'"));
    expect(source, contains("onTap: _sendGiftCombo,"));
    expect(source, contains('width: 68,'));
    expect(source, contains('height: 68,'));
    expect(source, contains('Color(0xFFFF5252)'));
    expect(source, contains("'Combo',"));
  });

  test('sendGift carries the combo count and the send shows xN', () {
    final backend = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(backend, contains('int count = 1,'));
    expect(backend, contains("'count': count,"));

    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Future<bool> _sendGiftByDefinition('));
    expect(source, contains('int count = 1,'));
    expect(source, contains('count: count,'));
    expect(source, contains("result?['gift_count']"));
    expect(source, contains("result?['gift_total_cost']"));
    expect(source, contains('x\$sentCount'));
    expect(source, contains("'count': sentCount,"));
    // Remote members see the count too (gift-events feed carries it).
    expect(source, contains("verifiedEvent['count']"));
    expect(source, contains('x\$giftCount'));
  });

  test('the 5s ring cannot kill a combo whose send is still running', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    // The ring is wall-clock, but a multi-recipient send takes longer
    // than 5s (two round trips per copy): the ring firing mid-send
    // used to null the combo state, and the post-send timer restart
    // could not resurrect the button — the combo died after one press
    // (Vinay, 2026-11-22). The hide is now ignored while a send runs,
    // and the send restarts the ring when it lands.
    final hideStart = source.indexOf('void _hideGiftCombo()');
    final hideEnd = source.indexOf('/// Gift combo', hideStart);
    final hide = source.substring(hideStart, hideEnd);
    expect(hide, contains('if (!mounted || _giftComboSending) return;'));

    final sendStart = source.indexOf('Future<void> _sendGiftCombo() async {');
    final sendEnd = source.indexOf('Future<void> _sendGift()', sendStart);
    final send = source.substring(sendStart, sendEnd);
    // A second tap while sending must not start a second loop (it
    // would send — and charge — the batch twice).
    expect(send, contains('if (_giftComboSending) return;'));
    expect(send, contains('_giftComboSending = true;'));
    // The flag always clears, even on the early returns (not
    // connected, cannot afford, a copy failed, unmounted).
    expect(send, contains('} finally {'));
    expect(send, contains('_giftComboSending = false;'));
    // A failed combo still hides (its ring already drained while the
    // send ran, and the hide was ignored) instead of sitting there
    // with a dead ring.
    expect(send, contains('if (mounted && sentCopies == 0) _hideGiftCombo();'));
    // A successful send still restarts the ring.
    expect(send, contains('setState(() => _giftComboTotal += sentCopies);'));
    expect(send, contains('_startGiftComboTimer();'));
  });
}
