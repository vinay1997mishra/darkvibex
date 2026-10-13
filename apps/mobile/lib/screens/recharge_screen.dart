import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'conversation_screen.dart';
import 'wallet_detail_screens.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  bool loading = true;
  List<Map<String, dynamic>> providers = const <Map<String, dynamic>>[];

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (state.backendConnected) {
      await state.refreshWallet(notify: false);
      providers = await state.backend.rechargeProviders();
    } else {
      providers = const <Map<String, dynamic>>[];
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  String _roleLabel(String role) =>
      role == 'merchant' ? 'Merchant' : 'Coin Seller';

  Future<void> _openProvider(Map<String, dynamic> row) async {
    final id = row['user_id']?.toString() ?? '';
    if (id.isEmpty || id == state.userId) return;
    final name = row['display_name']?.toString().trim();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          state: state,
          otherUserId: id,
          otherName: name == null || name.isEmpty ? _roleLabel(row['role']?.toString() ?? '') : name,
        ),
      ),
    );
  }

  Future<void> _openOwnRoleWallet() async {
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
    final ownRoleWallet =
        state.userRole == 'coin_seller' || state.userRole == 'merchant';
    final coinSellers = providers
        .where((row) => row['role']?.toString() == 'coin_seller')
        .toList(growable: false);
    final merchants = providers
        .where((row) => row['role']?.toString() == 'merchant')
        .toList(growable: false);

    return Scaffold(
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
            onPressed: loading
                ? null
                : () {
                    setState(() => loading = true);
                    _load();
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TinniBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TinniPanel(
                            child: Column(
                              children: [
                                const Text(
                                  'Coins',
                                  style: TextStyle(
                                    color: TinniPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  state.coins.toString(),
                                  style: const TextStyle(
                                    color: TinniPalette.gold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TinniPanel(
                            child: Column(
                              children: [
                                const Text(
                                  'Diamonds',
                                  style: TextStyle(
                                    color: TinniPalette.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  state.diamonds.toString(),
                                  style: const TextStyle(
                                    color: TinniPalette.gold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ownRoleWallet) ...[
                      const SizedBox(height: 10),
                      TinniPanel(
                        onTap: _openOwnRoleWallet,
                        child: Row(
                          children: [
                            const TinniGlowIcon(
                              icon: Icons.account_balance_wallet_rounded,
                              size: 22,
                              boxSize: 42,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _roleLabel(state.userRole) + ' Wallet',
                                    style: const TextStyle(
                                      color: TinniPalette.gold,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const Text(
                                    'Open secured role wallet and coin transfers.',
                                    style: TextStyle(
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
                    const SizedBox(height: 16),
                    const Text(
                      'Coin Sellers',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (coinSellers.isEmpty)
                      const TinniPanel(
                        child: Text(
                          'No active Coin Seller is available right now.',
                          style: TextStyle(color: TinniPalette.muted),
                        ),
                      )
                    else
                      for (final row in coinSellers)
                        _ProviderTile(
                          state: state,
                          row: row,
                          roleLabel: 'Coin Seller',
                          onMessage: () => _openProvider(row),
                        ),
                    const SizedBox(height: 16),
                    const Text(
                      'Merchants',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (merchants.isEmpty)
                      const TinniPanel(
                        child: Text(
                          'No active Merchant is available right now.',
                          style: TextStyle(color: TinniPalette.muted),
                        ),
                      )
                    else
                      for (final row in merchants)
                        _ProviderTile(
                          state: state,
                          row: row,
                          roleLabel: 'Merchant',
                          onMessage: () => _openProvider(row),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.state,
    required this.row,
    required this.roleLabel,
    required this.onMessage,
  });

  final AppState state;
  final Map<String, dynamic> row;
  final String roleLabel;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final id = row['user_id']?.toString() ?? '';
    final name = row['display_name']?.toString().trim();
    final avatar = row['avatar_key']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TinniPanel(
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundImage: avatar.isEmpty
                  ? null
                  : NetworkImage(
                      state.backend.fileUrl(avatar),
                      headers: state.backend.fileHeaders,
                    ),
              child: avatar.isEmpty
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name == null || name.isEmpty ? roleLabel : name,
                    style: const TextStyle(
                      color: TinniPalette.cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    roleLabel + ' • ID ' + id,
                    style: const TextStyle(
                      color: TinniPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_rounded),
              label: const Text('Message'),
            ),
          ],
        ),
      ),
    );
  }
}
