import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../app/app_state.dart';
import '../effects/gift_effect_overlay.dart';
import '../features/catalog_models.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../infra/realtime.dart';
import '../room/seat_layout.dart';
import '../widgets/gift_sheet.dart';
import 'relationships_screen.dart';
import 'store_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.state,
    required this.room,
  });

  final AppState state;
  final RoomSummary room;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final GiftEffectController effects = GiftEffectController();
  final AudioPlayer musicPlayer = AudioPlayer();
  final ValueNotifier<Map<String, double>> silentLevels =
      ValueNotifier<Map<String, double>>(const <String, double>{});

  int? mySeat;
  bool muted = true;
  String voiceStatus = 'Connecting…';
  RtcAdapter? rtc;
  Timer? presenceTimer;
  List<RoomMember> members = const [];
  List<CatalogItem> gifts = const [];
  final List<String> chat = <String>['Welcome to the room 👋'];

  @override
  void initState() {
    super.initState();
    widget.state.markRoomVisited(widget.room.id);
    unawaited(_connectVoice());
    unawaited(_loadMembers());
    unawaited(_loadGifts());
    presenceTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_loadMembers()),
    );
  }

  Future<void> _connectVoice() async {
    if (widget.state.backendConnected) {
      await widget.state.backend.joinRoom(
        roomId: widget.room.id,
        userId: widget.state.userId,
        displayName: widget.state.displayName,
      );
    }

    final token = widget.state.sessionToken;
    RtcAdapter candidate;
    if (widget.state.backendConnected &&
        token != null &&
        token.isNotEmpty &&
        BackendApi.origin.isNotEmpty) {
      candidate = LiveKitRtcAdapter(apiBase: Uri.parse(BackendApi.origin));
    } else {
      candidate = LocalRtcAdapter();
    }

    try {
      await candidate.join(
        widget.room.id,
        widget.state.userId,
        authToken: token,
      );
      rtc = candidate;
      if (!mounted) return;
      setState(() {
        voiceStatus =
            candidate is LiveKitRtcAdapter ? 'Voice connected' : 'Local voice mode';
      });
    } catch (_) {
      if (candidate is LiveKitRtcAdapter) candidate.dispose();
      final fallback = LocalRtcAdapter();
      await fallback.join(widget.room.id, widget.state.userId);
      rtc = fallback;
      if (!mounted) return;
      setState(() => voiceStatus = 'Voice setup required');
    }
  }

  Future<void> _loadMembers() async {
    if (!widget.state.backendConnected) {
      if (members.isEmpty && mounted) {
        setState(() {
          members = [
            RoomMember(
              userId: widget.state.userId,
              displayName: widget.state.displayName,
              seatIndex: mySeat,
              micMuted: muted,
              vipLevel: widget.state.vipLevel,
            ),
          ];
        });
      }
      return;
    }
    final rows = await widget.state.backend.roomMembers(
      widget.room.id,
      viewerId: widget.state.userId,
    );
    if (!mounted) return;
    final next = rows.map(RoomMember.fromMap).toList();
    RoomMember? me;
    for (final member in next) {
      if (member.userId == widget.state.userId) {
        me = member;
        break;
      }
    }
    setState(() {
      members = next;
      if (me != null) {
        mySeat = me.seatIndex;
        muted = me.micMuted;
      }
    });
  }

  Future<void> _loadGifts() async {
    final rows = await widget.state.backend.catalog('gift');
    if (!mounted) return;
    setState(() => gifts = rows.map(CatalogItem.fromMap).toList());
  }

  @override
  void dispose() {
    presenceTimer?.cancel();
    unawaited(
      widget.state.backend.leaveRoom(
        roomId: widget.room.id,
        userId: widget.state.userId,
      ),
    );
    final current = rtc;
    if (current != null) {
      unawaited(
        current.leave().whenComplete(() {
          if (current is LiveKitRtcAdapter) {
            current.dispose();
          } else if (current is LocalRtcAdapter) {
            current.dispose();
          }
        }),
      );
    }
    effects.dispose();
    silentLevels.dispose();
    unawaited(musicPlayer.dispose());
    super.dispose();
  }

  RoomMember? _memberAt(int seat) {
    for (final member in members) {
      if (member.seatIndex == seat) return member;
    }
    return null;
  }

  Future<void> _tapSeat(int seat) async {
    final occupant = _memberAt(seat);
    if (occupant != null && occupant.userId != widget.state.userId) return;
    final leaving = mySeat == seat;

    if (widget.state.backendConnected) {
      final ok = await widget.state.backend.setSeat(
        roomId: widget.room.id,
        userId: widget.state.userId,
        seatIndex: leaving ? null : seat,
        micMuted: true,
      );
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seat is not available')),
        );
        return;
      }
    }

    if (leaving && !muted) {
      await rtc?.setMicPublished(false);
    }
    if (!mounted) return;
    setState(() {
      mySeat = leaving ? null : seat;
      muted = true;
    });
    await _loadMembers();
  }

  Future<void> _toggleMic() async {
    if (mySeat == null) return;
    final enable = muted;
    try {
      await rtc?.setMicPublished(enable);
      if (widget.state.backendConnected) {
        await widget.state.backend.setSeat(
          roomId: widget.room.id,
          userId: widget.state.userId,
          seatIndex: mySeat,
          micMuted: !enable,
        );
      }
      if (!mounted) return;
      setState(() => muted = !enable);
      await _loadMembers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Microphone unavailable: $error')),
      );
    }
  }

  String _mediaUrl(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('https://')) return raw;
    if (BackendApi.origin.isEmpty) return '';
    return '${BackendApi.origin}/api/files?key=${Uri.encodeQueryComponent(raw)}';
  }

  Future<bool> _sendGift(GiftSelection selection) async {
    final result = await widget.state.backend.sendGift(
      roomId: widget.room.id,
      senderUserId: widget.state.userId,
      receiverUserId: selection.recipient.userId,
      giftId: selection.gift.id,
      quantity: selection.quantity,
    );
    if (!mounted) return false;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gift could not be sent')),
      );
      return false;
    }
    final balance =
        int.tryParse(result['sender_coin_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    final levelBefore =
        int.tryParse(result['level_before']?.toString() ?? '');
    final levelAfter =
        int.tryParse(result['level_after']?.toString() ?? '');
    effects.play(
      GiftEffectEvent(
        id: result['event_id']?.toString() ?? selection.gift.id,
        emoji: selection.gift.emoji,
        name: selection.quantity > 1
            ? '${selection.gift.name} ×${selection.quantity}'
            : selection.gift.name,
        sender: widget.state.displayName,
        receiver: selection.recipient.displayName,
        tier: selection.gift.effect,
        asset: _mediaUrl(selection.gift.data['asset']),
        levelBefore: levelBefore,
        levelAfter: levelAfter,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✨ ${selection.gift.name} ×${selection.quantity} sent',
        ),
      ),
    );
    return true;
  }

  Future<void> _openGifts() async {
    if (gifts.isEmpty) await _loadGifts();
    if (members.isEmpty) await _loadMembers();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => GiftSheet(
        gifts: gifts,
        members: members,
        currentUserId: widget.state.userId,
        onSend: _sendGift,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Room message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(hintText: 'Say something…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    if (widget.state.backendConnected) {
      await widget.state.backend.sendRoomMessage(
        roomId: widget.room.id,
        userId: widget.state.userId,
        text: value,
      );
    }
    if (!mounted) return;
    setState(() => chat.add('${widget.state.displayName}: $value'));
  }

  Future<void> _showMusic() async {
    final rows = await widget.state.backend.catalog('music');
    if (!mounted) return;
    final songs = rows.take(300).toList();
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 440,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.library_music_rounded),
                title: Text('Room Music'),
                subtitle: Text('Up to 300 owner-added songs • no demo songs'),
              ),
              const Divider(height: 1),
              Expanded(
                child: songs.isEmpty
                    ? const Center(
                        child: Text(
                          'No songs added by the owner yet.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final data = song['data'] is Map
                              ? Map<String, dynamic>.from(song['data'] as Map)
                              : <String, dynamic>{};
                          final media = _mediaUrl(data['asset']);
                          return ListTile(
                            leading: const Icon(Icons.music_note_rounded),
                            title: Text(song['name']?.toString() ?? 'Song'),
                            subtitle: Text(
                              data['description']?.toString() ??
                                  (media.isEmpty ? 'No audio file attached' : 'Tap to play'),
                            ),
                            trailing: media.isEmpty
                                ? null
                                : const Icon(Icons.play_arrow_rounded),
                            onTap: media.isEmpty
                                ? null
                                : () async {
                                    try {
                                      await musicPlayer.setUrl(media);
                                      await musicPlayer.play();
                                    } catch (_) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(content: Text('Song could not be played')),
                                      );
                                    }
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTools() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Room tools',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_music_rounded),
              title: const Text('Music'),
              subtitle: const Text('Owner-managed room music library'),
              onTap: () {
                Navigator.pop(sheetContext);
                unawaited(_showMusic());
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: const Text('Store & room themes'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreScreen(state: widget.state),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows_rounded),
              title: const Text('CP & Enemy levels'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RelationshipsScreen(state: widget.state),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = SeatLayoutSpec.forCount(widget.room.seatCount);
    final speaking = rtc?.speakingLevelsListenable ?? silentLevels;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.name),
            Text(
              'ID ${widget.room.id} • $voiceStatus',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openTools,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 5,
                child: ValueListenableBuilder<Map<String, double>>(
                  valueListenable: speaking,
                  builder: (context, levels, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final diameter =
                            spec.seatDiameter(constraints.maxWidth - 24);
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 14,
                            children: List<Widget>.generate(
                              widget.room.seatCount,
                              (seat) {
                                final member = _memberAt(seat);
                                final mine =
                                    member?.userId == widget.state.userId;
                                final activeLevel = member == null
                                    ? 0.0
                                    : (levels[member.userId] ?? 0);
                                final speakingNow = activeLevel >= .01;
                                return SizedBox(
                                  width: diameter + 28,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: member == null || mine
                                        ? () => unawaited(_tapSeat(seat))
                                        : null,
                                    child: Column(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          width: diameter,
                                          height: diameter,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              width: speakingNow
                                                  ? 4
                                                  : mine
                                                      ? 3
                                                      : 1,
                                              color: speakingNow
                                                  ? const Color(0xFF28D7A3)
                                                  : mine
                                                      ? const Color(0xFFFFD36A)
                                                      : Colors.white24,
                                            ),
                                            boxShadow: speakingNow
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF28D7A3,
                                                      ).withValues(
                                                        alpha: .25 +
                                                            activeLevel * .5,
                                                      ),
                                                      blurRadius:
                                                          12 + activeLevel * 18,
                                                      spreadRadius:
                                                          1 + activeLevel * 5,
                                                    ),
                                                  ]
                                                : const [],
                                          ),
                                          child: Center(
                                            child: member == null
                                                ? const Icon(Icons.add_rounded)
                                                : Text(
                                                    member.displayName.isEmpty
                                                        ? '?'
                                                        : member.displayName
                                                            .substring(0, 1)
                                                            .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          member?.displayName ??
                                              'Seat ${seat + 1}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 11),
                                        ),
                                        if (member != null)
                                          Text(
                                            'VIP ${member.vipLevel}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Colors.white54,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: chat.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(chat[index]),
                    ),
                  ),
                ),
              ),
            ],
          ),
          GiftEffectOverlay(controller: effects),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: _sendMessage,
                icon: const Icon(Icons.chat_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: mySeat == null ? null : _toggleMic,
                icon: Icon(
                  muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openGifts,
                icon: const Icon(Icons.card_giftcard_rounded),
                label: const Text('Gift'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
