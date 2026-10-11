import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../features/catalog_models.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.state});

  final AppState state;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  static const kinds = <(String, String, IconData)>[
    ('frame', 'Frames', Icons.crop_square_rounded),
    ('ring', 'Rings', Icons.radio_button_unchecked_rounded),
    ('bubble', 'Bubbles', Icons.chat_bubble_outline_rounded),
    ('profile_background', 'Profile', Icons.wallpaper_rounded),
    ('vehicle', 'Entry', Icons.directions_car_filled_rounded),
    ('theme', 'Themes', Icons.palette_rounded),
    ('tag', 'Tags', Icons.sell_rounded),
  ];

  final Map<String, List<CatalogItem>> catalogs = {};
  List<Map<String, dynamic>> active = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    for (final kind in kinds) {
      final rows = await widget.state.backend.catalog(kind.$1);
      catalogs[kind.$1] = rows.map(CatalogItem.fromMap).toList();
    }
    active = await widget.state.backend.entitlements(widget.state.userId);
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _buy(CatalogItem item) async {
    final result = await widget.state.backend.purchaseStoreItem(
      userId: widget.state.userId,
      kind: item.kind,
      itemId: item.id,
    );
    if (!mounted) return;
    final balance = int.tryParse(result?['coin_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result == null ? 'Purchase failed' : '${item.name} added to your inventory'),
      ),
    );
    if (result != null) await _load();
  }

  String _coins(int value) => value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: kinds.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Store'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final kind in kinds) Tab(icon: Icon(kind.$3), text: kind.$2)],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (active.isNotEmpty)
                    SizedBox(
                      height: 54,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final row in active)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: Chip(
                                avatar: const Icon(Icons.verified_rounded, size: 16),
                                label: Text(row['item_name']?.toString() ?? 'Active'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final kind in kinds)
                          _StoreList(
                            items: catalogs[kind.$1] ?? const [],
                            onBuy: _buy,
                            coins: _coins,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StoreList extends StatelessWidget {
  const _StoreList({
    required this.items,
    required this.onBuy,
    required this.coins,
  });

  final List<CatalogItem> items;
  final Future<void> Function(CatalogItem item) onBuy;
  final String Function(int value) coins;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items published in this category yet.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .92,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final days = item.data['duration_days'];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD36A), size: 30),
                const SizedBox(height: 10),
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                if (days != null) Text('$days days', style: Theme.of(context).textTheme.bodySmall),
                Text('🪙 ${coins(item.priceCoins)}', style: const TextStyle(color: Color(0xFFFFD36A), fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onBuy(item),
                    child: const Text('Get'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
