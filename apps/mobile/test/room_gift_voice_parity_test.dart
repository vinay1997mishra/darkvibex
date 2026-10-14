import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room gifts include self, target DP, and speaking waves', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();

    final chooserStart =
        source.indexOf('Future<String?> _chooseGiftReceiver() async');
    final chooserEnd =
        source.indexOf('Future<Map<String, dynamic>?> _createRoomCustomGift()',
            chooserStart);
    expect(chooserStart, greaterThanOrEqualTo(0));
    expect(chooserEnd, greaterThan(chooserStart));
    final chooser = source.substring(chooserStart, chooserEnd);

    expect(chooser, contains("'user_id': widget.state.userId"));
    expect(chooser, contains("Key('gift-recipient-$userId')"));
    expect(chooser, contains('room-gift-recipient-grid'));
    expect(
      chooser,
      isNot(contains("member['user_id']?.toString() != widget.state.userId")),
    );

    final sendStart = source.indexOf('Future<void> _sendGift() async');
    final sendEnd =
        source.indexOf('Future<void> _sendInlineMessage', sendStart);
    final sendBlock = source.substring(sendStart, sendEnd);
    expect(sendBlock, contains('final selected = await _chooseGiftReceiver()'));
    expect(sendBlock, isNot(contains('if (isRoomHost)')));

    expect(source, contains('activeGiftReceiverId == memberId'));
    expect(source, contains('_buildSeatGiftImpactEffect'));
    expect(source, contains('activeGiftReceiverAvatarKey'));
    expect(source, contains('speakingLevelsListenable'));
    expect(source, contains('_LiveMicWaves'));
    expect(source, contains('_LiveMicWavePainter'));
  });

  test('LiveKit speaking levels are sampled from active speakers', () {
    final source = File('lib/infra/livekit_rtc.dart').readAsStringSync();
    expect(source, contains('for (final participant in room.activeSpeakers)'));
    expect(source, contains('participant.isSpeaking'));
    expect(source, contains('participant.audioLevel'));
    expect(source, contains('const Duration(milliseconds: 150)'));
  });
}
