import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:image_picker/image_picker.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart' as gift_video;

import '../utils/public_user_id.dart';
import '../utils/room_kick_tracker.dart';
import '../app/app_state.dart';
import '../background/room_foreground_service.dart';
import '../background/room_permission_bridge.dart';
import '../infra/backend_api.dart';
import '../infra/agora_rtc.dart';
import '../infra/realtime.dart';
import '../room/seat_layout.dart';
import '../room/month_top_gifter.dart';
import '../room/ktv_service.dart';
import '../vip/vip_policy.dart';
import '../vip/vip_visual_assets.dart';
import '../widgets/vip_animated_frame.dart';
import '../widgets/seat_panda_emote.dart';
import '../widgets/vip_entry_effect_banner.dart';
import '../widgets/gift_ribbon_banner.dart';
import '../widgets/top_room_banner.dart';
import '../widgets/level_medal.dart';
import '../widgets/vip_tag_image.dart';
import '../widgets/vip_name_text.dart';
import '../widgets/vip_priority_message_banner.dart';
import '../widgets/profile_card_anim_background.dart';
import '../ui/tinni_style.dart';
import '../widgets/gift_media_preview.dart';
import '../widgets/cosmetic_store_previews.dart';
import '../widgets/vip_chat_bubble.dart';
import '../widgets/room_chat_sender_header.dart';
import '../widgets/custom_asset_effect_playback.dart';
import '../widgets/vehicle_entry_effect.dart';
import '../widgets/vehicle_entry_effect_v2.dart';
import '../widgets/room_floating_logos.dart';
import 'aladdin_lamp_screen.dart';
import 'legal_policy_screen.dart';
import 'games_screen.dart';
import 'fruit_party_screen.dart';
import 'greedy_girl_screen.dart';
import 'home_shell.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import '../utils/rocket_progress.dart';
import '../utils/rocket_reward_frames.dart';
import '../widgets/rocket_reward_frame_preview.dart';
import 'conversation_screen.dart';
import 'rocket_room_screen.dart';
import 'room_gift_ranking_screen.dart';

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

class _RoomScreenState extends State<RoomScreen>
    with WidgetsBindingObserver {
  static final Set<String> _acceptedLegalInSession = <String>{};
  static const List<int> _rocketStageTargets = rocketStageTargets;
  int? mySeat;
  bool muted = true;
  String voiceStatus = 'Connecting…';
  RtcAdapter? rtc;
  VoidCallback? _rtcMediaListener;
  StreamSubscription<AgoraGiftEvent>? _rtcGiftSubscription;
  bool cameraPublished = false;
  bool speakerphoneOn = true;
  bool followingRoom = false;
  bool followBusy = false;
  final List<Map<String, dynamic>> chat = <Map<String, dynamic>>[
    <String, dynamic>{'display_name': 'DarkVibeX', 'text': 'Welcome to the room 👋'},
  ];

  /// Priority message the user dismissed with the banner's X. The
  /// banner stays hidden until a newer priority message arrives.
  Map<String, dynamic>? _dismissedPriorityMessage;

  /// The priority message pinned at the top of the room chat (VIP9+),
  /// or null when there is none or it was dismissed.
  Map<String, dynamic>? get _pinnedPriorityMessage {
    final latest = latestPriorityMessage(chat);
    if (latest == null || identical(latest, _dismissedPriorityMessage)) {
      return null;
    }
    return latest;
  }
  final TextEditingController roomChatController = TextEditingController();
  final ScrollController roomChatScrollController = ScrollController();
  bool roomMessageSending = false;
  bool uploadingRoomImage = false;
  final Map<int, Map<String, dynamic>> membersBySeat = <int, Map<String, dynamic>>{};
  List<Map<String, dynamic>> roomMembers = <Map<String, dynamic>>[];
  int roomGiftLifetimeTotal = 0;
  int _giftEventCursorMs = DateTime.now().millisecondsSinceEpoch;
  String _giftEventCursorId = '';
  final Set<String> _seenGiftEventIds = <String>{};
  Future<void> _giftPlaybackQueue = Future<void>.value();
  List<Map<String, dynamic>> roomGiftRanking = <Map<String, dynamic>>[];
  bool _roomGiftRankingInitialized = false;
  // Month's top gifter for the header chip, from the 3s state poll
  // (gift_month_top). Shown only while they are in the room.
  Map<String, dynamic>? roomMonthTopGifter;
  int _lastObservedRocketCompleted = 0;
  OverlayEntry? _rocketLaunchOverlay;
  bool _rocketRewardDialogShowing = false;
  final Set<String> knownRoomMembers = <String>{};
  bool memberListInitialized = false;
  // Self-kick detection (Vinay, 2026-11-20): the worker 403s the member
  // list when my own membership row is gone (kicked), so consecutive
  // failed fetches mean I was removed — mic off, leave the channel,
  // exit the room. Set when I leave on purpose so a voluntary exit is
  // never mistaken for a kick.
  final RoomKickTracker _kickTracker = RoomKickTracker();
  bool _leavingRoom = false;
  // Room polling is split by data freshness needs. Polling every 4 seconds
  // for all four resources multiplied Worker requests for every connected user.
  Timer? roomStateTimer;
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
  int roomVipOnly = 0;
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
  bool rocketBannerEnabled = true;
  // Per-effect toggles (Vinay, 2026-11-22): every animation has its own
  // off switch. Each one is per-user (local prefs) — turning it off hides
  // that effect only for this user; everyone else in the room still sees it.
  bool giftBannerEnabled = true;
  bool gameBannerEnabled = true;
  Map<String, dynamic>? activeGiftEffect;
  // Gift split (Vinay, 2026-11-22): one gift sent in a single go to N
  // users shows as ONE gift in the screen centre, then splits into N
  // copies, one flying to each receiver's DP. All receivers of the same
  // batch share one effect; the per-seat widgets all start at the same
  // centre point, so they overlap as one gift and then diverge to their
  // seats. Same for a combo send (the same batch re-sent).
  Set<String> activeGiftReceiverIds = <String>{};
  String? activeGiftSenderId;
  DateTime? _giftEffectStartedAt;
  String? activeGiftReceiverAvatarKey;
  int giftEffectSequence = 0;
  Timer? giftEffectTimer;
  // Gift ribbon banner (VIP gift banner, shown with the gift display):
  // tier image for the sender's VIP level with the VIP level BIG and
  // bold, sender -> receiver, and the gift name. Cleared on its own
  // timer so it also shows after a gift video/GLB dialog closes.
  Map<String, dynamic>? activeGiftRibbon;
  Timer? giftRibbonTimer;
  // Top-of-room banner (Vinay, 2026-11-22): ONE 2-line banner at the
  // top, gift-banner style, for every event — gift sends (incl. Lucky
  // Bag), Lucky wins, big gifts, Rocket launches, VIP entries,
  // event/ranking announcements. One message at a time (NOT a
  // continuously scrolling marquee): the queue rotates every 4s, and
  // the banner hides when the queue is empty. A message that names
  // another room (a Rocket launch or big gift elsewhere) carries that
  // room's id, so tapping it takes the user into that room.
  final List<Map<String, dynamic>> _topBannerQueue = [];
  Map<String, dynamic>? _currentTopBanner;
  Timer? _topBannerTimer;
  final Set<String> _seenTopBannerKeys = <String>{};
  // Gift combo (Vinay, 2026-11-21): after a gift-box send, a combo button
  // appears below the Rocket so the same gift can be sent again to the
  // same users. _giftComboTotal counts every copy sent in this combo
  // (4 users x combo 7 = 28 per send). The button hides by itself after
  // 5s without a touch; every touch restarts the 5s timer.
  List<Map<String, dynamic>>? _giftComboGifts;
  List<String>? _giftComboRecipientIds;
  int _giftComboCount = 1;
  int _giftComboTotal = 0;
  // Combo timer (Vinay, 2026-11-21): the ring around the button drains
  // over 5s; a new key restarts it. Changing the key rebuilds the ring
  // animation from full — no periodic timer, no whole-screen rebuild.
  int _giftComboTimerKey = 0;
  final Map<String, String> activeSeatReactions = <String, String>{};
  final Map<String, String> activeSeatReactionMessageIds = <String, String>{};
  final Set<String> seenSeatReactionMessageIds = <String>{};
  final Map<String, Timer> seatReactionTimers = <String, Timer>{};
  // Panda seat emotes (userId -> emote name, e.g. "happy"). A panda
  // emote plays its VAP video on the sender's seat, above the DP, for
  // 5 seconds — the big animated reaction, not a text emoji. Cleared
  // by its own timer (and by the video's onDone).
  final Map<String, String> activeSeatPandaEmotes = <String, String>{};
  final Map<String, String> activeSeatPandaEmoteMessageIds =
      <String, String>{};
  final Map<String, Timer> seatPandaEmoteTimers = <String, Timer>{};
  final ValueNotifier<Map<String, double>> _silentSpeakingLevels =
      ValueNotifier<Map<String, double>>(const <String, double>{});
  final KtvService roomMusic = KtvService();
  final RoomForegroundServiceBridge roomForegroundService =
      const RoomForegroundServiceBridge();
  final RoomPermissionBridge roomPermissions = const RoomPermissionBridge();
  bool roomForegroundServiceStarted = false;

  bool get isRoomHost => widget.room.ownerUserId == widget.state.userId;
  bool get isRoomAdmin => isRoomHost || amRoomAdmin;

  int? _roomMessageTimestampMs(dynamic value) {
    if (value is num) {
      final timestamp = value.toInt();
      return timestamp < 100000000000 ? timestamp * 1000 : timestamp;
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final numeric = int.tryParse(raw);
    if (numeric != null) {
      return numeric < 100000000000 ? numeric * 1000 : numeric;
    }
    return DateTime.tryParse(raw)?.toLocal().millisecondsSinceEpoch;
  }

  // Chat clear (Vinay, 2026-11-20): the room owner/admin clears the chat
  // on the server from the 4-Box menu. An owner clear hides the old chat
  // from everyone; an admin clear hides it from everyone except the
  // owner. The server filters on the clear, so a cleared chat never
  // comes back on the next poll or after re-entering the room.
  Future<void> _clearRoomChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chat clear?'),
        content: Text(
          isRoomHost
              ? 'This clears the room chat for everyone. New messages will keep appearing.'
              : 'This clears the room chat for everyone except the room owner. New messages will keep appearing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-clear-room-chat'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chat clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    bool ok;
    try {
      ok = await widget.state.backend.clearRoomChat(
        roomId: widget.room.id,
        userId: widget.state.userId,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not clear the chat. Please try again.'),
        ),
      );
      return;
    }

    setState(() {
      chat.clear();
      _dismissedPriorityMessage = null;
      for (final timer in seatReactionTimers.values) {
        timer.cancel();
      }
      seatReactionTimers.clear();
      activeSeatReactions.clear();
      activeSeatReactionMessageIds.clear();
      seenSeatReactionMessageIds.clear();
      for (final timer in seatPandaEmoteTimers.values) {
        timer.cancel();
      }
      seatPandaEmoteTimers.clear();
      activeSeatPandaEmotes.clear();
      activeSeatPandaEmoteMessageIds.clear();
    });
    _scrollChatToLatest();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room chat cleared')),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    unawaited(_loadRoomSettings());
    unawaited(_loadRoomControls());
    unawaited(_loadRoomGiftRanking());
    unawaited(_loadRoomMessages());
    unawaited(_loadRoomGiftEvents());

    // One 3s poll for members + messages + controls + gift events +
    // settings (combined room-state endpoint) instead of five separate
    // timers. Speed does not drop — members were 4s, messages 8s,
    // controls 20s, settings 60s; now all refresh every 3s — while
    // the Workers free-tier request count drops. Any room setting
    // change (room DP, background, name, lock, room chat off) shows
    // to everyone within 3s. User actions still refresh data
    // immediately through the old loaders.
    bool appIsActive() =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    roomStateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (appIsActive()) unawaited(_loadRoomState());
    });
  }

  Future<void> _loadRoomMembers() async {
    if (!widget.state.backendConnected) return;
    final rows = await widget.state.backend.roomMembersOrNull(roomId: widget.room.id);
    if (rows == null) {
      // The members list failed — the worker 403s it when my own
      // membership row is gone (kicked). One failure is transient; two
      // in a row means I was removed.
      if (_leavingRoom) return;
      if (_kickTracker.noteFetch(ok: false)) {
        await _handleKickedFromRoom();
      }
      return;
    }
    _kickTracker.noteFetch(ok: true);
    await _applyRoomMembers(rows);
  }

  /// Applies a members list to the same state fields [_loadRoomMembers]
  /// sets (seat map, my seat/admin, mic-mute sync, arrival effects).
  /// Shared by the old members loader and the combined state loader so
  /// both paths render identically. Does NOT touch the kick tracker —
  /// the caller records the fetch outcome.
  Future<void> _applyRoomMembers(List<Map<String, dynamic>> rows) async {
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
    // Whether I was on a seat BEFORE the setState below: the server may
    // have seat-downed me (mySeat becomes null), and the mute sync after
    // it must still fire on that transition — otherwise a seat-downed
    // user's live mic can never be stopped (the mic toggle is disabled
    // off-seat and _toggleMic early-returns when mySeat is null).
    final wasOnSeat = mySeat != null;
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
    // Moderator mute must silence the voice, not just the icon: if the
    // server says my seat is muted but my mic is still live, mute it now.
    // (Audit fix, Vinay 2026-11-20 — the mic-off icon flipped but the
    // voice kept transmitting.)
    final ownRow = rows.where(
      (member) => member['user_id']?.toString() == widget.state.userId,
    );
    final ownMuted = ownRow.isNotEmpty &&
        (ownRow.first['mic_muted'] == 1 ||
            ownRow.first['mic_muted']?.toString() == '1');
    if (ownMuted && (mySeat != null || wasOnSeat) && !muted) {
      try {
        await rtc?.setMicPublished(false);
      } catch (_) {
        // The mic adapter throws when not joined (StateError); a failed
        // mute must not break the member refresh.
      }
      if (!mounted) return;
      setState(() => muted = true);
    }
    // Prefetch animal vehicle videos on room join / member refresh so
    // the first frames are buffered before an entry plays.
    _prefetchArrivalVehicleVideos(rows);
    for (final member in arrivals) {
      final level = int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0;
      final invisible = member['invisible_entry'] == true || member['invisible_entry']?.toString() == '1';
      final entryId = member['active_entry_id']?.toString() ?? '';
      final hasVipNameplate = entryId.startsWith('entrance-vip-');
      final hasEquippedVehicle =
          member['active_vehicle_id']?.toString().trim().isNotEmpty == true;
      final hasBuiltInEntry =
          entryId.isNotEmpty && !hasVipNameplate;
      if (invisible ||
          (!hasVipNameplate && !hasEquippedVehicle && !hasBuiltInEntry && level < 4)) {
        continue;
      }
      _prefetchArrivalVehicleVideos([member]);
      _showArrivalEffect(member);
    }
  }

  /// One combined poll for members + messages + controls + gift events,
  /// replacing the four separate timers. The payload embeds each
  /// section in the same shape as its old endpoint, so it is applied
  /// through the same helpers the old loaders use. Kick detection is
  /// unchanged: a failed call (worker 403 `room_membership_required`
  /// when my own membership row is gone) is null, one failure is
  /// transient, two in a row means I was removed. An empty members
  /// list is NOT a kick — it is a valid payload and is applied as-is.
  Future<void> _loadRoomState() async {
    if (!widget.state.backendConnected) return;
    final state = await widget.state.backend.roomStateOrNull(
      roomId: widget.room.id,
      after: _giftEventCursorMs,
      afterId: _giftEventCursorId,
    );
    if (state == null) {
      if (_leavingRoom) return;
      if (_kickTracker.noteFetch(ok: false)) {
        await _handleKickedFromRoom();
      }
      return;
    }
    _kickTracker.noteFetch(ok: true);
    final members = state['members'];
    if (members is List) {
      unawaited(
        _applyRoomMembers(
          members
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(),
        ),
      );
    }
    final messages = state['messages'];
    if (messages is List) {
      _applyRoomMessages(
        messages
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
    }
    final controls = state['controls'];
    if (controls is Map) {
      _applyRoomControls(Map<String, dynamic>.from(controls));
    }
    final events = state['events'];
    if (events is List) {
      _applyRoomGiftEvents(
        events
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
    }
    // Settings ride the same 3s poll now — any room setting change
    // (room DP, background, name, lock, room chat off) shows to
    // everyone within 3s. Absent on an older worker: skipped, never
    // a crash and never a stale clear of the current values.
    final settings = state['settings'];
    if (settings is Map) {
      // The state payload embeds the settings map itself; if a worker
      // shape wraps it under a `settings` key instead, unwrap that —
      // applying the wrapper would clear the boolean fields.
      final inner = settings['settings'];
      _applyRoomSettings(
        Map<String, dynamic>.from(inner is Map ? inner : settings),
      );
    }
    // Gift totals ride this same 3s poll (Vinay, 2026-11-21): the
    // lifetime total for the trophy/total chips, and the month's top
    // gifter for the header chip. Absent on an older worker: skipped,
    // never a crash and never a stale clear of the current values.
    final giftTotal = state['gift_lifetime_total'];
    final giftMonthTop = state['gift_month_top'];
    final nextTotal = giftTotal is num ? giftTotal.toInt() : null;
    final nextTop =
        giftMonthTop is Map ? Map<String, dynamic>.from(giftMonthTop) : null;
    final nextTopId = nextTop?['user_id']?.toString() ?? '';
    final currentTopId = roomMonthTopGifter?['user_id']?.toString() ?? '';
    if ((nextTotal != null && nextTotal > roomGiftLifetimeTotal) ||
        nextTopId != currentTopId) {
      if (!mounted) return;
      setState(() {
        if (nextTotal != null && nextTotal > roomGiftLifetimeTotal) {
          roomGiftLifetimeTotal = nextTotal;
        }
        roomMonthTopGifter = nextTop;
      });
    }
    // Cross-room banners (Vinay, 2026-11-22): Rocket launches, big
    // gifts and Lucky wins from ANY room ride the same 3s poll.
    // They join the top banner queue with their room id, so tapping
    // one takes the user into that room. A failed fetch keeps the
    // current queue — never a crash and never a stale clear.
    unawaited(_applyGlobalBanners());
  }

  Future<void> _applyGlobalBanners() async {
    if (!mounted || !widget.state.backendConnected) return;
    final items = await widget.state.backend.globalBanners();
    if (items == null || !mounted) return;
    for (final item in items) {
      final roomId = item['room_id']?.toString() ?? '';
      final text = item['text']?.toString() ?? '';
      final kind = item['kind']?.toString() ?? '';
      final createdAt = item['created_at']?.toString() ?? '';
      // Game wins name no room (games are global) — they still show
      // in every room, but with no room to enter (not tappable).
      final isGameWin = kind == 'game';
      if (text.isEmpty || (roomId.isEmpty && !isGameWin)) continue;
      // Skip this room's own events — they already arrive via the
      // room's gift events / Rocket launch / VIP entry paths.
      if (roomId == widget.room.id) continue;
      final bannerKind = switch (kind) {
        'rocket' => TopBannerKind.rocket,
        'gift' => TopBannerKind.gift,
        'lucky' => TopBannerKind.lucky,
        'game' => TopBannerKind.game,
        _ => TopBannerKind.event,
      };
      // Every rocket level has its own banner design (Vinay,
      // 2026-11-22) — the level rides the feed item.
      final rocketLevel = kind == 'rocket'
          ? int.tryParse(item['rocket_level']?.toString() ?? '')
          : null;
      _enqueueTopBanner(
        text: text,
        roomId: isGameWin ? null : roomId,
        key: 'global:$kind:$roomId:$createdAt',
        kind: bannerKind,
        rocketLevel: rocketLevel,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The 3s state poll is gated on the app being active, so a
      // background gap pauses my heartbeat — but my membership row
      // is never pruned (Vinay, 2026-11-21: an ID leaves a room only
      // when the user leaves it himself). Reconcile once on return
      // anyway, so a real kick during the gap still shows its dialog
      // instead of being counted as a transient failure.
      unawaited(_reconcileMembershipAfterResume());
    }
  }

  /// After a background gap, tell a real kick apart from a leave.
  /// The server records a kick marker only for an actual kick; a
  /// leave leaves none, and there is no presence-timeout prune
  /// (Vinay, 2026-11-21). Kicked -> the normal "Removed from room"
  /// flow. Left -> silently re-join and reset the kick tracker so
  /// the next poll does not show that dialog for a room I was never
  /// kicked from.
  Future<void> _reconcileMembershipAfterResume() async {
    if (_leavingRoom || !mounted || !widget.state.backendConnected) return;
    List<Map<String, dynamic>>? rows;
    try {
      rows = await widget.state.backend.roomMembersOrNull(
        roomId: widget.room.id,
      );
    } catch (_) {
      return;
    }
    if (rows != null) {
      _kickTracker.noteFetch(ok: true);
      return;
    }
    final kicked = await widget.state.backend.roomKickStatus(
      roomId: widget.room.id,
      userId: widget.state.userId,
    );
    if (kicked == null) return;
    if (kicked) {
      await _handleKickedFromRoom();
      return;
    }
    try {
      Map<String, dynamic>? joined = await widget.state.backend.joinRoomResult(
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
        if (password == null || !mounted) return;
        joined = await widget.state.backend.joinRoomResult(
          roomId: widget.room.id,
          userId: widget.state.userId,
          displayName: widget.state.displayName,
          password: password,
        );
        invalidPassword = joined?['error'] == 'room_password_invalid';
      }
      if (joined?['ok'] != true) return;
    } catch (_) {
      // A network drop on resume is not a kick — leave the tracker
      // alone; the normal poll will retry and only act on consecutive
      // failures.
      return;
    }
    _kickTracker.noteFetch(ok: true);
    await _loadRoomMembers();
  }

  /// Direct R2 URL for a member's animal vehicle video, or null when the
  /// member has a custom (non-animal) video key that must keep going
  /// through the Worker /api/files path.
  /// Rules: no member video key at all -> the level's animal video
  /// (VIP5-18 only, null below VIP5). Member key under vehicles/ -> the
  /// direct R2 URL for THAT key (it may be another level's animal via
  /// an Owner override). Any other key -> null (custom video, Worker path).
  String? _directAnimalVideoUrlForMember(Map<String, dynamic> member) {
    final memberVideoKey =
        ((member['active_vehicle_video_key'] ?? '').toString().trim().isNotEmpty)
            ? member['active_vehicle_video_key'].toString().trim()
            : (member['active_entry_video_key'] ?? '').toString().trim();
    if (memberVideoKey.isEmpty) {
      final level =
          int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0;
      return animalVideoUrlForVipLevel(level);
    }
    if (memberVideoKey.startsWith('vehicles/')) {
      return '$r2PublicBaseUrl/$memberVideoKey';
    }
    return null;
  }

  /// Prefetch the animal vehicle videos for the given members
  /// (best-effort, unawaited) so the first frames are buffered before
  /// an entry plays. The prefetch cache dedupes by URL, so calling
  /// this on every member refresh is cheap.
  void _prefetchArrivalVehicleVideos(List<Map<String, dynamic>> members) {
    for (final member in members) {
      final url = _directAnimalVideoUrlForMember(member);
      if (url != null) {
        CustomAssetEffectPlayback.prefetchDirectVideoUrl(url);
      }
    }
  }

  void _showArrivalEffect(Map<String, dynamic> member) {
    arrivalEffectTimer?.cancel();
    if (!mounted) return;
    setState(() => arrivalEffectMember = Map<String, dynamic>.from(member));
    // Top-of-room banner (Vinay, 2026-11-22): a VIP entry joins the
    // top banner queue (in-room only — the entry banner itself is the
    // Vehicle Effect, this message is the Game Banner).
    final entryVipLevel =
        int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0;
    if (entryVipLevel >= 5) {
      final entryName =
          (member['display_name']?.toString().trim().isNotEmpty == true)
              ? member['display_name'].toString()
              : 'User';
      // Entry effect banner (Vinay, 2026-11-22): the entering user's
      // DP shows in the banner with their name.
      final entryAvatarKey = member['avatar_key']?.toString().trim() ?? '';
      _enqueueTopBanner(
        text: '👑 $entryName (VIP$entryVipLevel) entered the room!',
        key: 'vip-entry:${member['user_id']?.toString() ?? ''}:${DateTime.now().millisecondsSinceEpoch}',
        kind: TopBannerKind.vip,
        avatarUrl: entryAvatarKey.isEmpty
            ? null
            : widget.state.backend.fileUrl(entryAvatarKey),
      );
    }
    final hasCustomMedia = [
      member['active_entry_video_key'], member['active_entry_glb_key'],
      member['active_vehicle_video_key'], member['active_vehicle_glb_key'],
    ].any((value) => value?.toString().trim().isNotEmpty == true);
    final activeEntryId = member['active_entry_id']?.toString() ?? '';
    final hasBuiltInVehicle =
        member['active_vehicle_id']?.toString().trim().isNotEmpty == true ||
        (activeEntryId.isNotEmpty && !activeEntryId.startsWith('entrance-vip-'));
    final requestedMs = int.tryParse(
      (member['active_entry_animation_ms'] ?? member['active_vehicle_animation_ms'] ?? '').toString(),
    ) ?? 0;
    // Keep the overlay visible while remote media initializes.
    final durationMs = (requestedMs > 0
        ? requestedMs.clamp(2000, 10000).toInt()
        : (hasCustomMedia ? 6000 : (hasBuiltInVehicle ? 4800 : 2000))) +
        (hasCustomMedia ? 5000 : 0);
    arrivalEffectTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) setState(() => arrivalEffectMember = null);
    });
  }

  void _scrollChatToLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !roomChatScrollController.hasClients) return;
      final target = roomChatScrollController.position.maxScrollExtent;
      if (animate) {
        roomChatScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        roomChatScrollController.jumpTo(target);
      }
    });
  }

  void _showSeatReaction({
    required String userId,
    required String emoji,
    required String messageId,
  }) {
    if (userId.isEmpty || emoji.isEmpty || messageId.isEmpty) return;
    if (activeSeatReactionMessageIds[userId] == messageId) return;
    activeSeatReactionMessageIds[userId] = messageId;
    activeSeatReactions[userId] = emoji;
    seatReactionTimers[userId]?.cancel();
    if (mounted) setState(() {});
    seatReactionTimers[userId] = Timer(const Duration(seconds: 3), () {
      if (!mounted ||
          activeSeatReactionMessageIds[userId] != messageId) {
        return;
      }
      setState(() {
        activeSeatReactions.remove(userId);
        activeSeatReactionMessageIds.remove(userId);
      });
      seatReactionTimers.remove(userId);
    });
  }

  /// Shows a panda emote on [userId]'s seat: the full-body panda VAP
  /// video plays above the DP for 5 seconds, then clears. A text emoji
  /// reaction on the same seat is replaced by the panda (the panda is
  /// the bigger reaction).
  void _showSeatPandaEmote({
    required String userId,
    required String emoteName,
    required String messageId,
  }) {
    if (userId.isEmpty ||
        emoteName.isEmpty ||
        messageId.isEmpty ||
        !isPandaEmoteName(emoteName)) {
      return;
    }
    if (activeSeatPandaEmoteMessageIds[userId] == messageId) return;
    activeSeatPandaEmoteMessageIds[userId] = messageId;
    activeSeatPandaEmotes[userId] = emoteName;
    seatPandaEmoteTimers[userId]?.cancel();
    // A panda replaces any text emoji on the same seat.
    activeSeatReactions.remove(userId);
    activeSeatReactionMessageIds.remove(userId);
    seatReactionTimers[userId]?.cancel();
    seatReactionTimers.remove(userId);
    if (mounted) setState(() {});
    seatPandaEmoteTimers[userId] = Timer(const Duration(seconds: 5), () {
      if (!mounted ||
          activeSeatPandaEmoteMessageIds[userId] != messageId) {
        return;
      }
      _clearSeatPandaEmote(userId, messageId);
    });
  }

  /// Clears the panda emote on [userId]'s seat (timer or video done).
  void _clearSeatPandaEmote(String userId, String messageId) {
    if (activeSeatPandaEmoteMessageIds[userId] != messageId) return;
    seatPandaEmoteTimers[userId]?.cancel();
    seatPandaEmoteTimers.remove(userId);
    if (!mounted) return;
    setState(() {
      activeSeatPandaEmotes.remove(userId);
      activeSeatPandaEmoteMessageIds.remove(userId);
    });
  }

  void _syncSeatReactions(List<Map<String, dynamic>> messages) {
    final latestByUser = <String, Map<String, dynamic>>{};
    for (final message in messages.reversed) {
      final userId = message['user_id']?.toString() ?? '';
      final text = message['text']?.toString().trim() ?? '';
      if (userId.isEmpty || text.isEmpty || latestByUser.containsKey(userId)) {
        continue;
      }
      // A panda emote marker ("[panda:happy]") is a seat reaction too —
      // check it BEFORE the text-emoji filter (the marker has letters,
      // so the filter below would skip it).
      if (pandaEmoteNameFromMarker(text) != null) {
        latestByUser[userId] = message;
        continue;
      }
      if (text.length > 12 || RegExp(r'[A-Za-z0-9]').hasMatch(text)) {
        continue;
      }
      latestByUser[userId] = message;
    }
    for (final entry in latestByUser.entries) {
      final message = entry.value;
      // The server stores created_at as epoch milliseconds, so
      // DateTime.tryParse never parses it and the 4s freshness guard
      // was dead (stale panda emotes replayed on every poll).
      final createdAtMs = _roomMessageTimestampMs(message['created_at']);
      if (createdAtMs != null &&
          DateTime.now().millisecondsSinceEpoch - createdAtMs >
              const Duration(seconds: 4).inMilliseconds) {
        continue;
      }
      final messageId = (message['id'] ??
              message['message_id'] ??
              message['created_at'] ??
              '${entry.key}:${message['text']}')
          .toString();
      if (seenSeatReactionMessageIds.contains(messageId)) continue;
      seenSeatReactionMessageIds.add(messageId);
      final String text = message['text']?.toString().trim() ?? '';
      final String? pandaName = pandaEmoteNameFromMarker(text);
      if (pandaName != null) {
        _showSeatPandaEmote(
          userId: entry.key,
          emoteName: pandaName,
          messageId: messageId,
        );
        continue;
      }
      _showSeatReaction(
        userId: entry.key,
        emoji: text,
        messageId: messageId,
      );
    }
  }

  String _roomMessageEventKey(Map<String, dynamic> message) {
    final id = message['id'] ?? message['message_id'] ?? message['messageId'];
    if (id != null && id.toString().isNotEmpty) return 'id:${id.toString()}';
    return <String>[
      message['user_id']?.toString() ?? '',
      message['created_at']?.toString() ?? '',
      message['text']?.toString() ?? '',
      message['image_key']?.toString() ?? '',
    ].join('|');
  }

  bool _isRoomGiftAnnouncement(Map<String, dynamic> message) {
    final text = message['text']?.toString() ?? '';
    return text.startsWith('🎁 ') && text.contains(' sent ') && text.contains(' to ');
  }

  Future<void> _loadRoomMessages() async {
    if (!widget.state.backendConnected) return;
    final rows = await widget.state.backend.roomMessages(roomId: widget.room.id);
    _applyRoomMessages(rows);
  }

  /// Applies a messages list to the same state fields [_loadRoomMessages]
  /// sets. Shared by the old messages loader and the combined state
  /// loader; the loader keeps the fetch, this keeps the rendering.
  void _applyRoomMessages(List<Map<String, dynamic>> rows) {
    if (!mounted) return;
    if (rows.isEmpty &&
        chat.length == 1 &&
        chat.first['text'] == 'Welcome to the room 👋') {
      return;
    }
    final next = rows
        .map((message) => Map<String, dynamic>.from(message))
        .toList();
    _syncSeatReactions(next);
    if (!mounted || next.toString() == chat.toString()) return;
    final previousMessageKeys = chat.map(_roomMessageEventKey).toSet();
    final hasNewGiftAnnouncement = next.any(
      (message) => _isRoomGiftAnnouncement(message) &&
          !previousMessageKeys.contains(_roomMessageEventKey(message)),
    );
    setState(() {
      chat
        ..clear()
        ..addAll(next);
    });
    _scrollChatToLatest();
    // Other room members learn about a gift through the existing room-chat
    // polling. Refresh totals only when a new gift event arrives, rather than
    // adding a high-frequency room-ranking poll for every participant.
    if (hasNewGiftAnnouncement) unawaited(_loadRoomGiftRanking());
  }

  Future<void> _loadRoomGiftEvents() async {
    if (!mounted || !widget.state.backendConnected) return;
    final events = await widget.state.backend.roomGiftEvents(
      roomId: widget.room.id,
      after: _giftEventCursorMs,
      afterId: _giftEventCursorId,
    );
    _applyRoomGiftEvents(events);
  }

  /// Applies gift events (cursor advance, dedup, playback queue) exactly
  /// as [_loadRoomGiftEvents] did. Shared by the old gift-events loader
  /// and the combined state loader.
  void _applyRoomGiftEvents(List<Map<String, dynamic>> events) {
    if (!mounted || events.isEmpty) return;

    for (final event in events) {
      final eventId = event['id']?.toString() ?? '';
      final createdAt = int.tryParse(event['created_at']?.toString() ?? '') ?? 0;
      if (createdAt > _giftEventCursorMs ||
          (createdAt == _giftEventCursorMs &&
              eventId.compareTo(_giftEventCursorId) > 0)) {
        _giftEventCursorMs = createdAt;
        _giftEventCursorId = eventId;
      }
      if (eventId.isEmpty || !_seenGiftEventIds.add(eventId)) continue;
      // The sender already plays the animation immediately after the
      // successful send response. Do not play the same event twice locally.
      if (event['sender_user_id']?.toString() == widget.state.userId) continue;

      final gift = <String, dynamic>{
        'id': event['gift_id']?.toString() ?? '',
        'name': event['gift_name']?.toString() ?? 'Gift',
        'emoji': event['emoji']?.toString() ?? '🎁',
        'coin_cost': event['coin_cost'] ?? 0,
        'video_key': event['video_key']?.toString() ?? '',
        'glb_key': event['glb_key']?.toString() ?? '',
        'svga_key': event['svga_key']?.toString() ?? '',
        'asset_key': event['asset_key']?.toString() ?? '',
      };
      final receiverId = event['receiver_user_id']?.toString() ?? '';
      final senderName = event['sender_name']?.toString() ?? 'User';
      final receiverName = event['receiver_name']?.toString() ?? 'User';
      _giftPlaybackQueue = _giftPlaybackQueue.then((_) async {
        if (!mounted || receiverId.isEmpty) return;
        final videoKey = gift['video_key']?.toString() ?? '';
        final glbKey = gift['glb_key']?.toString() ?? '';
        final svgaKey = gift['svga_key']?.toString() ?? '';
        // Dragon gifts skip the full-screen SVGA dialog (Vinay,
        // 2026-11-22): they fly in the screen centre, then to the DP.
        if (svgaKey.isNotEmpty && _isBigGift(gift) && !_isDragonGift(gift)) {
          await _playGiftSvga(
            gift,
            receiverId: receiverId,
            svgaKey: svgaKey,
            senderName: senderName,
          );
        } else if (videoKey.isNotEmpty) {
          await _playGiftVideo(
            gift,
            receiverId: receiverId,
            videoKey: videoKey,
            senderName: senderName,
          );
        } else if (glbKey.isNotEmpty) {
          await _playGiftGlb(gift, receiverId: receiverId, glbKey: glbKey);
        } else {
          _playGiftEffect(
            gift,
            receiverId: receiverId,
            senderId: event['sender_user_id']?.toString(),
          );
        }
        // Gift ribbon banner (sender's VIP tier, basic for VIP0):
        // shown with the gift display, after any video/GLB dialog.
        _showGiftRibbon(
          event: event,
          senderName: senderName,
          receiverName: receiverName,
          giftName: gift['name']?.toString() ?? 'Gift',
        );
        // Top-of-room banner (Vinay, 2026-11-22): every gift send
        // joins the top banner queue (Lucky Bag too — same banner).
        _enqueueTopBanner(
          text:
              '🎁 $senderName sent ${gift['name']?.toString() ?? 'Gift'} to $receiverName',
          key: 'gift:$eventId',
          kind: TopBannerKind.gift,
        );
        // Lucky win announcement (Vinay, 2026-11-22): a win on this
        // gift is announced to the room when the gift plays.
        _showLuckyWinAnnouncement(
          event,
          senderName,
          gift['name']?.toString() ?? 'Gift',
          receiverName,
        );
      });
    }
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

  void _showRocketLaunch(int level) {
    if (!mounted || !effectsEnabled || !rocketBannerEnabled) return;
    // Top-of-room banner (Vinay, 2026-11-22): the Rocket launch joins
    // the top banner queue (in-room — tapping is for other rooms'
    // launches, which arrive via the global banner feed).
    _enqueueTopBanner(
      text: '🚀 Rocket Lv.$level launched in ${widget.room.name}! Come and watch!',
      key: 'rocket:${widget.room.id}:$level',
      kind: TopBannerKind.rocket,
      rocketLevel: level,
    );
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final previous = _rocketLaunchOverlay;
    if (previous != null) {
      previous.remove();
      previous.dispose();
      _rocketLaunchOverlay = null;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => RoomRocketLaunchEffect(
        level: level,
        onFinished: () {
          if (!identical(_rocketLaunchOverlay, entry)) return;
          _rocketLaunchOverlay = null;
          entry.remove();
          entry.dispose();
        },
      ),
    );
    _rocketLaunchOverlay = entry;
    overlay.insert(entry);
  }

  String _formatRocketRewardCoins(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );

  Future<void> _showRocketRewardChest(int level) async {
    if (!mounted || _rocketRewardDialogShowing) {
      return;
    }
    _rocketRewardDialogShowing = true;
    try {
      final status = await widget.state.backend.roomRocketRewardStatus(
        roomId: widget.room.id,
        rocketLevel: level,
      );
      if (!mounted || status == null || status['ok'] != true) return;
      final rawTier = status['tier'];
      if (rawTier is! Map) return;
      final tier = Map<String, dynamic>.from(rawTier);
      final rewardFrame = rocketRewardFrameForGroup(tier['group']?.toString());
      // The reward pool pays random Coins only — no frames (Vinay,
      // 2026-11-19). When a tier awards no frames, the frame preview
      // and "First 0 successful claims ... 0 day(s)" line must not render.
      final frameWinners =
          int.tryParse(tier['frame_winners']?.toString() ?? '') ?? 0;
      final rawClaim = status['claim'];
      Map<String, dynamic>? claim = rawClaim is Map
          ? Map<String, dynamic>.from(rawClaim)
          : null;
      var alreadyClaimed = claim != null;
      var canClaim = status['can_claim'] == true;
      var claiming = false;
      var message = '';
      if (claim != null) {
        final type = claim['reward_type']?.toString() ?? '';
        message = type == 'frame'
            ? 'You already claimed ${claim['frame_name'] ?? rewardFrame['name']}. It is available in Store > Frame > Inventory for ${claim['frame_days'] ?? tier['frame_days']} day(s). Tap Use to equip it. No Coins were awarded.'
            : 'You already claimed ${_formatRocketRewardCoins(int.tryParse(claim['coins']?.toString() ?? '') ?? 0)} Coins.';
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF08173E),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: TinniPalette.brightGold, width: 1.2),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            contentPadding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
            actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            title: Column(
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFFBFA7FF), Color(0xFF53D9FF), Color(0xFFEC6B2D)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0xFF53D9FF).withValues(alpha: .3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFF422000),
                    size: 42,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ROCKET REWARD CHEST',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF50D8FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rocket Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${tier['max_winners']} winners • ${status['remaining_winners'] ?? 0} spots left',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE0E7FF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (frameWinners > 0) ...<Widget>[
                  const SizedBox(height: 10),
                  RocketRewardFramePreview(
                    rewardGroup: tier['group']?.toString(),
                    size: 58,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rewardFrame['name'] ?? 'Rocket Animated Frame',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF50D8FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'First ${tier['frame_winners']} successful claims receive this animated frame for ${tier['frame_days']} day(s), with no Coins deducted. Other winners receive ${_formatRocketRewardCoins(int.tryParse(tier['coin_min']?.toString() ?? '') ?? 0)}–${_formatRocketRewardCoins(int.tryParse(tier['coin_max']?.toString() ?? '') ?? 0)} Coins.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFBFCDF3),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    'Winners receive ${_formatRocketRewardCoins(int.tryParse(tier['coin_min']?.toString() ?? '') ?? 0)}–${_formatRocketRewardCoins(int.tryParse(tier['coin_max']?.toString() ?? '') ?? 0)} Coins.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFBFCDF3),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                if (message.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF50D8FF),
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ],
                if (!canClaim && !alreadyClaimed && message.isEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text(
                    'This chest has no claimable rewards remaining.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFFFC7B8), fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              if (!alreadyClaimed && canClaim)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('rocket-reward-claim-now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TinniPalette.brightGold,
                      foregroundColor: const Color(0xFF302000),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: claiming
                        ? null
                        : () async {
                            setDialogState(() {
                              claiming = true;
                              message = '';
                            });
                            // A failed claim used to leave CLAIMING… stuck
                            // (full-app audit 2026-11-20): the await threw,
                            // so `claiming` never reset. result stays null
                            // on failure, so the dialog shows the retry
                            // message and the button re-enables below.
                            Map<String, dynamic>? result;
                            try {
                              result = await widget.state.backend.claimRoomRocketReward(
                                roomId: widget.room.id,
                                rocketLevel: level,
                              );
                              if (result?['ok'] == true &&
                                  result?['reward_type']?.toString() == 'coins') {
                                await widget.state.refreshWallet();
                              } else if (result?['ok'] == true &&
                                  result?['reward_type']?.toString() == 'frame') {
                                await widget.state.refreshCosmetics();
                              }
                            } catch (_) {
                              result = null;
                            }
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              claiming = false;
                              if (result?['ok'] == true) {
                                canClaim = false;
                                final claimed = Map<String, dynamic>.from(result!);
                                claim = claimed;
                                alreadyClaimed = true;
                                if (claimed['reward_type']?.toString() == 'frame') {
                                  message = 'Congratulations! ${claimed['frame_name'] ?? rewardFrame['name']} is now in Store > Frame > Inventory for ${claimed['frame_days'] ?? tier['frame_days']} day(s). Tap Use to equip your animated frame. No Coins were awarded.';
                                } else {
                                  final amount = int.tryParse(claimed['coins']?.toString() ?? '') ?? 0;
                                  message = claimed['already_claimed'] == true
                                      ? 'This reward was already claimed. Your wallet has been refreshed: ${_formatRocketRewardCoins(amount)} Coins.'
                                      : 'Congratulations! ${_formatRocketRewardCoins(amount)} Coins have been added to your wallet.';
                                }
                              } else if (result?['error']?.toString() == 'reward_claims_full') {
                                canClaim = false;
                                message = 'All rewards for this Rocket chest have already been claimed.';
                              } else if (result?['error']?.toString() == 'rocket_target_not_reached') {
                                canClaim = false;
                                message = 'This Rocket target has not been reached yet.';
                              } else {
                                message = 'The reward could not be claimed. Please try again.';
                              }
                            });
                          },
                    child: Text(claiming ? 'CLAIMING…' : 'CLAIM NOW'),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(color: Color(0xFFBFCDF3), fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      _rocketRewardDialogShowing = false;
    }
  }

  Future<void> _loadRoomGiftRanking() async {
    if (!widget.state.backendConnected) return;
    final value =
        await widget.state.backend.roomGiftRanking(roomId: widget.room.id);
    if (!mounted || value?['ok'] != true) return;
    final rawRanking = value?['ranking'];
    final nextTotal =
        int.tryParse(value?['lifetime_total']?.toString() ?? '') ?? 0;
    final nextCompleted = _rocketProgressState(nextTotal)['completed']!.toInt();
    final wasInitialized = _roomGiftRankingInitialized;
    final previouslyObservedCompleted = _lastObservedRocketCompleted;

    setState(() {
      // Lifetime room totals should never move backwards if overlapping API
      // responses return out of order.
      if (nextTotal >= roomGiftLifetimeTotal) {
        roomGiftLifetimeTotal = nextTotal;
      }
      roomGiftRanking = rawRanking is List
          ? rawRanking
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : <Map<String, dynamic>>[];
      _roomGiftRankingInitialized = true;
      if (nextCompleted > _lastObservedRocketCompleted) {
        _lastObservedRocketCompleted = nextCompleted;
      }
    });

    // Do not fire old milestones on initial room load. A shared guard makes
    // concurrent refreshes launch only once per newly reached stage.
    if (wasInitialized && nextCompleted > previouslyObservedCompleted) {
      final reachedLevel =
          nextCompleted.clamp(1, _rocketStageTargets.length).toInt();
      _showRocketLaunch(reachedLevel);
      // Let the launch animation finish before showing the reward chest.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) unawaited(_showRocketRewardChest(reachedLevel));
      }));
    }
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

  Map<String, num> _rocketProgressState(int total) =>
      calculateRocketProgress(total);

  int get _currentRocketLevel {
    final completed =
        _rocketProgressState(roomGiftLifetimeTotal)['completed']!.toInt();
    return completed >= _rocketStageTargets.length
        ? _rocketStageTargets.length
        : completed + 1;
  }

  Future<void> _showRocketPanel() async {
    await _loadRoomGiftRanking();
    if (!mounted) return;
    final progress = _rocketProgressState(roomGiftLifetimeTotal);
    final completed = progress['completed']!.toInt();
    final allComplete = completed >= _rocketStageTargets.length;
    final currentLevel = allComplete ? _rocketStageTargets.length : completed + 1;
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
              color: TinniPalette.brightGold,
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
                        'Rocket $currentLevel/${_rocketStageTargets.length}',
                        style: const TextStyle(
                          color: Color(0xFF50D8FF),
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
                                      ? Color(0xFF50D8FF)
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
                                          ? Color(0xFF50D8FF)
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
                      Expanded(
                        child: Center(
                          child: RoomStealthRocketLogo(
                            size: 132,
                            level: currentLevel,
                          ),
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
                        Color(0xFF50D8FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  allComplete
                      ? '${_rocketStageTargets.length}/${_rocketStageTargets.length} rockets complete'
                      : '${_compactRoomCoins(currentProgress)} / '
                          '${_compactRoomCoins(currentTarget)} • '
                          '${(percent * 100).floor()}%',
                  key: const Key('room-rocket-progress-label'),
                  style: const TextStyle(
                    color: Color(0xFF50D8FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                if (completed > 0) ...<Widget>[
                  const SizedBox(height: 7),
                  const Text(
                    'REWARD CHESTS',
                    style: TextStyle(
                      color: Color(0xFF50D8FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 5,
                      runSpacing: 4,
                      children: List<Widget>.generate(completed, (index) {
                        final level = index + 1;
                        return OutlinedButton.icon(
                          key: Key('room-rocket-reward-chest-$level'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(_showRocketRewardChest(level));
                          },
                          icon: const Icon(Icons.card_giftcard_rounded, size: 14),
                          label: Text('L$level'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF50D8FF),
                            side: BorderSide(
                              color: TinniPalette.brightGold.withValues(alpha: .55),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            minimumSize: const Size(44, 38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: FilledButton.icon(
                    key: const Key('room-rocket-open-full-page'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      unawaited(Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => RocketRoomPage(
                            roomId: widget.room.id,
                            roomName: roomName,
                            roomNumber: widget.room.roomNumber,
                            onlineCount: roomMembers.length,
                            lifetimeTotal: roomGiftLifetimeTotal,
                            ranking: roomGiftRanking,
                            seatMembers: roomMembers,
                            currentUserId: widget.state.userId,
                            backend: widget.state.backend,
                            state: widget.state,
                          ),
                        ),
                      ));
                    },
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Open Rocket Room'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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

  // Touching the Ranking / total chips opens the room ranking page
  // (Vinay, 2026-11-21): this room only, Day / Week / Month, top 99.
  // The old bottom sheet is replaced by the page.
  Future<void> _showRoomGiftRanking() async {
    await _openRoomGiftRanking();
  }

  // Monthly top gifter shown in the header (Vinay, 2026-11-21): the ID
  // disappears the moment the top gifter exits the room, so it only
  // shows while they are among the room members.
  Map<String, dynamic>? get _monthTopGifterInRoom =>
      monthTopGifterInRoom(roomMonthTopGifter, roomMembers);

  Future<void> _openRoomGiftRanking({String initialPeriod = 'day'}) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomGiftRankingScreen(
          roomId: widget.room.id,
          roomName: roomName,
          backend: widget.state.backend,
          initialPeriod: initialPeriod,
        ),
      ),
    );
  }

  Future<void> _loadRoomControls() async {
    if (!widget.state.backendConnected) return;
    final value = await widget.state.backend.roomControls(roomId: widget.room.id);
    if (value == null) return;
    _applyRoomControls(value);
  }

  /// Applies a controls payload to the same state fields
  /// [_loadRoomControls] sets. Shared by the old controls loader and
  /// the combined state loader. The payload must be the controls
  /// endpoint's response shape (with its `ok` field) — the combined
  /// state endpoint embeds it unchanged under `controls`.
  void _applyRoomControls(Map<String, dynamic> value) {
    if (!mounted || value['ok'] != true) return;
    final rawSeatControls = value['seat_controls'];
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
    final rawRequests = value['seat_requests'];
    final rawInvite = value['seat_invite'];
    final nextInvite = rawInvite is Map
        ? Map<String, dynamic>.from(rawInvite)
        : null;
    setState(() {
      roomMicMode = value['mic_mode']?.toString() == 'apply' ? 'apply' : 'free';
      publicScreenEnabled = value['public_screen_enabled'] != false;
      roomVipOnly = int.tryParse(value['vip_only']?.toString() ?? '') ?? 0;
      chatBanned = value['chat_banned'] == true;
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
      } else if (accepted == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join Seat ${seat + 1}')),
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
    _applyRoomSettings(Map<String, dynamic>.from(settings));
  }

  /// Applies a settings map to the same state fields [_loadRoomSettings]
  /// sets (name, seats, lock, theme/background, room DP, PK,
  /// announcement, welcome image). Shared by the old settings loader
  /// and the combined state loader so both paths render identically.
  void _applyRoomSettings(Map<String, dynamic> settings) {
    if (!mounted) return;
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
      final avatarKey = settings['avatar_key']?.toString().trim() ?? '';
      if (avatarKey.isNotEmpty) roomAvatarKey = avatarKey;
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
    if (savedRoomMode != 'live' && cameraPublished && rtc is AgoraRtcAdapter) {
      try {
        await (rtc as AgoraRtcAdapter).setCameraPublished(false);
        if (mounted) {
          setState(() {
            cameraPublished = false;

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
                      : error == 'room_vip_only'
                          ? widget.room.vipOnlyLevel > 0
                              ? 'This room is for VIP${widget.room.vipOnlyLevel}+ members'
                              : 'This room is for VIP members'
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
      candidate = AgoraRtcAdapter(
        apiBase: Uri.parse(BackendApi.origin),
        channelType: 'party',
      );
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
      if (candidate is AgoraRtcAdapter) {
        _bindAgoraEvents(candidate);
      }
      if (!mounted) return;
      setState(() {
        voiceStatus = !voicePermissionGranted
            ? 'Listening • microphone permission needed'
            : candidate is AgoraRtcAdapter
                ? 'Voice/video connected'
                : 'Local voice mode';
      });
    } catch (_) {
      if (candidate is AgoraRtcAdapter) candidate.dispose();
      final fallback = LocalRtcAdapter();
      await fallback.join(widget.room.id, widget.state.userId);
      rtc = fallback;
      if (!mounted) return;
      setState(() => voiceStatus = 'Voice setup required');
    }
  }

  Future<void> _handleLiveGiftEvent(
    Map<String, dynamic> packet, {
    required String senderIdentity,
  }) async {
    if (!mounted || packet['type'] != 'gift') return;
    final eventId = packet['id']?.toString() ?? '';
    if (eventId.isEmpty || _seenGiftEventIds.contains(eventId)) return;
    // Agora account identity is the authenticated DarkVibeX user ID.
    // Do not trust media metadata sent by a client: resolve the event from D1.
    final claimedSender = packet['sender_user_id']?.toString() ?? '';
    if (senderIdentity.isEmpty || claimedSender != senderIdentity) return;
    final verifiedEvents = await widget.state.backend.roomGiftEvents(
      roomId: widget.room.id,
      after: 0,
      eventId: eventId,
    );
    if (!mounted) return;
    Map<String, dynamic>? verified;
    for (final candidate in verifiedEvents) {
      if (candidate['id']?.toString() == eventId &&
          candidate['sender_user_id']?.toString() == senderIdentity) {
        verified = candidate;
        break;
      }
    }
    if (verified == null || !_seenGiftEventIds.add(eventId)) return;
    // Capture the promoted non-null event before entering the async queue
    // callback; Dart cannot preserve nullable promotion across closures.
    final verifiedEvent = verified;
    final receiverId = verifiedEvent['receiver_user_id']?.toString() ?? '';
    if (receiverId.isEmpty) return;
    // Gift combo (Vinay, 2026-11-21): a counted event shows "xN" for
    // everyone in the room, not just the sender.
    final giftCount =
        (int.tryParse(verifiedEvent['count']?.toString() ?? '') ?? 1)
            .clamp(1, 7777);
    final gift = <String, dynamic>{
      'id': verifiedEvent['gift_id']?.toString() ?? '',
      'name': giftCount > 1
          ? '${verifiedEvent['gift_name']?.toString() ?? 'Gift'} x$giftCount'
          : (verifiedEvent['gift_name']?.toString() ?? 'Gift'),
      'emoji': verifiedEvent['emoji']?.toString() ?? '🎁',
      'coin_cost': verifiedEvent['coin_cost'] ?? 0,
      'count': giftCount,
      'video_key': verifiedEvent['video_key']?.toString() ?? '',
      'glb_key': verifiedEvent['glb_key']?.toString() ?? '',
      'svga_key': verifiedEvent['svga_key']?.toString() ?? '',
      'asset_key': verifiedEvent['asset_key']?.toString() ?? '',
    };
    final senderName = verifiedEvent['sender_name']?.toString() ?? 'User';
    final receiverName = verifiedEvent['receiver_name']?.toString() ?? 'User';
    _giftPlaybackQueue = _giftPlaybackQueue.then((_) async {
      if (!mounted) return;
      final videoKey = gift['video_key']?.toString() ?? '';
      final glbKey = gift['glb_key']?.toString() ?? '';
      final svgaKey = gift['svga_key']?.toString() ?? '';
      // Dragon gifts skip the full-screen SVGA dialog (Vinay,
      // 2026-11-22): they fly in the screen centre, then to the DP.
      if (svgaKey.isNotEmpty && _isBigGift(gift) && !_isDragonGift(gift)) {
        await _playGiftSvga(gift, receiverId: receiverId, svgaKey: svgaKey, senderName: senderName);
      } else if (videoKey.isNotEmpty) {
        await _playGiftVideo(gift, receiverId: receiverId, videoKey: videoKey, senderName: senderName);
      } else if (glbKey.isNotEmpty) {
        await _playGiftGlb(gift, receiverId: receiverId, glbKey: glbKey);
      } else {
        _playGiftEffect(gift, receiverId: receiverId, senderId: senderIdentity);
      }
      // Gift ribbon banner (sender's VIP tier, basic for VIP0):
      // shown with the gift display, after any video/GLB dialog.
      _showGiftRibbon(
        event: verifiedEvent,
        senderName: senderName,
        receiverName: receiverName,
        giftName: gift['name']?.toString() ?? 'Gift',
      );
      // Lucky win announcement (Vinay, 2026-11-22): a win on this
      // gift is announced to the room when the gift plays.
      _showLuckyWinAnnouncement(
        verifiedEvent,
        senderName,
        gift['name']?.toString() ?? 'Gift',
        receiverName,
      );
    });
  }

  void _bindAgoraEvents(AgoraRtcAdapter adapter) {
    _unbindAgoraEvents();
    void refreshMedia() {
      if (mounted) setState(() {});
    }
    _rtcMediaListener = refreshMedia;
    adapter.mediaRevisionListenable.addListener(refreshMedia);
    _rtcGiftSubscription = adapter.giftEvents.listen((event) {
      if (event.packet['type'] != 'gift') return;
      unawaited(_handleLiveGiftEvent(
        event.packet,
        senderIdentity: event.senderAccount,
      ));
    });
  }

  void _unbindAgoraEvents() {
    final adapter = rtc;
    final listener = _rtcMediaListener;
    if (adapter is AgoraRtcAdapter && listener != null) {
      adapter.mediaRevisionListenable.removeListener(listener);
    }
    _rtcMediaListener = null;
    final subscription = _rtcGiftSubscription;
    _rtcGiftSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  Future<void> _toggleSpeaker() async {
    final adapter = rtc;
    if (adapter is! AgoraRtcAdapter) return;
    final next = !speakerphoneOn;
    try {
      await adapter.setSpeakerphoneOn(next);
      if (mounted) setState(() => speakerphoneOn = next);
    } catch (_) {}
  }

  Future<void> _toggleCamera() async {
    if (mySeat == null) return;
    final adapter = rtc;
    if (adapter is! AgoraRtcAdapter) {
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera unavailable: $error')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final rocketOverlay = _rocketLaunchOverlay;
    _rocketLaunchOverlay = null;
    if (rocketOverlay != null) {
      rocketOverlay.remove();
      rocketOverlay.dispose();
    }
    roomStateTimer?.cancel();
    arrivalEffectTimer?.cancel();
    giftEffectTimer?.cancel();
    giftRibbonTimer?.cancel();
    _topBannerTimer?.cancel();
    for (final timer in seatReactionTimers.values) {
      timer.cancel();
    }
    seatReactionTimers.clear();
    for (final timer in seatPandaEmoteTimers.values) {
      timer.cancel();
    }
    seatPandaEmoteTimers.clear();
    _silentSpeakingLevels.dispose();
    roomChatController.dispose();
    roomChatScrollController.dispose();
    unawaited(roomMusic.dispose());
    _unbindAgoraEvents();
    unawaited(roomForegroundService.stop());
    roomForegroundServiceStarted = false;
    final current = rtc;
    if (current != null) {
      unawaited(
        current.leave().whenComplete(() {
          if (current is AgoraRtcAdapter) {
            current.dispose();
          } else if (current is LocalRtcAdapter) {
            current.dispose();
          }
        }),
      );
    }
    super.dispose();
  }

  bool _seatMemberIsAdmin(Map<String, dynamic>? member) {
    if (member == null) return false;
    return member['is_admin'] == true || member['is_admin']?.toString() == '1';
  }

  bool _canModerateSeatMember(Map<String, dynamic>? member) {
    if (!isRoomAdmin || member == null) return false;
    final userId = member['user_id']?.toString() ?? '';
    if (userId.isEmpty || userId == widget.state.userId) return false;
    if (isRoomHost) return true;
    if (userId == widget.room.ownerUserId) return false;
    return !_seatMemberIsAdmin(member);
  }

  Future<bool> _leaveMySeat() async {
    final currentSeat = mySeat;
    if (currentSeat == null) return true;

    if (widget.state.backendConnected) {
      final ok = await widget.state.backend.setSeat(
        roomId: widget.room.id,
        userId: widget.state.userId,
        seatIndex: null,
        micMuted: true,
      );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not leave this seat')),
          );
        }
        return false;
      }
    }

    await roomMusic.stopForSeatDown(widget.state.userId);
    if (!muted) {
      try {
        await rtc?.setMicPublished(false);
      } catch (_) {
        // The mic adapter throws when not joined (StateError); a throw
        // here must not abort the seat-down flow (it also backs the
        // admin "Take Seat" path via _takeSeatDirect).
      }
    }
    if (cameraPublished && rtc is AgoraRtcAdapter) {
      await (rtc as AgoraRtcAdapter).setCameraPublished(false);
    }
    if (!mounted) return true;
    setState(() {
      mySeat = null;
      muted = true;
      cameraPublished = false;

    });
    unawaited(_loadRoomMembers());
    unawaited(_loadRoomControls());
    return true;
  }

  Future<void> _showMySeatLeavePanel() async {
    if (mySeat == null || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: TinniPalette.nearBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: TinniPalette.gold),
        ),
        child: InkWell(
          key: const Key('room-self-seat-leave'),
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            Navigator.pop(dialogContext);
            await _leaveMySeat();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 34, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TinniGlowIcon(
                  icon: Icons.keyboard_double_arrow_down_rounded,
                  size: 28,
                  boxSize: 46,
                ),
                SizedBox(height: 10),
                Text(
                  'Leave Seat',
                  style: TextStyle(
                    color: TinniPalette.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendGiftToSeatUser(String receiverId) async {
    // Combined gifts + diamonds + coins (Vinay, 2026-11-21): ONE call
    // carrying the full catalog + the authoritative server wallet balance
    // before showing Gift Box, instead of separate refreshWallet +
    // giftCatalog calls. A stale/default AppState balance must never be
    // presented as the wallet.
    List<Map<String, dynamic>> catalog = <Map<String, dynamic>>[];
    if (widget.state.backendConnected) {
      try {
        final combined =
            await widget.state.backend.giftsCombinedState();
        final rows = combined?['gifts'];
        if (rows is List) {
          catalog = rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
        }
        final wallet = combined?['wallet'];
        if (wallet is Map) {
          final coins = int.tryParse(wallet['coins']?.toString() ?? '');
          if (coins != null && coins != widget.state.coins) {
            widget.state.setCoinBalance(coins);
          }
          final diamonds =
              int.tryParse(wallet['diamonds']?.toString() ?? '');
          if (diamonds != null && diamonds != widget.state.diamonds) {
            widget.state.setDiamondBalance(diamonds);
          }
        }
      } catch (_) {
        // A network drop must not kill the Gift Box — it opens with an
        // empty catalog and the last known balance.
        catalog = <Map<String, dynamic>>[];
      }
    }
    if (!mounted) return;
    List<Map<String, dynamic>> fetchedMembers;
    try {
      fetchedMembers = widget.state.backendConnected
          ? await widget.state.backend.roomMembers(roomId: widget.room.id)
          : roomMembers;
    } catch (_) {
      fetchedMembers = roomMembers;
    }
    if (!mounted) return;
    final availableMembers =
        fetchedMembers.isEmpty ? roomMembers : fetchedMembers;

    final selection = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final sheetHeight = MediaQuery.sizeOf(sheetContext).height * .58;
        var selectedGiftCategory = 'Normal';
        // Gift combo (Vinay, 2026-11-21): how many copies of the gift go to
        // each selected user in one send (1/7/77/177/777/7777).
        var selectedComboCount = 1;
        final selectedReceiverIds = receiverId.trim().isEmpty
            ? <String>{}
            : <String>{receiverId};
        final selectedGiftIds = <String>{};
        final giftOptions = catalog
            .map((gift) => Map<String, dynamic>.from(gift))
            .toList(growable: true);
        final recipients = <Map<String, dynamic>>[
          ...availableMembers.map((row) => Map<String, dynamic>.from(row)),
        ];
        if (receiverId.trim().isNotEmpty &&
            !recipients.any((row) => row['user_id']?.toString() == receiverId)) {
          recipients.insert(0, <String, dynamic>{
            'user_id': receiverId,
            'display_name': receiverId == widget.state.userId
                ? widget.state.displayName
                : 'Selected user',
          });
        }
        if (!recipients.any(
          (row) => row['user_id']?.toString() == widget.state.userId,
        )) {
          recipients.insert(0, <String, dynamic>{
            'user_id': widget.state.userId,
            'display_name': widget.state.displayName,
            'avatar_key': widget.state.avatarKey,
            'seat_index': mySeat,
          });
        }

        String giftSelectionKey(Map<String, dynamic> item) {
          final id = item['id']?.toString().trim() ?? '';
          if (id.isNotEmpty) return id;
          return (item['name'] ?? 'Gift').toString() +
              ':' +
              (item['coin_cost'] ?? 0).toString();
        }

        int giftCost(Map<String, dynamic> item) =>
            int.tryParse(item['coin_cost']?.toString() ?? '') ?? 0;

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final visibleGifts = giftOptions.where((item) {
              final rawCategory = (item['category'] ??
                      item['gift_category'] ??
                      item['type'] ??
                      '')
                  .toString()
                  .toLowerCase();
              final category = rawCategory
                  .replaceAll('-', '')
                  .replaceAll('_', '')
                  .replaceAll(' ', '');
              switch (selectedGiftCategory) {
                case 'Lucky':
                  return category == 'lucky';
                case 'CP':
                  return category == 'cp' || category.contains('couple');
                case 'Country':
                  return category == 'country';
                case 'Luxury':
                  return category == 'luxury';
                case 'Backpack':
                  return category == 'backpack';
                case 'Normal':
                default:
                  return category.isEmpty ||
                      category == 'normal' ||
                      category == 'gift' ||
                      !const <String>{
                        'lucky',
                        'cp',
                        'couple',
                        'country',
                        'luxury',
                        'backpack',
                      }.contains(category);
              }
            }).toList(growable: false);

            final selectedGifts = giftOptions
                .where((item) => selectedGiftIds.contains(giftSelectionKey(item)))
                .toList(growable: false);
            final totalCoins = selectedGifts.fold<int>(
                  0,
                  (total, item) => total + giftCost(item),
                ) *
                selectedReceiverIds.length *
                selectedComboCount;

            // Select All (Vinay, 2026-11-21): every seat user's DP,
            // including yourself (you are already in the recipients list).
            final allRecipientIds = recipients
                .map((row) => row['user_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toSet();
            final allRecipientsSelected = allRecipientIds.isNotEmpty &&
                allRecipientIds.every(selectedReceiverIds.contains);
            // Recipient DPs (Vinay, 2026-11-21): only 7 DPs show in one
            // row, at the biggest size that still fits 7 across. The rest
            // are reached by sliding right. The DP stays small but big
            // enough to be visible.
            final recipientItemWidth =
                ((MediaQuery.sizeOf(sheetContext).width - 30) / 7)
                    .clamp(44.0, 64.0);
            final recipientAvatarSize = recipientItemWidth - 6;

            return Container(
              height: sheetHeight,
              decoration: const BoxDecoration(
                color: Color(0xFF10192D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9, bottom: 5),
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4D7E1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 7, 14, 5),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gift',
                            style: TextStyle(
                              color: Color(0xFFB77BE5),
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                  SizedBox(
                    height: 47,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          for (final category in const [
                            'Normal',
                            'Lucky',
                            'CP',
                            'Country',
                            'Luxury',
                            'Backpack',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                key: Key('room-gift-category-' + category),
                                label: Text(category),
                                selected: selectedGiftCategory == category,
                                onSelected: (_) => setSheetState(
                                  () => selectedGiftCategory = category,
                                ),
                                showCheckmark: true,
                                checkmarkColor: const Color(0xFFD3DEFA),
                                selectedColor: const Color(0xFF293D60),
                                backgroundColor: const Color(0xFF1A263B),
                                side: BorderSide(
                                  color: selectedGiftCategory == category
                                      ? const Color(0xFF7598D6)
                                      : const Color(0xFF43516B),
                                  width: selectedGiftCategory == category
                                      ? 1.4
                                      : 1,
                                ),
                                labelStyle: TextStyle(
                                  color: selectedGiftCategory == category
                                      ? const Color(0xFFB3C6EC)
                                      : const Color(0xFFE8EAF2),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 2),
                    child: Row(
                      children: [
                        const Text(
                          'To',
                          style: TextStyle(
                            color: Color(0xFFC4C9D5),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          key: const Key('room-gift-select-all'),
                          onPressed: () => setSheetState(() {
                            // Select All (Vinay, 2026-11-21): one tap selects
                            // every seat user's DP, including yourself.
                            // Tapping again clears the selection.
                            if (allRecipientsSelected) {
                              selectedReceiverIds.clear();
                            } else {
                              selectedReceiverIds.addAll(allRecipientIds);
                            }
                          }),
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            allRecipientsSelected
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(
                              color: Color(0xFFB77BE5),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 79,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(15, 5, 15, 4),
                      children: [
                        for (final person in recipients)
                          Builder(
                            builder: (context) {
                              final id =
                                  person['user_id']?.toString().trim() ?? '';
                              if (id.isEmpty) return const SizedBox.shrink();
                              final name = (person['display_name'] ??
                                      person['name'] ??
                                      person['nickname'] ??
                                      'User')
                                  .toString();
                              final avatar =
                                  person['avatar_key']?.toString() ?? '';
                              final chosen = selectedReceiverIds.contains(id);
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setSheetState(() {
                                  if (chosen) {
                                    selectedReceiverIds.remove(id);
                                  } else {
                                    selectedReceiverIds.add(id);
                                  }
                                }),
                                child: SizedBox(
                                  width: recipientItemWidth,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: recipientAvatarSize,
                                        height: recipientAvatarSize,
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: chosen
                                                ? const Color(0xFFB77BE5)
                                                : const Color(0xFF586681),
                                            width: chosen ? 2.5 : 1,
                                          ),
                                          boxShadow: chosen
                                              ? const [
                                                  BoxShadow(
                                                    color: Color(0x554B2B87),
                                                    blurRadius: 8,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: ClipOval(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ColoredBox(
                                                color: const Color(0xFF202D45),
                                                child: avatar.isEmpty
                                                    ? const Icon(
                                                        Icons.person_rounded,
                                                        color: Colors.white70,
                                                        size: 28,
                                                      )
                                                    : Image.network(
                                                        widget.state.backend
                                                            .fileUrl(avatar),
                                                        headers: widget.state
                                                            .backend.fileHeaders,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) =>
                                                            const Icon(
                                                          Icons.person_rounded,
                                                          color: Colors.white70,
                                                          size: 28,
                                                        ),
                                                      ),
                                              ),
                                              if (chosen)
                                                const ColoredBox(
                                                  color: Color(0x55100D20),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.check_rounded,
                                                      size: 29,
                                                      color: Color(0xFF50D8FF),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: chosen
                                              ? const Color(0xFFE2C6FF)
                                              : const Color(0xFFC7CBDA),
                                          fontSize: 10,
                                          fontWeight: chosen
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibleGifts.isEmpty
                        ? Center(
                            child: Text(
                              catalog.isEmpty
                                  ? 'No gifts available'
                                  : 'No ' +
                                      selectedGiftCategory.toLowerCase() +
                                      ' gifts available',
                              style: const TextStyle(
                                color: Color(0xFFC7CBDA),
                                fontSize: 13,
                              ),
                            ),
                          )
                        : GridView.builder(
                            key: const Key('room-gift-selection-grid'),
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 5,
                              childAspectRatio: .72,
                            ),
                            itemCount: visibleGifts.length,
                            itemBuilder: (context, index) {
                              final item = visibleGifts[index];
                              final id = giftSelectionKey(item);
                              final chosen = selectedGiftIds.contains(id);
                              final name =
                                  item['name']?.toString() ?? 'Gift';
                              final emoji =
                                  item['emoji']?.toString() ?? '🎁';
                              final assetKey =
                                  item['asset_key']?.toString().trim() ?? '';
                              final videoKey =
                                  item['video_key']?.toString().trim() ?? '';
                              final glbKey =
                                  item['glb_key']?.toString().trim() ?? '';
                              final cost = giftCost(item);
                              final vipLevel = int.tryParse(
                                    item['vip_level']?.toString() ?? '',
                                  ) ??
                                  0;

                              return InkWell(
                                key: Key('room-gift-card-' + id),
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setSheetState(() {
                                  if (chosen) {
                                    selectedGiftIds.remove(id);
                                  } else {
                                    selectedGiftIds.add(id);
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 130),
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    // Keep gift artwork visually free of the
                                    // oversized square card border. Selection
                                    // is indicated by the check badge instead.
                                    color: chosen
                                        ? const Color(0x1FB77BE5)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned.fill(
                                              child: Center(
                                                child: SizedBox(
                                                  width: 36,
                                                  height: 36,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      8,
                                                    ),
                                                    child: GiftMediaPreview(
                                                      backend:
                                                          widget.state.backend,
                                                      videoKey: videoKey,
                                                      assetKey: assetKey,
                                                      glbKey: glbKey,
                                                      emoji: emoji,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (vipLevel > 0)
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFD8B65B,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'V' + vipLevel.toString(),
                                                    style: const TextStyle(
                                                      color: Color(0xFF1A1D26),
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (chosen)
                                              const Positioned(
                                                top: 0,
                                                right: 0,
                                                child: CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor:
                                                      Color(0xFFB77BE5),
                                                  child: Icon(
                                                    Icons.check_rounded,
                                                    size: 13,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFF0F0F6),
                                          fontSize: 9,
                                          height: 1.05,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        cost.toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFC4B078),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Gift combo (Vinay, 2026-11-21): the copy count for the
                  // gift, at the bottom right of the gift box. The number
                  // is how many copies go to EACH selected user in one
                  // send (4 users x combo 7 = 28 sends in one go).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 4, 15, 2),
                    child: Row(
                      children: [
                        const Text(
                          'Combo',
                          style: TextStyle(
                            color: Color(0xFFC4C9D5),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        for (final count in const <int>[1, 7, 77, 177, 777, 7777])
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: ChoiceChip(
                              key: Key('room-gift-combo-$count'),
                              label: Text(count.toString()),
                              selected: selectedComboCount == count,
                              onSelected: (_) => setSheetState(
                                () => selectedComboCount = count,
                              ),
                              showCheckmark: false,
                              selectedColor: const Color(0xFFB77BE5),
                              backgroundColor: const Color(0xFF1A263B),
                              side: BorderSide(
                                color: selectedComboCount == count
                                    ? const Color(0xFFB77BE5)
                                    : const Color(0xFF43516B),
                                width: 1,
                              ),
                              labelStyle: TextStyle(
                                color: selectedComboCount == count
                                    ? const Color(0xFF1A1022)
                                    : const Color(0xFFE8EAF2),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF10192D),
                      border: Border(
                        top: BorderSide(color: Color(0xFF28364E), width: 1),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 9, 14, 9),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              color: Color(0xFF50D8FF),
                              size: 21,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Column(
                                key: const Key('room-gift-wallet-summary'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Wallet Coins ' +
                                        widget.state.coins.toString(),
                                    key: const Key('room-gift-wallet-coins'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF50D8FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Total Coins ' + _compactRoomCoins(totalCoins),
                                    key: const Key('room-gift-total-coins'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFC4C9D5),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 44,
                              child: FilledButton.icon(
                                key: const Key('room-gift-send-button'),
                                onPressed: selectedGifts.isEmpty ||
                                        selectedReceiverIds.isEmpty
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(
                                          <String, dynamic>{
                                            '_selected_receiver_ids':
                                                selectedReceiverIds.toList(),
                                            '_selected_gifts': selectedGifts
                                                .map(
                                                  (gift) =>
                                                      Map<String, dynamic>.from(
                                                    gift,
                                                  ),
                                                )
                                                .toList(growable: false),
                                            '_selected_combo_count':
                                                selectedComboCount,
                                          },
                                        ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF44364F),
                                  disabledBackgroundColor:
                                      const Color(0xFF272536),
                                  foregroundColor:
                                      const Color(0xFFD8DCE8),
                                  disabledForegroundColor:
                                      const Color(0xFF777D8D),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 23,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                ),
                                label: const Text('Send'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || selection == null) return;
    final recipientIds = (selection['_selected_receiver_ids'] as List?)
            ?.map((id) => id.toString())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false) ??
        <String>[];
    final selectedGifts = (selection['_selected_gifts'] as List?)
            ?.whereType<Map>()
            .map((gift) => Map<String, dynamic>.from(gift))
            .toList(growable: false) ??
        <Map<String, dynamic>>[];

    if (recipientIds.isEmpty || selectedGifts.isEmpty) return;
    // Gift combo (Vinay, 2026-11-21): the combo number is how many copies
    // of the gift go to EACH selected user in one send (4 users x combo 7
    // = 28 sends in one go). The total is gift cost x users x combo.
    final comboCount = (int.tryParse(
              selection['_selected_combo_count']?.toString() ?? '',
            ) ??
            1)
        .clamp(1, 7777);
    // Bulk send (Vinay, 2026-11-21): the gift goes to every selected
    // recipient at once ONLY if the wallet can afford the whole total.
    // Never start a bulk send the wallet cannot cover. The total uses
    // the catalog cost, which is the most the server can charge (the
    // VIP discount can only lower it), so this check is conservative.
    final totalCost = selectedGifts.fold<int>(
          0,
          (total, gift) =>
              total + (int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0),
        ) *
        recipientIds.length *
        comboCount;
    if (widget.state.coins < totalCost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough coins — need $totalCost, you have ${widget.state.coins}.',
          ),
        ),
      );
      return;
    }
    var sentCopies = 0;
    // Split send (Vinay, 2026-11-22): fly-effect gifts (no video, no
    // GLB) do NOT play one effect per recipient here. The split effect
    // for the whole batch plays once below: one gift in the centre that
    // splits to every receiver's DP. Video/GLB gifts keep their
    // per-recipient dialog (a full-screen dialog cannot split).
    final flyGifts = <Map<String, dynamic>>[];
    for (final gift in selectedGifts) {
      final isFlyGift =
          (gift['video_key']?.toString().trim() ?? '').isEmpty &&
              (gift['glb_key']?.toString().trim() ?? '').isEmpty;
      for (final id in recipientIds) {
        if (!mounted) return;
        final sent = await _sendGiftByDefinition(
          gift,
          id,
          count: comboCount,
          playEffect: !isFlyGift,
        );
        if (!sent) return;
        sentCopies += comboCount;
      }
      if (isFlyGift) flyGifts.add(gift);
    }
    if (mounted && flyGifts.isNotEmpty && sentCopies > 0) {
      for (final gift in flyGifts) {
        final displayGift = Map<String, dynamic>.from(gift);
        if (comboCount > 1) {
          displayGift['name'] =
              '${gift['name'] ?? 'Gift'} x$comboCount';
          displayGift['count'] = comboCount;
        }
        _playGiftEffect(
          displayGift,
          receiverId: recipientIds.first,
          receiverIds: recipientIds,
          senderId: widget.state.userId,
        );
      }
      final firstReceiver = membersBySeat.values.firstWhere(
        (member) => member['user_id']?.toString() == recipientIds.first,
        orElse: () => <String, dynamic>{},
      );
      final firstReceiverName = (firstReceiver['display_name'] ??
              firstReceiver['name'] ??
              firstReceiver['nickname'] ??
              (recipientIds.first == widget.state.userId
                  ? widget.state.displayName
                  : recipientIds.first))
          .toString();
      final firstGift = flyGifts.first;
      _showGiftRibbon(
        event: <String, dynamic>{
          'gift_name': comboCount > 1
              ? '${firstGift['name'] ?? 'Gift'} x$comboCount'
              : (firstGift['name'] ?? 'Gift').toString(),
        },
        senderName: widget.state.displayName,
        receiverName: firstReceiverName,
        giftName: comboCount > 1
            ? '${firstGift['name'] ?? 'Gift'} x$comboCount'
            : (firstGift['name'] ?? 'Gift').toString(),
      );
    }
    // The whole bulk send landed: show the combo button so the same gift
    // can be sent again to the same users. It hides by itself after 5s
    // without a touch, and every touch restarts the 5s timer.
    if (mounted) {
      setState(() {
        _giftComboGifts = selectedGifts
            .map((gift) => Map<String, dynamic>.from(gift))
            .toList(growable: false);
        _giftComboRecipientIds = List<String>.from(recipientIds);
        _giftComboCount = comboCount;
        _giftComboTotal = sentCopies;
      });
      _startGiftComboTimer();
    }
  }

  /// Room user tap (Vinay, 2026-11-20): like other live apps, tapping a
  /// user in the room opens their profile card first; my own opens my
  /// main profile page (the card popup never shows for myself).
  Future<void> _openRoomUserProfile(
    String userId,
    String? displayName,
    String? avatarKey,
  ) async {
    if (userId.isEmpty) return;
    if (userId == widget.state.userId) {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            state: widget.state,
            userId: userId,
          ),
        ),
      );
      return;
    }
    await _showSeatMemberProfile(
      <String, dynamic>{
        'user_id': userId,
        'display_name': displayName ?? '',
        'avatar_key': avatarKey ?? '',
      },
      null,
    );
  }

  Future<void> _showSeatMemberProfile(
    Map<String, dynamic> member,
    int? seat,
  ) async {
    final userId = member['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    if (userId == widget.state.userId) {
      if (seat != null) {
        await _showMySeatLeavePanel();
      }
      return;
    }

    final rawName = member['display_name']?.toString().trim();
    final fallbackName =
        rawName == null || rawName.isEmpty ? 'User' : rawName;

    final values = await Future.wait<Object?>([
      widget.state.backend.userProfile(
        userId: userId,
        recordVisit: false,
      ),
      widget.state.backend.socialStats(userId: userId),
      widget.state.backend.idLevelStatus(userId: userId),
      widget.state.backend.medals(userId: userId),
      widget.state.backend.cpState(userId: userId),
      widget.state.backend.followStatus(
        userId: widget.state.userId,
        targetUserId: userId,
      ),
      widget.state.backend.friends(userId: widget.state.userId),
    ]);
    if (!mounted) return;

    final profileResponse = values[0] is Map ? values[0] as Map : null;
    final rawUser = profileResponse?['user'];
    final profile = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : <String, dynamic>{
            'id': userId,
            'display_name': fallbackName,
            'avatar_key': member['avatar_key'],
          };
    final statsResponse = values[1] is Map ? values[1] as Map : null;
    final stats = statsResponse?['stats'] is Map
        ? Map<String, dynamic>.from(statsResponse!['stats'] as Map)
        : <String, dynamic>{};
    final levelResponse = values[2] is Map ? values[2] as Map : null;
    final idLevel = levelResponse?['level'] is Map
        ? Map<String, dynamic>.from(levelResponse!['level'] as Map)
        : <String, dynamic>{};
    final medals = values[3] is List
        ? (values[3] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    final cpResponse = values[4] is Map ? values[4] as Map : null;
    final rawCp = cpResponse?['cp'];
    final cp = rawCp is Map ? Map<String, dynamic>.from(rawCp) : null;
    var following = values[5] == true;
    final friends = values[6] is List ? values[6] as List : const [];
    var mutual = friends.whereType<Map>().any(
          (row) => row['id']?.toString() == userId,
        );
    var followersCount =
        int.tryParse(stats['followers_count']?.toString() ?? '') ?? 0;

    final targetIsOwner = userId == widget.room.ownerUserId;
    final targetIsAdmin = _seatMemberIsAdmin(member);
    final canModerate = _canModerateSeatMember(member);
    final roomMuted = seat != null && roomMutedSeats.contains(seat);
    final chatIsBanned =
        member['chat_banned'] == true || member['chat_banned']?.toString() == '1';

    final name = profile['display_name']?.toString().trim().isNotEmpty == true
        ? profile['display_name']!.toString().trim()
        : fallbackName;
    final avatar = profile['avatar_key']?.toString() ?? '';
    final shownId = formatPublicUserId(profile['public_id']);
    final country = profile['country_name']?.toString().trim() ?? '';
    final flag = profile['flag_emoji']?.toString().trim() ?? '';
    final gender = profile['gender']?.toString().trim().toLowerCase() ?? '';
    final bio = profile['bio']?.toString().trim() ?? '';
    final level = int.tryParse(idLevel['level']?.toString() ?? '') ?? 0;
    final activeVipLevel = int.tryParse(profile['active_vip_level']?.toString() ?? '') ?? 0;
    final rawVipVisuals = profile['vip_visuals'];
    final vipVisuals = rawVipVisuals is Map
        ? Map<String, dynamic>.from(rawVipVisuals)
        : <String, dynamic>{};
    final vipFrame = vipVisuals['frame'] is Map
        ? Map<String, dynamic>.from(vipVisuals['frame'] as Map)
        : <String, dynamic>{};
    final vipMiniProfile = vipVisuals['mini_profile_panel'] is Map
        ? Map<String, dynamic>.from(vipVisuals['mini_profile_panel'] as Map)
        : <String, dynamic>{};
    final vipMiniProfileAssetKey =
        vipMiniProfile['asset_key']?.toString().trim() ?? '';
    final vipProfileCardAnim = vipVisuals['profile_card_anim'] is Map
        ? Map<String, dynamic>.from(vipVisuals['profile_card_anim'] as Map)
        : <String, dynamic>{};
    final profileCardAnimVideoKey =
        vipProfileCardAnim['video_key']?.toString().trim() ?? '';
    // The level's card background (video VIP4-18, still pic VIP1-3)
    // sits BEHIND the text — the cat stays behind the text (Vinay,
    // 2026-11-20) — and the card covers 35% of the room screen.
    final hasCardBackground = activeVipLevel > 0;
    const vipVisualLabels = <String, String>{
      'frame': 'Profile frame',
      'chat_box': 'VIP chat box',
      'entry_effect': 'Entry ribbon',
      'vip_banner': 'VIP banner',
      'vehicle_entry': 'Vehicle entry',
      'mini_profile_panel': 'Mini profile',
    };
    final visibleVipVisuals = vipVisualLabels.entries
        .where((entry) => vipVisuals[entry.key] is Map)
        .toList(growable: false);

    String cpPartnerId = '';
    String cpPartnerAvatar = '';
    if (cp?['state']?.toString() == 'active') {
      final a = cp?['user_a']?.toString() ?? '';
      final b = cp?['user_b']?.toString() ?? '';
      if (a == userId) {
        cpPartnerId = b;
        cpPartnerAvatar = cp?['user_b_avatar_key']?.toString() ?? '';
      } else {
        cpPartnerId = a;
        cpPartnerAvatar = cp?['user_a_avatar_key']?.toString() ?? '';
      }
    }

    ImageProvider<Object>? avatarProvider(String value) {
      if (value.trim().isEmpty) return null;
      return NetworkImage(
        widget.state.backend.fileUrl(value),
        headers: widget.state.backend.fileHeaders,
      );
    }

    void openFullProfile(String target) {
      if (target.isEmpty) return;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            state: widget.state,
            userId: target,
          ),
        ),
      );
    }

    Future<void> openModeration() async {
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: TinniPalette.nearBlack,
        builder: (actionContext) => SafeArea(
          child: Wrap(
            children: [
              if (isRoomHost && !targetIsOwner)
                ListTile(
                  leading: Icon(
                    targetIsAdmin
                        ? Icons.remove_moderator_rounded
                        : Icons.admin_panel_settings_rounded,
                  ),
                  title: Text(targetIsAdmin ? 'Remove Admin' : 'Set Admin'),
                  onTap: () async {
                    Navigator.pop(actionContext);
                    await _setRoomAdmin(
                      userId,
                      admin: !targetIsAdmin,
                    );
                  },
                ),
              if (canModerate && seat != null)
                ListTile(
                  enabled: !VipPolicy.hasAntiMute(
                    activeVipLevel,
                    active: activeVipLevel > 0,
                  ),
                  leading: Icon(
                    roomMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                  ),
                  title: Text(roomMuted ? 'Unmute' : 'Mute'),
                  subtitle: VipPolicy.hasAntiMute(
                    activeVipLevel,
                    active: activeVipLevel > 0,
                  )
                      ? const Text(
                          'VIP13 Anti-Mute — this member cannot be muted',
                        )
                      : null,
                  onTap: VipPolicy.hasAntiMute(
                    activeVipLevel,
                    active: activeVipLevel > 0,
                  )
                      ? null
                      : () async {
                          Navigator.pop(actionContext);
                          final result =
                              await widget.state.backend.setRoomControl(
                            roomId: widget.room.id,
                            userId: widget.state.userId,
                            action: 'seat_mute',
                            seatIndex: seat,
                            muted: !roomMuted,
                          );
                          if (result?['ok'] == true) {
                            await _loadRoomMembers();
                            await _loadRoomControls();
                          } else if (result?['error'] == 'vip_anti_mute') {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This member has Anti-Mute (VIP13+)',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                ),
              if (canModerate && seat != null)
                ListTile(
                  leading: const Icon(
                    Icons.airline_seat_recline_normal_rounded,
                  ),
                  title: const Text('Seat down'),
                  onTap: () async {
                    Navigator.pop(actionContext);
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
                  },
                ),
              if (canModerate)
                ListTile(
                  leading: Icon(
                    chatIsBanned
                        ? Icons.chat_rounded
                        : Icons.comments_disabled_rounded,
                  ),
                  title: Text(chatIsBanned ? 'Chat Unban' : 'Chat Ban'),
                  onTap: () async {
                    Navigator.pop(actionContext);
                    await _setChatBan(userId, !chatIsBanned);
                  },
                ),
              if (canModerate)
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Kick'),
                  onTap: () async {
                    Navigator.pop(actionContext);
                    await _removeRoomMember(userId);
                  },
                ),
              if (canModerate)
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('Block'),
                  subtitle: const Text('Remove and block from this room'),
                  onTap: () async {
                    Navigator.pop(actionContext);
                    await _removeRoomMember(userId, ban: true);
                  },
                ),
              if (!isRoomHost && !canModerate)
                const ListTile(
                  leading: Icon(Icons.more_horiz_rounded),
                  title: Text('No room controls available'),
                ),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          Future<void> toggleFollow() async {
            final next = !following;
            final ok = await widget.state.backend.setUserFollow(
              userId: widget.state.userId,
              targetUserId: userId,
              follow: next,
            );
            if (!ok) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not update follow')),
                );
              }
              return;
            }
            if (!sheetContext.mounted) return;
            final newFriends = await widget.state.backend.friends(
              userId: widget.state.userId,
            );
            if (!sheetContext.mounted) return;
            refresh(() {
              following = next;
              mutual = newFriends.any(
                (row) => row['id']?.toString() == userId,
              );
              followersCount =
                  (followersCount + (next ? 1 : -1))
                      .clamp(0, 1 << 31)
                      .toInt();
            });
          }

          final followLabel = mutual
              ? 'Mutual Friend'
              : following
                  ? 'Followed'
                  : 'Follow';

          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (hasCardBackground)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: ProfileCardAnimBackground.forVipLevel(
                          level: activeVipLevel,
                          videoKey: profileCardAnimVideoKey,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  GestureDetector(
                    // Tapping the card itself opens the user's main
                    // profile page (Vinay, 2026-11-20). The buttons
                    // inside (Chat, Give Gifts) keep their own taps;
                    // Follow / More / Mention and the DP above the card
                    // are Positioned outside this container, and the DP
                    // already opens the full profile too.
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Future<void>.delayed(
                        Duration.zero,
                        () => openFullProfile(userId),
                      );
                    },
                    child: Container(
                      key: Key('room-seat-profile-card-$userId'),
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.sizeOf(sheetContext).height * .35,
                    ),
                    decoration: BoxDecoration(
                      color: hasCardBackground
                          ? Colors.transparent
                          : Colors.white,
                      image: hasCardBackground ||
                              vipMiniProfileAssetKey.isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(
                                widget.state.backend.fileUrl(vipMiniProfileAssetKey),
                                headers: widget.state.backend.fileHeaders,
                              ),
                              fit: BoxFit.cover,
                              opacity: 0.16,
                            ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 62, 16, 16),
                        child: Column(
                          children: [
                            VipNameText(
                              name: name,
                              vipLevel: activeVipLevel,
                              style: TextStyle(
                                color: hasCardBackground
                                    ? const Color(0xFFE8C882)
                                    : Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 5,
                              children: [
                                if (gender == 'male' || gender == 'female')
                                  Icon(
                                    gender == 'male'
                                        ? Icons.male_rounded
                                        : Icons.female_rounded,
                                    size: 20,
                                    color: gender == 'male'
                                        ? const Color(0xFF4789E7)
                                        : const Color(0xFFE868A7),
                                  ),
                                Text(
                                  'ID $shownId',
                                  style: TextStyle(
                                    color: hasCardBackground
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (activeVipLevel > 0)
                                  VipTagImage(
                                    vipLevel: activeVipLevel,
                                    fontSize: 12,
                                  ),
                                Text(
                                  '|',
                                  style: TextStyle(
                                    color: hasCardBackground
                                        ? Colors.white30
                                        : Colors.black26,
                                  ),
                                ),
                                Text(
                                  '$followersCount followers',
                                  style: TextStyle(
                                    color: hasCardBackground
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                if (country.isNotEmpty) ...[
                                  Text(
                                    '|',
                                    style: TextStyle(
                                      color: hasCardBackground
                                          ? Colors.white30
                                          : Colors.black26,
                                    ),
                                  ),
                                  Text(
                                    flag.isEmpty ? country : '$flag $country',
                                    style: TextStyle(
                                      color: hasCardBackground
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E8E55),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF1D15F),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'LV.$level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (activeVipLevel > 0 && visibleVipVisuals.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEAF5FF), Color(0xFFF1E9FF)],
                                  ),
                                  border: Border.all(color: const Color(0xFF9BA8F4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'VIP $activeVipLevel COLLECTION',
                                      style: const TextStyle(
                                        color: Color(0xFF4D56A5),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final visualEntry in visibleVipVisuals)
                                          Builder(builder: (_) {
                                            final visual = Map<String, dynamic>.from(
                                              vipVisuals[visualEntry.key] as Map,
                                            );
                                            return SizedBox(
                                              width: 88,
                                              child: Column(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(9),
                                                    child: SizedBox(
                                                      width: 46,
                                                      height: 42,
                                                      child: GiftMediaPreview(
                                                        backend: widget.state.backend,
                                                        videoKey: visual['video_key']?.toString() ?? '',
                                                        assetKey: visual['asset_key']?.toString() ?? '',
                                                        glbKey: visual['glb_key']?.toString() ?? '',
                                                        emoji: '✨',
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    visualEntry.value,
                                                    maxLines: 2,
                                                    textAlign: TextAlign.center,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFF3D427A),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  Text(
                                                    visual['name']?.toString() ?? '',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xFF646A91),
                                                      fontSize: 8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (medals.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 42,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: medals.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, index) =>
                                      ProfileMedalChip(
                                    medal: medals[index],
                                  ),
                                ),
                              ),
                            ],
                            if (bio.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: hasCardBackground
                                      ? Colors.white70
                                      : Colors.black54,
                                  height: 1.3,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ConversationScreen(
                                            state: widget.state,
                                            otherUserId: userId,
                                            otherName: name,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                    ),
                                    label: const Text('Chat'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size.fromHeight(48),
                                      foregroundColor: hasCardBackground
                                          ? Colors.white
                                          : Colors.black87,
                                      side: BorderSide(
                                        color: hasCardBackground
                                            ? Colors.white54
                                            : const Color(0xFFD7D7D7),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      unawaited(
                                        _sendGiftToSeatUser(userId),
                                      );
                                    },
                                    child: Container(
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF26D5E8),
                                            Color(0xFFB977F4),
                                          ],
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.card_giftcard_rounded,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 7),
                                          Text(
                                            'Give Gifts',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 8,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'More',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Future<void>.delayed(
                              Duration.zero,
                              openModeration,
                            );
                          },
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: hasCardBackground
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mention in room',
                          onPressed: () {
                            final mention = '@$name ';
                            final current = roomChatController.text;
                            roomChatController.text = mention + current;
                            roomChatController.selection =
                                TextSelection.collapsed(
                              offset: roomChatController.text.length,
                            );
                            Navigator.pop(sheetContext);
                          },
                          icon: Icon(
                            Icons.alternate_email_rounded,
                            color: hasCardBackground
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 13,
                    right: 16,
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: toggleFollow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: hasCardBackground
                              ? Colors.white
                              : Colors.black87,
                          side: BorderSide(
                            color: hasCardBackground
                                ? Colors.white54
                                : const Color(0xFFD6D6D6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          followLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -48,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: cpPartnerId.isEmpty ? 92 : 136,
                        height: 96,
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            if (cpPartnerId.isNotEmpty)
                              Positioned(
                                left: 66,
                                bottom: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    Future<void>.delayed(
                                      Duration.zero,
                                      () =>
                                          openFullProfile(cpPartnerId),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundColor:
                                        const Color(0xFFE8E8E8),
                                    backgroundImage:
                                        avatarProvider(cpPartnerAvatar),
                                    child: cpPartnerAvatar.isEmpty
                                        ? const Icon(
                                            Icons.favorite_rounded,
                                            color: Color(0xFFE868A7),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            GestureDetector(
                              key: Key('room-seat-profile-dp-$userId'),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Future<void>.delayed(
                                  Duration.zero,
                                  () => openFullProfile(userId),
                                );
                              },
                              child: VipAnimatedFrame.auto(
                                // Auto-sizing: reads the sheet avatar size
                                // at runtime (88px box). Falls back to the
                                // level's animal frame still when the
                                // profile has no frame configured.
                                enabled: (activeVipLevel > 0 && vipFrame.isNotEmpty) ||
                                    vipFrameStillUrlForVipLevel(activeVipLevel) != null,
                                level: activeVipLevel > 0 ? activeVipLevel : level,
                                styleId: vipFrame['id']?.toString(),
                                assetUrl: (vipFrame['asset_key']?.toString().trim().isNotEmpty == true)
                                    ? resolveVipVisualAssetUrl(
                                        vipFrame['asset_key'].toString(),
                                        widget.state.backend.fileUrl,
                                      )
                                    : vipFrameStillUrlForVipLevel(activeVipLevel),
                                // VAP alpha-video: only when the frame
                                // shown IS the animal frame (custom frames
                                // have no VAP video and show the still).
                                videoUrl: vipFrameVapUrlForDisplay(
                                  vipFrame['asset_key']?.toString(),
                                  activeVipLevel,
                                ),
                                assetHeaders: widget.state.backend.fileHeaders,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF6D78E8),
                                      width: 2.5,
                                    ),
                                    color: Colors.white,
                                  ),
                                  child: CircleAvatar(
                                    radius: 42,
                                    backgroundColor:
                                        const Color(0xFFE8E8E8),
                                    backgroundImage:
                                        avatarProvider(avatar),
                                    child: avatar.isEmpty
                                        ? Text(
                                            name.isEmpty
                                                ? '?'
                                                : name
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFF6B3E8D),
                                              fontSize: 27,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Future<bool> _takeSeatDirect(int seat) async {
    if (widget.state.backendConnected) {
      final result = await widget.state.backend.setSeatResult(
        roomId: widget.room.id,
        userId: widget.state.userId,
        seatIndex: seat,
        micMuted: true,
      );
      if (result?['ok'] != true) {
        if (mounted) {
          final error = result?['error']?.toString() ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error == 'seat_request_required'
                    ? 'This seat needs the owner’s approval — send a seat request from the seat menu.'
                    : error == 'seat_locked'
                        ? 'This seat is locked.'
                        : 'Seat is not available',
              ),
            ),
          );
        }
        return false;
      }
    }
    if (!mounted) return true;
    setState(() {
      mySeat = seat;
      muted = true;
    });
    unawaited(_loadRoomMembers());
    unawaited(_loadRoomControls());
    return true;
  }

  Future<void> _handleUserSeatTap(int seat) async {
    if (lockedSeats.contains(seat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat ${seat + 1} is locked')),
      );
      return;
    }
    if (membersBySeat.containsKey(seat)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat ${seat + 1} is occupied')),
      );
      return;
    }
    if (mySeat != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave your current seat first')),
      );
      return;
    }

    if (roomMicMode == 'apply' &&
        !isRoomAdmin &&
        widget.state.backendConnected) {
      final result = await widget.state.backend.requestRoomSeat(
        roomId: widget.room.id,
        userId: widget.state.userId,
        seatIndex: seat,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['ok'] == true
                ? 'Mic request sent for Seat ${seat + 1}'
                : 'Mic request could not be sent',
          ),
        ),
      );
      return;
    }

    await _takeSeatDirect(seat);
  }

  Future<void> _tapSeat(int seat) async {
    final occupied = membersBySeat[seat];

    if (mySeat == seat) {
      await _showMySeatLeavePanel();
      return;
    }

    if (isRoomAdmin && occupied == null) {
      await _showSeatControls(seat);
      return;
    }

    if (occupied != null) {
      await _showSeatMemberProfile(occupied, seat);
      return;
    }

    if (isRoomAdmin) {
      await _showSeatControls(seat);
      return;
    }

    await _handleUserSeatTap(seat);
  }

  Future<void> _toggleMic() async {
    if (mySeat == null) return;
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
      // Ask the server first: a moderator mute overrides a local unmute
      // request, and the server answers with the effective mic state.
      // (Audit fix, Vinay 2026-11-20 — tapping unmute inside the 20s
      // controls refresh used to re-open the voice even on a muted seat.)
      Map<String, dynamic>? seatResult;
      if (widget.state.backendConnected && mySeat != null) {
        seatResult = await widget.state.backend.setSeatResult(
          roomId: widget.room.id,
          userId: widget.state.userId,
          seatIndex: mySeat,
          micMuted: !enable,
        );
      }
      // The local roomMutedSeats set refreshes only every 20s, so it can
      // still list a seat the moderator already unmuted. It is only a
      // fallback when the server gave no answer.
      if (seatResult == null && roomMutedSeats.contains(mySeat)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This mic is muted by room owner/admin')),
        );
        return;
      }
      if (enable && seatResult?['mic_muted'] == true) {
        await rtc?.setMicPublished(false);
        if (!mounted) return;
        setState(() => muted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This mic is muted by room owner/admin'),
          ),
        );
        return;
      }
      await rtc?.setMicPublished(enable);
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
                    .where((member) {
                      final publicId = formatPublicUserId(member['public_id']);
                      final name = member['display_name']?.toString() ?? '';
                      final q = query.toLowerCase();
                      return publicId.contains(query) ||
                          name.toLowerCase().contains(q);
                    })
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
                                        ? 'User'
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
                                  subtitle: Text('ID ${formatPublicUserId(member['public_id'])} • Audience'),
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
    final blockIdController = TextEditingController();
    try {
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: blockIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Block user by ID',
                            prefixIcon: Icon(Icons.block_rounded),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final typed =
                              normalizePublicIdInput(blockIdController.text);
                          if (typed.isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a user ID'),
                              ),
                            );
                            return;
                          }
                          final found = await widget.state.backend
                              .userByPublicId(typed);
                          if (!sheetContext.mounted) return;
                          if (found == null) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('No user with this ID'),
                              ),
                            );
                            return;
                          }
                          final targetId =
                              found['user_id']?.toString() ?? '';
                          final name =
                              found['display_name']?.toString() ?? 'User';
                          final confirmed = await showDialog<bool>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: Text('Block $name?'),
                              content: Text(
                                'ID ${formatPublicUserId(found['public_id'])} will not be able to rejoin this room.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Block'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !sheetContext.mounted) {
                            return;
                          }
                          final ok = await widget.state.backend
                              .removeRoomMember(
                            roomId: widget.room.id,
                            actorUserId: widget.state.userId,
                            targetUserId: targetId,
                            ban: true,
                          );
                          if (!sheetContext.mounted) return;
                          if (!ok) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Could not block this user'),
                              ),
                            );
                            return;
                          }
                          blockIdController.clear();
                          rows = await widget.state.backend.roomBlacklist(
                            roomId: widget.room.id,
                          );
                          if (sheetContext.mounted) refresh(() {});
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text('Blocked $name')),
                          );
                        },
                        child: const Text('Block'),
                      ),
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
                              subtitle: Text('ID ${formatPublicUserId(row['public_id'])}'),
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
    } finally {
      blockIdController.dispose();
    }
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
                                      _showSeatMemberProfile(member, seat);
                                    });
                                  },
                            leading: VipAnimatedFrame.auto(
                              // Auto-sizing: reads the 42px list avatar at
                              // runtime. Shows the animal frame from VIP5
                              // (not just the painted ring from VIP7).
                              enabled: (member['active_frame_id']?.toString().isNotEmpty == true) ||
                                  (int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0) >= 5,
                              level: int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 7,
                              styleId: member['active_frame_id']?.toString(),
                              assetUrl: (member['active_frame_asset_key']?.toString().trim().isNotEmpty == true)
                                  ? resolveVipVisualAssetUrl(
                                      member['active_frame_asset_key'].toString(),
                                      widget.state.backend.fileUrl,
                                    )
                                  : vipFrameStillUrlForVipLevel(
                                      int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0,
                                    ),
                              // VAP alpha-video: only when the frame shown
                              // IS the animal frame (custom frames have no
                              // VAP video and show the still).
                              videoUrl: vipFrameVapUrlForDisplay(
                                member['active_frame_asset_key']?.toString(),
                                int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0,
                              ),
                              assetHeaders: widget.state.backend.fileHeaders,
                              child: CircleAvatar(
                                radius: 21,
                                backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(widget.state.backend.fileUrl(avatar), headers: widget.state.backend.fileHeaders) : null,
                                child: avatar == null || avatar.isEmpty ? const Icon(Icons.person_rounded, size: 20) : null,
                              ),
                            ),
                            title: Text('${name == null || name.isEmpty ? 'User' : name}${isOwner ? ' • Owner' : (member['is_admin'] == true || member['is_admin']?.toString() == '1' ? ' • Admin' : '')}${(int.tryParse(member['active_vip_level']?.toString() ?? '') ?? 0) >= 9 && member['mic_muted'] != 1 && member['mic_muted']?.toString() != '1' ? '  🎤✨' : ''}'),
                            subtitle: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ID ${formatPublicUserId(member['public_id'])} • ' +
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
                                          icon: const Icon(Icons.waving_hand_rounded, color: Color(0xFF50D8FF)),
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
      if (cameraPublished && current is AgoraRtcAdapter) {
        await current.setCameraPublished(false);
      }
    } catch (_) {}

    _unbindAgoraEvents();

    try {
      await current?.leave();
    } catch (_) {}
    if (current is AgoraRtcAdapter) {
      current.dispose();
    } else if (current is LocalRtcAdapter) {
      current.dispose();
    }

    cameraPublished = false;

    mySeat = null;
    muted = true;

    try {
      await roomForegroundService.stop();
    } catch (_) {}
    roomForegroundServiceStarted = false;
  }

  /// I was kicked out of the room: my membership row is gone, so the
  /// member list keeps failing. Stop my voice and leave the channel
  /// first (same teardown as leaving on purpose — the worker's LiveKit
  /// remove call cannot do this: voice is Agora), then tell the user
  /// and exit. Any dismissal of the dialog exits the room.
  Future<void> _handleKickedFromRoom() async {
    if (_leavingRoom) return;
    _leavingRoom = true;
    widget.state.clearMinimizedRoom(roomId: widget.room.id);
    await _disconnectRoomRuntime();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Removed from room'),
        content: const Text(
          'You were removed from this room by the room owner or an admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _leaveServerMembership() async {
    _leavingRoom = true;
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
      displayId: widget.room.displayId,
      name: roomName,
      ownerName: widget.room.ownerName,
      ownerUserId: widget.room.ownerUserId,
      online: roomMembers.length,
      seatCount: roomSeatCount,
      avatarKey: roomAvatarKey,
      partyMode: roomPartyMode,
      roomMode: roomMode,
    );
    final roomRoute = ModalRoute.of(context);
    widget.state.showMinimizedRoom(
      room: displayRoom,
      onResume: () {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (roomRoute != null) {
          navigator.popUntil((route) => route == roomRoute);
        }
        widget.state.clearMinimizedRoom(roomId: widget.room.id);
      },
      onClose: () async {
        await _cleanupMinimizedRoom();
        if (!mounted) {
          widget.state.clearMinimizedRoom(roomId: widget.room.id);
          return;
        }
        final navigator = Navigator.of(context);
        if (roomRoute != null) {
          navigator.popUntil((route) => route == roomRoute);
        }
        widget.state.clearMinimizedRoom(roomId: widget.room.id);
        if (navigator.canPop()) {
          navigator.pop();
        }
      },
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HomeShell(state: widget.state),
      ),
    );
    if (mounted) {
      widget.state.clearMinimizedRoom(roomId: widget.room.id);
    }
  }

  /// Top-of-room banner tap (Vinay, 2026-11-22): a banner that names
  /// another room (a Rocket launch or big gift elsewhere) takes the
  /// user into that room. The current room is left first (same
  /// teardown as _leaveRoom), then this screen pops with the target
  /// room id — the home shell opens that room on return. Tapping a
  /// banner for the room the user is already in does nothing.
  /// (Oyaar video, Vinay 2026-11-22: tapping a cross-room banner
  /// first asks "Enter this room?" — Cancel / Confirm — and only
  /// Confirm enters the room.)
  Future<void> _onTopBannerTap(String roomId) async {
    if (!mounted || roomId.isEmpty || roomId == widget.room.id) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter this room?'),
        content: const Text(
          'Tip: Swipe left on the floating panel to close it quickly',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.state.clearMinimizedRoom(roomId: widget.room.id);
    await _leaveServerMembership();
    await _disconnectRoomRuntime();
    if (mounted) Navigator.of(context).pop(roomId);
  }

  Future<void> _leaveRoom() async {
    // Exit always tears down the local room first-class resources. The server
    // membership request is retried, but a transient network error must never
    // leave mic/RTC/foreground-service work running after the user exits.
    widget.state.clearMinimizedRoom(roomId: widget.room.id);
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
          onGameRoom: () => Navigator.pop(context, 'convert-game-room'),
          onFruitParty: () => Navigator.pop(context, 'fruit-party'),
          onGreedyGirl: () => Navigator.pop(context, 'greedy-girl'),
          onToggleMic: _toggleMic,
          micOn: () => mySeat != null && !muted,
          hasMicSeat: () => mySeat != null,
        ),
      ),
    );
    if (!mounted) return;
    if (selection == 'convert-game-room') {
      if (roomMode == 'game') return;
      final ok = await _saveRoomConfiguration(nextRoomMode: 'game');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'This room is now a Game Room.'
                : 'This room could not be converted to Game Room.',
          ),
        ),
      );
    } else if (selection == 'fruit-party') {
      await showFruitParty(context, widget.state);
    } else if (selection == 'greedy-girl') {
      await showGreedyGirl(context, widget.state);
    }
  }

  Future<void> _shareRoomId() async {
    await Clipboard.setData(ClipboardData(text: formatPublicUserId(widget.room.roomNumber)));
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
    'midnight' => const Color(0xA6111B32),
    'rose' => const Color(0xA632192B),
    'forest' => const Color(0xA614281F),
    'gold' => const Color(0xA6171006),
    _ => Colors.transparent,
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

  Future<void> _showVipOnlyRoom() async {
    if (!isRoomHost) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'VIP-only Room',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text('Choose who can enter this room.'),
            ),
            RadioListTile<int>(
              value: 0,
              groupValue: roomVipOnly,
              title: const Text('Everyone'),
              subtitle: const Text('Any member can enter.'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
            RadioListTile<int>(
              value: 1,
              groupValue: roomVipOnly,
              title: const Text('VIP 1+'),
              subtitle: const Text('VIP 1 to VIP 18 members can enter.'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
            RadioListTile<int>(
              value: 5,
              groupValue: roomVipOnly,
              title: const Text('VIP 5+'),
              subtitle: const Text('Only VIP 5 and above can enter.'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected > 0 &&
        !VipPolicy.canEnterVipOnlyRoom(
          widget.state.vipLevel,
          active: widget.state.vipIsActive,
          requiredLevel: 10,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VIP10 is required to make a VIP-only room'),
        ),
      );
      return;
    }
    final result = await widget.state.backend.setRoomControl(
      roomId: widget.room.id,
      userId: widget.state.userId,
      action: 'vip_only',
      vipOnly: selected,
    );
    if (!mounted) return;
    if (result?['ok'] == true) {
      setState(() => roomVipOnly = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected == 0
                ? 'Room is open to everyone now'
                : 'Room is VIP $selected+ only now',
          ),
        ),
      );
    } else if (result?['error'] == 'vip_only_requires_vip10') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VIP10 is required to make a VIP-only room'),
        ),
      );
    }
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
                                    ? 'User'
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
    if (!isRoomAdmin || seat < 0 || seat >= roomSeatCount) return;
    final member = membersBySeat[seat];
    final locked = lockedSeats.contains(seat);
    final roomMuted = roomMutedSeats.contains(seat);
    final memberId = member?['user_id']?.toString() ?? '';
    final memberIsOwner =
        memberId.isNotEmpty && memberId == widget.room.ownerUserId;
    final memberIsAdmin = _seatMemberIsAdmin(member);

    if (member != null &&
        !isRoomHost &&
        (memberIsOwner || memberIsAdmin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            memberIsOwner
                ? 'Admin cannot mute, lock or seat down the room owner.'
                : 'Admin cannot control another admin seat.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        key: const Key('reference-seat-control-panel'),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
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
            ListTile(
              key: const Key('seat-control-lock'),
              leading: Icon(
                locked ? Icons.lock_open_rounded : Icons.lock_rounded,
              ),
              title: Text(locked ? 'Seat Unlock' : 'Seat Lock'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await widget.state.backend.setRoomControl(
                  roomId: widget.room.id,
                  userId: widget.state.userId,
                  action: 'seat_lock',
                  seatIndex: seat,
                  locked: !locked,
                );
                if (result?['ok'] == true) {
                  await _loadRoomControls();
                } else if (mounted) {
                  final error = result?['error']?.toString() ?? '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.isEmpty
                            ? 'Seat lock could not be changed'
                            : error.replaceAll('_', ' '),
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              key: const Key('seat-control-mute'),
              leading: Icon(
                roomMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
              ),
              title: Text(roomMuted ? 'Seat Unmute' : 'Seat Mute'),
              onTap: () async {
                Navigator.pop(sheetContext);
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
                } else if (mounted) {
                  final error = result?['error']?.toString() ?? '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.isEmpty
                            ? 'Seat mute could not be changed'
                            : error.replaceAll('_', ' '),
                      ),
                    ),
                  );
                }
              },
            ),
            if (member == null)
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
                  Future<void>.delayed(Duration.zero, () {
                    if (mounted) {
                      unawaited(_inviteOffSeatMemberToSeat(seat));
                    }
                  });
                },
              ),
            if (member == null)
              ListTile(
                key: const Key('seat-control-take'),
                leading: const Icon(
                  Icons.event_seat_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Take Seat'),
                subtitle: const Text(
                  'Owner/Admin can take this empty seat directly.',
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (mySeat != null && mySeat != seat) {
                    final left = await _leaveMySeat();
                    if (!left) return;
                  }
                  await _takeSeatDirect(seat);
                },
              ),
            if (member != null &&
                memberId != widget.state.userId &&
                (isRoomHost || _canModerateSeatMember(member)))
              ListTile(
                key: const Key('seat-control-down'),
                leading: const Icon(
                  Icons.airline_seat_recline_normal_rounded,
                  color: TinniPalette.brightGold,
                ),
                title: const Text('Seat Down'),
                subtitle: Text(
                  '${member['display_name']?.toString() ?? 'User'} ko audience me bheje',
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
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
                },
              ),
            if (mySeat == seat)
              ListTile(
                key: const Key('seat-control-leave'),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: TinniPalette.brightGold,
                ),
                title: const Text('Leave this seat'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _leaveMySeat();
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
      rocketBannerEnabled =
          prefs.getBool('dvx.room.effects.rocket_notice') ?? true;
      giftBannerEnabled =
          prefs.getBool('dvx.room.effects.gift_banner') ?? true;
      gameBannerEnabled =
          prefs.getBool('dvx.room.effects.game_banner') ?? true;
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
                  title: const Text('Vehicle Effect'),
                  subtitle: const Text('Vehicle room-entry animations.'),
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
                  title: const Text('Gift Banner'),
                  subtitle: const Text(
                    'Gift ribbon banner and Lucky win announcement.',
                  ),
                  value: giftBannerEnabled,
                  onChanged: (value) {
                    setState(() => giftBannerEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.gift_banner',
                        value,
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Rocket Banner'),
                  subtitle: const Text('Rocket launch animation in the room.'),
                  value: rocketBannerEnabled,
                  onChanged: (value) {
                    setState(() => rocketBannerEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.rocket_notice',
                        value,
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Game Banner'),
                  subtitle: const Text(
                    '2-line banner at the top of the room (gift, Lucky win, Rocket, VIP entry).',
                  ),
                  value: gameBannerEnabled,
                  onChanged: (value) {
                    setState(() => gameBannerEnabled = value);
                    refresh(() {});
                    unawaited(
                      _setRoomEffectPreference(
                        'dvx.room.effects.game_banner',
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

  Offset _giftFlightOriginOffset(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return Offset.zero;
    }
    final screen = MediaQuery.sizeOf(context);
    final centerGlobal = Offset(screen.width / 2, screen.height / 2);
    final centerLocal = renderObject.globalToLocal(centerGlobal);
    return centerLocal - renderObject.size.center(Offset.zero);
  }

  String? _giftReceiverAvatar(String receiverId) {
    for (final member in roomMembers) {
      if (member['user_id']?.toString() == receiverId) {
        final key = member['avatar_key']?.toString().trim() ?? '';
        if (key.isNotEmpty) return key;
      }
    }
    for (final member in membersBySeat.values) {
      if (member['user_id']?.toString() == receiverId) {
        final key = member['avatar_key']?.toString().trim() ?? '';
        if (key.isNotEmpty) return key;
      }
    }
    if (receiverId == widget.state.userId) return widget.state.avatarKey;
    return null;
  }

  void _playGiftEffect(
    Map<String, dynamic> gift, {
    required String receiverId,
    // Split send (Vinay, 2026-11-22): when one gift goes to several
    // users in a single go, pass ALL their ids here. One gift appears
    // in the screen centre and splits into one copy per receiver.
    List<String>? receiverIds,
    String? senderId,
  }) {
    if (!effectsEnabled || !giftEffectsEnabled) return;
    if (giftSoundEnabled) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    if (!giftFlyInEnabled && !giftBubbleEnabled) return;
    final ids = <String>{
      ...?receiverIds,
      receiverId,
    }.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final now = DateTime.now();
    // Coalesce: the same gift from the same sender, sent again within
    // 600ms (the other copies of one multi-user batch arriving via the
    // poll or the Agora live feed), joins the effect already playing
    // instead of restarting it. The new receivers' seats start their
    // own flight from the same centre point, so the single gift visibly
    // splits. Existing flights are NOT restarted (giftEffectSequence is
    // left alone), only the clear timer is pushed out so the last copy
    // gets its full flight.
    final sameBatch = activeGiftEffect != null &&
        activeGiftEffect!['id']?.toString() == gift['id']?.toString() &&
        senderId != null &&
        activeGiftSenderId != null &&
        activeGiftSenderId == senderId &&
        _giftEffectStartedAt != null &&
        now.difference(_giftEffectStartedAt!).inMilliseconds < 600;
    giftEffectTimer?.cancel();
    if (sameBatch) {
      setState(() {
        activeGiftReceiverIds.addAll(ids);
        activeGiftReceiverAvatarKey ??= _giftReceiverAvatar(ids.first);
      });
    } else {
      setState(() {
        activeGiftEffect = Map<String, dynamic>.from(gift);
        activeGiftReceiverIds = ids;
        activeGiftSenderId = senderId;
        activeGiftReceiverAvatarKey = _giftReceiverAvatar(ids.first);
        _giftEffectStartedAt = now;
        giftEffectSequence++;
      });
    }
    // Dragon gifts (Vinay, 2026-11-22): the dragon flies in the
    // centre for 2 seconds, then 1 second to the receiver's DP —
    // the effect lives 3.2s in total, not 2.2s.
    final dragonEffect = _isDragonGift(gift);
    giftEffectTimer = Timer(Duration(milliseconds: dragonEffect ? 3200 : 2200), () {
      if (!mounted) return;
      setState(() {
        activeGiftEffect = null;
        activeGiftReceiverIds = <String>{};
        activeGiftSenderId = null;
        _giftEffectStartedAt = null;
        activeGiftReceiverAvatarKey = null;
      });
    });
  }

  /// Shows the VIP gift ribbon banner for a gift event, for a few
  /// seconds, ALONGSIDE (never instead of) the existing gift display
  /// (emoji fly-in / video / GLB). The banner is the tier image for the
  /// SENDER's VIP level (basic Sleek Gold for VIP0/no-VIP), with the VIP
  /// level BIG and bold, sender -> receiver, and the gift name. The
  /// server ribbon (gift_ribbon.url) is preferred; without it the local
  /// mapping by sender VIP level is used. It has its own timer so it
  /// also shows after a gift video/GLB dialog closes.
  // Top-of-room banner queue (Vinay, 2026-11-22): every banner event
  // — gift, Lucky win, Rocket launch, VIP entry — joins this queue,
  // and the banner shows one message at a time for 4s each, then
  // rotates to the next. Deduped by a key so the same event (arriving
  // via the poll and the live event, or re-polled) shows once. The
  // queue is capped so a gift storm cannot grow it without bound.
  void _enqueueTopBanner({
    required String text,
    String? roomId,
    required String key,
    TopBannerKind kind = TopBannerKind.event,
    int? rocketLevel,
    String? avatarUrl,
  }) {
    if (!mounted) return;
    if (!_seenTopBannerKeys.add(key)) return;
    _topBannerQueue.add({
      'text': text,
      'room_id': roomId,
      'kind': kind,
      'rocket_level': rocketLevel,
      'avatar_url': avatarUrl,
    });
    if (_topBannerQueue.length > 10) _topBannerQueue.removeAt(0);
    if (_currentTopBanner == null) _showNextTopBanner();
  }

  void _showNextTopBanner() {
    if (!mounted) return;
    _topBannerTimer?.cancel();
    if (_topBannerQueue.isEmpty) {
      setState(() => _currentTopBanner = null);
      return;
    }
    setState(() => _currentTopBanner = _topBannerQueue.removeAt(0));
    _topBannerTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _showNextTopBanner();
    });
  }

  void _showGiftRibbon({
    required Map<String, dynamic> event,
    required String senderName,
    required String receiverName,
    required String giftName,
  }) {
    if (!mounted || !effectsEnabled || !giftBannerEnabled) return;
    final int vipLevel = giftRibbonVipLevelFromEvent(event);
    giftRibbonTimer?.cancel();
    setState(() {
      activeGiftRibbon = <String, dynamic>{
        'vip_level': vipLevel,
        'sender_name': senderName,
        'receiver_name': receiverName,
        'gift_name': giftName,
        'ribbon_url': giftRibbonUrlFromEvent(event),
      };
    });
    giftRibbonTimer = Timer(const Duration(milliseconds: 4000), () {
      if (!mounted) return;
      setState(() {
        activeGiftRibbon = null;
      });
    });
  }

  // Lucky win announcement (Vinay, 2026-11-22): when a gift event paid
  // its sender a win, everyone in the room sees this banner when the
  // gift plays. The sender's own screen shows the win in the send
  // snackbar and the room chat message instead, so this helper is only
  // called for other users' gifts (the sender skips their own events).
  void _showLuckyWinAnnouncement(
    Map<String, dynamic> event,
    String senderName,
    String giftName,
    String receiverName,
  ) {
    if (!mounted || !effectsEnabled || !giftBannerEnabled) return;
    final winCoins =
        int.tryParse(event['lucky_win_coins']?.toString() ?? '') ?? 0;
    if (winCoins <= 0) return;
    final multiplier =
        int.tryParse(event['lucky_multiplier']?.toString() ?? '') ?? 0;
    // Top-of-room banner (Vinay, 2026-11-22): the Lucky win shows in
    // the same gift banner as the gift itself, not a separate banner.
    // The banner names the room ID and who received the gift (Vinay,
    // 2026-11-22 13:38 IST: "Lucky gift per room id aur kisko mile ye
    // kyu nhi likha").
    final luckyText =
        '🎉 $senderName won $winCoins coins on a Lucky $giftName (${multiplier}×) for $receiverName in ${widget.room.name} (Room ID: ${widget.room.id})!';
    _enqueueTopBanner(
      text: luckyText,
      key: 'lucky:${event['id']?.toString() ?? ''}',
      kind: TopBannerKind.lucky,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(luckyText),
      ),
    );
  }

  Widget _buildSeatGiftImpactEffect(double seatDiameter) {
    final gift = activeGiftEffect;
    if (gift == null) return const SizedBox.shrink();
    final emoji = gift['emoji']?.toString() ?? '🎁';
    // Glass gifts (Vinay, 2026-11-22): when the gift has an R2 image
    // (asset_key), the flying gift IS that 3D glass image, not the emoji.
    // The emoji stays only as the fallback for gifts without an image.
    final assetKey = gift['asset_key']?.toString().trim() ?? '';
    final videoKey = gift['video_key']?.toString().trim() ?? '';
    final glbKey = gift['glb_key']?.toString().trim() ?? '';
    final svgaKey = gift['svga_key']?.toString().trim() ?? '';
    // Animation intensity (Vinay, 2026-11-22): gifts of 20,000 coins and
    // above get the FULL animation effect (SVGA plays in the centre);
    // gifts below 20,000 coins get only 20% animation — a small pop,
    // no SVGA, static image only. Judged on the gift's UNIT price
    // (coin_cost / count), not the combo total.
    final giftCostTotal =
        int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
    final giftCount = int.tryParse(gift['count']?.toString() ?? '') ?? 1;
    final giftCost = giftCount > 0 ? giftCostTotal ~/ giftCount : giftCostTotal;
    final fullAnimation = giftCost >= 20000 && svgaKey.isNotEmpty;
    // Dragon gifts (Vinay, 2026-11-22): BIG in the screen centre,
    // wings flapping for 2 seconds, then flying to the receiver's DP.
    final isDragon = _isDragonGift(gift);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey<int>(giftEffectSequence),
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: isDragon ? 3000 : 1450),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          // Small gifts (Vinay, 2026-11-22): the gift goes to the
          // screen centre, STAYS there showing its animation, then
          // flies to the receiver's DP. Hold phase = first 45% of the
          // tween stays at the centre (pop-in only); flight starts
          // after that. Dragons hold longer: 2 of the 3 seconds in
          // the centre, wings flapping, then 1 second to the DP.
          final holdEnd = isDragon ? 0.67 : 0.45;
          final flight = value < holdEnd
              ? 0.0
              : ((value - holdEnd) / (1 - holdEnd))
                  .clamp(0.0, 1.0)
                  .toDouble();
          final fade = flight < .72
              ? 1.0
              : ((1 - flight) / .28).clamp(0.0, 1.0).toDouble();
          // Full animation: the SVGA does its own pop-in, so the
          // Flutter scale stays at 1.0 during the hold. Dragons
          // (Vinay, 2026-11-22): shrink while flying to the DP —
          // the dragon gets smaller as it goes to the receiver's DP.
          // 20% animation: only a small pop (0.8 -> 1.0) instead of
          // the full pop.
          final scale = fullAnimation
              ? (isDragon ? 1.0 - flight * 0.8 : 1.0)
              : value < holdEnd
                  ? .8 + Curves.easeOutBack.transform(value / holdEnd) * .2
                  : 1.0;
          final rise = math.sin(math.pi * flight) * seatDiameter * .42;
          final origin = _giftFlightOriginOffset(context);
          return Transform.translate(
            offset: Offset(
              origin.dx * (1 - flight),
              origin.dy * (1 - flight) - rise,
            ),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: fade,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TinniPalette.brightGold,
                      width: 1.2,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x99FFD45A),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: fullAnimation
                      ? SizedBox(
                          // Dragon: BIG in the centre (85% of screen
                          // width), looping so the wings keep flapping
                          // while it flies to the DP. Other gifts:
                          // (Vinay, 2026-11-22: "20% bada kar de") —
                          // seat-sized, 20% bigger than before
                          // (0.62 -> 0.744), plays once.
                          width: isDragon
                              ? MediaQuery.of(context).size.width * .85
                              : seatDiameter * .744,
                          height: isDragon
                              ? MediaQuery.of(context).size.width * .85
                              : seatDiameter * .744,
                          child: SVGAEasyPlayer(
                            resUrl: widget.state.backend.fileUrl(svgaKey),
                            loops: isDragon,
                          ),
                        )
                      : assetKey.isNotEmpty
                          ? SizedBox(
                              width: seatDiameter * .62,
                              height: seatDiameter * .62,
                              child: GiftMediaPreview(
                                backend: widget.state.backend,
                                videoKey: videoKey,
                                assetKey: assetKey,
                                glbKey: glbKey,
                                emoji: emoji,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Text(
                              emoji,
                              style: TextStyle(fontSize: seatDiameter * .56),
                            ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color get _seatThemeAccent => switch (roomSeatThemeId) {
        'neon-blue' => const Color(0xFF58B8FF),
        'rose-glow' => const Color(0xFFFF6EA9),
        _ => TinniPalette.brightGold,
      };

  Future<Map<String, dynamic>?> _saveRoomConfigurationResult({
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
    if (!mounted) return result;
    if (ok) {
      final settings = result?['settings'];
      final generatedCode =
          settings is Map ? settings['lock_code']?.toString().trim() ?? '' : '';
      if (nextRoomMode != null &&
          nextRoomMode != 'live' &&
          cameraPublished &&
          rtc is AgoraRtcAdapter) {
        try {
          await (rtc as AgoraRtcAdapter).setCameraPublished(false);
          if (mounted) {
            cameraPublished = false;

          }
        } catch (_) {}
      }
      if (!mounted) return result;
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
    return result;
  }

  Future<bool> _saveRoomConfiguration({
    int? seatCount,
    String? themeId,
    String? seatThemeId,
    bool? groupPk,
    bool? locked,
    String? partyMode,
    String? nextRoomMode,
  }) async {
    final result = await _saveRoomConfigurationResult(
      seatCount: seatCount,
      themeId: themeId,
      seatThemeId: seatThemeId,
      groupPk: groupPk,
      locked: locked,
      partyMode: partyMode,
      nextRoomMode: nextRoomMode,
    );
    return result?['ok'] == true;
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
    final result = await _saveRoomConfigurationResult(themeId: selected);
    if (!mounted || result?['ok'] == true) return;
    // The server gates room background on VIP3; surface that instead of
    // the generic error (the settings dialog hides the dropdown without
    // the privilege, but this selector offers every theme to any host).
    final error = result?['error']?.toString() ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == 'vip3_required_for_room_background'
              ? 'Room background unlocks at VIP3.'
              : 'Room theme could not be changed',
        ),
      ),
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
        'VIP-only Room',
        Icons.workspace_premium_rounded,
        _showVipOnlyRoom,
        isRoomHost,
      ),
      (
        'Chat clear',
        Icons.delete_sweep_rounded,
        _clearRoomChat,
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
      if (tool.$1 == 'VIP-only Room') return isRoomHost;
      if (tool.$1 == 'Chat clear') return isRoomAdmin;
      if (tool.$1 == 'Report') return !isRoomHost;
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
              subtitle: Text(formatPublicUserId(widget.room.roomNumber)),
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

  Future<void> _playGiftGlb(
    Map<String, dynamic> gift, {
    required String receiverId,
    required String glbKey,
  }) async {
    // Video/GLB gifts respect the Gift Effects toggle (Vinay, 2026-11-22):
    // with Gift Effects off, no gift animation plays for this user.
    if (!mounted || !effectsEnabled || !giftEffectsEnabled) return;
    if (glbKey.trim().isEmpty) return;
    final receiver = membersBySeat.values.firstWhere(
      (member) => member['user_id']?.toString() == receiverId,
      orElse: () => <String, dynamic>{},
    );
    final receiverName = (receiver['display_name'] ??
            receiver['name'] ??
            receiver['nickname'] ??
            (receiverId == widget.state.userId
                ? widget.state.displayName
                : receiverId))
        .toString();
    final giftName = (gift['name'] ?? 'Gift').toString();
    final senderDisplayName = widget.state.displayName;
    var closeTriggered = false;
    Timer? closeTimer;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (dialogContext) {
          closeTimer ??= Timer(
            Duration(
              milliseconds: (int.tryParse(
                        gift['animation_ms']?.toString() ?? '',
                      ) ??
                      5000)
                  .clamp(2000, 10000)
                  .toInt(),
            ),
            () {
              if (!closeTriggered &&
                  Navigator.of(dialogContext).canPop()) {
                closeTriggered = true;
                Navigator.of(dialogContext).pop();
              }
            },
          );
          return PopScope(
            canPop: true,
            child: Scaffold(
              backgroundColor: const Color(0xFF080611),
              body: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: ModelViewer(
                        src: widget.state.backend.fileUrl(glbKey),
                        alt: giftName,
                        backgroundColor: const Color(0xFF080611),
                        autoRotate: true,
                        autoPlay: true,
                        ar: false,
                        cameraControls: false,
                        disableZoom: true,
                        shadowIntensity: 1,
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xCC100D22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0x669F88FF),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$senderDisplayName sent $giftName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To: $receiverName',
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        tooltip: 'Close 3D gift',
                        onPressed: () {
                          closeTriggered = true;
                          closeTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      // A malformed or unavailable GLB must not interfere with a completed gift send.
      if (mounted) _playGiftEffect(gift, receiverId: receiverId);
    } finally {
      closeTimer?.cancel();
    }
  }

  Future<void> _playGiftVideo(
    Map<String, dynamic> gift, {
    required String receiverId,
    required String videoKey,
    String? senderName,
  }) async {
    // Video/GLB gifts respect the Gift Effects toggle (Vinay, 2026-11-22):
    // with Gift Effects off, no gift animation plays for this user.
    if (!mounted || !effectsEnabled || !giftEffectsEnabled) return;
    gift_video.VideoPlayerController? controller;
    VoidCallback? playbackListener;
    var listenerAttached = false;
    var closeTriggered = false;
    try {
      final player = gift_video.VideoPlayerController.networkUrl(
        Uri.parse(widget.state.backend.fileUrl(videoKey)),
        httpHeaders: widget.state.backend.fileHeaders,
      );
      controller = player;
      await player.initialize();
      await player.setLooping(false);
      await player.setVolume(1.0);
      if (!mounted) return;

      final receiver = membersBySeat.values.firstWhere(
        (member) => member['user_id']?.toString() == receiverId,
        orElse: () => <String, dynamic>{},
      );
      final receiverName = (receiver['display_name'] ??
              receiver['name'] ??
              receiver['nickname'] ??
              (receiverId == widget.state.userId
                  ? widget.state.displayName
                  : receiverId))
          .toString();
      final giftName = (gift['name'] ?? 'Gift').toString();
      final senderDisplayName = senderName?.trim().isNotEmpty == true
          ? senderName!.trim()
          : widget.state.displayName;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black,
        builder: (dialogContext) {
          playbackListener ??= () {
            if (!player.value.isInitialized ||
                !player.value.isCompleted ||
                closeTriggered) {
              return;
            }
            closeTriggered = true;
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          };
          if (!listenerAttached) {
            player.addListener(playbackListener!);
            listenerAttached = true;
          }
          if (!player.value.isPlaying && !player.value.isCompleted) {
            unawaited(player.play());
          }
          return PopScope(
            canPop: true,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: player.value.aspectRatio > 0
                            ? player.value.aspectRatio
                            : 9 / 16,
                        child: gift_video.VideoPlayer(player),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 16,
                      right: 16,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xB8000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$senderDisplayName sent $giftName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To: $receiverName',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        tooltip: 'Close gift video',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      // Keep gift sending usable if R2 playback is temporarily unavailable.
      if (mounted) _playGiftEffect(gift, receiverId: receiverId);
    } finally {
      if (controller != null && playbackListener != null) {
        controller.removeListener(playbackListener!);
      }
      await controller?.dispose();
    }
  }

  /// Big-gift threshold (Vinay, 2026-11-22): big gifts play full-screen
  /// (SVGA / video / GLB dialog); small gifts play at the screen centre,
  /// pause, then fly to the receiver's DP. 500,000 coins (5 lakh) —
  /// gifts under 5 lakh are small, 5 lakh and above are big.
  static const int _bigGiftCoinThreshold = 500000;

  bool _isBigGift(Map<String, dynamic> gift) {
    final cost = int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
    return cost >= _bigGiftCoinThreshold;
  }

  /// Dragon gifts (Vinay, 2026-11-22): Fire Dragon and Cosmic Dragon
  /// Palace do NOT play full-screen. They fly in the CENTRE of the
  /// screen, wings flapping, for 2-3 seconds, then fly to the
  /// receiver's DP — like a small gift, but BIG and with the wing-flap
  /// SVGA animation. (Golden Dragon was REMOVED from the catalog by
  /// Vinay, 2026-11-22: "Tu is dragon ko hta de ye rahega hi nhi".)
  static const Set<String> _dragonGiftIds = <String>{
    'fire-dragon',
    'cosmic-dragon-palace',
  };

  bool _isDragonGift(Map<String, dynamic> gift) {
    return _dragonGiftIds.contains(gift['id']?.toString());
  }

  /// Plays an SVGA gift animation (Vinay, 2026-11-22): SVGA files are
  /// made from pictures + animation keyframes (scale, move, fade,
  /// sparkle), NOT video files. The SVGA background is transparent, so
  /// the dialog is transparent too — the room shows through behind the
  /// gift, unlike the black video dialog. Plays once, then closes.
  /// Falls back to the simple effect if the SVGA cannot load.
  Future<void> _playGiftSvga(
    Map<String, dynamic> gift, {
    required String receiverId,
    required String svgaKey,
    String? senderName,
  }) async {
    // SVGA gifts respect the Gift Effects toggle (Vinay, 2026-11-22):
    // with Gift Effects off, no gift animation plays for this user.
    if (!mounted || !effectsEnabled || !giftEffectsEnabled) return;
    try {
      final receiver = membersBySeat.values.firstWhere(
        (member) => member['user_id']?.toString() == receiverId,
        orElse: () => <String, dynamic>{},
      );
      final receiverName = (receiver['display_name'] ??
              receiver['name'] ??
              receiver['nickname'] ??
              (receiverId == widget.state.userId
                  ? widget.state.displayName
                  : receiverId))
          .toString();
      final giftName = (gift['name'] ?? 'Gift').toString();
      final senderDisplayName = senderName?.trim().isNotEmpty == true
          ? senderName!.trim()
          : widget.state.displayName;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (dialogContext) {
          var closeTriggered = false;
          return PopScope(
            canPop: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Dragon flies at the TOP of the screen (Vinay,
                    // 2026-11-22: "Screen ke uper udega ye") — the
                    // SVGA sits at the top, below the sender card,
                    // instead of in the screen centre.
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 96),
                        child: SVGAEasyPlayer(
                          resUrl: widget.state.backend.fileUrl(svgaKey),
                          loops: false,
                          onFinished: () {
                            if (!closeTriggered &&
                                Navigator.of(dialogContext).canPop()) {
                              closeTriggered = true;
                              Navigator.of(dialogContext).pop();
                            }
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 16,
                      right: 16,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xB8000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$senderDisplayName sent $giftName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'To: $receiverName',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        tooltip: 'Close gift animation',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      // Keep gift sending usable if SVGA playback is temporarily
      // unavailable.
      if (mounted) _playGiftEffect(gift, receiverId: receiverId);
    }
  }

  Future<bool> _sendGiftByDefinition(
    Map<String, dynamic> gift,
    String receiverId, {
    int count = 1,
    // Split send (Vinay, 2026-11-22): a bulk send passes playEffect
    // false so each copy does NOT play its own effect; the caller plays
    // ONE split effect for the whole batch (one gift in the centre that
    // splits to every receiver) after the loop.
    bool playEffect = true,
  }) async {
    final giftId = gift['id']?.toString() ?? '';
    final giftCost = int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0;
    if (giftId.isEmpty || giftCost <= 0 || receiverId.isEmpty) return false;
    Map<String, dynamic>? result;
    try {
      result = await widget.state.backend.sendGift(
        roomId: widget.room.id,
        senderUserId: widget.state.userId,
        receiverUserId: receiverId,
        giftId: giftId,
        coinCost: giftCost,
        count: count,
      );
    } catch (_) {
      // _json throws on a network drop; a failed send must show a
      // snackbar instead of crashing the gift flow.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gift could not be sent. Check your connection and try again.')),
        );
      }
      return false;
    }
    final remoteBalance =
        int.tryParse(result?['sender_coin_balance']?.toString() ?? '');
    final receiverDiamondBalance = int.tryParse(
      result?['receiver_diamond_balance']?.toString() ?? '',
    );
    if (receiverId == widget.state.userId &&
        receiverDiamondBalance != null) {
      widget.state.setDiamondBalance(receiverDiamondBalance);
    }
    if (remoteBalance != null) {
      // Gift combo (Vinay, 2026-11-21): the server confirms how many
      // copies were sent and the total charged; the room shows "xN".
      final sentCount =
          (int.tryParse(result?['gift_count']?.toString() ?? '') ?? count)
              .clamp(1, 7777);
      final sentTotal =
          int.tryParse(result?['gift_total_cost']?.toString() ?? '') ??
              (giftCost * sentCount);
      final displayGiftName = sentCount > 1
          ? '${gift['name'] ?? 'Gift'} x$sentCount'
          : (gift['name'] ?? 'Gift').toString();
      // Lucky win (Vinay, 2026-11-22): the send response carries the
      // roll for this send — 0 means no win, otherwise the sender won
      // lucky_win_coins in-app coins on top of the gift.
      final luckyMultiplier =
          int.tryParse(result?['lucky_multiplier']?.toString() ?? '') ?? 0;
      final luckyWinCoins =
          int.tryParse(result?['lucky_win_coins']?.toString() ?? '') ?? 0;
      final displayGift = Map<String, dynamic>.from(gift)
        ..['count'] = sentCount
        ..['name'] = displayGiftName;
      final committedEventId = result?['event_id']?.toString() ?? '';
      if (committedEventId.isNotEmpty) {
        _seenGiftEventIds.add(committedEventId);
        final adapter = rtc;
        if (adapter is AgoraRtcAdapter) {
          unawaited(adapter.publishGiftEvent(<String, dynamic>{
            'type': 'gift',
            'id': committedEventId,
            'sender_user_id': widget.state.userId,
            'receiver_user_id': receiverId,
            'sender_name': widget.state.displayName,
            'gift_id': giftId,
            'gift_name': displayGiftName,
            'emoji': gift['emoji']?.toString() ?? '🎁',
            'coin_cost': sentTotal,
            'count': sentCount,
            'video_key': (gift['video_key'] ?? gift['videoKey'] ?? '').toString(),
            'glb_key': (gift['glb_key'] ?? gift['glbKey'] ?? '').toString(),
            'asset_key': (gift['asset_key'] ?? gift['asset'] ?? '').toString(),
          }).catchError((_) {
            // The committed Worker event feed remains the recovery path if a
            // Agora data stream can fail transiently; committed Worker feed is the fallback.
          }));
        }
      }
      widget.state.setCoinBalance(remoteBalance);
      final videoKey = (gift['video_key'] ?? gift['videoKey'] ?? '')
          .toString()
          .trim();
      final glbKey = (gift['glb_key'] ?? gift['glbKey'] ?? '')
          .toString()
          .trim();
      final svgaKey = (gift['svga_key'] ?? gift['svgaKey'] ?? '')
          .toString()
          .trim();
      final receiver = membersBySeat.values.firstWhere(
        (member) => member['user_id']?.toString() == receiverId,
        orElse: () => <String, dynamic>{},
      );
      final receiverName = (receiver['display_name'] ??
              receiver['name'] ??
              receiver['nickname'] ??
              (receiverId == widget.state.userId
                  ? widget.state.displayName
                  : receiverId))
          .toString();
      final giftName = displayGiftName;
      // Keep the gift visible in the room chat as a normal room event too.
      // A Lucky win is announced in the same message, so the whole room
      // sees it (the receiver's screen also shows a win banner when the
      // gift plays).
      final winSuffix = luckyWinCoins > 0
          ? ' 🎉 Lucky win: +$luckyWinCoins coins (${luckyMultiplier}×)!'
          : '';
      unawaited(widget.state.backend.sendRoomMessage(
        roomId: widget.room.id,
        userId: widget.state.userId,
        text: '🎁 ${widget.state.displayName} sent $giftName to $receiverName$winSuffix',
      ));
      if (playEffect) {
        // Dragon gifts skip the full-screen SVGA dialog (Vinay,
        // 2026-11-22): they fly in the screen centre, then to the DP.
        if (svgaKey.isNotEmpty && _isBigGift(displayGift) && !_isDragonGift(displayGift)) {
          await _playGiftSvga(displayGift, receiverId: receiverId, svgaKey: svgaKey);
        } else if (videoKey.isNotEmpty) {
          await _playGiftVideo(displayGift, receiverId: receiverId, videoKey: videoKey);
        } else if (glbKey.isNotEmpty) {
          await _playGiftGlb(displayGift, receiverId: receiverId, glbKey: glbKey);
        } else {
          _playGiftEffect(
            displayGift,
            receiverId: receiverId,
            senderId: widget.state.userId,
          );
        }
        // Gift ribbon banner (sender's VIP tier from the send response,
        // basic for VIP0): shown with the gift display, after any
        // video/GLB dialog.
        _showGiftRibbon(
          event: result ?? <String, dynamic>{},
          senderName: widget.state.displayName,
          receiverName: receiverName,
          giftName: giftName,
        );
      }
      await widget.state.refreshIdLevel(notify: false);
      if (!mounted) return false;
      unawaited(_loadRoomGiftRanking());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // Lucky win (Vinay, 2026-11-22): the sender's win is the
            // headline — it replaces the plain "sent" snackbar.
            luckyWinCoins > 0
                ? '🎉 Lucky win! You won $luckyWinCoins coins (${luckyMultiplier}×)!'
                : (gift['emoji']?.toString() ?? '🎁') +
                    ' ' +
                    displayGiftName +
                    ' sent • ' +
                    sentTotal.toString() +
                    ' coins',
          ),
        ),
      );
      return true;
    }
    if (!mounted) return false;
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
    return false;
  }

  void _startGiftComboTimer() {
    // Combo (Vinay, 2026-11-21): a new key restarts the 5s ring around
    // the button. If the button is not touched again within 5s, the
    // ring drains to zero and the bubble disappears (onEnd below).
    if (!mounted) return;
    setState(() => _giftComboTimerKey++);
  }

  void _hideGiftCombo() {
    if (!mounted) return;
    setState(() {
      _giftComboGifts = null;
      _giftComboRecipientIds = null;
      _giftComboTotal = 0;
    });
  }

  /// Gift combo (Vinay, 2026-11-21): re-sends the last gift-box gift to
  /// the same users, as many times as the user wants, inside the 5s
  /// window. Each press sends the same batch again (users x combo
  /// count) and restarts the 5s timer. To change users, re-select from
  /// the gift box (a new gift-box send replaces this combo).
  Future<void> _sendGiftCombo() async {
    final gifts = _giftComboGifts;
    final recipientIds = _giftComboRecipientIds;
    if (gifts == null ||
        gifts.isEmpty ||
        recipientIds == null ||
        recipientIds.isEmpty) {
      return;
    }
    // Touching the combo button restarts the 5s timer, whether or not
    // this press can afford the send.
    _startGiftComboTimer();
    if (!widget.state.backendConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to the server to send a gift')),
      );
      return;
    }
    final totalCost = gifts.fold<int>(
          0,
          (total, gift) =>
              total + (int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0),
        ) *
        recipientIds.length *
        _giftComboCount;
    if (widget.state.coins < totalCost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not enough coins — need $totalCost, you have ${widget.state.coins}.',
          ),
        ),
      );
      return;
    }
    var sentCopies = 0;
    // Split send (Vinay, 2026-11-22): same as the gift-box bulk send —
    // fly-effect gifts play ONE split effect for the whole batch below
    // (one gift in the centre that splits to every receiver's DP);
    // video/GLB gifts keep their per-recipient dialog.
    final flyGifts = <Map<String, dynamic>>[];
    for (final gift in gifts) {
      final isFlyGift =
          (gift['video_key']?.toString().trim() ?? '').isEmpty &&
              (gift['glb_key']?.toString().trim() ?? '').isEmpty;
      for (final id in recipientIds) {
        if (!mounted) return;
        final sent = await _sendGiftByDefinition(
          gift,
          id,
          count: _giftComboCount,
          playEffect: !isFlyGift,
        );
        if (!sent) return;
        sentCopies += _giftComboCount;
      }
      if (isFlyGift) flyGifts.add(gift);
    }
    if (mounted && flyGifts.isNotEmpty && sentCopies > 0) {
      for (final gift in flyGifts) {
        final displayGift = Map<String, dynamic>.from(gift);
        if (_giftComboCount > 1) {
          displayGift['name'] =
              '${gift['name'] ?? 'Gift'} x$_giftComboCount';
          displayGift['count'] = _giftComboCount;
        }
        _playGiftEffect(
          displayGift,
          receiverId: recipientIds.first,
          receiverIds: recipientIds,
          senderId: widget.state.userId,
        );
      }
      final firstReceiver = membersBySeat.values.firstWhere(
        (member) => member['user_id']?.toString() == recipientIds.first,
        orElse: () => <String, dynamic>{},
      );
      final firstReceiverName = (firstReceiver['display_name'] ??
              firstReceiver['name'] ??
              firstReceiver['nickname'] ??
              (recipientIds.first == widget.state.userId
                  ? widget.state.displayName
                  : recipientIds.first))
          .toString();
      final firstGift = flyGifts.first;
      _showGiftRibbon(
        event: <String, dynamic>{
          'gift_name': _giftComboCount > 1
              ? '${firstGift['name'] ?? 'Gift'} x$_giftComboCount'
              : (firstGift['name'] ?? 'Gift').toString(),
        },
        senderName: widget.state.displayName,
        receiverName: firstReceiverName,
        giftName: _giftComboCount > 1
            ? '${firstGift['name'] ?? 'Gift'} x$_giftComboCount'
            : (firstGift['name'] ?? 'Gift').toString(),
      );
    }
    if (mounted && sentCopies > 0) {
      setState(() => _giftComboTotal += sentCopies);
      _startGiftComboTimer();
    }
  }

  Future<void> _sendGift() async {
    if (!widget.state.backendConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to the server to send a gift')),
      );
      return;
    }

    // Open the complete Gift Box first: recipient DPs and all seven category
    // chips are visible together, and the user chooses recipients in that box.
    await _sendGiftToSeatUser('');
  }

  Future<void> _sendInlineMessage([String? override]) async {
    if (roomMessageSending) return;
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

    if (mounted) setState(() => roomMessageSending = true);
    try {
      if (widget.state.backendConnected) {
        final result = await widget.state.backend.sendRoomMessageResult(
          roomId: widget.room.id,
          userId: widget.state.userId,
          text: value,
        );
        if (result == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message was not sent. Check your connection.'),
              ),
            );
          }
          return;
        }

        roomChatController.clear();
        if (!mounted) return;
        final serverMessage = result['message'];
        final message = serverMessage is Map
            ? Map<String, dynamic>.from(serverMessage)
            : <String, dynamic>{
                'id': result['message_id'],
                'user_id': widget.state.userId,
                'display_name': widget.state.displayName,
                'text': value,
                'created_at': result['created_at'],
                'active_bubble_id': widget.state.activeCosmetic('bubble'),
              };
        message['display_name'] ??= widget.state.displayName;
        message['active_bubble_id'] ??= widget.state.activeCosmetic('bubble');
        final id = message['id']?.toString();
        if (id == null ||
            id.isEmpty ||
            !chat.any((item) => item['id']?.toString() == id)) {
          setState(() => chat.add(message));
        }
        _scrollChatToLatest();
        unawaited(_loadRoomMessages());
        return;
      }

      if (!mounted) return;
      roomChatController.clear();
      setState(() => chat.add(<String, dynamic>{
            'user_id': widget.state.userId,
            'display_name': widget.state.displayName,
            'text': value,
            'active_bubble_id': widget.state.activeCosmetic('bubble'),
          }));
      _scrollChatToLatest();
    } finally {
      if (mounted) setState(() => roomMessageSending = false);
    }
  }

  /// Emoji panel with two tabs: "Emoji" (the unicode emojis, inserted
  /// into the chat text field as before) and "Panda" (the 20 full-body
  /// panda emotes). Tapping a panda emote sends it at once — the
  /// `[panda:<name>]` marker goes out as a room message and the panda
  /// VAP video plays on the sender's seat, above the DP. The marker
  /// text is never shown in the chat.
  Future<void> _showEmojiPicker() async {
    const emojis = <String>[
      '😀', '😂', '😍', '🥰', '😎', '🥳', '😭', '😡',
      '❤️', '🔥', '👏', '👍', '🎉', '🎁', '⭐', '💯',
      '🌹', '💎', '👑', '🎤', '🎵', '🤝', '😘', '🙏',
    ];
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DefaultTabController(
          length: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  labelColor: TinniPalette.brightGold,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: TinniPalette.brightGold,
                  tabs: [
                    Tab(text: 'Emoji'),
                    Tab(text: '🐼 Panda'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 340,
                  child: TabBarView(
                    children: [
                      // Emoji tab: unicode emojis, inserted into the
                      // chat text field (unchanged behaviour).
                      GridView.count(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final value in emojis)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  Navigator.pop(sheetContext, value),
                              child: Center(
                                child: Text(
                                  value,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Panda tab: the 20 full-body panda emotes.
                      // Tapping one returns its marker, which the
                      // caller sends at once as a seat reaction.
                      GridView.count(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.72,
                        children: [
                          for (final name in kPandaEmoteNames)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.pop(
                                sheetContext,
                                pandaEmoteMarkerForName(name),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        pandaEmoteThumbUrlForName(name) ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                          child: Text(
                                            '🐼',
                                            style: TextStyle(fontSize: 28),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    kPandaEmoteLabels[name] ?? name,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
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
    if (result == null || !mounted) return;
    // A panda marker is sent at once as a seat reaction; a unicode
    // emoji is inserted into the chat text field as before.
    final String? pandaName = pandaEmoteNameFromMarker(result);
    if (pandaName != null) {
      final String? marker = pandaEmoteMarkerForName(pandaName);
      if (marker != null) unawaited(_sendInlineMessage(marker));
      return;
    }
    roomChatController
      ..text += result
      ..selection = TextSelection.collapsed(
        offset: roomChatController.text.length,
      );
  }

  Future<void> _openRoomInbox() async {
    await widget.state.refreshInbox();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MessagesScreen(
          state: widget.state,
          standalone: true,
        ),
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
    // Same gates as text messages: a chat-banned user must not reach the
    // picker at all — the old code uploaded the image to R2 first and
    // only failed at send time, leaving an orphaned file behind.
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
      final result = await widget.state.backend.sendRoomMessageResult(
        roomId: widget.room.id,
        userId: widget.state.userId,
        imageKey: key,
      );
      if (result == null) throw StateError('send_failed');
      if (!mounted) return;
      final serverMessage = result['message'];
      final message = serverMessage is Map
          ? Map<String, dynamic>.from(serverMessage)
          : <String, dynamic>{
              'id': result['message_id'],
              'user_id': widget.state.userId,
              'display_name': widget.state.displayName,
              'text': '',
              'image_key': key,
              'created_at': result['created_at'],
              'active_bubble_id': widget.state.activeCosmetic('bubble'),
            };
      message['display_name'] ??= widget.state.displayName;
      message['image_key'] ??= key;
      final id = message['id']?.toString();
      if (id == null ||
          id.isEmpty ||
          !chat.any((item) => item['id']?.toString() == id)) {
        setState(() => chat.add(message));
      }
      _scrollChatToLatest();
      unawaited(_loadRoomMessages());
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
    final adapter = rtc;
    final engine = adapter is AgoraRtcAdapter ? adapter.engine : null;
    if (adapter is! AgoraRtcAdapter || engine == null) {
      return const SizedBox.shrink();
    }
    final entries = <MapEntry<String, int>>[];
    if (adapter.publishingCamera) {
      entries.add(const MapEntry<String, int>('You', 0));
    }
    for (final uid in adapter.remoteVideoUids) {
      entries.add(MapEntry<String, int>(adapter.accountForUid(uid), uid));
    }
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
          final controller = entry.value == 0
              ? VideoViewController(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: 0),
                )
              : VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: entry.value),
                  connection: adapter.connection,
                );
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
                      child: AgoraVideoView(controller: controller),
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
    final typingMode = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_minimizeRoom());
      },
      child: Scaffold(
      resizeToAvoidBottomInset: false,
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
                    'ID ${formatPublicUserId(widget.room.roomNumber)} • ${switch (roomMode) { 'game' => 'Game Room', 'live' => 'Live Room', _ => 'Voice Room' }} • ${roomPartyMode == 'Event hosting mode' ? 'Event Mode' : 'Friends Party'} • $voiceStatus',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: rtc is AgoraRtcAdapter ? _toggleSpeaker : null,
            tooltip: speakerphoneOn ? 'Use earpiece' : 'Use speaker',
            icon: TinniGlowIcon(
              icon: speakerphoneOn
                  ? Icons.volume_up_rounded
                  : Icons.hearing_rounded,
              size: 18,
              boxSize: 34,
            ),
          ),
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
                // Month's top gifter (Vinay, 2026-11-21): their ID shows
                // here for the month, and disappears the moment they exit
                // the room (see _monthTopGifterInRoom). Tapping opens the
                // ranking page on the Monthly tab.
                if (_monthTopGifterInRoom != null) ...[
                  const SizedBox(width: 6),
                  TinniPanel(
                    key: const Key('room-header-top-gifter'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    onTap: () =>
                        _openRoomGiftRanking(initialPeriod: 'month'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 15,
                          color: TinniPalette.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ID ${formatPublicUserId(_monthTopGifterInRoom!['public_id'])}',
                          style: const TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          // Top-of-room banner (Vinay, 2026-11-22): the 2-line banner
          // for every event (gift, Lucky win, Rocket, VIP entry). One
          // message at a time, rotating; hidden when the queue is
          // empty. Gated by the Game Banner toggle (top-of-room banner).
          if (effectsEnabled &&
              gameBannerEnabled &&
              _currentTopBanner != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
              // Slide animation (Oyaar video, Vinay 2026-11-22): the
              // banner slides in from the right and out to the left.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(position: offset, child: child);
                },
                child: TopRoomBanner(
                  key: ValueKey(_currentTopBanner!['text']?.toString() ?? ''),
                  text: _currentTopBanner!['text']?.toString() ?? '',
                  kind: _currentTopBanner!['kind'] as TopBannerKind? ??
                      TopBannerKind.event,
                  rocketLevel: _currentTopBanner!['rocket_level'] as int?,
                  avatarUrl: _currentTopBanner!['avatar_url']?.toString(),
                  onTap: _currentTopBanner!['room_id']?.toString().isNotEmpty ==
                          true
                      ? () => _onTopBannerTap(
                            _currentTopBanner!['room_id'].toString(),
                          )
                      : null,
                ),
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
                  final activeFrameAssetKey =
                      member?['active_frame_asset_key']?.toString().trim() ?? '';
                  final activeEntry = mine
                      ? widget.state.activeCosmetic('entry')
                      : member?['active_entry_id']?.toString();
                  // Animal frame URL: the member payload's asset key first
                  // (equipped custom frame, or the worker's animal-frame
                  // fallback); otherwise the level's animal frame still,
                  // direct from R2. frames/ keys must NOT go through
                  // backend.fileUrl() — /api/files rejects them.
                  final String? seatFrameAssetUrl =
                      activeFrameAssetKey.isNotEmpty
                          ? resolveVipVisualAssetUrl(
                              activeFrameAssetKey,
                              widget.state.backend.fileUrl,
                            )
                          : vipFrameStillUrlForVipLevel(vipLevel);
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
                  final memberId = member?['user_id']?.toString() ?? '';
                  final seatUserId = memberId.isNotEmpty
                      ? memberId
                      : (mine ? widget.state.userId : '');
                  final seatReaction = activeSeatReactions[seatUserId];
                  final seatPandaEmote = activeSeatPandaEmotes[seatUserId];
                  final seatPandaEmoteMessageId =
                      activeSeatPandaEmoteMessageIds[seatUserId];
                  final speakingUserId = memberId.isNotEmpty
                      ? memberId
                      : (mine ? widget.state.userId : null);
                  final isMicBlocked = mine
                      ? muted
                      : (!micOn || roomMutedSeats.contains(seat));
                  final showGiftImpact = memberId.isNotEmpty &&
                      activeGiftReceiverIds.contains(memberId) &&
                      activeGiftEffect != null &&
                      effectsEnabled &&
                      giftEffectsEnabled;

                  return SizedBox(
                    width: seatWidth,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => unawaited(_tapSeat(seat)),
                      onLongPress: () {
                        if (isRoomAdmin) {
                          unawaited(_showSeatControls(seat));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Only the room owner or room admin can control seats.',
                              ),
                            ),
                          );
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
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
                                    ? VipAnimatedFrame.auto(
                                        // Auto-sizing: the frame reads the
                                        // seat diameter at runtime (the seat
                                        // container is diameter x diameter)
                                        // and scales ring/gems/head/plate
                                        // proportionally. No fixed size.
                                        enabled: activeFrame != null ||
                                            seatFrameAssetUrl != null ||
                                            vipLevel >= 7 ||
                                            (vipLevel >= 16 && micOn),
                                        level: frameTier,
                                        styleId: activeFrame,
                                        assetUrl: seatFrameAssetUrl,
                                        // VAP alpha-video: only when the
                                        // frame shown IS the animal frame
                                        // (custom frames have no VAP video
                                        // and show the still).
                                        videoUrl: vipFrameVapUrlForDisplay(
                                          activeFrameAssetKey,
                                          vipLevel,
                                        ),
                                        assetHeaders: widget.state.backend.fileHeaders,
                                        child: CircleAvatar(
                                          radius: (diameter / 2) - 1,
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
                                              if (showGiftImpact)
                                                Positioned.fill(
                                                  child: _buildSeatGiftImpactEffect(
                                                    diameter,
                                                  ),
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
                                            ? TinniPalette.brightGold
                                            : TinniPalette.cream,
                                      ),
                              ),
                              if (seatReaction != null)
                                Positioned(
                                  top: -(compactSeats ? 15.0 : 22.0),
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: const Color(0xCC15102E),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: TinniPalette.brightGold,
                                          width: .8,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x665A2DFF),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          compactSeats ? 2 : 4,
                                        ),
                                        child: Text(
                                          seatReaction,
                                          style: TextStyle(
                                            fontSize: compactSeats ? 13 : 20,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Panda seat emote: the full-body panda
                              // VAP video plays above the DP, bigger
                              // than the text-emoji badge (the panda is
                              // the big animated reaction). It plays
                              // once and clears itself via onDone.
                              if (seatPandaEmote != null &&
                                  seatPandaEmoteMessageId != null)
                                Positioned(
                                  bottom: diameter - (compactSeats ? 6.0 : 10.0),
                                  child: IgnorePointer(
                                    child: SeatPandaEmote(
                                      key: ValueKey<String>(
                                        'panda-$seatUserId-$seatPandaEmoteMessageId',
                                      ),
                                      videoUrl: pandaEmoteVapUrlForName(
                                            seatPandaEmote,
                                          ) ??
                                          '',
                                      width: compactSeats ? 64 : 96,
                                      height: compactSeats ? 114 : 170,
                                      onDone: () => _clearSeatPandaEmote(
                                        seatUserId,
                                        seatPandaEmoteMessageId,
                                      ),
                                    ),
                                  ),
                                ),
                              if (speakingUserId != null)
                                Positioned(
                                  left: -(compactSeats ? 9.0 : 12.0),
                                  top: -(compactSeats ? 9.0 : 12.0),
                                  child: IgnorePointer(
                                    child: ValueListenableBuilder<
                                        Map<String, double>>(
                                      valueListenable:
                                          rtc?.speakingLevelsListenable ??
                                              _silentSpeakingLevels,
                                      builder: (context, levels, child) {
                                        final level =
                                            levels[speakingUserId] ?? 0.0;
                                        if (isMicBlocked || level <= 0) {
                                          return const SizedBox.shrink();
                                        }
                                        return _LiveMicWaves(
                                          level: level,
                                          compact: compactSeats,
                                          diameter: diameter,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: compactSeats ? 1 : 3),
                          if (activeEntry != null &&
                              activeEntry.startsWith('entrance-vip-'))
                            EntranceNameplatePreview(
                              compact: true,
                              styleId: activeEntry,
                              displayName: mine
                                  ? (widget.state.vipAnonymousEverywhere
                                      ? 'Anonymous'
                                      : widget.state.displayName)
                                  : (member?['display_name']?.toString() ??
                                      'No.${seat + 1}'),
                              vipLevel: vipLevel.clamp(1, 18).toInt(),
                            )
                          else
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
                  if (_pinnedPriorityMessage case final priority?)
                    VipPriorityMessageBanner(
                      message: priority,
                      onDismissed: () => setState(
                        () => _dismissedPriorityMessage = priority,
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      key: const Key('room-chat-list'),
                      controller: roomChatScrollController,
                      padding: const EdgeInsets.only(bottom: 14),
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
                        // A panda emote marker ("[panda:happy]") is a seat
                        // reaction, not chat text — the marker itself is
                        // never shown; the chat line reads as an emote
                        // action instead, while the panda video plays on
                        // the sender's seat.
                        final String rawText =
                            message['text']?.toString() ?? '';
                        final String? pandaMarkerName =
                            pandaEmoteNameFromMarker(rawText);
                        final text = pandaMarkerName != null
                            ? '🐼 sent a panda emote (${kPandaEmoteLabels[pandaMarkerName] ?? pandaMarkerName})'
                            : rawText;
                        final imageKey = message['image_key']?.toString();
                        final senderId = message['user_id']?.toString() ?? '';
                        // The message carries the sender's active VIP level;
                        // the header resolves the animal frame + golden tag
                        // from it (frame still = direct R2 URL).
                        final senderVipLevel =
                            int.tryParse(message['active_vip_level']?.toString() ?? '') ?? 0;
                        final bubbleId = senderId == widget.state.userId
                            ? widget.state.activeCosmetic('bubble')
                            : message['active_bubble_id']?.toString();
                        final bubbleAssetKey =
                            message['active_bubble_asset_key']?.toString().trim() ?? '';
                        final hasBubble =
                            (bubbleId != null && bubbleId.isNotEmpty) ||
                            bubbleAssetKey.isNotEmpty;
                        final effectiveBubbleId = bubbleId?.isNotEmpty == true
                            ? bubbleId!
                            : 'bubble-dream';
                        final messageContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (text.isNotEmpty)
                              hasBubble
                                  ? BubbleChatText(text: text)
                                  : Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            if (imageKey != null && imageKey.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    widget.state.backend.fileUrl(imageKey),
                                    width: 192,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
                                      width: 192,
                                      height: 64,
                                      child: Center(
                                        child: Text('Photo unavailable'),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                        final rawTags = message['profile_tags'];
                        final profileTags = rawTags is List
                            ? rawTags
                                .whereType<Map>()
                                .map((tag) => Map<String, dynamic>.from(tag))
                                .toList(growable: false)
                            : const <Map<String, dynamic>>[];
                        final rawMedals = message['medals'];
                        final profileMedals = rawMedals is List
                            ? rawMedals
                                .whereType<Map>()
                                .map((medal) => Map<String, dynamic>.from(medal))
                                .toList(growable: false)
                            : const <Map<String, dynamic>>[];
                        final avatarKey = message['avatar_key']?.toString().trim() ?? '';
                        final messageBubble = hasBubble
                            ? bubbleAssetKey.isNotEmpty
                                // Custom uploaded bubble art supplies its own
                                // outline: show it as before.
                                ? StretchableCosmeticBubble(
                                    styleId: effectiveBubbleId,
                                    assetImageUrl: widget.state.backend
                                        .fileUrl(bubbleAssetKey),
                                    assetImageHeaders:
                                        widget.state.backend.fileHeaders,
                                    maxWidth: 280,
                                    minWidth: 100,
                                    minHeight: 44,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 44,
                                      vertical: 10,
                                    ),
                                    child: messageContent,
                                  )
                                : VipChatBubble(
                                    styleId: effectiveBubbleId,
                                    maxWidth: 280,
                                    minWidth: 100,
                                    minHeight: 44,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 44,
                                      vertical: 10,
                                    ),
                                    child: messageContent,
                                  )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 280),
                                child: messageContent,
                              );
                        return Padding(
                          key: Key('room-chat-message-$index'),
                          // Keep every room message visually separate and
                          // reserve the floating Rocket/Game lane on the right.
                          padding: const EdgeInsets.fromLTRB(0, 7, 76, 7),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RoomChatSenderHeader(
                                    displayName: name == null || name.isEmpty
                                        ? 'User'
                                        : name,
                                    avatarUrl: avatarKey.isEmpty
                                        ? null
                                        : widget.state.backend.fileUrl(avatarKey),
                                    avatarHeaders: widget.state.backend.fileHeaders,
                                    tags: profileTags,
                                    medals: profileMedals,
                                    vipLevel: senderVipLevel,
                                    // Animal frame still (VIP5-18) with its
                                    // VAP alpha-video; the frame animates
                                    // once and then shows the still.
                                    frameAssetUrl: vipFrameStillUrlForVipLevel(senderVipLevel),
                                    frameVideoUrl: vipFrameVapUrlForVipLevel(senderVipLevel),
                                    // Tapping the sender's DP or name in
                                    // room chat opens their profile card
                                    // (Vinay, 2026-11-20); tapping the card
                                    // itself opens their main profile page.
                                    onAvatarTap: senderId.isEmpty
                                        ? null
                                        : () => _openRoomUserProfile(
                                              senderId,
                                              name,
                                              avatarKey,
                                            ),
                                  ),
                                  const SizedBox(height: 4),
                                  messageBubble,
                                ],
                              ),
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
          // Rocket/Game Center buttons are navigation, not a banner —
          // the Rocket Banner toggle only hides the rocket launch
          // animation, never these buttons (Vinay, 2026-11-22).
          if (!typingMode && effectsEnabled)
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
                    child: RoomStealthRocketLogo(
                      size: 42,
                      level: _currentRocketLevel,
                    ),
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
          if (_giftComboGifts != null &&
              _giftComboGifts!.isNotEmpty &&
              _giftComboRecipientIds != null &&
              _giftComboRecipientIds!.isNotEmpty)
            Positioned(
              // Gift combo (Vinay, 2026-11-21; Bigo reference): below the
              // Rocket, slightly to the right, a BIG prominent button —
              // Bigo's is a large red "Combo" button pressed again and
              // again while the multiplier climbs. The count above the
              // button shows how many copies were sent in this combo.
              // The gold ring drains over 5s; untouched for 5s and the
              // bubble disappears. Every touch restarts the ring.
              right: 2,
              bottom: 34,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const Key('room-gift-combo-count'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1A1022),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TinniPalette.brightGold),
                    ),
                    child: Text(
                      'x$_giftComboTotal',
                      style: const TextStyle(
                        color: TinniPalette.brightGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    key: ValueKey<int>(_giftComboTimerKey),
                    tween: Tween<double>(begin: 1, end: 0),
                    duration: const Duration(seconds: 5),
                    onEnd: _hideGiftCombo,
                    builder: (context, value, child) {
                      return SizedBox(
                        width: 76,
                        height: 76,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 76,
                              height: 76,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 3,
                                color: TinniPalette.brightGold,
                                backgroundColor: const Color(0x33FFFFFF),
                              ),
                            ),
                            child!,
                          ],
                        ),
                      );
                    },
                    child: Semantics(
                      button: true,
                      label: 'Gift combo',
                      child: InkResponse(
                        key: const Key('room-gift-combo-button'),
                        radius: 36,
                        onTap: _sendGiftCombo,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: <Color>[
                                Color(0xFFFF5252),
                                Color(0xFFFFB300),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: TinniPalette.brightGold,
                              width: 2,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x88FF5252),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _giftComboGifts!.first['emoji']?.toString() ??
                                    '🎁',
                                style: const TextStyle(fontSize: 24),
                              ),
                              const Text(
                                'Combo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (activeGiftRibbon != null && effectsEnabled && giftBannerEnabled)
            Positioned(
              // Gift ribbon banner (sender's VIP tier): full-width
              // banner with the VIP level BIG and bold, sender ->
              // receiver, and the gift name. An addition to the gift
              // effect bar below — never a replacement for it.
              left: 12,
              right: 12,
              bottom: 220,
              child: IgnorePointer(
                child: GiftRibbonBanner(
                  key: const Key('room-gift-ribbon'),
                  vipLevel: int.tryParse(
                        activeGiftRibbon?['vip_level']?.toString() ?? '',
                      ) ??
                      0,
                  senderName: activeGiftRibbon?['sender_name']?.toString() ??
                      'User',
                  receiverName:
                      activeGiftRibbon?['receiver_name']?.toString() ??
                          'User',
                  giftName:
                      activeGiftRibbon?['gift_name']?.toString() ?? 'Gift',
                  ribbonUrl:
                      activeGiftRibbon?['ribbon_url']?.toString(),
                ),
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
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: CircleAvatar(
                                backgroundColor: TinniPalette.panel2,
                                backgroundImage:
                                    activeGiftReceiverAvatarKey != null &&
                                            activeGiftReceiverAvatarKey!
                                                .isNotEmpty
                                        ? NetworkImage(
                                            widget.state.backend.fileUrl(
                                              activeGiftReceiverAvatarKey!,
                                            ),
                                            headers:
                                                widget.state.backend.fileHeaders,
                                          )
                                        : null,
                                child: activeGiftReceiverAvatarKey == null ||
                                        activeGiftReceiverAvatarKey!.isEmpty
                                    ? const Icon(Icons.person_rounded)
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: -5,
                              bottom: -5,
                              child: Container(
                                width: 25,
                                height: 25,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF35103F),
                                  border: Border.all(
                                    color: TinniPalette.brightGold,
                                  ),
                                ),
                                child: Text(
                                  activeGiftEffect?['emoji']?.toString() ??
                                      '🎁',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
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
          // VIP entry banner (entry effect, Vehicle Effect toggle):
          // the Game Banner toggle controls the 2-line top banner,
          // not this entry effect — it is gated by the vehicle
          // effect (or the built-in VIP entrance effect) only.
          if (arrivalEffectMember != null && effectsEnabled &&
              (carEffectsEnabled ||
                  (arrivalEffectMember?['active_entry_id']?.toString() ?? '')
                      .startsWith('entrance-vip-')) &&
              (int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0) >= 5)
            Positioned(
              // Animal entry banner (VIP5-18): full-width top banner with
              // the arriving user's DP in its transparent circle. Sizes
              // itself to the room width (aspect ratio per level).
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: VipEntryEffectBanner(
                  vipLevel: int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0,
                  avatarUrl: (arrivalEffectMember?['avatar_key']?.toString().trim().isNotEmpty == true)
                      ? widget.state.backend.fileUrl(arrivalEffectMember!['avatar_key'].toString())
                      : null,
                  avatarHeaders: widget.state.backend.fileHeaders,
                ),
              ),
            ),
          if (arrivalEffectMember != null && effectsEnabled &&
              (carEffectsEnabled ||
                  (arrivalEffectMember?['active_entry_id']?.toString() ?? '')
                      .startsWith('entrance-vip-')))
            Builder(
              builder: (context) {
                final int arrivalVipLevel =
                    int.tryParse(arrivalEffectMember?['active_vip_level']?.toString() ?? '') ?? 0;
                final Size arrivalScreenSize = MediaQuery.sizeOf(context);
                // Animal vehicle layout (Vinay, 2026-11-18): VIP5-15
                // bottom-anchored, 40% of screen height; VIP16-18
                // full-screen. entryRectForVipLevel() is the single
                // source of truth; the fallback matches it exactly.
                final Rect arrivalRect =
                    entryRectForVipLevel(arrivalVipLevel, arrivalScreenSize) ??
                        Rect.fromLTWH(
                          0,
                          arrivalScreenSize.height * 0.60,
                          arrivalScreenSize.width,
                          arrivalScreenSize.height * bottomEntryHeightFraction,
                        );
                final String memberVideoKey =
                    ((arrivalEffectMember?['active_vehicle_video_key'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty)
                        ? arrivalEffectMember!['active_vehicle_video_key'].toString()
                        : (arrivalEffectMember?['active_entry_video_key'] ?? '').toString();
                // A custom equipped/Owner video key wins and keeps its
                // Worker /api/files path; otherwise the animal video
                // plays DIRECTLY from R2 (never through /api/files,
                // whose allowlist rejects vehicles/ keys).
                final String? directAnimalVideoUrl =
                    _directAnimalVideoUrlForMember(arrivalEffectMember!);
                return Positioned(
                  left: arrivalRect.left,
                  top: arrivalRect.top,
                  width: arrivalRect.width,
                  height: arrivalRect.height,
                  child: ((arrivalEffectMember?['active_entry_id']?.toString() ?? '')
                          .startsWith('entrance-vip-'))
                      ? IgnorePointer(
                          child: Center(
                            child: EntranceNameplatePreview(
                              styleId: arrivalEffectMember!['active_entry_id'].toString(),
                              displayName: arrivalEffectMember?['display_name']?.toString() ?? 'VIP member',
                              vipLevel: arrivalVipLevel.clamp(1, 18).toInt(),
                            ),
                          ),
                        )
                      : CustomAssetEffectPlayback(
                          backend: widget.state.backend,
                          videoKey: directAnimalVideoUrl != null ? '' : memberVideoKey,
                          directVideoUrl: directAnimalVideoUrl,
                          glbKey: ((arrivalEffectMember?['active_vehicle_glb_key'] ?? '').toString().trim().isNotEmpty)
                              ? arrivalEffectMember!['active_vehicle_glb_key'].toString()
                              : (arrivalEffectMember?['active_entry_glb_key'] ?? '').toString(),
                          fallback: VehicleEntryEffect(
                            displayName: (arrivalEffectMember?['display_name']?.toString().trim().isNotEmpty == true)
                                ? arrivalEffectMember!['display_name'].toString()
                                : 'VIP member',
                            level: arrivalVipLevel,
                            showVehicle: true,
                            customVehicle: arrivalEffectMember?['active_vehicle_id']?.toString() == 'vehicle_dragon' ||
                                arrivalEffectMember?['active_entry_id'] != null ||
                                arrivalVipLevel >= 18,
                            vehicleId: (arrivalEffectMember?['active_vehicle_id']?.toString().trim().isNotEmpty == true)
                                ? arrivalEffectMember!['active_vehicle_id'].toString()
                                : arrivalEffectMember?['active_entry_id']?.toString(),
                            vehicleLabel: arrivalEffectMember?['active_vehicle_id']?.toString() ?? 'VEHICLE ENTRY',
                          ),
                        ),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
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
                    key: const Key('room-chat-composer'),
                    controller: roomChatController,
                    enabled: !chatBanned && (publicScreenEnabled || isRoomAdmin),
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 200,
                    scrollPadding: const EdgeInsets.only(bottom: 96),
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
                              : 'Type a message'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                    ),
                    onTap: () {
                      Future<void>.delayed(
                        const Duration(milliseconds: 220),
                        _scrollChatToLatest,
                      );
                    },
                    onSubmitted: (_) => _sendInlineMessage(),
                  ),
                ),
                if (typingMode)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: roomChatController,
                    builder: (context, value, child) {
                      if (value.text.trim().isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        key: const Key('room-chat-send-button'),
                        tooltip: 'Send',
                        onPressed: roomMessageSending
                            ? null
                            : () => _sendInlineMessage(),
                        icon: const TinniGlowIcon(
                          icon: Icons.send_rounded,
                          size: 20,
                          boxSize: 36,
                        ),
                      );
                    },
                  ),
                if (!typingMode) ...<Widget>[
                  IconButton(
                    tooltip: 'Emoji & Emotes',
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _showEmojiPicker();
                    },
                    icon: const TinniGlowIcon(
                      icon: Icons.emoji_emotions_rounded,
                      size: 20,
                      boxSize: 36,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Microphone',
                    onPressed: mySeat == null
                        ? null
                        : () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            _toggleMic();
                          },
                    icon: TinniGlowIcon(
                      icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: 20,
                      boxSize: 36,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gifts',
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _sendGift();
                    },
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
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}


class _LiveMicWaves extends StatefulWidget {
  const _LiveMicWaves({
    required this.level,
    required this.compact,
    required this.diameter,
  });

  final double level;
  final bool compact;
  final double diameter;

  @override
  State<_LiveMicWaves> createState() => _LiveMicWavesState();
}

class _LiveMicWavesState extends State<_LiveMicWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerPadding = widget.compact ? 9.0 : 12.0;
    final size = Size.square(widget.diameter + outerPadding * 2);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          size: size,
          painter: _LiveMicWavePainter(
            level: widget.level,
            phase: _controller.value,
            compact: widget.compact,
            avatarDiameter: widget.diameter,
          ),
        ),
      ),
    );
  }
}

class _LiveMicWavePainter extends CustomPainter {
  const _LiveMicWavePainter({
    required this.level,
    required this.phase,
    required this.compact,
    required this.avatarDiameter,
  });

  final double level;
  final double phase;
  final bool compact;
  final double avatarDiameter;

  @override
  void paint(Canvas canvas, Size size) {
    final normalized = level.clamp(0.0, 1.0).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final outerPadding = compact ? 9.0 : 12.0;
    final baseRadius = avatarDiameter / 2 + (compact ? 1.2 : 1.8);
    final liveColor = Color.lerp(
      Color(0xFF8B7CFF),
      const Color(0xFF56F2C2),
      (.30 + normalized * .70).clamp(0.0, 1.0),
    )!;

    final edgePaint = Paint()
      ..color = liveColor.withValues(
        alpha: (.30 + normalized * .55).clamp(.30, .90),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = (compact ? 1.15 : 1.45) + normalized * .85;
    canvas.drawCircle(center, baseRadius, edgePaint);

    for (var index = 0; index < 3; index++) {
      final progress = (phase + index / 3) % 1.0;
      final radius = baseRadius + progress * outerPadding;
      final fade = 1.0 - progress;
      final opacity =
          (fade * (.20 + normalized * .68)).clamp(0.0, .88);
      if (opacity <= .02) continue;
      final wavePaint = Paint()
        ..color = liveColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            (compact ? 1.0 : 1.25) + normalized * (compact ? .75 : 1.05);
      canvas.drawCircle(center, radius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveMicWavePainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.compact != compact ||
        oldDelegate.avatarDiameter != avatarDiameter;
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
          Color(0xFFEAF5FF),
          Color(0xFF53D9FF),
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
      ..color = Color(0xFF50D8FF)
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
      Paint()..color = Color(0xFFEAF5FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
