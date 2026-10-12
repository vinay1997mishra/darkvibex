import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';

class GameRoomLobbyScreen extends StatefulWidget {
  const GameRoomLobbyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<GameRoomLobbyScreen> createState() => _GameRoomLobbyScreenState();
}

class _GameRoomLobbyScreenState extends State<GameRoomLobbyScreen> {
  List<Map<String, dynamic>> rooms = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final result = await widget.state.backend.gameRooms(userId: widget.state.userId);
    if (!mounted) return;
    setState(() { rooms = result; loading = false; });
  }

  Future<void> _create() async {
    final input = TextEditingController(text: '${widget.state.displayName} Party Room');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create shared game room'),
        content: TextField(controller: input, maxLength: 48, decoration: const InputDecoration(labelText: 'Room name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    input.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final result = await widget.state.backend.createGameRoom(userId: widget.state.userId, name: name);
    final id = result?['room_id']?.toString();
    if (id == null || id.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create game room')));
      return;
    }
    await _open(id, join: false);
  }

  Future<void> _open(String roomId, {bool join = true}) async {
    if (join) {
      final joined = await widget.state.backend.joinGameRoom(roomId: roomId, userId: widget.state.userId);
      if (joined?['ok'] != true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room is full or unavailable')));
        await _refresh();
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push<void>(context, MaterialPageRoute<void>(
      builder: (_) => SharedGameRoomScreen(state: widget.state, roomId: roomId),
    ));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shared Game Rooms'), actions: [
      IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('Create room'),
    ),
    body: loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _refresh,
          child: rooms.isEmpty
            ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No public game rooms yet. Create one to start.'))])
            : ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: ListTile(
                      leading: const CircleAvatar(child: Text('🎮')),
                      title: Text(room['name']?.toString() ?? 'Game room'),
                      subtitle: Text('${room['owner_name'] ?? 'Player'} • ${room['member_count'] ?? 0}/15 seats • Shared score ${room['shared_score'] ?? 0}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(room['id'].toString()),
                    ),
                  );
                },
              ),
        ),
  );
}

class SharedGameRoomScreen extends StatefulWidget {
  const SharedGameRoomScreen({super.key, required this.state, required this.roomId});
  final AppState state;
  final String roomId;

  @override
  State<SharedGameRoomScreen> createState() => _SharedGameRoomScreenState();
}

class _SharedGameRoomScreenState extends State<SharedGameRoomScreen> {
  Map<String, dynamic>? data;
  Timer? timer;
  bool tapping = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final result = await widget.state.backend.gameRoom(roomId: widget.roomId, userId: widget.state.userId);
    if (mounted && result?['ok'] == true) setState(() => data = result);
  }

  Future<void> _tapTogether() async {
    if (tapping) return;
    setState(() => tapping = true);
    final result = await widget.state.backend.tapGameRoom(roomId: widget.roomId, userId: widget.state.userId);
    if (mounted) {
      if (result?['ok'] == true) {
        await _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join this room before playing')));
      }
      setState(() => tapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = data?['room'] is Map ? Map<String, dynamic>.from(data!['room'] as Map) : <String, dynamic>{};
    final members = data?['members'] is List
        ? (data!['members'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    final score = int.tryParse(room['shared_score']?.toString() ?? '') ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(room['name']?.toString() ?? 'Game Room')),
      body: data == null
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('PARTY TAP', style: TextStyle(fontSize: 14, letterSpacing: 3, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 18),
                        Text('$score', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Color(0xFFFFD36A))),
                        const Text('Shared room score'),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: tapping ? null : _tapTogether,
                          style: FilledButton.styleFrom(minimumSize: const Size(180, 100), shape: const CircleBorder()),
                          child: tapping
                            ? const CircularProgressIndicator()
                            : const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app_rounded, size: 36), Text('TAP TOGETHER')]),
                        ),
                        const SizedBox(height: 14),
                        Text('${members.length}/15 players • everyone in this room shares the score', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 68,
                decoration: const BoxDecoration(
                  color: Color(0x22111122),
                  border: Border(left: BorderSide(color: Colors.white12)),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: 15,
                  itemBuilder: (context, index) {
                    final seatMembers = members.where((row) => int.tryParse(row['seat_index']?.toString() ?? '') == index).toList();
                    final player = seatMembers.isEmpty ? null : seatMembers.first;
                    final name = player?['display_name']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Tooltip(
                        message: player == null ? 'Seat ${index + 1} available' : name,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: player == null ? Colors.white10 : const Color(0xFF60417F),
                          child: Text(player == null ? '${index + 1}' : (name.isEmpty ? 'U' : name[0].toUpperCase()), style: const TextStyle(fontSize: 11)),
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
