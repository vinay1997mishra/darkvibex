import 'package:flutter/material.dart';
import '../utils/public_user_id.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

class FamilyWalletScreen extends StatefulWidget {
  const FamilyWalletScreen({
    super.key,
    required this.state,
    required this.familyName,
  });

  final AppState state;
  final String familyName;

  @override
  State<FamilyWalletScreen> createState() => _FamilyWalletScreenState();
}

class _FamilyWalletScreenState extends State<FamilyWalletScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> members = const [];
  List<Map<String, dynamic>> transfers = const [];
  int familyBonusWallet = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _compact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _date(dynamic value) {
    final ms = int.tryParse(value?.toString() ?? '');
    if (ms == null || ms <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.state.backend.familyState(userId: widget.state.userId),
        widget.state.backend.familyWalletTransfers(),
        widget.state.refreshWallet(notify: false),
      ]);
      final state = results[0] as Map<String, dynamic>?;
      final rawMembers = state?['members'];
      final rawFamily = state?['family'];
      if (!mounted) return;
      setState(() {
        members = rawMembers is List
            ? rawMembers
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false)
            : const [];
        transfers = List<Map<String, dynamic>>.from(
          results[1] as List<Map<String, dynamic>>,
        );
        familyBonusWallet = rawFamily is Map
            ? int.tryParse(rawFamily['wallet_coins']?.toString() ?? '') ?? 0
            : 0;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _sendCoins(Map<String, dynamic> member) async {
    final targetId = member['user_id']?.toString() ?? '';
    if (targetId.isEmpty || targetId == widget.state.userId) return;
    final targetName = member['display_name']?.toString().trim();
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Send coins to ${targetName == null || targetName.isEmpty ? 'User' : targetName}',
        ),
        content: TextField(
          key: const Key('family-wallet-amount'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Coins',
            helperText: 'Available: ${widget.state.coins} coins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;

    final result = await widget.state.backend.sendFamilyCoins(
      receiverUserId: targetId,
      coins: amount,
    );
    if (!mounted) return;
    if (result?['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['error']?.toString().replaceAll('_', ' ') ??
                'Family coin transfer failed.',
          ),
        ),
      );
      return;
    }
    final balance =
        int.tryParse(result?['coin_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$amount coins sent. Receiver gives Family EXP +$amount.',
        ),
      ),
    );
    await _load();
  }

  ImageProvider<Object>? _avatar(Map<String, dynamic> member) {
    final key = member['avatar_key']?.toString().trim() ?? '';
    if (key.isEmpty) return null;
    return NetworkImage(
      widget.state.backend.fileUrl(key),
      headers: widget.state.backend.fileHeaders,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Family Wallet'),
        ),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      TinniPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.familyName,
                              style: const TextStyle(
                                color: TinniPalette.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'My Coins: ${widget.state.coins}',
                              style: const TextStyle(
                                color: TinniPalette.gold,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Family Bonus Wallet: $familyBonusWallet',
                              style: const TextStyle(
                                color: TinniPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Family member transfer: receiver adds Family EXP 1:1. Sender gets no Family EXP.',
                              style: TextStyle(
                                color: TinniPalette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Send coins to Family members',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final member in members)
                        TinniPanel(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: _avatar(member),
                              child: _avatar(member) == null
                                  ? const Icon(Icons.person_rounded)
                                  : null,
                            ),
                            title: Text(
                              member['display_name']?.toString() ?? 'User',
                            ),
                            subtitle: Text(
                              'ID ${formatPublicUserId(member['public_id'])} • Received ${_compact(int.tryParse(member['received_coins']?.toString() ?? '') ?? 0)}',
                            ),
                            trailing:
                                member['user_id']?.toString() ==
                                        widget.state.userId
                                    ? null
                                    : TextButton(
                                        key: Key(
                                          'family-wallet-send-${member['user_id']}',
                                        ),
                                        onPressed: () => _sendCoins(member),
                                        child: const Text('Send'),
                                      ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        'Transfer Records',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (transfers.isEmpty)
                        const TinniPanel(
                          child: Text(
                            'No Family Wallet transfers yet.',
                            style: TextStyle(color: TinniPalette.muted),
                          ),
                        ),
                      for (final row in transfers)
                        ListTile(
                          leading: const Icon(
                            Icons.swap_horiz_rounded,
                            color: TinniPalette.gold,
                          ),
                          title: Text(
                            '${row['sender_name'] ?? 'User'} → '
                            '${row['receiver_name'] ?? 'User'}',
                          ),
                          subtitle: Text(_date(row['created_at'])),
                          trailing: Text(
                            _compact(
                              int.tryParse(row['coins']?.toString() ?? '') ?? 0,
                            ),
                            style: const TextStyle(
                              color: TinniPalette.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      );
}
