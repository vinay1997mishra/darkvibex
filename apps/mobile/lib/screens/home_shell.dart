import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import '../i18n/darkvibex_localization.dart';
import '../ui/tinni_style.dart';
import '../vip/vip_policy.dart';
import 'messages_screen.dart';
import 'mine_social_screens.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';
import 'gifts_screen.dart';
import 'vip_screen.dart';
import 'room_screen.dart';
import 'weekly_sign_in_dialog.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.state,
    this.minimizedRoom,
    this.onResumeRoom,
    this.onCloseMinimizedRoom,
  });

  final AppState state;
  final RoomSummary? minimizedRoom;
  final VoidCallback? onResumeRoom;
  final Future<void> Function()? onCloseMinimizedRoom;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final Set<int> visited = <int>{0};
  bool _weeklyDialogScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_weeklyStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleWeeklySignIn();
    });
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) return;
    oldWidget.state.removeListener(_weeklyStateChanged);
    widget.state.addListener(_weeklyStateChanged);
    _weeklyDialogScheduled = false;
    _scheduleWeeklySignIn();
  }

  @override
  void dispose() {
    widget.state.removeListener(_weeklyStateChanged);
    super.dispose();
  }

  void _weeklyStateChanged() {
    if (!mounted) return;
    _scheduleWeeklySignIn();
  }

  void _scheduleWeeklySignIn() {
    if (!mounted ||
        _weeklyDialogScheduled ||
        !widget.state.weeklySignInReady ||
        widget.state.weeklySignInClaimedToday) {
      return;
    }
    _weeklyDialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showWeeklySignInDialog(context, state: widget.state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _RoomsHome(
        state: widget.state,
        onSelect: (value) => setState(() {
          index = value;
          visited.add(value);
        }),
      ),
      _DiscoverHome(state: widget.state),
      MessagesScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: index,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    visited.contains(i) ? pages[i] : const SizedBox.shrink(),
                ],
              ),
            ),
            if (widget.minimizedRoom != null)
              Positioned.fill(
                child: MinimizedRoomBubble(
                  state: widget.state,
                  room: widget.minimizedRoom!,
                  onResume: widget.onResumeRoom,
                  onClose: widget.onCloseMinimizedRoom,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF17130D),
              TinniPalette.nearBlack,
              TinniPalette.black,
            ],
          ),
          border: Border(
            top: BorderSide(
              color: TinniPalette.gold.withValues(alpha: .42),
              width: .8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: TinniPalette.gold.withValues(alpha: .08),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: widget.state.languagePreference,
          builder: (context, language, _) => NavigationBar(
            selectedIndex: index,
            backgroundColor: Colors.transparent,
            indicatorColor: TinniPalette.gold.withValues(alpha: .12),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (value) => setState(() {
              index = value;
              visited.add(value);
            }),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.groups_rounded),
                selectedIcon:
                    const TinniGlowIcon(icon: Icons.groups_rounded),
                label: darkVibeXText(language, 'party'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.explore_rounded),
                selectedIcon:
                    const TinniGlowIcon(icon: Icons.explore_rounded),
                label: darkVibeXText(language, 'discover'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.mail_rounded),
                selectedIcon:
                    const TinniGlowIcon(icon: Icons.mail_rounded),
                label: darkVibeXText(language, 'message'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_rounded),
                selectedIcon:
                    const TinniGlowIcon(icon: Icons.person_rounded),
                label: darkVibeXText(language, 'mine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MinimizedRoomBubble extends StatefulWidget {
  const MinimizedRoomBubble({
    required this.state,
    required this.room,
    this.onResume,
    this.onClose,
  });

  final AppState state;
  final RoomSummary room;
  final VoidCallback? onResume;
  final Future<void> Function()? onClose;

  @override
  State<MinimizedRoomBubble> createState() => MinimizedRoomBubbleState();
}

class MinimizedRoomBubbleState extends State<MinimizedRoomBubble> {
  static const double _bubbleExtent = 82;
  Offset? position;
  bool closing = false;

  Offset _clampPosition(Offset value, BoxConstraints constraints) {
    final maxX = (constraints.maxWidth - _bubbleExtent).clamp(4.0, double.infinity);
    final maxY = (constraints.maxHeight - _bubbleExtent).clamp(4.0, double.infinity);
    return Offset(
      value.dx.clamp(4.0, maxX).toDouble(),
      value.dy.clamp(4.0, maxY).toDouble(),
    );
  }

  Future<void> _closeRoom() async {
    if (closing) return;
    setState(() => closing = true);
    try {
      await widget.onClose?.call();
    } finally {
      if (mounted) setState(() => closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultPosition = Offset(
          (constraints.maxWidth - _bubbleExtent - 8)
              .clamp(4.0, double.infinity)
              .toDouble(),
          (constraints.maxHeight * .42)
              .clamp(
                4.0,
                (constraints.maxHeight - _bubbleExtent)
                    .clamp(4.0, double.infinity)
                    .toDouble(),
              )
              .toDouble(),
        );
        final bubblePosition =
            _clampPosition(position ?? defaultPosition, constraints);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: bubblePosition.dx,
              top: bubblePosition.dy,
              width: _bubbleExtent,
              height: _bubbleExtent,
              child: GestureDetector(
                key: const Key('mini-room-bubble'),
                behavior: HitTestBehavior.opaque,
                onTap: closing ? null : widget.onResume,
                onPanUpdate: closing
                    ? null
                    : (details) {
                        setState(() {
                          position = _clampPosition(
                            bubblePosition + details.delta,
                            constraints,
                          );
                        });
                      },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TinniPalette.brightGold,
                            width: 3,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: room.avatarKey == null
                              ? Container(
                                  color: TinniPalette.panel2,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.mic_external_on_rounded,
                                    size: 34,
                                    color: TinniPalette.gold,
                                  ),
                                )
                              : Image.network(
                                  widget.state.backend.fileUrl(room.avatarKey!),
                                  headers: widget.state.backend.fileHeaders,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: TinniPalette.panel2,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.mic_external_on_rounded,
                                      size: 34,
                                      color: TinniPalette.gold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Material(
                        color: const Color(0xE6F4B400),
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('mini-room-bubble-close'),
                          customBorder: const CircleBorder(),
                          onTap: closing ? null : _closeRoom,
                          child: SizedBox(
                            width: 27,
                            height: 27,
                            child: Center(
                              child: closing
                                  ? const SizedBox.square(
                                      dimension: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.close_rounded,
                                      size: 19,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoomsHome extends StatefulWidget {
  const _RoomsHome({required this.state, required this.onSelect});

  final AppState state;
  final ValueChanged<int> onSelect;

  @override
  State<_RoomsHome> createState() => _RoomsHomeState();
}

class _RoomsHomeState extends State<_RoomsHome> {
  AppState get state => widget.state;
  bool popular = true;
  Timer? roomListRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFollowedRooms();
    _loadBanners();
    roomListRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !state.backendConnected) return;
      unawaited(state.refreshRooms());
    });
  }

  @override
  void dispose() {
    roomListRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFollowedRooms() async {
    if (!state.backendConnected) return;
    final rows = await state.backend.followedRooms(userId: state.userId);
    final values = rows.map((row) {
      return RoomSummary(
        id: row['id']?.toString() ?? '',
        displayId: row['display_id']?.toString(),
        name: row['name']?.toString() ?? 'Room',
        ownerName: row['owner_name']?.toString() ?? 'Owner',
        ownerUserId: row['owner_user_id']?.toString() ?? '',
        online: int.tryParse(row['online']?.toString() ?? '') ?? 0,
        seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ?? 12,
        avatarKey: row['avatar_key']?.toString().isNotEmpty == true
            ? row['avatar_key']?.toString()
            : null,
        partyMode:
            row['party_mode']?.toString() ?? 'Friends-making Party',
        roomMode: row['room_mode']?.toString() ?? 'voice',
      );
    }).where((room) => room.id.isNotEmpty).toList(growable: false);
    if (!mounted) return;
    setState(() => followedRooms = values);
  }
  int topPage = 1;
  final List<String> recentRoomIds = <String>[];
  List<RoomSummary> followedRooms = const <RoomSummary>[];
  List<Map<String, dynamic>> ownerBanners = const <Map<String, dynamic>>[];

  Future<void> _loadBanners() async {
    if (!state.backendConnected) return;
    final rows = await state.backend.activeBanners();
    if (!mounted) return;
    setState(() => ownerBanners = rows);
  }

  void _openOwnerBanner(Map<String, dynamic> banner) {
    final link = banner['link']?.toString().trim() ?? '';
    final roomId = link.startsWith('room:') ? link.substring(5).trim() : '';
    if (roomId.isNotEmpty) {
      for (final room in state.rooms) {
        if (room.id == roomId || room.roomNumber == roomId) {
          _openRoom(room);
          return;
        }
      }
    }
    if (link == 'rankings' || link == 'ranking') {
      _openRankings(context);
      return;
    }
    if (link == 'discover') {
      widget.onSelect(1);
    }
  }

  List<RoomSummary> get visibleFollowedRooms {
    final allowed = state.rooms
        .where((room) => room.online > 0)
        .map((room) => room.id)
        .toSet();
    return followedRooms
        .where((room) => allowed.contains(room.id))
        .toList(growable: false);
  }

  Future<void> _openRankings(
    BuildContext context, {
    int initialTab = 1,
  }) async {
    final room = await Navigator.of(context).push<RoomSummary>(
      MaterialPageRoute<RoomSummary>(
        builder: (_) => RankingScreen(
          state: state,
          initialTab: initialTab,
        ),
      ),
    );
    if (!mounted || room == null) return;
    _openRoom(room);
  }

  Future<void> _createRoom(BuildContext context) async {
    // My room is permanent: tapping create again should reopen it, not create
    // another setup flow or a duplicate local entry.
    for (final room in state.rooms) {
      if (room.id.isNotEmpty && room.ownerUserId == state.userId) {
        _openRoom(room);
        return;
      }
    }
    final draft = await showModalBottomSheet<_CreateRoomDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (_) => _CreateRoomSheet(maxSeats: VipPolicy.maxRoomSeats(state.vipLevel)),
    );
    if (draft == null || !context.mounted) return;

    try {
      final created = await state.createRoom(
        draft.title,
        seatCount: draft.seatCount,
        partyMode: draft.partyMode,
        roomMode: draft.roomMode,
      );

      RoomSummary room = created;
      if (draft.avatarBytes != null && draft.avatarBytes!.isNotEmpty) {
        final key = await state.backend.uploadImage(
          key: 'rooms/${created.id}/avatar-${DateTime.now().microsecondsSinceEpoch}.${draft.avatarExtension}',
          bytes: draft.avatarBytes!,
          contentType: draft.avatarContentType,
        );
        if (key != null &&
            await state.backend.setRoomAvatar(
              roomId: created.id,
              userId: state.userId,
              avatarKey: key,
            )) {
          state.setRoomAvatarKey(created.id, key);
          room = RoomSummary(
            id: created.id,
            displayId: created.displayId,
            name: created.name,
            ownerName: created.ownerName,
            ownerUserId: created.ownerUserId,
            online: created.online,
            seatCount: created.seatCount,
            avatarKey: key,
            partyMode: created.partyMode,
            roomMode: created.roomMode,
          );
        }
      }

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomScreen(state: state, room: room),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Room could not be created: ${error.toString().replaceFirst('Bad state: ', '')}',
          ),
        ),
      );
    }
  }

  void _openRoom(RoomSummary room) {
    setState(() {
      recentRoomIds
        ..remove(room.id)
        ..insert(0, room.id);
      if (recentRoomIds.length > 4) {
        recentRoomIds.removeRange(4, recentRoomIds.length);
      }
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(state: state, room: room),
      ),
    ).then((_) async {
      await state.refreshRooms();
      await _loadFollowedRooms();
    });
  }

  Widget _buildPartyPage(BuildContext context) {
    final publicRooms = state.rooms
        .where((room) => room.online > 0)
        .toList(growable: false);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => TinniBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: SizedBox(
                  height: 142,
                  child: PageView(
                    children: [
                      for (final banner in ownerBanners)
                        _OwnerBannerCard(
                          state: state,
                          banner: banner,
                          onTap: () => _openOwnerBanner(banner),
                        ),
                      _PromoCard(
                        title: 'ROYAL PARTY',
                        subtitle: 'Live rooms, rankings and royal rewards',
                        icon: Icons.workspace_premium_rounded,
                        onTap: () => _openRankings(context, initialTab: 0),
                      ),
                      _PromoCard(
                        title: 'WEEKLY STAR',
                        subtitle: 'Weekly rankings and royal rewards',
                        icon: Icons.emoji_events_rounded,
                        onTap: () => _openRankings(context, initialTab: 1),
                      ),
                      _PromoCard(
                        title: 'THE GREAT NAVIGATOR',
                        subtitle: 'Featured rooms and discovery',
                        icon: Icons.explore_rounded,
                        onTap: () => widget.onSelect(1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickCard(
                        label: 'Room',
                        icon: Icons.mic_external_on_rounded,
                        onTap: () => _openRankings(context, initialTab: 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickCard(
                        label: 'CP Ranking',
                        icon: Icons.favorite_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CpRankingScreen(state: state),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickCard(
                        label: 'Family',
                        icon: Icons.groups_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => FamilyRankingScreen(state: state),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('🔥 Popular'),
                      selected: popular,
                      onSelected: (_) => setState(() => popular = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('✨ New'),
                      selected: !popular,
                      onSelected: (_) => setState(() => popular = false),
                    ),
                    const Spacer(),
                    Text(
                      '${publicRooms.length} rooms',
                      style: const TextStyle(
                        color: TinniPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top 3 Rooms',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var rank = 0; rank < 3; rank++) ...[
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final rooms = [...publicRooms];
                                if (popular) {
                                  rooms.sort((a, b) => b.online.compareTo(a.online));
                                } else {
                                  rooms.sort((a, b) => b.id.compareTo(a.id));
                                }
                                if (rank >= rooms.length) {
                                  return const SizedBox.shrink();
                                }
                                return _TopRoomCard(
                                  state: state,
                                  room: rooms[rank],
                                  rank: rank + 1,
                                  onTap: () => _openRoom(rooms[rank]),
                                );
                              },
                            ),
                          ),
                          if (rank != 2) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              sliver: SliverList.separated(
                itemCount: publicRooms.length > 3 ? publicRooms.length - 3 : 0,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, roomIndex) {
                  final rooms = [...publicRooms];
                  if (popular) {
                    rooms.sort((a, b) => b.online.compareTo(a.online));
                  } else {
                    rooms.sort((a, b) => b.id.compareTo(a.id));
                  }
                  final room = rooms[roomIndex + 3];
                  return _RoomCard(
                    state: state,
                    room: room,
                    onTap: () => _openRoom(room),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHomeNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(
                  Icons.notifications_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text(
                  'Notifications',
                  style: TextStyle(
                    color: TinniPalette.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: state.messages.isEmpty
                    ? const Center(child: Text('No notifications yet'))
                    : ListView.builder(
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final item = state.messages[index];
                          return ListTile(
                            leading: const Icon(Icons.mail_rounded),
                            title: Text(item.name),
                            subtitle: Text(
                              item.preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: item.unread > 0
                                ? Badge(label: Text(item.unread.toString()))
                                : null,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              widget.onSelect(2);
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

  Widget _topTabs() {
    const labels = <String>['Mine', 'Party', 'Events'];
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TextButton(
                      onPressed: () => setState(() => topPage = i),
                      style: TextButton.styleFrom(
                        foregroundColor: topPage == i
                            ? TinniPalette.gold
                            : TinniPalette.muted,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontWeight: topPage == i
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: topPage == i ? 22 : 0,
                            height: 2,
                            decoration: BoxDecoration(
                              color: TinniPalette.gold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Rankings',
          onPressed: () => _openRankings(context),
          icon: const TinniGlowIcon(
            icon: Icons.leaderboard_rounded,
            size: 18,
            boxSize: 34,
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: _showHomeNotifications,
          icon: const TinniGlowIcon(
            icon: Icons.notifications_rounded,
            size: 18,
            boxSize: 34,
          ),
        ),
        IconButton(
          tooltip: 'Search',
          onPressed: () => widget.onSelect(1),
          icon: const TinniGlowIcon(
            icon: Icons.search_rounded,
            size: 18,
            boxSize: 34,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeMinePage() {
    final owned = state.rooms
        .where((room) => room.ownerUserId == state.userId)
        .toList(growable: false);
    final recent = recentRoomIds
        .map((id) {
          for (final room in state.rooms) {
            if (room.id == id && room.online > 0) return room;
          }
          return null;
        })
        .whereType<RoomSummary>()
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        const Text(
          'My room',
          style: TextStyle(
            color: TinniPalette.gold,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (owned.isEmpty)
          TinniPanel(
            onTap: () => _createRoom(context),
            child: const Row(
              children: [
                TinniGlowIcon(
                  icon: Icons.add_home_rounded,
                  size: 28,
                  boxSize: 54,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create my room',
                        style: TextStyle(
                          color: TinniPalette.cream,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Your own room will appear here.',
                        style: TextStyle(
                          color: TinniPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: TinniPalette.gold,
                ),
              ],
            ),
          )
        else
          _RoomCard(
            state: state,
            room: owned.first,
            onTap: () => _openRoom(owned.first),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recents',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (recent.isNotEmpty)
              IconButton(
                tooltip: 'Clear recents',
                onPressed: () => setState(recentRoomIds.clear),
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  color: TinniPalette.gold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          TinniPanel(
            onTap: () => setState(() => topPage = 1),
            child: const Text(
              'No recent rooms yet. Tap to open Party.',
              style: TextStyle(color: TinniPalette.cream),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final room = recent[index];
                return SizedBox(
                  width: 156,
                  child: _TopRoomCard(
                    state: state,
                    room: room,
                    rank: index + 1,
                    onTap: () => _openRoom(room),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'My followings',
          style: TextStyle(
            color: TinniPalette.gold,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (visibleFollowedRooms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Column(
              children: [
                TinniGlowIcon(
                  icon: Icons.inventory_2_outlined,
                  size: 36,
                  boxSize: 62,
                ),
                SizedBox(height: 10),
                Text(
                  'No following rooms yet',
                  style: TextStyle(color: TinniPalette.muted),
                ),
              ],
            ),
          )
        else
          for (final room in visibleFollowedRooms)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _RoomCard(
                state: state,
                room: room,
                onTap: () => _openRoom(room),
              ),
            ),
      ],
    );
  }

  Widget _buildEventsPage() {
    final events = <(String, String, IconData, VoidCallback)>[
      (
        'Weekly CP',
        'Couple ranking, intimacy and heartbeat activities',
        Icons.favorite_rounded,
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CpRankingScreen(state: state),
          ),
        ),
      ),
      (
        'Gift Festival',
        'Popular, luxury, CP, VS and backpack gift collections',
        Icons.card_giftcard_rounded,
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => GiftsScreen(state: state),
          ),
        ),
      ),
      (
        'VIP Celebration',
        'VIP privileges, entry status and royal rewards',
        Icons.workspace_premium_rounded,
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => VipScreen(state: state),
          ),
        ),
      ),
      (
        'Family Party',
        'Family sign-in, contribution and group activities',
        Icons.groups_rounded,
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FamilyRankingScreen(state: state),
          ),
        ),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        const TinniPanel(
          child: Row(
            children: [
              TinniGlowIcon(
                icon: Icons.celebration_rounded,
                size: 30,
                boxSize: 56,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Royal Events',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'DarkVibeX events and social activities.',
                      style: TextStyle(color: TinniPalette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final item in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TinniPanel(
              onTap: item.$4,
              child: Row(
                children: [
                  TinniGlowIcon(
                    icon: item.$3,
                    size: 26,
                    boxSize: 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            color: TinniPalette.cream,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            color: TinniPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: TinniPalette.gold,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

    @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => TinniBackground(
        child: Column(
          children: [
            _topTabs(),
            const SizedBox(height: 6),
            Expanded(
              child: IndexedStack(
                index: topPage,
                children: [
                  _buildHomeMinePage(),
                  _buildPartyPage(context),
                  _buildEventsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
class _DiscoverHome extends StatefulWidget {
  const _DiscoverHome({required this.state});
  final AppState state;

  @override
  State<_DiscoverHome> createState() => _DiscoverHomeState();
}

class _DiscoverHomeState extends State<_DiscoverHome> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final rooms = widget.state.rooms
        .where((room) => room.online > 0)
        .where(
          (room) =>
              q.isEmpty ||
              room.name.toLowerCase().contains(q) ||
              room.roomNumber.toLowerCase().contains(q) ||
              room.ownerName.toLowerCase().contains(q),
        )
        .toList();

    return TinniBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          const Row(
            children: [
              Text(
                'Discover',
                style: TextStyle(
                  color: TinniPalette.gold,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              TinniGlowIcon(icon: Icons.explore_rounded),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              hintText: 'Search room, ID or user',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Rooms for you',
            style: TextStyle(
              color: TinniPalette.gold,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          for (final room in rooms)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _RoomCard(
                state: widget.state,
                room: room,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RoomScreen(state: widget.state, room: room),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopRoomCard extends StatelessWidget {
  const _TopRoomCard({
    required this.state,
    required this.room,
    required this.rank,
    required this.onTap,
  });

  final AppState state;
  final RoomSummary room;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TinniPanel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(7, 8, 7, 9),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: TinniPalette.panel2,
                  backgroundImage: room.avatarKey == null
                      ? null
                      : NetworkImage(
                          state.backend.fileUrl(room.avatarKey!),
                          headers: state.backend.fileHeaders,
                        ),
                  child: room.avatarKey == null
                      ? const Icon(Icons.mic_rounded, color: TinniPalette.gold)
                      : null,
                ),
                Positioned(
                  right: -5,
                  top: -6,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: TinniPalette.gold,
                    child: Text(
                      rank.toString(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TinniPalette.cream,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${room.online} online',
              style: const TextStyle(
                color: TinniPalette.muted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
}

class _OwnerBannerCard extends StatelessWidget {
  const _OwnerBannerCard({
    required this.state,
    required this.banner,
    required this.onTap,
  });

  final AppState state;
  final Map<String, dynamic> banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = banner['name']?.toString().trim() ?? 'DarkVibeX';
    final asset = banner['asset_key']?.toString().trim() ?? '';
    final link = banner['link']?.toString().trim() ?? '';
    final imageUrl = asset.isEmpty
        ? ''
        : (asset.startsWith('http://') || asset.startsWith('https://')
            ? asset
            : state.backend.fileUrl(asset));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TinniPanel(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  headers: asset.startsWith('http') ? null : state.backend.fileHeaders,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xDD090909), Color(0x66090909)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (link.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'Tap to open',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TinniPanel(
          onTap: onTap,
          child: Row(
            children: [
              TinniGlowIcon(icon: icon, size: 30, boxSize: 58),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: TinniPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: TinniPalette.gold,
              ),
            ],
          ),
        ),
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TinniPanel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            TinniGlowIcon(icon: icon, size: 19, boxSize: 36),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: TinniPalette.gold,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.state,
    required this.room,
    required this.onTap,
  });

  final AppState state;
  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TinniPanel(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: TinniPalette.gold),
              ),
              child: CircleAvatar(
                backgroundColor: TinniPalette.panel2,
                backgroundImage: room.avatarKey == null
                    ? null
                    : NetworkImage(
                        state.backend.fileUrl(room.avatarKey!),
                        headers: state.backend.fileHeaders,
                      ),
                child: room.avatarKey == null
                    ? Text(
                        room.name.isEmpty
                            ? '?'
                            : room.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: TinniPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TinniPalette.cream,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID ${room.roomNumber} • ${room.online} online • ${room.seatCount} seats • ${room.partyMode == 'Event hosting mode' ? 'Event' : 'Friends'}',
                    style: const TextStyle(
                      color: TinniPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.ownerName,
                    style: const TextStyle(
                      color: TinniPalette.deepGold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const TinniGlowIcon(
              icon: Icons.mic_external_on_rounded,
              size: 17,
              boxSize: 34,
            ),
          ],
        ),
      );
}


class _CreateRoomDraft {
  const _CreateRoomDraft({
    required this.title,
    required this.seatCount,
    required this.partyMode,
    required this.roomMode,
    this.avatarBytes,
    this.avatarExtension = 'jpg',
    this.avatarContentType = 'image/jpeg',
  });

  final String title;
  final int seatCount;
  final String partyMode;
  final String roomMode;
  final Uint8List? avatarBytes;
  final String avatarExtension;
  final String avatarContentType;
}

class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet({required this.maxSeats});
  final int maxSeats;

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  final TextEditingController _title = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  int _seatCount = 12;
  String _partyMode = 'Friends-making Party';
  String _roomMode = 'voice';
  Uint8List? _avatarBytes;
  String _avatarExtension = 'jpg';
  String _avatarContentType = 'image/jpeg';

  @override
  void initState() {
    super.initState();
    if (_seatCount > widget.maxSeats) {
      _seatCount = widget.maxSeats.clamp(8, 42);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const TinniGlowIcon(icon: Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const TinniGlowIcon(icon: Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 768,
      maxHeight: 768,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPG, PNG or WebP room photo')),
        );
      }
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarExtension = ext == 'jpeg' ? 'jpg' : ext;
      _avatarContentType = type;
    });
  }

  void _submit() {
    final name = _title.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room name is required')),
      );
      return;
    }
    Navigator.pop(
      context,
      _CreateRoomDraft(
        title: name,
        seatCount: _seatCount,
        partyMode: _partyMode,
        roomMode: _roomMode,
        avatarBytes: _avatarBytes,
        avatarExtension: _avatarExtension,
        avatarContentType: _avatarContentType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowedSeats = <int>[
      for (var value = 8; value <= widget.maxSeats.clamp(8, 42); value++)
        value,
    ];
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create room',
              style: TextStyle(
                color: TinniPalette.gold,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: InkWell(
                onTap: _pickPhoto,
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: TinniPalette.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: TinniPalette.gold, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _avatarBytes == null
                            ? const Center(
                                child: TinniGlowIcon(
                                  icon: Icons.add_a_photo_rounded,
                                  size: 30,
                                  boxSize: 62,
                                ),
                              )
                            : Image.memory(_avatarBytes!, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _avatarBytes == null ? 'Add room photo' : 'Change room DP',
                      style: const TextStyle(
                        color: TinniPalette.cream,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Gallery or Camera',
                      style: TextStyle(color: TinniPalette.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Room type',
              style: TextStyle(
                color: TinniPalette.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final mode in const ['voice', 'live'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(
                          mode == 'voice'
                              ? Icons.mic_rounded
                              : Icons.videocam_rounded,
                          size: 18,
                        ),
                        label: Text(
                          mode == 'voice' ? 'Voice Room' : 'Live Room',
                        ),
                        selected: _roomMode == mode,
                        onSelected: (_) => setState(() => _roomMode = mode),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose party mode',
              style: TextStyle(
                color: TinniPalette.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final mode in const [
                  'Friends-making Party',
                  'Event hosting mode',
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          mode == 'Friends-making Party'
                              ? 'Friends Party'
                              : 'Event Mode',
                        ),
                        selected: _partyMode == mode,
                        onSelected: (_) => setState(() => _partyMode = mode),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Number of mics',
              style: TextStyle(
                color: TinniPalette.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final count in allowedSeats)
                  ChoiceChip(
                    label: Text(count.toString()),
                    selected: _seatCount == count,
                    onSelected: (_) => setState(() => _seatCount = count),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add_circle_rounded),
                label: const Text('Create room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
