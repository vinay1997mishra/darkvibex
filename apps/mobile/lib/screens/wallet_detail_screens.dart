import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import '../utils/diamond_exchange.dart';

int _walletInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

List<Map<String, dynamic>> _walletRows(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

String _walletNumber(int value) {
  final text = value.toString();
  return text.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

String _walletDateTime(int milliseconds) {
  if (milliseconds <= 0) return '—';
  final value =
      DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}


class CoinsHistoryScreen extends StatefulWidget {
  const CoinsHistoryScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CoinsHistoryScreen> createState() => _CoinsHistoryScreenState();
}

class _CoinsHistoryScreenState extends State<CoinsHistoryScreen> {
  bool loading = true;
  Map<String, dynamic> data = const {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final value = await widget.state.backend.coinsHistory(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() {
      data = value ?? const {};
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gifts = _walletRows(data['gifts']);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Coins History')),
      body: TinniBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  children: [
                    TinniPanel(
                      child: Row(
                        children: [
                          const TinniGlowIcon(
                            icon: Icons.monetization_on_rounded,
                            size: 24,
                            boxSize: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Coins',
                                  style: TextStyle(
                                    color: TinniPalette.muted,
                                  ),
                                ),
                                Text(
                                  _walletNumber(
                                    _walletInt(data['current_coins']),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: TinniPalette.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SellerReceivedCoinsScreen(
                                  state: widget.state,
                                ),
                              ),
                            ),
                            child: const Text('Seller Received'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gift Sent',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (gifts.isEmpty)
                      const TinniPanel(child: Text('No gift history.'))
                    else
                      for (final row in gifts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TinniPanel(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.card_giftcard_rounded,
                                color: TinniPalette.gold,
                              ),
                              title: Text(
                                row['gift_id']?.toString() ?? 'Gift',
                              ),
                              subtitle: Text(
                                '${row['receiver_name'] ?? row['receiver_user_id']} • '
                                'ID ${row['receiver_user_id'] ?? ''}\n'
                                '${_walletDateTime(_walletInt(row['created_at']))}',
                              ),
                              trailing: Text(
                                '-${_walletNumber(_walletInt(row['coins']))}',
                                style: const TextStyle(
                                  color: TinniPalette.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class SellerReceivedCoinsScreen extends StatefulWidget {
  const SellerReceivedCoinsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SellerReceivedCoinsScreen> createState() =>
      _SellerReceivedCoinsScreenState();
}

class _SellerReceivedCoinsScreenState
    extends State<SellerReceivedCoinsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final value = await widget.state.backend.coinsHistory(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() {
      rows = _walletRows(value?['seller_received']);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Coins Received')),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    children: rows.isEmpty
                        ? const [
                            TinniPanel(
                              child: Text('No seller transfers.'),
                            ),
                          ]
                        : [
                            for (final row in rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TinniPanel(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      row['wallet_type'] == 'merchant'
                                          ? 'Merchant'
                                          : 'Coin Seller',
                                    ),
                                    subtitle: Text(
                                      _walletDateTime(
                                        _walletInt(row['created_at']),
                                      ),
                                    ),
                                    trailing: Text(
                                      '+${_walletNumber(_walletInt(row['coins']))}',
                                      style: const TextStyle(
                                        color: TinniPalette.gold,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                  ),
                ),
        ),
      );
}

class DiamondsWalletScreen extends StatefulWidget {
  const DiamondsWalletScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DiamondsWalletScreen> createState() =>
      _DiamondsWalletScreenState();
}

class _DiamondsWalletScreenState extends State<DiamondsWalletScreen> {
  bool loading = true;
  bool converting = false;
  Map<String, dynamic> data = const {};
  final TextEditingController _exchangeAmountController =
      TextEditingController();

  int get _exchangeAmount =>
      int.tryParse(_exchangeAmountController.text.trim()) ?? 0;

  int get _exchangeCoins =>
      DiamondExchange.coinsForDiamonds(_exchangeAmount);

  bool get _canExchange {
    final available = _walletInt(data['current_diamonds']);
    return !loading &&
        !converting &&
        DiamondExchange.isExactAmount(_exchangeAmount) &&
        _exchangeAmount <= available &&
        _exchangeCoins > 0;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _exchangeAmountController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final value = await widget.state.backend.diamondsHistory(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() {
      data = value ?? const {};
      loading = false;
    });
  }

  Future<void> convert() async {
    final amount = _exchangeAmount;
    final available = _walletInt(data['current_diamonds']);
    if (!DiamondExchange.isExactAmount(amount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a multiple of 5 diamonds for an exact 60% exchange.'),
        ),
      );
      return;
    }
    if (amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough diamonds.')),
      );
      return;
    }
    if (!_canExchange) return;

    setState(() => converting = true);
    Map<String, dynamic>? result;
    try {
      result = await widget.state.backend.convertDiamonds(
        userId: widget.state.userId,
        diamonds: amount,
      );
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    setState(() {
      converting = false;
      if (result?['ok'] == true) _exchangeAmountController.clear();
    });

    if (result?['ok'] == true) {
      final coins = _walletInt(result?['current_coins']);
      final diamonds = _walletInt(result?['current_diamonds']);
      widget.state.setCoinBalance(coins);
      widget.state.setDiamondBalance(diamonds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$amount diamonds exchanged for ${result?['coins'] ?? _exchangeCoins} coins.',
          ),
        ),
      );
      await load();
      return;
    }

    final error = result?['error']?.toString() ?? '';
    final message = error == 'insufficient_diamonds'
        ? 'Not enough diamonds.'
        : error == 'diamonds_must_be_multiple_of_5'
            ? 'Exchange amount must be a multiple of 5 diamonds.'
            : 'Diamond exchange failed. Check your connection and try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversions = _walletRows(data['conversions']);
    final gifts = _walletRows(data['gifts']);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Diamonds')),
      body: TinniBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  children: [
                    TinniPanel(
                      child: Row(
                        children: [
                          const TinniGlowIcon(
                            icon: Icons.diamond_rounded,
                            size: 24,
                            boxSize: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Diamonds'),
                                Text(
                                  _walletNumber(
                                    _walletInt(data['current_diamonds']),
                                  ),
                                  style: const TextStyle(
                                    color: TinniPalette.gold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TinniPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const TinniGlowIcon(
                                icon: Icons.currency_exchange_rounded,
                                size: 22,
                                boxSize: 44,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Exchange Diamonds to Coins',
                                      style: TextStyle(
                                        color: TinniPalette.gold,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Rate: 100 Diamonds = 60 Coins (60%)',
                                      style: TextStyle(
                                        color: TinniPalette.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _exchangeAmountController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(12),
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Diamonds to exchange',
                              hintText: 'e.g. 100',
                              helperText:
                                  'Use multiples of 5 so the 60% rate converts to whole coins.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: TinniPalette.gold.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: TinniPalette.gold.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'You will receive',
                                    style: TextStyle(
                                      color: TinniPalette.muted,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_walletNumber(_exchangeCoins)} Coins',
                                  style: const TextStyle(
                                    color: TinniPalette.gold,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _canExchange ? convert : null,
                              icon: converting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.currency_exchange_rounded),
                              label: Text(
                                converting ? 'Exchanging...' : 'Exchange Now',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Received from gifts',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (gifts.isEmpty)
                      const TinniPanel(child: Text('No diamond gift history.'))
                    else
                      for (final row in gifts.take(50))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: TinniPanel(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                row['sender_name']?.toString() ?? 'User',
                              ),
                              subtitle: Text(
                                'ID ${row['sender_user_id'] ?? ''} • '
                                '${_walletDateTime(_walletInt(row['created_at']))}',
                              ),
                              trailing: Text(
                                '+${_walletNumber(_walletInt(row['diamonds']))}',
                                style: const TextStyle(
                                  color: TinniPalette.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 15),
                    const Text(
                      'Conversion History',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (conversions.isEmpty)
                      const TinniPanel(child: Text('No conversions.'))
                    else
                      for (final row in conversions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: TinniPanel(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${_walletNumber(_walletInt(row['diamonds']))} Diamonds',
                              ),
                              subtitle: Text(
                                _walletDateTime(
                                  _walletInt(row['created_at']),
                                ),
                              ),
                              trailing: Text(
                                '+${_walletNumber(_walletInt(row['coins']))} Coins',
                                style: const TextStyle(
                                  color: TinniPalette.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class RoleWalletDetailScreen extends StatefulWidget {
  const RoleWalletDetailScreen({
    super.key,
    required this.state,
    required this.walletType,
  });

  final AppState state;
  final String walletType;

  @override
  State<RoleWalletDetailScreen> createState() =>
      _RoleWalletDetailScreenState();
}

class _RoleWalletDetailScreenState
    extends State<RoleWalletDetailScreen> {
  bool loading = true;
  Map<String, dynamic> wallet = const {};

  String get title => widget.walletType == 'merchant'
      ? 'Merchant Wallet'
      : 'Coin Seller Wallet';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final value = await widget.state.backend.roleWalletDetail(
      userId: widget.state.userId,
      walletType: widget.walletType,
    );
    if (!mounted) return;
    setState(() {
      wallet = value?['wallet'] is Map
          ? Map<String, dynamic>.from(value!['wallet'] as Map)
          : const {};
      loading = false;
    });
  }

  bool get credentialSet => wallet['credential_set'] == true;

  Future<String?> _askCredential({
    required String title,
    bool confirm = false,
  }) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              obscureText: true,
              keyboardType: widget.walletType == 'coin_seller'
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: widget.walletType == 'coin_seller'
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              maxLength: widget.walletType == 'coin_seller' ? 4 : 32,
              decoration: InputDecoration(
                labelText: widget.walletType == 'coin_seller'
                    ? '4-digit PIN'
                    : 'Merchant credential',
              ),
            ),
            if (confirm)
              TextField(
                controller: second,
                obscureText: true,
                keyboardType: widget.walletType == 'coin_seller'
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: widget.walletType == 'coin_seller'
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                maxLength: widget.walletType == 'coin_seller' ? 4 : 32,
                decoration:
                    const InputDecoration(labelText: 'Confirm credential'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = first.text;
              if (confirm && value != second.text) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    first.dispose();
    second.dispose();
    return result;
  }

  Future<void> setupCredential() async {
    final credential = await _askCredential(
      title: credentialSet
          ? 'Change wallet credential'
          : 'Set wallet credential',
      confirm: true,
    );
    if (credential == null || credential.isEmpty || !mounted) return;
    String? old;
    if (credentialSet) {
      old = await _askCredential(title: 'Enter current credential');
      if (old == null || old.isEmpty || !mounted) return;
    }
    final result = await widget.state.backend.setRoleWalletCredential(
      userId: widget.state.userId,
      walletType: widget.walletType,
      credential: credential,
      oldCredential: old,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?['ok'] == true
              ? 'Wallet credential saved'
              : (result?['error']?.toString() ??
                  'Credential could not be saved'),
        ),
      ),
    );
    if (result?['ok'] == true) await load();
  }

  Future<void> sendCoins() async {
    if (!credentialSet) {
      await setupCredential();
      return;
    }
    final receiver = TextEditingController();
    final amount = TextEditingController();
    final credential = TextEditingController();
    final data = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send Coins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: receiver,
              decoration: const InputDecoration(
                labelText: 'Receiver DarkVibeX ID',
              ),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(labelText: 'Coin amount'),
            ),
            TextField(
              controller: credential,
              obscureText: true,
              keyboardType: widget.walletType == 'coin_seller'
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: widget.walletType == 'coin_seller'
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              maxLength: widget.walletType == 'coin_seller' ? 4 : 32,
              decoration: const InputDecoration(
                labelText: 'Wallet credential',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              [receiver.text.trim(), amount.text.trim(), credential.text],
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    receiver.dispose();
    amount.dispose();
    credential.dispose();
    if (data == null || data.length != 3 || !mounted) return;
    final coins = int.tryParse(data[1]) ?? 0;
    final result = await widget.state.backend.roleWalletCoinTransfer(
      userId: widget.state.userId,
      walletType: widget.walletType,
      receiverUserId: data[0],
      coins: coins,
      credential: data[2],
    );
    if (!mounted) return;
    if (result?['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.walletType == 'coin_seller'
                ? 'Coins sent. Receiver VIP EXP was updated.'
                : 'Coins sent from Merchant Wallet.',
          ),
        ),
      );
      await load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['error']?.toString() ?? 'Transfer failed',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _walletRows(wallet['transactions']);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Security',
            onPressed: setupCredential,
            icon: const Icon(Icons.lock_rounded),
          ),
        ],
      ),
      body: TinniBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  children: [
                    TinniPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: TinniPalette.gold,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _RoleAmount(
                            label: 'Coins',
                            value: _walletNumber(
                              _walletInt(wallet['balance_coins']),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            credentialSet
                                ? 'Wallet security active'
                                : 'Set wallet security before transfers',
                            style: TextStyle(
                              color: credentialSet
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: sendCoins,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Send Coins'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Permanent Coin Ledger',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (transactions.isEmpty)
                      const TinniPanel(child: Text('No coin transactions.'))
                    else
                      for (final row in transactions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: TinniPanel(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                row['kind']?.toString() ?? 'Coin transaction',
                              ),
                              subtitle: Text(
                                [
                                  if ((row['counterparty_user_id']
                                              ?.toString() ??
                                          '')
                                      .isNotEmpty)
                                    'ID ${row['counterparty_user_id']}',
                                  _walletDateTime(
                                    _walletInt(row['created_at']),
                                  ),
                                ].join(' • '),
                              ),
                              trailing: Text(
                                '${_walletInt(row['coin_amount']) > 0 ? '+' : ''}'
                                '${_walletNumber(_walletInt(row['coin_amount']))}',
                                style: const TextStyle(
                                  color: TinniPalette.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RoleAmount extends StatelessWidget {
  const _RoleAmount({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TinniPalette.muted,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: TinniPalette.gold,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}
