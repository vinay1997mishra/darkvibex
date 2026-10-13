import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'discover_rooms_screen.dart';
import 'games_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'room_screen.dart';

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
      _RoomsHome(
        state: widget.state,
        onSelect: (value) => setState(() => index = value),
      ),
      DiscoverRoomsScreen(state: widget.state),
      MessagesScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];

    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mic_rounded), label: 'Party'),
          NavigationDestination(icon: Icon(Icons.explore_rounded), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: 'Message'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Mine'),
        ],
      ),
    );
  }
}

class _RoomsHome extends StatefulWidget {
  const _RoomsHome({required this.state, required this.onSelect});

  final AppState state;
  final ValueChanged<int> onSelect;

  @override
  State<_RoomsHome> createState() => _RoomsHomeState();
}

class _RoomsHomeState extends State<_RoomsHome> {
  String section = 'Party';
  AppState get state => widget.state;

  Future<void> _openFourBoxMenu(BuildContext context) async {
    const entries = <(String, IconData, int)>[
      ('Party', Icons.mic_rounded, 0),
      ('Discover', Icons.explore_rounded, 1),
      ('Message', Icons.chat_bubble_rounded, 2),
      ('Mine', Icons.person_rounded, 3),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Quick menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.7,
                children: [
                  for (final entry in entries)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onSelect(entry.$3);
                      },
                      icon: Icon(entry.$2),
                      label: Text(entry.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
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
    if (name == null || !context.mounted) return;
    try {
      final created = await state.createRoom(name);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoomScreen(state: state, room: created)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room could not be created. Check your connection and try again.')),
      );
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      state.refreshRooms(),
      state.refreshPublicConfig(),
    ]);
  }

  List<RoomSummary> _visibleRooms() {
    final rooms = switch (section) {
      'Mine' => state.rooms.where((room) => room.ownerUserId == state.userId).toList(),
      'Country' => state.countryCode.trim().isEmpty
          ? <RoomSummary>[]
          : state.rooms.where((room) =>
              room.ownerCountryCode.toUpperCase() == state.countryCode.toUpperCase() &&
              room.online > 0).toList(),
      _ => state.rooms.where((room) => room.online > 0).toList(),
    };
    rooms.sort((a, b) => b.online.compareTo(a.online));
    return rooms;
  }

  List<Map<String, dynamic>> _visibleEvents() => state.publicAnnouncements.where((row) {
        final country = row['country']?.toString().trim() ?? '';
        return country.isEmpty ||
            country.toUpperCase() == 'ALL' ||
            country.toUpperCase() == state.countryCode.toUpperCase();
      }).toList();

  @override
  Widget build(BuildContext context) {
    final rooms = _visibleRooms();
    final events = _visibleEvents();
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Party', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => GamesScreen(state: state)),
                ),
                icon: const Icon(Icons.sports_esports_rounded),
                tooltip: 'Games',
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh rooms and events',
              ),
              IconButton(
                onPressed: () => _openFourBoxMenu(context),
                icon: const Icon(Icons.grid_view_rounded),
                tooltip: 'Four box menu',
              ),
              if (section != 'Events')
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
                  gradient: const LinearGradient(colors: [Color(0xFF17151D), Color(0xFF2A1F12)]),
                  border: Border.all(color: const Color(0x55FFD36A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LIVE VOICE ROOMS', style: TextStyle(fontSize: 12, letterSpacing: 2)),
                    SizedBox(height: 8),
                    Text('Talk. Play. Vibe.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text('Join a room or create your own space.'),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  for (final item in const ['Party', 'Mine', 'Events', 'Country'])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: section == item,
                        onSelected: (_) => setState(() => section = item),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (section == 'Events')
            if (events.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No active events or announcements.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.campaign_rounded)),
                        title: Text(event['title']?.toString() ?? 'Event'),
                        subtitle: Text(event['body']?.toString() ?? '', maxLines: 4, overflow: TextOverflow.ellipsis),
                      ),
                    );
                  },
                ),
              )
          else if (section == 'Country' && state.countryCode.trim().isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Set your country in Mine profile to see country rooms.')),
            )
          else if (rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(section == 'Mine' ? 'You have not created a room yet.' : 'No active rooms right now.'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, roomIndex) {
                  final room = rooms[roomIndex];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundImage: room.avatarKey == null
                            ? null
                            : NetworkImage(state.backend.fileUrl(room.avatarKey!), headers: state.backend.fileHeaders),
                        child: room.avatarKey == null
                            ? Text(room.name.isEmpty ? '?' : room.name.substring(0, 1).toUpperCase())
                            : null,
                      ),
                      title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('ID ${room.id} • ${room.online} online • ${room.seatCount} seats'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RoomScreen(state: state, room: room)),
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
