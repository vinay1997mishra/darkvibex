import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('room Gift Box does not expose in-app add-new-gift controls', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    final gifts = File('lib/screens/gifts_screen.dart').readAsStringSync();
    final backend = File('lib/infra/backend_api.dart').readAsStringSync();

    expect(room, isNot(contains('room-create-custom-gift-grid')));
    expect(room, isNot(contains('Add custom gift')));
    expect(room, isNot(contains('_createRoomCustomGift')));
    expect(room, isNot(contains('FilePicker.pickFiles')));
    expect(backend, isNot(contains('createCustomGift')));

    // Gift browsing, category selection, media playback and sending remain.
    expect(room, contains('_sendGiftToSeatUser'));
    expect(room, contains('GiftMediaPreview('));
    expect(gifts, contains('GiftMediaPreview('));
    expect(backend, contains("'/api/gifts/send'"));
  });
}
