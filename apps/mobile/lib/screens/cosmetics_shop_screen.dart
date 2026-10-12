import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../widgets/vehicle_entry_effect.dart';
import '../widgets/vip_animated_frame.dart';

class CosmeticsShopScreen extends StatefulWidget {
  const CosmeticsShopScreen({super.key, required this.state});
  final AppState state;

  @override
  State<CosmeticsShopScreen> createState() => _CosmeticsShopScreenState();
}

class _CosmeticsShopScreenState extends State<CosmeticsShopScreen> {
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _owned = const [];
  bool _loading = true;
  bool _vehicles = false;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final result = await widget.state.backend.cosmetics(userId: widget.state.userId);
    await widget.state.refreshCosmetics();
    if (!mounted) return;
    setState(() {
      _items = (result?['items'] as List? ?? const [])
          .whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      _owned = (result?['owned'] as List? ?? const [])
          .whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      _loading = false;
    });
  }

  Map<String, dynamic>? _ownership(String id) {
    for (final row in _owned) {
      if (row['item_id']?.toString() == id) return row;
    }
    return null;
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _buy(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    final result = await widget.state.backend.purchaseCosmetic(userId: widget.state.userId, itemId: id);
    await widget.state.refreshWallet();
    await _load();
    if (result?['ok'] == true) {
      _notice('${item['name']} bought. Equip it to use it.');
    } else {
      final error = result?['error']?.toString();
      _notice(switch (error) {
        'vip_level_required' => 'Active VIP${result?['required_level'] ?? item['min_vip_level']} is required.',
        'insufficient_coins' => 'Not enough coins.',
        'already_owned' => 'You already own this item.',
        _ => 'Purchase could not be completed. Connect to the server and try again.',
      });
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _send(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final controller = TextEditingController();
    final recipient = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Send ${item['name']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(labelText: 'Recipient DarkVibeX ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    if (recipient == null || recipient.isEmpty || !mounted) return;
    if (recipient == widget.state.userId) {
      _notice('Choose another user ID.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm gift'),
        content: Text('${item['name']} costs ${item['price_coins']} coins and lasts ${item['duration_days']} days. Send to $recipient?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send')),
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
    if (result?['ok'] == true) {
      _notice('${item['name']} sent to $recipient.');
    } else {
      final error = result?['error']?.toString();
      _notice(switch (error) {
        'vip_level_required' => 'The recipient needs active VIP${result?['required_level'] ?? item['min_vip_level']}.',
        'insufficient_coins' => 'Not enough coins.',
        'already_owned' => 'The recipient already owns this item.',
        _ => 'Gift could not be sent. Check the ID and try again.',
      });
    }
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _equip(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final result = await widget.state.backend.equipCosmetic(userId: widget.state.userId, itemId: id);
    if (result?['ok'] == true) {
      _notice('${item['name']} equipped.');
      await widget.state.refreshCosmetics();
      await _load();
    } else {
      _notice('Could not equip this item. Refresh and try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF090711),
        appBar: AppBar(
          title: const Text('Frames & Vehicles'),
          backgroundColor: const Color(0xFF090711),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFF191325), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                _tab('Frames', !_vehicles, () => setState(() => _vehicles = false)),
                _tab('Vehicles', _vehicles, () => setState(() => _vehicles = true)),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_items.any((item) => item['kind']?.toString() == (_vehicles ? 'vehicle' : 'frame'))
                      ? Center(child: Text(widget.state.backendConnected ? 'Shop items are unavailable.' : 'Connect to the server to load the shop.'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
                            itemCount: _items.where((item) => item['kind']?.toString() == (_vehicles ? 'vehicle' : 'frame')).length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: .68,
                            ),
                            itemBuilder: (context, index) {
                              final products = _items.where((item) => item['kind']?.toString() == (_vehicles ? 'vehicle' : 'frame')).toList();
                              final item = products[index];
                              return _productCard(item);
                            },
                          ),
                        ),
            ),
          ],
        ),
      );

  Widget _tab(String label, bool selected, VoidCallback onTap) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: selected ? BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6748B5), Color(0xFFAA46C9)]), borderRadius: BorderRadius.circular(12)) : null,
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : Colors.white60)),
          ),
        ),
      );

  Widget _productCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final owned = _ownership(id);
    final active = owned?['active'] == true || owned?['active']?.toString() == '1';
    final requiredLevel = int.tryParse(item['min_vip_level']?.toString() ?? '') ?? 0;
    final tier = int.tryParse(item['tier']?.toString() ?? '') ?? requiredLevel;
    final canUse = widget.state.vipIsActive && widget.state.vipLevel >= requiredLevel;
    final busy = _busy.contains(id);
    return Card(
      color: const Color(0xFF171322),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: active ? const Color(0xFFFFD36A) : const Color(0xFF594C70))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const RadialGradient(colors: [Color(0xFF392653), Color(0xFF16111F)]),
              ),
              child: item['kind']?.toString() == 'frame'
                  ? Center(child: VipAnimatedFrame(size: 88, enabled: true, level: tier, styleId: id, child: const CircleAvatar(backgroundColor: Color(0xFF110D18), child: Icon(Icons.person_rounded, color: Colors.white70, size: 35))))
                  : Padding(padding: const EdgeInsets.all(12), child: VehicleShowcase(level: tier)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name']?.toString() ?? 'VIP effect', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('VIP$requiredLevel  •  ${item['duration_days'] ?? 30} days', style: const TextStyle(fontSize: 11, color: Color(0xFFD0BBFF))),
                const SizedBox(height: 5),
                Text('${item['price_coins'] ?? 0} coins', style: const TextStyle(color: Color(0xFFFFD36A), fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                if (active && canUse)
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.check_rounded), label: const Text('Equipped')))
                else if (owned != null && canUse)
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _equip(item), child: const Text('Equip')))
                else ...[
                  Row(children: [
                    Expanded(child: canUse && owned == null
                        ? FilledButton(onPressed: busy ? null : () => _buy(item), child: Text(busy ? '…' : 'Buy'))
                        : OutlinedButton(onPressed: null, child: Text('VIP$requiredLevel'))),
                    const SizedBox(width: 6),
                    Expanded(child: OutlinedButton(onPressed: busy ? null : () => _send(item), child: const Text('Send'))),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
