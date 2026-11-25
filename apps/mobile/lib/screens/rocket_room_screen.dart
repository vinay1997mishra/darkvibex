import 'dart:async';
import 'dart:math' as math;

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/screens/room_gift_ranking_screen.dart';
import 'package:darkvibex/ui/tinni_style.dart';
import 'package:darkvibex/utils/rocket_progress.dart';
import 'package:darkvibex/utils/rocket_top_rewards.dart';
import 'package:darkvibex/vip/vip_visual_assets.dart';
import 'package:darkvibex/widgets/room_floating_logos.dart';
import 'package:flutter/material.dart';

/// Rocket Room Page — full-screen Rocket view for a room.
///
/// Layout follows the approved v5 preview
/// (~/workspace/darkvibex-vip-section/rocket-room-compare/darkvibex-rocket-room-page-v5.jpg):
/// room header, mic seats, left level ladder Lv.1-18, centre rocket on a
/// glowing launch pad with a countdown timer, right vertical progress bar,
/// Top 1/2/3 gifters with rank badges, bottom tabs (Top 1 / Top 2 / Top 3 /
/// User) with reward cards, and a Record button.
///
/// Rewards follow Vinay's CURRENT rules, not the preview's ring/star cards:
/// NO frames for anyone — Top 1/2/3 get a Rocket medal (permanent, PR #151),
/// and everyone in the entry-order pool gets random coins only. The VIP and
/// coin figures on the reward cards are the confirmed DISPLAY values for the
/// level (rocket_top_rewards.dart) — they are NOT granted (the VIP + coins
/// grant was stopped; only the medal is granted). The pool range comes from
/// the live rocket-reward status endpoint, so it is never hard-coded here.
///
/// STUBBED: the countdown has no backend deadline — it counts down to the
/// next UTC midnight (daily cycle). The mic seats row shows the first 8
/// room members (not seat-number mapped). See the report for the full list.
class RocketRoomPage extends StatefulWidget {
  const RocketRoomPage({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.roomNumber,
    required this.onlineCount,
    required this.lifetimeTotal,
    required this.dailyTotal,
    required this.ranking,
    required this.seatMembers,
    required this.currentUserId,
    this.backend = const BackendApi(),
    this.state,
  });

  final String roomId;
  final String roomName;
  final String roomNumber;
  final int onlineCount;

  /// Cumulative room gift coins (drives level + progress).
  final int lifetimeTotal;

  /// Today's (IST day) room gift total. The rocket level and progress
  /// run on this, so the rocket returns to level 1 on the new day
  /// (Vinay, 2026-11-23); the lifetime total above is only the display
  /// total.
  final int dailyTotal;

  /// Top gifters, best first. Rows carry display_name, avatar_key,
  /// sent_coins and user_id (same shape as roomGiftRanking).
  final List<Map<String, dynamic>> ranking;

  /// Room members shown as mic seats (first 8).
  final List<Map<String, dynamic>> seatMembers;

  final String currentUserId;
  final BackendApi backend;

  /// Optional: when provided, a successful pool claim refreshes the
  /// wallet/cosmetics through it (the room screen passes its state;
  /// tests build the page without it).
  final AppState? state;

  @override
  State<RocketRoomPage> createState() => _RocketRoomPageState();
}

String _compactCoins(int value) {
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

String _formatLakh(int coins) {
  final lakh = coins / 100000;
  final text = lakh == lakh.truncateToDouble()
      ? lakh.truncate().toString()
      : lakh.toStringAsFixed(1);
  return '$text Lakh';
}

class _RocketRoomPageState extends State<RocketRoomPage> {
  static const double _ladderTileHeight = 64;

  int _selectedTab = 0;
  Map<String, dynamic>? _rewardStatus;
  bool _rewardStatusFailed = false;
  bool _claiming = false;
  Duration _countdown = Duration.zero;
  Timer? _countdownTimer;
  final ScrollController _ladderController = ScrollController();

  int get _completed =>
      calculateRocketProgress(widget.dailyTotal)['completed']!.toInt();

  int get _currentLevel =>
      _completed >= rocketStageTargets.length ? rocketStageTargets.length : _completed + 1;

  double get _progressPercent =>
      calculateRocketProgress(widget.dailyTotal)['percent']!.toDouble();

  List<RocketTopReward> get _topRewards =>
      rocketTopRewardsForLevel(_currentLevel) ??
      rocketTopRewardsForLevel(1)!;

  @override
  void initState() {
    super.initState();
    _tickCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _tickCountdown();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offset = (rocketStageTargets.length - _currentLevel) *
          (_ladderTileHeight + 6);
      if (_ladderController.hasClients) {
        _ladderController.jumpTo(
          offset.clamp(0.0, _ladderController.position.maxScrollExtent),
        );
      }
    });
    unawaited(_loadRewardStatus());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ladderController.dispose();
    super.dispose();
  }

  // STUBBED: no backend rocket deadline exists, so the timer counts down
  // to the next UTC midnight (daily cycle).
  void _tickCountdown() {
    final now = DateTime.now().toUtc();
    final nextMidnight = DateTime.utc(now.year, now.month, now.day + 1);
    setState(() {
      _countdown = nextMidnight.difference(now);
    });
  }

  String get _countdownText {
    final totalSeconds = _countdown.inSeconds.clamp(0, 86399);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(hours)} : ${two(minutes)} : ${two(seconds)}';
  }

  Future<void> _loadRewardStatus() async {
    try {
      final status = await widget.backend.roomRocketRewardStatus(
        roomId: widget.roomId,
        rocketLevel: _currentLevel,
      );
      if (!mounted) return;
      if (status == null || status['ok'] != true) {
        setState(() => _rewardStatusFailed = true);
        return;
      }
      setState(() => _rewardStatus = status);
    } catch (_) {
      if (mounted) setState(() => _rewardStatusFailed = true);
    }
  }

  /// Claims the pool from this page (full-app audit 2026-11-20): the
  /// page used to tell eligible users "you can claim the pool" with no
  /// way to act on it — the only claim button lived in the room
  /// screen's chest dialog. Same endpoint, same result handling.
  Future<void> _claimPool() async {
    if (_claiming || !mounted) return;
    setState(() => _claiming = true);
    Map<String, dynamic>? result;
    try {
      result = await widget.backend.claimRoomRocketReward(
        roomId: widget.roomId,
        rocketLevel: _currentLevel,
      );
    } catch (_) {
      result = null;
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
    if (!mounted) return;
    if (result?['ok'] == true) {
      if (result?['reward_type']?.toString() == 'coins') {
        await widget.state?.refreshWallet();
      } else if (result?['reward_type']?.toString() == 'frame') {
        await widget.state?.refreshCosmetics();
      }
      if (!mounted) return;
      final amount = int.tryParse(result?['coins']?.toString() ?? '') ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result?['already_claimed'] == true
                ? 'This reward was already claimed. Your wallet has been refreshed.'
                : 'Congratulations! $amount Coins have been added to your wallet.',
          ),
        ),
      );
      unawaited(_loadRewardStatus());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (result?['error']?.toString() ?? 'The reward could not be claimed. Please try again.')
                .replaceAll('_', ' '),
          ),
        ),
      );
    }
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('rocket-room-help-dialog'),
        backgroundColor: const Color(0xFF2A2140),
        title: const Text(
          'How Rocket rewards work',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Room gifts add up to the Rocket target. When a level is reached, '
          'the rocket launches.\n\n'
          'Top 1, Top 2 and Top 3 gifters get a Rocket medal — it stays '
          'permanently.\n\n'
          'Everyone else in the room who entered early enough gets random '
          'coins only. No frames are given to anyone.\n\n'
          'Entry order counts: the earliest room entrants claim first.',
          style: const TextStyle(color: Color(0xFFB9C8F3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showRecords() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('rocket-room-record-dialog'),
        backgroundColor: const Color(0xFF2A2140),
        title: const Text(
          'Rocket records',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < rocketStageTargets.length; index++)
                  Builder(
                    builder: (context) {
                      final level = index + 1;
                      final reached = index < _completed;
                      return ListTile(
                        key: Key('rocket-room-record-level-$level'),
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: reached
                              ? const Color(0xFFFFB11B)
                              : const Color(0xFF24304F),
                          child: Text(
                            '$level',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          'Lv.$level — ${_compactCoins(rocketStageTargets[index])} coins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Text(
                          reached ? 'Reached' : 'Pending',
                          style: TextStyle(
                            color: reached
                                ? const Color(0xFF62FFD1)
                                : const Color(0xFFB9C8F3),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('rocket-room-page'),
      backgroundColor: TinniPalette.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    const Color(0xFF05081F),
                    const Color(0xFF0A1030),
                    const Color(0xFF05081F),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _StarfieldPainter()),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  _buildTotalRow(),
                  _buildSeatsRow(),
                  _buildMiddleRow(),
                  _buildTopThreeRow(),
                  _buildBottomPanel(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DarkVibeX • ${widget.roomName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID ${widget.roomNumber}',
                  style: const TextStyle(
                    color: Color(0xFFB9C8F3),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.visibility_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            _compactCoins(widget.onlineCount),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.more_horiz_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    // Touching the total gifting amount opens the room ranking page
    // (Vinay, 2026-11-21): this room only, Day / Week / Month, top 99.
    // The display itself is unchanged.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: InkWell(
        key: const Key('rocket-room-total-gifts'),
        onTap: _openGiftRanking,
        child: Row(
          children: [
            // Realistic gold trophy (Vinay, 2026-11-21): same size as
            // the flat icon it replaces (22 high).
            Image.asset(
              'assets/images/gold_trophy.png',
              key: const Key('rocket-room-total-trophy'),
              height: 22,
            ),
            const SizedBox(width: 4),
            Text(
              _compactCoins(widget.lifetimeTotal),
              key: const Key('rocket-room-total'),
              style: const TextStyle(
                color: Color(0xFFFFB11B),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'room gifts',
              style: TextStyle(
                color: Color(0xFFB9C8F3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGiftRanking() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomGiftRankingScreen(
          roomId: widget.roomId,
          roomName: widget.roomName,
          backend: widget.backend,
        ),
      ),
    );
  }

  Widget _buildSeatsRow() {
    final seats = widget.seatMembers.take(8).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        key: const Key('rocket-room-seats'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          mainAxisExtent: 72,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          if (index >= seats.length) {
            return Column(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1B2340),
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFF56627E)),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Empty',
                  style: TextStyle(
                    color: Color(0xFF56627E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          }
          final member = seats[index];
          final name =
              member['display_name']?.toString() ?? 'User';
          final avatarKey = member['avatar_key']?.toString() ?? '';
          return Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: avatarKey.isEmpty
                    ? null
                    : NetworkImage(
                        widget.backend.fileUrl(avatarKey),
                        headers: widget.backend.fileHeaders,
                      ),
                onBackgroundImageError: avatarKey.isEmpty ? null : (_, __) {},
                child: avatarKey.isEmpty
                    ? const Icon(Icons.person_rounded,
                        color: Color(0xFFB9C8F3))
                    : null,
              ),
              const SizedBox(height: 3),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SizedBox(
        height: 320,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLadder(),
            Expanded(child: _buildRocketCentre()),
            _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLadder() {
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          const Icon(Icons.arrow_drop_up_rounded,
              color: Color(0xFF9D7BFF), size: 26),
          Expanded(
            child: ListView.builder(
              key: const Key('rocket-room-ladder'),
              controller: _ladderController,
              itemCount: rocketStageTargets.length,
              itemBuilder: (context, index) {
                final level = rocketStageTargets.length - index;
                final done = level <= _completed;
                final current = level == _currentLevel;
                return Container(
                  key: Key('rocket-room-ladder-level-$level'),
                  height: _ladderTileHeight,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: current
                        ? const Color(0xFF173E8F)
                        : const Color(0xFF071B4D),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: current
                          ? const Color(0xFFFFB11B)
                          : done
                              ? const Color(0xFF9D7BFF)
                              : const Color(0xFF56627E),
                      width: current ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          rocketMedalUrlForLevel(level),
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.rocket_launch_rounded,
                            color: Color(0xFF9D7BFF),
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Lv.$level',
                          style: TextStyle(
                            color: current
                                ? const Color(0xFFFFB11B)
                                : done
                                    ? const Color(0xFF9D7BFF)
                                    : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded,
              color: Color(0xFF9D7BFF), size: 26),
        ],
      ),
    );
  }

  Widget _buildRocketCentre() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 210,
                height: 210,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      Color(0x665D3BFF),
                      Color(0x225D3BFF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: _LaunchPadPainter()),
              ),
              Image.network(
                rocketMedalUrlForLevel(_currentLevel),
                key: const Key('rocket-room-rocket-image'),
                width: 168,
                height: 168,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => RoomStealthRocketLogo(
                  size: 132,
                  level: _currentLevel,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          key: const Key('rocket-room-countdown'),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2140),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF9D7BFF)),
          ),
          child: Text(
            _countdownText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final percentText = '${(_progressPercent * 100).floor()}%';
    return SizedBox(
      width: 34,
      child: Column(
        children: [
          Expanded(
            child: Container(
              key: const Key('rocket-room-progress'),
              width: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2340),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9D7BFF)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: _progressPercent.clamp(0.0, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[
                            Color(0xFF5E35B1),
                            Color(0xFF9D7BFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            key: const Key('rocket-room-progress-percent'),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2140),
              border: Border.all(color: const Color(0xFF9D7BFF)),
            ),
            child: Text(
              percentText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreeRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List<Widget>.generate(3, (index) {
                final rank = index + 1;
                final row = index < widget.ranking.length
                    ? widget.ranking[index]
                    : null;
                final name =
                    row?['display_name']?.toString() ?? '—';
                final avatarKey = row?['avatar_key']?.toString() ?? '';
                final sent = int.tryParse(
                        row?['sent_coins']?.toString() ?? '') ??
                    0;
                final ringColor = rank == 1
                    ? const Color(0xFFFFB11B)
                    : rank == 2
                        ? const Color(0xFFC0C8D8)
                        : const Color(0xFFCD7F32);
                return Column(
                  key: Key('rocket-room-top-$rank'),
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ringColor,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundImage: avatarKey.isEmpty
                                ? null
                                : NetworkImage(
                                    widget.backend.fileUrl(avatarKey),
                                    headers: widget.backend.fileHeaders,
                                  ),
                            onBackgroundImageError:
                                avatarKey.isEmpty ? null : (_, __) {},
                            child: avatarKey.isEmpty
                                ? const Icon(Icons.person_rounded,
                                    color: Color(0xFFB9C8F3))
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: -8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: ringColor,
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _compactCoins(sent),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB9C8F3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const Key('rocket-room-record-button'),
            onPressed: _showRecords,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF9D7BFF)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text(
              'Record',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    const tabs = <String>['Top 1', 'Top 2', 'Top 3', 'User'];
    return Container(
      key: const Key('rocket-room-rewards-panel'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF24304F)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
                    child: FilledButton(
                      key: Key('rocket-room-tab-${tabs[i].toLowerCase().replaceAll(' ', '-')}'),
                      onPressed: () => setState(() => _selectedTab = i),
                      style: FilledButton.styleFrom(
                        backgroundColor: _selectedTab == i
                            ? const Color(0xFFFF9D00)
                            : const Color(0xFF131C3A),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _selectedTab == i
                                ? const Color(0xFFFFD36A)
                                : const Color(0xFF9D7BFF),
                          ),
                        ),
                      ),
                      child: Text(
                        tabs[i],
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                key: const Key('rocket-room-help-button'),
                onPressed: _showHelp,
                icon: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF9D7BFF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRewardCards(),
        ],
      ),
    );
  }

  Widget _buildRewardCards() {
    if (_selectedTab == 3) return _buildUserCards();
    final reward = _topRewards[_selectedTab];
    return _rewardCards(reward: reward, showPool: true);
  }

  Widget _buildUserCards() {
    final myIndex = widget.ranking.indexWhere(
      (row) => row['user_id']?.toString() == widget.currentUserId,
    );
    final myRank = myIndex >= 0 ? myIndex + 1 : null;
    final mySent = myIndex >= 0
        ? int.tryParse(
                widget.ranking[myIndex]['sent_coins']?.toString() ?? '') ??
            0
        : 0;
    final entryRank = _rewardStatus?['entry_rank'];
    final canClaim = _rewardStatus?['can_claim'] == true;
    final reward = myRank != null && myRank <= 3
        ? _topRewards[myRank - 1]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          myRank == null
              ? 'You have not gifted in this room yet.'
              : 'You are Rank $myRank · sent ${_compactCoins(mySent)} coins',
          key: const Key('rocket-room-user-status'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          entryRank == null
              ? 'Entry rank: —'
              : 'Entry rank: ${int.tryParse(entryRank.toString()) ?? entryRank} · ${canClaim ? 'you can claim the pool' : 'pool claim not open yet'}',
          key: const Key('rocket-room-user-entry'),
          style: const TextStyle(
            color: Color(0xFFB9C8F3),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        if (canClaim)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.icon(
              key: const Key('rocket-room-claim-pool'),
              onPressed: _claiming ? null : _claimPool,
              icon: const Icon(Icons.redeem_rounded),
              label: Text(_claiming ? 'CLAIMING…' : 'Claim pool'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF9D00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (reward != null)
          _rewardCards(reward: reward, showPool: true)
        else
          _rewardCards(reward: null, showPool: true),
      ],
    );
  }

  Widget _rewardCards({required RocketTopReward? reward, required bool showPool}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _rewardCard(
            key: const Key('rocket-room-vip-card'),
            icon: Icons.workspace_premium_rounded,
            iconColor: const Color(0xFFFFB11B),
            title: reward == null ? 'VIP —' : 'VIP ${reward.vipLevel}',
            subtitle: reward == null
                ? 'top 3 only'
                : '${reward.vipDays} ${reward.vipDays == 1 ? 'day' : 'days'} · direct VIP',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _rewardCard(
            key: const Key('rocket-room-coins-card'),
            icon: Icons.monetization_on_rounded,
            iconColor: const Color(0xFFFFD36A),
            title: reward == null ? '—' : _formatLakh(reward.launchCoins),
            subtitle: 'coins on launch',
          ),
        ),
        if (showPool) ...[
          const SizedBox(width: 8),
          Expanded(child: _poolCard()),
        ],
      ],
    );
  }

  Widget _poolCard() {
    final tier = _rewardStatus?['tier'];
    final coinMin = int.tryParse(tier?['coin_min']?.toString() ?? '');
    final coinMax = int.tryParse(tier?['coin_max']?.toString() ?? '');
    final maxWinners = int.tryParse(tier?['max_winners']?.toString() ?? '');
    final String title;
    final String subtitle;
    if (tier == null) {
      title = _rewardStatusFailed ? 'Offline' : '…';
      subtitle = _rewardStatusFailed
          ? 'pool needs connection'
          : 'loading pool…';
    } else if (coinMin == null || coinMax == null || maxWinners == null) {
      title = '—';
      subtitle = 'random coins';
    } else {
      title = '${_compactCoins(coinMin)}–${_compactCoins(coinMax)}';
      subtitle = 'random coins · top $maxWinners';
    }
    return _rewardCard(
      key: const Key('rocket-room-pool-card'),
      icon: Icons.casino_rounded,
      iconColor: const Color(0xFF62FFD1),
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _rewardCard({
    required Key key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131C3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF24304F)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFD36A),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB9C8F3),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 70; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = 0.6 + random.nextDouble() * 1.1;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LaunchPadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final rings = <double>[0.46, 0.38, 0.30];
    final colors = <Color>[
      const Color(0xFF9D7BFF).withValues(alpha: 0.85),
      const Color(0xFF9D7BFF).withValues(alpha: 0.55),
      const Color(0xFF8B7CFF).withValues(alpha: 0.45),
    ];
    for (var i = 0; i < rings.length; i++) {
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * rings[i] * 2,
        height: size.width * rings[i] * 0.55,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors[i],
      );
    }
    final glowPaint = Paint()
      ..color = const Color(0xFF9D7BFF).withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.5,
        height: size.width * 0.14,
      ),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
