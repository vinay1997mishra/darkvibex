import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../app/app_state.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../infra/realtime.dart';
import '../room/seat_layout.dart';
import 'aladdin_lamp_screen.dart';

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
  EventsListener<RoomEvent>? rtcEvents;
  VideoTrack? localVideoTrack;
  final Map<String, VideoTrack> remoteVideoTracks = <String, VideoTrack>{};
  bool cameraPublished = false;
  bool followingRoom = false;
  bool followBusy = false;
  final List<String> chat = <String>['Welcome to the room 👋'];

  bool get isRoomHost => widget.room.ownerUserId == widget.state.userId;

  @override
  void initState() {
    super.initState();
    unawaited(_connectVoice());
    unawaited(_loadRoomFollow());
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
      if (candidate is LiveKitRtcAdapter) {
        _bindVideoTracks(candidate);
      }
      if (!mounted) return;
      setState(() {
        voiceStatus = candidate is LiveKitRtcAdapter
            ? 'Voice/video connected'
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

  void _bindVideoTracks(LiveKitRtcAdapter adapter) {
    final room = adapter.room;
    if (room == null) return;
    rtcEvents?.dispose();
    rtcEvents = room.createListener()
      ..on<TrackSubscribedEvent>((_) => _refreshVideoTracks(adapter))
      ..on<TrackUnsubscribedEvent>((_) => _refreshVideoTracks(adapter))
      ..on<TrackPublishedEvent>((_) => _refreshVideoTracks(adapter))
      ..on<TrackUnpublishedEvent>((_) => _refreshVideoTracks(adapter))
      ..on<ParticipantDisconnectedEvent>((_) => _refreshVideoTracks(adapter));
    _refreshVideoTracks(adapter);
  }

  void _refreshVideoTracks(LiveKitRtcAdapter adapter) {
    final room = adapter.room;
    if (room == null || !mounted) return;

    VideoTrack? local;
    final localParticipant = room.localParticipant;
    if (localParticipant != null) {
      for (final publication in localParticipant.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack && !publication.muted) {
          local = track;
          break;
        }
      }
    }

    final remotes = <String, VideoTrack>{};
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack && !publication.muted) {
          remotes[participant.identity] = track as VideoTrack;
          break;
        }
      }
    }

    setState(() {
      localVideoTrack = local;
      remoteVideoTracks
        ..clear()
        ..addAll(remotes);
    });
  }

  Future<void> _toggleCamera() async {
    if (mySeat == null) return;
    final adapter = rtc;
    if (adapter is! LiveKitRtcAdapter) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video needs the live room server')),
      );
      return;
    }

    final enable = !cameraPublished;
    try {
      await adapter.setCameraPublished(enable);
      if (!mounted) return;
      setState(() => cameraPublished = enable);
      _refreshVideoTracks(adapter);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera unavailable: $error')),
      );
    }
  }

  @override
  void dispose() {
    rtcEvents?.dispose();
    rtcEvents = null;
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
    if (leaving && cameraPublished && rtc is LiveKitRtcAdapter) {
      await (rtc as LiveKitRtcAdapter).setCameraPublished(false);
    }
    if (!mounted) return;
    setState(() {
      if (leaving) {
        mySeat = null;
        muted = true;
        cameraPublished = false;
        localVideoTrack = null;
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

  Future<void> _loadRoomFollow() async {
    if (isRoomHost || !widget.state.backendConnected) return;
    final following = await widget.state.backend.roomFollowStatus(
      roomId: widget.room.id,
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() => followingRoom = following);
  }

  Future<void> _toggleRoomFollow() async {
    if (isRoomHost || followBusy || !widget.state.backendConnected) return;
    setState(() => followBusy = true);
    final next = !followingRoom;
    final ok = await widget.state.backend.setRoomFollow(
      roomId: widget.room.id,
      userId: widget.state.userId,
      follow: next,
    );
    if (!mounted) return;
    setState(() {
      followBusy = false;
      if (ok) followingRoom = next;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update room follow')),
      );
    }
  }

  Future<void> _openLamp() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AladdinLampScreen(
          state: widget.state,
          room: widget.room,
        ),
      ),
    );
  }

  Future<String?> _chooseGiftReceiver() async {
    final members =
        await widget.state.backend.roomMembers(roomId: widget.room.id);
    if (!mounted) return null;
    final candidates = members
        .where((member) =>
            member['user_id']?.toString().isNotEmpty == true &&
            member['user_id']?.toString() != widget.state.userId)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other user is in the room yet')),
      );
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Send gift to',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final member in candidates)
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person_rounded),
                ),
                title: Text(
                  member['display_name']?.toString().trim().isNotEmpty == true
                      ? member['display_name'].toString()
                      : 'User ' + member['user_id'].toString(),
                ),
                subtitle: Text(
                  member['seat_index'] == null ? 'Audience' : 'On mic',
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  member['user_id'].toString(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendGift() async {
    const giftCost = 5000;
    String receiverId = widget.room.ownerUserId;

    if (isRoomHost) {
      if (!widget.state.backendConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connect to the server to send a host gift')),
        );
        return;
      }
      final selected = await _chooseGiftReceiver();
      if (selected == null || selected.isEmpty) return;
      receiverId = selected;
    }

    if (widget.state.backendConnected && receiverId.isNotEmpty) {
      final result = await widget.state.backend.sendGift(
        roomId: widget.room.id,
        senderUserId: widget.state.userId,
        receiverUserId: receiverId,
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
      SnackBar(
        content: Text(
          ok ? '✨ Gift sent • 5,000 coins' : 'Not enough coins',
        ),
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

  Widget _videoStage() {
    final entries = <MapEntry<String, VideoTrack>>[];
    if (localVideoTrack != null) {
      entries.add(MapEntry<String, VideoTrack>('You', localVideoTrack!));
    }
    entries.addAll(remoteVideoTracks.entries);
    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return SizedBox(
            width: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.black,
                      child: VideoTrackRenderer(entry.value),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
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
          if (!isRoomHost)
            IconButton(
              onPressed: followBusy ? null : _toggleRoomFollow,
              tooltip: followingRoom ? 'Unfollow room' : 'Follow room',
              icon: Icon(
                followingRoom
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: followingRoom ? const Color(0xFFFF5D8F) : null,
              ),
            ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
          _videoStage(),
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
          ),
          Positioned(
            right: 10,
            top: 112,
            child: _RoomLampButton(onTap: _openLamp),
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
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: mySeat == null ? null : _toggleCamera,
                icon: Icon(cameraPublished ? Icons.videocam_rounded : Icons.videocam_off_rounded),
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


class _RoomLampButton extends StatelessWidget {
  const _RoomLampButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 82,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFF4F178D),
                Color(0xFF8729E9),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFDF54),
              width: 1.3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFFD54A).withOpacity(.28),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 34,
                child: CustomPaint(painter: _MiniLampPainter()),
              ),
              SizedBox(height: 3),
              Text(
                'Aladdin\'s\nLamp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFEA83),
                  fontSize: 10,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLampPainter extends CustomPainter {
  const _MiniLampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFFFFF2A1),
          Color(0xFFFFC62C),
          Color(0xFFD88C00),
        ],
      ).createShader(Offset.zero & size);
    final body = Path()
      ..moveTo(size.width * .28, size.height * .50)
      ..quadraticBezierTo(
        size.width * .42,
        size.height * .30,
        size.width * .66,
        size.height * .47,
      )
      ..quadraticBezierTo(
        size.width * .70,
        size.height * .72,
        size.width * .43,
        size.height * .76,
      )
      ..quadraticBezierTo(
        size.width * .28,
        size.height * .72,
        size.width * .28,
        size.height * .50,
      )
      ..close();
    canvas.drawPath(body, gold);
    final spout = Path()
      ..moveTo(size.width * .30, size.height * .51)
      ..quadraticBezierTo(
        size.width * .13,
        size.height * .44,
        size.width * .06,
        size.height * .29,
      )
      ..quadraticBezierTo(
        size.width * .22,
        size.height * .33,
        size.width * .40,
        size.height * .47,
      )
      ..close();
    canvas.drawPath(spout, gold);
    final handle = Paint()
      ..color = const Color(0xFFFFDD53)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .70, size.height * .52),
        width: size.width * .25,
        height: size.height * .45,
      ),
      -1.2,
      2.5,
      false,
      handle,
    );
    canvas.drawCircle(
      Offset(size.width * .48, size.height * .22),
      2,
      Paint()..color = const Color(0xFFFFFFC5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
