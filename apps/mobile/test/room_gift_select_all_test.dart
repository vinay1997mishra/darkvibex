// Gift Box "Select All" + bulk-send affordability gate (Vinay, 2026-11-21).
//
// - The Gift Box recipient row has a Select All button that selects every
//   seat user's DP at once, including the sender (the sender is already in
//   the recipients list). Tapping again deselects all.
// - The gift goes to every selected recipient at once ONLY if the wallet
//   can afford the whole total (catalog cost x recipient count). If not,
//   nothing is sent and the user is told the total and the balance.
// - The send loop stops on the first failed send, so a bulk send never
//   keeps spending after a failure.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gift box has a Select All button that selects every seat DP incl. self', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final pickerStart =
        source.indexOf('Future<void> _sendGiftToSeatUser(String receiverId)');
    final pickerEnd =
        source.indexOf('Future<void> _showSeatMemberProfile', pickerStart);
    expect(pickerStart, greaterThanOrEqualTo(0));
    expect(pickerEnd, greaterThan(pickerStart));
    final picker = source.substring(pickerStart, pickerEnd);

    expect(picker, contains("Key('room-gift-select-all')"));
    expect(picker, contains("'Select All'"));
    expect(picker, contains("'Deselect All'"));
    // The selection set is built from every recipient row, and the sender
    // is already in the recipients list (inserted when absent).
    expect(picker, contains('final allRecipientIds = recipients'));
    expect(
      picker,
      contains('selectedReceiverIds.addAll(allRecipientIds)'),
    );
    expect(picker, contains('selectedReceiverIds.clear()'));
    expect(
      picker,
      contains("'avatar_key': widget.state.avatarKey"),
      reason: 'Select All must include the sender, who is in the list',
    );
    // The button sits above the horizontal DP row.
    final selectAll = picker.indexOf("Key('room-gift-select-all')");
    final recipientRow = picker.indexOf('for (final person in recipients)');
    expect(selectAll, greaterThanOrEqualTo(0));
    expect(recipientRow, greaterThan(selectAll));
  });

  test('bulk send only starts when the wallet can afford the whole total', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final consumerStart =
        source.indexOf("if (recipientIds.isEmpty || selectedGifts.isEmpty) return;");
    expect(consumerStart, greaterThanOrEqualTo(0));
    final consumerEnd = source.indexOf('Future<void> _openRoomUserProfile', consumerStart);
    expect(consumerEnd, greaterThan(consumerStart));
    final consumer = source.substring(consumerStart, consumerEnd);

    expect(consumer, contains('final totalCost = selectedGifts.fold<int>('));
    expect(consumer, contains('recipientIds.length'));
    expect(
      consumer,
      contains('if (widget.state.coins < totalCost)'),
      reason: 'Never start a bulk send the wallet cannot cover',
    );
    expect(consumer, contains("'Not enough coins — need \$totalCost, you have \${widget.state.coins}.'"));
    // The insufficient-coins return happens before the send loop.
    final gate = consumer.indexOf('if (widget.state.coins < totalCost)');
    final loop = consumer.indexOf('for (final gift in selectedGifts)');
    expect(gate, greaterThanOrEqualTo(0));
    expect(loop, greaterThan(gate));
  });

  test('bulk send stops on the first failed send', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(source, contains('Future<bool> _sendGiftByDefinition('));
    expect(source, contains('if (giftId.isEmpty || giftCost <= 0 || receiverId.isEmpty) return false;'));
    expect(source, contains('return true;'));
    final consumerStart =
        source.indexOf("if (recipientIds.isEmpty || selectedGifts.isEmpty) return;");
    final consumerEnd = source.indexOf('Future<void> _openRoomUserProfile', consumerStart);
    final consumer = source.substring(consumerStart, consumerEnd);
    expect(
      consumer,
      contains('final sent = await _sendGiftByDefinition(gift, id, count: comboCount);'),
    );
    expect(consumer, contains('if (!sent) return;'));
  });

  test('recipient row shows only 7 DPs at a time, the rest by sliding right', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final pickerStart =
        source.indexOf('Future<void> _sendGiftToSeatUser(String receiverId)');
    final pickerEnd =
        source.indexOf('Future<void> _showSeatMemberProfile', pickerStart);
    final picker = source.substring(pickerStart, pickerEnd);
    // Exactly 7 items fit the row width; the avatar takes the biggest
    // size that still fits 7 across, so it stays visible, not tiny.
    expect(picker, contains('final recipientItemWidth ='));
    expect(picker, contains('/ 7)'));
    expect(picker, contains('width: recipientItemWidth,'));
    expect(picker, contains('final recipientAvatarSize = recipientItemWidth - 6;'));
    expect(picker, contains('width: recipientAvatarSize,'));
    expect(picker, contains('height: recipientAvatarSize,'));
    // The row still scrolls horizontally, so the remaining DPs are
    // reached by sliding right.
    expect(picker, contains('scrollDirection: Axis.horizontal,'));
    // No fixed tiny size remains for the recipient DP.
    expect(picker, isNot(contains('width: 49,')));
    expect(picker, isNot(contains('width: 66,')));
  });
}
