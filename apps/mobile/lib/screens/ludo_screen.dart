import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../games/ludo_game.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({
    super.key,
    required this.state,
    required this.roomId,
    required this.playerCount,
    this.colorPair,
    this.roomOwnerUserId,
    this.onToggleMic,
    this.micOn,
    this.hasMicSeat,
  });

  final AppState state;
  final String roomId;

  /// 2 or 4 players. In a 2-player game [colorPair] picks the cross
  /// pair: 'red-yellow' or 'blue-green' (null for 4-player).
  final int playerCount;
  final String? colorPair;
  final String? roomOwnerUserId;
  final Future<void> Function()? onToggleMic;
  final bool Function()? micOn;
  final bool Function()? hasMicSeat;

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with WidgetsBindingObserver {
  late final LudoGame game = LudoGame(
    playerCount: widget.playerCount,
    colorPair: widget.colorPair,
  );
  final Map<String, Map<String, dynamic>> players =
      <String, Map<String, dynamic>>{};

  Timer? refreshTimer;
  bool busy = false;
  bool ready = false;
  bool foreground = true;
  String? myColor;
  String? errorText;
  int version = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (foreground && !busy) unawaited(_refresh(silent: true));
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) unawaited(_refresh(silent: true));
  }

  void _apply(Map<String, dynamic> data) {
    if (data['ok'] != true) return;
    final nextVersion = int.tryParse(data['version']?.toString() ?? '') ?? 0;
    if (version > 0 && nextVersion > 0 && nextVersion < version) return;

    game.applyServerState(data);
    players.clear();
    final rawPlayers = data['players'];
    if (rawPlayers is List) {
      for (final raw in rawPlayers.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final color = row['color']?.toString() ?? '';
        if (color.isNotEmpty) players[color] = row;
      }
    }

    version = math.max(version, nextVersion);
    myColor = data['player_color']?.toString();
    if (myColor?.isEmpty == true) myColor = null;
    ready = true;
    errorText = null;
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!widget.state.backendConnected) {
      if (!silent && mounted) {
        setState(() {
          ready = false;
          errorText = 'Room server is not connected.';
        });
      }
      return;
    }
    Map<String, dynamic>? value;
    try {
      value = await widget.state.backend.ludoState(
        roomId: widget.roomId,
        playerCount: widget.playerCount,
        colorPair: widget.colorPair,
      );
    } catch (_) {
      // Transient failure: treated like no data below; the 5s poll
      // retries instead of an unhandled error every tick.
      value = null;
    }
    if (!mounted) return;
    if (value?['ok'] == true) {
      setState(() => _apply(Map<String, dynamic>.from(value!)));
      return;
    }
    if (!silent) {
      setState(() {
        ready = false;
        errorText =
            value?['error']?.toString().replaceAll('_', ' ') ??
                'Could not load Ludo.';
      });
    }
  }

  Future<void> _act(
    Future<Map<String, dynamic>?> Function() action,
  ) async {
    if (busy || !ready) return;
    setState(() => busy = true);
    try {
      final value = await action();
      if (!mounted) return;
      if (value?['ok'] == true) {
        setState(() => _apply(Map<String, dynamic>.from(value!)));
        return;
      }
      final nested = value?['state'];
      if (nested is Map && nested['ok'] == true) {
        setState(() => _apply(Map<String, dynamic>.from(nested)));
      }
      final error = value?['error']?.toString().replaceAll('_', ' ') ??
          'Ludo action failed.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleVoice() async {
    if (busy || widget.onToggleMic == null) return;
    if (widget.hasMicSeat?.call() != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Take a room mic seat first, then you can speak in Ludo.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onToggleMic!.call();
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Color _color(LudoPlayer player) => switch (player) {
        LudoPlayer.red => const Color(0xFFE5484D),
        LudoPlayer.green => const Color(0xFF31B46C),
        LudoPlayer.yellow => const Color(0xFFF2C94C),
        LudoPlayer.blue => const Color(0xFF3C82F6),
      };

  /// My colour from the server (player_color). Null while loading or
  /// for spectators — they see the default layout.
  LudoPlayer? get _myPlayer {
    final name = myColor;
    if (name == null) return null;
    for (final player in LudoPlayer.values) {
      if (player.name == name) return player;
    }
    return null;
  }

  /// Quarter-turns that put my home bottom-left on my screen.
  int get _boardTurns => LudoGame.boardTurnsFor(_myPlayer);

  // Board corners in clockwise order: 0 top-left, 1 top-right,
  // 2 bottom-right, 3 bottom-left. Rotating the board by _boardTurns
  // moves every colour's corner forward by that many steps.
  static const Map<LudoPlayer, int> _cornerOf = {
    LudoPlayer.red: 0,
    LudoPlayer.green: 1,
    LudoPlayer.yellow: 2,
    LudoPlayer.blue: 3,
  };

  int _rotatedCorner(LudoPlayer player) =>
      (_cornerOf[player]! + _boardTurns) % 4;

  /// Colours keyed by the corner they land on after rotation, so the
  /// player chips sit on the same corners as their homes on the board.
  Map<int, LudoPlayer> get _corners => {
        for (final player in LudoPlayer.values)
          _rotatedCorner(player): player,
      };

  String _name(LudoPlayer player) =>
      players[player.name]?['display_name']?.toString() ?? 'Waiting';

  ImageProvider<Object>? _avatar(Map<String, dynamic>? row) {
    final key = row?['avatar_key']?.toString().trim() ?? '';
    if (key.isEmpty) return null;
    return NetworkImage(
      widget.state.backend.fileUrl(key),
      headers: widget.state.backend.fileHeaders,
    );
  }

  bool _voiceOn(Map<String, dynamic>? row, bool mine) {
    if (mine && widget.micOn != null) return widget.micOn!.call();
    if (row == null || row['seat_index'] == null) return false;
    final muted = row['mic_muted'];
    return muted == false || muted == 0 || muted?.toString() == '0';
  }

  Widget _player(LudoPlayer player) {
    // Colours that are not playing (2-player mode) sit grey and empty,
    // so the two active chips land on opposite corners — cross.
    if (!game.activePlayers.contains(player)) {
      return Expanded(
        child: Container(
          key: Key('ludo-player-${player.name}-empty'),
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Empty',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ),
      );
    }
    final row = players[player.name];
    final userId = row?['user_id']?.toString() ?? '';
    final mine = userId.isNotEmpty && userId == widget.state.userId;
    final voice = _voiceOn(row, mine);
    final turn = ready && game.currentPlayer == player && row != null;
    final seat = int.tryParse(row?['seat_index']?.toString() ?? '');

    return Expanded(
      child: Container(
        key: Key('ludo-player-${player.name}'),
        height: 58,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _color(player).withValues(alpha: .16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _color(player),
            width: turn ? 2.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _color(player),
                    foregroundImage: _avatar(row),
                    child: Icon(
                      row == null ? Icons.event_seat_rounded : Icons.person,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _name(player),
                    key: Key('ludo-name-${player.name}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  player.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: _color(player),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${game.tokens[player]!.where((token) => token.isFinished).length}/4',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 8,
                  ),
                ),
                if (seat != null)
                  Text(
                    'S${seat + 1}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 7,
                    ),
                  ),
              ],
            ),
            IconButton(
              key: Key('ludo-mic-${player.name}'),
              tooltip: mine
                  ? 'Toggle your room microphone'
                  : (voice ? 'Microphone on' : 'Microphone off'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 30,
                height: 32,
              ),
              onPressed: mine && !busy ? _toggleVoice : null,
              icon: Icon(
                voice ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: voice ? const Color(0xFF86EFC6) : Colors.white54,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = myColor == game.currentPlayer.name;
    final movable = game.movableTokenIndexes();
    final owner = widget.roomOwnerUserId == widget.state.userId;
    final spectator = myColor == null;
    // Player chips follow the rotated board corners, so "You" is
    // always on the bottom row with your colour bottom-left.
    final corners = _corners;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text(
          'Ludo',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          if (owner)
            IconButton(
              tooltip: 'Restart Ludo',
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
              onPressed: ready && !busy
                  ? () => _act(
                        () => widget.state.backend.ludoReset(
                          roomId: widget.roomId,
                        ),
                      )
                  : null,
            ),
          IconButton(
            tooltip: 'Refresh Ludo',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: busy ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, viewport) {
            final content = Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          errorText ??
                              (!ready
                                  ? 'Connecting…'
                                  : spectator
                                      ? 'Table full • watching as spectator'
                                      : game.winner != null
                                          ? '${_name(game.winner!)} won!'
                                          : '${_name(game.currentPlayer)} • ${game.status}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 31,
                        child: FilledButton(
                          key: const Key('ludo-roll-dice'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _color(game.currentPlayer),
                            foregroundColor:
                                game.currentPlayer == LudoPlayer.yellow
                                    ? Colors.black
                                    : Colors.white,
                            elevation: 4,
                            shadowColor: Colors.black54,
                          ),
                          onPressed: ready &&
                                  !busy &&
                                  mine &&
                                  game.rolled == null &&
                                  game.winner == null
                              ? () => _act(
                                    () => widget.state.backend.ludoRoll(
                                      roomId: widget.roomId,
                                    ),
                                  )
                              : null,
                          child: Text(
                            busy
                                ? '…'
                                : game.rolled == null
                                    ? 'ROLL'
                                    : 'Dice ${game.rolled}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _player(corners[0]!),
                    _player(corners[1]!),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math
                          .min(
                            constraints.maxWidth - 16,
                            constraints.maxHeight,
                          )
                          .clamp(0.0, double.infinity)
                          .toDouble();
                      return Center(
                        // 3D slab: dark edge under the cream board plus a
                        // drop shadow, matching the approved preview.
                        child: Container(
                          width: side,
                          height: side + 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B5433),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            // Whole board rotates so my home lands
                            // bottom-left on my screen. Geometry is
                            // untouched — only the widget turns.
                            child: RotatedBox(
                              quarterTurns: _boardTurns,
                              child: SizedBox(
                                width: side,
                                height: side,
                                child: CustomPaint(
                                  painter: _LudoBoardPainter(
                                    game: game,
                                    playerColor: _color,
                                  ),
                                  child: Stack(
                                    children: [
                                      for (final player in game.activePlayers)
                                        for (final token
                                            in game.tokens[player]!)
                                          _TokenButton(
                                            token: token,
                                            game: game,
                                            boardSize: side,
                                            color: _color(player),
                                            // Counter-turn keeps the
                                            // token number upright.
                                            uprightTurns:
                                                (4 - _boardTurns) % 4,
                                            enabled: ready &&
                                                !busy &&
                                                mine &&
                                                player ==
                                                    game.currentPlayer &&
                                                movable.contains(token.index),
                                            onTap: () => _act(
                                              () => widget.state.backend
                                                  .ludoMove(
                                                roomId: widget.roomId,
                                                tokenIndex: token.index,
                                              ),
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                if (mine && game.rolled != null && game.winner == null)
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        for (var index = 0; index < 4; index++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: OutlinedButton(
                                key: Key('ludo-move-token-$index'),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: !busy && movable.contains(index)
                                    ? () => _act(
                                          () => widget.state.backend.ludoMove(
                                            roomId: widget.roomId,
                                            tokenIndex: index,
                                          ),
                                        )
                                    : null,
                                child: Text(
                                  'Token ${index + 1}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    _player(corners[3]!),
                    _player(corners[2]!),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            );

            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: viewport.maxHeight < 300 ? 360 : viewport.maxHeight,
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.state.backendConnected) {
      unawaited(widget.state.backend.ludoLeave(roomId: widget.roomId));
    }
    super.dispose();
  }
}

class _TokenButton extends StatelessWidget {
  const _TokenButton({
    required this.token,
    required this.game,
    required this.boardSize,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.uprightTurns = 0,
  });

  final LudoToken token;
  final LudoGame game;
  final double boardSize;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  /// Quarter-turns that undo the board rotation, so the token number
  /// stays upright on screen while the token sits on its rotated spot.
  final int uprightTurns;

  @override
  Widget build(BuildContext context) {
    final position = _LudoGeometry.positionFor(token, game, boardSize);
    return Positioned(
      key: Key('ludo-token-${token.player.name}-${token.index}'),
      left: position.dx - boardSize / 30,
      top: position.dy - boardSize / 30,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: RotatedBox(
          quarterTurns: uprightTurns,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: boardSize / 15,
            height: boardSize / 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Glossy 3D token: light cap top-left, dark base bottom-right.
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 0.95,
                colors: [
                  Color.lerp(color, Colors.white, 0.55)!,
                  color,
                  Color.lerp(color, Colors.black, 0.30)!,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              border: Border.all(
                color: enabled ? Colors.white : Colors.black54,
                width: enabled ? 3 : 1.5,
              ),
              boxShadow: [
                const BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
                if (enabled)
                  BoxShadow(
                    color: color.withValues(alpha: .55),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${token.index + 1}',
              style: TextStyle(
                color: token.player == LudoPlayer.yellow
                    ? Colors.black
                    : Colors.white,
                fontSize: math.max(6.0, boardSize / 45),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LudoGeometry {
  static const double boardCells = 15;

  static List<Offset> track(double size) {
    final cell = size / boardCells;
    const cells = <Offset>[
      Offset(1, 6),
      Offset(2, 6),
      Offset(3, 6),
      Offset(4, 6),
      Offset(5, 6),
      Offset(6, 5),
      Offset(6, 4),
      Offset(6, 3),
      Offset(6, 2),
      Offset(6, 1),
      Offset(6, 0),
      Offset(7, 0),
      Offset(8, 0),
      Offset(8, 1),
      Offset(8, 2),
      Offset(8, 3),
      Offset(8, 4),
      Offset(8, 5),
      Offset(9, 6),
      Offset(10, 6),
      Offset(11, 6),
      Offset(12, 6),
      Offset(13, 6),
      Offset(14, 6),
      Offset(14, 7),
      Offset(14, 8),
      Offset(13, 8),
      Offset(12, 8),
      Offset(11, 8),
      Offset(10, 8),
      Offset(9, 8),
      Offset(8, 9),
      Offset(8, 10),
      Offset(8, 11),
      Offset(8, 12),
      Offset(8, 13),
      Offset(8, 14),
      Offset(7, 14),
      Offset(6, 14),
      Offset(6, 13),
      Offset(6, 12),
      Offset(6, 11),
      Offset(6, 10),
      Offset(6, 9),
      Offset(5, 8),
      Offset(4, 8),
      Offset(3, 8),
      Offset(2, 8),
      Offset(1, 8),
      Offset(0, 8),
      Offset(0, 7),
      Offset(0, 6),
    ];
    return cells
        .map((p) => Offset((p.dx + .5) * cell, (p.dy + .5) * cell))
        .toList();
  }

  static Offset positionFor(
    LudoToken token,
    LudoGame game,
    double size,
  ) {
    final cell = size / boardCells;

    if (token.isHome) {
      const homes = <LudoPlayer, List<Offset>>{
        LudoPlayer.red: [
          Offset(2.0, 2.0),
          Offset(4.0, 2.0),
          Offset(2.0, 4.0),
          Offset(4.0, 4.0),
        ],
        LudoPlayer.green: [
          Offset(10.5, 2.0),
          Offset(12.5, 2.0),
          Offset(10.5, 4.0),
          Offset(12.5, 4.0),
        ],
        LudoPlayer.yellow: [
          Offset(10.5, 10.5),
          Offset(12.5, 10.5),
          Offset(10.5, 12.5),
          Offset(12.5, 12.5),
        ],
        LudoPlayer.blue: [
          Offset(2.0, 10.5),
          Offset(4.0, 10.5),
          Offset(2.0, 12.5),
          Offset(4.0, 12.5),
        ],
      };
      final p = homes[token.player]![token.index];
      return Offset(p.dx * cell, p.dy * cell);
    }

    if (token.progress < 52) {
      return track(size)[game.sharedTrackIndex(token.player, token.progress)];
    }

    final step = (token.progress - 51).clamp(1, 6).toInt();
    final point = switch (token.player) {
      LudoPlayer.red => Offset(step.toDouble(), 7),
      LudoPlayer.green => Offset(7, step.toDouble()),
      LudoPlayer.yellow => Offset(14 - step.toDouble(), 7),
      LudoPlayer.blue => Offset(7, 14 - step.toDouble()),
    };
    return Offset((point.dx + .5) * cell, (point.dy + .5) * cell);
  }
}

class _LudoBoardPainter extends CustomPainter {
  _LudoBoardPainter({
    required this.game,
    required this.playerColor,
  });

  final LudoGame game;
  final Color Function(LudoPlayer) playerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final cell = side / _LudoGeometry.boardCells;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, side, side),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFFF4EAD2),
    );

    final homeRects = <LudoPlayer, Rect>{
      LudoPlayer.red: Rect.fromLTWH(0, 0, 6 * cell, 6 * cell),
      LudoPlayer.green: Rect.fromLTWH(9 * cell, 0, 6 * cell, 6 * cell),
      LudoPlayer.yellow:
          Rect.fromLTWH(9 * cell, 9 * cell, 6 * cell, 6 * cell),
      LudoPlayer.blue: Rect.fromLTWH(0, 9 * cell, 6 * cell, 6 * cell),
    };

    // Colours that are not playing (2-player mode) render grey and
    // empty, like the approved preview.
    for (final entry in homeRects.entries) {
      final active = game.activePlayers.contains(entry.key);
      canvas.drawRect(
        entry.value,
        Paint()
          ..color = active
              ? playerColor(entry.key).withValues(alpha: .78)
              : const Color(0xFF9A9A9A).withValues(alpha: .78),
      );
    }

    final pathPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFF8D846E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final point in _LudoGeometry.track(side)) {
      final rect = Rect.fromCenter(
        center: point,
        width: cell,
        height: cell,
      );
      canvas.drawRect(rect, pathPaint);
      canvas.drawRect(rect, border);
    }

    for (final index in const [0, 8, 13, 21, 26, 34, 39, 47]) {
      final point = _LudoGeometry.track(side)[index];
      final star = TextPainter(
        text: TextSpan(
          text: '★',
          style: TextStyle(
            color: const Color(0xFF80682C),
            fontSize: cell * .7,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      star.paint(
        canvas,
        point - Offset(star.width / 2, star.height / 2),
      );
    }

    for (final player in LudoPlayer.values) {
      final active = game.activePlayers.contains(player);
      final start =
          _LudoGeometry.track(side)[LudoGame.startOffsets[player]!];
      canvas.drawRect(
        Rect.fromCenter(center: start, width: cell, height: cell),
        Paint()
          ..color = active
              ? playerColor(player)
              : const Color(0xFFF4EAD2),
      );
      for (var step = 1; step <= 6; step++) {
        final point = _LudoGeometry.positionFor(
          LudoToken(
            player: player,
            index: 0,
            progress: 51 + step,
          ),
          game,
          side,
        );
        canvas.drawRect(
          Rect.fromCenter(center: point, width: cell, height: cell),
          Paint()
            ..color = active
                ? playerColor(player)
                : const Color(0xFFF4EAD2),
        );
        if (active) {
          canvas.drawRect(
            Rect.fromCenter(center: point, width: cell, height: cell),
            border,
          );
        }
      }
    }

    final middle = Offset(side / 2, side / 2);
    final corners = [
      Offset(6 * cell, 6 * cell),
      Offset(9 * cell, 6 * cell),
      Offset(9 * cell, 9 * cell),
      Offset(6 * cell, 9 * cell),
    ];
    final middleColors = [
      LudoPlayer.green,
      LudoPlayer.yellow,
      LudoPlayer.blue,
      LudoPlayer.red,
    ];
    for (var index = 0; index < 4; index++) {
      final triangle = Path()
        ..moveTo(middle.dx, middle.dy)
        ..lineTo(corners[index].dx, corners[index].dy)
        ..lineTo(
          corners[(index + 1) % 4].dx,
          corners[(index + 1) % 4].dy,
        )
        ..close();
      final trianglePlayer = middleColors[index];
      canvas.drawPath(
        triangle,
        Paint()
          ..color = game.activePlayers.contains(trianglePlayer)
              ? playerColor(trianglePlayer)
              : const Color(0xFF9A9A9A),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) => true;
}
