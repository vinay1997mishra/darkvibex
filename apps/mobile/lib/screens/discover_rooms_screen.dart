import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'room_screen.dart';

class DiscoverRoomsScreen extends StatefulWidget {
  const DiscoverRoomsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<DiscoverRoomsScreen> createState() => _DiscoverRoomsScreenState();
}

class _DiscoverRoomsScreenState extends State<DiscoverRoomsScreen> {
  final TextEditingController _search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final needle = query.trim().toLowerCase();
        final rooms = widget.state.rooms
            .where((room) =>
                needle.isEmpty ||
                room.name.toLowerCase().contains(needle) ||
                room.id.toLowerCase().contains(needle))
            .toList()
          ..sort((a, b) => b.online.compareTo(a.online));

        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              title: Text('Discover', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search room name or ID',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
            if (rooms.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No rooms match this search.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundImage: room.avatarKey == null
                              ? null
                              : NetworkImage(
                                  widget.state.backend.fileUrl(room.avatarKey!),
                                  headers: widget.state.backend.fileHeaders,
                                ),
                          child: room.avatarKey == null
                              ? Text(room.name.isEmpty ? '?' : room.name.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('ID ${room.id} • ${room.online} online • ${room.seatCount} seats'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RoomScreen(state: widget.state, room: room),
                          ),
                        ),
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
