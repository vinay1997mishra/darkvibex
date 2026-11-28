import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../app/app_state.dart';
import '../infra/play_billing.dart';
import '../ui/tinni_style.dart';
import '../ui/currency_badge.dart';
import '../utils/public_user_id.dart';
import 'conversation_screen.dart';
import 'wallet_detail_screens.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key, required this.state, this.playBilling});

  final AppState state;

  /// Test seam: the widget tests inject a fake store here. Production
  /// call sites leave it null and the real Play Billing service is used.
  final PlayBillingService? playBilling;

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  bool loading = true;
  List<Map<String, dynamic>> providers = const <Map<String, dynamic>>[];

  late final PlayBillingService _billing;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// Product ID of the pack whose purchase is in flight, if any.
  String? _buyingProductId;

  /// Purchase tokens currently being verified with the server, so a
  /// purchase the stream delivers twice is never verified twice.
  final Set<String> _verifyingTokens = <String>{};

  /// Purchase IDs already shown a "payment pending" notice for.
  final Set<String> _pendingNotified = <String>{};

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _billing = widget.playBilling ?? PlayBillingService();
    _purchaseSub = _billing.purchaseStream.listen(
      _onPurchases,
      onError: (_) {},
    );
    _load();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _billing.dispose();
    super.dispose();
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
    // Billing loads in the background: the packs render immediately
    // (unavailable until the store answers) and enable themselves
    // once availability + prices arrive. A device without Play
    // Billing must never stare at a spinner while the store times out.
    await _billing.init(state.backend);
    // Replay unfinished past purchases onto the purchase stream so a
    // purchase interrupted before verification is processed now.
    await _billing.restore();
    if (!mounted) return;
    setState(() {});
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

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static String _formatCoins(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );

  Future<void> _buyPack(PlayPack pack) async {
    if (_buyingProductId != null) return;
    if (!_billing.available || !_billing.prices.containsKey(pack.productId)) {
      _notice('In-app purchases are not available on this device.');
      return;
    }
    setState(() => _buyingProductId = pack.productId);
    bool started = false;
    try {
      started = await _billing.buy(pack.productId);
    } catch (_) {
      started = false;
    }
    if (!mounted) return;
    if (!started) {
      // The store refused to start the purchase; nothing is in flight.
      setState(() => _buyingProductId = null);
      _notice('Could not start the purchase. Please try again.');
    }
    // When started, the purchase stream drives the rest: the buying
    // state resets when the purchase completes, errors, or is canceled.
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          unawaited(_handlePurchased(purchase));
        case PurchaseStatus.pending:
          final purchaseId = purchase.purchaseID ?? purchase.productID;
          if (_pendingNotified.add(purchaseId)) {
            _notice('Payment is pending. Your coins will arrive once it completes.');
          }
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            unawaited(_billing.complete(purchase));
          }
          if (_buyingProductId == purchase.productID) {
            setState(() => _buyingProductId = null);
          }
          final errorMessage = purchase.error?.message.trim() ?? '';
          _notice(
            errorMessage.isNotEmpty
                ? errorMessage
                : 'Purchase failed. Please try again.',
          );
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            unawaited(_billing.complete(purchase));
          }
          if (_buyingProductId == purchase.productID) {
            setState(() => _buyingProductId = null);
          }
          _notice('Purchase canceled.');
      }
    }
  }

  Future<void> _handlePurchased(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      _notice('Could not verify your purchase. Please try again.');
      return;
    }
    if (!_verifyingTokens.add(token)) return;
    try {
      final result = await state.backend.verifyPlayPurchase(
        productId: purchase.productID,
        purchaseToken: token,
      );
      if (result == null || result['ok'] != true) {
        // Do NOT complete the purchase: it stays unfinished and the
        // stream re-delivers it, so the user is never charged for
        // coins they did not receive.
        _notice('Could not verify your purchase. Please try again.');
        return;
      }
      await _billing.complete(purchase);
      if (_billing.firstRechargeAvailable &&
          result['first_recharge'] == true &&
          mounted) {
        setState(() => _billing.firstRechargeAvailable = false);
      }
      await state.refreshWallet();
      if (!mounted) return;
      final credited =
          int.tryParse(result['coins_credited']?.toString() ?? '') ?? 0;
      final bonus =
          int.tryParse(result['bonus_coins']?.toString() ?? '') ?? 0;
      final firstRecharge = result['first_recharge'] == true;
      // Amounts show in dollars only, everywhere in the app (Vinay,
      // 2026-11-21): no rupee amount is ever shown here, even though
      // the Play sheet itself charges in rupees. The notice only
      // states the coins.
      final message = StringBuffer('${_formatCoins(credited)} coins added to your wallet!');
      if (bonus > 0) {
        message.write(' Includes ${_formatCoins(bonus)} first-recharge bonus coins.');
      }
      if (firstRecharge) {
        message.write(' VIP1 unlocked for 10 days!');
      }
      _notice(message.toString());
    } finally {
      _verifyingTokens.remove(token);
      if (mounted && _buyingProductId == purchase.productID) {
        setState(() => _buyingProductId = null);
      }
    }
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
      backgroundColor: Colors.transparent,
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
                                const CurrencyBadge(
                                  icon: Icons.monetization_on_rounded,
                                  isDiamond: false,
                                  size: 38,
                                ),
                                const SizedBox(height: 6),
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
                                    color: TinniPalette.brightGold,
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
                            key: const Key('recharge-diamonds-card'),
                            onTap: () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DiamondsWalletScreen(state: state),
                                ),
                              );
                              if (mounted) await state.refreshWallet();
                            },
                            child: Column(
                              children: [
                                const CurrencyBadge(
                                  icon: Icons.diamond_rounded,
                                  isDiamond: true,
                                  size: 38,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Diamonds',
                                      style: TextStyle(
                                        color: TinniPalette.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: TinniPalette.gold,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  state.diamonds.toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF8DEBFF),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Tap to exchange',
                                  style: TextStyle(
                                    color: TinniPalette.muted,
                                    fontSize: 9,
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
                      'Buy Coins',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_billing.firstRechargeAvailable)
                      Container(
                        key: const Key('recharge-first-recharge-badge'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: TinniPalette.brightGold,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'First recharge: DOUBLE coins + VIP1 for 10 days',
                          style: TextStyle(
                            color: TinniPalette.brightGold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    if (!_billing.available)
                      const TinniPanel(
                        child: Text(
                          'In-app purchases are not available on this device.',
                          style: TextStyle(color: TinniPalette.muted),
                        ),
                      ),
                    for (final pack in PlayBillingService.packs)
                      _PackTile(
                        pack: pack,
                        price: _billing.prices[pack.productId]?.price,
                        buying: _buyingProductId == pack.productId,
                        buyingAny: _buyingProductId != null,
                        enabled: _billing.available,
                        onBuy: () => _buyPack(pack),
                      ),
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

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.pack,
    required this.price,
    required this.buying,
    required this.buyingAny,
    required this.enabled,
    required this.onBuy,
  });

  final PlayPack pack;

  /// Localized Play storefront price (e.g. "₹110.00"). The button
  /// shows the pack's $ label ($1 / $2 / $5 / $10, Vinay 2026-11-21) — the
  /// storefront price is only used to know the store has the pack,
  /// and the rupee amount is what the payment sheet charges.
  /// Null while the store has not returned it yet.
  final String? price;
  final bool buying;
  final bool buyingAny;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final canBuy = enabled && price != null && !buyingAny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TinniPanel(
        child: Row(
          children: [
            const CurrencyBadge(
              icon: Icons.monetization_on_rounded,
              isDiamond: false,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_RechargeScreenState._formatCoins(pack.coins)} coins',
                style: const TextStyle(
                  color: TinniPalette.cream,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton(
              key: Key('recharge-pack-${pack.productId}'),
              onPressed: canBuy ? onBuy : null,
              child: buying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(pack.usdLabel),
            ),
          ],
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
                    roleLabel + ' • ID ' + formatPublicUserId(row['public_id']),
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
