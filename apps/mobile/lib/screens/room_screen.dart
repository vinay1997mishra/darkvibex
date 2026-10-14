import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_state.dart';
import '../background/room_foreground_service.dart';
import '../background/room_permission_bridge.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../infra/realtime.dart';
import '../room/seat_layout.dart';
import '../room/ktv_service.dart';
import '../widgets/vip_animated_frame.dart';
import '../ui/tinni_style.dart';
import '../widgets/vehicle_entry_effect.dart';
import '../widgets/room_floating_logos.dart';
import 'aladdin_lamp_screen.dart';
import 'legal_policy_screen.dart';
import 'games_screen.dart';
import 'fruit_party_screen.dart';
import 'greedy_girl_screen.dart';
import 'home_shell.dart';
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
  static const List<int> _rocketStageTargets = <int>[
    8000000,
    15000000,
    30000000,
    50000000,
    90000000,
    150000000,
    200000000,
    250000000,
    350000000,
    500000000,
  ];
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
  List<Map<String, dynamic>> roomMembers = <Map<String, dynamic>>[];
  int roomGiftLifetimeTotal = 0;
  List<Map<String, dynamic>> roomGiftRanking = <Map<String, dynamic>>[];
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
  bool roomPasswordSet = false;
  String? roomLockCode;
  bool amRoomAdmin = false;
  String roomThemeId = 'dark';
  String? roomThemeAssetKey;
  String roomSeatThemeId = 'royal-gold';
  late String roomPartyMode;
  late String roomMode;
  bool groupPkEnabled = false;
  String roomMicMode = 'free';
  bool publicScreenEnabled = true;
  bool chatBanned = false;
  final Set<int> lockedSeats = <int>{};
  final Set<int> roomMutedSeats = <int>{};
  List<Map<String, dynamic>> seatRequests = <Map<String, dynamic>>[];
  Map<String, dynamic>? pendingSeatInvite;
  bool seatInviteDialogVisible = false;
  bool effectsEnabled = true;
  bool roomNoticesEnabled = true;
  bool giftEffectsEnabled = true;
  bool giftSoundEnabled = true;
  bool giftFlyInEnabled = true;
  bool carEffectsEnabled = true;
  bool giftBubbleEnabled = true;
  bool rocketDrawNoticeEnabled = true;
  Map<String, dynamic>? activeGiftEffect;
  Timer? giftEffectTimer;
  final KtvService roomMusic = KtvService();
  final RoomForegroundServiceBridge roomForegroundService =
      const RoomForegroundServiceBridge();
  final RoomPermissionBridge roomPermissions = const RoomPermissionBridge();
  bool roomForegroundServiceStarted = false;

  bool get isRoomHost => widget.room.ownerUserId == widget.state.userId;
  bool get isRoomAdmin => isRoomHost || amRoomAdmin;

  @override
  void initState() {
    super.initState();
    roomAvatarKey = widget.room.avatarKey;
    roomName = widget.room.name;
    roomSeatCount = widget.room.seatCount;
    roomPartyMode = widget.room.partyMode;
    roomMode = widget.room.roomMode;
    unawaited(roomMusic.loadLocalSongs());
    unawaited(_loadRoomEffectPreferences());
    unawaited(_connectVoice());
    unawaited(_loadRoomFollow());
    unawaited(_loadRoomMembers());
    unawaited(_loadRoomControls());
    unawaited(_loadRoomGiftRanking());
    memberRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_loadRoomMembers());
      unawaited(_loadRoomMessages());
      unawaited(_loadRoomSettings());
      unawaited(_loadRoomControls());
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
      roomMembers = rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
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
    giftEffectTimer?.cancel();
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

  Future<void> _loadRoomGiftRanking() async {
    if (!widget.state.backendConnected) return;
    final value =
        await widget.state.backend.roomGiftRanking(roomId: widget.room.id);
    if (!mounted || value?['ok'] != true) return;
    final rawRanking = value?['ranking'];
    setState(() {
      roomGiftLifetimeTotal =
          int.tryParse(value?['lifetime_total']?.toString() ?? '') ?? 0;
      roomGiftRanking = rawRanking is List
          ? rawRanking
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
    });
  }

  String _compactRoomCoins(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Map<String, num> _rocketProgressState(int total) {
    var remaining = total < 0 ? 0 : total;
    var completed = 0;
    var currentProgress = 0;
    var currentTarget = _rocketStageTargets.last;
    for (var index = 0; index < _rocketStageTargets.length; index++) {
      final target = _rocketStageTargets[index];
      if (remaining >= target) {
        remaining -= target;
        completed++;
        continue;
      }
      currentProgress = remaining;
      currentTarget = target;
      break;
    }
    if (completed >= _rocketStageTargets.length) {
      currentProgress = _rocketStageTargets.last;
      currentTarget = _rocketStageTargets.last;
    }
    final percent = completed >= _rocketStageTargets.length
        ? 1.0
        : (currentProgress / currentTarget).clamp(0.0, 1.0);
    return <String, num>{
      'completed': completed,
      'current_progress': currentProgress,
      'current_target': currentTarget,
      'percent': percent,
    };
  }

  Future<void> _showRocketPanel() async {
    await _loadRoomGiftRanking();
    if (!mounted) return;
    final progress = _rocketProgressState(roomGiftLifetimeTotal);
    final completed = progress['completed']!.toInt();
    final allComplete = completed >= _rocketStageTargets.length;
    final currentLevel = allComplete ? 10 : completed + 1;
    final currentProgress = progress['current_progress']!.toInt();
    final currentTarget = progress['current_target']!.toInt();
    final percent = progress['percent']!.toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .72,
        child: Container(
          key: const Key('room-rocket-panel'),
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFF07143B),
                Color(0xFF0B2564),
                Color(0xFF08163F),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFC94A),
              width: 1.1,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x665D3BFF), blurRadius: 24),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
                  child: Row(
                    children: [
                      Text(
                        'Rocket $currentLevel/10',
                        style: const TextStyle(
                          color: Color(0xFFFFD45A),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _compactRoomCoins(roomGiftLifetimeTotal),
                        key: const Key('room-rocket-social-total'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
                          itemCount: _rocketStageTargets.length,
                          itemBuilder: (context, index) {
                            final level = index + 1;
                            final done = index < completed;
                            final current = !allComplete && index == completed;
                            return Container(
                              key: Key('room-rocket-stage-$level'),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: current
                                    ? const Color(0xFF173E8F)
                                    : const Color(0xFF071B4D),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: done
                                      ? const Color(0xFFFFD45A)
                                      : current
                                          ? const Color(0xFF61D9FF)
                                          : const Color(0xFF56627E),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rocket $level',
                                    style: TextStyle(
                                      color: done
                                          ? const Color(0xFFFFD45A)
                                          : Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _compactRoomCoins(
                                      _rocketStageTargets[index],
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFFB9C8F3),
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: RoomStealthRocketLogo(size: 132),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      key: const Key('room-rocket-progress'),
                      value: percent,
                      minHeight: 12,
                      backgroundColor: const Color(0xFF241B2C),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD45A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  allComplete
                      ? '10/10 rockets complete'
                      : '${_compactRoomCoins(currentProgress)} / '
                          '${_compactRoomCoins(currentTarget)} • '
                          '${(percent * 100).floor()}%',
                  key: const Key('room-rocket-progress-label'),
                  style: const TextStyle(
                    color: Color(0xFFFFD45A),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: Text(
                    'Rocket follows the same room gift total and 10-stage targets as Tinni.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB9C8F3),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRoomGiftRanking() async {
    await _loadRoomGiftRanking();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .64,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: TinniPalette.gold,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Room Ranking',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      _compactRoomCoins(roomGiftLifetimeTotal),
                      style: const TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: roomGiftRanking.isEmpty
                    ? const Center(child: Text('No gifting ranking yet'))
                    : ListView.builder(
                        itemCount: roomGiftRanking.length,
                        itemBuilder: (context, index) {
                          final row = roomGiftRanking[index];
                          final userId = row['user_id']?.toString() ?? '';
                          final name =
                              row['display_name']?.toString() ?? 'User';
                          final avatar = row['avatar_key']?.toString() ?? '';
                          final sent = int.tryParse(
                                row['sent_coins']?.toString() ?? '',
                              ) ??
                              0;
                          return ListTile(
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  backgroundImage: avatar.isEmpty
                                      ? null
                                      : NetworkImage(
                                          widget.state.backend.fileUrl(avatar),
                                          headers:
                                              widget.state.backend.fileHeaders,
                                        ),
                                  child: avatar.isEmpty
                                      ? const Icon(Icons.person_rounded)
                                      : null,
                                ),
                                Positioned(
                                  right: -5,
                                  top: -5,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: TinniPalette.gold,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(name),
                            subtitle: Text(
                              'Sent ${_compactRoomCoins(sent)} coins',
                            ),
                            trailing:
                                const Icon(Icons.chevron_right_rounded),
                            onTap: userId.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PublicProfileScreen(
                                          state: widget.state,
                                          userId: userId,
                                        ),
                                      ),
                                    );
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

  Future<void> _loadRoomControls() async {
    if (!widget.state.backendConnected) return;
    final value = await widget.state.backend.roomControls(roomId: widget.room.id);
    if (!mounted || value?['ok'] != true) return;
    final rawSeatControls = value?['seat_controls'];
    final nextLocked = <int>{};
    final nextMuted = <int>{};
    if (rawSeatControls is List) {
      for (final raw in rawSeatControls.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final seat = int.tryParse(row['seat_index']?.toString() ?? '');
        if (seat == null) continue;
        if (row['locked'] == true || row['locked']?.toString() == '1') {
          nextLocked.add(seat);
        }
        if (row['room_muted'] == true || row['room_muted']?.toString() == '1') {
          nextMuted.add(seat);
        }
      }
    }
    final rawRequests = value?['seat_requests'];
    final rawInvite = value?['seat_invite'];
    final nextInvite = rawInvite is Map
        ? Map<String, dynamic>.from(rawInvite)
        : null;
    setState(() {
      roomMicMode = value?['mic_mode']?.toString() == 'apply' ? 'apply' : 'free';
      publicScreenEnabled = value?['public_screen_enabled'] != false;
      chatBanned = value?['chat_banned'] == true;
      lockedSeats
        ..clear()
        ..addAll(nextLocked);
      roomMutedSeats
        ..clear()
        ..addAll(nextMuted);
      seatRequests = rawRequests is List
          ? rawRequests
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      pendingSeatInvite = nextInvite;
    });
    if (nextInvite != null && !seatInviteDialogVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_maybeShowSeatInvite());
      });
    }
  }

  Future<void> _maybeShowSeatInvite() async {
    final invite = pendingSeatInvite;
    if (invite == null || seatInviteDialogVisible || !mounted) return;
    final seat =
        int.tryParse(invite['seat_index']?.toString() ?? '') ?? 0;
    final inviter =
        invite['invited_by_name']?.toString().trim();
    seatInviteDialogVisible = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seat Invite'),
        content: Text(
          '${inviter == null || inviter.isEmpty ? 'Owner/Admin' : inviter} invites you to Seat No. ${seat + 1}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Reject'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Accept'),
          ),
        ],
      ),
    );
    if (mounted) {
      final result = await widget.state.backend.setRoomControl(
        roomId: widget.room.id,
        userId: widget.state.userId,
        action: 'seat_invite_respond',
        accepted: accepted == true,
      );
      if (result?['ok'] == true && accepted == true) {
        await _loadRoomMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined Seat ${seat + 1}')),
        );
      }
    }
    seatInviteDialogVisible = false;
    if (mounted) await _loadRoomControls();
  }

  Future<void> _loadRoomSettings() async {
    final value = await widget.state.backend.roomSettings(roomId: widget.room.id);
    final settings = value?['settings'];
    if (!mounted || settings is! Map) return;
    setState(() {
      roomName = settings['name']?.toString() ?? roomName;
      roomSeatCount = int.tryParse(settings['seat_count']?.toString() ?? '') ?? roomSeatCount;
      roomLocked = settings['locked'] == true || settings['locked']?.toString() == '1';
      roomPasswordSet = settings['lock_password_set'] == true ||
          settings['lock_password_set']?.toString() == '1';
      final lockCode = settings['lock_code']?.toString().trim() ?? '';
      roomLockCode = lockCode.isEmpty ? null : lockCode;
      roomThemeId = settings['theme_id']?.toString() ?? roomThemeId;
      final themeAsset = settings['theme_asset_key']?.toString().trim() ?? '';
      roomThemeAssetKey = themeAsset.isEmpty ? null : themeAsset;
      roomSeatThemeId = settings['seat_theme_id']?.toString() ?? roomSeatThemeId;
      roomPartyMode = settings['party_mode']?.toString() ?? roomPartyMode;
      roomMode = settings['room_mode']?.toString() ?? roomMode;
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
    ];
    if (!seatOptions.contains(roomSeatCount)) seatOptions.add(roomSeatCount);
    seatOptions.sort();
    var seatCount = seatOptions.contains(roomSeatCount) ? roomSeatCount : seatOptions.last;
    var locked = roomLocked;
    var themeId = roomThemeId;
    var partyMode = roomPartyMode;
    var selectedRoomMode = roomMode;
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
                  value: selectedRoomMode,
                  decoration: const InputDecoration(
                    labelText: 'Room type',
                    helperText: 'Voice, Game or Live mode',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'voice', child: Text('Voice Room')),
                    DropdownMenuItem(value: 'game', child: Text('Game Room')),
                    DropdownMenuItem(value: 'live', child: Text('Live Room')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRoomMode = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
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
                if (locked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TinniPalette.panel2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: TinniPalette.gold.withValues(alpha: .45),
                      ),
                    ),
                    child: Text(
                      roomLockCode == null
                          ? 'A secure 5-digit room code will be generated after Save.'
                          : 'Current room code: $roomLockCode',
                      style: const TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: announcement,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Room owner greeting', hintText: 'Your welcome message; official terms cannot be edited'),
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
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('Block List'),
                  subtitle: const Text('Users blocked from this room'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    Future<void>.delayed(
                      const Duration(milliseconds: 220),
                      _showRoomBlacklist,
                    );
                  },
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
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'seat_count': seatCount,
                  'locked': locked,
                  'announcement': announcement.text.trim(),
                  'theme_id': themeId,
                  'party_mode': partyMode,
                  'room_mode': selectedRoomMode,
                  'group_pk_enabled': pkEnabled,
                  'welcome_image_key': welcomeImageKey,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    announcement.dispose();
    if (result == null || !mounted) return;
    final saved = await widget.state.backend.saveRoomSettingsResult(
      roomId: widget.room.id,
      userId: widget.state.userId,
      name: result['name'] as String,
      seatCount: result['seat_count'] as int,
      locked: result['locked'] as bool,
      announcement: result['announcement'] as String,
      themeId: result['theme_id'] as String,
      partyMode: result['party_mode'] as String,
      roomMode: result['room_mode'] as String,
      groupPkEnabled: result['group_pk_enabled'] as bool,
      welcomeImageKey: result['welcome_image_key'] as String,
      seatThemeId: roomSeatThemeId,
    );
    final ok = saved?['ok'] == true;
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room settings could not be saved')));
      return;
    }
    final savedRoomMode = result['room_mode'] as String;
    if (savedRoomMode != 'live' && cameraPublished && rtc is LiveKitRtcAdapter) {
      try {
        await (rtc as LiveKitRtcAdapter).setCameraPublished(false);
        if (mounted) {
          setState(() {
            cameraPublished = false;
            localVideoTrack = null;
          });
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      roomName = result['name'] as String;
      roomSeatCount = result['seat_count'] as int;
      roomLocked = result['locked'] as bool;
      roomPasswordSet = roomLocked;
      final savedSettings = saved?['settings'];
      final savedCode = savedSettings is Map
          ? savedSettings['lock_code']?.toString().trim() ?? ''
          : '';
      roomLockCode = roomLocked && savedCode.isNotEmpty ? savedCode : null;
      roomThemeId = result['theme_id'] as String;
      roomPartyMode = result['party_mode'] as String;
      roomMode = savedRoomMode;
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

  Future<String?> _promptRoomPassword({bool invalid = false}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Locked room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          maxLength: 5,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: '5-digit room code',
            counterText: '',
            errorText: invalid ? 'Wrong room code' : null,
          ),
          onSubmitted: (value) {
            if (RegExp(r'^\d{5}$').hasMatch(value.trim())) {
              Navigator.pop(dialogContext, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (RegExp(r'^\d{5}$').hasMatch(value)) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Enter room'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _ensureRoomVoicePermission({
    bool request = true,
  }) async {
    var granted = await roomPermissions.hasVoiceRoomPermissions();
    if (!granted && request) {
      granted = await roomPermissions.requestVoiceRoomPermissions();
    }
    if (granted && !roomForegroundServiceStarted) {
      final started = await roomForegroundService.start();
      if (mounted) {
        setState(() => roomForegroundServiceStarted = started);
      } else {
        roomForegroundServiceStarted = started;
      }
    }
    return granted;
  }

  Future<void> _connectVoice() async {
    if (!await _ensureLegalAgreement()) return;
    if (widget.state.backendConnected) {
      Map<String, dynamic>? joined =
          await widget.state.backend.joinRoomResult(
        roomId: widget.room.id,
        userId: widget.state.userId,
        displayName: widget.state.displayName,
      );
      var invalidPassword = false;
      while (mounted &&
          joined?['ok'] != true &&
          (joined?['error'] == 'room_password_required' ||
              joined?['error'] == 'room_password_invalid')) {
        final password =
            await _promptRoomPassword(invalid: invalidPassword);
        if (password == null || !mounted) {
          Navigator.of(context).pop();
          return;
        }
        joined = await widget.state.backend.joinRoomResult(
          roomId: widget.room.id,
          userId: widget.state.userId,
          displayName: widget.state.displayName,
          password: password,
        );
        invalidPassword = joined?['error'] == 'room_password_invalid';
      }
      if (joined?['ok'] != true) {
        if (mounted) {
          final error = joined?['error']?.toString() ?? '';
          final message = error == 'room_blocked'
              ? 'You are blocked from this room'
              : error == 'room_country_mismatch'
                  ? 'Only rooms from your selected country are available'
                  : error == 'room_locked'
                      ? 'This locked room has no usable password yet'
                      : 'This room is unavailable';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      await _loadRoomSettings();
      await widget.state.refreshIdLevel(notify: false);
    }

    final voicePermissionGranted =
        await _ensureRoomVoicePermission(request: true);
    if (!voicePermissionGranted && mounted) {
      setState(() {
        voiceStatus = 'Listen-only • allow microphone for voice';
      });
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
        voiceStatus = !voicePermissionGranted
            ? 'Listening • microphone permission needed'
            : candidate is LiveKitRtcAdapter
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
    unawaited(roomForegroundService.stop());
    roomForegroundServiceStarted = false;
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
    final occupied = membersBySeat[seat];
    final occupiedUserId = occupied?['user_id']?.toString() ?? '';
    if (occupied != null &&
        occupiedUserId.isNotEmpty &&
        occupiedUserId != widget.state.userId) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            state: widget.state,
            userId: occupiedUserId,
          ),
        ),
      );
      return;
    }

    final leaving = mySeat == seat;
    if (!leaving && lockedSeats.contains(seat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat ${seat + 1} is locked')),
      );
      return;
    }

    if (!leaving &&
        roomMicMode == 'apply' &&
        !isRoomAdmin &&
        widget.state.backendConnected) {
      final result = await widget.state.backend.requestRoomSeat(
        roomId: widget.room.id,
        userId: widget.state.userId,
        seatIndex: seat,
      );
      if (!mounted) return;
      final ok = result?['ok'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Mic request sent for Seat ${seat + 1}'
                : 'Mic request could not be sent',
          ),
        ),
      );
      return;
    }

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
    unawaited(_loadRoomControls());
  }

  Future<void> _toggleMic() async {
    if (mySeat == null) return;
    if (roomMutedSeats.contains(mySeat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This mic is muted by room owner/admin')),
      );
      return;
    }
    final enable = muted;
    if (enable) {
      final permission = await _ensureRoomVoicePermission(request: true);
      if (!permission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow microphone access to speak on a seat'),
          ),
        );
        return;
      }
    }
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

  Future<void> _inviteMemberToMic(
    String targetUserId,
    String targetName,
  ) async {
    if (!isRoomAdmin) return;
    await _loadRoomControls();
    if (!mounted) return;
    final availableSeats = <int>[
      for (var seat = 0; seat < roomSeatCount; seat++)
        if (!membersBySeat.containsKey(seat) && !lockedSeats.contains(seat))
          seat,
    ];
    if (availableSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unlocked empty mic is available')),
      );
      return;
    }
    final seat = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Invite ${targetName} to mic',
                style: const TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final value in availableSeats)
              ListTile(
                leading: const Icon(
                  Icons.mic_external_on_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text('Seat ${value + 1}'),
                onTap: () => Navigator.pop(sheetContext, value),
              ),
          ],
        ),
      ),
    );
    if (seat == null || !mounted) return;
    final result = await widget.state.backend.setRoomControl(
      roomId: widget.room.id,
      userId: widget.state.userId,
      action: 'seat_invite',
      targetUserId: targetUserId,
      seatIndex: seat,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?['ok'] == true
              ? 'Mic invite sent to ${targetName}'
              : 'Mic invite could not be sent',
        ),
      ),
    );
  }

  Future<void> _inviteOffSeatMemberToSeat(int seat) async {
    if (!isRoomAdmin || !widget.state.backendConnected) return;
    await _loadRoomMembers();
    await _loadRoomControls();
    if (!mounted) return;
    if (seat < 0 ||
        seat >= roomSeatCount ||
        membersBySeat.containsKey(seat) ||
        lockedSeats.contains(seat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat ${seat + 1} is not available')),
      );
      return;
    }

    final eligible = roomMembers
        .where((member) {
          final userId = member['user_id']?.toString() ?? '';
          final memberSeat =
              int.tryParse(member['seat_index']?.toString() ?? '');
          return userId.isNotEmpty &&
              userId != widget.state.userId &&
              memberSeat == null;
        })
        .map((member) => Map<String, dynamic>.from(member))
        .toList(growable: false);

    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No off-seat users are available to invite')),
      );
      return;
    }

    final searchController = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: TinniPalette.nearBlack,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, refresh) {
            final query = searchController.text.trim();
            final visible = query.isEmpty
                ? eligible
                : eligible
                    .where(
                      (member) =>
                          (member['user_id']?.toString() ?? '').contains(query),
                    )
                    .toList(growable: false);

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .62,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Invite to Seat No. ${seat + 1}',
                              style: const TextStyle(
                                color: TinniPalette.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text('${eligible.length} available'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: TextField(
                        controller: searchController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search ID in this room',
                        ),
                        onChanged: (_) => refresh(() {}),
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text('No matching off-seat user in this room'),
                            )
                          : ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final member = visible[index];
                                final userId =
                                    member['user_id']?.toString() ?? '';
                                final rawName =
                                    member['display_name']?.toString().trim();
                                final name =
                                    rawName == null || rawName.isEmpty
                                        ? 'User $userId'
                                        : rawName;
                                final avatar =
                                    member['avatar_key']?.toString();
                                final isAdmin =
                                    member['is_admin'] == true ||
                                        member['is_admin']?.toString() == '1';
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: TinniPalette.panel2,
                                    backgroundImage:
                                        avatar != null && avatar.isNotEmpty
                                            ? NetworkImage(
                                                widget.state.backend
                                                    .fileUrl(avatar),
                                                headers: widget
                                                    .state.backend.fileHeaders,
                                              )
                                            : null,
                                    child: avatar == null || avatar.isEmpty
                                        ? const Icon(Icons.person_rounded)
                                        : null,
                                  ),
                                  title: Text(
                                    '$name${isAdmin ? ' • Admin' : ''}',
                                  ),
                                  subtitle: Text('ID $userId • Audience'),
                                  trailing: TextButton(
                                    key: Key(
                                      'room-seat-$seat-invite-user-$userId',
                                    ),
                                    onPressed: () async {
                                      final result = await widget.state.backend
                                          .setRoomControl(
                                        roomId: widget.room.id,
                                        userId: widget.state.userId,
                                        action: 'seat_invite',
                                        targetUserId: userId,
                                        seatIndex: seat,
                                      );
                                      if (!sheetContext.mounted) return;
                                      if (result?['ok'] == true) {
                                        Navigator.pop(sheetContext);
                                        if (mounted) {
                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Invite sent to $name for Seat No. ${seat + 1}',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        ScaffoldMessenger.of(sheetContext)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Seat invite could not be sent',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Invite'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _showRoomBlacklist() async {
    if (!isRoomAdmin) return;
    var rows =
        await widget.state.backend.roomBlacklist(roomId: widget.room.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .62,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Room Blacklist',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text('${rows.length} blocked'),
                    ],
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(
                          child: Text('No users are blocked from this room'),
                        )
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final userId =
                                row['user_id']?.toString() ?? '';
                            final name =
                                row['display_name']?.toString() ?? 'User';
                            final avatar =
                                row['avatar_key']?.toString() ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar.isEmpty
                                    ? null
                                    : NetworkImage(
                                        widget.state.backend.fileUrl(avatar),
                                        headers:
                                            widget.state.backend.fileHeaders,
                                      ),
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person_off_rounded)
                                    : null,
                              ),
                              title: Text(name),
                              subtitle: Text('ID ${userId}'),
                              trailing: TextButton(
                                onPressed: () async {
                                  final ok = await widget.state.backend
                                      .unblockRoomMember(
                                    roomId: widget.room.id,
                                    targetUserId: userId,
                                  );
                                  if (!ok) return;
                                  rows = await widget.state.backend
                                      .roomBlacklist(roomId: widget.room.id);
                                  if (sheetContext.mounted) refresh(() {});
                                },
                                child: const Text('Unblock'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                            subtitle: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ID $userId • ' +
                                        (seat == null
                                            ? 'Audience'
                                            : 'Seat ${seat + 1} • ${member['mic_muted'] == 1 || member['mic_muted']?.toString() == '1' ? 'Mic off' : 'Mic on'}') +
                                        ((member['chat_banned'] == true || member['chat_banned']?.toString() == '1')
                                            ? ' • Chat banned'
                                            : ''),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isSelf && seat == null && isRoomAdmin)
                                  TextButton(
                                    key: Key('room-member-invite-$userId'),
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      Future<void>.delayed(Duration.zero, () {
                                        if (!mounted) return;
                                        _inviteMemberToMic(
                                          userId,
                                          name?.isNotEmpty == true ? name! : 'User',
                                        );
                                      });
                                    },
                                    child: const Text('Invite'),
                                  ),
                              ],
                            ),
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
                                      } else if (action == 'chat_ban') {
                                        await _setChatBan(userId, true);
                                      } else if (action == 'chat_unban') {
                                        await _setChatBan(userId, false);
                                      } else if (action == 'invite_mic') {
                                        await _inviteMemberToMic(
                                          userId,
                                          name?.isNotEmpty == true ? name! : 'User',
                                        );
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
                                      if (seat == null)
                                        const PopupMenuItem(
                                          value: 'invite_mic',
                                          child: Text('Invite to mic'),
                                        ),
                                      PopupMenuItem(
                                        value: (member['chat_banned'] == true || member['chat_banned']?.toString() == '1')
                                            ? 'chat_unban'
                                            : 'chat_ban',
                                        child: Text(
                                          (member['chat_banned'] == true || member['chat_banned']?.toString() == '1')
                                              ? 'Chat Unban'
                                              : 'Chat Ban',
                                        ),
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

  Future<void> _disconnectRoomRuntime() async {
    try {
      await roomMusic.stopRoomPlayback();
    } catch (_) {}

    final current = rtc;
    rtc = null;

    try {
      await current?.setMicPublished(false);
    } catch (_) {}
    try {
      if (cameraPublished && current is LiveKitRtcAdapter) {
        await current.setCameraPublished(false);
      }
    } catch (_) {}

    rtcEvents?.dispose();
    rtcEvents = null;

    try {
      await current?.leave();
    } catch (_) {}
    if (current is LiveKitRtcAdapter) {
      current.dispose();
    } else if (current is LocalRtcAdapter) {
      current.dispose();
    }

    cameraPublished = false;
    localVideoTrack = null;
    remoteVideoTracks.clear();
    mySeat = null;
    muted = true;

    try {
      await roomForegroundService.stop();
    } catch (_) {}
    roomForegroundServiceStarted = false;
  }

  Future<void> _leaveServerMembership() async {
    if (!widget.state.backendConnected) return;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final ok = await widget.state.backend.leaveRoom(
          roomId: widget.room.id,
          userId: widget.state.userId,
        );
        if (ok) return;
      } catch (_) {}
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    }
  }

  Future<void> _cleanupMinimizedRoom() async {
    await _leaveServerMembership();
    await _disconnectRoomRuntime();
  }

  Future<void> _minimizeRoom() async {
    if (!mounted) return;
    final displayRoom = RoomSummary(
      id: widget.room.id,
      name: roomName,
      ownerName: widget.room.ownerName,
      ownerUserId: widget.room.ownerUserId,
      online: roomMembers.length,
      seatCount: roomSeatCount,
      avatarKey: roomAvatarKey,
      partyMode: roomPartyMode,
      roomMode: roomMode,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(
          state: widget.state,
          minimizedRoom: displayRoom,
          onResumeRoom: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          onCloseMinimizedRoom: _cleanupMinimizedRoom,
        ),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    // Exit always tears down the local room first-class resources. The server
    // membership request is retried, but a transient network error must never
    // leave mic/RTC/foreground-service work running after the user exits.
    await _leaveServerMembership();
    await _disconnectRoomRuntime();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openGames() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: GamesScreen(
          state: widget.state,
          roomId: widget.room.id,
          roomOwnerUserId: widget.room.ownerUserId,
          onFruitParty: () => Navigator.pop(context, 'fruit-party'),
          onGreedyGirl: () => Navigator.pop(context, 'greedy-girl'),
          onToggleMic: _toggleMic,
          micOn: () => mySeat != null && !muted,
          hasMicSeat: () => mySeat != null,
        ),
      ),
    );
    if (!mounted) return;
    if (selection == 'fruit-party') {
      await showFruitParty(context, widget.state);
    } else if (selection == 'greedy-girl') {
      await showGreedyGirl(context, widget.state);
    }
  }

  Future<void> _shareRoomId() async {
    await Clipboard.setData(ClipboardData(text: widget.room.roomNumber));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect to the room server to use Red Pocket (LP)')));
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
                const Text('Red Pocket (LP)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (pouch == null) ...[
                  const Text('No active Red Pocket. Members can create one using their coins.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final values = await showDialog<(int, int)>(
                        context: context,
                        builder: (dialogContext) {
                          const allowed = <int, List<int>>{
                            5: <int>[100000, 500000, 1000000, 2000000, 5000000, 8000000, 10000000],
                            20: <int>[100000, 500000, 1000000, 2000000, 5000000, 8000000, 10000000],
                            50: <int>[500000, 1000000, 2000000, 5000000, 8000000, 10000000],
                            100: <int>[1000000, 2000000, 5000000, 8000000, 10000000],
                            200: <int>[1000000, 2000000, 5000000, 8000000, 10000000],
                            500: <int>[2000000, 5000000, 8000000, 10000000],
                          };
                          var slots = 5;
                          var coins = 100000;
                          return StatefulBuilder(
                            builder: (dialogContext, setDialogState) {
                              final coinOptions = allowed[slots]!;
                              return AlertDialog(
                                title: const Text('Create Red Pocket (LP)'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButtonFormField<int>(
                                      value: slots,
                                      decoration: const InputDecoration(
                                        labelText: 'People',
                                      ),
                                      items: allowed.keys
                                          .map(
                                            (n) => DropdownMenuItem(
                                              value: n,
                                              child: Text('$n people'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setDialogState(() {
                                          slots = value;
                                          final next = allowed[slots]!;
                                          if (!next.contains(coins)) {
                                            coins = next.first;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<int>(
                                      value: coins,
                                      decoration: const InputDecoration(
                                        labelText: 'Coin amount',
                                      ),
                                      items: coinOptions
                                          .map(
                                            (n) => DropdownMenuItem(
                                              value: n,
                                              child: Text(
                                                '${_compactRoomCoins(n)} coins',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() => coins = value);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(
                                      dialogContext,
                                      (coins, slots),
                                    ),
                                    child: const Text('Create'),
                                  ),
                                ],
                              );
                            },
                          );
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
                      if (amount != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Red Pocket (LP): +$amount coins')));
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
    if (!widget.state.backendConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to the room server to draw a Lucky Number.'),
        ),
      );
      return;
    }
    final result = await widget.state.backend.drawRoomLuckyNumber(
      roomId: widget.room.id,
    );
    if (!mounted) return;
    final rawEvent = result?['event'];
    if (result?['ok'] != true || rawEvent is! Map) {
      final reason = result?['error']?.toString().replaceAll('_', ' ') ??
          'Lucky Number could not be drawn.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
      return;
    }
    final event = Map<String, dynamic>.from(rawEvent);
    final number = int.tryParse(event['number']?.toString() ?? '') ?? 0;
    final displayName = event['display_name']?.toString().trim();
    final rawEvents = result?['events'];
    final recent = rawEvents is List
        ? rawEvents
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .take(10)
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lucky Number'),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '${displayName == null || displayName.isEmpty ? 'You' : displayName} drew $number.',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'This result is generated and stored by the room server.',
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Recent room draws',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final row in recent)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.confirmation_number_rounded),
                    title: Text(
                      row['display_name']?.toString().trim().isNotEmpty == true
                          ? row['display_name'].toString()
                          : 'User',
                    ),
                    trailing: Text(
                      row['number']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
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

  Future<void> _setMicMode(String mode) async {
    if (!isRoomHost) return;
    final result = await widget.state.backend.setRoomControl(
      roomId: widget.room.id,
      userId: widget.state.userId,
      action: 'mic_mode',
      micMode: mode,
    );
    if (!mounted) return;
    if (result?['ok'] == true) {
      setState(() => roomMicMode = mode == 'apply' ? 'apply' : 'free');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            roomMicMode == 'free'
                ? 'Free mic enabled'
                : 'Request mic enabled',
          ),
        ),
      );
      await _loadRoomControls();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mic mode could not be changed')),
      );
    }
  }

  Future<void> _showMicModeControl() async {
    if (!isRoomHost) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Mic Type',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text('Choose how users can take an empty mic.'),
            ),
            RadioListTile<String>(
              value: 'free',
              groupValue: roomMicMode,
              title: const Text('Free mic'),
              subtitle: const Text('Users can take any unlocked empty mic directly.'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
            RadioListTile<String>(
              value: 'apply',
              groupValue: roomMicMode,
              title: const Text('Request mic'),
              subtitle: const Text('Users send a request; owner/admin approves it.'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
          ],
        ),
      ),
    );
    if (selected != null) await _setMicMode(selected);
  }

  Future<void> _showMicRequests() async {
    if (!isRoomAdmin) return;
    await _loadRoomControls();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .58,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Mic Requests',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text('${seatRequests.length} pending'),
                    ],
                  ),
                ),
                Expanded(
                  child: seatRequests.isEmpty
                      ? const Center(child: Text('No pending mic requests'))
                      : ListView.builder(
                          itemCount: seatRequests.length,
                          itemBuilder: (context, index) {
                            final request = seatRequests[index];
                            final userId =
                                request['user_id']?.toString() ?? '';
                            final displayName =
                                request['display_name']?.toString().trim();
                            final seat = int.tryParse(
                                  request['seat_index']?.toString() ?? '',
                                ) ??
                                0;
                            final avatar =
                                request['avatar_key']?.toString() ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatar.isEmpty
                                    ? null
                                    : NetworkImage(
                                        widget.state.backend.fileUrl(avatar),
                                        headers:
                                            widget.state.backend.fileHeaders,
                                      ),
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person_rounded)
                                    : null,
                              ),
                              title: Text(
                                displayName == null || displayName.isEmpty
                                    ? 'User ${userId}'
                                    : displayName,
                              ),
                              subtitle: Text('Requests Seat ${seat + 1}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Reject',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      await widget.state.backend
                                          .resolveRoomSeatRequest(
                                        roomId: widget.room.id,
                                        userId: widget.state.userId,
                                        targetUserId: userId,
                                        approved: false,
                                      );
                                      await _loadRoomControls();
                                      if (sheetContext.mounted) refresh(() {});
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Approve',
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.greenAccent,
                                    ),
                                    onPressed: () async {
                                      final result = await widget.state.backend
                                          .resolveRoomSeatRequest(
                                        roomId: widget.room.id,
                                        userId: widget.state.userId,
                                        targetUserId: userId,
                                        approved: true,
                                      );
                                      if (result?['ok'] == true) {
                                        await _loadRoomMembers();
                                      }
                                      await _loadRoomControls();
                                      if (sheetContext.mounted) refresh(() {});
                                    },
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
      ),
    );
  }

  Future<void> _showSeatControls(int seat) async {
    if (!isRoomAdmin) return;
    final member = membersBySeat[seat];
    final locked = lockedSeats.contains(seat);
    final roomMuted = roomMutedSeats.contains(seat);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const TinniGlowIcon(icon: Icons.event_seat_rounded),
              title: Text('Seat ${seat + 1}'),
              subtitle: Text(
                member == null
                    ? (locked ? 'Empty • Locked' : 'Empty')
                    : (member['display_name']?.toString() ?? 'Occupied'),
              ),
            ),
            if (member == null && !locked)
              ListTile(
                key: Key('room-seat-invite-$seat'),
                leading: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Invite'),
                subtitle: Text(
                  'Invite an in-room off-seat user/admin to Seat No. ${seat + 1}.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future<void>.delayed(
                    const Duration(milliseconds: 180),
                    () {
                      if (mounted) {
                        unawaited(_inviteOffSeatMemberToSeat(seat));
                      }
                    },
                  );
                },
              ),
            ListTile(
              leading: Icon(
                locked ? Icons.lock_open_rounded : Icons.lock_rounded,
              ),
              title: Text(locked ? 'Seat Unlock' : 'Seat Lock'),
              onTap: () async {
                final result = await widget.state.backend.setRoomControl(
                  roomId: widget.room.id,
                  userId: widget.state.userId,
                  action: 'seat_lock',
                  seatIndex: seat,
                  locked: !locked,
                );
                if (result?['ok'] == true) await _loadRoomControls();
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            if (member != null)
              ListTile(
                leading: Icon(
                  roomMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                ),
                title: Text(roomMuted ? 'Seat Unmute' : 'Seat Mute'),
                onTap: () async {
                  final result = await widget.state.backend.setRoomControl(
                    roomId: widget.room.id,
                    userId: widget.state.userId,
                    action: 'seat_mute',
                    seatIndex: seat,
                    muted: !roomMuted,
                  );
                  if (result?['ok'] == true) {
                    await _loadRoomMembers();
                    await _loadRoomControls();
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            if (member != null &&
                member['user_id']?.toString() != widget.room.ownerUserId)
              ListTile(
                leading: const Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  color: Colors.orangeAccent,
                ),
                title: const Text('Seat Down'),
                subtitle: const Text('Move this user to audience and mute mic.'),
                onTap: () async {
                  final result = await widget.state.backend.setRoomControl(
                    roomId: widget.room.id,
                    userId: widget.state.userId,
                    action: 'seat_down',
                    seatIndex: seat,
                  );
                  if (result?['ok'] == true) {
                    await _loadRoomMembers();
                    await _loadRoomControls();
                  }
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setChatBan(String targetUserId, bool banned) async {
    final result = await widget.state.backend.setRoomControl(
      roomId: widget.room.id,
      userId: widget.state.userId,
      action: 'chat_ban',
      targetUserId: targetUserId,
      banned: banned,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result?['ok'] == true
              ? (banned ? 'User chat banned' : 'User chat unbanned')
              : 'Chat permission could not be changed',
        ),
      ),
    );
    if (result?['ok'] == true) await _loadRoomMembers();
  }

  Future<void> _showPublicScreen() async {
    if (!isRoomAdmin) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Public Screen'),
          content: Text(
            publicScreenEnabled
                ? 'Everyone can type in room chat.'
                : 'Only room owner/admin can type in room chat.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    var enabled = publicScreenEnabled;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('Public Screen'),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Everyone can type'),
            subtitle: Text(
              enabled
                  ? 'Room members can use public chat.'
                  : 'Only room owner/admin can type.',
            ),
            value: enabled,
            onChanged: (value) async {
              final result = await widget.state.backend.setRoomControl(
                roomId: widget.room.id,
                userId: widget.state.userId,
                action: 'public_screen',
                enabled: value,
              );
              if (result?['ok'] == true) {
                enabled = value;
                if (mounted) {
                  setState(() => publicScreenEnabled = value);
                }
                refresh(() {});
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showRoomRules();
              },
              child: const Text('Terms & rules'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    await _loadRoomControls();
  }

  Future<void> _loadRoomEffectPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      effectsEnabled = prefs.getBool('dvx.room.effects.all') ?? true;
      roomNoticesEnabled = prefs.getBool('dvx.room.effects.notices') ?? true;
      giftEffectsEnabled = prefs.getBool('dvx.room.effects.gift') ?? true;
      giftSoundEnabled = prefs.getBool('dvx.room.effects.gift_sound') ?? true;
      giftFlyInEnabled = prefs.getBool('dvx.room.effects.gift_fly_in') ?? true;
      carEffectsEnabled = prefs.getBool('dvx.room.effects.car') ?? true;
      giftBubbleEnabled = prefs.getBool('dvx.room.effects.gift_bubble') ?? true;
      rocketDrawNoticeEnabled =
          prefs.getBool('dvx.room.effects.rocket_notice') ?? true;
    });
  }

  Future<void> _setRoomEffectPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _showRoomEffects() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
              children: [
                const ListTile(
                  leading: TinniGlowIcon(
                    icon: Icons.auto_awesome_rounded,
                    size: 22,
                    boxSize: 42,
                  ),
                  title: Text(
                    'Effects',
                    style: TextStyle(
                      color: TinniPalette.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'Choose exactly which room effects you want to see or hear.',
                  ),
                ),
                SwitchListTile(
                  title: const Text('All Visual Effects'),
                  subtitle: const Text('Master switch for room visual effects.'),
                  value: effectsEnabled,
                  onChanged: (value) {
                    setState(() => effectsEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference('dvx.room.effects.all', value),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Room Notices'),
                  subtitle: const Text('Show or hide general room notices.'),
                  value: roomNoticesEnabled,
                  onChanged: (value) {
                    setState(() => roomNoticesEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.notices',
                        value,
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Gift Effects'),
                  subtitle: const Text('Gift animation and visual effects.'),
                  value: giftEffectsEnabled,
                  onChanged: (value) {
                    setState(() => giftEffectsEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference('dvx.room.effects.gift', value),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Gift Sound'),
                  subtitle: const Text('Sound played with supported gift effects.'),
                  value: giftSoundEnabled,
                  onChanged: (value) {
                    setState(() => giftSoundEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.gift_sound',
                        value,
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Gift Fly-in'),
                  subtitle: const Text('Gift entry/fly-in animation in the room.'),
                  value: giftFlyInEnabled,
                  onChanged: (value) {
                    setState(() => giftFlyInEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.gift_fly_in',
                        value,
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Car Effects'),
                  subtitle: const Text('Vehicle/car room-entry animations.'),
                  value: carEffectsEnabled,
                  onChanged: (value) {
                    setState(() => carEffectsEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference('dvx.room.effects.car', value),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Gift Bubble'),
                  subtitle: const Text('Gift bubble/pop-up notices in the room.'),
                  value: giftBubbleEnabled,
                  onChanged: (value) {
                    setState(() => giftBubbleEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.gift_bubble',
                        value,
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Rocket Draw Notice'),
                  subtitle: const Text('Show the room Rocket shortcut and notice.'),
                  value: rocketDrawNoticeEnabled,
                  onChanged: (value) {
                    setState(() => rocketDrawNoticeEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.rocket_notice',
                        value,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _playGiftEffect(Map<String, dynamic> gift) {
    if (!effectsEnabled || !giftEffectsEnabled) return;
    giftEffectTimer?.cancel();
    if (giftSoundEnabled) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    if (giftFlyInEnabled || giftBubbleEnabled) {
      setState(() => activeGiftEffect = Map<String, dynamic>.from(gift));
      giftEffectTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => activeGiftEffect = null);
      });
    }
  }

  Color get _seatThemeAccent => switch (roomSeatThemeId) {
        'neon-blue' => const Color(0xFF58B8FF),
        'rose-glow' => const Color(0xFFFF6EA9),
        _ => TinniPalette.brightGold,
      };

  Future<bool> _saveRoomConfiguration({
    int? seatCount,
    String? themeId,
    String? seatThemeId,
    bool? groupPk,
    bool? locked,
    String? partyMode,
    String? nextRoomMode,
  }) async {
    final result = await widget.state.backend.saveRoomSettingsResult(
      roomId: widget.room.id,
      userId: widget.state.userId,
      name: roomName,
      seatCount: seatCount ?? roomSeatCount,
      locked: locked ?? roomLocked,
      announcement: roomAnnouncement ?? '',
      themeId: themeId ?? roomThemeId,
      partyMode: partyMode ?? roomPartyMode,
      roomMode: nextRoomMode ?? roomMode,
      groupPkEnabled: groupPk ?? groupPkEnabled,
      welcomeImageKey: roomWelcomeImageKey ?? '',
      seatThemeId: seatThemeId ?? roomSeatThemeId,
    );
    final ok = result?['ok'] == true;
    if (!mounted) return ok;
    if (ok) {
      final settings = result?['settings'];
      final generatedCode =
          settings is Map ? settings['lock_code']?.toString().trim() ?? '' : '';
      if (nextRoomMode != null &&
          nextRoomMode != 'live' &&
          cameraPublished &&
          rtc is LiveKitRtcAdapter) {
        try {
          await (rtc as LiveKitRtcAdapter).setCameraPublished(false);
          if (mounted) {
            cameraPublished = false;
            localVideoTrack = null;
          }
        } catch (_) {}
      }
      if (!mounted) return ok;
      setState(() {
        if (seatCount != null) roomSeatCount = seatCount;
        if (themeId != null) roomThemeId = themeId;
        if (seatThemeId != null) roomSeatThemeId = seatThemeId;
        if (groupPk != null) groupPkEnabled = groupPk;
        if (locked != null) {
          roomLocked = locked;
          roomPasswordSet = locked;
          if (!locked) {
            roomLockCode = null;
          } else if (generatedCode.isNotEmpty) {
            roomLockCode = generatedCode;
          }
        }
        if (partyMode != null) roomPartyMode = partyMode;
        if (nextRoomMode != null) roomMode = nextRoomMode;
      });
      await widget.state.refreshRooms();
      if (themeId != null && mounted) {
        await _loadRoomSettings();
      }
    }
    return ok;
  }

  Future<void> _showSeatCountSelector() async {
    if (!isRoomAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only room owner/admin can change seats')),
      );
      return;
    }
    final options = isRoomHost
        ? <int>[for (var count = 8; count <= 42; count++) count]
        : <int>[
            for (var count = roomSeatCount + 1; count <= 42; count++) count,
          ];
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('42 seats is already the maximum')),
      );
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          children: [
            ListTile(
              title: Text(
                isRoomHost ? 'Room Seats' : 'Increase Room Seats',
                style: const TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                isRoomHost
                    ? 'Owner can increase or decrease seats from 8 to 42.'
                    : 'Admin can only increase the current seat count.',
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final count in options)
                  ChoiceChip(
                    label: Text(count.toString()),
                    selected: count == roomSeatCount,
                    onSelected: count == roomSeatCount
                        ? null
                        : (_) => Navigator.pop(sheetContext, count),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (selected == null || selected == roomSeatCount) return;
    final ok = await _saveRoomConfiguration(seatCount: selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Room seats changed to $selected.'
              : 'Room seats could not be changed.',
        ),
      ),
    );
  }

  Future<void> _createCustomRoomTheme() async {
    if (!isRoomHost || !widget.state.backendConnected) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1440,
      maxHeight: 1920,
    );
    if (image == null) return;
    final ext = image.name.split('.').last.toLowerCase();
    final normalizedExt = ext == 'jpeg' ? 'jpg' : ext;
    final contentType = switch (normalizedExt) {
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    if (contentType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPG, PNG or WebP image')),
        );
      }
      return;
    }

    final details = await showDialog<(String, bool)>(
      context: context,
      builder: (dialogContext) {
        final name = TextEditingController(text: 'My Room Theme');
        var confirmed = false;
        return StatefulBuilder(
          builder: (dialogContext, refresh) => AlertDialog(
            title: const Text('Add New Room Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Theme name'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: (value) =>
                      refresh(() => confirmed = value == true),
                  title: const Text(
                    'I confirm this room cover is safe and allowed.',
                  ),
                ),
                const Text(
                  'User theme price: 10M coins • valid for 7 days.',
                  style: TextStyle(
                    color: TinniPalette.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: confirmed && name.text.trim().isNotEmpty
                    ? () => Navigator.pop(
                          dialogContext,
                          (name.text.trim(), confirmed),
                        )
                    : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
    if (details == null) return;

    final key = await widget.state.backend.uploadImage(
      key:
          'room-themes/${widget.state.userId}/theme-${DateTime.now().microsecondsSinceEpoch}.$normalizedExt',
      bytes: await image.readAsBytes(),
      contentType: contentType,
    );
    if (key == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room theme image upload failed')),
        );
      }
      return;
    }

    final result = await widget.state.backend.createRoomTheme(
      roomId: widget.room.id,
      name: details.$1,
      assetKey: key,
      policyConfirmed: details.$2,
      durationDays: 7,
    );
    if (!mounted) return;
    if (result?['ok'] != true) {
      final error = result?['error']?.toString().replaceAll('_', ' ') ??
          'Room theme could not be created';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    final balance = int.tryParse(result?['coin_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    final rawTheme = result?['theme'];
    final themeId =
        rawTheme is Map ? rawTheme['id']?.toString().trim() ?? '' : '';
    if (themeId.isEmpty) return;
    final ok = await _saveRoomConfiguration(themeId: themeId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Room theme activated for 7 days.'
              : 'Theme created, but could not be activated.',
        ),
      ),
    );
  }

  Future<void> _showRoomThemeSelector() async {
    if (!isRoomHost) return;
    final response =
        await widget.state.backend.roomThemes(roomId: widget.room.id);
    final rawThemes = response?['themes'];
    final customThemes = rawThemes is List
        ? rawThemes
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: ListView(
            children: [
              const ListTile(
                leading: Icon(Icons.image_rounded),
                title: Text(
                  'Room Cover / Theme',
                  style: TextStyle(
                    color: TinniPalette.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text('Built-in and purchased room-wide covers'),
              ),
              ListTile(
                key: const Key('room-theme-add-custom'),
                leading: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Add New Room Theme'),
                subtitle: const Text('10M coins • 7 days'),
                onTap: () => Navigator.pop(sheetContext, '__add__'),
              ),
              const Divider(),
              for (final entry in const <(String, String)>[
                ('dark', 'Dark'),
                ('midnight', 'Midnight'),
                ('rose', 'Rose'),
                ('forest', 'Forest'),
                ('gold', 'Gold'),
              ])
                RadioListTile<String>(
                  value: entry.$1,
                  groupValue: roomThemeId,
                  title: Text(entry.$2),
                  onChanged: (value) => Navigator.pop(sheetContext, value),
                ),
              if (customThemes.isNotEmpty) const Divider(),
              for (final theme in customThemes)
                RadioListTile<String>(
                  value: theme['id']?.toString() ?? '',
                  groupValue: roomThemeId,
                  secondary: const Icon(Icons.wallpaper_rounded),
                  title: Text(theme['name']?.toString() ?? 'Room Theme'),
                  subtitle: Text(
                    theme['expires_at'] == null
                        ? 'Permanent'
                        : 'Purchased room cover',
                  ),
                  onChanged: (value) => Navigator.pop(sheetContext, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__add__') {
      await _createCustomRoomTheme();
      return;
    }
    if (selected == roomThemeId) return;
    final ok = await _saveRoomConfiguration(themeId: selected);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room theme could not be changed')),
    );
  }

  Future<void> _showRoomModeSelector() async {
    if (!isRoomHost) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.meeting_room_rounded),
              title: Text(
                'Room Mode',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text('Choose how this room is used'),
            ),
            for (final entry in const <(String, String, IconData)>[
              ('voice', 'Voice Room', Icons.mic_rounded),
              ('game', 'Game Room', Icons.sports_esports_rounded),
              ('live', 'Live Room', Icons.videocam_rounded),
            ])
              ListTile(
                leading: Icon(entry.$3),
                title: Text(entry.$2),
                trailing: roomMode == entry.$1
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: TinniPalette.gold,
                      )
                    : null,
                onTap: () => Navigator.pop(sheetContext, entry.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == roomMode) return;
    final ok = await _saveRoomConfiguration(nextRoomMode: selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Room changed to ${switch (selected) { 'game' => 'Game Room', 'live' => 'Live Room', _ => 'Voice Room' }}.'
              : 'Room mode could not be changed.',
        ),
      ),
    );
  }

  Future<void> _toggleGroupPk() async {
    if (!isRoomHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only room owner can control Group PK')),
      );
      return;
    }
    final next = !groupPkEnabled;
    final ok = await _saveRoomConfiguration(groupPk: next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (next ? 'Group PK enabled.' : 'Group PK disabled.')
              : 'Group PK could not be changed.',
        ),
      ),
    );
  }

  Future<void> _showRoomTypePanel() async {
    if (!isRoomAdmin) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => DefaultTabController(
        length: 4,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .66,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.dashboard_customize_rounded),
                  title: Text(
                    'Room Type',
                    style: TextStyle(
                      color: TinniPalette.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Mic Types'),
                    Tab(text: 'Cover'),
                    Tab(text: 'Mic Theme'),
                    Tab(text: 'Setting'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.event_seat_rounded),
                            title: const Text('Mic Types'),
                            subtitle: Text(
                              '$roomSeatCount seats • Tinni 8–42 layout',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _showSeatCountSelector();
                            },
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ListTile(
                            leading: const Icon(Icons.image_rounded),
                            title: const Text('Room Cover / Theme'),
                            subtitle: const Text(
                              'Change the room background or theme.',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            enabled: isRoomHost,
                            onTap: !isRoomHost
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    _showRoomThemeSelector();
                                  },
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final entry in const <(String, String)>[
                            ('royal-gold', 'Royal Gold'),
                            ('neon-blue', 'Neon Blue'),
                            ('rose-glow', 'Rose Glow'),
                          ])
                            ListTile(
                              leading: Icon(
                                roomSeatThemeId == entry.$1
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: roomSeatThemeId == entry.$1
                                    ? _seatThemeAccent
                                    : TinniPalette.muted,
                              ),
                              title: Text(entry.$2),
                              enabled: isRoomHost,
                              onTap: !isRoomHost
                                  ? null
                                  : () async {
                                      final ok =
                                          await _saveRoomConfiguration(
                                        seatThemeId: entry.$1,
                                      );
                                      if (ok && mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                    },
                            ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (isRoomHost)
                            ListTile(
                              leading: Icon(
                                switch (roomMode) {
                                  'game' => Icons.sports_esports_rounded,
                                  'live' => Icons.videocam_rounded,
                                  _ => Icons.mic_rounded,
                                },
                              ),
                              title: const Text('Room Mode'),
                              subtitle: Text(
                                switch (roomMode) {
                                  'game' => 'Game Room',
                                  'live' => 'Live Room',
                                  _ => 'Voice Room',
                                },
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _showRoomModeSelector();
                              },
                            ),
                          ListTile(
                            leading: const Icon(Icons.event_seat_rounded),
                            title: const Text('Room Seats'),
                            subtitle: Text('$roomSeatCount seats'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _showSeatCountSelector();
                            },
                          ),
                          if (isRoomHost)
                            ListTile(
                              leading:
                                  const Icon(Icons.mic_external_on_rounded),
                              title: const Text('Mic Type'),
                              subtitle: Text(
                                roomMicMode == 'free'
                                    ? 'Free mic'
                                    : 'Request mic',
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _showMicModeControl();
                              },
                            ),
                          if (isRoomAdmin && seatRequests.isNotEmpty)
                            ListTile(
                              leading: const Icon(Icons.how_to_reg_rounded),
                              title: const Text('Mic Requests'),
                              subtitle:
                                  Text('${seatRequests.length} pending'),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _showMicRequests();
                              },
                            ),
                          if (isRoomHost)
                            SwitchListTile(
                              secondary: Icon(
                                roomLocked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                color: TinniPalette.gold,
                              ),
                              title: const Text('Room Lock'),
                              subtitle: Text(
                                roomLocked
                                    ? (roomLockCode == null
                                        ? '5-digit code active'
                                        : 'Code: $roomLockCode')
                                    : 'Off',
                              ),
                              value: roomLocked,
                              onChanged: (value) async {
                                final ok = await _saveRoomConfiguration(
                                  locked: value,
                                );
                                if (ok && mounted) setState(() {});
                              },
                            ),
                          if (isRoomHost)
                            ListTile(
                              leading: const Icon(Icons.settings_rounded),
                              title: const Text('More room settings'),
                              subtitle: const Text(
                                'Room type, name, notice, welcome picture and party mode',
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _openRoomSettings();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomToolTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: label == 'Red Pocket (LP)'
                ? const [Color(0xFF5B0710), Color(0xFF220204)]
                : const [Color(0xFF120D04), Color(0xFF030303)],
          ),
          border: Border.all(
            color: TinniPalette.gold.withValues(alpha: enabled ? .88 : .28),
          ),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x44FFD45A),
                    blurRadius: 9,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TinniGlowIcon(icon: icon, size: 20, boxSize: 38),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: enabled ? TinniPalette.cream : TinniPalette.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoomTools() async {
    final tools = <(String, IconData, VoidCallback, bool)>[
      (
        'Room Type',
        Icons.dashboard_customize_rounded,
        _showRoomTypePanel,
        isRoomAdmin,
      ),
      (
        'Music',
        Icons.music_note_rounded,
        _showRoomMusic,
        isRoomAdmin,
      ),
      (
        'Effects',
        Icons.auto_awesome_rounded,
        _showRoomEffects,
        true,
      ),
      (
        'Red Pocket (LP)',
        Icons.card_giftcard_rounded,
        _showLuckyPouch,
        true,
      ),
      (
        roomMusic.outputMuted ? 'Sound Off' : 'Sound On',
        roomMusic.outputMuted
            ? Icons.volume_off_rounded
            : Icons.volume_up_rounded,
        _toggleRoomSound,
        true,
      ),
      (
        'Lucky Number',
        Icons.confirmation_number_rounded,
        _showLuckyNumber,
        true,
      ),
      (
        groupPkEnabled ? 'Stop Group PK' : 'Group PK',
        Icons.sports_mma_rounded,
        _toggleGroupPk,
        true,
      ),
      (
        'Public Screen',
        Icons.tv_rounded,
        _showPublicScreen,
        isRoomAdmin,
      ),
      (
        'Report',
        Icons.report_rounded,
        _reportRoom,
        !isRoomHost,
      ),
    ];

    final visible = tools.where((tool) {
      if (tool.$1 == 'Room Type' || tool.$1 == 'Music') return isRoomAdmin;
      if (tool.$1 == 'Public Screen') return isRoomAdmin;
      return true;
    }).toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: visible.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: .88,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, index) {
              final tool = visible[index];
              return _roomToolTile(
                label: tool.$1,
                icon: tool.$2,
                enabled: tool.$4,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future<void>.delayed(
                    const Duration(milliseconds: 220),
                    tool.$3,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openExitMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('room-exit-minimize'),
            leading: const Icon(Icons.minimize_rounded),
            title: const Text('Minimize'),
            onTap: () { Navigator.pop(sheetContext); _minimizeRoom(); },
          ),
          ListTile(
            key: const Key('room-exit-leave'),
            leading: const Icon(Icons.exit_to_app_rounded),
            title: const Text('Exit'),
            onTap: () { Navigator.pop(sheetContext); _leaveRoom(); },
          ),
        ]),
      ),
    );
  }

  Future<void> _openRoomMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy room ID'),
              subtitle: Text(widget.room.roomNumber),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: widget.room.roomNumber));
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
            if (widget.state.hasVipPrivilege('send_pictures'))
              ListTile(
                key: const Key('room-send-photo-menu'),
                leading: const Icon(Icons.photo_rounded),
                title: const Text('Send room photo'),
                subtitle: const Text('VIP10+ room image message'),
                onTap: uploadingRoomImage
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        Future<void>.delayed(
                          const Duration(milliseconds: 180),
                          _sendRoomImage,
                        );
                      },
              ),
            if (roomMode == 'live' && mySeat != null)
              ListTile(
                key: const Key('room-camera-menu'),
                leading: Icon(
                  cameraPublished
                      ? Icons.videocam_off_rounded
                      : Icons.videocam_rounded,
                ),
                title: Text(
                  cameraPublished ? 'Turn camera off' : 'Turn camera on',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future<void>.delayed(
                    const Duration(milliseconds: 180),
                    _toggleCamera,
                  );
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
          ],
        )),
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

  Future<Map<String, dynamic>?> _createRoomCustomGift() async {
    if (!widget.state.backendConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to the server before creating a Custom Gift.')),
      );
      return null;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'mp4'],
    );
    if (files.isEmpty || !mounted) return null;
    final file = files.first;
    final path = file.path;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This custom gift file could not be opened.')),
      );
      return null;
    }
    final lower = file.name.toLowerCase();
    final extension = lower.contains('.') ? lower.split('.').last : '';
    final contentType = switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      _ => '',
    };
    if (contentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose PNG, JPG, WebP or MP4.')),
      );
      return null;
    }

    final nameController = TextEditingController(
      text: file.name.contains('.')
          ? file.name.substring(0, file.name.lastIndexOf('.'))
          : file.name,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Gift'),
        content: TextField(
          controller: nameController,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Gift name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = nameController.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return null;

    try {
      final bytes = await File(path).readAsBytes();
      final normalizedExtension = extension == 'jpeg' ? 'jpg' : extension;
      final key = await widget.state.backend.uploadImage(
        key: 'custom-gifts/${widget.state.userId}/gift-${DateTime.now().microsecondsSinceEpoch}.$normalizedExtension',
        bytes: bytes,
        contentType: contentType,
      );
      if (key == null) throw StateError('upload_failed');
      final result = await widget.state.backend.createCustomGift(
        userId: widget.state.userId,
        name: name.trim(),
        assetKey: key,
      );
      final gift = result?['gift'];
      if (gift is! Map) throw StateError('create_failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(name.trim() + ' added to Custom Gifts.')),
      );
      return Map<String, dynamic>.from(gift);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom Gift could not be created.')),
        );
      }
      return null;
    }
  }

  Future<void> _sendGiftByDefinition(
    Map<String, dynamic> gift,
    String receiverId,
  ) async {
    final giftId = gift['id']?.toString() ?? '';
    final giftCost = int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
    if (giftId.isEmpty || giftCost <= 0 || receiverId.isEmpty) return;
    final result = await widget.state.backend.sendGift(
      roomId: widget.room.id,
      senderUserId: widget.state.userId,
      receiverUserId: receiverId,
      giftId: giftId,
      coinCost: giftCost,
    );
    final remoteBalance =
        int.tryParse(result?['sender_coin_balance']?.toString() ?? '');
    if (remoteBalance != null) {
      widget.state.setCoinBalance(remoteBalance);
      _playGiftEffect(gift);
      await widget.state.refreshIdLevel(notify: false);
      if (!mounted) return;
      unawaited(_loadRoomGiftRanking());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (gift['emoji']?.toString() ?? '🎁') +
                ' ' +
                (gift['name']?.toString() ?? 'Gift') +
                ' sent • ' +
                giftCost.toString() +
                ' coins',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final error = result?['error']?.toString() ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.isEmpty
              ? 'Gift was not sent. Check access and coin balance.'
              : error.replaceAll('_', ' '),
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
          ListTile(
            key: const Key('room-create-custom-gift'),
            leading: const TinniGlowIcon(
              icon: Icons.add_photo_alternate_rounded,
              size: 20,
              boxSize: 38,
            ),
            title: const Text('Custom Gift'),
            subtitle: const Text('Create with PNG, JPG, WebP or MP4'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              Navigator.pop(sheetContext);
              final created = await _createRoomCustomGift();
              if (created == null || !mounted) return;
              await _sendGiftByDefinition(created, receiverId);
            },
          ),
          const Divider(height: 1),
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
    if (widget.state.backendConnected && receiverId.isNotEmpty) {
      await _sendGiftByDefinition(gift, receiverId);
      return;
    }
  }

  Future<void> _sendInlineMessage([String? override]) async {
    if (chatBanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room owner/admin has chat banned this ID')),
      );
      return;
    }
    if (!publicScreenEnabled && !isRoomAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Public Screen is owner/admin only')),
      );
      return;
    }
    final value = (override ?? roomChatController.text).trim();
    if (value.isEmpty) return;
    if (widget.state.backendConnected) {
      final sent = await widget.state.backend.sendRoomMessage(
        roomId: widget.room.id,
        userId: widget.state.userId,
        text: value,
      );
      if (!sent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message was not sent. Check your connection.')),
          );
        }
        return;
      }
      roomChatController.clear();
      await _loadRoomMessages();
      return;
    }
    if (!mounted) return;
    roomChatController.clear();
    setState(() => chat.add(<String, dynamic>{
      'display_name': widget.state.displayName,
      'text': value,
    }));
  }

  Future<void> _showEmojiPicker() async {
    const emojis = <String>[
      '😀', '😂', '😍', '🥰', '😎', '🥳', '😭', '😡',
      '❤️', '🔥', '👏', '👍', '🎉', '🎁', '⭐', '💯',
      '🌹', '💎', '👑', '🎤', '🎵', '🤝', '😘', '🙏',
    ];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final value in emojis)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(sheetContext, value),
                  child: Center(
                    child: Text(value, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null || !mounted) return;
    roomChatController
      ..text += emoji
      ..selection = TextSelection.collapsed(
        offset: roomChatController.text.length,
      );
  }

  Future<void> _openRoomInbox() async {
    await widget.state.refreshInbox();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MessagesScreen(state: widget.state),
      ),
    );
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
    if (roomMode != 'live') return const SizedBox.shrink();
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
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            InkWell(
              key: const Key('room-dp-settings'),
              onTap: _openRoomMenu,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
              radius: 19,
              backgroundImage: roomAvatarKey == null
                  ? null
                  : NetworkImage(widget.state.backend.fileUrl(roomAvatarKey!), headers: widget.state.backend.fileHeaders),
              child: roomAvatarKey == null ? const Icon(Icons.mic_rounded, size: 18) : null,
            ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roomName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    'ID ${widget.room.roomNumber} • ${switch (roomMode) { 'game' => 'Game Room', 'live' => 'Live Room', _ => 'Voice Room' }} • ${roomPartyMode == 'Event hosting mode' ? 'Event Mode' : 'Friends Party'} • $voiceStatus',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (roomMode == 'live')
            IconButton(
              onPressed: mySeat == null ? null : _toggleCamera,
              tooltip: cameraPublished ? 'Turn camera off' : 'Turn camera on',
              icon: TinniGlowIcon(
                icon: cameraPublished
                    ? Icons.videocam_off_rounded
                    : Icons.videocam_rounded,
                size: 18,
                boxSize: 34,
              ),
            ),
          IconButton(
            onPressed: _shareRoomId,
            tooltip: 'Share room',
            icon: const TinniGlowIcon(
              icon: Icons.share_rounded,
              size: 18,
              boxSize: 34,
            ),
          ),
          IconButton(
            onPressed: _openExitMenu,
            tooltip: 'Exit or minimize',
            icon: const TinniGlowIcon(
              icon: Icons.power_settings_new_rounded,
              size: 18,
              boxSize: 34,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (roomThemeAssetKey != null)
            Positioned.fill(
              child: Image(
                image: NetworkImage(
                  widget.state.backend.fileUrl(roomThemeAssetKey!),
                  headers: widget.state.backend.fileHeaders,
                ),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: _roomThemeColor),
              ),
            ),
          if (roomThemeAssetKey != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .28),
              ),
            ),
          Positioned.fill(
            child: Column(
              children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
            child: Row(
              children: [
                TinniPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  onTap: _showRoomGiftRanking,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 17,
                        color: TinniPalette.gold,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Ranking',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                TinniPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  onTap: _showRoomGiftRanking,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 15,
                        color: TinniPalette.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _compactRoomCoins(roomGiftLifetimeTotal),
                        style: const TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _RoomLampButton(onTap: _openLamp),
                const SizedBox(width: 6),
                TinniPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  onTap: _openRoomMembers,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roomMembers.isNotEmpty)
                        SizedBox(
                          width: 28.0 +
                              ((roomMembers.take(3).length - 1) * 17.0),
                          height: 28,
                          child: Stack(
                            children: [
                              for (var index = 0;
                                  index < roomMembers.take(3).length;
                                  index++)
                                Positioned(
                                  left: index * 17.0,
                                  child: GestureDetector(
                                    onTap: _openRoomMembers,
                                    child: CircleAvatar(
                                      radius: 13,
                                      backgroundColor: TinniPalette.panel2,
                                      backgroundImage:
                                          roomMembers[index]['avatar_key']
                                                      ?.toString()
                                                      .isNotEmpty ==
                                                  true
                                              ? NetworkImage(
                                                  widget.state.backend.fileUrl(
                                                    roomMembers[index]
                                                            ['avatar_key']
                                                        .toString(),
                                                  ),
                                                  headers: widget
                                                      .state.backend.fileHeaders,
                                                )
                                              : null,
                                      child: roomMembers[index]['avatar_key']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? null
                                          : const Icon(
                                              Icons.person_rounded,
                                              size: 13,
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        const Icon(
                          Icons.groups_rounded,
                          size: 17,
                          color: TinniPalette.cream,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        '${roomMembers.length}',
                        style: const TextStyle(
                          color: TinniPalette.cream,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _videoStage(),
          Expanded(
            key: const Key('darkvibex-seat-grid'),
            flex: 11,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactSeats = roomSeatCount >= 31;
                final widthSeatDiameter =
                    spec.seatDiameter(constraints.maxWidth - 8);
                final rowLabelSpace = compactSeats
                    ? 18.0
                    : (widthSeatDiameter < 48 ? 28.0 : 38.0);
                final heightSeatDiameter =
                    (constraints.maxHeight / spec.rows) - rowLabelSpace;
                final diameter =
                    (widthSeatDiameter < heightSeatDiameter
                            ? widthSeatDiameter
                            : heightSeatDiameter)
                        .clamp(compactSeats ? 22.0 : 30.0, 68.0)
                        .toDouble();
                final seatWidth =
                    (diameter + (diameter < 44 ? 8 : 16))
                        .clamp(38.0, 78.0)
                        .toDouble();

                Widget seatTile(int seat) {
                  final mine = mySeat == seat;
                  final member = membersBySeat[seat];
                  final avatar = member?['avatar_key']?.toString();
                  final vipLevel = int.tryParse(
                        member?['active_vip_level']?.toString() ?? '',
                      ) ??
                      0;
                  final activeFrame = member?['active_frame_id']?.toString();
                  final frameTier = switch (activeFrame) {
                    'frame_royal' => 1,
                    'frame_king' => 18,
                    'frame_phoenix' => 8,
                    'frame_sapphire' => 4,
                    _ => vipLevel,
                  };
                  final micOn = member != null &&
                      (member['mic_muted'] == 0 ||
                          member['mic_muted']?.toString() == '0');

                  return SizedBox(
                    width: seatWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => unawaited(_tapSeat(seat)),
                      onLongPress: isRoomAdmin
                          ? () => unawaited(_showSeatControls(seat))
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: diameter,
                            height: diameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: mine ? 3 : 1.2,
                                color: mine
                                    ? TinniPalette.brightGold
                                    : effectsEnabled
                                        ? _seatThemeAccent
                                        : TinniPalette.bronze,
                              ),
                              boxShadow: effectsEnabled
                                  ? [
                                      BoxShadow(
                                        color: _seatThemeAccent
                                            .withValues(alpha: .18),
                                        blurRadius: 9,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: member != null
                                ? VipAnimatedFrame(
                                    size: diameter - 2,
                                    enabled: activeFrame != null ||
                                        vipLevel >= 7 ||
                                        (vipLevel >= 16 && micOn),
                                    level: frameTier,
                                    styleId: activeFrame,
                                    child: CircleAvatar(
                                      backgroundImage:
                                          avatar != null && avatar.isNotEmpty
                                              ? NetworkImage(
                                                  widget.state.backend
                                                      .fileUrl(avatar),
                                                  headers: widget.state.backend
                                                      .fileHeaders,
                                                )
                                              : null,
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          if (avatar == null || avatar.isEmpty)
                                            const Center(
                                              child:
                                                  Icon(Icons.person_rounded),
                                            ),
                                          Icon(
                                            micOn
                                                ? Icons.mic_rounded
                                                : Icons.mic_off_rounded,
                                            size: diameter < 48 ? 11 : 13,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Icon(
                                    lockedSeats.contains(seat)
                                        ? Icons.lock_rounded
                                        : mine
                                            ? (muted
                                                ? Icons.mic_off_rounded
                                                : Icons.mic_rounded)
                                            : Icons.add_rounded,
                                    size: diameter < 48 ? 17 : 22,
                                    color: lockedSeats.contains(seat)
                                        ? Colors.orangeAccent
                                        : TinniPalette.cream,
                                  ),
                          ),
                          SizedBox(height: compactSeats ? 1 : 3),
                          Text(
                            mine
                                ? (widget.state.vipAnonymousEverywhere
                                    ? 'Anonymous'
                                    : widget.state.displayName)
                                : (member?['display_name']?.toString() ??
                                    'No.${seat + 1}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize:
                                  compactSeats ? 8 : (diameter < 48 ? 9 : 11),
                              color: TinniPalette.cream,
                            ),
                          ),
                          if (mine &&
                              widget.state.hasVipPrivilege('mic_chair'))
                            const Icon(
                              Icons.chair_alt_rounded,
                              size: 12,
                              color: TinniPalette.brightGold,
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                  child: Column(
                    children: [
                      for (var row = 0; row < spec.rows; row++)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final range = spec.rangeForRow(row);
                              return Row(
                                key: Key('darkvibex-seat-row-$row'),
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  for (var seat = range.$1;
                                      seat < range.$2;
                                      seat++)
                                    SizedBox(
                                      width: seatWidth,
                                      child: seatTile(seat),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 9,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView.builder(
                      key: const Key('room-chat-list'),
                      itemCount: chat.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                key: const Key('official-announcement'),
                                color: const Color(0xFF2A1F12),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: const Text(
                                    'Be respectful. No harassment, explicit or unlawful content, scams, or sharing private information. Room chat and voice are visible to participants.',
                                  ),
                                ),
                              ),
                              if (roomNoticesEnabled && (roomAnnouncement != null || roomWelcomeImageKey?.isNotEmpty == true))
                                Card(
                                  key: const Key('room-owner-greeting'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Text('Room owner greeting', style: TextStyle(fontWeight: FontWeight.w800)),
                                      if (roomAnnouncement != null) Text(roomAnnouncement!),
                                      if (roomWelcomeImageKey?.isNotEmpty == true)
                                        Image.network(widget.state.backend.fileUrl(roomWelcomeImageKey!), height: 116, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Text('Welcome picture unavailable')),
                                    ]),
                                  ),
                                ),
                            ],
                          );
                        }
                        final message = chat[index - 1];
                        final name = message['display_name']?.toString().trim();
                        final text = message['text']?.toString() ?? '';
                        final imageKey = message['image_key']?.toString();
                        final senderId = message['user_id']?.toString() ?? '';
                        final bubbleId = senderId == widget.state.userId
                            ? widget.state.activeCosmetic('bubble')
                            : message['active_bubble_id']?.toString();
                        final hasBubble =
                            bubbleId != null && bubbleId.isNotEmpty;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Container(
                            padding: hasBubble
                                ? const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  )
                                : EdgeInsets.zero,
                            decoration: hasBubble
                                ? BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: <Color>[
                                        Color(0x992A1538),
                                        Color(0x995A2D65),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xAAEE91FF),
                                    ),
                                  )
                                : null,
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
          if (rocketDrawNoticeEnabled && effectsEnabled)
            Positioned(
            key: const Key('room-game-floating-position'),
            right: 8,
            bottom: 138,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: 'Rocket',
                  child: InkResponse(
                    key: const Key('room-rocket-floating-button'),
                    radius: 24,
                    onTap: _showRocketPanel,
                    child: const RoomStealthRocketLogo(size: 42),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111214),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: const Color(0xFF5D6065),
                      width: .8,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x44FF8A1F),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Semantics(
                  button: true,
                  label: 'Game Center',
                  child: InkResponse(
                    key: const Key('room-game-floating-button'),
                    radius: 26,
                    onTap: _openGames,
                    child: const RoomGameKeyboardLogo(size: 54),
                  ),
                ),
              ],
            ),
          ),
          if (activeGiftEffect != null && effectsEnabled && giftEffectsEnabled)
            Positioned(
              left: 24,
              right: 24,
              bottom: 154,
              child: IgnorePointer(
                child: Container(
                  key: const Key('room-gift-effect'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        Color(0xEE25102F),
                        Color(0xEE5A2D65),
                        Color(0xEE1A1022),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: TinniPalette.gold),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x55FFD45A),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        activeGiftEffect?['emoji']?.toString() ?? '🎁',
                        style: const TextStyle(fontSize: 34),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activeGiftEffect?['name']?.toString() ?? 'Gift',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TinniPalette.cream,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (arrivalEffectMember != null && effectsEnabled && carEffectsEnabled)
            Positioned.fill(
              child: VehicleEntryEffect(
                displayName: (arrivalEffectMember?['display_name']?.toString().trim().isNotEmpty == true)
                    ? arrivalEffectMember!['display_name'].toString()
                    : 'VIP member',
                level: int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0,
                showVehicle: (int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0) >= 8 ||
                    arrivalEffectMember?['active_vehicle_id'] != null ||
                    arrivalEffectMember?['active_entry_id'] != null,
                customVehicle: arrivalEffectMember?['active_vehicle_id']?.toString() == 'vehicle_king' ||
                    arrivalEffectMember?['active_entry_id'] != null ||
                    (int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0) >= 18,
                vehicleLabel: arrivalEffectMember?['active_entry_id']?.toString().isNotEmpty == true
                    ? arrivalEffectMember!['active_entry_id']
                        .toString()
                        .replaceAll('entry-', '')
                        .replaceAll('-', ' ')
                        .toUpperCase()
                    : switch (arrivalEffectMember?['active_vehicle_id']?.toString()) {
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: const BoxDecoration(
            color: TinniPalette.black,
            border: Border(top: BorderSide(color: TinniPalette.bronze)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: roomChatController,
                  enabled: !chatBanned && (publicScreenEnabled || isRoomAdmin),
                  textInputAction: TextInputAction.send,
                  maxLength: 200,
                  buildCounter: (
                    BuildContext context, {
                    required int currentLength,
                    required bool isFocused,
                    required int? maxLength,
                  }) => null,
                  decoration: InputDecoration(
                    hintText: chatBanned
                        ? 'Chat banned'
                        : (!publicScreenEnabled && !isRoomAdmin
                            ? 'Owner/Admin only'
                            : 'Chat'),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendInlineMessage(),
                ),
              ),
              IconButton(
                tooltip: 'Emoji & Emotes',
                onPressed: _showEmojiPicker,
                icon: const TinniGlowIcon(
                  icon: Icons.emoji_emotions_rounded,
                  size: 20,
                  boxSize: 36,
                ),
              ),
              IconButton(
                tooltip: 'Microphone',
                onPressed: mySeat == null ? null : _toggleMic,
                icon: TinniGlowIcon(
                  icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  size: 20,
                  boxSize: 36,
                ),
              ),
              IconButton(
                tooltip: 'Gifts',
                onPressed: _sendGift,
                icon: const TinniGlowIcon(
                  icon: Icons.card_giftcard_rounded,
                  size: 20,
                  boxSize: 36,
                ),
              ),
              IconButton(
                tooltip: 'Messages',
                onPressed: _openRoomInbox,
                icon: const TinniGlowIcon(
                  icon: Icons.mark_chat_unread_rounded,
                  size: 20,
                  boxSize: 36,
                ),
              ),
              IconButton(
                tooltip: '4-Box',
                onPressed: _showRoomTools,
                icon: const TinniGlowIcon(
                  icon: Icons.grid_view_rounded,
                  size: 20,
                  boxSize: 36,
                ),
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
    return Tooltip(
      message: 'Aladdin\'s Lamp',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: const SizedBox(
            width: 42,
            height: 36,
            child: Padding(
              padding: EdgeInsets.all(3),
              child: CustomPaint(painter: _MiniLampPainter()),
            ),
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
