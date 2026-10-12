import 'package:flutter/material.dart';

import '../app/app_state.dart';

class MineFeatureScreen extends StatefulWidget {
  const MineFeatureScreen({super.key, required this.state, required this.kind});
  final AppState state;
  final String kind;

  @override
  State<MineFeatureScreen> createState() => _MineFeatureScreenState();
}

class _MineFeatureScreenState extends State<MineFeatureScreen> {
  bool loading = true;
  bool saving = false;
  String? claiming;
  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> rows = const [];
  final message = TextEditingController();
  String category = 'General';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.kind == 'Guardian') {
      final value = await widget.state.backend.mineGuardianState(userId: widget.state.userId);
      final rawRows = value?['supporters'];
      if (!mounted) return;
      setState(() {
        stats = value;
        rows = rawRows is List ? rawRows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList() : const [];
        loading = false;
      });
      return;
    }
    if (widget.kind == 'Wealth Level') {
      final value = await widget.state.backend.mineWealth(userId: widget.state.userId);
      if (!mounted) return;
      setState(() { stats = value; loading = false; });
      return;
    }
    final values = switch (widget.kind) {
      'Guardian' => await widget.state.backend.mineGuardian(userId: widget.state.userId),
      'Feedback' => await widget.state.backend.mineFeedback(userId: widget.state.userId),
      'Task' => await widget.state.backend.mineTasks(userId: widget.state.userId),
      'Medal of Honor' => await widget.state.backend.mineMedals(userId: widget.state.userId),
      _ => await widget.state.backend.mineBlocks(userId: widget.state.userId),
    };
    if (!mounted) return;
    setState(() { rows = values; loading = false; });
  }

  Future<void> _submitFeedback() async {
    final text = message.text.trim();
    if (text.length < 3 || saving) return;
    setState(() => saving = true);
    final ok = await widget.state.backend.submitMineFeedback(
      userId: widget.state.userId,
      category: category,
      message: text,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      message.clear();
      await _load();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Feedback submitted' : 'Feedback could not be submitted')),
    );
  }

  Future<void> _unblock(String userId) async {
    final ok = await widget.state.backend.setMineBlock(
      userId: widget.state.userId,
      targetUserId: userId,
      blocked: false,
    );
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      'Guardian' => 'My Guardian',
      'Feedback' => 'Feedback',
      'Task' => 'Task',
      'Wealth Level' => 'Wealth level',
      'Medal of Honor' => 'Medal of Honor',
      _ => 'Blacklist',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.kind == 'Wealth Level') ...[
                    const Card(child: ListTile(
                      leading: Icon(Icons.diamond_rounded),
                      title: Text('Wealth Level'),
                      subtitle: Text('Based on lifetime coins spent on gifts.'),
                    )),
                    ListTile(
                      title: Text('Level ${(stats?['wealth'] as Map?)?['level'] ?? 0}'),
                      subtitle: Text('Lifetime gift coins spent: ${stats?['lifetime_sent_coins'] ?? 0}'),
                    ),
                    if ((stats?['wealth'] as Map?)?['next_threshold'] != null)
                      ListTile(title: const Text('Next level at'), subtitle: Text('${(stats?['wealth'] as Map?)?['next_threshold']} coins')),
                  ] else if (widget.kind == 'Task') ...[
                    for (final task in rows)
                      Card(child: ListTile(
                        title: Text(task['title']?.toString() ?? 'Task'),
                        subtitle: Text('Reward: ${task['reward_coins'] ?? 0} coins'),
                        trailing: task['claimed'] == true
                          ? const Text('Claimed')
                          : FilledButton(
                              onPressed: task['completed'] == true && claiming == null ? () async {
                                final taskId = task['id']?.toString() ?? '';
                                setState(() => claiming = taskId);
                                final result = await widget.state.backend.claimMineTask(userId: widget.state.userId, taskId: taskId);
                                await widget.state.refreshWallet();
                                if (!mounted) return;
                                setState(() {
                                  claiming = null;
                                  if (result?['tasks'] is List) {
                                    rows = (result!['tasks'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result?['ok'] == true ? 'Reward claimed' : 'Could not claim reward')));
                              } : null,
                              child: Text(claiming == task['id'] ? 'Claiming…' : task['completed'] == true ? 'Claim' : 'Incomplete'),
                            ),
                      )),
                  ] else if (widget.kind == 'Medal of Honor') ...[
                    if (rows.isEmpty) const ListTile(title: Text('No medals yet')),
                    for (final medal in rows)
                      ListTile(leading: const Icon(Icons.military_tech_rounded), title: Text(medal['name']?.toString() ?? 'Medal')),
                  ] else if (widget.kind == 'Feedback') ...[
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const ['General', 'Bug', 'Suggestion', 'Account']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (value) => setState(() => category = value ?? 'General'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: message,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Your feedback',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FilledButton(
                      onPressed: saving ? null : _submitFeedback,
                      child: Text(saving ? 'Submitting…' : 'Submit feedback'),
                    ),
                    const Divider(height: 28),
                    const Text('Feedback history', style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final row in rows)
                      ListTile(
                        title: Text(row['category']?.toString() ?? 'General'),
                        subtitle: Text(row['message']?.toString() ?? ''),
                        trailing: Text(row['status']?.toString() ?? 'received'),
                      ),
                  ] else if (widget.kind == 'Guardian') ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.shield_rounded),
                        title: Text((stats?['guardian'] as Map?)?['display_name']?.toString() ?? 'Guardian not assigned'),
                        subtitle: Text((stats?['guardian'] as Map?)?['guardian_eligible'] == true
                            ? 'Current Guardian • 30 day window'
                            : 'Top supporter needs 5,000,000 coins in 30 days'),
                        trailing: Text('${stats?['guardian_threshold'] ?? 5000000}'),
                      ),
                    ),
                    if (rows.isEmpty)
                      const ListTile(title: Text('No eligible gift supporters yet')),
                    for (var i = 0; i < rows.length; i++)
                      ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(rows[i]['display_name']?.toString() ?? rows[i]['user_id']?.toString() ?? 'User'),
                        subtitle: Text('ID ${rows[i]['user_id'] ?? ''}'),
                        trailing: Text('${rows[i]['gift_coins'] ?? rows[i]['coins'] ?? 0} coins'),
                      ),
                  ] else ...[
                    if (rows.isEmpty)
                      const ListTile(title: Text('Blacklist is empty')),
                    for (final row in rows)
                      ListTile(
                        leading: const Icon(Icons.block_rounded),
                        title: Text(row['display_name']?.toString() ?? 'User'),
                        subtitle: Text('ID ${row['id'] ?? ''}'),
                        trailing: TextButton(
                          onPressed: () => _unblock(row['id']?.toString() ?? ''),
                          child: const Text('Unblock'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
