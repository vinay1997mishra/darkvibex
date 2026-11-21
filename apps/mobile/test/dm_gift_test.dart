import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// DM gift (Vinay, 2026-11-21): pic and gift both send from inside the
// 1-to-1 DM chat. The pic button already existed; this adds a gift button
// next to it in the composer, a gift picker, and a gold gift card render
// for the kind='gift' DM row the server writes for room-less gifts.
void main() {
  test('DM composer has a gift button next to the pic button, gated on friends',
      () {
    final conversation =
        File('lib/screens/conversation_screen.dart').readAsStringSync();
    expect(conversation, contains("Icons.card_giftcard_rounded"));
    expect(conversation, contains("tooltip: 'Send gift'"));
    expect(conversation, contains('_sendGift'));
    expect(conversation, contains('sendingGift'));
    expect(
      conversation,
      contains('onPressed: !isFriend || sendingGift ? null : _sendGift'),
    );
    // The pic option is untouched.
    expect(conversation, contains("Icons.image_rounded"));
    expect(conversation, contains("tooltip: 'Share photo'"));
    expect(conversation, contains('_sendImage'));
  });

  test('DM gift flow picks from the catalog, confirms, and sends with no room',
      () {
    final conversation =
        File('lib/screens/conversation_screen.dart').readAsStringSync();
    expect(conversation, contains('giftCatalog(userId: widget.state.userId)'));
    expect(conversation, contains('_DmGiftPicker'));
    expect(conversation, contains("Send a gift to"));
    expect(conversation, contains("child: const Text('Send gift')"));
    expect(
      conversation,
      contains('widget.state.backend.sendGift('),
    );
    expect(
      conversation,
      contains('receiverUserId: widget.otherUserId,'),
    );
    expect(conversation, contains("Gifts can only be sent to mutual friends."));
    expect(conversation, contains("'friends_required' =>"));
    expect(conversation, contains("'insufficient_coins' =>"));
    expect(conversation, contains('refreshWallet()'));
  });

  test('DM gift picker has the same 6 categories as the room gift panel', () {
    final conversation =
        File('lib/screens/conversation_screen.dart').readAsStringSync();
    for (final category in ['Normal', 'Lucky', 'CP', 'Country', 'Luxury', 'Backpack']) {
      expect(conversation, contains("'$category'"));
    }
    expect(conversation, contains("category == 'lucky'"));
    expect(conversation, contains("category == 'cp'"));
    expect(conversation, contains("category == 'country'"));
    expect(conversation, contains("category == 'luxury'"));
    expect(conversation, contains("category == 'backpack'"));
  });

  test('DM thread renders a kind=gift row as a gold gift card', () {
    final conversation =
        File('lib/screens/conversation_screen.dart').readAsStringSync();
    expect(conversation, contains("item['kind']?.toString() == 'gift'"));
    expect(conversation, contains('const Color(0xAAFFD36A)'));
    expect(conversation, contains('color: Color(0xFFFFD36A)'));
  });

  test('room-less gift send leaves room_id out so the server treats it as a DM gift',
      () {
    final backend = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(backend, contains('String? roomId,'));
    expect(
      backend,
      contains("if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,"),
    );
  });

  test('server writes a kind=gift DM row only for room-less gifts', () {
    final worker = File('../worker/src/index.js').readAsStringSync();
    expect(worker, contains("kind='gift' DM row"));
    expect(
      worker,
      contains(
        '"INSERT INTO direct_messages (id, sender_user_id, receiver_user_id, kind, text, created_at, read_at) "',
      ),
    );
    expect(worker, contains("SELECT 1 FROM gift_events WHERE id=?)"));
    expect(worker, contains('friends_required'));
  });
}
