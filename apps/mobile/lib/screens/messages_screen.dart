import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'conversation_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool loadingFeeds = true;
  List<Map<String, dynamic>> official = const [];
  List<Map<String, dynamic>> activity = const [];

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    final values = await Future.wait<List<Map<String, dynamic>>>([
      state.backend.officialMessages(),
      state.backend.activityMessages(userId: state.userId),
    ]);
    if (!mounted) return;
    setState(() {
      official = values[0];
      activity = values[1];
      loadingFeeds = false;
    });
  }

  String _preview(List<Map<String, dynamic>> rows, String fallback) {
    if (rows.isEmpty) return fallback;
    final row = rows.first;
    return row['body']?.toString() ??
        row['title']?.toString() ??
        fallback;
  }

  Future<void> _openOfficial() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SystemFeedScreen(
          title: 'DarkVibeX Official',
          icon: Icons.verified_rounded,
          rows: official,
          emptyText: 'No official notices yet',
        ),
      ),
    );
  }

  Future<void> _openActivity() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SystemFeedScreen(
          title: 'Activity',
          icon: Icons.notifications_active_rounded,
          rows: activity,
          emptyText: 'No activity yet',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => TinniBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait<void>([
              state.refreshInbox(),
              _loadFeeds(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TinniGlowIcon(
                    icon: Icons.mail_rounded,
                    size: 19,
                    boxSize: 36,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TinniPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: TinniPalette.gold,
                        child: Icon(
                          Icons.verified_rounded,
                          color: Colors.black,
                        ),
                      ),
                      title: const Text(
                        'DarkVibeX Official',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        loadingFeeds
                            ? 'Loading…'
                            : _preview(
                                official,
                                'Official notices and app information',
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: loadingFeeds ? null : _openOfficial,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF321C0A),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: TinniPalette.gold,
                        ),
                      ),
                      title: const Text(
                        'Activity',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        loadingFeeds
                            ? 'Loading…'
                            : _preview(
                                activity,
                                'Gifts, visitors and wallet activity',
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: activity.isNotEmpty
                          ? Badge(label: Text(activity.length.clamp(1, 99).toString()))
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: loadingFeeds ? null : _openActivity,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(color: TinniPalette.muted),
                    ),
                  ),
                ),
              for (final item in state.messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: TinniPanel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: TinniPalette.panel2,
                        backgroundImage: item.avatarKey == null
                            ? null
                            : NetworkImage(
                                state.backend.fileUrl(item.avatarKey!),
                                headers: state.backend.fileHeaders,
                              ),
                        child: item.avatarKey == null
                            ? Text(
                                item.name.isEmpty
                                    ? '?'
                                    : item.name.substring(0, 1),
                              )
                            : null,
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        item.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: item.unread > 0
                          ? Badge(label: Text(item.unread.toString()))
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ConversationScreen(
                            state: state,
                            otherUserId: item.id,
                            otherName: item.name,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemFeedScreen extends StatelessWidget {
  const _SystemFeedScreen({
    required this.title,
    required this.icon,
    required this.rows,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> rows;
  final String emptyText;

  String _date(dynamic raw) {
    final value = int.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 1) return '';
    final millis = value < 100000000000 ? value * 1000 : value;
    final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: Text(title)),
        body: TinniBackground(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    emptyText,
                    style: const TextStyle(color: TinniPalette.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final date = _date(row['created_at']);
                    return TinniPanel(
                      child: ListTile(
                        leading: TinniGlowIcon(
                          icon: icon,
                          size: 17,
                          boxSize: 34,
                        ),
                        title: Text(
                          row['title']?.toString() ??
                              row['kind']?.toString() ??
                              title,
                          style: const TextStyle(
                            color: TinniPalette.cream,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          [
                            row['body']?.toString() ?? '',
                            if (date.isNotEmpty) date,
                          ].where((value) => value.isNotEmpty).join('\n'),
                        ),
                        isThreeLine: date.isNotEmpty,
                      ),
                    );
                  },
                ),
        ),
      );
}
