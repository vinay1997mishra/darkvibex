import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../features/catalog_models.dart';

class RelationshipsScreen extends StatefulWidget {
  const RelationshipsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<RelationshipsScreen> createState() => _RelationshipsScreenState();
}

class _RelationshipsScreenState extends State<RelationshipsScreen> {
  final otherId = TextEditingController();
  RelationshipProgress? cp;
  RelationshipProgress? enemy;
  bool loading = false;

  @override
  void dispose() {
    otherId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = otherId.text.trim();
    if (id.isEmpty) return;
    setState(() => loading = true);
    final value = await widget.state.backend.relationships(userA: widget.state.userId, userB: id);
    if (!mounted) return;
    final rawCp = value?['cp'];
    final rawEnemy = value?['enemy'];
    setState(() {
      cp = rawCp is Map ? RelationshipProgress.fromMap(Map<String, dynamic>.from(rawCp)) : null;
      enemy = rawEnemy is Map ? RelationshipProgress.fromMap(Map<String, dynamic>.from(rawEnemy)) : null;
      loading = false;
    });
  }

  String amount(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  Widget card(RelationshipProgress value, bool rivalry) {
    final next = value.nextThreshold;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(rivalry ? '⚔️' : '💞', style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rivalry ? 'Enemy Level ${value.level}' : 'CP Level ${value.level}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: value.fraction, minHeight: 9),
            const SizedBox(height: 8),
            Text('${amount(value.progress)} confirmed gift progress'),
            Text(next == null ? 'Maximum level reached' : '${amount(next - value.progress)} to next level'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CP & Enemy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: otherId,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'Other user ID',
              suffixIcon: IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.search_rounded)),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 14),
          const Text('CP level grows only from CP gifts. Enemy level grows only from Enemy gifts. Both systems stay completely independent.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (cp != null) card(cp!, false),
          if (enemy != null) card(enemy!, true),
        ],
      ),
    );
  }
}
