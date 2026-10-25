import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

class IdLevelScreen extends StatefulWidget {
  const IdLevelScreen({super.key, required this.state});

  final AppState state;

  @override
  State<IdLevelScreen> createState() => _IdLevelScreenState();
}

class _IdLevelScreenState extends State<IdLevelScreen> {
  Map<String, dynamic>? status;
  bool loading = true;
  String? error;
  bool claiming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.state.backendConnected) {
      setState(() {
        loading = false;
        error = 'Connect to the server to load ID Level progress.';
      });
      return;
    }
    final response = await widget.state.backend.idLevelStatus(userId: widget.state.userId);
    if (!mounted) return;
    final value = response?['level'];
    setState(() {
      status = value is Map ? Map<String, dynamic>.from(value) : null;
      loading = false;
      error = status == null ? 'Could not load ID Level progress.' : null;
    });
  }

  Future<void> _claim(int level) async {
    if (claiming) return;
    setState(() => claiming = true);
    final result = await widget.state.backend.claimIdLevelReward(
      userId: widget.state.userId,
      level: level,
    );
    if (!mounted) return;
    setState(() => claiming = false);
    if (result?['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Level $level reward claimed')),
      );
      await _load();
    } else {
      final message = result?['error']?.toString() == 'id_level_reward_claimed'
          ? 'This level reward was already claimed.'
          : 'This reward is locked.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = int.tryParse(status?['level']?.toString() ?? '') ?? 0;
    final exp = int.tryParse(status?['exp']?.toString() ?? '') ?? 0;
    final next = int.tryParse(status?['exp_to_next']?.toString() ?? '') ?? 0;
    final total = int.tryParse(status?['total_exp']?.toString() ?? '') ?? 0;
    final progress = next == 0 ? 1.0 : (exp / next).clamp(0.0, 1.0).toDouble();
    final rewards = (status?['rewards'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('ID Level'),
        backgroundColor: Colors.transparent,
        actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error!, textAlign: TextAlign.center),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      _levelCard(level, exp, next, total, progress),
                      const SizedBox(height: 16),
                      _upgradeCard(),
                      const SizedBox(height: 20),
                      const Text('Level rewards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...rewards.map((reward) => _rewardCard(reward)),
                    ],
                  ),
                ),
    );
  }

  Widget _levelCard(int level, int exp, int next, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF442078), Color(0xFF171126), Color(0xFF302047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Color(0x668B7CFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.military_tech_rounded, color: Color(0xFF50D8FF), size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text('LV. $level', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
            Text('$total total EXP', style: const TextStyle(color: Colors.white70)),
          ]),
          const SizedBox(height: 18),
          LinearProgressIndicator(value: progress, minHeight: 9, borderRadius: BorderRadius.circular(20)),
          const SizedBox(height: 8),
          Text(next == 0 ? 'Maximum level reached' : '$exp / $next EXP • ${next - exp} to next level',
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _upgradeCard() {
    return Card(
      color: TinniPalette.panel,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('How to upgrade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          _SourceRow(icon: Icons.card_giftcard_rounded, title: 'Gift coins consumed', detail: '400 coins = 1 EXP'),
          _SourceRow(icon: Icons.meeting_room_rounded, title: 'Enter a room', detail: '70 EXP per day'),
          _SourceRow(icon: Icons.share_rounded, title: 'Share a room', detail: '75 EXP per day'),
          _SourceRow(icon: Icons.flag_rounded, title: 'Participate in activities', detail: 'Activities can speed up the upgrade'),
          _SourceRow(icon: Icons.workspace_premium_rounded, title: 'Aristocracy', detail: 'Membership accelerates the upgrade'),
        ]),
      ),
    );
  }

  Widget _rewardCard(Map<String, dynamic> reward) {
    final level = int.tryParse(reward['level']?.toString() ?? '') ?? 0;
    final unlocked = reward['unlocked'] == true;
    final claimed = reward['claimed'] == true;
    final items = (reward['items'] as List?)?.whereType<Map>().toList() ?? const [];
    return Card(
      color: TinniPalette.panel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: unlocked ? TinniPalette.brightGold : Colors.white38),
            const SizedBox(width: 8),
            Expanded(child: Text('Level $level', style: const TextStyle(fontWeight: FontWeight.w800))),
            if (claimed) const Chip(label: Text('Claimed'))
            else if (unlocked)
              TextButton(onPressed: claiming ? null : () => _claim(level), child: const Text('Claim'))
            else
              const Text('Locked', style: TextStyle(color: Colors.white54)),
          ]),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: items.map((item) => Chip(
              avatar: Icon(_rewardIcon(item['kind']?.toString() ?? ''), size: 16),
              label: Text(item['label']?.toString() ?? 'Reward'),
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ]),
      ),
    );
  }

  IconData _rewardIcon(String kind) => switch (kind) {
        'medal' => Icons.workspace_premium_rounded,
        'frame' => Icons.filter_frames_rounded,
        'vehicle' => Icons.directions_car_filled_rounded,
        _ => Icons.card_giftcard_rounded,
      };
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: TinniPalette.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
          Text(detail, style: const TextStyle(color: Color(0xFF50D8FF), fontSize: 12)),
        ]),
      );
}
