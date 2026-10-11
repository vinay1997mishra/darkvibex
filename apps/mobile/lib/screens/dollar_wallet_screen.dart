import 'package:flutter/material.dart';

import '../app/app_state.dart';

class DollarWalletScreen extends StatefulWidget {
  const DollarWalletScreen({super.key, required this.state});

  final AppState state;

  @override
  State<DollarWalletScreen> createState() => _DollarWalletScreenState();
}

class _DollarWalletScreenState extends State<DollarWalletScreen> {
  int balanceCents = 0;
  List<Map<String, dynamic>> ledger = const [];
  bool loading = true;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String money(int cents) => '\${(cents / 100).toStringAsFixed(2)}';

  Future<void> _load() async {
    final token = widget.state.sessionToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => loading = false);
      return;
    }
    final value = await widget.state.backend.dollarWallet(
      userId: widget.state.userId,
      authToken: token,
    );
    if (!mounted) return;
    final rows = value?['ledger'];
    setState(() {
      balanceCents =
          int.tryParse(value?['balance_cents']?.toString() ?? '') ?? 0;
      ledger = rows is List
          ? rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : const [];
      loading = false;
    });
  }

  Future<void> _send() async {
    final amountController = TextEditingController();
    final destinationController = TextEditingController();
    var destination = 'company';

    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Dollars'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: destination,
                decoration: const InputDecoration(labelText: 'Destination'),
                items: const [
                  DropdownMenuItem(
                    value: 'company',
                    child: Text('Company'),
                  ),
                  DropdownMenuItem(
                    value: 'crypto',
                    child: Text('Cryptocurrency'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => destination = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount in dollars',
                  hintText: '10.00',
                ),
              ),
              if (destination == 'crypto') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: destinationController,
                  decoration: const InputDecoration(
                    labelText: 'USDT / crypto address',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'destination': destination,
                'amount': amountController.text.trim(),
                'reference': destinationController.text.trim(),
              }),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    destinationController.dispose();
    if (payload == null) return;

    final amount =
        double.tryParse(payload['amount'] ?? '') ?? 0;
    final cents = (amount * 100).round();
    if (cents <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid dollar amount')),
      );
      return;
    }
    if (payload['destination'] == 'crypto' &&
        (payload['reference'] ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crypto address is required')),
      );
      return;
    }

    final token = widget.state.sessionToken;
    if (token == null || token.isEmpty) return;
    setState(() => sending = true);
    final result = await widget.state.backend.settleDollars(
      userId: widget.state.userId,
      authToken: token,
      amountCents: cents,
      destinationType: payload['destination'] ?? 'company',
      destinationRef: payload['reference'] ?? '',
    );
    if (!mounted) return;
    setState(() => sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Dollar transfer could not be completed'
              : 'Dollar transfer recorded',
        ),
      ),
    );
    if (result != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dollar Wallet')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF151820), Color(0xFF2A1F12)],
                    ),
                    border: Border.all(color: const Color(0x66FFD36A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AVAILABLE DOLLARS',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.8,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        money(balanceCents),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD36A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: sending ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Send Dollars'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Permanent ledger',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (ledger.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No dollar transactions yet.'),
                    ),
                  )
                else
                  for (final row in ledger)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          (int.tryParse(
                                        row['amount_cents']?.toString() ?? '',
                                      ) ??
                                      0) <
                                  0
                              ? Icons.north_east_rounded
                              : Icons.south_west_rounded,
                        ),
                        title: Text(
                          row['kind']?.toString().replaceAll('_', ' ') ??
                              'transaction',
                        ),
                        subtitle: Text(
                          [
                            if ((row['destination_type']?.toString() ?? '')
                                .isNotEmpty)
                              row['destination_type'].toString(),
                            if ((row['destination_ref']?.toString() ?? '')
                                .isNotEmpty)
                              row['destination_ref'].toString(),
                          ].join(' • '),
                        ),
                        trailing: Text(
                          money(
                            int.tryParse(
                                  row['amount_cents']?.toString() ?? '',
                                ) ??
                                0,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
