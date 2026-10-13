import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'fruit_party_screen.dart';
import 'game_room_screen.dart';
import 'ludo_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({
    super.key,
    required this.state,
    this.roomId,
    this.roomOwnerUserId,
    this.onToggleMic,
    this.micOn,
    this.hasMicSeat,
  });

  final AppState state;
  final String? roomId;
  final String? roomOwnerUserId;
  final Future<void> Function()? onToggleMic;
  final bool Function()? micOn;
  final bool Function()? hasMicSeat;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  Future<void> _openLudo() async {
    final roomId = widget.roomId?.trim() ?? '';
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a voice room first to play online Ludo.'),
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LudoScreen(
          state: widget.state,
          roomId: roomId,
          roomOwnerUserId: widget.roomOwnerUserId,
          onToggleMic: widget.onToggleMic,
          micOn: widget.micOn,
          hasMicSeat: widget.hasMicSeat,
        ),
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
                  subtitle: const Text('Free 4-player online room game • room mic stays active'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openLudo,
                ),
              ),
            ],
          ),
        ),
      );
}
