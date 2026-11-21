import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'fruit_party_screen.dart';
import 'greedy_girl_screen.dart';
import 'local_ludo_screen.dart';
import 'ludo_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({
    super.key,
    required this.state,
    this.roomId,
    this.onFruitParty,
    this.onGreedyGirl,
    this.roomOwnerUserId,
    this.onGameRoom,
    this.onToggleMic,
    this.micOn,
    this.hasMicSeat,
  });

  final AppState state;
  final String? roomId;
  final VoidCallback? onFruitParty;
  final VoidCallback? onGreedyGirl;
  final String? roomOwnerUserId;
  final VoidCallback? onGameRoom;
  final Future<void> Function()? onToggleMic;
  final bool Function()? micOn;
  final bool Function()? hasMicSeat;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  Future<void> _openOnlineLudo({
    required int playerCount,
    String? colorPair,
  }) async {
    final roomId = widget.roomId?.trim() ?? '';
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LudoScreen(
          state: widget.state,
          roomId: roomId,
          playerCount: playerCount,
          colorPair: colorPair,
          roomOwnerUserId: widget.roomOwnerUserId,
          onToggleMic: widget.onToggleMic,
          micOn: widget.micOn,
          hasMicSeat: widget.hasMicSeat,
        ),
      ),
    );
  }

  Future<void> _openLocalLudo(int playerCount) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LocalLudoScreen(playerCount: playerCount),
      ),
    );
  }

  /// 2-player cross-pair choice: Red vs Yellow or Blue vs Green.
  Future<void> _pickOnlinePair() async {
    final pair = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('ludo-pair-red-yellow'),
              leading: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 10, backgroundColor: Color(0xFFE5484D)),
                  SizedBox(width: 4),
                  CircleAvatar(radius: 10, backgroundColor: Color(0xFFF2C94C)),
                ],
              ),
              title: const Text('Red vs Yellow'),
              subtitle: const Text('Cross — top-left vs bottom-right'),
              onTap: () => Navigator.pop(sheetContext, 'red-yellow'),
            ),
            ListTile(
              key: const Key('ludo-pair-blue-green'),
              leading: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 10, backgroundColor: Color(0xFF3C82F6)),
                  SizedBox(width: 4),
                  CircleAvatar(radius: 10, backgroundColor: Color(0xFF31B46C)),
                ],
              ),
              title: const Text('Blue vs Green'),
              subtitle: const Text('Cross — bottom-left vs top-right'),
              onTap: () => Navigator.pop(sheetContext, 'blue-green'),
            ),
          ],
        ),
      ),
    );
    if (pair == null || !mounted) return;
    await _openOnlineLudo(playerCount: 2, colorPair: pair);
  }

  Future<void> _openLudo() async {
    final roomId = widget.roomId?.trim() ?? '';
    // No room: play on this phone (local Ludo, 2 or 4 players).
    if (roomId.isEmpty) {
      final count = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Play on this phone'),
                subtitle: Text('No room needed — pass the phone around'),
              ),
              ListTile(
                key: const Key('ludo-local-2p'),
                leading: const Text('👥', style: TextStyle(fontSize: 28)),
                title: const Text('2 Players'),
                subtitle: const Text('Red vs Yellow'),
                onTap: () => Navigator.pop(sheetContext, 2),
              ),
              ListTile(
                key: const Key('ludo-local-4p'),
                leading: const Text('👥👥', style: TextStyle(fontSize: 28)),
                title: const Text('4 Players'),
                subtitle: const Text('Red, Green, Yellow, Blue'),
                onTap: () => Navigator.pop(sheetContext, 4),
              ),
            ],
          ),
        ),
      );
      if (count == null || !mounted) return;
      await _openLocalLudo(count);
      return;
    }
    // In a room: online Ludo, pick 2 or 4 players first.
    final count = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('ludo-online-2p'),
              leading: const Text('👥', style: TextStyle(fontSize: 28)),
              title: const Text('2 Players'),
              subtitle: const Text('Cross pair — pick Red-Yellow or Blue-Green'),
              onTap: () => Navigator.pop(sheetContext, 2),
            ),
            ListTile(
              key: const Key('ludo-online-4p'),
              leading: const Text('👥👥', style: TextStyle(fontSize: 28)),
              title: const Text('4 Players'),
              subtitle: const Text('Red, Green, Yellow, Blue'),
              onTap: () => Navigator.pop(sheetContext, 4),
            ),
          ],
        ),
      ),
    );
    if (count == null || !mounted) return;
    if (count == 2) {
      await _pickOnlinePair();
      return;
    }
    await _openOnlineLudo(playerCount: 4);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.state,
    builder: (context, _) => TinniBackground(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Games',
            style: TextStyle(
              color: TinniPalette.gold,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              key: const Key('open-fruit-party'),
              leading: const Text('🍒', style: TextStyle(fontSize: 34)),
              title: const Text(
                'GIRLS PARTY',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                '21s rounds • Silver & Gold Lucky • last 7 results',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap:
                  widget.onFruitParty ??
                  () => showFruitParty(context, widget.state),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              key: const Key('open-greedy-girl'),
              leading: const Text('👩🏻‍🎤', style: TextStyle(fontSize: 32)),
              title: const Text(
                'GREEDY GIRL',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                '30s rounds • food multipliers • server-settled results',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap:
                  widget.onGreedyGirl ??
                  () => showGreedyGirl(context, widget.state),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              key: const Key('convert-current-room-to-game'),
              leading: const Icon(
                Icons.sports_esports_rounded,
                size: 32,
                color: TinniPalette.brightGold,
              ),
              title: const Text('Use this room as Game Room'),
              subtitle: const Text(
                'Convert this room in place — no second room is created.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onGameRoom,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Text('🎲', style: TextStyle(fontSize: 32)),
              title: const Text('Ludo'),
              subtitle: const Text(
                'Free 2 or 4-player game • room mic stays active',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _openLudo,
            ),
          ),
        ],
      ),
    ),
  );
}
