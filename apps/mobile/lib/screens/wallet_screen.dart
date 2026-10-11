import 'package:flutter/material.dart';

import '../app/app_state.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Wallet',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: state.backendConnected ? state.refreshWallet : null,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh wallet',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceCard(
                  icon: '🪙',
                  label: 'Coins',
                  value: state.coins.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceCard(
                  icon: '💎',
                  label: 'Diamonds',
                  value: state.diamonds.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.receipt_long_rounded),
                  title: Text('Recent transactions'),
                ),
                if (state.walletLedger.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No synced transactions yet.'),
                    ),
                  )
                else
                  for (final row in state.walletLedger.take(6))
                    ListTile(
                      dense: true,
                      title: Text(row['kind']?.toString() ?? 'transaction'),
                      subtitle: Text(
                        'Balance: ${row['balance_after'] ?? '-'}',
                      ),
                      trailing: Text(
                        '${int.tryParse(row['amount']?.toString() ?? '') ?? 0}',
                      ),
                    ),
              ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 12),
          Text(label),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
