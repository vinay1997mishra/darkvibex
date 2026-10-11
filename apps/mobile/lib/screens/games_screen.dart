import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'fruit_party_screen.dart';
import 'ludo_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Games',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        _GameCard(
          emoji: '🍒',
          title: 'Fruit Party',
          subtitle:
              '21s betting • 5s result • 5× / 10× / 15× / 25× / 45× • Lucky 11',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FruitPartyScreen(state: state),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _GameCard(
          emoji: '🎲',
          title: 'Ludo',
          subtitle: 'Playable 4-player board rules with captures and safe cells',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LudoScreen()),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Fruit Party Jackpot removed'),
            subtitle: Text(
              'The removed Jackpot game and Jackpot records are not included.',
            ),
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
