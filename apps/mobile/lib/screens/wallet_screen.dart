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
          const Text('Wallet', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
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
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: const Text('Transaction history'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storefront_rounded),
                  title: const Text('Coin Seller'),
                  subtitle: const Text('Seller wallet and transfers'),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded),
                  title: const Text('Merchant'),
                  subtitle: const Text('Merchant settlement wallet'),
                  onTap: () {},
                ),
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
