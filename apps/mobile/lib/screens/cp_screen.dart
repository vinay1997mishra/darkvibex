import 'package:flutter/material.dart';

import '../app/app_state.dart';

class CpScreen extends StatefulWidget {
  const CpScreen({super.key, required this.state});
  final AppState state;
  @override
  State<CpScreen> createState() => _CpScreenState();
}

class _CpScreenState extends State<CpScreen> {
  bool loading = true, working = false;
  Map<String, dynamic>? cp, partner;
  List<Map<String, dynamic>> memories = [], ranking = [];
  final target = TextEditingController(), memoryText = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { target.dispose(); memoryText.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final result = await widget.state.backend.cpState(userId: widget.state.userId);
    final raw = result?['cp'];
    final nextCp = raw is Map ? Map<String, dynamic>.from(raw) : null;
    var nextPartner;
    var nextMemories = <Map<String, dynamic>>[];
    if (nextCp != null) {
      final otherId = nextCp['user_a']?.toString() == widget.state.userId
          ? nextCp['user_b']?.toString()
          : nextCp['user_a']?.toString();
      if (otherId?.isNotEmpty == true) nextPartner = await widget.state.backend.userProfile(userId: otherId!);
      if (nextCp['state'] == 'accepted') nextMemories = await widget.state.backend.cpMemories(userId: widget.state.userId);
    }
    final nextRanking = await widget.state.backend.cpRanking(limit: 30);
    if (!mounted) return;
    setState(() {
      cp = nextCp;
      partner = nextPartner is Map && nextPartner['user'] is Map ? Map<String, dynamic>.from(nextPartner['user']) : null;
      memories = nextMemories;
      ranking = nextRanking;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CP Nest')),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (cp == null) _requestCard() else if (cp!['state'] == 'pending') _pendingCard() else if (cp!['state'] == 'accepted') _activeCard() else _requestCard(),
        const SizedBox(height: 20),
        const Text('CP Ranking', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (ranking.isEmpty) const ListTile(title: Text('No active CP pairs yet')),
        for (var i = 0; i < ranking.length; i++)
          ListTile(
            leading: CircleAvatar(child: Text((i + 1).toString())),
            title: Text((ranking[i]['user_a_name']?.toString() ?? 'User') + ' ♥ ' + (ranking[i]['user_b_name']?.toString() ?? 'User')),
            subtitle: Text('Lv.' + (ranking[i]['level']?.toString() ?? '1') + ' • ' + (ranking[i]['intimacy']?.toString() ?? '0') + ' intimacy'),
          ),
      ]),
    ),
  );

  Widget _requestCard() => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Bind with CP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Send a CP request by the other person’s public ID. Both people can have only one active or pending CP flow.'),
      const SizedBox(height: 12),
      TextField(controller: target, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'User ID')),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: working || target.text.trim().isEmpty ? null : () => _act(
          () => widget.state.backend.cpRequest(userId: widget.state.userId, targetUserId: target.text.trim()),
          'CP request sent',
        ),
        icon: const Icon(Icons.favorite_rounded),
        label: const Text('Send CP request'),
      ),
    ]),
  ));

  Widget _pendingCard() {
    final mine = cp?['requested_by']?.toString() == widget.state.userId;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mine ? 'CP request sent' : 'CP request received', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('ID ' + (partner?['id']?.toString() ?? '')),
        if (mine) const Text('Waiting for the other person to respond.'),
        if (!mine) Wrap(spacing: 8, children: [
          FilledButton(onPressed: working ? null : () => _act(() => widget.state.backend.cpRespond(userId: widget.state.userId, accept: true), 'CP request accepted'), child: const Text('Accept')),
          OutlinedButton(onPressed: working ? null : () => _act(() => widget.state.backend.cpRespond(userId: widget.state.userId, accept: false), 'CP request declined'), child: const Text('Decline')),
        ]),
      ]),
    ));
  }

  Widget _activeCard() {
    final exp = int.tryParse(cp?['intimacy']?.toString() ?? '') ?? 0;
    final ring = cp?['ring_id']?.toString() ?? '';
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(child: Icon(Icons.person_rounded)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.favorite_rounded, color: Colors.pinkAccent)),
          CircleAvatar(child: Text((partner?['display_name']?.toString().isNotEmpty == true ? partner!['display_name'].toString()[0] : 'U').toUpperCase())),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(partner?['display_name']?.toString() ?? 'CP partner', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('ID ' + (partner?['id']?.toString() ?? '')),
          ])),
        ]),
        const Divider(height: 24),
        Text('CP Level ' + (cp?['level']?.toString() ?? '1') + ' • ' + exp.toString() + ' intimacy'),
        const SizedBox(height: 6),
        const LinearProgressIndicator(value: 0),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.diamond_outlined), title: const Text('CP Ring'), subtitle: Text(ring.isEmpty ? 'No ring equipped' : ring)),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(onPressed: _addMemory, icon: const Icon(Icons.auto_awesome), label: const Text('Add memory')),
          OutlinedButton.icon(onPressed: _showMemories, icon: const Icon(Icons.collections_bookmark_outlined), label: Text('Memories (' + memories.length.toString() + ')')),
          OutlinedButton.icon(onPressed: _selectRing, icon: const Icon(Icons.diamond_rounded), label: const Text('Set ring ID')),
        ]),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: working ? null : _disconnect, icon: const Icon(Icons.link_off_rounded), label: const Text('Disconnect CP')),
      ]),
    ));
  }

  Future<void> _addMemory() async {
    final input = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Add CP memory'),
      content: TextField(controller: input, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'Write a memory')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, input.text.trim()), child: const Text('Save'))],
    ));
    input.dispose();
    if (value != null && value.isNotEmpty) await _act(() => widget.state.backend.cpAddMemory(userId: widget.state.userId, text: value), 'Memory saved');
  }

  Future<void> _showMemories() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .6,
          child: memories.isEmpty
              ? const Center(child: Text('No CP memories yet'))
              : ListView(
                  children: [
                    for (final memory in memories)
                      ListTile(
                        leading: const Icon(Icons.favorite_border),
                        title: Text(memory['text']?.toString() ?? ''),
                        subtitle: Text(memory['display_name']?.toString() ?? 'CP'),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _selectRing() async {
    final input = TextEditingController(text: cp?['ring_id']?.toString() ?? '');
    final value = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Equip CP ring'),
      content: TextField(controller: input, maxLength: 100, decoration: const InputDecoration(labelText: 'Ring item ID')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, input.text.trim()), child: const Text('Save'))],
    ));
    input.dispose();
    if (value != null && value.isNotEmpty) await _act(() => widget.state.backend.cpUpdate(userId: widget.state.userId, action: 'ring', ringId: value), 'Ring updated');
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Disconnect CP?'),
      content: const Text('This ends the current CP relationship.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Disconnect'))],
    ));
    if (ok == true) await _act(() => widget.state.backend.cpDisconnect(userId: widget.state.userId), 'CP disconnected');
  }
}
