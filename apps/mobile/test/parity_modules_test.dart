import 'package:flutter_test/flutter_test.dart';

import 'package:darkvibex/features/catalog_models.dart';
import 'package:darkvibex/games/ludo_game.dart';

void main() {
  test('relationship progress keeps independent level math', () {
    final progress = RelationshipProgress.fromMap(<String, dynamic>{
      'kind': 'cp',
      'progress': 3000000,
      'level': 4,
      'previous_threshold': 3000000,
      'next_threshold': 6000000,
    });

    expect(progress.kind, 'cp');
    expect(progress.level, 4);
    expect(progress.fraction, 0);
  });

  test('ludo starts with four tokens per player and unique track offsets', () {
    final game = LudoGame();

    for (final player in LudoPlayer.values) {
      expect(game.tokens[player], hasLength(4));
      expect(game.tokens[player]!.every((token) => token.isHome), isTrue);
    }

    expect(game.sharedTrackIndex(LudoPlayer.red, 0), 0);
    expect(game.sharedTrackIndex(LudoPlayer.green, 0), 13);
    expect(game.sharedTrackIndex(LudoPlayer.yellow, 0), 26);
    expect(game.sharedTrackIndex(LudoPlayer.blue, 0), 39);
  });
}
