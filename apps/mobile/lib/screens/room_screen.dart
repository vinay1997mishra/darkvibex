import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../infra/realtime.dart';
import '../room/seat_layout.dart';

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
  int? mySeat;
  bool muted = true;
  String voiceStatus = 'Connecting…';
  RtcAdapter? rtc;
  final List<String> chat = <String>['Welcome to the room 👋'];

  @override
  void initState() {
    super.initState();
    unawaited(_connectVoice());
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
        voiceStatus = candidate is LiveKitRtcAdapter
            ? 'Voice connected'
            : 'Local voice mode';
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

  @override
  void dispose() {
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
    super.dispose();
  }

  Future<void> _tapSeat(int seat) async {
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
      if (leaving) {
        mySeat = null;
        muted = true;
      } else {
        mySeat = seat;
        muted = true;
      }
    });
  }

  Future<void> _toggleMic() async {
    if (mySeat == null) return;
    final enable = muted;
    try {
      await rtc?.setMicPublished(enable);
      if (widget.state.backendConnected && mySeat != null) {
        await widget.state.backend.setSeat(
          roomId: widget.room.id,
          userId: widget.state.userId,
          seatIndex: mySeat,
          micMuted: !enable,
        );
      }
      if (!mounted) return;
      setState(() => muted = !enable);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Microphone unavailable: $error')),
      );
    }
  }

  Future<void> _sendGift() async {
    const giftCost = 5000;

    if (widget.state.backendConnected && widget.room.ownerUserId.isNotEmpty) {
      final result = await widget.state.backend.sendGift(
        roomId: widget.room.id,
        senderUserId: widget.state.userId,
        receiverUserId: widget.room.ownerUserId,
        giftId: 'basic-star',
        coinCost: giftCost,
      );
      final remoteBalance = int.tryParse(
        result?['sender_coin_balance']?.toString() ?? '',
      );
      if (remoteBalance != null) {
        widget.state.setCoinBalance(remoteBalance);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ Gift sent • 5,000 coins')),
        );
        return;
      }
    }

    final ok = widget.state.spendCoins(giftCost);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '✨ Gift sent • 5,000 coins' : 'Not enough coins')),
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    final spec = SeatLayoutSpec.forCount(widget.room.seatCount);

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
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final diameter = spec.seatDiameter(constraints.maxWidth - 24);
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 14,
                    children: List<Widget>.generate(widget.room.seatCount, (seat) {
                      final mine = mySeat == seat;
                      return SizedBox(
                        width: diameter + 26,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => unawaited(_tapSeat(seat)),
                          child: Column(
                            children: [
                              Container(
                                width: diameter,
                                height: diameter,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: mine ? 3 : 1,
                                    color: mine ? const Color(0xFFFFD36A) : Colors.white24,
                                  ),
                                ),
                                child: Icon(
                                  mine
                                      ? (muted ? Icons.mic_off_rounded : Icons.mic_rounded)
                                      : Icons.add_rounded,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mine ? widget.state.displayName : 'Seat ${seat + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
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
                border: Border(top: BorderSide(color: Colors.white12)),
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
                icon: Icon(muted ? Icons.mic_off_rounded : Icons.mic_rounded),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _sendGift,
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
