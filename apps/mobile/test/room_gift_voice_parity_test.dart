// Gift + voice parity build lock.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room Gift Box opens with recipient DPs and categories together', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    final sendStart = source.indexOf('Future<void> _sendGift() async');
    final sendEnd =
        source.indexOf('Future<void> _sendInlineMessage', sendStart);
    expect(sendStart, greaterThanOrEqualTo(0));
    expect(sendEnd, greaterThan(sendStart));
    final sendBlock = source.substring(sendStart, sendEnd);
    expect(sendBlock, contains("await _sendGiftToSeatUser('')"));
    expect(sendBlock, isNot(contains('_chooseGiftReceiver')));

    final pickerStart =
        source.indexOf('Future<void> _sendGiftToSeatUser(String receiverId)');
    final pickerEnd =
        source.indexOf('Future<void> _showSeatMemberProfile', pickerStart);
    expect(pickerStart, greaterThanOrEqualTo(0));
    expect(pickerEnd, greaterThan(pickerStart));
    final picker = source.substring(pickerStart, pickerEnd);

    expect(picker, contains("final selectedReceiverIds = receiverId.trim().isEmpty"));
    expect(picker, contains("for (final category in const ["));
    expect(picker, contains("Key('room-gift-category-' + category)"));
    expect(picker, contains('for (final person in recipients)'));
    expect(picker, contains("Key('room-gift-total-coins')"));
    expect(picker, contains("Key('room-gift-send-button')"));
    expect(picker, contains("final fetchedMembers = widget.state.backendConnected"));
    expect(picker, contains("'avatar_key': widget.state.avatarKey"));
    expect(
      picker,
      contains("MediaQuery.sizeOf(sheetContext).height * .58"),
      reason: 'Gift Box panel should be shorter to leave more room for the room',
    );
    expect(picker, contains('height: 79,'));
    expect(picker, contains('crossAxisCount: 5'));
    expect(picker, contains('crossAxisSpacing: 2'));
    expect(picker, contains('mainAxisSpacing: 5'));
    expect(picker, contains('childAspectRatio: .72'));
    expect(picker, contains('width: 36,\n                                                  height: 36,'));
    expect(picker, contains('fontSize: 9,\n                                          height: 1.05,'));

    final categoryRow = picker.indexOf("for (final category in const [");
    final recipientRow = picker.indexOf('for (final person in recipients)');
    expect(categoryRow, greaterThanOrEqualTo(0));
    expect(recipientRow, greaterThan(categoryRow));

    expect(source, contains('activeGiftReceiverId == memberId'));
    expect(source, contains('_buildSeatGiftImpactEffect'));
    expect(source, contains('activeGiftReceiverAvatarKey'));
    expect(source, contains('speakingLevelsListenable'));
    expect(source, contains('_LiveMicWaves'));
    expect(source, contains('_LiveMicWavePainter'));
    expect(source, contains('required this.diameter'));
    expect(source, contains('final baseRadius = avatarDiameter / 2'));
    expect(source, contains('canvas.drawCircle(center, radius, wavePaint)'));
    expect(source, contains('left: -(compactSeats ? 9.0 : 12.0)'));
    expect(source, contains('top: -(compactSeats ? 9.0 : 12.0)'));
  });


  test('room gift events are polled and played once for remote members', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final backend = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(backend, contains('roomGiftEvents('));
    expect(backend, contains('/gift-events?after='));
    expect(source, contains('unawaited(_loadRoomGiftEvents())'));
    expect(source, contains('event[\'sender_user_id\']?.toString() == widget.state.userId'));
    expect(source, contains('_seenGiftEventIds.add(eventId)'));
    expect(source, contains('_giftPlaybackQueue'));
    expect(source, contains('senderName: senderName'));
    expect(source, contains('required String videoKey'));
  });

  test('gift sender sees their own gift immediately without duplicate polling playback', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final sendStart = source.indexOf('Future<void> _sendGiftByDefinition');
    final sendEnd = source.indexOf('Future<void> ', sendStart + 20);
    final sendFlow = source.substring(sendStart, sendEnd);
    expect(sendFlow, contains('_seenGiftEventIds.add(committedEventId)'));
    expect(sendFlow, contains('await _playGiftVideo(gift, receiverId: receiverId, videoKey: videoKey)'));
    expect(sendFlow, contains('await _playGiftGlb(gift, receiverId: receiverId, glbKey: glbKey)'));
    expect(sendFlow, contains('_playGiftEffect(gift, receiverId: receiverId)'));
    expect(sendFlow, contains('sendRoomMessage('));
    expect(source, contains("if (event['sender_user_id']?.toString() == widget.state.userId) continue;"));
  });

  test('LiveKit speaking levels are sampled from active speakers', () {
    final source = File('lib/infra/livekit_rtc.dart').readAsStringSync();
    expect(source, contains('for (final participant in room.activeSpeakers)'));
    expect(source, contains('participant.isSpeaking'));
    expect(source, contains('participant.audioLevel'));
    expect(source, contains('const Duration(milliseconds: 150)'));
  });
}
