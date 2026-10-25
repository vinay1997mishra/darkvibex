import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'conversation_screen.dart';
import 'direct_call_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.state,
    this.standalone = false,
  });

  final AppState state;
  final bool standalone;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool loadingFeeds = true;
  List<Map<String, dynamic>> official = const [];
  List<Map<String, dynamic>> activity = const [];
  Timer? callPollTimer;
  bool incomingCallOpen = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
    callPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        unawaited(_checkIncomingCall());
        unawaited(_refreshInbox());
      },
    );
    unawaited(_checkIncomingCall());
    unawaited(_refreshInbox());
  }

  @override
  void dispose() {
    callPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshInbox() async {
    if (!state.backendConnected || !state.isAuthenticated) return;
    await state.refreshInbox();
  }

  Future<void> _openConversation(DirectMessage item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          state: state,
          otherUserId: item.id,
          otherName: item.name,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshInbox();
  }

  Future<void> _checkIncomingCall() async {
    if (incomingCallOpen ||
        !state.backendConnected ||
        !state.isAuthenticated ||
        !mounted) {
      return;
    }
    final value = await state.backend.incomingDirectCall(
      userId: state.userId,
    );
    final raw = value?['call'];
    if (raw is! Map || !mounted) return;
    final call = Map<String, dynamic>.from(raw);
    final callId = call['id']?.toString() ?? '';
    if (callId.isEmpty || call['state']?.toString() != 'ringing') return;

    incomingCallOpen = true;
    final callerName =
        call['caller_name']?.toString().trim().isNotEmpty == true ? call['caller_name'].toString() : 'User';
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.call_rounded, color: TinniPalette.gold),
            SizedBox(width: 8),
            Text('Incoming call'),
          ],
        ),
        content: Text('$callerName is calling you.'),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.call_end_rounded),
            label: const Text('Refuse'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Accept'),
          ),
        ],
      ),
    );
    if (!mounted) {
      incomingCallOpen = false;
      return;
    }

    final response = await state.backend.respondDirectCall(
      userId: state.userId,
      callId: callId,
      accept: accept == true,
    );
    incomingCallOpen = false;
    if (accept != true || !mounted) return;

    final nextRaw = response?['call'];
    if (response?['ok'] != true || nextRaw is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call could not be answered')),
      );
      return;
    }
    final next = Map<String, dynamic>.from(nextRaw);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectCallScreen(
          state: state,
          callId: callId,
          peerName: callerName,
          initialState: next['state']?.toString() ?? 'active',
        ),
      ),
    );
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

  Widget _systemFeedPanel() => TinniPanel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [TinniPalette.gold, TinniPalette.brightGold],
                  ),
                  border: Border.all(
                    color: TinniPalette.brightGold.withValues(alpha: .72),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TinniPalette.gold.withValues(alpha: .22),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 25,
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
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B52C9), Color(0xFF218EBE)],
                  ),
                  border: Border.all(
                    color: TinniPalette.brightGold.withValues(alpha: .52),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x303E8BFF), blurRadius: 12),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 22,
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
      );

  Widget _conversationTile(DirectMessage item) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TinniPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
            key: Key('message-thread-${item.id}'),
            leading: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [TinniPalette.gold, TinniPalette.brightGold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: TinniPalette.gold.withValues(alpha: .2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: TinniPalette.panel2,
                backgroundImage: item.avatarKey == null
                    ? null
                    : NetworkImage(
                        state.backend.fileUrl(item.avatarKey!),
                        headers: state.backend.fileHeaders,
                      ),
                child: item.avatarKey == null
                    ? Text(
                        item.name.isEmpty ? '?' : item.name.substring(0, 1),
                        style: const TextStyle(
                          color: TinniPalette.cream,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: item.unread > 0 ? FontWeight.w900 : FontWeight.w700,
                color: item.unread > 0 ? TinniPalette.cream : null,
              ),
            ),
            subtitle: Text(
              item.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: item.unread > 0 ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            trailing: item.unread > 0
                ? Badge(
                    label: Text(
                      item.unread > 99 ? '99+' : item.unread.toString(),
                    ),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: () => _openConversation(item),
          ),
        ),
      );

  Widget _messageList({required bool standalone}) {
    final conversations = List<DirectMessage>.of(state.messages)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return TinniBackground(
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>([
            state.refreshInbox(),
            _loadFeeds(),
          ]);
        },
        child: ListView(
          key: Key(standalone
              ? 'room-standalone-message-list'
              : 'embedded-message-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            if (!standalone) ...[
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
            ],
            if (standalone) ...[
              const Text(
                'Chats',
                key: Key('room-inbox-chats-title'),
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (conversations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(color: TinniPalette.muted),
                    ),
                  ),
                ),
              for (final item in conversations) _conversationTile(item),
              const SizedBox(height: 4),
              _systemFeedPanel(),
            ] else ...[
              _systemFeedPanel(),
              const SizedBox(height: 12),
              if (conversations.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(color: TinniPalette.muted),
                    ),
                  ),
                ),
              for (final item in conversations) _conversationTile(item),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.standalone) {
      return AnimatedBuilder(
        animation: state,
        builder: (context, _) => _messageList(standalone: false),
      );
    }

    return Scaffold(
      key: const Key('room-standalone-messages'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: TinniPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) => _messageList(standalone: true),
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
        backgroundColor: Colors.transparent,
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
