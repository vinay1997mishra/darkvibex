import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'wallet_detail_screens.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.state});

  final AppState state;

  Future<void> _openRoleWallet(BuildContext context) async {
    final role = state.userRole;
    if (role != 'coin_seller' && role != 'merchant') return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoleWalletDetailScreen(
          state: state,
          walletType: role,
        ),
      ),
    );
    await state.refreshWallet();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(
          title: const Text(
            'Wallet',
            style: TextStyle(
              color: TinniPalette.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed:
                  state.backendConnected ? state.refreshWallet : null,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh wallet',
            ),
          ],
        ),
        body: TinniBackground(
          child: RefreshIndicator(
            onRefresh: state.refreshWallet,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(14),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BalanceCard(
                        key: const Key('wallet-coins-card'),
                        icon: Icons.monetization_on_rounded,
                        label: 'Coins',
                        value: state.coins.toString(),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CoinsHistoryScreen(state: state),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BalanceCard(
                        key: const Key('wallet-diamonds-card'),
                        icon: Icons.diamond_rounded,
                        label: 'Diamonds',
                        value: state.diamonds.toString(),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DiamondsWalletScreen(state: state),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.userRole == 'coin_seller' ||
                    state.userRole == 'merchant') ...[
                  const SizedBox(height: 10),
                  TinniPanel(
                    onTap: () => _openRoleWallet(context),
                    child: Row(
                      children: [
                        TinniGlowIcon(
                          icon: state.userRole == 'merchant'
                              ? Icons.storefront_rounded
                              : Icons.currency_exchange_rounded,
                          size: 24,
                          boxSize: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.userRole == 'merchant'
                                    ? 'Merchant Wallet'
                                    : 'Coin Seller Wallet',
                                style: const TextStyle(
                                  color: TinniPalette.gold,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                state.userRole == 'merchant'
                                    ? 'Separate merchant coins, USD and permanent ledger'
                                    : 'Separate seller coins, USD, PIN and permanent ledger',
                                style: const TextStyle(
                                  color: TinniPalette.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TinniPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(
                          Icons.receipt_long_rounded,
                          color: TinniPalette.gold,
                        ),
                        title: Text(
                          'Recent transactions',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (state.walletLedger.isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child:
                                Text('No synced transactions yet.'),
                          ),
                        )
                      else
                        for (final row in state.walletLedger.take(20))
                          ListTile(
                            dense: true,
                            leading: Icon(
                              (int.tryParse(
                                            row['amount']
                                                    ?.toString() ??
                                                '',
                                          ) ??
                                          0) >=
                                      0
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              size: 18,
                              color: TinniPalette.gold,
                            ),
                            title: Text(
                              row['kind']?.toString() ??
                                  'transaction',
                            ),
                            subtitle: Text(
                              'Balance: ${row['balance_after'] ?? '-'}',
                            ),
                            trailing: Text(
                              '${int.tryParse(row['amount']?.toString() ?? '') ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const TinniPanel(
                  child: Text(
                    'Normal Coins, Diamonds, Coin Seller coins, Merchant coins and role USD balances stay separate. Role USD never auto-converts to Coins.',
                    style: TextStyle(
                      color: TinniPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TinniPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: SizedBox(
        height: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TinniGlowIcon(icon: icon, size: 20, boxSize: 36),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                color: TinniPalette.muted,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TinniPalette.gold,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
