import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'profile_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    required this.state,
    this.initialTab = 1,
  });

  final AppState state;
  final int initialTab;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const _tabs = <String>['Room', 'Send gifts', 'Charm', 'Game'];
  static const _kinds = <String>['room', 'send', 'charm', 'game'];
  static const _periods = <String>['day', 'week', 'month'];

  late int _tab;
  String _period = 'day';
  bool _loading = false;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, _tabs.length - 1);
    _load();
  }

  Future<void> _load() async {
    if (_loading || !widget.state.backendConnected) {
      if (!widget.state.backendConnected && mounted) {
        setState(() => _rows = const []);
      }
      return;
    }
    setState(() => _loading = true);
    final rows = await widget.state.backend.globalRanking(
      kind: _kinds[_tab],
      period: _period,
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  String _periodLabel(String value) => switch (value) {
        'week' => 'Weekly',
        'month' => 'Monthly list',
        _ => 'Daily',
      };

  String _compact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Future<void> _openRow(Map<String, dynamic> row) async {
    if (_kinds[_tab] == 'room') {
      final roomId = row['room_id']?.toString() ?? '';
      if (roomId.isEmpty) return;
      final room = RoomSummary(
        id: roomId,
        name: row['room_name']?.toString() ?? 'Room',
        ownerName: row['owner_name']?.toString() ?? 'Owner',
        ownerUserId: row['owner_user_id']?.toString() ?? '',
        online: int.tryParse(row['online']?.toString() ?? '') ?? 0,
        seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ?? 12,
        avatarKey: row['avatar_key']?.toString().trim().isNotEmpty == true
            ? row['avatar_key']?.toString()
            : null,
      );
      Navigator.of(context).pop(room);
      return;
    }
    final userId = row['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          state: widget.state,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: const Text('Ranking'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TinniBackground(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final selected = _tab == index;
                  return ChoiceChip(
                    key: Key('ranking-tab-${_kinds[index]}'),
                    label: Text(_tabs[index]),
                    selected: selected,
                    onSelected: (_) {
                      if (_tab == index) return;
                      setState(() {
                        _tab = index;
                        _rows = const [];
                      });
                      _load();
                    },
                  );
                },
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final value in _periods)
                    Expanded(
                      child: InkWell(
                        key: Key('ranking-period-$value'),
                        onTap: () {
                          if (_period == value) return;
                          setState(() {
                            _period = value;
                            _rows = const [];
                          });
                          _load();
                        },
                        child: Center(
                          child: Text(
                            _periodLabel(value),
                            style: TextStyle(
                              color: _period == value
                                  ? TinniPalette.gold
                                  : TinniPalette.muted,
                              fontWeight: _period == value
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: TinniPalette.bronze),
            Expanded(
              child: _loading && _rows.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? Center(
                          child: Text(
                            widget.state.backendConnected
                                ? 'No ranking data yet'
                                : 'Connect to the server to load ranking',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                            itemCount: _rows.length,
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              final room = _kinds[_tab] == 'room';
                              final avatar =
                                  row['avatar_key']?.toString() ?? '';
                              final title = room
                                  ? row['room_name']?.toString() ?? 'Room'
                                  : row['display_name']?.toString() ?? 'User';
                              final id = room
                                  ? row['room_id']?.toString() ?? ''
                                  : row['user_id']?.toString() ?? '';
                              final score = int.tryParse(
                                    row['score']?.toString() ?? '',
                                  ) ??
                                  0;
                              return Card(
                                color: const Color(0xE60A0804),
                                child: ListTile(
                                  key: Key('ranking-row-$index'),
                                  onTap: () => _openRow(row),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: TinniPalette.panel2,
                                        backgroundImage: avatar.isEmpty
                                            ? null
                                            : NetworkImage(
                                                widget.state.backend
                                                    .fileUrl(avatar),
                                                headers: widget.state.backend
                                                    .fileHeaders,
                                              ),
                                        child: avatar.isEmpty
                                            ? Icon(
                                                room
                                                    ? Icons.mic_external_on_rounded
                                                    : Icons.person_rounded,
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        right: -5,
                                        top: -5,
                                        child: CircleAvatar(
                                          radius: 10,
                                          backgroundColor:
                                              index < 3
                                                  ? TinniPalette.gold
                                                  : TinniPalette.panel2,
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: index < 3
                                                  ? Colors.black
                                                  : TinniPalette.cream,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    room
                                        ? 'ID $id • ${row['online'] ?? 0} online'
                                        : 'ID $id',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _compact(score),
                                        style: const TextStyle(
                                          color: TinniPalette.gold,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        switch (_kinds[_tab]) {
                                          'room' => 'Room points',
                                          'charm' => 'Charm points',
                                          'game' => 'Game points',
                                          _ => 'Sending',
                                        },
                                        style: const TextStyle(
                                          color: TinniPalette.muted,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
