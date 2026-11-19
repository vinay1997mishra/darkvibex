import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/games/ludo_game.dart';

Map<String, dynamic> _state({
  Object? playerCount,
  Object? colorPair,
  String currentPlayer = 'red',
  Map<String, List<int>>? tokens,
}) {
  return {
    'ok': true,
    'player_count': playerCount,
    'color_pair': colorPair,
    'current_player': currentPlayer,
    'rolled': 6,
    'winner': null,
    'status': 'RED starts. Roll the dice.',
    'tokens': tokens ??
        {
          'red': [-1, -1, -1, -1],
          'green': [-1, -1, -1, -1],
          'yellow': [-1, -1, -1, -1],
          'blue': [-1, -1, -1, -1],
        },
  };
}

void main() {
  test('defaults to 4 players with all colours active', () {
    final game = LudoGame();
    expect(game.playerCount, 4);
    expect(game.colorPair, isNull);
    expect(game.activePlayers, LudoPlayer.values);
  });

  test('2-player red-yellow activates only red and yellow', () {
    final game = LudoGame();
    game.applyServerState(
      _state(
        playerCount: 2,
        colorPair: 'red-yellow',
        tokens: {
          'red': [-1, -1, -1, -1],
          'green': [0, -1, -1, -1],
          'yellow': [-1, -1, -1, -1],
          'blue': [3, -1, -1, -1],
        },
      ),
    );

    expect(game.playerCount, 2);
    expect(game.colorPair, 'red-yellow');
    expect(game.activePlayers, [LudoPlayer.red, LudoPlayer.yellow]);
    // Inactive colours are forced back home, whatever the server sent.
    expect(game.tokens[LudoPlayer.green]!.every((t) => t.isHome), isTrue);
    expect(game.tokens[LudoPlayer.blue]!.every((t) => t.isHome), isTrue);
  });

  test('2-player blue-green activates only blue and green', () {
    final game = LudoGame();
    game.applyServerState(_state(playerCount: 2, colorPair: 'blue-green'));

    expect(game.activePlayers, [LudoPlayer.blue, LudoPlayer.green]);
  });

  test('4-player clears any color pair and activates all colours', () {
    final game = LudoGame(playerCount: 2, colorPair: 'red-yellow');
    game.applyServerState(_state(playerCount: 4, colorPair: 'red-yellow'));

    expect(game.playerCount, 4);
    expect(game.colorPair, isNull);
    expect(game.activePlayers, LudoPlayer.values);
  });

  test('string player_count parses, invalid values keep the mode', () {
    final game = LudoGame(playerCount: 2, colorPair: 'blue-green');
    game.applyServerState(_state(playerCount: '2', colorPair: 'blue-green'));
    expect(game.playerCount, 2);
    expect(game.colorPair, 'blue-green');

    game.applyServerState(_state(playerCount: 3, colorPair: 'red-green'));
    expect(game.playerCount, 2);
    expect(game.colorPair, isNull);

    game.applyServerState(_state(playerCount: null, colorPair: null));
    expect(game.playerCount, 2);
    expect(game.colorPair, isNull);
  });

  test('inactive current player has no movable tokens', () {
    final game = LudoGame();
    game.applyServerState(
      _state(
        playerCount: 2,
        colorPair: 'red-yellow',
        currentPlayer: 'green',
      ),
    );

    expect(game.movableTokenIndexes(), isEmpty);
  });

  test('active current player can move on a six', () {
    final game = LudoGame();
    game.applyServerState(
      _state(playerCount: 2, colorPair: 'red-yellow'),
    );

    expect(game.currentPlayer, LudoPlayer.red);
    expect(game.movableTokenIndexes(), [0, 1, 2, 3]);
  });

  test('board turns put every colour bottom-left on its own screen', () {
    // Vinay's examples: his colour is Blue (already bottom-left, no
    // rotation); the Green player's screen turns 180° so Green lands
    // bottom-left there.
    expect(LudoGame.boardTurnsFor(LudoPlayer.blue), 0);
    expect(LudoGame.boardTurnsFor(LudoPlayer.green), 2);
    expect(LudoGame.boardTurnsFor(LudoPlayer.red), 3);
    expect(LudoGame.boardTurnsFor(LudoPlayer.yellow), 1);
    // Spectator keeps the default layout.
    expect(LudoGame.boardTurnsFor(null), 0);
  });
}
