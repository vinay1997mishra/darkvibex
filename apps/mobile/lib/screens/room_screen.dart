import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:livekit_client/livekit_client.dart';

import '../app/app_state.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../infra/realtime.dart';
import '../room/seat_layout.dart';
import '../room/ktv_service.dart';
import '../vip/vip_policy.dart';
import '../widgets/vip_animated_frame.dart';
import '../ui/tinni_style.dart';
import '../widgets/vehicle_entry_effect.dart';
import 'aladdin_lamp_screen.dart';
import 'legal_policy_screen.dart';
import 'games_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';

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
  final List<Map<String, dynamic>> chat = <Map<String, dynamic>>[
    <String, dynamic>{'display_name': 'DarkVibeX', 'text': 'Welcome to the room 👋'},
  ];
  final TextEditingController roomChatController = TextEditingController();
  bool uploadingRoomImage = false;
  final Map<int, Map<String, dynamic>> membersBySeat = <int, Map<String, dynamic>>{};
  final Set<String> knownRoomMembers = <String>{};
  bool memberListInitialized = false;
  Timer? memberRefreshTimer;
  Timer? arrivalEffectTimer;
  Map<String, dynamic>? arrivalEffectMember;
  String? roomAvatarKey;
  String? roomAnnouncement;
  String? roomWelcomeImageKey;
  late String roomName;
  late int roomSeatCount;
  bool roomLocked = false;
  bool amRoomAdmin = false;
  String roomThemeId = 'dark';
  late String roomPartyMode;
  bool groupPkEnabled = false;
  bool effectsEnabled = true;
  final KtvService roomMusic = KtvService();

  bool get isRoomHost => widget.room.ownerUserId == widget.state.userId;
  bool get isRoomAdmin => isRoomHost || amRoomAdmin;

  @override
  void initState() {
    super.initState();
    roomAvatarKey = widget.room.avatarKey;
    roomName = widget.room.name;
    roomSeatCount = widget.room.seatCount;
    roomPartyMode = widget.room.partyMode;
    unawaited(roomMusic.loadLocalSongs());
    unawaited(_connectVoice());
    unawaited(_loadRoomFollow());
    unawaited(_loadRoomMembers());
    memberRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_loadRoomMembers());
      unawaited(_loadRoomMessages());
      unawaited(_loadRoomSettings());
    });
    unawaited(_loadRoomMessages());
  }

  Future<void> _loadRoomMembers() async {
    if (!widget.state.backendConnected) return;
    final rows = await widget.state.backend.roomMembers(roomId: widget.room.id);
    final next = <int, Map<String, dynamic>>{};
    final presentIds = rows.map((member) => member['user_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
    final arrivals = memberListInitialized
        ? rows.where((member) => !knownRoomMembers.contains(member['user_id']?.toString() ?? '')).toList()
        : const <Map<String, dynamic>>[];
    knownRoomMembers.removeWhere((id) => !presentIds.contains(id));
    knownRoomMembers.addAll(presentIds);
    memberListInitialized = true;
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
        amRoomAdmin = own.first['is_admin'] == true || own.first['is_admin']?.toString() == '1';
      }
    });
    for (final member in arrivals) {
      final level = int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0;
      final invisible = member['invisible_entry'] == true || member['invisible_entry']?.toString() == '1';
      if (level < 4 || invisible) continue;
      _showArrivalEffect(member);
    }
  }

  void _showArrivalEffect(Map<String, dynamic> member) {
    arrivalEffectTimer?.cancel();
    if (!mounted) return;
    setState(() => arrivalEffectMember = Map<String, dynamic>.from(member));
    arrivalEffectTimer = Timer(const Duration(milliseconds: 5000), () {
      if (mounted) setState(() => arrivalEffectMember = null);
    });
  }

  Future<void> _loadRoomMessages() async {
    if (!widget.state.backendConnected) return;
    final rows = await widget.state.backend.roomMessages(roomId: widget.room.id);
    if (!mounted || rows.isEmpty && chat.length == 1 && chat.first['text'] == 'Welcome to the room 👋') return;
    final next = rows.map((message) => Map<String, dynamic>.from(message)).toList();
    if (!mounted || next.toString() == chat.toString()) return;
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
      roomThemeId = settings['theme_id']?.toString() ?? roomThemeId;
      roomPartyMode = settings['party_mode']?.toString() ?? roomPartyMode;
      groupPkEnabled = settings['group_pk_enabled'] == true || settings['group_pk_enabled']?.toString() == '1';
      final text = settings['announcement']?.toString().trim() ?? '';
      roomAnnouncement = text.isEmpty ? null : text;
      final welcomeKey = settings['welcome_image_key']?.toString().trim() ?? '';
      roomWelcomeImageKey = welcomeKey.isEmpty ? null : welcomeKey;
    });
  }

  Future<void> _openRoomSettings() async {
    if (!isRoomHost) return;
    final name = TextEditingController(text: roomName);
    final announcement = TextEditingController(text: roomAnnouncement ?? '');
    final seatOptions = <int>[
      for (var count = 8; count <= 42; count++) count,
    ].where((count) => count <= VipPolicy.maxRoomSeats(
              widget.state.vipIsActive ? widget.state.vipLevel : 0,
            ))
        .toList();
    if (!seatOptions.contains(roomSeatCount)) seatOptions.add(roomSeatCount);
    seatOptions.sort();
    var seatCount = seatOptions.contains(roomSeatCount) ? roomSeatCount : seatOptions.last;
    var locked = roomLocked;
    var themeId = roomThemeId;
    var partyMode = roomPartyMode;
    var pkEnabled = groupPkEnabled;
    var welcomeImageKey = roomWelcomeImageKey ?? '';
    var welcomeUploading = false;
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
                DropdownButtonFormField<String>(
                  value: partyMode,
                  decoration: const InputDecoration(labelText: 'Party mode'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Friends-making Party',
                      child: Text('Friends Party'),
                    ),
                    DropdownMenuItem(
                      value: 'Event hosting mode',
                      child: Text('Event Mode'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => partyMode = value);
                  },
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: !widget.state.hasVipPrivilege('picture_welcome') || welcomeUploading
                      ? null
                      : () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 82,
                            maxWidth: 1440,
                            maxHeight: 1440,
                          );
                          if (file == null || !dialogContext.mounted) return;
                          final ext = file.name.split('.').last.toLowerCase();
                          final contentType = switch (ext) {
                            'jpg' || 'jpeg' => 'image/jpeg',
                            'png' => 'image/png',
                            'webp' => 'image/webp',
                            _ => null,
                          };
                          if (contentType == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Choose a JPG, PNG or WebP image.')),
                            );
                            return;
                          }
                          setDialogState(() => welcomeUploading = true);
                          try {
                            final normalizedExt = ext == 'jpeg' ? 'jpg' : ext;
                            final key = await widget.state.backend.uploadImage(
                              key: 'users/${widget.state.userId}/welcome-${widget.room.id}-${DateTime.now().microsecondsSinceEpoch}.$normalizedExt',
                              bytes: await file.readAsBytes(),
                              contentType: contentType,
                            );
                            if (key == null) throw StateError('upload_failed');
                            if (dialogContext.mounted) setDialogState(() => welcomeImageKey = key);
                          } catch (_) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Picture welcome could not be uploaded.')),
                            );
                          } finally {
                            if (dialogContext.mounted) setDialogState(() => welcomeUploading = false);
                          }
                        },
                  icon: welcomeUploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(welcomeImageKey.isEmpty ? 'Set picture welcome (VIP5)' : 'Change picture welcome'),
                ),
                if (!widget.state.hasVipPrivilege('picture_welcome'))
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Requires active VIP5 or above', style: TextStyle(fontSize: 12, color: Colors.white60)),
                  ),
                if (welcomeImageKey.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setDialogState(() => welcomeImageKey = ''),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove welcome picture'),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  value: themeId,
                  decoration: InputDecoration(
                    labelText: 'Room theme (visible to everyone)',
                    helperText: widget.state.hasVipPrivilege('room_background')
                        ? 'VIP room background unlocked'
                        : 'VIP3 unlocks custom room backgrounds',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                    DropdownMenuItem(value: 'midnight', child: Text('Midnight')),
                    DropdownMenuItem(value: 'rose', child: Text('Rose')),
                    DropdownMenuItem(value: 'forest', child: Text('Forest')),
                    DropdownMenuItem(value: 'gold', child: Text('Gold')),
                  ],
                  onChanged: widget.state.hasVipPrivilege('room_background')
                      ? (value) { if (value != null) setDialogState(() => themeId = value); }
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Group PK mode'),
                  subtitle: const Text('Shared room mode indicator'),
                  value: pkEnabled,
                  onChanged: (value) => setDialogState(() => pkEnabled = value),
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
              'theme_id': themeId,
              'party_mode': partyMode,
              'group_pk_enabled': pkEnabled,
              'welcome_image_key': welcomeImageKey,
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
      themeId: result['theme_id'] as String,
      partyMode: result['party_mode'] as String,
      groupPkEnabled: result['group_pk_enabled'] as bool,
      welcomeImageKey: result['welcome_image_key'] as String,
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
      roomThemeId = result['theme_id'] as String;
      roomPartyMode = result['party_mode'] as String;
      groupPkEnabled = result['group_pk_enabled'] as bool;
      final welcomeKey = result['welcome_image_key'] as String;
      roomWelcomeImageKey = welcomeKey.isEmpty ? null : welcomeKey;
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
      await widget.state.refreshIdLevel(notify: false);
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
    memberRefreshTimer?.cancel();
    arrivalEffectTimer?.cancel();
    roomChatController.dispose();
    unawaited(roomMusic.dispose());
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

    if (leaving) await roomMusic.stopForSeatDown(widget.state.userId);
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

  Future<void> _removeRoomMember(String targetUserId, {bool ban = false}) async {
    if (!isRoomAdmin || targetUserId == widget.state.userId || targetUserId == widget.room.ownerUserId) return;
    final ok = await widget.state.backend.removeRoomMember(
      roomId: widget.room.id,
      actorUserId: widget.state.userId,
      targetUserId: targetUserId,
      ban: ban,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ban ? 'Could not block this member' : 'Could not remove this member')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ban ? 'Member blocked from this room' : 'Member removed from this room')),
    );
    await _loadRoomMembers();
  }

  Future<void> _setRoomAdmin(String targetUserId, {required bool admin}) async {
    if (!isRoomHost || targetUserId == widget.state.userId || targetUserId == widget.room.ownerUserId) return;
    final ok = await widget.state.backend.setRoomAdmin(
      roomId: widget.room.id,
      actorUserId: widget.state.userId,
      targetUserId: targetUserId,
      admin: admin,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? (admin ? 'Room admin added' : 'Room admin removed') : 'Could not update room admin'),
    ));
    if (ok) await _loadRoomMembers();
  }

  Future<void> _reportRoom() async {
    const reasons = ['Harassment', 'Inappropriate content', 'Spam or scam', 'Safety concern', 'Other'];
    var reason = reasons.first;
    final details = TextEditingController();
    final report = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Report this room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                items: reasons.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) { if (value != null) setDialogState(() => reason = value); },
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              TextField(
                controller: details,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Details (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, (reason, details.text.trim())), child: const Text('Submit')),
          ],
        ),
      ),
    );
    final detailText = details.text.trim();
    details.dispose();
    if (report == null || !mounted) return;
    final ok = await widget.state.backend.reportRoom(
      roomId: widget.room.id,
      userId: widget.state.userId,
      reason: report.$1,
      details: report.$2.isEmpty ? detailText : report.$2,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Room report submitted' : 'Could not submit report')),
    );
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
                          final canModerate = !isSelf && !isOwner &&
                              ((isRoomHost) || (isRoomAdmin && member['is_admin'] != true && member['is_admin']?.toString() != '1'));
                          return ListTile(
                            onTap: isSelf
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    Future<void>.delayed(Duration.zero, () {
                                      if (!mounted) return;
                                      Navigator.of(this.context).push(MaterialPageRoute<void>(
                                        builder: (_) => PublicProfileScreen(state: widget.state, userId: userId),
                                      ));
                                    });
                                  },
                            leading: VipAnimatedFrame(
                              size: 44,
                              enabled: (int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0) >= 7,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(widget.state.backend.fileUrl(avatar), headers: widget.state.backend.fileHeaders) : null,
                                child: avatar == null || avatar.isEmpty ? const Icon(Icons.person_rounded, size: 20) : null,
                              ),
                            ),
                            title: Text('${name == null || name.isEmpty ? 'User $userId' : name}${isOwner ? ' • Owner' : (member['is_admin'] == true || member['is_admin']?.toString() == '1' ? ' • Admin' : '')}${(int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0) >= 9 && member['mic_muted'] != 1 && member['mic_muted']?.toString() != '1' ? '  🎤✨' : ''}'),
                            subtitle: Text(seat == null ? 'Audience' : 'Seat ${seat + 1} • ${member['mic_muted'] == 1 || member['mic_muted']?.toString() == '1' ? 'Mic off' : 'Mic on'}'),
                            trailing: !isSelf && (widget.state.hasVipPrivilege('free_say_hi') || canModerate)
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.state.hasVipPrivilege('free_say_hi') && widget.state.vipFreeSayHiRemaining > 0)
                                        IconButton(
                                          tooltip: 'Free Say Hi (${widget.state.vipFreeSayHiRemaining} left)',
                                          icon: const Icon(Icons.waving_hand_rounded, color: Color(0xFFFFD36A)),
                                          onPressed: () => _composeVipSayHi(context, userId, name?.isNotEmpty == true ? name! : 'User'),
                                        ),
                                      if (canModerate)
                                        PopupMenuButton<String>(
                                    tooltip: 'Member actions',
                                    onSelected: (action) async {
                                      Navigator.pop(sheetContext);
                                      if (action == 'set_admin') {
                                        await _setRoomAdmin(userId, admin: true);
                                      } else if (action == 'remove_admin') {
                                        await _setRoomAdmin(userId, admin: false);
                                      } else {
                                        await _removeRoomMember(userId, ban: action == 'block');
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (isRoomHost)
                                        PopupMenuItem(
                                          value: (member['is_admin'] == true || member['is_admin']?.toString() == '1') ? 'remove_admin' : 'set_admin',
                                          child: Text((member['is_admin'] == true || member['is_admin']?.toString() == '1') ? 'Remove admin role' : 'Make room admin'),
                                        ),
                                      const PopupMenuItem(value: 'remove', child: Text('Remove from room')),
                                      const PopupMenuItem(value: 'block', child: Text('Block from room')),
                                    ],
                                        ),
                                    ],
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

  Future<void> _composeVipSayHi(BuildContext context, String receiverId, String receiverName) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Free Say Hi to $receiverName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Write up to 30 words'),
            ),
            Text('${widget.state.vipFreeSayHiRemaining} free messages remaining'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Send')),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.isEmpty || !mounted) return;
    final sent = await widget.state.sendVipSayHi(receiverUserId: receiverId, message: message);
    if (!mounted || !context.mounted) return;
    final reason = widget.state.vipError;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent ? 'Free Say Hi sent' : (reason == 'say_hi_disabled_by_receiver' ? 'This user has disabled Say Hi' : reason ?? 'Say Hi could not be sent')),
    ));
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
    await roomMusic.stopRoomPlayback();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openGames() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => GamesScreen(state: widget.state)),
    );
  }

  Future<void> _shareRoomId() async {
    await Clipboard.setData(ClipboardData(text: widget.room.id));
    final result = widget.state.backendConnected
        ? await widget.state.backend.shareRoomForIdLevel(
            userId: widget.state.userId,
            roomId: widget.room.id,
          )
        : null;
    await widget.state.refreshIdLevel(notify: false);
    if (!mounted) return;
    final gained = int.tryParse(result?['id_level_daily_exp']?.toString() ?? '') ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(gained > 0
          ? 'Room ID copied • +$gained ID Level EXP today'
          : 'Room ID copied. Daily room-share EXP was already claimed.')),
    );
  }

  Color get _roomThemeColor => switch (roomThemeId) {
    'midnight' => const Color(0xFF111B32),
    'rose' => const Color(0xFF32192B),
    'forest' => const Color(0xFF14281F),
    'gold' => const Color(0xFF171006),
    _ => TinniPalette.black,
  };

  Future<void> _showRoomMusic() async {
    if (mySeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Take a seat to control room music')));
      return;
    }
    await roomMusic.loadLocalSongs();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: Column(
              children: [
                const ListTile(
                  title: Text('Phone music / KTV', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Audio plays on this device only. Add local audio files to your queue.'),
                ),
                ListTile(
                  leading: const Icon(Icons.library_music_rounded),
                  title: Text(roomMusic.current?.song.title ?? 'Nothing playing'),
                  subtitle: Text('Queue: ${roomMusic.queue.length} • Library: ${roomMusic.localSongCount}/${KtvService.maxLocalSongs}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(tooltip: 'Previous', onPressed: roomMusic.canPlayPrevious ? () async { await roomMusic.playPrevious(); refresh(() {}); } : null, icon: const Icon(Icons.skip_previous_rounded)),
                      IconButton(tooltip: roomMusic.isPlaying ? 'Pause' : 'Play', onPressed: roomMusic.current == null ? null : () async { await roomMusic.togglePlayPause(); refresh(() {}); }, icon: Icon(roomMusic.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
                      IconButton(tooltip: 'Next', onPressed: roomMusic.canPlayNext ? () async { await roomMusic.playNext(); refresh(() {}); } : null, icon: const Icon(Icons.skip_next_rounded)),
                      IconButton(tooltip: roomMusic.outputMuted ? 'Unmute music' : 'Mute music', onPressed: () async { await roomMusic.setOutputMuted(!roomMusic.outputMuted); refresh(() {}); }, icon: Icon(roomMusic.outputMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
                    ],
                  ),
                ),
                if (roomMusic.playbackError != null)
                  Padding(padding: const EdgeInsets.all(8), child: Text('Playback error: ${roomMusic.playbackError}', style: const TextStyle(color: Colors.redAccent))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: roomMusic.canAddLocalSong ? () async {
                          final files = await FilePicker.pickFiles(type: FileType.audio);
                          if (files.isEmpty) return;
                          for (final file in files) {
                            final path = file.path;
                            if (path == null) continue;
                            try { await roomMusic.importLocalSong(fileName: file.name, sourcePath: path); }
                            catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
                          }
                          refresh(() {});
                        } : null,
                        icon: const Icon(Icons.add_rounded), label: const Text('Add phone audio'),
                      )),
                      const SizedBox(width: 8),
                      IconButton(tooltip: 'Stop and clear queue', onPressed: () async { await roomMusic.stopRoomPlayback(); refresh(() {}); }, icon: const Icon(Icons.stop_rounded)),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(child: ListView.builder(
                  itemCount: roomMusic.library.where((song) => song.local).length,
                  itemBuilder: (context, index) {
                    final songs = roomMusic.library.where((song) => song.local).toList(growable: false);
                    final song = songs[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note_rounded),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.singer),
                      trailing: IconButton(
                        tooltip: 'Queue song',
                        icon: const Icon(Icons.queue_music_rounded),
                        onPressed: () { roomMusic.addToQueue(song, widget.state.userId); refresh(() {}); },
                      ),
                      onTap: () async { roomMusic.addToQueue(song, widget.state.userId); await roomMusic.playNext(); refresh(() {}); },
                    );
                  },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLuckyPouch() async {
    if (!widget.state.backendConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to the room server to use Lucky Pouch')));
      return;
    }
    Future<Map<String, dynamic>?> refreshPouch() async {
      final response = await widget.state.backend.roomLuckyPouch(roomId: widget.room.id);
      final pouch = response?['pouch'];
      return pouch is Map ? Map<String, dynamic>.from(pouch) : null;
    }
    var pouch = await refreshPouch();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Lucky Pouch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (pouch == null) ...[
                  const Text('No active pouch. Members can create one using their coins.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final values = await showDialog<(int, int)>(
                        context: context,
                        builder: (dialogContext) {
                          var coins = 5000;
                          var slots = 10;
                          return StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
                            title: const Text('Create Lucky Pouch'),
                            content: Column(mainAxisSize: MainAxisSize.min, children: [
                              DropdownButtonFormField<int>(
                                value: coins,
                                decoration: const InputDecoration(labelText: 'Coin amount'),
                                items: const [5000, 10000, 25000, 50000].map((n) => DropdownMenuItem(value: n, child: Text('$n coins'))).toList(),
                                onChanged: (v) { if (v != null) setDialogState(() => coins = v); },
                              ),
                              DropdownButtonFormField<int>(
                                value: slots,
                                decoration: const InputDecoration(labelText: 'Winners'),
                                items: const [5, 10, 20].map((n) => DropdownMenuItem(value: n, child: Text('$n people'))).toList(),
                                onChanged: (v) { if (v != null) setDialogState(() => slots = v); },
                              ),
                            ]),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(dialogContext, (coins, slots)), child: const Text('Create')),
                            ],
                          ));
                        },
                      );
                      if (values == null) return;
                      final result = await widget.state.backend.createRoomLuckyPouch(
                        roomId: widget.room.id,
                        userId: widget.state.userId,
                        totalCoins: values.$1,
                        slots: values.$2,
                        requestId: '${widget.state.userId}-${DateTime.now().microsecondsSinceEpoch}',
                      );
                      final balance = int.tryParse(result?['coin_balance']?.toString() ?? '');
                      if (balance != null) widget.state.setCoinBalance(balance);
                      pouch = await refreshPouch();
                      if (pouch == null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create pouch. Check your coin balance or active pouch.')));
                      refresh(() {});
                    },
                    icon: const Icon(Icons.redeem_rounded),
                    label: const Text('Create with coins'),
                  ),
                ] else ...[
                  Text('${pouch!['remaining_coins']} coins left • ${pouch!['remaining_slots']} winners'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: (pouch!['claimed'] == true || pouch!['claimed']?.toString() == '1') || (int.tryParse(pouch!['remaining_slots']?.toString() ?? '0') ?? 0) == 0 ? null : () async {
                      final result = await widget.state.backend.claimRoomLuckyPouch(roomId: widget.room.id, userId: widget.state.userId);
                      final amount = int.tryParse(result?['amount']?.toString() ?? '');
                      final balance = int.tryParse(result?['coin_balance']?.toString() ?? '');
                      if (balance != null) widget.state.setCoinBalance(balance);
                      if (amount != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lucky Pouch: +$amount coins')));
                      pouch = await refreshPouch();
                      refresh(() {});
                    },
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: Text((pouch!['claimed'] == true || pouch!['claimed']?.toString() == '1') ? 'Already claimed' : 'Claim coins'),
                  ),
                  TextButton(onPressed: () async { pouch = await refreshPouch(); refresh(() {}); }, child: const Text('Refresh')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLuckyNumber() async {
    final number = Random.secure().nextInt(99) + 1;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lucky Number'),
        content: Text('Your number is $number. This is a local for-fun draw; it does not award coins.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _toggleRoomSound() async {
    await roomMusic.setOutputMuted(!roomMusic.outputMuted);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(roomMusic.outputMuted ? 'Room music muted on this device' : 'Room music sound enabled on this device'),
    ));
  }

  Future<void> _showPublicScreen() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(roomName),
        content: Text(roomAnnouncement?.isNotEmpty == true
            ? roomAnnouncement!
            : 'No owner announcement is set. Room safety rules are shown to everyone here.'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(dialogContext); _showRoomRules(); }, child: const Text('Terms & rules')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _toggleRoomEffects() async {
    setState(() => effectsEnabled = !effectsEnabled);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(effectsEnabled ? 'Room glow effects enabled on this device' : 'Room glow effects disabled on this device')));
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
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _showRoomMusic(); },
                    icon: const Icon(Icons.music_note_rounded), label: const Text('Music / KTV'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _showLuckyPouch(); },
                    icon: const Icon(Icons.redeem_rounded), label: const Text('Lucky Pouch'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _showLuckyNumber(); },
                    icon: const Icon(Icons.casino_rounded), label: const Text('Lucky Number'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _toggleRoomEffects(); },
                    icon: Icon(effectsEnabled ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined), label: const Text('Effects'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _toggleRoomSound(); },
                    icon: Icon(roomMusic.outputMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded), label: const Text('Sound On / Off'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _showPublicScreen(); },
                    icon: const Icon(Icons.tv_rounded), label: const Text('Public Screen'),
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
                  FilledButton.tonalIcon(
                    onPressed: () { Navigator.pop(sheetContext); _reportRoom(); },
                    icon: const Icon(Icons.flag_outlined), label: const Text('Report room'),
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
    String receiverId = widget.room.ownerUserId;
    if (isRoomHost) {
      if (!widget.state.backendConnected) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to the server to send a gift')));
        return;
      }
      final selected = await _chooseGiftReceiver();
      if (selected == null || selected.isEmpty) return;
      receiverId = selected;
    }
    final gifts = widget.state.backendConnected
        ? await widget.state.backend.giftCatalog(userId: widget.state.userId)
        : <Map<String, dynamic>>[{'id': 'basic-star', 'name': 'Star', 'emoji': '⭐', 'coin_cost': 5000}];
    if (!mounted || gifts.isEmpty) return;
    final gift = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(18), child: Text('Choose a gift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          ...gifts.map((item) => ListTile(
            leading: Text(item['emoji']?.toString() ?? '🎁', style: const TextStyle(fontSize: 30)),
            title: Text(item['name']?.toString() ?? 'Gift'),
            subtitle: Text('${item['coin_cost'] ?? 0} coins'),
            onTap: () => Navigator.pop(sheetContext, item),
          )),
        ]),
      ),
    );
    if (!mounted || gift == null) return;
    final giftId = gift['id']?.toString() ?? 'basic-star';
    final giftCost = int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
    if (widget.state.backendConnected && receiverId.isNotEmpty) {
      final result = await widget.state.backend.sendGift(
        roomId: widget.room.id, senderUserId: widget.state.userId,
        receiverUserId: receiverId, giftId: giftId, coinCost: giftCost,
      );
      final remoteBalance = int.tryParse(result?['sender_coin_balance']?.toString() ?? '');
      if (remoteBalance != null) {
        widget.state.setCoinBalance(remoteBalance);
        await widget.state.refreshIdLevel(notify: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${gift['emoji'] ?? '🎁'} ${gift['name'] ?? 'Gift'} sent • $giftCost coins')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gift was not sent. Check VIP access and coin balance.')));
      return;
    }
    final ok = widget.state.spendCoins(giftCost);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '${gift['emoji'] ?? '🎁'} ${gift['name'] ?? 'Gift'} sent • $giftCost coins' : 'Not enough coins')));
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
    setState(() => chat.add(<String, dynamic>{'display_name': widget.state.displayName, 'text': value}));
  }

  Future<void> _sendRoomImage() async {
    if (!widget.state.hasVipPrivilege('send_pictures')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room photo messages unlock at VIP10.')),
      );
      return;
    }
    if (!widget.state.backendConnected || uploadingRoomImage) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1440,
      maxHeight: 1440,
    );
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    if (contentType == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a JPG, PNG or WebP image.')),
      );
      return;
    }
    setState(() => uploadingRoomImage = true);
    try {
      final bytes = await file.readAsBytes();
      final normalizedExt = ext == 'jpeg' ? 'jpg' : ext;
      final key = await widget.state.backend.uploadImage(
        key: 'messages/${widget.state.userId}/room-${widget.room.id}-${DateTime.now().microsecondsSinceEpoch}.$normalizedExt',
        bytes: bytes,
        contentType: contentType,
      );
      if (key == null) throw StateError('upload_failed');
      final sent = await widget.state.backend.sendRoomMessage(
        roomId: widget.room.id,
        userId: widget.state.userId,
        imageKey: key,
      );
      if (!sent) throw StateError('send_failed');
      await _loadRoomMessages();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo could not be sent. Check your connection and try again.')),
      );
    } finally {
      if (mounted) setState(() => uploadingRoomImage = false);
    }
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
      backgroundColor: _roomThemeColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundImage: roomAvatarKey == null
                  ? null
                  : NetworkImage(widget.state.backend.fileUrl(roomAvatarKey!), headers: widget.state.backend.fileHeaders),
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
                                    color: mine ? TinniPalette.brightGold : (effectsEnabled ? TinniPalette.deepGold : TinniPalette.bronze),
                                  ),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final member = membersBySeat[seat];
                                    final avatar = member?['avatar_key']?.toString();
                                    if (member != null) {
                                      final vipLevel = int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0;
                                      final activeFrame = member['active_frame_id']?.toString();
                                      final frameTier = switch (activeFrame) {
                                        'frame_royal' => 1,
                                        'frame_king' => 18,
                                        'frame_phoenix' => 8,
                                        'frame_sapphire' => 4,
                                        _ => vipLevel,
                                      };
                                      final micOn = member['mic_muted'] == 0 || member['mic_muted']?.toString() == '0';
                                      return VipAnimatedFrame(
                                        size: diameter - 2,
                                        enabled: activeFrame != null || vipLevel >= 7 || (vipLevel >= 16 && micOn),
                                        level: frameTier,
                                        styleId: activeFrame,
                                        child: CircleAvatar(
                                          backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(widget.state.backend.fileUrl(avatar), headers: widget.state.backend.fileHeaders) : null,
                                          child: Stack(alignment: Alignment.bottomRight, children: [
                                            if (avatar == null || avatar.isEmpty) const Center(child: Icon(Icons.person_rounded)),
                                            Icon(micOn ? Icons.mic_rounded : Icons.mic_off_rounded, size: 13, color: Colors.white),
                                          ]),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      mine
                                          ? (widget.state.vipAnonymousEverywhere ? 'Anonymous' : widget.state.displayName)
                                          : (membersBySeat[seat]?['display_name']?.toString() ?? 'Seat ${seat + 1}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  if (mine && widget.state.hasVipPrivilege('mic_chair'))
                                    const Padding(
                                      padding: EdgeInsets.only(left: 3),
                                      child: Icon(Icons.chair_alt_rounded, size: 13, color: Color(0xFFFFD36A)),
                                    ),
                                ],
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
                          if (roomWelcomeImageKey?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  widget.state.backend.fileUrl(roomWelcomeImageKey!),
                                  height: 116,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 48,
                                    child: Center(child: Text('Welcome picture unavailable')),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: chat.length,
                      itemBuilder: (context, index) {
                        final message = chat[index];
                        final name = message['display_name']?.toString().trim();
                        final text = message['text']?.toString() ?? '';
                        final imageKey = message['image_key']?.toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (text.isNotEmpty)
                                Text('${name == null || name.isEmpty ? 'User' : name}: $text'),
                              if (imageKey != null && imageKey.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      widget.state.backend.fileUrl(imageKey),
                                      width: 210,
                                      height: 160,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(
                                        width: 210,
                                        height: 64,
                                        child: Center(child: Text('Photo unavailable')),
                                      ),
                                    ),
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
          ),
              ],
            ),
          ),
          if (groupPkEnabled)
            Positioned(
              left: 12,
              top: 8,
              child: Chip(
                avatar: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('GROUP PK MODE'),
                backgroundColor: const Color(0xFF5D1E65),
              ),
            ),
          Positioned(
            right: 10,
            top: 112,
            child: _RoomLampButton(onTap: _openLamp),
          ),
          if (arrivalEffectMember != null)
            Positioned.fill(
              child: VehicleEntryEffect(
                displayName: (arrivalEffectMember?['display_name']?.toString().trim().isNotEmpty == true)
                    ? arrivalEffectMember!['display_name'].toString()
                    : 'VIP member',
                level: int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0,
                showVehicle: (int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0) >= 8 ||
                    arrivalEffectMember?['active_vehicle_id'] != null,
                customVehicle: arrivalEffectMember?['active_vehicle_id']?.toString() == 'vehicle_king' ||
                    (int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0) >= 18,
                vehicleLabel: switch (arrivalEffectMember?['active_vehicle_id']?.toString()) {
                  'vehicle_king' => 'KING OF VIP',
                  'vehicle_phoenix' => 'PHOENIX GT',
                  'vehicle_royal' => 'ROYAL CHARIOT',
                  'vehicle_spark' => 'STARLIGHT COUPE',
                  _ => null,
                },
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
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: uploadingRoomImage ? null : _sendRoomImage,
                tooltip: 'Send room photo (VIP10)',
                icon: uploadingRoomImage
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image_rounded),
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
