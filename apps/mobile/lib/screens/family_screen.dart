import 'package:flutter/material.dart';

import '../app/app_state.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.state});
  final AppState state;
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool loading = true, working = false;
  Map<String, dynamic>? family;
  List<Map<String, dynamic>> members = [], requests = [], families = [], transfers = [];
  final name = TextEditingController(), tag = TextEditingController(), notice = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { name.dispose(); tag.dispose(); notice.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final result = await widget.state.backend.familyState(userId: widget.state.userId);
    final raw = result?['family'];
    final nextFamily = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final nextMembers = result?['members'];
    final nextRequests = result?['join_requests'];
    final nextFamilies = nextFamily == null ? await widget.state.backend.familyList() : <Map<String, dynamic>>[];
    final nextTransfers = nextFamily == null ? <Map<String, dynamic>>[] : await widget.state.backend.familyWalletTransfers(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      family = nextFamily;
      members = nextMembers is List ? nextMembers.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList() : [];
      requests = nextRequests is List ? nextRequests.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList() : [];
      families = nextFamilies;
      transfers = nextTransfers;
      notice.text = family?['notice']?.toString() ?? '';
      loading = false;
    });
  }

  Future<void> _act(Future<Map<String, dynamic>?> Function() action, String success) async {
    if (working) return;
    setState(() => working = true);
    final result = await action();
    if (!mounted) return;
    setState(() => working = false);
    if (result?['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((result?['error']?.toString() ?? 'Request failed').replaceAll('_', ' '))));
    }
  }

  bool get canManage => members.any((m) => m['user_id']?.toString() == widget.state.userId && const ['leader', 'admin'].contains(m['role']?.toString()));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Family')),
    body: loading ? const Center(child: CircularProgressIndicator()) : family == null ? _explore() : _home(),
  );

  Widget _explore() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Create a family', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      TextField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: 'Family name')),
      TextField(controller: tag, maxLength: 6, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Family tag')),
      FilledButton(onPressed: working ? null : () => _act(() => widget.state.backend.createFamily(userId: widget.state.userId, name: name.text.trim(), tag: tag.text.trim()), 'Family created'), child: const Text('Create family')),
      const SizedBox(height: 24),
      const Text('Family ranking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      if (families.isEmpty) const ListTile(title: Text('No families yet')),
      for (final row in families) Card(child: ListTile(
        title: Text(row['name']?.toString() ?? 'Family'),
        subtitle: Text('#' + (row['tag']?.toString() ?? '') + ' • ' + (row['member_count']?.toString() ?? '0') + ' members'),
        trailing: FilledButton.tonal(onPressed: working ? null : () => _act(() => widget.state.backend.requestFamilyJoin(userId: widget.state.userId, familyId: row['id'].toString()), 'Join request sent'), child: const Text('Request')),
      )),
    ]),
  );

  Widget _home() {
    final myMember = members.cast<Map<String, dynamic>?>().firstWhere((m) => m?['user_id']?.toString() == widget.state.userId, orElse: () => null);
    final role = myMember?['role']?.toString() ?? 'member';
    final exp = int.tryParse(family?['experience']?.toString() ?? '') ?? 0;
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.groups_rounded)),
        title: Text(family?['name']?.toString() ?? 'Family', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('#' + (family?['tag']?.toString() ?? '') + ' • ' + role.toUpperCase()),
        trailing: Text('Lv.' + (family?['level']?.toString() ?? '1')),
      )),
      Card(child: Column(children: [
        ListTile(title: const Text('Family EXP'), subtitle: Text(exp.toString() + ' • Level 1→2: 50,000,000'), leading: const Icon(Icons.bolt_rounded)),
        LinearProgressIndicator(value: (exp / 50000000).clamp(0, 1).toDouble()),
        ListTile(title: const Text('Family Wallet'), subtitle: Text((family?['wallet_coins']?.toString() ?? '0') + ' coins'), leading: const Icon(Icons.account_balance_wallet_rounded)),
        if (canManage) ListTile(title: const Text('Announcement'), subtitle: Text(family?['notice']?.toString().isNotEmpty == true ? family!['notice'].toString() : 'Set family notice'), trailing: const Icon(Icons.edit_rounded), onTap: _editNotice),
      ])),
      FilledButton.tonalIcon(onPressed: working ? null : () => _act(() => widget.state.backend.familyCheckIn(userId: widget.state.userId), 'Daily sign-in claimed · +100 EXP'), icon: const Icon(Icons.event_available_rounded), label: const Text('Daily family sign-in')),
      const SizedBox(height: 16),
      const Text('Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      for (final m in members) ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
        title: Text(m['display_name']?.toString() ?? m['user_id']?.toString() ?? 'Member'),
        subtitle: Text((m['role']?.toString() ?? 'member') + ' • ID ' + (m['user_id']?.toString() ?? '')),
        trailing: canManage && role == 'leader' && m['role'] != 'leader'
          ? PopupMenuButton<String>(onSelected: (v) => _act(
              v == 'remove'
                ? () => widget.state.backend.removeFamilyMember(userId: widget.state.userId, targetUserId: m['user_id'].toString())
                : () => widget.state.backend.setFamilyAdmin(userId: widget.state.userId, targetUserId: m['user_id'].toString(), admin: v == 'admin'),
              v == 'remove' ? 'Member removed' : 'Role updated',
            ), itemBuilder: (_) => const [PopupMenuItem(value: 'admin', child: Text('Make admin')), PopupMenuItem(value: 'member', child: Text('Remove admin')), PopupMenuItem(value: 'remove', child: Text('Remove member'))])
          : null,
      ),
      if (canManage) ...[
        const SizedBox(height: 12),
        const Text('Join requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (requests.isEmpty) const ListTile(title: Text('No pending requests')),
        for (final r in requests) ListTile(
          title: Text(r['display_name']?.toString() ?? r['user_id']?.toString() ?? 'User'),
          subtitle: Text('ID ' + (r['user_id']?.toString() ?? '')),
          trailing: Wrap(children: [
            IconButton(onPressed: () => _act(() => widget.state.backend.resolveFamilyJoin(userId: widget.state.userId, targetUserId: r['user_id'].toString(), approve: true), 'Request approved'), icon: const Icon(Icons.check_circle_outline)),
            IconButton(onPressed: () => _act(() => widget.state.backend.resolveFamilyJoin(userId: widget.state.userId, targetUserId: r['user_id'].toString(), approve: false), 'Request declined'), icon: const Icon(Icons.cancel_outlined)),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      const Text('Family wallet history', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      if (transfers.isEmpty) const ListTile(title: Text('No contributions yet')),
      for (final t in transfers.take(20)) ListTile(leading: const Icon(Icons.add_circle_outline), title: Text((t['amount']?.toString() ?? '0') + ' coins'), subtitle: Text((t['display_name']?.toString() ?? 'Member') + ' • ' + (t['created_at']?.toString() ?? ''))),
      OutlinedButton.icon(onPressed: working ? null : _contribute, icon: const Icon(Icons.savings_rounded), label: const Text('Contribute to family wallet')),
      if (role != 'leader') TextButton(onPressed: working ? null : () => _act(() => widget.state.backend.leaveFamily(userId: widget.state.userId), 'Left family'), child: const Text('Leave family')),
    ]));
  }

  Future<void> _editNotice() async {
    final value = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Family announcement'),
      content: TextField(controller: notice, maxLength: 500, maxLines: 4),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, notice.text.trim()), child: const Text('Save'))],
    ));
    if (value != null) await _act(() => widget.state.backend.updateFamilyNotice(userId: widget.state.userId, notice: value), 'Announcement updated');
  }

  Future<void> _contribute() async {
    final input = TextEditingController();
    final value = await showDialog<int>(context: context, builder: (c) => AlertDialog(
      title: const Text('Family wallet contribution'),
      content: TextField(controller: input, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coins')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(input.text.trim())), child: const Text('Contribute'))],
    ));
    input.dispose();
    if (value != null && value > 0) {
      await _act(() => widget.state.backend.sendFamilyCoins(userId: widget.state.userId, amount: value), 'Family wallet credited');
      await widget.state.refreshWallet();
    }
  }
}
