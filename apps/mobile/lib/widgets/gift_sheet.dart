import 'package:flutter/material.dart';

import '../features/catalog_models.dart';

class GiftSelection {
  const GiftSelection({
    required this.gift,
    required this.recipient,
    required this.quantity,
  });

  final CatalogItem gift;
  final RoomMember recipient;
  final int quantity;
}

class GiftSheet extends StatefulWidget {
  const GiftSheet({
    super.key,
    required this.gifts,
    required this.members,
    required this.currentUserId,
    required this.onSend,
  });

  final List<CatalogItem> gifts;
  final List<RoomMember> members;
  final String currentUserId;
  final Future<bool> Function(GiftSelection selection) onSend;

  @override
  State<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet> {
  static const preferredCategories = <String>[
    'popular',
    'lucky',
    'music',
    'lucky_bag',
    'four_box',
    'rank_hall',
    'moderation',
    'custom',
    'cp',
    'enemy',
  ];

  String category = 'popular';
  RoomMember? recipient;
  CatalogItem? selected;
  int quantity = 1;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    final available = widget.gifts.map((e) => e.category).where((e) => e.isNotEmpty).toSet();
    if (!available.contains(category) && available.isNotEmpty) {
      category = available.first;
    }
    if (widget.members.isNotEmpty) {
      recipient = widget.members.firstWhere(
        (member) => member.userId != widget.currentUserId,
        orElse: () => widget.members.first,
      );
    }
  }

  String label(String value) => switch (value) {
        'lucky_bag' => 'Lucky Bag',
        'four_box' => '4 Box',
        'rank_hall' => 'Rank/Hall',
        'cp' => 'CP',
        'enemy' => 'Enemy',
        _ => value.isEmpty
            ? 'Other'
            : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}',
      };

  String coins(int value) {
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(value % 10000000 == 0 ? 0 : 1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return value.toString();
  }

  Future<void> send() async {
    final gift = selected;
    final user = recipient;
    if (gift == null || user == null || sending) return;
    setState(() => sending = true);
    final ok = await widget.onSend(
      GiftSelection(gift: gift, recipient: user, quantity: quantity),
    );
    if (!mounted) return;
    setState(() => sending = false);
    if (ok) {
      selected = null;
      quantity = 1;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.gifts.map((e) => e.category).where((e) => e.isNotEmpty).toSet();
    final categories = <String>[
      ...preferredCategories.where(available.contains),
      ...available.where((e) => !preferredCategories.contains(e)),
    ];
    final items = widget.gifts.where((gift) => gift.category == category).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(9))),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Send Gift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
            ),
            SizedBox(
              height: 78,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: widget.members.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final member = widget.members[index];
                  final active = recipient?.userId == member.userId;
                  return InkWell(
                    onTap: () => setState(() => recipient = member),
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 68,
                      child: Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: active ? const Color(0xFFFFD36A) : Colors.white24,
                                width: active ? 3 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                member.displayName.isEmpty ? '?' : member.displayName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final value = categories[index];
                  return ChoiceChip(
                    selected: category == value,
                    label: Text(label(value)),
                    onSelected: (_) => setState(() {
                      category = value;
                      selected = null;
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: .78,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final gift = items[index];
                  final active = selected?.id == gift.id;
                  return InkWell(
                    onTap: () => setState(() => selected = gift),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: active ? const Color(0x3328D7A3) : Colors.white.withValues(alpha: .045),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: active ? const Color(0xFFFFD36A) : Colors.white12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gift.emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 4),
                          Text(gift.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('🪙 ${coins(gift.priceCoins)}', style: const TextStyle(fontSize: 9, color: Color(0xFFFFD36A))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    for (final value in const [1, 10, 99])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selected: quantity == value,
                          label: Text('×$value'),
                          onSelected: (_) => setState(() => quantity = value),
                        ),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: recipient == null || sending ? null : send,
                      icon: sending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: Text('Send ×$quantity'),
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
