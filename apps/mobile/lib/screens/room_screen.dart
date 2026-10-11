import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:livekit_client/livekit_client.dart';

import '../app/app_state.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../infra/realtime.dart';
import '../room/seat_layout.dart';
import '../vip/vip_policy.dart';
import 'aladdin_lamp_screen.dart';
import 'legal_policy_screen.dart';
import 'games_screen.dart';

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
  static final Set<String> _acceptedLegalInSession = <String>{};
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
  final Map<int, Map<String, dynamic>> membersBySeat = <int, Map<String, dynamic>>{};
  Timer? memberRefreshTimer;
  String? roomAvatarKey;
  String? roomAnnouncement;
  late String roomName;
  late int roomSeatCount;
  bool roomLocked = false;

  bool get isRoomHost => widget.room.ownerUserId == widget.state.userId;

  @override
  void initState() {
    super.initState();
    roomAvatarKey = widget.room.avatarKey;
    roomName = widget.room.name;
    roomSeatCount = widget.room.seatCount;
    unawaited(_connectVoice());
    unawaited(_loadRoomFollow());
    unawaited(_loadRoomMembers());
    memberRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_loadRoomMembers());
      unawaited(_loadRoomMessages());
    });
    unawaited(_loadRoomMessages());
  }

  Future<void> _loadRoomMembers() async {
    if (!widget.state.backendConnected) return;
    final rows = await widget.state.backend.roomMembers(roomId: widget.room.id);
    final next = <int, Map<String, dynamic>>{};
    for (final member in rows) {
      final seat = int.tryParse(member['seat_index']?.toString() ?? '');
      if (seat != null) next[seat] = member;
    }
    if (!mounted) return;
    setState(() {
      membersBySeat
        ..clear()
        ..addAll(next);
      final own = rows.where((member) => member['user_id']?.toString() == widget.state.userId);
      if (own.isNotEmpty) {
        mySeat = int.tryParse(own.first['seat_index']?.toString() ?? '');
      }
    });
  }

  Future<void> _loadRoomMessages() async {
    if (!widget.state.backendConnected) return;
    final rows = await widget.state.backend.roomMessages(roomId: widget.room.id);
    if (!mounted || rows.isEmpty && chat.length == 1 && chat.first == 'Welcome to the room 👋') return;
    final next = rows.map((message) {
      final name = message['display_name']?.toString().trim();
      final text = message['text']?.toString() ?? '';
      return '${name == null || name.isEmpty ? 'User' : name}: $text';
    }).where((message) => !message.endsWith(': ')).toList();
    if (!mounted || next.join('\n') == chat.join('\n')) return;
    setState(() {
      chat
        ..clear()
        ..addAll(next);
    });
  }

  static const _legalVersion = 'darkvibex-terms-privacy-2026-10-v1';

  Future<bool> _ensureLegalAgreement() async {
    final consentKey = '${widget.state.userId}:$_legalVersion';
    if (_acceptedLegalInSession.contains(consentKey)) return true;
    if (widget.state.backendConnected &&
        await widget.state.backend.legalConsentAccepted(version: _legalVersion)) {
      _acceptedLegalInSession.add(consentKey);
      return true;
    }
    if (!mounted) return false;
    var checked = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Room rules & agreement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please read the DarkVibeX Terms and Privacy notice before using room chat and voice. Be respectful, do not share unlawful or harmful content, and remember that other room participants can see or hear what you share.'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const LegalPolicyScreen(),
                  )),
                  child: const Text('Read Terms & Privacy'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: (value) => setDialogState(() => checked = value ?? false),
                  title: const Text('I have read and agree to the Terms and Privacy notice.'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Leave room')),
            FilledButton(
              onPressed: checked ? () => Navigator.pop(dialogContext, true) : null,
              child: const Text('Agree & continue'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      if (mounted) Navigator.of(context).pop();
      return false;
    }
    final saved = await widget.state.backend.acceptLegalConsent(version: _legalVersion);
    _acceptedLegalInSession.add(consentKey);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agreement is active for this session; server sync is unavailable.')),
      );
    }
    return true;
  }

  Future<void> _loadRoomSettings() async {
    final value = await widget.state.backend.roomSettings(roomId: widget.room.id);
    final settings = value?['settings'];
    if (!mounted || settings is! Map) return;
    setState(() {
      roomName = settings['name']?.toString() ?? roomName;
      roomSeatCount = int.tryParse(settings['seat_count']?.toString() ?? '') ?? roomSeatCount;
      roomLocked = settings['locked'] == true || settings['locked']?.toString() == '1';
      final text = settings['announcement']?.toString().trim() ?? '';
      roomAnnouncement = text.isEmpty ? null : text;
    });
  }

  Future<void> _openRoomSettings() async {
    if (!isRoomHost) return;
    final name = TextEditingController(text: roomName);
    final announcement = TextEditingController(text: roomAnnouncement ?? '');
    final seatOptions = [8, 10, 12, 15, 20, 25, 30, 35, 42]
        .where((count) => count <= VipPolicy.maxRoomSeats(widget.state.vipLevel))
        .toList();
    if (!seatOptions.contains(roomSeatCount)) seatOptions.add(roomSeatCount);
    seatOptions.sort();
    var seatCount = seatOptions.contains(roomSeatCount) ? roomSeatCount : seatOptions.last;
    var locked = roomLocked;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Room settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, maxLength: 80, decoration: const InputDecoration(labelText: 'Room name')),
                DropdownButtonFormField<int>(
                  value: seatCount,
                  decoration: const InputDecoration(labelText: 'Seat capacity'),
                  items: seatOptions
                      .map((count) => DropdownMenuItem(value: count, child: Text('$count seats')))
                      .toList(),
                  onChanged: (value) { if (value != null) setDialogState(() => seatCount = value); },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lock room'),
                  value: locked,
                  onChanged: (value) => setDialogState(() => locked = value),
                ),
                TextField(
                  controller: announcement,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Room announcement', hintText: 'Rules or message shown in room chat'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {
              'name': name.text.trim(),
              'seat_count': seatCount,
              'locked': locked,
              'announcement': announcement.text.trim(),
            }), child: const Text('Save')),
          ],
        ),
      ),
    );
    name.dispose();
    announcement.dispose();
    if (result == null || !mounted) return;
    final ok = await widget.state.backend.saveRoomSettings(
      roomId: widget.room.id,
      userId: widget.state.userId,
      name: result['name'] as String,
      seatCount: result['seat_count'] as int,
      locked: result['locked'] as bool,
      announcement: result['announcement'] as String,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room settings could not be saved')));
      return;
    }
    setState(() {
      roomName = result['name'] as String;
      roomSeatCount = result['seat_count'] as int;
      roomLocked = result['locked'] as bool;
      final text = result['announcement'] as String;
      roomAnnouncement = text.isEmpty ? null : text;
    });
    await widget.state.refreshRooms();
  }

  Future<void> _showRoomRules() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LegalPolicyScreen()),
    );
  }

  Future<void> _pickRoomAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    final type = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
    if (type == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a JPG, PNG or WebP image')),
      );
      return;
    }
    final key = await widget.state.backend.uploadImage(
      key: 'rooms/${widget.room.id}/avatar-${DateTime.now().microsecondsSinceEpoch}.${ext == 'jpeg' ? 'jpg' : ext}',
      bytes: await file.readAsBytes(),
      contentType: type,
    );
    if (key == null || !await widget.state.backend.setRoomAvatar(
      roomId: widget.room.id,
      userId: widget.state.userId,
      avatarKey: key,
    )) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room photo could not be saved')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => roomAvatarKey = key);
    widget.state.setRoomAvatarKey(widget.room.id, key);
  }

  Future<void> _connectVoice() async {
    if (!await _ensureLegalAgreement()) return;
    if (widget.state.backendConnected) {
      final joined = await widget.state.backend.joinRoom(
        roomId: widget.room.id,
        userId: widget.state.userId,
        displayName: widget.state.displayName,
      );
      if (!joined) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This room is locked or unavailable')),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      await _loadRoomSettings();
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
    unawaited(_loadRoomMembers());
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

  Future<void> _removeRoomMember(String targetUserId) async {
    if (!isRoomHost || targetUserId == widget.state.userId) return;
    final ok = await widget.state.backend.removeRoomMember(
      roomId: widget.room.id,
      ownerUserId: widget.state.userId,
      targetUserId: targetUserId,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove this member')),
      );
      return;
    }
    await _loadRoomMembers();
  }

  Future<void> _openRoomMembers() async {
    final members = await widget.state.backend.roomMembers(roomId: widget.room.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    const Expanded(child: Text('Room members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    Text('${members.length} online'),
                  ],
                ),
              ),
              Expanded(
                child: members.isEmpty
                    ? const Center(child: Text('No members are online'))
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final userId = member['user_id']?.toString() ?? '';
                          final name = member['display_name']?.toString().trim();
                          final avatar = member['avatar_key']?.toString();
                          final seat = int.tryParse(member['seat_index']?.toString() ?? '');
                          final isSelf = userId == widget.state.userId;
                          final isOwner = userId == widget.room.ownerUserId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: avatar != null && avatar.isNotEmpty
                                  ? NetworkImage(widget.state.backend.fileUrl(avatar))
                                  : null,
                              child: avatar == null || avatar.isEmpty
                                  ? const Icon(Icons.person_rounded)
                                  : null,
                            ),
                            title: Text('${name == null || name.isEmpty ? 'User $userId' : name}${isOwner ? ' • Owner' : ''}'),
                            subtitle: Text(seat == null ? 'Audience' : 'Seat ${seat + 1} • ${member['mic_muted'] == 1 || member['mic_muted']?.toString() == '1' ? 'Mic off' : 'Mic on'}'),
                            trailing: isRoomHost && !isSelf
                                ? IconButton(
                                    tooltip: 'Remove from room',
                                    icon: const Icon(Icons.person_remove_alt_1_rounded),
                                    onPressed: () async {
                                      Navigator.pop(sheetContext);
                                      await _removeRoomMember(userId);
                                    },
                                  )
                                : null,
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

  Future<void> _leaveRoom() async {
    if (widget.state.backendConnected) {
      final ok = await widget.state.backend.leaveRoom(
        roomId: widget.room.id,
        userId: widget.state.userId,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not leave the room on the server')),
        );
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openGames() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => GamesScreen(state: widget.state)),
    );
  }

  Future<void> _shareRoomId() async {
    await Clipboard.setData(ClipboardData(text: widget.room.id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room ID copied. Share it with friends to invite them.')),
    );
  }

  Future<void> _showRoomTools() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 6, 12),
                child: Text('Room tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.5,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _openRoomMembers(); },
                    icon: const Icon(Icons.groups_rounded), label: const Text('Members'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _openGames(); },
                    icon: const Icon(Icons.sports_esports_rounded), label: const Text('Games'),
                  ),
                  if (isRoomHost)
                    FilledButton.tonalIcon(
                      onPressed: () { Navigator.pop(sheetContext); _openRoomSettings(); },
                      icon: const Icon(Icons.settings_rounded), label: const Text('Settings'),
                    ),
                  if (isRoomHost)
                    FilledButton.tonalIcon(
                      onPressed: () { Navigator.pop(sheetContext); _pickRoomAvatar(); },
                      icon: const Icon(Icons.image_rounded), label: const Text('Room photo'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _shareRoomId(); },
                    icon: const Icon(Icons.share_rounded), label: const Text('Share room ID'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _showRoomRules(); },
                    icon: const Icon(Icons.policy_rounded), label: const Text('Terms & rules'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRoomMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy room ID'),
              subtitle: Text(widget.room.id),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: widget.room.id));
                if (!mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room ID copied')),
                );
              },
            ),
            if (isRoomHost)
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Room settings'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openRoomSettings();
                },
              ),
            if (isRoomHost)
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('Change room photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickRoomAvatar();
                },
              ),
            if (!isRoomHost)
              ListTile(
                leading: Icon(followingRoom ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                title: Text(followingRoom ? 'Unfollow room' : 'Follow room'),
                onTap: followBusy ? null : () {
                  Navigator.pop(sheetContext);
                  _toggleRoomFollow();
                },
              ),
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded),
              title: const Text('Leave room'),
              onTap: () {
                Navigator.pop(sheetContext);
                _leaveRoom();
              },
            ),
          ],
        ),
      ),
    );
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
      final sent = await widget.state.backend.sendRoomMessage(
        roomId: widget.room.id,
        userId: widget.state.userId,
        text: value,
      );
      if (!sent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message was not sent. Check your connection.')),
        );
        return;
      }
      await _loadRoomMessages();
      return;
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
    final spec = SeatLayoutSpec.forCount(roomSeatCount);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundImage: roomAvatarKey == null
                  ? null
                  : NetworkImage(widget.state.backend.fileUrl(roomAvatarKey!)),
              child: roomAvatarKey == null ? const Icon(Icons.mic_rounded, size: 18) : null,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roomName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    'ID ${widget.room.id} • $voiceStatus',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isRoomHost)
            IconButton(onPressed: _pickRoomAvatar, tooltip: 'Change room photo', icon: const Icon(Icons.add_a_photo_outlined)),
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
          if (isRoomHost)
            IconButton(onPressed: _openRoomSettings, tooltip: 'Room settings', icon: const Icon(Icons.settings_rounded)),
          IconButton(
            onPressed: _showRoomTools,
            tooltip: 'Room tools',
            icon: const Icon(Icons.grid_view_rounded),
          ),
          IconButton(
            onPressed: _openRoomMenu,
            tooltip: 'Room options',
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
                    children: List<Widget>.generate(roomSeatCount, (seat) {
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
                                child: Builder(
                                  builder: (context) {
                                    final member = membersBySeat[seat];
                                    final avatar = member?['avatar_key']?.toString();
                                    if (member != null && avatar != null && avatar.isNotEmpty) {
                                      return CircleAvatar(
                                        backgroundImage: NetworkImage(widget.state.backend.fileUrl(avatar)),
                                        child: Align(
                                          alignment: Alignment.bottomRight,
                                          child: Icon(
                                            member['mic_muted'] == 1 ? Icons.mic_off_rounded : Icons.mic_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    }
                                    return Icon(
                                      member != null
                                          ? Icons.person_rounded
                                          : mine
                                              ? (muted ? Icons.mic_off_rounded : Icons.mic_rounded)
                                              : Icons.add_rounded,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mine
                                    ? widget.state.displayName
                                    : (membersBySeat[seat]?['display_name']?.toString() ?? 'Seat ${seat + 1}'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFF2A1F12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.campaign_rounded, size: 18, color: Color(0xFFFFD36A)),
                            const SizedBox(width: 6),
                            const Expanded(child: Text('Room announcement & safety rules', style: TextStyle(fontWeight: FontWeight.w800))),
                            TextButton(onPressed: _showRoomRules, child: const Text('Terms')),
                          ]),
                          Text(roomAnnouncement ?? 'Be respectful. No harassment, explicit or unlawful content, scams, or sharing private information. Room chat and voice are visible to participants.'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: chat.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(chat[index]),
                      ),
                    ),
                  ),
                ],
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
