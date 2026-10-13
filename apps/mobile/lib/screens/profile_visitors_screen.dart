import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'vip_screen.dart';

class MineCharmVisitorsStrip extends StatefulWidget {
  const MineCharmVisitorsStrip({super.key, required this.state, required this.onOpenProfile});

  final AppState state;
  final ValueChanged<String> onOpenProfile;

  @override
  State<MineCharmVisitorsStrip> createState() => _MineCharmVisitorsStripState();
}

class _MineCharmVisitorsStripState extends State<MineCharmVisitorsStrip> {
  Map<String, dynamic>? overview;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.state.backend.mineOverview(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      overview = value;
      loading = false;
    });
  }

  String _format(Object? raw) {
    final value = int.tryParse(raw?.toString() ?? '') ?? 0;
    if (value < 1000) return value.toString();
    if (value < 1000000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final visitors = widget.state.hasVipPrivilege('view_visitors');
    return Row(
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Color(0xFFFF7CA8)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Charm', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text(loading ? '…' : _format(overview?['charm_points'])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProfileVisitorsScreen(state: widget.state, onOpenProfile: widget.onOpenProfile),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_rounded, color: Color(0xFFFFD36A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Visitors', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(visitors ? (loading ? '…' : _format(overview?['visitors_count'])) : 'VIP1 to view'),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileVisitorsScreen extends StatefulWidget {
  const ProfileVisitorsScreen({super.key, required this.state, required this.onOpenProfile});

  final AppState state;
  final ValueChanged<String> onOpenProfile;

  @override
  State<ProfileVisitorsScreen> createState() => _ProfileVisitorsScreenState();
}

class _ProfileVisitorsScreenState extends State<ProfileVisitorsScreen> {
  List<Map<String, dynamic>> visitors = const [];
  bool loading = true;
  String? error;

  bool get unlocked => widget.state.hasVipPrivilege('view_visitors');

  @override
  void initState() {
    super.initState();
    if (unlocked) _load();
    else loading = false;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.state.backend.profileVisitors(userId: widget.state.userId);
      if (!mounted) return;
      setState(() {
        visitors = result;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Visitors could not be loaded. Pull down to retry.';
        loading = false;
      });
    }
  }

  String _visitedLabel(Object? raw) {
    final count = int.tryParse(raw?.toString() ?? '') ?? 1;
    return 'Visited $count ${count == 1 ? 'time' : 'times'}';
  }

  String _initial(String name) {
    final value = name.trim();
    return value.isEmpty ? '?' : value.characters.first.toUpperCase();
  }

  String _visitedAtLabel(BuildContext context, Object? raw) {
    DateTime? date;
    if (raw is num) {
      date = DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
    } else {
      final value = raw?.toString();
      if (value != null && value.isNotEmpty) {
        final milliseconds = int.tryParse(value);
        date = milliseconds == null
            ? DateTime.tryParse(value)
            : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
      }
    }
    if (date == null) return 'Visit time unavailable';
    final local = date.toLocal();
    final day = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return 'Last visited $day • $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visitors')),
      body: !unlocked
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 40),
                    const SizedBox(height: 12),
                    const Text('Profile visitors unlock with active VIP1.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => VipScreen(state: widget.state)),
                      ),
                      child: const Text('View VIP'),
                    ),
                  ],
                ),
              ),
            )
          : loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 180),
                            Center(child: Text(error!)),
                          ],
                        )
                      : visitors.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 180),
                                Center(child: Text('No profile visitors yet')),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: visitors.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final visitor = visitors[index];
                                final userId = visitor['user_id']?.toString() ?? '';
                                final name = visitor['display_name']?.toString().trim().isNotEmpty == true
                                    ? visitor['display_name'].toString()
                                    : 'User';
                                final avatarKey = visitor['avatar_key']?.toString() ?? '';
                                final avatar = avatarKey.isEmpty
                                    ? null
                                    : NetworkImage(
                                        widget.state.backend.fileUrl(avatarKey),
                                        headers: widget.state.backend.fileHeaders,
                                      );
                                return Card(
                                  child: ListTile(
                                    leading: InkWell(
                                      onTap: userId.isEmpty ? null : () => widget.onOpenProfile(userId),
                                      customBorder: const CircleBorder(),
                                      child: CircleAvatar(
                                        backgroundImage: avatar,
                                        child: avatar == null ? Text(_initial(name)) : null,
                                      ),
                                    ),
                                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_visitedLabel(visitor['visit_count'])),
                                        Text(_visitedAtLabel(context, visitor['last_visited_at'])),
                                        Text('ID $userId'),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.person_outline_rounded),
                                  ),
                                );
                              },
                            ),
                ),
    );
  }
}
