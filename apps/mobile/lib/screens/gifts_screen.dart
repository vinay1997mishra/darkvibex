import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import '../widgets/gift_media_preview.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({
    super.key,
    required this.state,
    this.initialCategory,
  });

  final AppState state;
  final String? initialCategory;

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  static const categories = <String>[
    'Popular',
    'Normal',
    'CP',
    'VS',
    'Luxury',
    'Backpack',
  ];

  int categoryIndex = 0;
  bool loading = true;
  bool sending = false;
  List<Map<String, dynamic>> gifts = const <Map<String, dynamic>>[];

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    final requested = widget.initialCategory?.trim().toLowerCase();
    if (requested != null && requested.isNotEmpty) {
      final index = categories.indexWhere(
        (value) => value.toLowerCase() == requested,
      );
      if (index >= 0) categoryIndex = index;
    }
    _load();
  }

  Future<void> _load() async {
    final rows = state.backendConnected
        ? await state.backend.giftCatalog(userId: state.userId)
        : const <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      gifts = rows;
      loading = false;
    });
  }

  String _category(Map<String, dynamic> gift) {
    final explicit = gift['category']?.toString().toLowerCase().trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final id = gift['id']?.toString().toLowerCase() ?? '';
    if (id.startsWith('cp-')) return 'cp';
    if (id.startsWith('vs-') || id.startsWith('enemy-')) return 'vs';
    final price = int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
    if (price >= 1000000) return 'luxury';
    return 'normal';
  }

  List<Map<String, dynamic>> get visibleGifts {
    final selected = categories[categoryIndex].toLowerCase();
    final safe = gifts.where((gift) {
      final category = _category(gift);
      return category != 'lucky' && category != 'country';
    }).toList(growable: false);
    if (selected == 'popular') return safe;
    if (selected == 'luxury') {
      return safe.where((gift) {
        final price = int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
        return _category(gift) == 'luxury' || price >= 1000000;
      }).toList(growable: false);
    }
    return safe
        .where((gift) => _category(gift) == selected)
        .toList(growable: false);
  }

  Future<RoomSummary?> _chooseRoom() async {
    if (state.rooms.isEmpty) await state.refreshRooms();
    if (!mounted) return null;
    return showModalBottomSheet<RoomSummary>(
      context: context,
      showDragHandle: true,
      backgroundColor: TinniPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            const ListTile(
              title: Text(
                'Choose room',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text('Gift will be sent inside the selected room.'),
            ),
            for (final room in state.rooms)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: room.avatarKey == null
                      ? null
                      : NetworkImage(
                          state.backend.fileUrl(room.avatarKey!),
                          headers: state.backend.fileHeaders,
                        ),
                  child: room.avatarKey == null
                      ? const Icon(Icons.mic_rounded)
                      : null,
                ),
                title: Text(room.name),
                subtitle: Text(
                  'ID ' + room.id + ' • ' + room.online.toString() + ' online',
                ),
                onTap: () => Navigator.pop(sheetContext, room),
              ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _chooseRecipient(RoomSummary room) async {
    final rows = await state.backend.roomMembers(roomId: room.id);
    if (!mounted) return null;
    final recipients = rows
        .where((row) =>
            row['user_id']?.toString().isNotEmpty == true &&
            row['user_id']?.toString() != state.userId)
        .toList(growable: false);
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other user is in this room yet.')),
      );
      return null;
    }
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      backgroundColor: TinniPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            const ListTile(
              title: Text(
                'Send gift to',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final row in recipients)
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: row['avatar_key']?.toString().isNotEmpty == true
                      ? NetworkImage(
                          state.backend.fileUrl(row['avatar_key'].toString()),
                          headers: state.backend.fileHeaders,
                        )
                      : null,
                  child: row['avatar_key']?.toString().isNotEmpty == true
                      ? null
                      : const Icon(Icons.person_rounded),
                ),
                title: Text(
                  row['display_name']?.toString().trim().isNotEmpty == true
                      ? row['display_name'].toString()
                      : 'User ' + row['user_id'].toString(),
                ),
                subtitle: Text(
                  row['seat_index'] == null
                      ? 'Audience'
                      : 'Seat ' +
                          ((int.tryParse(row['seat_index']?.toString() ?? '') ??
                                      0) +
                                  1)
                              .toString(),
                ),
                onTap: () => Navigator.pop(sheetContext, row),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(Map<String, dynamic> gift) async {
    if (sending) return;
    if (!state.backendConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to the server before sending gifts.'),
        ),
      );
      return;
    }
    final room = await _chooseRoom();
    if (room == null || !mounted) return;
    final recipient = await _chooseRecipient(room);
    if (recipient == null || !mounted) return;
    final receiverId = recipient['user_id']?.toString() ?? '';
    final giftId = gift['id']?.toString() ?? '';
    final cost = int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
    if (receiverId.isEmpty || giftId.isEmpty || cost <= 0) return;
    setState(() => sending = true);
    final result = await state.backend.sendGift(
      roomId: room.id,
      senderUserId: state.userId,
      receiverUserId: receiverId,
      giftId: giftId,
      coinCost: cost,
    );
    if (!mounted) return;
    setState(() => sending = false);
    if (result?['ok'] == true) {
      final balance =
          int.tryParse(result?['sender_coin_balance']?.toString() ?? '');
      if (balance != null) state.setCoinBalance(balance);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (gift['name']?.toString() ?? 'Gift') +
                ' sent to ' +
                (recipient['display_name']?.toString() ?? receiverId) +
                '.',
          ),
        ),
      );
    } else {
      final error = result?['error']?.toString() ?? 'Gift could not be sent.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.replaceAll('_', ' '))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = visibleGifts;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Gift Festival',
          style: TextStyle(
            color: TinniPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TinniBackground(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) => ChoiceChip(
                  label: Text(categories[index]),
                  selected: categoryIndex == index,
                  onSelected: (_) => setState(() => categoryIndex = index),
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                      ? Center(
                          child: Text(
                            'No ' +
                                categories[categoryIndex] +
                                ' gifts available.',
                            style:
                                const TextStyle(color: TinniPalette.muted),
                          ),
                        )
                      : GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: .82,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final gift = rows[index];
                            final cost = int.tryParse(
                                  gift['coin_cost']?.toString() ?? '',
                                ) ??
                                0;
                            return TinniPanel(
                              onTap: sending ? null : () => _send(gift),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 58,
                                    height: 58,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: GiftMediaPreview(
                                        backend: state.backend,
                                        videoKey:
                                            gift['video_key']?.toString() ?? '',
                                        assetKey:
                                            gift['asset_key']?.toString() ?? '',
                                        emoji:
                                            gift['emoji']?.toString() ?? '🎁',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    gift['name']?.toString() ?? 'Gift',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: TinniPalette.cream,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cost.toString() + ' coins',
                                    style: const TextStyle(
                                      color: TinniPalette.gold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
