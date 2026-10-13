enum LudoPlayer { red, green, yellow, blue }

class LudoToken {
  const LudoToken({
    required this.player,
    required this.index,
    this.progress = -1,
  });

  final LudoPlayer player;
  final int index;

  bool get isHome => progress < 0;
  bool get isFinished => progress >= 57;

  LudoToken copyWith({int? progress}) => LudoToken(
        player: player,
        index: index,
        progress: progress ?? this.progress,
      );
}

class LudoGame {
  LudoGame() {
    tokens = {
      for (final player in LudoPlayer.values)
        player: List<LudoToken>.generate(
          4,
          (index) => LudoToken(player: player, index: index),
          growable: false,
        ),
    };
  }

  late final Map<LudoPlayer, List<LudoToken>> tokens;
  LudoPlayer currentPlayer = LudoPlayer.red;
  int? rolled;
  String status = 'RED starts. Roll the dice.';
  LudoPlayer? winner;

  static const Map<LudoPlayer, int> startOffsets = {
    LudoPlayer.red: 0,
    LudoPlayer.green: 13,
    LudoPlayer.yellow: 26,
    LudoPlayer.blue: 39,
  };

  List<int> movableTokenIndexes() {
    final dice = rolled;
    if (dice == null || winner != null) return const [];
    final list = tokens[currentPlayer]!;
    final values = <int>[];
    for (var i = 0; i < list.length; i++) {
      final token = list[i];
      if (token.isFinished) continue;
      if (token.isHome) {
        if (dice == 6) values.add(i);
        continue;
      }
      if (token.progress + dice <= 57) values.add(i);
    }
    return values;
  }

  int sharedTrackIndex(LudoPlayer player, int progress) {
    if (progress < 0 || progress >= 52) return -1;
    return (startOffsets[player]! + progress) % 52;
  }

  void applyServerState(Map<String, dynamic> data) {
    LudoPlayer? parsePlayer(dynamic value) {
      final name = value?.toString().toLowerCase() ?? '';
      for (final player in LudoPlayer.values) {
        if (player.name == name) return player;
      }
      return null;
    }

    final remoteCurrent = parsePlayer(data['current_player']);
    if (remoteCurrent != null) currentPlayer = remoteCurrent;

    final remoteRolled = data['rolled'];
    if (remoteRolled == null) {
      rolled = null;
    } else if (remoteRolled is num) {
      rolled = remoteRolled.toInt();
    } else {
      rolled = int.tryParse(remoteRolled.toString());
    }

    winner = parsePlayer(data['winner']);
    status = data['status']?.toString() ?? status;

    final rawTokens = data['tokens'];
    if (rawTokens is Map) {
      for (final player in LudoPlayer.values) {
        final raw = rawTokens[player.name];
        if (raw is! List) continue;
        final next = <LudoToken>[];
        for (var index = 0; index < 4; index += 1) {
          final value = index < raw.length ? raw[index] : -1;
          final progress = value is num
              ? value.toInt()
              : int.tryParse(value.toString()) ?? -1;
          next.add(
            LudoToken(
              player: player,
              index: index,
              progress: progress.clamp(-1, 57).toInt(),
            ),
          );
        }
        tokens[player] = List<LudoToken>.unmodifiable(next);
      }
    }
  }
}
