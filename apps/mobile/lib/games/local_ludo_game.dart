import 'dart:math';

enum LocalLudoPlayer { red, green, yellow, blue }

class LocalLudoToken {
  const LocalLudoToken(this.player, this.index, [this.progress = -1]);
  final LocalLudoPlayer player;
  final int index;
  final int progress; // -1 home, 0..51 track, 52..57 home lane
  bool get isHome => progress < 0;
  bool get isFinished => progress >= 57;
}

class LocalLudoGame {
  LocalLudoGame({required this.playerCount, Random? random})
      : assert(playerCount == 2 || playerCount == 4),
        _random = random ?? Random() {
    reset();
  }

  final int playerCount;
  final Random _random;
  late final List<LocalLudoPlayer> players = playerCount == 2
      ? const [LocalLudoPlayer.red, LocalLudoPlayer.yellow]
      : LocalLudoPlayer.values;
  late Map<LocalLudoPlayer, List<LocalLudoToken>> tokens;
  int turn = 0;
  int? rolled;
  LocalLudoPlayer? winner;
  String status = '';

  LocalLudoPlayer get currentPlayer => players[turn];

  static const offsets = <LocalLudoPlayer, int>{
    LocalLudoPlayer.red: 0,
    LocalLudoPlayer.green: 13,
    LocalLudoPlayer.yellow: 26,
    LocalLudoPlayer.blue: 39,
  };

  int roll() {
    if (winner != null || rolled != null) return rolled ?? 1;
    final value = _random.nextInt(6) + 1;
    rolled = value;
    status = '${_label(currentPlayer)} rolled $value.';
    if (movableIndexes.isEmpty) _finishTurn(keepTurn: value == 6);
    return value;
  }

  List<int> get movableIndexes {
    final dice = rolled;
    if (dice == null || winner != null) return const [];
    final list = tokens[currentPlayer]!;
    return [for (var i = 0; i < list.length; i++)
      if (!list[i].isFinished &&
          (list[i].isHome ? dice == 6 : list[i].progress + dice <= 57)) i];
  }

  bool move(int index) {
    final dice = rolled;
    if (dice == null || !movableIndexes.contains(index)) return false;
    final old = tokens[currentPlayer]![index];
    final progress = old.isHome ? 0 : old.progress + dice;
    final updated = List<LocalLudoToken>.from(tokens[currentPlayer]!);
    updated[index] = LocalLudoToken(currentPlayer, index, progress);
    tokens[currentPlayer] = updated;

    if (progress < 52) _capture((offsets[currentPlayer]! + progress) % 52);
    if (tokens[currentPlayer]!.every((token) => token.isFinished)) {
      winner = currentPlayer;
      rolled = null;
      status = '${_label(currentPlayer)} wins!';
      return true;
    }
    status = '${_label(currentPlayer)} moved token ${index + 1}.';
    _finishTurn(keepTurn: dice == 6);
    return true;
  }

  void _capture(int square) {
    const safe = <int>{0, 8, 13, 21, 26, 34, 39, 47};
    if (safe.contains(square)) return;
    for (final opponent in players.where((player) => player != currentPlayer)) {
      final list = List<LocalLudoToken>.from(tokens[opponent]!);
      var changed = false;
      for (var i = 0; i < list.length; i++) {
        final token = list[i];
        if (token.progress >= 0 && token.progress < 52 &&
            (offsets[opponent]! + token.progress) % 52 == square) {
          list[i] = LocalLudoToken(opponent, i);
          changed = true;
        }
      }
      if (changed) tokens[opponent] = list;
    }
  }

  void _finishTurn({required bool keepTurn}) {
    rolled = null;
    if (winner != null) return;
    if (keepTurn) {
      status = '${_label(currentPlayer)} gets another roll.';
    } else {
      turn = (turn + 1) % players.length;
      status = '${_label(currentPlayer)} turn.';
    }
  }

  void reset() {
    tokens = {for (final player in players)
      player: List.generate(4, (i) => LocalLudoToken(player, i))};
    turn = 0;
    rolled = null;
    winner = null;
    status = '${_label(currentPlayer)} starts. Roll the dice.';
  }

  static String _label(LocalLudoPlayer player) =>
      player.name[0].toUpperCase() + player.name.substring(1);
}
