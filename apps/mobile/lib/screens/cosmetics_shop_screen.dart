import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import '../widgets/vehicle_entry_effect.dart';
import '../widgets/vip_animated_frame.dart';
import 'unique_id_store_screen.dart';

class CosmeticsShopScreen extends StatefulWidget {
  const CosmeticsShopScreen({
    super.key,
    required this.state,
    this.initialKind,
  });

  final AppState state;
  final String? initialKind;

  @override
  State<CosmeticsShopScreen> createState() => _CosmeticsShopScreenState();
}

class _StoreCategory {
  const _StoreCategory(this.label, this.kind, this.icon);
  final String label;
  final String kind;
  final IconData icon;
}

class _CosmeticsShopScreenState extends State<CosmeticsShopScreen> {
  static const _categories = <_StoreCategory>[
    _StoreCategory('Car', 'vehicle', Icons.directions_car_filled_rounded),
    _StoreCategory('Profile', 'profile_card', Icons.badge_rounded),
    _StoreCategory('Unique ID', 'unique_id', Icons.numbers_rounded),
    _StoreCategory('Ring', 'ring', Icons.circle_outlined),
    _StoreCategory(
      'Profile Background',
      'profile_background',
      Icons.wallpaper_rounded,
    ),
    _StoreCategory('Entrance', 'entry', Icons.auto_awesome_rounded),
    _StoreCategory('Bubble', 'bubble', Icons.chat_bubble_rounded),
    _StoreCategory('Frame', 'frame', Icons.account_box_rounded),
  ];

  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _owned = const [];
  bool _loading = true;
  bool _inventoryOnly = false;
  int _categoryIndex = 0;
  final Set<String> _busy = <String>{};

  _StoreCategory get _category => _categories[_categoryIndex];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKind;
    if (initial != null) {
      final index = _categories.indexWhere((item) => item.kind == initial);
      if (index >= 0 && _categories[index].kind != 'unique_id') {
        _categoryIndex = index;
      }
    }
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final result = await widget.state.backend.cosmetics(
      userId: widget.state.userId,
    );
    await widget.state.refreshCosmetics();
    if (!mounted) return;
    setState(() {
      _items = (result?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _owned = (result?['owned'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _loading = false;
    });
  }

  Map<String, dynamic>? _ownership(String id) {
    for (final row in _owned) {
      if (row['item_id']?.toString() == id) return row;
    }
    return null;
  }

  List<Map<String, dynamic>> get _visibleItems {
    if (_category.kind == 'unique_id') {
      return const <Map<String, dynamic>>[];
    }
    final rows = _items
        .where((item) => item['kind']?.toString() == _category.kind)
        .toList();
    if (!_inventoryOnly) return rows;
    return rows
        .where((item) => _ownership(item['id']?.toString() ?? '') != null)
        .toList();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _buy(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    final result = await widget.state.backend.purchaseCosmetic(
      userId: widget.state.userId,
      itemId: id,
    );
    await widget.state.refreshWallet();
    await _load();
    if (result?['ok'] == true) {
      _notice('${item['name']} bought. Equip it to use it.');
    } else {
      final error = result?['error']?.toString();
      _notice(
        switch (error) {
          'vip_level_required' =>
            'Active VIP${result?['required_level'] ?? item['min_vip_level']} is required.',
          'insufficient_coins' => 'Not enough coins.',
          'already_owned' => 'You already own this item.',
          _ => 'Purchase could not be completed.',
        },
      );
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _send(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    final controller = TextEditingController();
    final recipient = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send ${item['name']}'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(labelText: 'Recipient DarkVibeX ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (recipient == null || recipient.isEmpty || !mounted) return;
    if (recipient == widget.state.userId ||
        recipient == widget.state.customVipId) {
      _notice('Choose another user ID.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm gift'),
        content: Text(
          '${item['name']} costs ${item['price_coins']} coins and lasts '
          '${item['duration_days'] ?? 30} days. Send to $recipient?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy.add(id));
    final result = await widget.state.backend.purchaseCosmetic(
      userId: widget.state.userId,
      itemId: id,
      recipientUserId: recipient,
    );
    await widget.state.refreshWallet();
    if (!mounted) return;
    if (result?['ok'] == true) {
      _notice('${item['name']} sent to $recipient.');
    } else {
      final error = result?['error']?.toString();
      _notice(
        switch (error) {
          'vip_level_required' =>
            'The recipient needs active VIP${result?['required_level'] ?? item['min_vip_level']}.',
          'insufficient_coins' => 'Not enough coins.',
          'already_owned' => 'The recipient already owns this item.',
          'recipient_not_found' => 'Recipient ID was not found.',
          _ => 'Gift could not be sent.',
        },
      );
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _equip(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    final result = await widget.state.backend.equipCosmetic(
      userId: widget.state.userId,
      itemId: id,
    );
    if (result?['ok'] == true) {
      _notice('${item['name']} equipped.');
      await widget.state.refreshCosmetics();
      await _load();
    } else {
      final error = result?['error']?.toString();
      _notice(
        error == 'vip_level_required'
            ? 'Required active VIP is not available.'
            : 'Could not equip this item.',
      );
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  void _selectCategory(int index) {
    final item = _categories[index];
    if (item.kind == 'unique_id') {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => UniqueIdStoreScreen(state: widget.state),
        ),
      );
      return;
    }
    setState(() => _categoryIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleItems;
    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: const Text(
          'Store',
          style: TextStyle(
            color: TinniPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton.icon(
            key: const Key('store-my-items'),
            onPressed: () =>
                setState(() => _inventoryOnly = !_inventoryOnly),
            icon: Icon(
              _inventoryOnly
                  ? Icons.storefront_rounded
                  : Icons.backpack_rounded,
            ),
            label: Text(_inventoryOnly ? 'Store' : 'My items'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TinniBackground(
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                itemCount: _categories.length,
                itemBuilder: (_, index) {
                  final item = _categories[index];
                  final selected = index == _categoryIndex &&
                      item.kind != 'unique_id';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      key: Key('store-category-${item.kind}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _selectCategory(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? TinniPalette.deepGold.withValues(alpha: .22)
                              : TinniPalette.nearBlack,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? TinniPalette.gold
                                : TinniPalette.bronze,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              item.icon,
                              color: selected
                                  ? TinniPalette.gold
                                  : TinniPalette.muted,
                              size: 20,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? TinniPalette.gold
                                    : TinniPalette.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const VerticalDivider(
              width: 1,
              color: TinniPalette.bronze,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? Center(
                          child: Text(
                            _inventoryOnly
                                ? 'No owned ${_category.label} items'
                                : 'No ${_category.label} items available',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.builder(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(10, 8, 10, 28),
                            itemCount: products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 9,
                              mainAxisSpacing: 9,
                              childAspectRatio: .64,
                            ),
                            itemBuilder: (_, index) =>
                                _productCard(products[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(String kind) => switch (kind) {
        'profile_card' => Icons.badge_rounded,
        'ring' => Icons.circle_outlined,
        'profile_background' => Icons.wallpaper_rounded,
        'entry' => Icons.auto_awesome_rounded,
        'bubble' => Icons.chat_bubble_rounded,
        'vehicle' => Icons.directions_car_filled_rounded,
        _ => Icons.account_box_rounded,
      };

  Widget _preview(Map<String, dynamic> item, int tier) {
    final kind = item['kind']?.toString() ?? '';
    final id = item['id']?.toString() ?? '';
    if (kind == 'frame') {
      return Center(
        child: VipAnimatedFrame(
          size: 84,
          enabled: true,
          level: tier,
          styleId: id,
          child: const CircleAvatar(
            backgroundColor: Color(0xFF110D18),
            child: Icon(
              Icons.person_rounded,
              color: Colors.white70,
              size: 34,
            ),
          ),
        ),
      );
    }
    if (kind == 'vehicle' || kind == 'entry') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: VehicleShowcase(level: tier.clamp(1, 18)),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TinniGlowIcon(
            icon: _kindIcon(kind),
            size: 30,
            boxSize: 66,
          ),
          const SizedBox(height: 6),
          Text(
            item['name']?.toString() ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TinniPalette.gold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final owned = _ownership(id);
    final active =
        owned?['active'] == true || owned?['active']?.toString() == '1';
    final requiredLevel =
        int.tryParse(item['min_vip_level']?.toString() ?? '') ?? 0;
    final tier =
        int.tryParse(item['tier']?.toString() ?? '') ?? requiredLevel;
    final canUse = requiredLevel <= 0 ||
        (widget.state.vipIsActive &&
            widget.state.vipLevel >= requiredLevel);
    final busy = _busy.contains(id);

    return Card(
      color: const Color(0xFF171322),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(
          color: active
              ? TinniPalette.gold
              : const Color(0xFF594C70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF392653),
                    Color(0xFF16111F),
                  ],
                ),
              ),
              child: _preview(item, tier),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 0, 9, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? 'Effect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  requiredLevel > 0
                      ? 'VIP$requiredLevel • ${item['duration_days'] ?? 30} days'
                      : '${item['duration_days'] ?? 30} days',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFD0BBFF),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item['price_coins'] ?? 0} coins',
                  style: const TextStyle(
                    color: TinniPalette.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                if (active && canUse)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(Icons.check_rounded),
                      label: Text('Using'),
                    ),
                  )
                else if (owned != null && canUse)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : () => _equip(item),
                      child: Text(busy ? '…' : 'Use'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: canUse
                            ? FilledButton(
                                onPressed:
                                    busy ? null : () => _buy(item),
                                child: Text(busy ? '…' : 'Buy'),
                              )
                            : OutlinedButton(
                                onPressed: null,
                                child: Text('VIP$requiredLevel'),
                              ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => _send(item),
                          child: const Text('Send'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
