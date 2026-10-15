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
    this.roomOwnerUserId,
    this.onToggleMic,
    this.micOn,
    this.hasMicSeat,
  });

  final AppState state;
  final String roomId;
  final String? roomOwnerUserId;
  final Future<void> Function()? onToggleMic;
  final bool Function()? micOn;
  final bool Function()? hasMicSeat;

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with WidgetsBindingObserver {
  final LudoGame game = LudoGame();
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
    final value = await widget.state.backend.ludoState(roomId: widget.roomId);
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
                    _player(LudoPlayer.red),
                    _player(LudoPlayer.green),
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
                                for (final player in LudoPlayer.values)
                                  for (final token in game.tokens[player]!)
                                    _TokenButton(
                                      token: token,
                                      game: game,
                                      boardSize: side,
                                      color: _color(player),
                                      enabled: ready &&
                                          !busy &&
                                          mine &&
                                          player == game.currentPlayer &&
                                          movable.contains(token.index),
                                      onTap: () => _act(
                                        () => widget.state.backend.ludoMove(
                                          roomId: widget.roomId,
                                          tokenIndex: token.index,
                                        ),
                                      ),
                                    ),
                              ],
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
                    _player(LudoPlayer.blue),
                    _player(LudoPlayer.yellow),
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
  });

  final LudoToken token;
  final LudoGame game;
  final double boardSize;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final position = _LudoGeometry.positionFor(token, game, boardSize);
    return Positioned(
      key: Key('ludo-token-${token.player.name}-${token.index}'),
      left: position.dx - boardSize / 30,
      top: position.dy - boardSize / 30,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: boardSize / 15,
          height: boardSize / 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: enabled ? Colors.white : Colors.black54,
              width: enabled ? 3 : 1.5,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: .55),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
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

    for (final entry in homeRects.entries) {
      canvas.drawRect(
        entry.value,
        Paint()..color = playerColor(entry.key).withValues(alpha: .78),
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
      final start =
          _LudoGeometry.track(side)[LudoGame.startOffsets[player]!];
      canvas.drawRect(
        Rect.fromCenter(center: start, width: cell, height: cell),
        Paint()..color = playerColor(player),
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
          Paint()..color = playerColor(player),
        );
        canvas.drawRect(
          Rect.fromCenter(center: point, width: cell, height: cell),
          border,
        );
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
      canvas.drawPath(
        triangle,
        Paint()..color = playerColor(middleColors[index]),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) => true;
}
