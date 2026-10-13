import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

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

String _walletUsd(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

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
      backgroundColor: TinniPalette.black,
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
        backgroundColor: TinniPalette.black,
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
  Map<String, dynamic> data = const {};

  @override
  void initState() {
    super.initState();
    load();
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
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Convert Diamonds'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText:
                'Diamond amount (available ${data['current_diamonds'] ?? 0})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()) ?? 0,
            ),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !mounted) return;
    final result = await widget.state.backend.convertDiamonds(
      userId: widget.state.userId,
      diamonds: amount,
    );
    if (!mounted) return;
    if (result?['ok'] == true) {
      final coins = _walletInt(result?['current_coins']);
      final diamonds = _walletInt(result?['current_diamonds']);
      widget.state.setCoinBalance(coins);
      widget.state.setDiamondBalance(diamonds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$amount diamonds converted to ${result?['coins'] ?? 0} coins.',
          ),
        ),
      );
      await load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['error'] == 'insufficient_diamonds'
                ? 'Not enough diamonds.'
                : 'Diamonds could not be converted.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversions = _walletRows(data['conversions']);
    final gifts = _walletRows(data['gifts']);
    return Scaffold(
      backgroundColor: TinniPalette.black,
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
                          FilledButton(
                            onPressed:
                                _walletInt(data['current_diamonds']) > 0
                                    ? convert
                                    : null,
                            child: const Text('Convert'),
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
      title: credentialSet ? 'Change wallet credential' : 'Set wallet credential',
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

  Future<void> withdrawDollars() async {
    if (!credentialSet) {
      await setupCredential();
      return;
    }
    final amount = TextEditingController();
    final address = TextEditingController();
    final credential = TextEditingController();
    var destination = 'company';
    final data = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Dollars'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: destination,
                  decoration:
                      const InputDecoration(labelText: 'Destination'),
                  items: const [
                    DropdownMenuItem(
                      value: 'company',
                      child: Text('Company'),
                    ),
                    DropdownMenuItem(
                      value: 'crypto_usdt',
                      child: Text('Cryptocurrency (USDT)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => destination = value);
                    }
                  },
                ),
                if (destination == 'crypto_usdt')
                  TextField(
                    controller: address,
                    decoration: InputDecoration(
                      labelText: 'USDT wallet address',
                      suffixIcon: IconButton(
                        key: const Key('usdt-scan-qr-button'),
                        onPressed: () async {
                          final value =
                              await Navigator.of(dialogContext).push<String>(
                            MaterialPageRoute<String>(
                              builder: (_) =>
                                  const _UsdtQrScannerScreen(),
                            ),
                          );
                          if (value != null && dialogContext.mounted) {
                            setDialogState(() => address.text = value);
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                    ),
                  ),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'USD amount (minimum ${_walletUsd(_walletInt(wallet['minimum_transfer_usd_cents']))})',
                  ),
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
                  decoration:
                      const InputDecoration(labelText: 'Wallet credential'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                [
                  destination,
                  amount.text.trim(),
                  address.text.trim(),
                  credential.text,
                ],
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    address.dispose();
    credential.dispose();
    if (data == null || data.length != 4 || !mounted) return;
    final cents = ((double.tryParse(data[1]) ?? 0) * 100).round();
    final result =
        await widget.state.backend.roleWalletDollarWithdrawal(
      userId: widget.state.userId,
      walletType: widget.walletType,
      destinationType: data[0],
      amountUsdCents: cents,
      destinationValue: data[2],
      credential: data[3],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?['ok'] == true
              ? 'Dollar transfer request saved.'
              : (result?['error']?.toString() ??
                  'Dollar transfer failed'),
        ),
      ),
    );
    if (result?['ok'] == true) await load();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _walletRows(wallet['transactions']);
    final withdrawals = _walletRows(wallet['withdrawals']);
    return Scaffold(
      backgroundColor: TinniPalette.black,
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
                          Row(
                            children: [
                              Expanded(
                                child: _RoleAmount(
                                  label: 'Coins',
                                  value: _walletNumber(
                                    _walletInt(wallet['balance_coins']),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _RoleAmount(
                                  label: 'Total Dollars',
                                  value: _walletUsd(
                                    _walletInt(wallet['total_usd_cents']),
                                  ),
                                ),
                              ),
                            ],
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
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: sendCoins,
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Send Coins'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: withdrawDollars,
                            icon: const Icon(
                              Icons.currency_exchange_rounded,
                            ),
                            label: const Text('Send Dollars'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Permanent Ledger',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (transactions.isEmpty)
                      const TinniPanel(child: Text('No transactions.'))
                    else
                      for (final row in transactions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: TinniPanel(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                row['kind']?.toString() ?? 'Transaction',
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
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  if (_walletInt(row['coin_amount']) != 0)
                                    Text(
                                      '${_walletInt(row['coin_amount']) > 0 ? '+' : ''}'
                                      '${_walletNumber(_walletInt(row['coin_amount']))}',
                                    ),
                                  if (_walletInt(
                                        row['usd_cents_amount'],
                                      ) !=
                                      0)
                                    Text(
                                      _walletUsd(
                                        _walletInt(
                                          row['usd_cents_amount'],
                                        ).abs(),
                                      ),
                                      style: const TextStyle(
                                        color: TinniPalette.gold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    if (withdrawals.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Dollar Withdrawals',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      for (final row in withdrawals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: TinniPanel(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                row['destination_type'] ==
                                        'crypto_usdt'
                                    ? 'Cryptocurrency (USDT)'
                                    : 'Company',
                              ),
                              subtitle: Text(
                                '${row['status'] ?? 'pending'} • '
                                '${_walletDateTime(_walletInt(row['created_at']))}',
                              ),
                              trailing: Text(
                                _walletUsd(
                                  _walletInt(row['amount_usd_cents']),
                                ),
                                style: const TextStyle(
                                  color: TinniPalette.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class ReceivedDollarsScreen extends StatelessWidget {
  const ReceivedDollarsScreen({
    super.key,
    required this.rows,
  });

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Received Dollars')),
        body: TinniBackground(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: rows
                .where((row) => _walletInt(row['usd_cents_amount']) > 0)
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TinniPanel(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          row['kind']?.toString() ?? 'Dollars received',
                        ),
                        subtitle: Text(
                          _walletDateTime(_walletInt(row['created_at'])),
                        ),
                        trailing: Text(
                          _walletUsd(
                            _walletInt(row['usd_cents_amount']),
                          ),
                          style: const TextStyle(
                            color: TinniPalette.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
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

class _UsdtQrScannerScreen extends StatefulWidget {
  const _UsdtQrScannerScreen();

  @override
  State<_UsdtQrScannerScreen> createState() =>
      _UsdtQrScannerScreenState();
}

class _UsdtQrScannerScreenState extends State<_UsdtQrScannerScreen> {
  bool handled = false;

  void onDetect(BarcodeCapture capture) {
    if (handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      handled = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: const Key('usdt-qr-scanner-screen'),
        appBar: AppBar(title: const Text('Scan USDT Address')),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(onDetect: onDetect),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: TinniPalette.gold,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: EdgeInsets.all(20),
                child: TinniPanel(
                  child: Text(
                    'Place the USDT wallet QR inside the frame.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
