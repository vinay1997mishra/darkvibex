import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'room_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key, required this.state});

  final AppState state;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final controller = TextEditingController();
  List<Map<String, dynamic>> users = const [];
  List<Map<String, dynamic>> rooms = const [];
  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final query = controller.text.trim();
    if (query.isEmpty) return;
    setState(() => loading = true);
    final value = await widget.state.backend.search(userId: widget.state.userId, query: query);
    if (!mounted) return;
    final rawUsers = value?['users'];
    final rawRooms = value?['rooms'];
    setState(() {
      users = rawUsers is List
          ? rawUsers
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : const [];
      rooms = rawRooms is List
          ? rawRooms
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : const [];
      loading = false;
    });
  }

  void openRoom(Map<String, dynamic> row) {
    final room = RoomSummary(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Room',
      ownerName: row['owner_name']?.toString() ?? '',
      ownerUserId: row['owner_user_id']?.toString() ?? '',
      online: int.tryParse(row['online']?.toString() ?? '') ?? 0,
      seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ?? 12,
    );
    if (room.id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(state: widget.state, room: room),
      ),
    );
  }

  void showUser(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final name = row['display_name']?.toString() ?? 'User';
    final vip = int.tryParse(row['vip_level']?.toString() ?? '') ?? 0;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('ID $id • VIP $vip'),
              const SizedBox(height: 14),
              const Text(
                'Use this ID for direct messages, CP and Enemy relationship progress.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: 'User ID, name, room ID or room name',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: loading ? null : search,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (users.isNotEmpty) ...[
              const Text(
                'Users',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              for (final row in users)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_rounded),
                    ),
                    title: Text(
                      row['display_name']?.toString() ?? 'User',
                    ),
                    subtitle: Text(
                      'ID ${row['id']} • VIP ${row['vip_level'] ?? 0}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showUser(row),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (rooms.isNotEmpty) ...[
              const Text(
                'Rooms',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              for (final row in rooms)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.mic_rounded),
                    ),
                    title: Text(row['name']?.toString() ?? 'Room'),
                    subtitle: Text('ID ${row['id']}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openRoom(row),
                  ),
                ),
            ],
            if (users.isEmpty &&
                rooms.isEmpty &&
                controller.text.trim().isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text('No matching result found.')),
              ),
          ],
        ],
      ),
    );
  }
}
