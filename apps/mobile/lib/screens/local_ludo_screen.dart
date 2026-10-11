import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../games/local_ludo_game.dart';

class LocalLudoScreen extends StatefulWidget {
  const LocalLudoScreen({super.key, required this.playerCount});
  final int playerCount;

  @override
  State<LocalLudoScreen> createState() => _LocalLudoScreenState();
}

class _LocalLudoScreenState extends State<LocalLudoScreen> {
  late final LocalLudoGame game =
      LocalLudoGame(playerCount: widget.playerCount);

  static const _colors = <LocalLudoPlayer, Color>{
    LocalLudoPlayer.red: Color(0xFFE5484D),
    LocalLudoPlayer.green: Color(0xFF31B46C),
    LocalLudoPlayer.yellow: Color(0xFFF2C94C),
    LocalLudoPlayer.blue: Color(0xFF3C82F6),
  };

  void _roll() {
    setState(() => game.roll());
  }

  void _move(int index) {
    setState(() => game.move(index));
  }

  String _label(LocalLudoPlayer player) =>
      player.name[0].toUpperCase() + player.name.substring(1);

  @override
  Widget build(BuildContext context) {
    final moves = game.movableIndexes;
    return Scaffold(
      appBar: AppBar(
        title: Text('Ludo • ${widget.playerCount} players'),
        actions: [
          IconButton(
            tooltip: 'Restart game',
            onPressed: () => setState(game.reset),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.money_off_csred_rounded),
                  SizedBox(width: 10),
                  Expanded(child: Text('Free local pass-and-play • no coins or wallet changes')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Pass the device after each turn. Roll a 6 to bring a token out of home.',
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _BoardPainter(game: game, colors: _colors),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final player in game.players)
                  _PlayerChip(
                    label: _label(player),
                    color: _colors[player]!,
                    active: player == game.currentPlayer && game.winner == null,
                    finished: game.tokens[player]!.where((token) => token.isFinished).length,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      game.status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (game.rolled != null)
                      Text('🎲  ${game.rolled}', style: const TextStyle(fontSize: 36)),
                    FilledButton.icon(
                      onPressed: game.rolled == null && game.winner == null ? _roll : null,
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('Roll dice'),
                    ),
                    if (game.rolled != null && game.winner == null) ...[
                      const SizedBox(height: 8),
                      Text('Choose a movable token', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          for (final index in moves)
                            OutlinedButton(
                              onPressed: () => _move(index),
                              child: Text('Token ${index + 1}'),
                            ),
                        ],
                      ),
                    ],
                    if (game.winner != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => setState(game.reset),
                        child: const Text('Play again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final player in game.players)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colors[player],
                    child: Text(_label(player)[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(_label(player)),
                  subtitle: Text(game.tokens[player]!.map((token) {
                    if (token.isFinished) return '✓';
                    if (token.isHome) return 'Home';
                    return token.progress < 52
                        ? 'Track ${token.progress + 1}/52'
                        : 'Lane ${token.progress - 51}/6';
                  }).join('  •  ')),
                  trailing: Text('${game.tokens[player]!.where((token) => token.isFinished).length}/4'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.label,
    required this.color,
    required this.active,
    required this.finished,
  });

  final String label;
  final Color color;
  final bool active;
  final int finished;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(backgroundColor: color, radius: 9),
    label: Text('$label • $finished/4'),
    side: BorderSide(color: color, width: active ? 2 : 1),
  );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter({required this.game, required this.colors});
  final LocalLudoGame game;
  final Map<LocalLudoPlayer, Color> colors;

  static const _cells = <Offset>[
    Offset(1,6),Offset(2,6),Offset(3,6),Offset(4,6),Offset(5,6),
    Offset(6,5),Offset(6,4),Offset(6,3),Offset(6,2),Offset(6,1),Offset(6,0),Offset(7,0),Offset(8,0),
    Offset(8,1),Offset(8,2),Offset(8,3),Offset(8,4),Offset(8,5),
    Offset(9,6),Offset(10,6),Offset(11,6),Offset(12,6),Offset(13,6),Offset(14,6),Offset(14,7),Offset(14,8),
    Offset(13,8),Offset(12,8),Offset(11,8),Offset(10,8),Offset(9,8),
    Offset(8,9),Offset(8,10),Offset(8,11),Offset(8,12),Offset(8,13),Offset(8,14),Offset(7,14),Offset(6,14),
    Offset(6,13),Offset(6,12),Offset(6,11),Offset(6,10),Offset(6,9),
    Offset(5,8),Offset(4,8),Offset(3,8),Offset(2,8),Offset(1,8),Offset(0,8),Offset(0,7),Offset(0,6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final cell = side / 15;
    final rect = Rect.fromLTWH(0.0, 0.0, side, side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()..color = const Color(0xFFF7F0DF),
    );

    final homes = <LocalLudoPlayer, Rect>{
      LocalLudoPlayer.red: Rect.fromLTWH(0.0, 0.0, 6 * cell, 6 * cell),
      LocalLudoPlayer.green: Rect.fromLTWH(9 * cell, 0, 6 * cell, 6 * cell),
      LocalLudoPlayer.yellow: Rect.fromLTWH(9 * cell, 9 * cell, 6 * cell, 6 * cell),
      LocalLudoPlayer.blue: Rect.fromLTWH(0, 9 * cell, 6 * cell, 6 * cell),
    };
    for (final entry in homes.entries) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(entry.value.deflate(cell * .18), Radius.circular(cell)),
        Paint()..color = colors[entry.key]!.withValues(alpha: .22),
      );
      final inner = entry.value.deflate(cell * 1.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cell * .45)),
        Paint()..color = Colors.white,
      );
    }
    final laneColors = <LocalLudoPlayer, List<Offset>>{
      LocalLudoPlayer.red: [for (var x = 1; x <= 6; x++) Offset(x, 7)],
      LocalLudoPlayer.green: [for (var y = 1; y <= 6; y++) Offset(7, y)],
      LocalLudoPlayer.yellow: [for (var x = 13; x >= 8; x--) Offset(x, 7)],
      LocalLudoPlayer.blue: [for (var y = 13; y >= 8; y--) Offset(7, y)],
    };

    final cellPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _cells.length; i++) {
      final point = _cells[i];
      cellPaint.color = (const {0,8,13,21,26,34,39,47}.contains(i))
          ? const Color(0xFFFFD36A)
          : Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(point.dx * cell + 1, point.dy * cell + 1, cell - 2, cell - 2),
          Radius.circular(cell * .12),
        ),
        cellPaint,
      );
    }
    for (final entry in laneColors.entries) {
      for (final point in entry.value) {
        canvas.drawRect(
          Rect.fromLTWH(point.dx * cell + 1, point.dy * cell + 1, cell - 2, cell - 2),
          Paint()..color = colors[entry.key]!.withValues(alpha: .34),
        );
      }
    }
    final center = Path()
      ..moveTo(6 * cell, 6 * cell)..lineTo(9 * cell, 6 * cell)
      ..lineTo(9 * cell, 9 * cell)..lineTo(6 * cell, 9 * cell)..close();
    canvas.drawPath(center, Paint()..color = const Color(0xFFDDD2BC));

    for (final player in game.players) {
      final list = game.tokens[player]!;
      for (var i = 0; i < list.length; i++) {
        final token = list[i];
        Offset point;
        if (token.isHome) {
          final home = homes[player]!;
          final slots = [
            Offset(2, 2), Offset(4, 2), Offset(2, 4), Offset(4, 4),
          ];
          final slot = slots[i];
          point = Offset((home.left / cell + slot.dx) * cell, (home.top / cell + slot.dy) * cell);
        } else if (token.progress < 52) {
          final index = (LocalLudoGame.offsets[player]! + token.progress) % 52;
          point = Offset((_cells[index].dx + .5) * cell, (_cells[index].dy + .5) * cell);
        } else {
          final lane = laneColors[player]!;
          point = Offset((lane[token.progress - 52].dx + .5) * cell, (lane[token.progress - 52].dy + .5) * cell);
        }
        final color = colors[player]!;
        canvas.drawCircle(point, cell * .28, Paint()..color = color);
        canvas.drawCircle(point, cell * .28, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, cell * .06));
        final text = TextPainter(
          text: TextSpan(text: '${i + 1}', style: TextStyle(
            color: player == LocalLudoPlayer.yellow ? Colors.black : Colors.white,
            fontSize: math.max(7, cell * .3), fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => true;
}
