import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import '../lib/games/local_ludo_game.dart';

class _Dice extends Random {
  _Dice(this.values);
  final List<int> values;

  @override
  int nextInt(int max) => values.removeAt(0) % max;
}

void main() {
  test('supports two and four active players', () {
    final two = LocalLudoGame(playerCount: 2, random: _Dice([0]));
    final four = LocalLudoGame(playerCount: 4, random: _Dice([0]));

    expect(two.players, [LocalLudoPlayer.red, LocalLudoPlayer.yellow]);
    expect(four.players, LocalLudoPlayer.values);
  });

  test('a six brings a token out and grants another roll', () {
    final game = LocalLudoGame(playerCount: 2, random: _Dice([5, 0]));

    expect(game.roll(), 6);
    expect(game.movableIndexes, [0, 1, 2, 3]);
    expect(game.move(0), isTrue);
    expect(game.currentPlayer, LocalLudoPlayer.red);
    expect(game.tokens[LocalLudoPlayer.red]![0].progress, 0);
    expect(game.rolled, isNull);
  });

  test('non-six with no movable token passes turn and reports the die', () {
    final game = LocalLudoGame(playerCount: 2, random: _Dice([1]));

    expect(game.roll(), 2);
    expect(game.currentPlayer, LocalLudoPlayer.yellow);
    expect(game.rolled, isNull);
  });

  test('rejects a move when the player has not rolled a six', () {
    final game = LocalLudoGame(playerCount: 2, random: _Dice([1]));

    game.roll();
    expect(game.move(0), isFalse);
    expect(game.currentPlayer, LocalLudoPlayer.yellow);
  });

  test('winning token finishes the game', () {
    final game = LocalLudoGame(playerCount: 2, random: _Dice([0]));
    game.tokens[LocalLudoPlayer.red] = [
      const LocalLudoToken(LocalLudoPlayer.red, 0, 56),
      const LocalLudoToken(LocalLudoPlayer.red, 1, 57),
      const LocalLudoToken(LocalLudoPlayer.red, 2, 57),
      const LocalLudoToken(LocalLudoPlayer.red, 3, 57),
    ];

    game.roll();
    expect(game.move(0), isTrue);
    expect(game.winner, LocalLudoPlayer.red);
    expect(game.status, 'Red wins!');
  });
}
