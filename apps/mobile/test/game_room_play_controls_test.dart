import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Game Room keeps its existing 15-seat rail', () {
    final source = File('lib/screens/game_room_screen.dart').readAsStringSync();

    expect(source, contains("key: const Key('game-room-15-seat-list')"));
    expect(source, contains('itemCount: 15'));
    expect(source, contains('width: 68'));
    expect(source, contains('radius: 16'));
  });

  test('Game Room exposes games and normal-room controls', () {
    final source = File('lib/screens/game_room_screen.dart').readAsStringSync();

    expect(source, contains("key: const Key('game-room-play-now')"));
    expect(source, contains("key: const Key('game-room-play-fruit-party')"));
    expect(source, contains("key: const Key('game-room-play-greedy-girl')"));
    expect(source, contains("key: const Key('game-room-play-ludo')"));
    expect(source, contains("key: const Key('game-room-share-button')"));
    expect(source, contains("key: const Key('game-room-mic-button')"));
    expect(source, contains("key: const Key('game-room-gift-button')"));
    expect(source, contains("key: const Key('game-room-messages-button')"));
    expect(source, contains("key: const Key('game-room-4box-button')"));
    expect(source, contains("key: const Key('game-room-chat-input')"));
  });

  test('Game Room backend supports chat voice and Ludo membership', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    final worker = File('../worker/src/index.js').readAsStringSync();

    expect(api, contains('gameRoomMessages'));
    expect(api, contains('sendGameRoomMessage'));
    expect(api, contains('leaveGameRoom'));
    expect(worker, contains('game_room_messages'));
    expect(worker, contains('game_room_members WHERE room_id = ? AND user_id = ?'));
    expect(worker, contains('join|leave|tap|messages'));
    expect(worker, contains('async function requireLudoRoomMember'));
  });
}
