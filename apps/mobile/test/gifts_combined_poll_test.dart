import 'dart:io';

import 'package:darkvibex/screens/wallet_detail_screens.dart';
import 'package:flutter_test/flutter_test.dart';

// Separate gifts + diamonds + coins calls (combined gifts API removed
// 2026-11-23, Vinay: "combined API hta de, har jagah se"): the priced
// catalog comes from giftCatalog, live balances from refreshWallet, and
// the Diamonds/Coins screens poll their own history endpoints every 3s
// (merging new rows on top of the full history loaded on open). The
// worker tests cover the endpoints; this test covers the live wiring.
void main() {
  test('mergeHistoryRows puts new rows first, dedupes by id, caps at 200', () {
    final existing = <Map<String, dynamic>>[
      {'id': 'a', 'created_at': 1},
      {'id': 'b', 'created_at': 2},
    ];
    final incoming = <Map<String, dynamic>>[
      {'id': 'c', 'created_at': 3},
      {'id': 'a', 'created_at': 1},
    ];
    expect(
      mergeHistoryRows(existing, incoming)
          .map((row) => row['id'])
          .toList(),
      ['c', 'a', 'b'],
    );
    final many = List<Map<String, dynamic>>.generate(
      250,
      (i) => {'id': 'x$i'},
    );
    expect(mergeHistoryRows(const [], many).length, 200);
    expect(mergeHistoryRows(existing, const []), existing);
  });

  test('Diamonds + Coins + Seller-received screens poll separate history calls every 3s', () {
    final wallet =
        File('lib/screens/wallet_detail_screens.dart').readAsStringSync();
    expect(wallet, isNot(contains('giftsCombinedState')));
    expect(wallet, isNot(contains('_pollCombined')));
    expect(wallet, contains('_pollHistory'));
    expect(wallet, contains('coinsHistory'));
    expect(wallet, contains('diamondsHistory'));
    expect(wallet, contains('refreshWallet'));
    // One 3s poll each: Diamonds, Coins History, Seller Received.
    expect('Duration(seconds: 3)'.allMatches(wallet).length, 3);
    expect('Timer.periodic('.allMatches(wallet).length, 3);
    expect(wallet, contains('mergeHistoryRows'));
  });

  test('gift UIs take their catalog from the separate catalog call', () {
    final room = File('lib/screens/room_screen.dart').readAsStringSync();
    expect(room, isNot(contains('giftsCombinedState')));
    expect(room, contains('giftCatalog('));

    final gameRoom =
        File('lib/screens/game_room_screen.dart').readAsStringSync();
    expect(gameRoom, isNot(contains('giftsCombinedState')));
    expect(gameRoom, contains('giftCatalog('));

    final gifts = File('lib/screens/gifts_screen.dart').readAsStringSync();
    expect(gifts, isNot(contains('giftsCombinedState')));
    expect(gifts, contains('giftCatalog('));
  });

  test('BackendApi exposes the separate endpoints, no combined call', () {
    final api = File('lib/infra/backend_api.dart').readAsStringSync();
    expect(api, isNot(contains("'/api/gifts/combined'")));
    expect(api, isNot(contains('giftsCombinedState')));
    expect(api, contains('/api/gifts/catalog?user_id='));
    expect(api, contains('coinsHistory'));
    expect(api, contains('diamondsHistory'));
  });
}
