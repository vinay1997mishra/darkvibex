import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_state.dart';
import '../utils/public_user_id.dart';

class AladdinLampScreen extends StatefulWidget {
  const AladdinLampScreen({
    super.key,
    required this.state,
    required this.room,
  });

  final AppState state;
  final RoomSummary room;

  @override
  State<AladdinLampScreen> createState() => _AladdinLampScreenState();
}

class _AladdinLampScreenState extends State<AladdinLampScreen> {
  bool loading = true;
  bool isHost = false;
  bool refreshingStatus = false;
  int bonusPercent = 5;
  int? resetAt;
  String? error;
  String? claimingTaskId;
  Timer? progressRefreshTimer;
  List<_LampTask> tasks = const <_LampTask>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    progressRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_load()),
    );
  }

  @override
  void dispose() {
    progressRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (refreshingStatus) return;
    refreshingStatus = true;
    if (!widget.state.backendConnected) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Connect to the DarkVibeX server to use Aladdin\'s Lamp.';
      });
      refreshingStatus = false;
      return;
    }
    final value = await widget.state.backend.aladdinLampStatus(
      roomId: widget.room.id,
      userId: widget.state.userId,
    );
    if (!mounted) return;
    if (value == null) {
      setState(() {
        loading = false;
        error = 'Aladdin\'s Lamp is unavailable right now.';
      });
      refreshingStatus = false;
      return;
    }
    final raw = value['tasks'];
    final next = raw is List
        ? raw
            .whereType<Map>()
            .map((row) => _LampTask.fromJson(Map<String, dynamic>.from(row)))
            .toList()
        : <_LampTask>[];
    setState(() {
      loading = false;
      error = null;
      isHost = value['is_host'] == true;
      bonusPercent =
          int.tryParse(value['bonus_percent']?.toString() ?? '') ?? 5;
      resetAt = int.tryParse(value['reset_at']?.toString() ?? '');
      tasks = next;
    });
    refreshingStatus = false;
  }

  Future<void> _claim(_LampTask task) async {
    if (!isHost || claimingTaskId != null || task.claimed || !task.completed) {
      return;
    }
    setState(() => claimingTaskId = task.id);
    final value = await widget.state.backend.claimAladdinLampTask(
      roomId: widget.room.id,
      userId: widget.state.userId,
      taskId: task.id,
    );
    if (!mounted) return;
    setState(() => claimingTaskId = null);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reward could not be claimed')),
      );
      return;
    }
    final balance =
        int.tryParse(value['coin_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    final payout =
        int.tryParse(value['payout_coins']?.toString() ?? '') ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🪙 ' +
              _formatCoins(payout) +
              ' coins received with ' +
              bonusPercent.toString() +
              '% lamp bonus',
        ),
      ),
    );
    await _load();
  }

  Future<void> _goFinish(_LampTask task) async {
    if (!isHost) return;
    switch (task.action) {
      case 'invite_mic':
        await _showInviteSheet();
        return;
      case 'share_whatsapp':
        await _shareRoom('whatsapp');
        return;
      case 'share_facebook':
        await _shareRoom('facebook');
        return;
      case 'share_room':
        await _showShareChoices();
        return;
      case 'host_gift':
      case 'room_activity':
      case 'mic_time':
      case 'host_mic':
        if (mounted) Navigator.pop(context);
        return;
      default:
        if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showInviteSheet() async {
    final members =
        await widget.state.backend.roomMembers(roomId: widget.room.id);
    if (!mounted) return;
    final candidates = members
        .where((m) => m['user_id']?.toString() != widget.state.userId)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audience member is available to invite yet'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const Text(
              'Invite to mic',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final member in candidates)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_rounded),
                ),
                title: Text(
                  (member['display_name']?.toString().trim().isNotEmpty ??
                          false)
                      ? member['display_name'].toString()
                      : 'User',
                ),
                subtitle: Text(
                  member['seat_index'] == null
                      ? 'Audience'
                      : 'Already on a seat',
                ),
                trailing: FilledButton(
                  onPressed: member['seat_index'] != null
                      ? null
                      : () async {
                          final ok =
                              await widget.state.backend.inviteAladdinMic(
                            roomId: widget.room.id,
                            hostUserId: widget.state.userId,
                            inviteeUserId:
                                member['user_id']?.toString() ?? '',
                          );
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Mic invitation sent'
                                    : 'Mic invitation failed',
                              ),
                            ),
                          );
                        },
                  child: const Text('Invite'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showShareChoices() async {
    final platform = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Share room',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, 'whatsapp'),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.pop(sheetContext, 'facebook'),
                icon: const Icon(Icons.public_rounded),
                label: const Text('Facebook'),
              ),
            ],
          ),
        ),
      ),
    );
    if (platform != null) await _shareRoom(platform);
  }

  Future<void> _shareRoom(String platform) async {
    final text = 'Join my DarkVibeX room "' +
        widget.room.name +
        '" • Room ID ' +
        formatPublicUserId(widget.room.roomNumber);

    var shared = false;
    if (platform == 'whatsapp') {
      final uri = Uri.https(
        'wa.me',
        '/',
        <String, String>{'text': text},
      );
      shared = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await SharePlus.instance.share(ShareParams(text: text));
      shared = true;
    }

    if (!shared) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open ' +
                (platform == 'facebook' ? 'Facebook' : 'WhatsApp'),
          ),
        ),
      );
      return;
    }

    await widget.state.backend.recordAladdinShare(
      roomId: widget.room.id,
      userId: widget.state.userId,
      platform: platform,
    );
    await _load();
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aladdin\'s Lamp'),
        content: Text(
          'Room daily tasks reset at 00:00 UTC. Complete tasks as the room host, '
          'then claim the displayed reward. Every claimed task also receives a ' +
              bonusPercent.toString() +
              '% lamp bonus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _resetText() {
    final value = resetAt;
    if (value == null) {
      return 'UTC+0 (0:00AM - 0:00AM the next day)';
    }
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      value,
      isUtc: true,
    ).difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 'Resetting now • UTC+0';
    return 'UTC+0 • resets in ' +
        remaining.inHours.toString() +
        'h ' +
        remaining.inMinutes.remainder(60).toString() +
        'm';
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFF8B7CFF);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0x6632106F),
              Color(0x80681DE1),
              Color(0x665012C6),
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Aladdin\'s Lamp',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: gold,
                              fontSize: 31,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _showHelp,
                          icon: const Icon(
                            Icons.help_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Column(
                      children: [
                        Container(
                          height: 155,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: gold.withOpacity(.72),
                              width: 1.4,
                            ),
                            gradient: const RadialGradient(
                              colors: <Color>[
                                Color(0xFFB45CFF),
                                Color(0xFF4D168C),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: gold.withOpacity(.28),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const CustomPaint(
                            painter: _MagicLampPainter(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Aladdin\'s magic lamp can help hosts get ' +
                              bonusPercent.toString() +
                              '% bonus from rewarded coins',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.25,
                          ),
                        ),
                        if (!isHost && !loading) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Only the room host can complete and claim these rewards.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFE798),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B27E9),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: gold, width: 1.5),
                          ),
                          child: const Text(
                            'Room Daily Tasks',
                            style: TextStyle(
                              color: gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _resetText(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                if (loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: gold),
                    ),
                  )
                else if (error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final task = tasks[index];
                          return _LampTaskCard(
                            task: task,
                            isHost: isHost,
                            claiming: claimingTaskId == task.id,
                            onClaim: () => _claim(task),
                            onGoFinish: () => _goFinish(task),
                          );
                        },
                        childCount: tasks.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LampTask {
  const _LampTask({
    required this.id,
    required this.title,
    required this.rewardCoins,
    required this.target,
    required this.progress,
    required this.action,
    required this.icon,
    required this.completed,
    required this.claimed,
  });

  factory _LampTask.fromJson(Map<String, dynamic> json) => _LampTask(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        rewardCoins:
            int.tryParse(json['reward_coins']?.toString() ?? '') ?? 0,
        target: int.tryParse(json['target']?.toString() ?? '') ?? 1,
        progress: int.tryParse(json['progress']?.toString() ?? '') ?? 0,
        action: json['action']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'gift',
        completed: json['completed'] == true,
        claimed: json['claimed'] == true,
      );

  final String id;
  final String title;
  final int rewardCoins;
  final int target;
  final int progress;
  final String action;
  final String icon;
  final bool completed;
  final bool claimed;
}

class _LampTaskCard extends StatelessWidget {
  const _LampTaskCard({
    required this.task,
    required this.isHost,
    required this.claiming,
    required this.onClaim,
    required this.onGoFinish,
  });

  final _LampTask task;
  final bool isHost;
  final bool claiming;
  final VoidCallback onClaim;
  final VoidCallback onGoFinish;

  IconData get taskIcon {
    if (task.icon == 'mic') return Icons.mic_rounded;
    if (task.icon == 'people') return Icons.people_alt_rounded;
    if (task.icon == 'share') return Icons.share_rounded;
    return Icons.card_giftcard_rounded;
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFF50D8FF);
    final showGoFinish =
        isHost && !task.completed && !task.claimed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF6E22DF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
            child: Icon(taskIcon, color: gold, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '🪙 Coins+' + _formatCoins(task.rewardCoins),
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (task.claimed)
            const _ProgressPill(text: 'Claimed', enabled: false)
          else if (task.completed && isHost)
            _ProgressPill(
              text: claiming ? '…' : 'Claim',
              enabled: !claiming,
              onTap: onClaim,
            )
          else if (showGoFinish && isHost)
            _ProgressPill(
              text: 'Go finish',
              enabled: true,
              onTap: onGoFinish,
            )
          else
            _ProgressPill(
              text:
                  task.progress.toString() + '/' + task.target.toString(),
              enabled: false,
            ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.text,
    required this.enabled,
    this.onTap,
  });

  final String text;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(minWidth: 86),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: enabled
              ? const LinearGradient(
                  colors: <Color>[
                    Color(0xFFB77CFF),
                    Color(0xFF8D32F3),
                  ],
                )
              : const LinearGradient(
                  colors: <Color>[
                    Color(0xFFF8F5F0),
                    Color(0xFFD7D3CF),
                  ],
                ),
          border: Border.all(
            color:
                enabled ? Colors.white70 : const Color(0xFFFFE172),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color:
                enabled ? Colors.white : const Color(0xFF6712D0),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MagicLampPainter extends CustomPainter {
  const _MagicLampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .49, size.height * .59);
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[
          Color(0xFFFFF39A),
          Color(0x00FFD94A),
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: size.shortestSide * .48,
        ),
      );
    canvas.drawCircle(center, size.shortestSide * .48, glow);

    final gold = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFFFFF09B),
          Color(0xFF8B7CFF),
          Color(0xFFDA8D00),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    final outline = Paint()
      ..color = const Color(0xFFFFF1A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final body = Path()
      ..moveTo(size.width * .28, size.height * .51)
      ..quadraticBezierTo(
        size.width * .37,
        size.height * .37,
        size.width * .55,
        size.height * .43,
      )
      ..quadraticBezierTo(
        size.width * .67,
        size.height * .46,
        size.width * .69,
        size.height * .57,
      )
      ..quadraticBezierTo(
        size.width * .66,
        size.height * .76,
        size.width * .42,
        size.height * .76,
      )
      ..quadraticBezierTo(
        size.width * .29,
        size.height * .72,
        size.width * .28,
        size.height * .51,
      )
      ..close();
    canvas.drawPath(body, gold);
    canvas.drawPath(body, outline);

    final spout = Path()
      ..moveTo(size.width * .31, size.height * .53)
      ..quadraticBezierTo(
        size.width * .14,
        size.height * .47,
        size.width * .08,
        size.height * .35,
      )
      ..quadraticBezierTo(
        size.width * .20,
        size.height * .38,
        size.width * .38,
        size.height * .48,
      )
      ..close();
    canvas.drawPath(spout, gold);
    canvas.drawPath(spout, outline);

    final handle = Rect.fromCenter(
      center: Offset(size.width * .72, size.height * .55),
      width: size.width * .24,
      height: size.height * .31,
    );
    final thickOutline = Paint()
      ..color = const Color(0xFFFFF1A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawArc(handle, -1.2, 2.5, false, thickOutline);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .49, size.height * .43),
        width: size.width * .31,
        height: 16,
      ),
      gold,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .49, size.height * .77),
        width: size.width * .34,
        height: 12,
      ),
      gold,
    );
    for (var i = 0; i < 5; i++) {
      final x = size.width * (.24 + i * .12);
      final y = size.height * (.26 + (i.isEven ? .02 : 0));
      canvas.drawCircle(
        Offset(x, y),
        3.2,
        Paint()..color = const Color(0xFFFFF8C9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatCoins(int value) {
  final text = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return (value < 0 ? '-' : '') + buffer.toString();
}
