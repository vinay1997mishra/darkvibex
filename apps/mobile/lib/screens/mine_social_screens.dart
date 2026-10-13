import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

class WealthLevelScreen extends StatefulWidget {
  const WealthLevelScreen({super.key, required this.state});
  final AppState state;

  @override
  State<WealthLevelScreen> createState() => _WealthLevelScreenState();
}

class _WealthLevelScreenState extends State<WealthLevelScreen> {
  bool loading = true;
  Map<String, dynamic> stats = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.state.backend.socialStats(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      stats = value?['stats'] is Map
          ? Map<String, dynamic>.from(value!['stats'] as Map)
          : const {};
      loading = false;
    });
  }

  String _compact(int value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final wealth = stats['wealth'] is Map
        ? Map<String, dynamic>.from(stats['wealth'] as Map)
        : const <String, dynamic>{};
    final level = int.tryParse(wealth['level']?.toString() ?? '') ?? 0;
    final sent = int.tryParse(stats['lifetime_sent_coins']?.toString() ?? '') ?? 0;
    final next = int.tryParse(wealth['next_threshold']?.toString() ?? '');

    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(title: const Text('Wealth level')),
      body: TinniBackground(
        child: RefreshIndicator(
          onRefresh: _load,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  children: [
                    TinniPanel(
                      child: Row(
                        children: [
                          const TinniGlowIcon(
                            icon: Icons.diamond_rounded,
                            size: 30,
                            boxSize: 58,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LV.$level',
                                  style: const TextStyle(
                                    color: TinniPalette.gold,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'Lifetime sending: ${_compact(sent)} coins',
                                  style: const TextStyle(
                                    color: TinniPalette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TinniPanel(
                      child: ListTile(
                        title: const Text('Next level'),
                        subtitle: Text(
                          next == null
                              ? 'Highest configured level reached'
                              : '${_compact(next)} lifetime sending coins required',
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

class MedalOfHonorScreen extends StatefulWidget {
  const MedalOfHonorScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MedalOfHonorScreen> createState() => _MedalOfHonorScreenState();
}

class _MedalOfHonorScreenState extends State<MedalOfHonorScreen> {
  bool loading = true;
  List<Map<String, dynamic>> medals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await widget.state.backend.medals(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      medals = values;
      loading = false;
    });
  }

  Color _color(String? value) {
    final hex = (value ?? '').replaceFirst('#', '');
    final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return parsed == null ? TinniPalette.gold : Color(parsed);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Medal of Honor')),
        body: TinniBackground(
          child: RefreshIndicator(
            onRefresh: _load,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (medals.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                              'No medals yet',
                              style: TextStyle(color: TinniPalette.muted),
                            ),
                          ),
                        ),
                      for (final medal in medals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TinniPanel(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _color(medal['color']?.toString()),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                medal['name']?.toString() ?? 'Medal',
                                style: const TextStyle(
                                  color: TinniPalette.cream,
                                  fontWeight: FontWeight.w800,
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

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key, required this.state});
  final AppState state;

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool loading = true;
  String? claiming;
  List<Map<String, dynamic>> tasks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await widget.state.backend.mineTasks(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      tasks = values;
      loading = false;
    });
  }

  Future<void> _claim(Map<String, dynamic> task) async {
    if (claiming != null) return;
    final id = task['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => claiming = id);
    final result = await widget.state.backend.claimMineTask(
      userId: widget.state.userId,
      taskId: id,
    );
    if (!mounted) return;
    final balance = int.tryParse(result?['coin_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    final rows = result?['tasks'];
    setState(() {
      if (rows is List) {
        tasks = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      claiming = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?['ok'] == true
              ? 'Task reward claimed'
              : (result?['error']?.toString() ?? 'Task reward could not be claimed'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Task')),
        body: TinniBackground(
          child: RefreshIndicator(
            onRefresh: _load,
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final task in tasks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TinniPanel(
                            child: ListTile(
                              leading: TinniGlowIcon(
                                icon: task['completed'] == true
                                    ? Icons.task_alt_rounded
                                    : Icons.bolt_rounded,
                                size: 18,
                                boxSize: 36,
                              ),
                              title: Text(
                                task['title']?.toString() ?? 'Task',
                                style: const TextStyle(
                                  color: TinniPalette.cream,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                'Reward: ${task['reward_coins'] ?? 0} coins',
                              ),
                              trailing: task['claimed'] == true
                                  ? const Text(
                                      'Claimed',
                                      style: TextStyle(
                                        color: TinniPalette.gold,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed: task['completed'] == true &&
                                              claiming == null
                                          ? () => _claim(task)
                                          : null,
                                      child: Text(
                                        claiming == task['id']
                                            ? '…'
                                            : 'Claim',
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

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final controller = TextEditingController();
  String category = 'General';
  bool sending = false;
  bool loading = true;
  List<Map<String, dynamic>> history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await widget.state.backend.feedbackHistory(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() {
      history = values;
      loading = false;
    });
  }

  Future<void> _submit() async {
    final message = controller.text.trim();
    if (message.length < 3 || sending) return;
    setState(() => sending = true);
    final ok = await widget.state.backend.submitFeedback(
      userId: widget.state.userId,
      category: category,
      message: message,
    );
    if (!mounted) return;
    if (ok) {
      controller.clear();
      await _load();
    }
    if (!mounted) return;
    setState(() => sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Feedback submitted' : 'Feedback could not be submitted')),
    );
  }

  String _date(dynamic raw) {
    final ms = int.tryParse(raw?.toString() ?? '');
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Feedback')),
        body: TinniBackground(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'General', child: Text('General')),
                  DropdownMenuItem(value: 'Bug', child: Text('Bug')),
                  DropdownMenuItem(value: 'Account', child: Text('Account')),
                  DropdownMenuItem(value: 'Room', child: Text('Room')),
                  DropdownMenuItem(value: 'Payment', child: Text('Payment')),
                  DropdownMenuItem(value: 'Safety', child: Text('Safety')),
                ],
                onChanged: sending
                    ? null
                    : (value) => setState(() => category = value ?? 'General'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Tell us what happened',
                  alignLabelWithHint: true,
                ),
              ),
              FilledButton.icon(
                onPressed: sending ? null : _submit,
                icon: const Icon(Icons.send_rounded),
                label: Text(sending ? 'Submitting…' : 'Submit'),
              ),
              const SizedBox(height: 18),
              const Text(
                'My feedback',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (loading) const LinearProgressIndicator(),
              for (final row in history)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TinniPanel(
                    child: ListTile(
                      title: Text(row['category']?.toString() ?? 'General'),
                      subtitle: Text(
                        '${row['message'] ?? ''}\n${_date(row['created_at'])}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        row['status']?.toString() ?? 'submitted',
                        style: const TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool loading = true;
  Map<String, dynamic>? family;
  List<Map<String, dynamic>> members = const [];
  List<Map<String, dynamic>> requests = const [];
  List<Map<String, dynamic>> available = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.state.backend.familyState(
      userId: widget.state.userId,
    );
    final rawFamily = value?['family'];
    final rawMembers = value?['members'];
    final rawRequests = value?['join_requests'];
    final rawAvailable = value?['available_families'];
    if (!mounted) return;
    setState(() {
      family = rawFamily is Map ? Map<String, dynamic>.from(rawFamily) : null;
      members = rawMembers is List
          ? rawMembers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [];
      requests = rawRequests is List
          ? rawRequests.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [];
      available = rawAvailable is List
          ? rawAvailable.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [];
      loading = false;
    });
    if (family == null && available.isEmpty) {
      final list = await widget.state.backend.familyList();
      if (mounted) setState(() => available = list);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final tag = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Family name')),
            const SizedBox(height: 8),
            TextField(controller: tag, maxLength: 12, decoration: const InputDecoration(labelText: 'Family tag')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              (name.text.trim(), tag.text.trim()),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    tag.dispose();
    if (result == null || result.$1.length < 2 || result.$2.length < 2) return;
    final value = await widget.state.backend.createFamily(
      userId: widget.state.userId,
      name: result.$1,
      tag: result.$2,
    );
    if (!mounted) return;
    if (value?['ok'] == true) await _load();
  }

  Future<void> _join(String familyId) async {
    final ok = await widget.state.backend.requestFamilyJoin(
      userId: widget.state.userId,
      familyId: familyId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Join request sent' : 'Could not send request')),
    );
  }

  Future<void> _notice() async {
    final controller = TextEditingController(text: family?['notice']?.toString() ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Family notice'),
        content: TextField(controller: controller, maxLength: 300, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    if (await widget.state.backend.updateFamilyNotice(userId: widget.state.userId, notice: text)) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Family')),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: family == null ? _noFamily() : _familyHome(),
                ),
        ),
      );

  Widget _noFamily() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          TinniPanel(
            onTap: _create,
            child: const Row(
              children: [
                TinniGlowIcon(icon: Icons.add_home_work_rounded, size: 26, boxSize: 50),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create Family',
                    style: TextStyle(
                      color: TinniPalette.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: TinniPalette.gold),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Family Ranking',
            style: TextStyle(
              color: TinniPalette.gold,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < available.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TinniPanel(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: TinniPalette.panel2,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(available[index]['name']?.toString() ?? 'Family'),
                  subtitle: Text(
                    '${available[index]['tag'] ?? ''} • ${available[index]['member_count'] ?? 0} members',
                  ),
                  trailing: FilledButton(
                    onPressed: () => _join(available[index]['id'].toString()),
                    child: const Text('Join'),
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _familyHome() {
    final role = family?['my_role']?.toString() ?? 'member';
    final canManage = role == 'leader' || role == 'admin';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(14),
      children: [
        TinniPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                family?['name']?.toString() ?? 'Family',
                style: const TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${family?['tag'] ?? ''} • LV.${family?['level'] ?? 1} • ${members.length} members',
                style: const TextStyle(color: TinniPalette.muted),
              ),
              const SizedBox(height: 9),
              Text(family?['notice']?.toString() ?? ''),
              if (canManage)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _notice,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit notice'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        FilledButton.icon(
          onPressed: () async {
            final value = await widget.state.backend.familyCheckIn(userId: widget.state.userId);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  value?['already_checked_in'] == true
                      ? 'Already checked in today'
                      : '+${value?['exp_awarded'] ?? 0} Family EXP',
                ),
              ),
            );
            await _load();
          },
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Daily check-in'),
        ),
        if (requests.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Join requests',
            style: TextStyle(color: TinniPalette.gold, fontWeight: FontWeight.w900),
          ),
          for (final row in requests)
            ListTile(
              title: Text(row['display_name']?.toString() ?? row['user_id'].toString()),
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () async {
                      await widget.state.backend.resolveFamilyJoin(
                        userId: widget.state.userId,
                        targetUserId: row['user_id'].toString(),
                        approve: true,
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.check_rounded),
                  ),
                  IconButton(
                    onPressed: () async {
                      await widget.state.backend.resolveFamilyJoin(
                        userId: widget.state.userId,
                        targetUserId: row['user_id'].toString(),
                        approve: false,
                      );
                      await _load();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 14),
        const Text(
          'Members',
          style: TextStyle(color: TinniPalette.gold, fontWeight: FontWeight.w900),
        ),
        for (final member in members)
          TinniPanel(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: member['avatar_key']?.toString().isNotEmpty == true
                    ? NetworkImage(
                        widget.state.backend.fileUrl(member['avatar_key'].toString()),
                        headers: widget.state.backend.fileHeaders,
                      )
                    : null,
                child: member['avatar_key']?.toString().isNotEmpty == true
                    ? null
                    : const Icon(Icons.person_rounded),
              ),
              title: Text(member['display_name']?.toString() ?? 'User'),
              subtitle: Text(member['role']?.toString() ?? 'member'),
              trailing: canManage &&
                      member['user_id']?.toString() != widget.state.userId &&
                      member['role']?.toString() != 'leader'
                  ? PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'admin') {
                          await widget.state.backend.setFamilyAdmin(
                            userId: widget.state.userId,
                            targetUserId: member['user_id'].toString(),
                            admin: member['role'] != 'admin',
                          );
                        } else if (action == 'remove') {
                          await widget.state.backend.removeFamilyMember(
                            userId: widget.state.userId,
                            targetUserId: member['user_id'].toString(),
                          );
                        }
                        await _load();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'admin',
                          child: Text(member['role'] == 'admin' ? 'Remove admin' : 'Make admin'),
                        ),
                        const PopupMenuItem(value: 'remove', child: Text('Remove member')),
                      ],
                    )
                  : null,
            ),
          ),
        if (role != 'leader') ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              if (await widget.state.backend.leaveFamily(userId: widget.state.userId)) {
                await _load();
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Leave Family'),
          ),
        ],
      ],
    );
  }
}

class CpScreen extends StatefulWidget {
  const CpScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CpScreen> createState() => _CpScreenState();
}

class _CpScreenState extends State<CpScreen> {
  bool loading = true;
  Map<String, dynamic>? cp;
  List<Map<String, dynamic>> memories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.state.backend.cpState(userId: widget.state.userId);
    final raw = value?['cp'];
    final next = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final memoryRows = next == null
        ? const <Map<String, dynamic>>[]
        : await widget.state.backend.cpMemories(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      cp = next;
      memories = memoryRows;
      loading = false;
    });
  }

  String _partnerId() {
    if (cp == null) return '';
    return cp!['user_a'] == widget.state.userId
        ? cp!['user_b']?.toString() ?? ''
        : cp!['user_a']?.toString() ?? '';
  }

  String _partnerName() {
    if (cp == null) return '';
    return cp!['user_a'] == widget.state.userId
        ? cp!['user_b_name']?.toString() ?? _partnerId()
        : cp!['user_a_name']?.toString() ?? _partnerId();
  }

  Future<void> _request() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request CP'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'User ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Send')),
        ],
      ),
    );
    controller.dispose();
    if (id == null || id.isEmpty) return;
    await widget.state.backend.cpRequest(
      userId: widget.state.userId,
      targetUserId: id,
    );
    await _load();
  }

  Future<void> _addMemory() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add CP memory'),
        content: TextField(controller: controller, maxLength: 500, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    if (await widget.state.backend.addCpMemory(userId: widget.state.userId, text: text)) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = cp?['state']?.toString();
    final pendingForMe = state == 'pending' &&
        cp?['requested_by']?.toString() != widget.state.userId;
    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: const Text('My CP'),
        actions: [
          IconButton(
            tooltip: 'CP Ranking',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CpRankingScreen(state: widget.state),
              ),
            ),
            icon: const Icon(Icons.leaderboard_rounded),
          ),
        ],
      ),
      body: TinniBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (cp == null)
                    TinniPanel(
                      onTap: _request,
                      child: const Row(
                        children: [
                          TinniGlowIcon(icon: Icons.favorite_rounded, size: 28, boxSize: 54),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Request CP',
                              style: TextStyle(
                                color: TinniPalette.cream,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: TinniPalette.gold),
                        ],
                      ),
                    )
                  else ...[
                    TinniPanel(
                      child: Column(
                        children: [
                          const TinniGlowIcon(icon: Icons.favorite_rounded, size: 34, boxSize: 66),
                          const SizedBox(height: 10),
                          Text(
                            _partnerName(),
                            style: const TextStyle(
                              color: TinniPalette.gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'ID ${_partnerId()} • ${state ?? ''}',
                            style: const TextStyle(color: TinniPalette.muted),
                          ),
                          if (state == 'active')
                            Text(
                              'Intimacy ${cp?['intimacy'] ?? 0} • Lv.${cp?['level'] ?? 1}',
                              style: const TextStyle(color: TinniPalette.cream),
                            ),
                        ],
                      ),
                    ),
                    if (pendingForMe) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await widget.state.backend.cpRespond(
                                  userId: widget.state.userId,
                                  accept: true,
                                );
                                await _load();
                              },
                              child: const Text('Accept CP'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await widget.state.backend.cpRespond(
                                  userId: widget.state.userId,
                                  accept: false,
                                );
                                await _load();
                              },
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (state == 'active') ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _addMemory,
                              icon: const Icon(Icons.auto_stories_rounded),
                              label: const Text('Add memory'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (await widget.state.backend.cpDisconnect(
                                  userId: widget.state.userId,
                                )) {
                                  await _load();
                                }
                              },
                              icon: const Icon(Icons.link_off_rounded),
                              label: const Text('Disconnect'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'CP Memories',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      for (final memory in memories)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TinniPanel(
                            child: ListTile(
                              leading: const Icon(
                                Icons.favorite_border_rounded,
                                color: TinniPalette.gold,
                              ),
                              title: Text(memory['body']?.toString() ?? ''),
                            ),
                          ),
                        ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class CpRankingScreen extends StatefulWidget {
  const CpRankingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CpRankingScreen> createState() => _CpRankingScreenState();
}

class _CpRankingScreenState extends State<CpRankingScreen> {
  bool loading = true;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await widget.state.backend.cpRanking();
    if (!mounted) return;
    setState(() {
      rows = values;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('CP Ranking')),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TinniPanel(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: TinniPalette.gold,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                            title: Text(
                              '${row['user_a_name'] ?? row['user_a']} ❤️ ${row['user_b_name'] ?? row['user_b']}',
                            ),
                            subtitle: Text(
                              'Intimacy ${row['intimacy'] ?? 0} • Lv.${row['level'] ?? 1}',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      );
}


class VsScreen extends StatefulWidget {
  const VsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<VsScreen> createState() => _VsScreenState();
}

class _VsScreenState extends State<VsScreen> {
  bool loading = true;
  Map<String, dynamic>? vs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.state.backend.vsState(
      userId: widget.state.userId,
    );
    final raw = value?['vs'];
    if (!mounted) return;
    setState(() {
      vs = raw is Map ? Map<String, dynamic>.from(raw) : null;
      loading = false;
    });
  }

  String _rivalId() {
    if (vs == null) return '';
    return vs!['user_a']?.toString() == widget.state.userId
        ? vs!['user_b']?.toString() ?? ''
        : vs!['user_a']?.toString() ?? '';
  }

  String _rivalName() {
    if (vs == null) return '';
    return vs!['user_a']?.toString() == widget.state.userId
        ? vs!['user_b_name']?.toString() ?? _rivalId()
        : vs!['user_a_name']?.toString() ?? _rivalId();
  }

  Future<void> _request() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('VS Challenge'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'User ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Challenge'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (id == null || id.isEmpty) return;
    await widget.state.backend.vsRequest(
      userId: widget.state.userId,
      targetUserId: id,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final relationState = vs?['state']?.toString();
    final incoming = relationState == 'pending' &&
        vs?['requested_by']?.toString() != widget.state.userId;

    return Scaffold(
      backgroundColor: const Color(0xFF05070B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF05070B),
        title: const Text(
          'VS',
          style: TextStyle(
            color: Color(0xFFFF202D),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'VS Ranking',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VsRankingScreen(state: widget.state),
              ),
            ),
            icon: const Icon(
              Icons.leaderboard_rounded,
              color: Color(0xFFFF202D),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (vs == null)
                  InkWell(
                    onTap: _request,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF220508),
                            Color(0xFF05070B),
                            Color(0xFF140306),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFF202D),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.dangerous_rounded,
                            color: Color(0xFFFF202D),
                            size: 64,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Add VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Choose a user ID and send a VS challenge.',
                            style: TextStyle(color: Color(0xFF9A8285)),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF220508),
                          Color(0xFF05070B),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFF202D),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.dangerous_rounded,
                          color: Color(0xFFFF202D),
                          size: 58,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _rivalName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'ID ${_rivalId()} • ${relationState ?? ''}',
                          style: const TextStyle(
                            color: Color(0xFF9A8285),
                          ),
                        ),
                        if (relationState == 'active')
                          Text(
                            'VS Lv.${vs?['level'] ?? 1} • Rivalry ${vs?['rivalry'] ?? 0}',
                            style: const TextStyle(
                              color: Color(0xFFFF202D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (incoming) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await widget.state.backend.vsRespond(
                                userId: widget.state.userId,
                                accept: false,
                              );
                              await _load();
                            },
                            child: const Text('Refuse'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await widget.state.backend.vsRespond(
                                userId: widget.state.userId,
                                accept: true,
                              );
                              await _load();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF202D),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (relationState == 'active') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (await widget.state.backend.vsDisconnect(
                          userId: widget.state.userId,
                        )) {
                          await _load();
                        }
                      },
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Remove VS'),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class VsRankingScreen extends StatefulWidget {
  const VsRankingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<VsRankingScreen> createState() => _VsRankingScreenState();
}

class _VsRankingScreenState extends State<VsRankingScreen> {
  bool loading = true;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await widget.state.backend.vsRanking();
    if (!mounted) return;
    setState(() {
      rows = values;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF05070B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF05070B),
          title: const Text(
            'VS Ranking',
            style: TextStyle(color: Color(0xFFFF202D)),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                      color: const Color(0xFF120609),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFFF202D),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          '${row['user_a_name'] ?? row['user_a']} VS ${row['user_b_name'] ?? row['user_b']}',
                        ),
                        subtitle: Text(
                          'Rivalry ${row['rivalry'] ?? 0} • Lv.${row['level'] ?? 1}',
                        ),
                      ),
                    );
                  },
                ),
              ),
      );
}
