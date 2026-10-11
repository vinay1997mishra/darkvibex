import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'games_screen.dart';
import 'global_search_screen.dart';
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

class _RoomsHome extends StatefulWidget {
  const _RoomsHome({required this.state});

  final AppState state;

  @override
  State<_RoomsHome> createState() => _RoomsHomeState();
}

class _RoomsHomeState extends State<_RoomsHome> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
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
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    final created = await widget.state.createRoom(name);
    if (!mounted) return;
    _openRoom(created);
  }

  void _openRoom(RoomSummary room) {
    widget.state.markRoomVisited(room.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(state: widget.state, room: room),
      ),
    );
  }

  List<RoomSummary> _recent() {
    final byId = {for (final room in widget.state.rooms) room.id: room};
    return widget.state.recentRoomIds
        .map((id) => byId[id])
        .whereType<RoomSummary>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final q = search.text.trim().toLowerCase();
        final rooms = widget.state.rooms.where((room) {
          if (q.isEmpty) return true;
          return room.id.toLowerCase().contains(q) ||
              room.name.toLowerCase().contains(q) ||
              room.ownerName.toLowerCase().contains(q);
        }).toList();
        final recent = _recent();

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text(
                'DarkVibeX',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GlobalSearchScreen(state: widget.state),
                    ),
                  ),
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Global search',
                ),
                IconButton(
                  onPressed: _createRoom,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Create room',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    Container(
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
                          Text(
                            'LIVE VOICE ROOMS',
                            style: TextStyle(fontSize: 12, letterSpacing: 2),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Talk. Play. Vibe.',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text('Join a room or create your own space.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search room name or ID',
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (q.isEmpty && recent.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 86,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recent.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 9),
                          itemBuilder: (context, index) {
                            final room = recent[index];
                            return InkWell(
                              onTap: () => _openRoom(room),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 150,
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.white.withValues(alpha: .05),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'ID ${room.id}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFFFD36A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: rooms.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No matching room found.')),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: rooms.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, roomIndex) {
                        final room = rooms[roomIndex];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              radius: 26,
                              child: Text(
                                room.name.isEmpty
                                    ? '?'
                                    : room.name
                                        .substring(0, 1)
                                        .toUpperCase(),
                              ),
                            ),
                            title: Text(
                              room.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              'ID ${room.id} • ${room.online} online • ${room.seatCount} seats',
                            ),
                            trailing:
                                const Icon(Icons.chevron_right_rounded),
                            onTap: () => _openRoom(room),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
