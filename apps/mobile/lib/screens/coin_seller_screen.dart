import 'package:flutter/material.dart';

import '../app/app_state.dart';

class CoinSellerScreen extends StatefulWidget {
  const CoinSellerScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CoinSellerScreen> createState() => _CoinSellerScreenState();
}

class _CoinSellerScreenState extends State<CoinSellerScreen> {
  final _receiver = TextEditingController();
  final _amount = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _receiver.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    final receiverId = _receiver.text.trim();
    final amount = int.tryParse(_amount.text.trim());
    if (!widget.state.backendConnected) {
      _show('Connect to the server before transferring coins.');
      return;
    }
    if (receiverId.isEmpty || receiverId == widget.state.userId || amount == null || amount <= 0) {
      _show('Enter another user’s ID and a valid coin amount.');
      return;
    }
    if (amount > widget.state.coins) {
      _show('Your coin balance is too low.');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await widget.state.backend.coinSellerTransfer(
        sellerUserId: widget.state.userId,
        receiverUserId: receiverId,
        coins: amount,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        _receiver.clear();
        _amount.clear();
        await widget.state.refreshWallet();
        final vipAward = result?['vip_award'];
        final exp = vipAward is Map ? vipAward['awarded_exp'] : null;
        if (mounted) _show('Coins transferred. Receiver earned ${exp ?? 0} VIP EXP.');
      } else {
        _show('Transfer failed. Check Coin Seller access, user ID, and balance.');
      }
    } catch (_) {
      if (mounted) _show('Could not reach the server. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coin Seller')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seller coin transfer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Send any amount of coins to a user by their DarkVibeX ID. Every coin received from a Coin Seller earns exactly 1 VIP EXP, with no transfer or monthly cap.'),
                  const SizedBox(height: 16),
                  Text('Available coins: ${widget.state.coins}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _receiver,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Receiver user ID', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Coins to send', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _transfer,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(_busy ? 'Sending…' : 'Transfer coins'),
          ),
        ],
      ),
    );
  }
}
