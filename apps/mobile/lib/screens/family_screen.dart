import 'package:flutter/material.dart';

import '../app/app_state.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  Map<String, dynamic>? family;
  List<Map<String, dynamic>> members = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await widget.state.backend.family(widget.state.userId);
    final rawFamily = value?['family'];
    final rawMembers = value?['members'];
    if (!mounted) return;
    setState(() {
      family = rawFamily is Map ? Map<String, dynamic>.from(rawFamily) : null;
      members = rawMembers is List
          ? rawMembers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [];
      loading = false;
    });
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Family'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Family name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final result = await widget.state.backend.createFamily(userId: widget.state.userId, name: name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result == null ? 'Could not create family' : 'Family created')));
    await _load();
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final familyId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Family'),
        content: TextField(controller: controller, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Family ID')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Join')),
        ],
      ),
    );
    controller.dispose();
    if (familyId == null || familyId.isEmpty) return;
    final result = await widget.state.backend.joinFamily(userId: widget.state.userId, familyId: familyId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result == null ? 'Could not join family' : 'Joined family')));
    await _load();
  }

  Future<void> _signIn() async {
    final result = await widget.state.backend.familySignIn(widget.state.userId);
    if (!mounted) return;
    final added = int.tryParse(result?['experience_added']?.toString() ?? '') ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(added > 0 ? 'Family sign-in +$added EXP' : 'Already signed in today')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : family == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.family_restroom_rounded, size: 72, color: Color(0xFFFFD36A)),
                        const SizedBox(height: 14),
                        const Text('Create a family or join with a Family ID.', textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('Create Family')),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(onPressed: _join, icon: const Icon(Icons.group_add_rounded), label: const Text('Join Family')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(family!['name']?.toString() ?? 'Family', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            Text('ID ${family!['id']} • Level ${family!['level']}'),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: ((Number.parse(family!['experience']?.toString() ?? '0') % 5000) / 5000).clamp(0, 1)),
                            const SizedBox(height: 6),
                            Text('${family!['experience']} EXP'),
                            const SizedBox(height: 12),
                            FilledButton.icon(onPressed: _signIn, icon: const Icon(Icons.event_available_rounded), label: const Text('Daily family sign-in')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    for (final member in members)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text((member['display_name']?.toString() ?? '?').characters.first.toUpperCase())),
                          title: Text(member['display_name']?.toString() ?? member['user_id']?.toString() ?? 'User'),
                          subtitle: Text('ID ${member['user_id']} • VIP ${member['vip_level'] ?? 0}'),
                          trailing: Chip(label: Text(member['role']?.toString().toUpperCase() ?? 'MEMBER')),
                        ),
                      ),
                  ],
                ),
    );
  }
}
