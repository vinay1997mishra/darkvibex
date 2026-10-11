import 'package:flutter/material.dart';

import '../app/app_state.dart';

class VipScreen extends StatelessWidget {
  const VipScreen({super.key, required this.state});

  final AppState state;

  static const List<int> levels = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD36A);
    final currentLevel = state.vipLevel.clamp(1, 11);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VIP', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF2A1F12), Color(0xFF111217)],
              ),
              border: Border.all(color: const Color(0x66FFD36A)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x22FFD36A),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: gold, size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DarkVibeX VIP',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Current level: VIP $currentLevel',
                        style: const TextStyle(color: gold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final level in levels) ...[
            _VipLevelCard(level: level, currentLevel: currentLevel),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Text(
            'VIP 1 to VIP 11 levels are ready. Benefits, pricing and upgrade rules are not active on this page.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: .55),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipLevelCard extends StatelessWidget {
  const _VipLevelCard({required this.level, required this.currentLevel});

  final int level;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final isCurrent = level == currentLevel;
    final isReached = level < currentLevel;
    const gold = Color(0xFFFFD36A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF251E12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? gold : Colors.white12,
          width: isCurrent ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? const Color(0x22FFD36A)
                  : Colors.white.withValues(alpha: .05),
              border: Border.all(color: isCurrent ? gold : Colors.white24),
            ),
            child: Text(
              '$level',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: isCurrent ? gold : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIP $level',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isCurrent
                      ? 'Current VIP level'
                      : isReached
                          ? 'Level reached'
                          : 'VIP level $level',
                  style: TextStyle(
                    color: isCurrent ? gold : Colors.white.withValues(alpha: .6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isCurrent
                ? Icons.workspace_premium_rounded
                : isReached
                    ? Icons.check_circle_rounded
                    : Icons.lock_outline_rounded,
            color: isCurrent
                ? gold
                : isReached
                    ? Colors.greenAccent
                    : Colors.white38,
          ),
        ],
      ),
    );
  }
}
