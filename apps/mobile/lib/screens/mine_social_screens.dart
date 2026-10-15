import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'family_wallet_screen.dart';
import 'gifts_screen.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  bool loading = true;
  bool posting = false;
  List<Map<String, dynamic>> trends = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.state.backend.profileTrends(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() {
      trends = rows;
      loading = false;
    });
  }

  String _time(dynamic raw) {
    final value = int.tryParse(raw?.toString() ?? '') ?? 0;
    if (value <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _post() async {
    if (posting) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Trend'),
        content: TextField(
          key: const Key('profile-trend-text'),
          controller: controller,
          maxLength: 500,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Share something on your profile…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => posting = true);
    try {
      final result = await widget.state.backend.addProfileTrend(
        userId: widget.state.userId,
        text: text,
      );
      final row = result?['trend'];
      if (!mounted) return;
      if (result?['ok'] == true && row is Map) {
        setState(() {
          trends = <Map<String, dynamic>>[
            Map<String, dynamic>.from(row),
            ...trends,
          ];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']?.toString().replaceAll('_', ' ') ??
                  'Trend could not be posted.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Trends',
            style: TextStyle(
              color: TinniPalette.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'New Trend',
              onPressed: posting ? null : _post,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                    children: [
                      TinniPanel(
                        onTap: posting ? null : _post,
                        child: const Row(
                          children: [
                            TinniGlowIcon(
                              icon: Icons.auto_awesome_rounded,
                              size: 22,
                              boxSize: 42,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Share something on your profile…',
                                style: TextStyle(
                                  color: TinniPalette.muted,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit_rounded,
                              color: TinniPalette.gold,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (trends.isEmpty)
                        const TinniPanel(
                          child: Text(
                            'No Trends yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: TinniPalette.muted),
                          ),
                        )
                      else
                        for (final row in trends)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TinniPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row['text']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: TinniPalette.cream,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _time(row['created_at']),
                                    style: const TextStyle(
                                      color: TinniPalette.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
        ),
      );
}

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
      backgroundColor: Colors.transparent,
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
        backgroundColor: Colors.transparent,
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
        backgroundColor: Colors.transparent,
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
        backgroundColor: Colors.transparent,
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
        backgroundColor: Colors.transparent,
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
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final value = await widget.state.backend.familyCheckIn(
                    userId: widget.state.userId,
                  );
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
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: const Key('family-wallet-open'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FamilyWalletScreen(
                      state: widget.state,
                      familyName: family?['name']?.toString() ?? 'Family',
                    ),
                  ),
                ).then((_) => _load()),
                icon: const Icon(Icons.account_balance_wallet_rounded),
                label: const Text('Family Wallet'),
              ),
            ),
          ],
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
  String _cpCompact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toString();
  }

  bool loading = true;
  bool busy = false;
  Map<String, dynamic>? cp;
  List<Map<String, dynamic>> memories = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> friends = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceAll('_', ' '))),
    );
  }

  Future<void> _load() async {
    final value = await widget.state.backend.cpState(
      userId: widget.state.userId,
    );
    final raw = value?['cp'];
    final next = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final values = await Future.wait<dynamic>([
      widget.state.backend.friends(userId: widget.state.userId),
      next == null
          ? Future.value(const <Map<String, dynamic>>[])
          : widget.state.backend.cpMemories(userId: widget.state.userId),
    ]);
    if (!mounted) return;
    setState(() {
      cp = next;
      friends = values[0] is List
          ? (values[0] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      memories = values[1] is List
          ? (values[1] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      loading = false;
    });
  }

  String _partnerId() {
    if (cp == null) return '';
    return cp!['user_a']?.toString() == widget.state.userId
        ? cp!['user_b']?.toString() ?? ''
        : cp!['user_a']?.toString() ?? '';
  }

  String _partnerName() {
    if (cp == null) return '';
    return cp!['user_a']?.toString() == widget.state.userId
        ? cp!['user_b_name']?.toString() ?? _partnerId()
        : cp!['user_a_name']?.toString() ?? _partnerId();
  }

  String? _partnerAvatarKey() {
    if (cp == null) return null;
    return cp!['user_a']?.toString() == widget.state.userId
        ? cp!['user_b_avatar_key']?.toString()
        : cp!['user_a_avatar_key']?.toString();
  }

  Future<void> _requestTo(String id) async {
    if (busy || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CP Invite'),
        content: const Text(
          'Send a confession invitation to this mutual friend? '
          'CP Invite costs 2,222,222 DarkVibeX coins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.cpRequest(
        userId: widget.state.userId,
        targetUserId: id,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        final balance =
            int.tryParse(result?['coin_balance']?.toString() ?? '');
        if (balance != null) widget.state.setCoinBalance(balance);
        _notice('CP invitation sent.');
      } else {
        _notice(result?['error']?.toString() ?? 'CP invitation failed');
      }
      await _load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _respond(bool accept) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.cpRespond(
        userId: widget.state.userId,
        accept: accept,
      );
      if (!mounted) return;
      if (result?['ok'] != true) {
        _notice(result?['error']?.toString() ?? 'CP response failed');
      }
      await _load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect CP'),
        content: const Text(
          'Send a CP disconnect request? Your partner must accept it. '
          'If nobody responds, the request times out after 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.cpDisconnectRequest(
        userId: widget.state.userId,
      );
      if (!mounted) return;
      if (result?['ok'] == true && result?['cp'] is Map) {
        setState(() => cp = Map<String, dynamic>.from(result!['cp'] as Map));
      } else {
        _notice(result?['error']?.toString() ?? 'CP disconnect request failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _respondDisconnect(bool accept) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.cpDisconnectRespond(
        userId: widget.state.userId,
        accept: accept,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        final raw = result?['cp'];
        setState(() {
          cp = raw is Map ? Map<String, dynamic>.from(raw) : null;
        });
        if (accept) {
          memories = const <Map<String, dynamic>>[];
        }
      } else {
        _notice(result?['error']?.toString() ?? 'CP disconnect response failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _heartbeatCp(String action, {String? choice}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.cpHeartbeat(
        userId: widget.state.userId,
        action: action,
        choice: choice,
      );
      if (!mounted) return;
      if (result?['ok'] == true && result?['cp'] is Map) {
        setState(() => cp = Map<String, dynamic>.from(result!['cp'] as Map));
      } else {
        _notice(result?['error']?.toString() ?? 'Heartbeat could not be updated');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openCpGifts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GiftsScreen(
          state: widget.state,
          initialCategory: 'CP',
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _addMemory() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add CP memory'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a CP memory',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final ok = await widget.state.backend.addCpMemory(
      userId: widget.state.userId,
      text: text,
    );
    if (!ok) {
      _notice('CP memory could not be saved.');
      return;
    }
    await _load();
  }

  Future<void> _showMemories() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: TinniPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            ListTile(
              title: const Text(
                'CP Memories',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              trailing: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _addMemory();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ),
            if (memories.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No CP memories yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: TinniPalette.muted),
                ),
              )
            else
              for (final memory in memories)
                ListTile(
                  leading: const Icon(
                    Icons.favorite_rounded,
                    color: TinniPalette.gold,
                  ),
                  title: Text(memory['body']?.toString() ?? ''),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRingCabinet() async {
    final value = await widget.state.backend.cosmetics(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    final rawItems = value?['items'];
    final rawOwned = value?['owned'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) => row['kind']?.toString() == 'ring')
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final ownedIds = rawOwned is List
        ? rawOwned
            .whereType<Map>()
            .where((row) => row['kind']?.toString() == 'ring')
            .map((row) => row['item_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet()
        : <String>{};
    final rings = items
        .where((item) => ownedIds.contains(item['id']?.toString()))
        .toList(growable: false);
    final selected = cp?['ring_id']?.toString();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: TinniPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            const ListTile(
              title: Text(
                'Ring Cabinet',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text('Choose an owned CP ring.'),
            ),
            if (rings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'No owned rings yet. Buy a ring from Shop first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: TinniPalette.muted),
                ),
              )
            else
              for (final ring in rings)
                ListTile(
                  leading: const TinniGlowIcon(
                    icon: Icons.diamond_rounded,
                    size: 20,
                    boxSize: 40,
                  ),
                  title: Text(
                    ring['name']?.toString() ??
                        ring['id']?.toString() ??
                        'Ring',
                  ),
                  subtitle: Text(ring['id']?.toString() ?? ''),
                  trailing: selected == ring['id']?.toString()
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: TinniPalette.gold,
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: selected == ring['id']?.toString()
                      ? null
                      : () async {
                          final result =
                              await widget.state.backend.cpSetRing(
                            userId: widget.state.userId,
                            ringId: ring['id']?.toString(),
                          );
                          if (!sheetContext.mounted) return;
                          if (result?['ok'] == true) {
                            Navigator.pop(sheetContext);
                            await _load();
                          } else {
                            _notice(
                              result?['error']?.toString() ??
                                  'Ring could not be selected',
                            );
                          }
                        },
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRules() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: TinniPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 22),
            children: const [
              Text(
                'CP Rules',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              ListTile(
                leading: Icon(
                  Icons.favorite_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text('Become CP'),
                subtitle: Text(
                  'Invite a mutual friend. The CP invitation costs 2,222,222 coins.',
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.card_giftcard_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text('Partner-only level progress'),
                subtitle: Text(
                  'Only gifts sent directly between the two active CP partners count. Gifts from any third user do not increase CP level.',
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.layers_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text('Sending + receiving required'),
                subtitle: Text(
                  'Both partners must complete the current level target in both directions. Lv.1→2 needs 150M sent and 150M received; Lv.2→3 needs 250M each; every next level adds 100M. After level-up both counters reset to 0.',
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.diamond_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text('Ring Cabinet'),
                subtitle: Text(
                  'An owned ring can be selected for the active CP relationship.',
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.auto_stories_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text('Memories'),
                subtitle: Text(
                  'Active CP users can save relationship memories inside CP Nest.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relationState = cp?['state']?.toString();
    final pendingForMe = relationState == 'pending' &&
        cp?['requested_by']?.toString() != widget.state.userId;
    final intimacy = int.tryParse(cp?['intimacy']?.toString() ?? '') ?? 0;
    final levelSending =
        int.tryParse(cp?['level_sending']?.toString() ?? '') ?? 0;
    final levelReceiving =
        int.tryParse(cp?['level_receiving']?.toString() ?? '') ?? 0;
    final next = int.tryParse(cp?['next_level_target']?.toString() ?? '') ??
        150000000;
    final sendingProgress =
        next <= 0 ? 0.0 : (levelSending / next).clamp(0.0, 1.0);
    final receivingProgress =
        next <= 0 ? 0.0 : (levelReceiving / next).clamp(0.0, 1.0);
    final loveDays = int.tryParse(cp?['love_days']?.toString() ?? '') ?? 0;
    final disconnectState = cp?['disconnect_state']?.toString() ?? 'none';
    final disconnectIncoming = disconnectState == 'requested' &&
        cp?['disconnect_requested_by']?.toString() != widget.state.userId;
    final disconnectOutgoing = disconnectState == 'requested' &&
        cp?['disconnect_requested_by']?.toString() == widget.state.userId;
    final heartbeatState = cp?['heartbeat_state']?.toString() ?? 'idle';
    final heartbeatChoice = cp?['heartbeat_choice']?.toString() ?? '';
    final partnerHeartbeatChoice =
        cp?['partner_heartbeat_choice']?.toString() ?? '';
    final partnerAvatar = _partnerAvatarKey();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My CP'),
        actions: [
          IconButton(
            tooltip: 'CP Rules',
            onPressed: _showRules,
            icon: const Icon(Icons.info_outline_rounded),
          ),
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
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  children: [
                    if (cp == null) ...[
                      const TinniPanel(
                        child: Column(
                          children: [
                            TinniGlowIcon(
                              icon: Icons.favorite_rounded,
                              size: 34,
                              boxSize: 66,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Choose a friend for CP',
                              style: TextStyle(
                                color: TinniPalette.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'CP invitations can only be sent to mutual friends.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: TinniPalette.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (friends.isEmpty)
                        const TinniPanel(
                          child: Text(
                            'No mutual friends available yet.',
                            style: TextStyle(color: TinniPalette.muted),
                          ),
                        )
                      else
                        for (final friend in friends)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TinniPanel(
                              onTap: busy
                                  ? null
                                  : () => _requestTo(
                                        friend['id']?.toString() ?? '',
                                      ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: TinniPalette.panel2,
                                    backgroundImage:
                                        friend['avatar_key']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? NetworkImage(
                                                widget.state.backend.fileUrl(
                                                  friend['avatar_key']
                                                      .toString(),
                                                ),
                                                headers: widget.state.backend
                                                    .fileHeaders,
                                              )
                                            : null,
                                    child: friend['avatar_key']
                                                ?.toString()
                                                .isNotEmpty ==
                                            true
                                        ? null
                                        : const Icon(
                                            Icons.person_rounded,
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend['display_name']?.toString() ??
                                              'Friend',
                                          style: const TextStyle(
                                            color: TinniPalette.cream,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          'ID ${friend['id'] ?? ''}',
                                          style: const TextStyle(
                                            color: TinniPalette.muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    'Invite',
                                    style: TextStyle(
                                      color: TinniPalette.gold,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ] else ...[
                      TinniPanel(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: TinniPalette.panel2,
                              backgroundImage:
                                  partnerAvatar?.isNotEmpty == true
                                      ? NetworkImage(
                                          widget.state.backend.fileUrl(
                                            partnerAvatar!,
                                          ),
                                          headers:
                                              widget.state.backend.fileHeaders,
                                        )
                                      : null,
                              child: partnerAvatar?.isNotEmpty == true
                                  ? null
                                  : const Icon(
                                      Icons.favorite_rounded,
                                      color: TinniPalette.gold,
                                      size: 36,
                                    ),
                            ),
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
                              'ID ${_partnerId()} • ${relationState ?? ''}',
                              style: const TextStyle(
                                color: TinniPalette.muted,
                              ),
                            ),
                            if (relationState == 'active') ...[
                              const SizedBox(height: 9),
                              Text(
                                'CP Lv.${cp?['level'] ?? 1} • Intimacy $intimacy',
                                style: const TextStyle(
                                  color: TinniPalette.cream,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Love Days $loveDays',
                                style: const TextStyle(
                                  color: TinniPalette.muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 66,
                                    child: Text(
                                      'Sending',
                                      style: TextStyle(
                                        color: TinniPalette.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: sendingProgress,
                                      minHeight: 7,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    '${_cpCompact(levelSending)} / ${_cpCompact(next)}',
                                    style: const TextStyle(
                                      color: TinniPalette.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 66,
                                    child: Text(
                                      'Receiving',
                                      style: TextStyle(
                                        color: TinniPalette.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: receivingProgress,
                                      minHeight: 7,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    '${_cpCompact(levelReceiving)} / ${_cpCompact(next)}',
                                    style: const TextStyle(
                                      color: TinniPalette.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Both must reach ${_cpCompact(next)} • next level resets both to 0',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: TinniPalette.muted,
                                  fontSize: 10,
                                ),
                              ),
                              if (cp?['ring_id']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.diamond_rounded,
                                      color: TinniPalette.gold,
                                      size: 17,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      cp!['ring_id'].toString(),
                                      style: const TextStyle(
                                        color: TinniPalette.gold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      if (pendingForMe) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    busy ? null : () => _respond(true),
                                child: const Text('Accept CP'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    busy ? null : () => _respond(false),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (relationState == 'pending' && !pendingForMe) ...[
                        const SizedBox(height: 10),
                        const TinniPanel(
                          child: Text(
                            'CP invitation sent. Waiting for your friend to accept.',
                            style: TextStyle(color: TinniPalette.muted),
                          ),
                        ),
                      ],
                      if (relationState == 'active') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TinniPanel(
                                onTap: _openCpGifts,
                                child: const Column(
                                  children: [
                                    TinniGlowIcon(
                                      icon: Icons.card_giftcard_rounded,
                                      size: 22,
                                      boxSize: 42,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'CP Gifts',
                                      style: TextStyle(
                                        color: TinniPalette.gold,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TinniPanel(
                                onTap: _showRingCabinet,
                                child: const Column(
                                  children: [
                                    TinniGlowIcon(
                                      icon: Icons.diamond_rounded,
                                      size: 22,
                                      boxSize: 42,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Ring Cabinet',
                                      style: TextStyle(
                                        color: TinniPalette.gold,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TinniPanel(
                                onTap: _showMemories,
                                child: const Column(
                                  children: [
                                    TinniGlowIcon(
                                      icon: Icons.auto_stories_rounded,
                                      size: 22,
                                      boxSize: 42,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Memories',
                                      style: TextStyle(
                                        color: TinniPalette.gold,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TinniPanel(
                                onTap: heartbeatState == 'idle'
                                    ? (busy ? null : () => _heartbeatCp('start'))
                                    : null,
                                child: Column(
                                  children: [
                                    const TinniGlowIcon(
                                      icon: Icons.monitor_heart_rounded,
                                      size: 22,
                                      boxSize: 42,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      heartbeatState == 'idle'
                                          ? 'Heartbeat'
                                          : 'Heartbeat: $heartbeatState',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: TinniPalette.gold,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (heartbeatState != 'idle') ...[
                          const SizedBox(height: 8),
                          TinniPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  heartbeatState == 'selecting'
                                      ? 'Choose heartbeat'
                                      : heartbeatState == 'matched'
                                          ? 'Heartbeat matched ❤️'
                                          : 'Heartbeat did not match',
                                  style: const TextStyle(
                                    color: TinniPalette.gold,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'You: ${heartbeatChoice.isEmpty ? 'waiting' : heartbeatChoice} • '
                                  'Partner: ${partnerHeartbeatChoice.isEmpty ? 'waiting' : partnerHeartbeatChoice}',
                                  style: const TextStyle(
                                    color: TinniPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (heartbeatState == 'selecting')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => _heartbeatCp(
                                                    'choose',
                                                    choice: 'A',
                                                  ),
                                          child: const Text('❤️ A'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => _heartbeatCp(
                                                    'choose',
                                                    choice: 'B',
                                                  ),
                                          child: const Text('❤️ B'),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => _heartbeatCp('close'),
                                      child: const Text('Close Heartbeat'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (disconnectIncoming)
                          TinniPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CP disconnect request received',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: busy
                                            ? null
                                            : () => _respondDisconnect(false),
                                        child: const Text('Keep CP'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: busy
                                            ? null
                                            : () => _respondDisconnect(true),
                                        child: const Text('Accept disconnect'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else if (disconnectOutgoing)
                          const TinniPanel(
                            child: Text(
                              'Disconnect request sent. Waiting for partner response.',
                              style: TextStyle(color: TinniPalette.muted),
                            ),
                          )
                        else ...[
                          if (disconnectState == 'refused' ||
                              disconnectState == 'timedOut')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                disconnectState == 'refused'
                                    ? 'Last disconnect request was refused.'
                                    : 'Last disconnect request timed out.',
                                style: const TextStyle(
                                  color: TinniPalette.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _disconnect,
                            icon: const Icon(Icons.link_off_rounded),
                            label: const Text('Request Disconnect'),
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
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
  int tab = 0;
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

  Widget _tabs() => Row(
        children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    tab == 0 ? TinniPalette.gold : TinniPalette.panel2,
                foregroundColor:
                    tab == 0 ? Colors.black : TinniPalette.cream,
              ),
              onPressed: () => setState(() => tab = 0),
              child: const Text('CP Ranking'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    tab == 1 ? TinniPalette.gold : TinniPalette.panel2,
                foregroundColor:
                    tab == 1 ? Colors.black : TinniPalette.cream,
              ),
              onPressed: () => setState(() => tab = 1),
              child: const Text('CP Square'),
            ),
          ),
        ],
      );

  Widget _rankingList() => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
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
                  '${row['user_a_name'] ?? row['user_a']} ❤️ '
                  '${row['user_b_name'] ?? row['user_b']}',
                ),
                subtitle: Text(
                  'Lv.${row['level'] ?? 1} • '
                  'Intimacy ${row['intimacy'] ?? 0}',
                ),
              ),
            ),
          );
        },
      );

  Widget _square() => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final a = row['user_a_name'] ?? row['user_a'] ?? 'User';
          final b = row['user_b_name'] ?? row['user_b'] ?? 'User';
          final createdAt =
              int.tryParse(row['activated_at']?.toString() ?? '') ??
                  int.tryParse(row['created_at']?.toString() ?? '') ??
                  0;
          final loveDays = createdAt <= 0
              ? 0
              : (DateTime.now()
                          .difference(
                            DateTime.fromMillisecondsSinceEpoch(createdAt),
                          )
                          .inDays +
                      1)
                  .clamp(1, 999999);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TinniPanel(
              child: Column(
                children: [
                  const TinniGlowIcon(
                    icon: Icons.favorite_rounded,
                    size: 24,
                    boxSize: 46,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$a  ❤️  $b',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TinniPalette.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CP Lv.${row['level'] ?? 1} • Love Days $loveDays',
                    style: const TextStyle(
                      color: TinniPalette.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Total intimacy ${row['intimacy'] ?? 0}',
                    style: const TextStyle(
                      color: TinniPalette.cream,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('CP')),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: _tabs(),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: tab == 0 ? _rankingList() : _square(),
                      ),
                    ],
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
  String _vsCompact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toString();
  }

  bool loading = true;
  bool busy = false;
  Map<String, dynamic>? vs;
  List<Map<String, dynamic>> friends = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final relation = await widget.state.backend.vsState(
      userId: widget.state.userId,
    );
    final friendRows = await widget.state.backend.friends(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    final raw = relation?['vs'];
    setState(() {
      vs = raw is Map ? Map<String, dynamic>.from(raw) : null;
      friends = friendRows;
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

  String? _rivalAvatarKey() {
    if (vs == null) return null;
    return vs!['user_a']?.toString() == widget.state.userId
        ? vs!['user_b_avatar_key']?.toString()
        : vs!['user_a_avatar_key']?.toString();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceAll('_', ' '))),
    );
  }

  Future<String?> _chooseFriend() async {
    if (friends.isEmpty) {
      _notice('No mutual friends available for a VS challenge.');
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF10080A),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          children: [
            const ListTile(
              title: Text(
                'Choose a friend to challenge',
                style: TextStyle(
                  color: Color(0xFFFF202D),
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                'VS can only be created with a mutual friend.',
              ),
            ),
            for (final friend in friends)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF241014),
                  backgroundImage:
                      friend['avatar_key']?.toString().isNotEmpty == true
                          ? NetworkImage(
                              widget.state.backend.fileUrl(
                                friend['avatar_key'].toString(),
                              ),
                              headers: widget.state.backend.fileHeaders,
                            )
                          : null,
                  child: friend['avatar_key']?.toString().isNotEmpty == true
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: Color(0xFFFF202D),
                        ),
                ),
                title: Text(
                  friend['display_name']?.toString().trim().isNotEmpty == true
                      ? friend['display_name'].toString()
                      : 'User',
                ),
                subtitle: Text('ID ${friend['id'] ?? ''}'),
                trailing: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFF202D),
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  friend['id']?.toString(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestTo(String id) async {
    if (busy || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('VS Challenge'),
        content: const Text(
          'Send this friend a VS challenge? Once accepted, only VS-category gifts exchanged between this pair raise the VS level.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF202D),
            ),
            child: const Text('Challenge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.vsRequest(
        userId: widget.state.userId,
        targetUserId: id,
      );
      if (!mounted) return;
      if (result?['ok'] != true) {
        _notice(result?['error']?.toString() ?? 'VS challenge failed');
      }
      await _load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _request() async {
    if (busy) return;
    final id = await _chooseFriend();
    if (id == null || id.isEmpty || !mounted) return;
    await _requestTo(id);
  }

  Future<void> _respond(bool accept) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.vsRespond(
        userId: widget.state.userId,
        accept: accept,
      );
      if (!mounted) return;
      if (result?['ok'] != true) {
        _notice(result?['error']?.toString() ?? 'VS response failed');
      }
      await _load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove VS'),
        content: const Text(
          'Send a VS disconnect request? Your VS partner must accept it. '
          'If nobody responds, the request times out after 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF202D),
            ),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.vsDisconnectRequest(
        userId: widget.state.userId,
      );
      if (!mounted) return;
      if (result?['ok'] == true && result?['vs'] is Map) {
        setState(() => vs = Map<String, dynamic>.from(result!['vs'] as Map));
      } else {
        _notice(result?['error']?.toString() ?? 'VS disconnect request failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _respondVsDisconnect(bool accept) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.vsDisconnectRespond(
        userId: widget.state.userId,
        accept: accept,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        final raw = result?['vs'];
        setState(() {
          vs = raw is Map ? Map<String, dynamic>.from(raw) : null;
        });
      } else {
        _notice(result?['error']?.toString() ?? 'VS disconnect response failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _heartbeatVs(String action, {String? choice}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.vsHeartbeat(
        userId: widget.state.userId,
        action: action,
        choice: choice,
      );
      if (!mounted) return;
      if (result?['ok'] == true && result?['vs'] is Map) {
        setState(() => vs = Map<String, dynamic>.from(result!['vs'] as Map));
      } else {
        _notice(result?['error']?.toString() ?? 'VS heartbeat could not be updated');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openVsGifts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GiftsScreen(
          state: widget.state,
          initialCategory: 'VS',
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _showVsRules() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: TinniPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .68,
          child: ListView(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 22),
            children: [
              Text(
                'VS Rules',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF202D),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              ListTile(
                leading: Icon(Icons.people_alt_rounded, color: Color(0xFFFF202D)),
                title: Text('Partner-only progress'),
                subtitle: Text(
                  'Only gifts exchanged directly between the two active VS partners count. Gifts from any other user add 0 VS level progress.',
                ),
              ),
              ListTile(
                leading: Icon(Icons.swap_horiz_rounded, color: Color(0xFFFF202D)),
                title: Text('Both directions required'),
                subtitle: Text(
                  'Every level requires both sending and receiving. Lv.1→2: 150M each. Lv.2→3: 250M each. Every following level target increases by 100M.',
                ),
              ),
              ListTile(
                leading: Icon(Icons.restart_alt_rounded, color: Color(0xFFFF202D)),
                title: Text('Reset each level'),
                subtitle: Text(
                  'When both targets are complete, VS level increases by 1 and both current-level counters reset to 0. Extra progress is not carried to the next level.',
                ),
              ),
              ListTile(
                leading: Icon(Icons.leaderboard_rounded, color: Color(0xFFFF202D)),
                title: Text('VS Ranking'),
                subtitle: Text(
                  'Ranking prioritizes higher VS level, then total direct partner gift value.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relationState = vs?['state']?.toString();
    final incoming = relationState == 'pending' &&
        vs?['requested_by']?.toString() != widget.state.userId;
    final rivalry = int.tryParse(vs?['rivalry']?.toString() ?? '') ?? 0;
    final levelSending =
        int.tryParse(vs?['level_sending']?.toString() ?? '') ?? 0;
    final levelReceiving =
        int.tryParse(vs?['level_receiving']?.toString() ?? '') ?? 0;
    final next = int.tryParse(vs?['next_level_target']?.toString() ?? '') ??
        150000000;
    final sendingProgress =
        next <= 0 ? 0.0 : (levelSending / next).clamp(0.0, 1.0);
    final receivingProgress =
        next <= 0 ? 0.0 : (levelReceiving / next).clamp(0.0, 1.0);
    final vsDays = int.tryParse(vs?['vs_days']?.toString() ?? '') ?? 0;
    final disconnectState = vs?['disconnect_state']?.toString() ?? 'none';
    final disconnectIncoming = disconnectState == 'requested' &&
        vs?['disconnect_requested_by']?.toString() != widget.state.userId;
    final disconnectOutgoing = disconnectState == 'requested' &&
        vs?['disconnect_requested_by']?.toString() == widget.state.userId;
    final heartbeatState = vs?['heartbeat_state']?.toString() ?? 'idle';
    final heartbeatChoice = vs?['heartbeat_choice']?.toString() ?? '';
    final partnerHeartbeatChoice =
        vs?['partner_heartbeat_choice']?.toString() ?? '';
    final avatarKey = _rivalAvatarKey();

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
            tooltip: 'VS Rules',
            onPressed: _showVsRules,
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFF202D),
            ),
          ),
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
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  if (vs == null) ...[
                    InkWell(
                      onTap: busy ? null : _request,
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
                              'Choose a mutual friend and send a VS challenge.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF9A8285)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Mutual friends',
                      style: TextStyle(
                        color: Color(0xFFFF202D),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      const TinniPanel(
                        child: Text(
                          'No mutual friends available yet.',
                          style: TextStyle(color: TinniPalette.muted),
                        ),
                      )
                    else
                      for (final friend in friends.take(20))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: TinniPanel(
                            onTap: busy
                                ? null
                                : () => _requestTo(
                                      friend['id']?.toString() ?? '',
                                    ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFFFF202D),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    friend['display_name']?.toString() ??
                                        friend['id']?.toString() ??
                                        'Friend',
                                  ),
                                ),
                                const Text(
                                  'Challenge',
                                  style: TextStyle(
                                    color: Color(0xFFFF202D),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ] else ...[
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
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFF241014),
                            backgroundImage:
                                avatarKey?.isNotEmpty == true
                                    ? NetworkImage(
                                        widget.state.backend.fileUrl(avatarKey!),
                                        headers:
                                            widget.state.backend.fileHeaders,
                                      )
                                    : null,
                            child: avatarKey?.isNotEmpty == true
                                ? null
                                : const Icon(
                                    Icons.dangerous_rounded,
                                    color: Color(0xFFFF202D),
                                    size: 42,
                                  ),
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
                          if (relationState == 'active') ...[
                            const SizedBox(height: 10),
                            Text(
                              'VS Lv.${vs?['level'] ?? 1} • Rivalry $rivalry',
                              style: const TextStyle(
                                color: Color(0xFFFF202D),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'VS Days $vsDays',
                              style: const TextStyle(
                                color: Color(0xFF9A8285),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 66,
                                  child: Text(
                                    'Sending',
                                    style: TextStyle(
                                      color: Color(0xFF9A8285),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: sendingProgress,
                                    minHeight: 7,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${_vsCompact(levelSending)} / ${_vsCompact(next)}',
                                  style: const TextStyle(
                                    color: Color(0xFF9A8285),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 66,
                                  child: Text(
                                    'Receiving',
                                    style: TextStyle(
                                      color: Color(0xFF9A8285),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: receivingProgress,
                                    minHeight: 7,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  '${_vsCompact(levelReceiving)} / ${_vsCompact(next)}',
                                  style: const TextStyle(
                                    color: Color(0xFF9A8285),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Both must reach ${_vsCompact(next)} • next level resets both to 0',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF9A8285),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (incoming) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  busy ? null : () => _respond(false),
                              child: const Text('Refuse'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  busy ? null : () => _respond(true),
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
                    if (relationState == 'pending' && !incoming) ...[
                      const SizedBox(height: 10),
                      const TinniPanel(
                        child: Text(
                          'VS challenge sent. Waiting for your friend to accept.',
                          style: TextStyle(color: TinniPalette.muted),
                        ),
                      ),
                    ],
                    if (relationState == 'active') ...[
                      const SizedBox(height: 12),
                      TinniPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VS Gifts',
                              style: TextStyle(
                                color: Color(0xFFFF202D),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Any gift sent directly between you and your connected VS counts toward that level. Third-party gifts never count.',
                              style: TextStyle(
                                color: TinniPalette.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openVsGifts,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFFF202D),
                                ),
                                icon:
                                    const Icon(Icons.card_giftcard_rounded),
                                label: const Text('Open VS Gifts'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TinniPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              heartbeatState == 'idle'
                                  ? 'VS Heartbeat'
                                  : heartbeatState == 'matched'
                                      ? 'VS Heartbeat matched ❤️'
                                      : heartbeatState == 'failed'
                                          ? 'VS Heartbeat did not match'
                                          : 'VS Heartbeat selecting',
                              style: const TextStyle(
                                color: Color(0xFFFF202D),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (heartbeatState == 'idle')
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => _heartbeatVs('start'),
                                  icon: const Icon(Icons.monitor_heart_rounded),
                                  label: const Text('Start Heartbeat'),
                                ),
                              )
                            else ...[
                              Text(
                                'You: ${heartbeatChoice.isEmpty ? 'waiting' : heartbeatChoice} • '
                                'Partner: ${partnerHeartbeatChoice.isEmpty ? 'waiting' : partnerHeartbeatChoice}',
                                style: const TextStyle(
                                  color: TinniPalette.muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (heartbeatState == 'selecting')
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: busy
                                            ? null
                                            : () => _heartbeatVs(
                                                  'choose',
                                                  choice: 'A',
                                                ),
                                        child: const Text('❤️ A'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: busy
                                            ? null
                                            : () => _heartbeatVs(
                                                  'choose',
                                                  choice: 'B',
                                                ),
                                        child: const Text('❤️ B'),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _heartbeatVs('close'),
                                    child: const Text('Close Heartbeat'),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (disconnectIncoming)
                        TinniPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VS disconnect request received',
                                style: TextStyle(
                                  color: Color(0xFFFF202D),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: busy
                                          ? null
                                          : () => _respondVsDisconnect(false),
                                      child: const Text('Keep VS'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => _respondVsDisconnect(true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF202D),
                                      ),
                                      child: const Text('Accept disconnect'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else if (disconnectOutgoing)
                        const TinniPanel(
                          child: Text(
                            'Disconnect request sent. Waiting for VS partner response.',
                            style: TextStyle(color: TinniPalette.muted),
                          ),
                        )
                      else ...[
                        if (disconnectState == 'refused' ||
                            disconnectState == 'timedOut')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              disconnectState == 'refused'
                                  ? 'Last VS disconnect request was refused.'
                                  : 'Last VS disconnect request timed out.',
                              style: const TextStyle(
                                color: TinniPalette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _disconnect,
                          icon: const Icon(Icons.link_off_rounded),
                          label: const Text('Request VS Disconnect'),
                        ),
                      ],
                    ],
                  ],
                ],
              ),
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


class FamilyRankingScreen extends StatefulWidget {
  const FamilyRankingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FamilyRankingScreen> createState() => _FamilyRankingScreenState();
}

class _FamilyRankingScreenState extends State<FamilyRankingScreen> {
  bool loading = true;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await widget.state.backend.familyList();
    if (!mounted) return;
    setState(() {
      rows = values;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Family Ranking')),
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
                              row['name']?.toString() ?? 'Family',
                              style: const TextStyle(
                                color: TinniPalette.cream,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${row['tag'] ?? ''} • ${row['member_count'] ?? 0} members • EXP ${row['experience'] ?? 0}',
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
