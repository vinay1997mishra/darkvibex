import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const fruits = <String>['🍎', '🍊', '🍉', '🍇', '🥝', '🍓', '🍒', '🍋'];
  final random = Random();
  String result = '🎮';
  int lastWin = 0;

  Future<void> play() async {
    const bet = 5000;

    if (widget.state.backendConnected) {
      final remote = await widget.state.backend.fruitPartyBet(
        userId: widget.state.userId,
        stake: bet,
      );
      if (remote != null) {
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
        return;
      }
    }

    if (!widget.state.spendCoins(bet)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }

    final fruit = fruits[random.nextInt(fruits.length)];
    final won = random.nextInt(100) < 28;
    final reward = won ? bet * 5 : 0;
    if (reward > 0) widget.state.addCoins(reward);
    if (!mounted) return;
    setState(() {
      result = fruit;
      lastWin = reward;
    });
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
                    onPressed: play,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
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
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
