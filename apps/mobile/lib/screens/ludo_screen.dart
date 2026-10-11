import 'package:flutter/material.dart';

import '../games/ludo_game.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  final game = LudoGame();

  Color color(LudoPlayer player) => switch (player) {
        LudoPlayer.red => Colors.redAccent,
        LudoPlayer.green => Colors.greenAccent,
        LudoPlayer.yellow => Colors.amberAccent,
        LudoPlayer.blue => Colors.blueAccent,
      };

  @override
  Widget build(BuildContext context) {
    final movable = game.movableTokenIndexes();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo'),
        actions: [
          IconButton(onPressed: () => setState(game.reset), icon: const Icon(Icons.restart_alt_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(game.status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Text(game.rolled?.toString() ?? '🎲', style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: game.rolled == null && game.winner == null ? () => setState(game.roll) : null,
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Roll dice'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final player in LudoPlayer.values)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(backgroundColor: color(player), radius: 8),
                      const SizedBox(width: 8),
                      Text(player.name.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: color(player))),
                      if (game.currentPlayer == player) const Padding(padding: EdgeInsets.only(left: 8), child: Chip(label: Text('TURN'))),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < game.tokens[player]!.length; i++)
                          FilledButton.tonal(
                            onPressed: game.currentPlayer == player && movable.contains(i)
                                ? () => setState(() => game.move(i))
                                : null,
                            child: Text(game.tokens[player]![i].isHome
                                ? 'Token ${i + 1} • Home'
                                : game.tokens[player]![i].isFinished
                                    ? 'Token ${i + 1} • Finish'
                                    : 'Token ${i + 1} • ${game.tokens[player]![i].progress}'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
