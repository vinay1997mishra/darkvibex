import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

class UniqueIdStoreScreen extends StatefulWidget {
  const UniqueIdStoreScreen({super.key, required this.state});

  final AppState state;

  @override
  State<UniqueIdStoreScreen> createState() => _UniqueIdStoreScreenState();
}

class _UniqueIdStoreScreenState extends State<UniqueIdStoreScreen> {
  bool loading = true;
  bool buying = false;
  List<Map<String, dynamic>> ids = const [];
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!widget.state.backendConnected) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Connect to the server to view Unique IDs.';
        });
      }
      return;
    }
    try {
      final values = await widget.state.backend.uniqueIdCatalog(
        userId: widget.state.userId,
      );
      if (!mounted) return;
      setState(() {
        ids = values;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Unique IDs could not be loaded.';
      });
    }
  }

  Future<void> buy(Map<String, dynamic> item) async {
    final publicId = item['public_id']?.toString() ?? '';
    if (publicId.isEmpty || buying) return;
    setState(() => buying = true);
    final result = await widget.state.backend.purchaseUniqueId(
      userId: widget.state.userId,
      publicId: publicId,
    );
    if (!mounted) return;
    setState(() => buying = false);

    if (result?['ok'] == true) {
      final wallet = result?['wallet'];
      if (wallet is Map) {
        final coins = int.tryParse(wallet['coins']?.toString() ?? '');
        final diamonds = int.tryParse(wallet['diamonds']?.toString() ?? '');
        if (coins != null) widget.state.setCoinBalance(coins);
        if (diamonds != null) widget.state.setDiamondBalance(diamonds);
      }
      await widget.state.refreshVip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unique ID $publicId activated')),
      );
      await load();
      return;
    }

    final code = result?['error']?.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch (code) {
            'insufficient_coins' => 'Not enough coins',
            'unique_id_taken' => 'This Unique ID is already taken',
            _ => 'Unique ID could not be purchased',
          },
        ),
      ),
    );
  }

  String _price(dynamic raw) {
    final value = int.tryParse(raw?.toString() ?? '') ?? 0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Unique ID Store',
            style: TextStyle(
              color: TinniPalette.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
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
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      TinniPanel(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.badge_rounded,
                              color: TinniPalette.gold,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Current public ID'),
                                  Text(
                                    widget.state.customVipId ??
                                        widget.state.userId,
                                    style: const TextStyle(
                                      color: TinniPalette.gold,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final item in ids)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TinniPanel(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const TinniGlowIcon(
                                icon: Icons.numbers_rounded,
                                size: 21,
                                boxSize: 42,
                              ),
                              title: Text(
                                item['public_id']?.toString() ?? '',
                                style: const TextStyle(
                                  color: TinniPalette.gold,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${_price(item['price_coins'])} coins • '
                                '${item['permanent'] == true ? 'Permanent' : '${item['duration_days'] ?? 0} days'}',
                              ),
                              trailing: item['available'] == false
                                  ? const Text(
                                      'Taken',
                                      style: TextStyle(
                                        color: TinniPalette.muted,
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed: buying
                                          ? null
                                          : () => buy(item),
                                      child: const Text('Buy'),
                                    ),
                            ),
                          ),
                        ),
                      if (ids.isEmpty && error == null)
                        const TinniPanel(
                          child: Text(
                            'No Unique IDs are available right now.',
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      );
}
