// Room gift ranking page (Vinay, 2026-11-21): opened by touching the
// total gifting amount beside the trophy (rocket page) or the Ranking /
// total chips in the room. Shows THIS room only — who sent how many
// coins here, Day / Week / Month, top 99. The data rides the room's
// 3s combined state poll (roomStateOrNull with ?period=), no separate
// ranking API. A day with no sending shows nobody. The month's top
// gifter gets a gold spotlight at the top (their ID shows for the
// month) when the Monthly tab is open.
import 'dart:async';

import 'package:flutter/material.dart';

import '../infra/backend_api.dart';
import '../ui/tinni_style.dart';
import '../utils/public_user_id.dart';

class RoomGiftRankingScreen extends StatefulWidget {
  const RoomGiftRankingScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.backend,
    this.initialPeriod = 'day',
  });

  final String roomId;
  final String roomName;
  final BackendApi backend;
  final String initialPeriod;

  @override
  State<RoomGiftRankingScreen> createState() => _RoomGiftRankingScreenState();
}

class _RoomGiftRankingScreenState extends State<RoomGiftRankingScreen> {
  static const _periods = <String>['day', 'week', 'month'];

  late String _period;
  bool _loading = false;
  int _lifetimeTotal = 0;
  List<Map<String, dynamic>> _rows = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _period = _periods.contains(widget.initialPeriod)
        ? widget.initialPeriod
        : 'day';
    _load();
    // Same 3s combined poll as the room screen, gated on the app being
    // in the foreground so background users cost nothing.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        return;
      }
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    final state = await widget.backend.roomStateOrNull(
      roomId: widget.roomId,
      period: _period,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (state == null) return;
      final total = state['gift_lifetime_total'];
      if (total is num) _lifetimeTotal = total.toInt();
      final rows = state['gift_ranking'];
      _rows = rows is List
          ? rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : const [];
    });
  }

  String _periodLabel(String value) => switch (value) {
        'week' => 'Weekly',
        'month' => 'Monthly',
        _ => 'Daily',
      };

  String _emptyLabel(String value) => switch (value) {
        'week' => 'No gifts sent this week',
        'month' => 'No gifts sent this month',
        _ => 'No gifts sent today',
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

  Widget _avatar(String avatarKey, {double radius = 22}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: TinniPalette.panel2,
      backgroundImage: avatarKey.isEmpty
          ? null
          : NetworkImage(
              widget.backend.fileUrl(avatarKey),
              headers: widget.backend.fileHeaders,
            ),
      child: avatarKey.isEmpty
          ? const Icon(Icons.person_rounded)
          : null,
    );
  }

  Widget _monthTopBanner(Map<String, dynamic> top) {
    final name = top['display_name']?.toString() ?? 'User';
    final publicId = top['public_id']?.toString() ?? '';
    final avatarKey = top['avatar_key']?.toString() ?? '';
    final sent =
        int.tryParse(top['sent_coins']?.toString() ?? '') ?? 0;
    return Container(
      key: const Key('room-ranking-month-top'),
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xE60A0804),
        border: Border.all(color: TinniPalette.gold, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _avatar(avatarKey, radius: 28),
              const Positioned(
                right: -4,
                top: -8,
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: TinniPalette.gold,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TinniPalette.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'ID ${formatPublicUserId(publicId)}',
                  style: const TextStyle(
                    color: TinniPalette.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Top Gifter of the Month',
                  style: TextStyle(
                    color: TinniPalette.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _compact(sent),
                style: const TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Text(
                'Sending',
                style: TextStyle(
                  color: TinniPalette.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthTop = _period == 'month' && _rows.isNotEmpty ? _rows.first : null;
    return Scaffold(
      backgroundColor: Colors.transparent,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TinniPalette.cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 15,
                    color: TinniPalette.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _compact(_lifetimeTotal),
                    key: const Key('room-ranking-lifetime-total'),
                    style: const TextStyle(
                      color: TinniPalette.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final value in _periods)
                    Expanded(
                      child: InkWell(
                        key: Key('room-ranking-period-$value'),
                        onTap: () {
                          if (_period == value) return;
                          setState(() {
                            _period = value;
                            _rows = const [];
                          });
                          unawaited(_load());
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
            if (monthTop != null) _monthTopBanner(monthTop),
            Expanded(
              child: _loading && _rows.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? Center(child: Text(_emptyLabel(_period)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                            itemCount: _rows.length,
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              final avatar =
                                  row['avatar_key']?.toString() ?? '';
                              final title =
                                  row['display_name']?.toString() ?? 'User';
                              final publicId =
                                  row['public_id']?.toString() ?? '';
                              final sent = int.tryParse(
                                    row['sent_coins']?.toString() ?? '',
                                  ) ??
                                  0;
                              return Card(
                                color: const Color(0xE60A0804),
                                child: ListTile(
                                  key: Key('room-ranking-row-$index'),
                                  leading: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _avatar(avatar),
                                      Positioned(
                                        right: -5,
                                        top: -5,
                                        child: CircleAvatar(
                                          radius: 10,
                                          backgroundColor: index < 3
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
                                    'ID ${formatPublicUserId(publicId)}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _compact(sent),
                                        style: const TextStyle(
                                          color: TinniPalette.gold,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Text(
                                        'Sending',
                                        style: TextStyle(
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
