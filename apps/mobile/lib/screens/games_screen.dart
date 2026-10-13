import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'fruit_party_screen.dart';
import 'game_room_screen.dart';
import 'local_ludo_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  Future<void> _openLudo() async {
    final count = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Free Ludo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Choose players. No coins or wallet balance are used.'),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('2 players'),
                subtitle: const Text('Local pass-and-play'),
                onTap: () => Navigator.pop(sheetContext, 2),
              ),
              ListTile(
                leading: const Icon(Icons.groups_2_outlined),
                title: const Text('4 players'),
                subtitle: const Text('Local pass-and-play'),
                onTap: () => Navigator.pop(sheetContext, 4),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || count == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LocalLudoScreen(playerCount: count),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => TinniBackground(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Games',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  key: const Key('open-fruit-party'),
                  leading: const Text('🍒', style: TextStyle(fontSize: 34)),
                  title: const Text(
                    'FRUIT PARTY',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    '21s rounds • 6 bet amounts • Lucky 11 • last 7 results',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => FruitPartyScreen(state: widget.state),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.groups_2_rounded,
                    size: 32,
                    color: Color(0xFFFFD36A),
                  ),
                  title: const Text('Shared Game Room'),
                  subtitle: const Text(
                    'Create or join a public room · 15 seats · play together',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GameRoomLobbyScreen(state: widget.state),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Text('🎲', style: TextStyle(fontSize: 32)),
                  title: const Text('Ludo'),
                  subtitle: const Text('Free 2-player or 4-player local game'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openLudo,
                ),
              ),
            ],
          ),
        ),
      );
}
