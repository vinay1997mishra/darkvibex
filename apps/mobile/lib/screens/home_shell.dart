import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'games_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'room_screen.dart';
import 'wallet_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _RoomsHome(state: widget.state),
      MessagesScreen(state: widget.state),
      GamesScreen(state: widget.state),
      WalletScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mic_rounded), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.sports_esports_rounded), label: 'Games'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Mine'),
        ],
      ),
    );
  }
}

class _RoomsHome extends StatelessWidget {
  const _RoomsHome({required this.state});

  final AppState state;

  Future<void> _createRoom(BuildContext context) async {
    final controller = TextEditingController();
    final created = await showDialog<RoomSummary>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Room name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              state.createRoom(controller.text),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (created == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomScreen(state: state, room: created)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text(
              'DarkVibeX',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                onPressed: () => _createRoom(context),
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: 'Create room',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17151D), Color(0xFF2A1F12)],
                  ),
                  border: Border.all(color: const Color(0x55FFD36A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LIVE VOICE ROOMS', style: TextStyle(fontSize: 12, letterSpacing: 2)),
                    SizedBox(height: 8),
                    Text(
                      'Talk. Play. Vibe.',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6),
                    Text('Join a room or create your own space.'),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: state.rooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, roomIndex) {
                final room = state.rooms[roomIndex];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      radius: 26,
                      child: Text(room.name.isEmpty ? '?' : room.name.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('ID ${room.id} • ${room.online} online • ${room.seatCount} seats'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomScreen(state: state, room: room),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
