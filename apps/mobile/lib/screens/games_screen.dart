import 'package:flutter/material.dart';

import '../app/app_state.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  bool playing = false;
  String result = '🎮';
  int lastWin = 0;

  Future<void> play() async {
    if (playing) return;
    if (!widget.state.backendConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to the server before playing.')),
      );
      return;
    }

    setState(() => playing = true);
    try {
      const bet = 5000;
      final remote = await widget.state.backend.fruitPartyBet(
        userId: widget.state.userId,
        stake: bet,
      );
      if (remote == null || remote['ok'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The game server did not accept this bet. No coins were changed.')),
        );
        return;
      }

      const symbols = <String, String>{
        'apple': '🍎',
        'orange': '🍊',
        'watermelon': '🍉',
        'grape': '🍇',
        'kiwi': '🥝',
        'strawberry': '🍓',
        'cherry': '🍒',
        'lemon': '🍋',
      };
      final payout = int.tryParse(remote['payout']?.toString() ?? '') ?? 0;
      final balance = int.tryParse(remote['coin_balance']?.toString() ?? '');
      if (balance != null) widget.state.setCoinBalance(balance);
      if (!mounted) return;
      setState(() {
        result = symbols[remote['result']?.toString()] ?? '🎮';
        lastWin = payout;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the game server. No coins were changed.')),
      );
    } finally {
      if (mounted) setState(() => playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Games', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Text('FRUIT PARTY', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  Text(result, style: const TextStyle(fontSize: 72)),
                  const SizedBox(height: 12),
                  Text(lastWin > 0 ? 'Won $lastWin coins' : 'Bet 5,000 coins'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: playing ? null : play,
                    icon: playing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(playing ? 'Playing…' : 'Play'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Text('🎲', style: TextStyle(fontSize: 32)),
              title: const Text('Ludo'),
              subtitle: const Text('Board game module'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ludo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        SizedBox(height: 8),
                        Text('Ludo multiplayer is not connected in this build. No coins will be charged.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
