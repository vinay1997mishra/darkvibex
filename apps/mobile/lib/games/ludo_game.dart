enum LudoPlayer { red, green, yellow, blue }

class LudoToken {
  const LudoToken({
    required this.player,
    required this.index,
    this.progress = -1,
  });

  final LudoPlayer player;
  final int index;
  final int progress;

  bool get isHome => progress < 0;
  bool get isFinished => progress >= 57;

  LudoToken copyWith({int? progress}) => LudoToken(
        player: player,
        index: index,
        progress: progress ?? this.progress,
      );
}

class LudoGame {
  LudoGame({this.playerCount = 4, this.colorPair}) {
    tokens = {
      for (final player in LudoPlayer.values)
        player: List<LudoToken>.generate(
          4,
          (index) => LudoToken(player: player, index: index),
          growable: false,
        ),
    };
  }

  /// 2 or 4. In a 2-player game only one cross pair plays.
  int playerCount;

  /// 2-player cross pair: 'red-yellow' or 'blue-green'. Null for 4-player.
  String? colorPair;

  /// Colours actually playing. 2P red-yellow -> [red, yellow];
  /// 2P blue-green -> [blue, green]; 4P -> all four.
  List<LudoPlayer> get activePlayers {
    if (playerCount == 2) {
      return colorPair == 'blue-green'
          ? const [LudoPlayer.blue, LudoPlayer.green]
          : const [LudoPlayer.red, LudoPlayer.yellow];
    }
    return LudoPlayer.values;
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

  /// Quarter-turns (clockwise) that bring [player]'s home to the
  /// bottom-left corner of the screen — every player sees their own
  /// colour bottom-left (Ludo King style). Blue is already bottom-left
  /// (0), red needs 3 (90° counter-clockwise), green 2 (180°), yellow
  /// 1 (90° clockwise). Null (spectator) keeps the default layout.
  static int boardTurnsFor(LudoPlayer? player) => switch (player) {
        LudoPlayer.red => 3,
        LudoPlayer.green => 2,
        LudoPlayer.yellow => 1,
        LudoPlayer.blue => 0,
        null => 0,
      };

  List<int> movableTokenIndexes() {
    final dice = rolled;
    if (dice == null || winner != null) return const [];
    if (!activePlayers.contains(currentPlayer)) return const [];
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

    // Table mode comes from the server state: player_count (2|4) and
    // color_pair ('red-yellow' | 'blue-green', null for 4P). The first
    // joiner sets it; invalid values keep the current mode.
    final rawCount = data['player_count'];
    final parsedCount = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '');
    if (parsedCount != null && (parsedCount == 2 || parsedCount == 4)) {
      playerCount = parsedCount;
    }
    final rawPair = data['color_pair']?.toString().toLowerCase();
    colorPair = (rawPair == 'red-yellow' || rawPair == 'blue-green')
        ? rawPair
        : null;
    if (playerCount == 4) colorPair = null;

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

    // Tokens of colours that are not playing stay home and are never
    // movable, whatever the server sent for them.
    for (final player in LudoPlayer.values) {
      if (!activePlayers.contains(player)) {
        tokens[player] = List<LudoToken>.unmodifiable(
          List<LudoToken>.generate(
            4,
            (index) => LudoToken(player: player, index: index),
            growable: false,
          ),
        );
      }
    }
  }
}
