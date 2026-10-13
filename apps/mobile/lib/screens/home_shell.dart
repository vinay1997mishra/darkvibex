import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import '../vip/vip_policy.dart';
import 'messages_screen.dart';
import 'mine_social_screens.dart';
import 'profile_screen.dart';
import 'room_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final Set<int> visited = <int>{0};

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
      backgroundColor: TinniPalette.black,
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < pages.length; i++)
              visited.contains(i) ? pages[i] : const SizedBox.shrink(),
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
        child: NavigationBar(
          selectedIndex: index,
          backgroundColor: Colors.transparent,
          indicatorColor: TinniPalette.gold.withValues(alpha: .12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (value) => setState(() {
            index = value;
            visited.add(value);
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.groups_rounded),
              selectedIcon: TinniGlowIcon(icon: Icons.groups_rounded),
              label: 'Party',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_rounded),
              selectedIcon: TinniGlowIcon(icon: Icons.explore_rounded),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.mail_rounded),
              selectedIcon: TinniGlowIcon(icon: Icons.mail_rounded),
              label: 'Message',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_rounded),
              selectedIcon: TinniGlowIcon(icon: Icons.person_rounded),
              label: 'Mine',
            ),
          ],
        ),
      ),
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

  @override
  void initState() {
    super.initState();
    _loadFollowedRooms();
  }

  Future<void> _loadFollowedRooms() async {
    if (!state.backendConnected) return;
    final rows = await state.backend.followedRooms(userId: state.userId);
    final values = rows.map((row) {
      return RoomSummary(
        id: row['id']?.toString() ?? '',
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
      );
    }).where((room) => room.id.isNotEmpty).toList(growable: false);
    if (!mounted) return;
    setState(() => followedRooms = values);
  }
  int topPage = 1;
  final List<String> recentRoomIds = <String>[];
  List<RoomSummary> followedRooms = const <RoomSummary>[];

  Future<void> _showRoomRanking(BuildContext context) async {
    final rooms = [...state.rooms]
      ..sort((a, b) => b.online.compareTo(a.online));
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .68,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: TinniPalette.gold),
                    SizedBox(width: 8),
                    Text(
                      'Room Ranking',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rooms.isEmpty
                    ? const Center(child: Text('No rooms available'))
                    : ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: TinniPalette.panel2,
                              backgroundImage: room.avatarKey == null
                                  ? null
                                  : NetworkImage(
                                      state.backend.fileUrl(room.avatarKey!),
                                      headers: state.backend.fileHeaders,
                                    ),
                              child: room.avatarKey == null
                                  ? Text('${index + 1}')
                                  : null,
                            ),
                            title: Text(room.name),
                            subtitle: Text(
                              'No.${index + 1} • ${room.online} online • ${room.partyMode == 'Event hosting mode' ? 'Event Mode' : 'Friends Party'}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _openRoom(room);
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

  Future<void> _createRoom(BuildContext context) async {
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
            name: created.name,
            ownerName: created.ownerName,
            ownerUserId: created.ownerUserId,
            online: created.online,
            seatCount: created.seatCount,
            avatarKey: key,
            partyMode: created.partyMode,
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
    ).then((_) => _loadFollowedRooms());
  }

  Widget _buildPartyPage(BuildContext context) {
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
                      _PromoCard(
                        title: 'ROYAL PARTY',
                        subtitle: 'Live rooms, rankings and royal rewards',
                        icon: Icons.workspace_premium_rounded,
                        onTap: () => _showRoomRanking(context),
                      ),
                      _PromoCard(
                        title: 'WEEKLY STAR',
                        subtitle: 'Weekly rankings and royal rewards',
                        icon: Icons.emoji_events_rounded,
                        onTap: () => _showRoomRanking(context),
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
                        onTap: () => _showRoomRanking(context),
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
                            builder: (_) => FamilyScreen(state: state),
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
                      '${state.rooms.length} rooms',
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
                                final rooms = [...state.rooms];
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
                itemCount: state.rooms.length > 3 ? state.rooms.length - 3 : 0,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, roomIndex) {
                  final rooms = [...state.rooms];
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
    const labels = <String>['Mine', 'Party', 'Events', 'Country'];
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
          onPressed: () => _showRoomRanking(context),
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
            if (room.id == id) return room;
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
        if (followedRooms.isEmpty)
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
          for (final room in followedRooms)
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
    final rooms = state.rooms
        .where((room) => room.partyMode == 'Event hosting mode')
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        const Text(
          'Events',
          style: TextStyle(
            color: TinniPalette.gold,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (rooms.isEmpty)
          const TinniPanel(
            child: Text(
              'No event rooms are live right now.',
              style: TextStyle(color: TinniPalette.muted),
            ),
          )
        else
          for (final room in rooms)
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

  Widget _buildCountryPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        const Text(
          'Country',
          style: TextStyle(
            color: TinniPalette.gold,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Rooms by country',
          style: TextStyle(color: TinniPalette.muted),
        ),
        const SizedBox(height: 12),
        for (final room in state.rooms)
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
                  _buildCountryPage(),
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
        .where(
          (room) =>
              q.isEmpty ||
              room.name.toLowerCase().contains(q) ||
              room.id.toLowerCase().contains(q) ||
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
                    'ID ${room.id} • ${room.online} online • ${room.seatCount} seats • ${room.partyMode == 'Event hosting mode' ? 'Event' : 'Friends'}',
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
    this.avatarBytes,
    this.avatarExtension = 'jpg',
    this.avatarContentType = 'image/jpeg',
  });

  final String title;
  final int seatCount;
  final String partyMode;
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
