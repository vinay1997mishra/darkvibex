import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../background/room_permission_bridge.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../ui/tinni_style.dart';
import 'fruit_party_screen.dart';
import 'greedy_girl_screen.dart';
import 'ludo_screen.dart';
import 'messages_screen.dart';

class GameRoomLobbyScreen extends StatefulWidget {
  const GameRoomLobbyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<GameRoomLobbyScreen> createState() => _GameRoomLobbyScreenState();
}

class _GameRoomLobbyScreenState extends State<GameRoomLobbyScreen> {
  List<Map<String, dynamic>> rooms = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final result =
        await widget.state.backend.gameRooms(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      rooms = result;
      loading = false;
    });
  }

  Future<void> _create() async {
    final input = TextEditingController(
      text: '${widget.state.displayName} Party Room',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create shared game room'),
        content: TextField(
          controller: input,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Room name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    input.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final result = await widget.state.backend.createGameRoom(
      userId: widget.state.userId,
      name: name,
    );
    final id = result?['room_id']?.toString();
    if (id == null || id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create game room')),
        );
      }
      return;
    }
    await _open(id, join: false);
  }

  Future<void> _open(String roomId, {bool join = true}) async {
    if (join) {
      final joined = await widget.state.backend.joinGameRoom(
        roomId: roomId,
        userId: widget.state.userId,
      );
      if (joined?['ok'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room is full or unavailable')),
          );
        }
        await _refresh();
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SharedGameRoomScreen(state: widget.state, roomId: roomId),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Shared Game Rooms'),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create room'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: rooms.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 180),
                          Center(
                            child: Text(
                              'No public game rooms yet. Create one to start.',
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(child: Text('🎮')),
                              title: Text(
                                room['name']?.toString() ?? 'Game room',
                              ),
                              subtitle: Text(
                                '${room['owner_name'] ?? 'Player'} • '
                                '${room['member_count'] ?? 0}/15 seats • '
                                'Shared score ${room['shared_score'] ?? 0}',
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () => _open(room['id'].toString()),
                            ),
                          );
                        },
                      ),
              ),
      );
}

class SharedGameRoomScreen extends StatefulWidget {
  const SharedGameRoomScreen({
    super.key,
    required this.state,
    required this.roomId,
  });

  final AppState state;
  final String roomId;

  @override
  State<SharedGameRoomScreen> createState() => _SharedGameRoomScreenState();
}

class _SharedGameRoomScreenState extends State<SharedGameRoomScreen> {
  final TextEditingController chatController = TextEditingController();
  final RoomPermissionBridge roomPermissions = const RoomPermissionBridge();

  Map<String, dynamic>? data;
  List<Map<String, dynamic>> chat = const <Map<String, dynamic>>[];
  Timer? timer;
  LiveKitRtcAdapter? rtc;
  bool tapping = false;
  bool sendingChat = false;
  bool muted = true;
  String voiceStatus = 'Connecting voice…';

  Map<String, dynamic> get room => data?['room'] is Map
      ? Map<String, dynamic>.from(data!['room'] as Map)
      : <String, dynamic>{};

  List<Map<String, dynamic>> get members => data?['members'] is List
      ? (data!['members'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];

  bool get isOwner =>
      room['owner_user_id']?.toString() == widget.state.userId;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    unawaited(_connectVoice());
    timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    chatController.dispose();
    final currentRtc = rtc;
    rtc = null;
    if (currentRtc != null) {
      unawaited(
        currentRtc.leave().whenComplete(currentRtc.dispose),
      );
    }
    if (widget.state.backendConnected) {
      unawaited(
        widget.state.backend.leaveGameRoom(
          roomId: widget.roomId,
          userId: widget.state.userId,
        ),
      );
    }
    super.dispose();
  }

  Future<void> _connectVoice() async {
    final token = widget.state.sessionToken;
    if (!widget.state.backendConnected ||
        token == null ||
        token.isEmpty ||
        BackendApi.origin.isEmpty) {
      if (mounted) setState(() => voiceStatus = 'Voice unavailable');
      return;
    }

    final adapter = LiveKitRtcAdapter(
      apiBase: Uri.parse(BackendApi.origin),
    );
    try {
      await adapter.join(
        widget.roomId,
        widget.state.userId,
        authToken: token,
      );
      if (!mounted) {
        await adapter.leave();
        adapter.dispose();
        return;
      }
      rtc = adapter;
      setState(() => voiceStatus = 'Voice connected');
    } catch (_) {
      adapter.dispose();
      if (mounted) setState(() => voiceStatus = 'Voice unavailable');
    }
  }

  Future<void> _toggleMic() async {
    final adapter = rtc;
    if (adapter == null) {
      await _connectVoice();
      if (!mounted || rtc == null) return;
    }

    if (muted) {
      final hasPermission = await roomPermissions.hasVoiceRoomPermissions();
      final allowed = hasPermission
          ? true
          : await roomPermissions.requestVoiceRoomPermissions();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required to speak.'),
            ),
          );
        }
        return;
      }
    }

    try {
      await rtc!.setMicPublished(muted);
      if (!mounted) return;
      setState(() {
        muted = !muted;
        voiceStatus = muted ? 'Voice connected' : 'Speaking';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone could not be changed.')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    final result = await widget.state.backend.gameRoom(
      roomId: widget.roomId,
      userId: widget.state.userId,
    );
    final rows = await widget.state.backend.gameRoomMessages(
      roomId: widget.roomId,
      userId: widget.state.userId,
    );
    if (!mounted) return;
    if (result?['ok'] == true) {
      setState(() {
        data = result;
        chat = rows;
      });
    }
  }

  Future<void> _sendChat() async {
    if (sendingChat) return;
    final value = chatController.text.trim();
    if (value.isEmpty) return;
    setState(() => sendingChat = true);
    final ok = await widget.state.backend.sendGameRoomMessage(
      roomId: widget.roomId,
      userId: widget.state.userId,
      text: value,
    );
    if (!mounted) return;
    if (ok) {
      chatController.clear();
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message was not sent.')),
      );
    }
    if (mounted) setState(() => sendingChat = false);
  }

  Future<void> _tapTogether() async {
    if (tapping) return;
    setState(() => tapping = true);
    final result = await widget.state.backend.tapGameRoom(
      roomId: widget.roomId,
      userId: widget.state.userId,
    );
    if (!mounted) return;
    if (result?['ok'] == true) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join this room before playing')),
      );
    }
    if (mounted) setState(() => tapping = false);
  }

  Future<void> _shareRoom() async {
    await Clipboard.setData(ClipboardData(text: widget.roomId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game Room ID copied')),
    );
  }

  Future<void> _openInbox() async {
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

  Future<void> _showMembers() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final name =
                  member['display_name']?.toString() ?? 'User';
              final avatar = member['avatar_key']?.toString();
              final seat =
                  int.tryParse(member['seat_index']?.toString() ?? '');
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: TinniPalette.panel2,
                  backgroundImage: avatar == null || avatar.isEmpty
                      ? null
                      : NetworkImage(
                          widget.state.backend.fileUrl(avatar),
                          headers: widget.state.backend.fileHeaders,
                        ),
                  child: avatar == null || avatar.isEmpty
                      ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                      : null,
                ),
                title: Text(name),
                subtitle: Text(
                  member['user_id']?.toString() == widget.state.userId
                      ? 'Seat ${(seat ?? 0) + 1} • You'
                      : 'Seat ${(seat ?? 0) + 1}',
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _sendGift() async {
    if (members.isEmpty) return;
    final receiver = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .58,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const ListTile(
                title: Text(
                  'Choose gift receiver',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              for (final member in members)
                ListTile(
                  leading: const Icon(
                    Icons.person_rounded,
                    color: TinniPalette.gold,
                  ),
                  title: Text(
                    member['display_name']?.toString() ?? 'User',
                  ),
                  subtitle: Text(
                    member['user_id']?.toString() == widget.state.userId
                        ? 'Send to yourself'
                        : 'Seat ${(int.tryParse(member['seat_index']?.toString() ?? '') ?? 0) + 1}',
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    Map<String, dynamic>.from(member),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (receiver == null || !mounted) return;

    final gifts = await widget.state.backend.giftCatalog(
      userId: widget.state.userId,
    );
    if (!mounted || gifts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gift catalog is unavailable.')),
        );
      }
      return;
    }

    final gift = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .62,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: gifts.length,
            itemBuilder: (context, index) {
              final item = gifts[index];
              return ListTile(
                leading: Text(
                  item['emoji']?.toString() ?? '🎁',
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(item['name']?.toString() ?? 'Gift'),
                subtitle: Text(
                  '${item['coin_cost'] ?? 0} coins',
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  Map<String, dynamic>.from(item),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (gift == null || !mounted) return;

    final result = await widget.state.backend.sendGift(
      roomId: widget.roomId,
      senderUserId: widget.state.userId,
      receiverUserId: receiver['user_id']?.toString() ?? '',
      giftId: gift['id']?.toString() ?? '',
      coinCost: int.tryParse(gift['coin_cost']?.toString() ?? '') ?? 0,
    );
    if (!mounted) return;
    if (result?['ok'] == true) {
      await widget.state.refreshWallet(notify: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${gift['name'] ?? 'Gift'} sent to '
            '${receiver['display_name'] ?? 'User'}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['error']?.toString().replaceAll('_', ' ') ??
                'Gift could not be sent.',
          ),
        ),
      );
    }
  }

  Future<void> _openGames() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Play Games',
                  style: TextStyle(
                    color: TinniPalette.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  'Choose a game without leaving this Game Room',
                ),
              ),
              ListTile(
                key: const Key('game-room-play-fruit-party'),
                leading: const Text('🍒', style: TextStyle(fontSize: 30)),
                title: const Text('Fruit Party'),
                onTap: () => Navigator.pop(sheetContext, 'fruit-party'),
              ),
              ListTile(
                key: const Key('game-room-play-greedy-girl'),
                leading: const Text('👩🏻‍🎤', style: TextStyle(fontSize: 30)),
                title: const Text('Greedy Girl'),
                onTap: () => Navigator.pop(sheetContext, 'greedy-girl'),
              ),
              ListTile(
                key: const Key('game-room-play-ludo'),
                leading: const Text('🎲', style: TextStyle(fontSize: 30)),
                title: const Text('Ludo'),
                subtitle: const Text('Free online room game'),
                onTap: () => Navigator.pop(sheetContext, 'ludo'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selection == null) return;
    if (selection == 'fruit-party') {
      await showFruitParty(context, widget.state);
      return;
    }
    if (selection == 'greedy-girl') {
      await showGreedyGirl(context, widget.state);
      return;
    }
    if (selection == 'ludo') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LudoScreen(
            state: widget.state,
            roomId: widget.roomId,
            roomOwnerUserId: room['owner_user_id']?.toString(),
            onToggleMic: _toggleMic,
            micOn: () => !muted,
            hasMicSeat: () => true,
          ),
        ),
      );
    }
  }

  Future<void> _showRoomTools() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              _GameRoomTool(
                icon: Icons.sports_esports_rounded,
                label: 'Play Games',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_openGames());
                },
              ),
              _GameRoomTool(
                icon: Icons.people_alt_rounded,
                label: 'Members',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_showMembers());
                },
              ),
              _GameRoomTool(
                icon: Icons.mark_chat_unread_rounded,
                label: 'Messages',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_openInbox());
                },
              ),
              _GameRoomTool(
                icon: Icons.copy_rounded,
                label: 'Copy Room ID',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(_shareRoom());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPowerMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Refresh room'),
              onTap: () => Navigator.pop(sheetContext, 'refresh'),
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded),
              title: const Text('Exit Game Room'),
              onTap: () => Navigator.pop(sheetContext, 'exit'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'refresh') {
      await _refresh();
    } else if (action == 'exit') {
      Navigator.of(context).pop();
    }
  }

  Widget _chatList() {
    if (chat.isEmpty) {
      return const Center(
        child: Text(
          'Room chat',
          style: TextStyle(color: TinniPalette.muted),
        ),
      );
    }
    return ListView.builder(
      key: const Key('game-room-chat-list'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: chat.length,
      itemBuilder: (context, index) {
        final item = chat[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: TinniPalette.cream,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: '${item['display_name'] ?? 'User'}: ',
                  style: const TextStyle(
                    color: TinniPalette.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: item['text']?.toString() ?? ''),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roomActions() => Container(
        key: const Key('game-room-normal-controls'),
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 5),
        decoration: const BoxDecoration(
          color: Color(0xDD09090D),
          border: Border(
            top: BorderSide(color: Colors.white12),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('game-room-play-games-button'),
              tooltip: 'Play Games',
              onPressed: _openGames,
              icon: const TinniGlowIcon(
                icon: Icons.sports_esports_rounded,
                size: 20,
                boxSize: 36,
              ),
            ),
            IconButton(
              key: const Key('game-room-mic-button'),
              tooltip: muted ? 'Turn microphone on' : 'Turn microphone off',
              onPressed: _toggleMic,
              icon: TinniGlowIcon(
                icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 20,
                boxSize: 36,
              ),
            ),
            IconButton(
              key: const Key('game-room-gift-button'),
              tooltip: 'Gifts',
              onPressed: _sendGift,
              icon: const TinniGlowIcon(
                icon: Icons.card_giftcard_rounded,
                size: 20,
                boxSize: 36,
              ),
            ),
            IconButton(
              key: const Key('game-room-messages-button'),
              tooltip: 'Messages',
              onPressed: _openInbox,
              icon: const TinniGlowIcon(
                icon: Icons.mark_chat_unread_rounded,
                size: 20,
                boxSize: 36,
              ),
            ),
            IconButton(
              key: const Key('game-room-4box-button'),
              tooltip: '4-Box',
              onPressed: _showRoomTools,
              icon: const TinniGlowIcon(
                icon: Icons.grid_view_rounded,
                size: 20,
                boxSize: 36,
              ),
            ),
            const Spacer(),
            Text(
              muted ? voiceStatus : 'Mic on',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TinniPalette.muted,
                fontSize: 9,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final score =
        int.tryParse(room['shared_score']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room['name']?.toString() ?? 'Game Room',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Game Room • ${members.length}/15 • $voiceStatus',
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('game-room-share-button'),
            tooltip: 'Share room',
            onPressed: _shareRoom,
            icon: const TinniGlowIcon(
              icon: Icons.share_rounded,
              size: 18,
              boxSize: 34,
            ),
          ),
          IconButton(
            key: const Key('game-room-power-button'),
            tooltip: 'Room options',
            onPressed: _showPowerMenu,
            icon: const TinniGlowIcon(
              icon: Icons.power_settings_new_rounded,
              size: 18,
              boxSize: 34,
            ),
          ),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : TinniBackground(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const Key('game-room-play-now'),
                              onPressed: _openGames,
                              icon: const Icon(Icons.sports_esports_rounded),
                              label: const Text('PLAY GAMES'),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          child: TinniPanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'PARTY TAP',
                                  style: TextStyle(
                                    color: TinniPalette.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$score',
                                  style: const TextStyle(
                                    color: TinniPalette.cream,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                  height: 32,
                                  child: FilledButton.tonalIcon(
                                    onPressed:
                                        tapping ? null : _tapTogether,
                                    icon: const Icon(
                                      Icons.touch_app_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Tap'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: _chatList()),
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                          decoration: const BoxDecoration(
                            color: Color(0xAA08080C),
                            border: Border(
                              top: BorderSide(color: Colors.white12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('game-room-chat-input'),
                                  controller: chatController,
                                  maxLength: 500,
                                  maxLines: 1,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted:
                                      sendingChat ? null : (_) => _sendChat(),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    hintText: 'Type a room message…',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const Key('game-room-chat-send'),
                                onPressed:
                                    sendingChat ? null : _sendChat,
                                icon: const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                        ),
                        _roomActions(),
                      ],
                    ),
                  ),
                  Container(
                    width: 68,
                    decoration: const BoxDecoration(
                      color: Color(0x22111122),
                      border: Border(
                        left: BorderSide(color: Colors.white12),
                      ),
                    ),
                    child: ListView.builder(
                      key: const Key('game-room-15-seat-list'),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: 15,
                      itemBuilder: (context, index) {
                        final seatMembers = members
                            .where(
                              (row) =>
                                  int.tryParse(
                                    row['seat_index']?.toString() ?? '',
                                  ) ==
                                  index,
                            )
                            .toList();
                        final player =
                            seatMembers.isEmpty ? null : seatMembers.first;
                        final name =
                            player?['display_name']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Tooltip(
                            message: player == null
                                ? 'Seat ${index + 1} available'
                                : name,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: player == null
                                  ? Colors.white10
                                  : const Color(0xFF60417F),
                              child: Text(
                                player == null
                                    ? '${index + 1}'
                                    : (name.isEmpty
                                        ? 'U'
                                        : name[0].toUpperCase()),
                                style: const TextStyle(fontSize: 11),
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
    );
  }
}

class _GameRoomTool extends StatelessWidget {
  const _GameRoomTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TinniPanel(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TinniGlowIcon(icon: icon, size: 20, boxSize: 34),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TinniPalette.cream,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
}
