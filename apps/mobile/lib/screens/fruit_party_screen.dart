import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import '../vip/vip_visual_assets.dart';

Future<void> showFruitParty(BuildContext context, AppState state) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .5,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: FruitPartyScreen(state: state),
      ),
    ),
  );
}

class FruitPartyScreen extends StatefulWidget {
  const FruitPartyScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FruitPartyScreen> createState() => _FruitPartyScreenState();
}

class _FruitPartyScreenState extends State<FruitPartyScreen> {
  Timer? stateTimer;
  Timer? clockTimer;
  Map<String, dynamic> game = const <String, dynamic>{};
  int selectedBet = 5000;
  bool loading = true;
  String panel = 'game';
  bool loadingState = false;
  // Bet queue (Vinay, 2026-11-23 — "Fruit Party ko bhi queue wala bana
  // de"): same pattern as Greedy Girl. A tap queues the bet at once and
  // returns — the tiles and the amount chips never lock while a bet is
  // in flight, so rapid counting taps all land. _drainBetQueue sends
  // them one at a time; queuedDebit keeps the shown balance honest
  // until each bet is confirmed.
  bool drainingBetQueue = false;
  final List<_QueuedFruitBet> betQueue = <_QueuedFruitBet>[];
  final Map<String, int> queuedBets = <String, int>{};
  int queuedDebit = 0;
  int serverTimeAtSync = 0;
  int localTimeAtSync = 0;
  int _lightStep = 0;
  String? _popupDismissedRound;

  static const _fallbackFruits = <Map<String, dynamic>>[
    {'key': 'lemon', 'emoji': '🍋', 'label': 'Lemon', 'multiplier': 5},
    {'key': 'raspberry', 'emoji': '🫐', 'label': 'Raspberry', 'multiplier': 5},
    {'key': 'kiwi', 'emoji': '🥝', 'label': 'Kiwi', 'multiplier': 5},
    {'key': 'plum', 'emoji': '🍑', 'label': 'Plum', 'multiplier': 5},
    {'key': 'banana', 'emoji': '🍌', 'label': 'Banana', 'multiplier': 10},
    {
      'key': 'strawberry',
      'emoji': '🍓',
      'label': 'Strawberry',
      'multiplier': 15,
    },
    {
      'key': 'watermelon',
      'emoji': '🍉',
      'label': 'Watermelon',
      'multiplier': 25,
    },
    {'key': 'cherry', 'emoji': '🍒', 'label': 'Cherry', 'multiplier': 45},
  ];

  /// Approved bet amounts (Vinay): the server list merged with these, so
  /// 20M is always offered even before the server list gains it.
  static const _approvedBetAmounts = <int>[
    5000,
    25000,
    100000,
    500000,
    2000000,
    10000000,
    20000000,
  ];

  static List<int> _mergeBetAmounts(List? raw) {
    final values = <int>{..._approvedBetAmounts};
    if (raw != null) {
      for (final entry in raw) {
        final value = int.tryParse(entry.toString()) ?? 0;
        if (value > 0) values.add(value);
      }
    }
    final sorted = values.toList(growable: false)..sort();
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    // Separate game calls (no combined game-state any more): round +
    // timer + config, own bets + today's winnings, and the last 7
    // results each come from their own endpoint every 3s. The 250ms
    // clock below keeps the countdown ticking locally between syncs;
    // a poll only corrects it to server time.
    stateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_load(silent: true)),
    );
    clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || game.isEmpty) return;
      // The marquee chase advances on every tick (lights run
      // continuously); the tick already rebuilds the countdown every 250ms.
      _lightStep += 2;
      setState(() {});
    });
  }

  @override
  void dispose() {
    stateTimer?.cancel();
    clockTimer?.cancel();
    super.dispose();
  }

  int get _estimatedServerNow {
    if (serverTimeAtSync <= 0 || localTimeAtSync <= 0) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    return serverTimeAtSync +
        (DateTime.now().millisecondsSinceEpoch - localTimeAtSync);
  }

  Map<String, dynamic> get _round {
    final raw = game['round'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  Map<String, dynamic> get _config {
    final raw = game['config'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  List<Map<String, dynamic>> get _fruits {
    final raw = _config['fruits'];
    if (raw is! List) return _fallbackFruits;
    final rows = raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => (row['key']?.toString() ?? '').isNotEmpty)
        .toList(growable: false);
    return rows.isEmpty ? _fallbackFruits : rows;
  }

  /// The 8 grid cells, in row-major order (centre is the timer): the
  /// server fruit list padded with the fallback so the grid is always 8.
  List<Map<String, dynamic>> get _gridFruits =>
      List<Map<String, dynamic>>.generate(
        8,
        (i) => i < _fruits.length ? _fruits[i] : _fallbackFruits[i],
      );

  List<int> get _betAmounts => _mergeBetAmounts(_config['bet_amounts'] as List?);

  Map<String, dynamic> get _myBets {
    final raw = game['my_bets'];
    final base =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    // Queued (not yet confirmed) bets show at once, like Greedy Girl.
    for (final entry in queuedBets.entries) {
      final current = int.tryParse(base[entry.key]?.toString() ?? '') ?? 0;
      base[entry.key] = current + entry.value;
    }
    return base;
  }

  List<Map<String, dynamic>> get _history {
    final raw = game['history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  bool get _bettingOpen {
    if (_round['phase']?.toString() != 'betting') return false;
    final end = int.tryParse(_round['round_end']?.toString() ?? '') ?? 0;
    return end > _estimatedServerNow;
  }

  /// The marquee lights chase continuously, in every phase (Vinay
  /// 2026-11-21: "Lighting chlti rehni chahiye countinue"). No
  /// game-logic change, lights only.
  bool get _lightsSpinning => true;

  /// The winning fruit key of the latest settled round, if any.
  String? get _winningFruitKey {
    if (_round['phase']?.toString() != 'result_spin' || _history.isEmpty) {
      return null;
    }
    final latest = _history.first;
    final bonus = latest['bonus_fruits'];
    if (latest['lucky11'] == true &&
        bonus is List &&
        bonus.whereType<Map>().isNotEmpty) {
      return bonus.whereType<Map>().first['key']?.toString();
    }
    return (latest['fruit'] as Map?)?['key']?.toString();
  }

  /// Girl colour of the round-end popup: the winning fruit's girl; for a
  /// Silver/Gold Lucky result (no single fruit) the purple Greedy Girl
  /// mascot kisses instead.
  String get _winningGirlKey {
    if (_history.isEmpty) return 'purple';
    final latest = _history.first;
    if (latest['lucky_type'] == 'silver' ||
        latest['lucky_type'] == 'gold') {
      return 'purple';
    }
    final key = _winningFruitKey;
    return key == null ? 'purple' : fruitPartyGirlForFruitKey(key);
  }

  List<Map<String, dynamic>> get _topWinners {
    if (_history.isEmpty) return const [];
    final winners = _history.first['top_winners'];
    if (winners is! List) return const [];
    return winners
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .take(3)
        .toList(growable: false);
  }

  int get _remainingMs {
    final phase = _round['phase']?.toString();
    final targetKey = phase == 'result_spin' ? 'cycle_end' : 'round_end';
    final target = int.tryParse(_round[targetKey]?.toString() ?? '') ?? 0;
    return (target - _estimatedServerNow).clamp(0, 1 << 31).toInt();
  }

  Future<void> _load({bool silent = false}) async {
    if (loadingState || drainingBetQueue || betQueue.isNotEmpty) return;
    if (!widget.state.backendConnected) {
      if (!silent && mounted) {
        setState(() => loading = false);
      }
      return;
    }
    loadingState = true;
    Map<String, dynamic>? round;
    Map<String, dynamic>? bets;
    Map<String, dynamic>? history;
    // Each slice is fetched on its own (Vinay, 2026-11-23 — "game bhi
    // play nhi ho raha"): one failing slice must not blank the whole
    // game the way the old combined call did. The round is the only
    // required slice; bets/history fall back to empty below, and the
    // balance falls back to the cached coins.
    try {
      round = await widget.state.backend.fruitPartyRound();
    } catch (_) {
      round = null;
    }
    try {
      bets = await widget.state.backend.fruitPartyMyBets();
    } catch (_) {
      bets = null;
    }
    try {
      history = await widget.state.backend.fruitPartyHistory();
    } catch (_) {
      history = null;
    }
    try {
      await widget.state.refreshWallet(notify: false);
    } catch (_) {
      // Balance stays cached; the next poll retries.
    }
    loadingState = false;
    if (!mounted) return;
    if (round == null) {
      setState(() => loading = false);
      return;
    }
    if (round['ok'] != true) {
      if (!silent) {
        setState(() => loading = false);
      }
      return;
    }
    _applyState(<String, dynamic>{
      ...round,
      'wallet_balance': widget.state.coins,
      'today_winnings': bets?['today_winnings'] ?? 0,
      'my_bets': bets?['my_bets'] ?? const <String, dynamic>{},
      'history': history?['history'] ?? const <Map<String, dynamic>>[],
    });
  }

  void _applyState(Map<String, dynamic> value) {
    final serverTime =
        int.tryParse(value['server_time']?.toString() ?? '') ?? 0;
    final balance = int.tryParse(value['wallet_balance']?.toString() ?? '');
    if (balance != null) {
      widget.state.setCoinBalance(math.max(0, balance - queuedDebit).toInt());
    }
    final bets = value['config'] is Map
        ? Map<String, dynamic>.from(value['config'] as Map)['bet_amounts']
        : null;
    final allowed = _mergeBetAmounts(bets as List?);
    setState(() {
      game = Map<String, dynamic>.from(value);
      serverTimeAtSync = serverTime;
      localTimeAtSync = DateTime.now().millisecondsSinceEpoch;
      loading = false;
      if (!allowed.contains(selectedBet)) {
        selectedBet = allowed.first;
      }
    });
  }

  Future<void> _placeBet(String fruitKey) async {
    if (!_bettingOpen) return;

    final authoritativeWallet =
        int.tryParse(game['wallet_balance']?.toString() ?? '') ??
            widget.state.coins;
    final availableWallet =
        math.max(0, authoritativeWallet - queuedDebit).toInt();
    final amount = selectedBet;
    if (availableWallet < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins for this bet.')),
      );
      return;
    }

    final bet = _QueuedFruitBet(
      fruitKey: fruitKey,
      amount: amount,
      requestId:
          'fp-${widget.state.userId}-${DateTime.now().microsecondsSinceEpoch}',
    );

    setState(() {
      betQueue.add(bet);
      queuedBets[fruitKey] = (queuedBets[fruitKey] ?? 0) + amount;
      queuedDebit += amount;
    });
    widget.state.setCoinBalance(
      math.max(0, authoritativeWallet - queuedDebit).toInt(),
    );
    unawaited(_drainBetQueue());
  }

  void _removeQueuedBet(_QueuedFruitBet bet) {
    if (betQueue.isNotEmpty && identical(betQueue.first, bet)) {
      betQueue.removeAt(0);
    } else {
      betQueue.remove(bet);
    }
    final next = (queuedBets[bet.fruitKey] ?? 0) - bet.amount;
    if (next <= 0) {
      queuedBets.remove(bet.fruitKey);
    } else {
      queuedBets[bet.fruitKey] = next;
    }
    queuedDebit = math.max(0, queuedDebit - bet.amount).toInt();
  }

  void _applyBetAck(
    Map<String, dynamic> result,
    _QueuedFruitBet bet,
  ) {
    final next = Map<String, dynamic>.from(game);
    final baseBets = next['my_bets'] is Map
        ? Map<String, dynamic>.from(next['my_bets'] as Map)
        : <String, dynamic>{};
    final current =
        int.tryParse(baseBets[bet.fruitKey]?.toString() ?? '') ?? 0;
    baseBets[bet.fruitKey] = current + bet.amount;
    next['my_bets'] = baseBets;

    final wallet =
        int.tryParse(result['wallet_balance']?.toString() ?? '');
    if (wallet != null) {
      next['wallet_balance'] = wallet;
      widget.state.setCoinBalance(math.max(0, wallet - queuedDebit).toInt());
    }

    final serverTime =
        int.tryParse(result['server_time']?.toString() ?? '') ?? 0;
    if (serverTime > 0) {
      next['server_time'] = serverTime;
      serverTimeAtSync = serverTime;
      localTimeAtSync = DateTime.now().millisecondsSinceEpoch;
    }

    if (mounted) {
      setState(() {
        game = next;
        loading = false;
      });
    }
  }

  Future<void> _drainBetQueue() async {
    if (drainingBetQueue) return;
    drainingBetQueue = true;
    var needsReconcile = false;

    try {
      while (mounted && betQueue.isNotEmpty) {
        final bet = betQueue.first;
        Map<String, dynamic>? result;
        Object? failure;

        try {
          result = await widget.state.backend.fruitPartyBet(
            userId: widget.state.userId,
            fruitKey: bet.fruitKey,
            amount: bet.amount,
            requestId: bet.requestId,
          );
        } catch (error) {
          failure = error;
        }

        if (!mounted) return;
        setState(() => _removeQueuedBet(bet));

        if (result?['ok'] == true) {
          if (result?['my_bets'] is Map) {
            _applyState(Map<String, dynamic>.from(result!));
          } else {
            _applyBetAck(result!, bet);
          }
          continue;
        }

        final returnedState = result?['state'];
        if (returnedState is Map) {
          _applyState(Map<String, dynamic>.from(returnedState));
        } else {
          needsReconcile = true;
        }

        final raw = result?['error']?.toString().trim();
        final error = switch (raw) {
          'insufficient_coins' => 'Not enough coins for this bet.',
          'betting_locked' =>
            'Betting closed for this round. Next round is starting.',
          'games_disabled' => 'Games are disabled by the owner.',
          'unauthorized' || 'forbidden' =>
            'Login session expired. Sign in again.',
          null || '' => failure == null
              ? 'Bet could not reach the server. Try again.'
              : 'Bet connection failed. Try again.',
          _ => raw.replaceAll('_', ' '),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } finally {
      drainingBetQueue = false;
      if (mounted) {
        setState(() {});
        if (needsReconcile || betQueue.isEmpty) {
          unawaited(_load(silent: true));
        }
      }
    }
  }

  String _compact(int value) {
    if (value >= 10000000) {
      final v = value / 1000000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}M';
    }
    if (value >= 1000000) {
      final v = value / 1000000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final v = value / 1000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}K';
    }
    return '$value';
  }

  String _fruitEmoji(String key) {
    for (final fruit in _fruits) {
      if (fruit['key']?.toString() == key) {
        return fruit['emoji']?.toString() ?? '🎰';
      }
    }
    return '🎰';
  }

  String _resultLabel(Map<String, dynamic> result) {
    if (result['lucky_type'] == 'silver') return 'Silver Lucky';
    if (result['lucky_type'] == 'gold') return 'Gold Lucky';
    if (result['lucky11'] == true) return 'Lucky 11';
    return _fruitEmoji((result['fruit'] as Map?)?['key']?.toString() ?? '');
  }

  /// Whether [fruitKey] won the latest settled round.
  bool _fruitWon(String fruitKey) {
    if (_round['phase']?.toString() != 'result_spin' || _history.isEmpty) {
      return false;
    }
    final latest = _history.first;
    final bonus = latest['bonus_fruits'];
    if (latest['lucky11'] == true) {
      return bonus is List &&
          bonus.whereType<Map>().any((f) => f['key'] == fruitKey);
    }
    return (latest['fruit'] as Map?)?['key'] == fruitKey;
  }

  Widget _lucky(String type) {
    final silver = type == 'silver';
    final active =
        _round['phase'] == 'result_spin' &&
        _history.isNotEmpty &&
        _history.first['lucky_type'] == type;
    return Expanded(
      child: InkWell(
        key: Key('fruit-party-$type-lucky'),
        onTap: () => setState(() => panel = 'rules'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: silver
                  ? const [Color(0xFFF5F2FF), Color(0xFFB9AED6)]
                  : const [Color(0xFFFFE27A), Color(0xFFD4A017)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFFF5C542)
                  : silver
                  ? const Color(0xFFB9AED6)
                  : const Color(0xFFD4A017),
              width: active ? 3 : 1,
            ),
            // 3D raised button: bright top edge, dark drop shadow below.
            boxShadow: [
              const BoxShadow(
                color: Color(0xFF000000),
                offset: Offset(0, 3),
                blurRadius: 4,
              ),
              BoxShadow(
                color: active
                    ? (silver
                          ? const Color(0xFFB9AED6)
                          : const Color(0xFFF5C542))
                    : Colors.transparent,
                blurRadius: active ? 14 : 0,
              ),
            ],
          ),
          child: Text(
            silver ? '★ Silver Lucky' : '★ Gold Lucky',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: silver
                  ? const Color(0xFF2A1155)
                  : const Color(0xFF3A2A00),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timerCell(int seconds) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3D1A6E), Color(0xFF1B0B38)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF5C542), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0xFFF5C542), blurRadius: 12),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                seconds.toString().padLeft(2, '0'),
                key: const Key('fruit-party-countdown-number'),
                style: const TextStyle(
                  color: Color(0xFFF5C542),
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                _round['phase']?.toString() == 'result_spin'
                    ? 'OPENING RESULT'
                    : _bettingOpen
                    ? 'PLACE YOUR BET'
                    : 'RESULT',
                style: const TextStyle(fontSize: 8, color: Color(0xFFEDE7FF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridPanel(int seconds) {
    final cells = _gridFruits;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1155), Color(0xFF150A2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: const Color(0xFFD4A017), width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final fruit in cells.take(3)) _girlTile(fruit),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [_girlTile(cells[3]), _timerCell(seconds), _girlTile(cells[4])],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final fruit in cells.skip(5)) _girlTile(fruit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _girlTile(Map<String, dynamic> fruit) {
    final key = fruit['key']?.toString() ?? '';
    final girl = fruitPartyGirlForFruitKey(key);
    final bet = int.tryParse(_myBets[key]?.toString() ?? '') ?? 0;
    final won = _fruitWon(key);
    return _GirlTile(
      fruit: fruit,
      girl: girl,
      won: won,
      bet: bet,
      compactBet: bet > 0 ? _compact(bet) : null,
      onTap: _bettingOpen ? () => unawaited(_placeBet(key)) : null,
    );
  }

  /// The bet tray: "Select the amount of coins" + the 7 bet buttons,
  /// below the grid (no overlap — everything stays clear) and raised
  /// in 3D like a real casino tray.
  Widget _betTray() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D1A6E), Color(0xFF221242)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C542), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          BoxShadow(color: Color(0xFFF5C542), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select the amount of coins › Select kiss',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFFF5C542),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < _betAmounts.length; i++)
                _betChip(_betAmounts[i], i),
            ],
          ),
        ],
      ),
    );
  }

  static const _betChipColors = <Color>[
    Color(0xFF8B5CF6),
    Color(0xFF3B82F6),
    Color(0xFFEF4444),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF14B8A6),
  ];

  Widget _betChip(int amount, int index) {
    final selected = amount == selectedBet;
    final color = _betChipColors[index % _betChipColors.length];
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: index == _betAmounts.length - 1 ? 0 : 4),
        child: InkWell(
          key: Key('fruit-party-bet-${_compact(amount)}'),
          onTap: () => setState(() => selectedBet = amount),
          child: Container(
            height: 28,
            alignment: Alignment.center,
            // 3D raised chip, like the top coin bar (Vinay 2026-11-21):
            // glossy bright top, dark bottom, strong drop shadow.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(Colors.white, color, 0.35)!,
                  color,
                  Color.lerp(Colors.black, color, 0.35)!,
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFFF5C542)
                    : Colors.white.withValues(alpha: .45),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                const BoxShadow(
                  color: Color(0xFF000000),
                  offset: Offset(0, 3),
                  blurRadius: 4,
                ),
                if (selected)
                  const BoxShadow(
                    color: Color(0xFFF5C542),
                    blurRadius: 8,
                  ),
              ],
            ),
            child: Text(
              _compact(amount),
              maxLines: 1,
              style: TextStyle(
                color: selected ? const Color(0xFF1A1400) : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _winningGlyph(Map<String, dynamic> result) {
    if (result['lucky_type'] == 'silver' ||
        result['lucky_type'] == 'gold' ||
        result['lucky11'] == true) {
      return '⭐';
    }
    return _fruitEmoji((result['fruit'] as Map?)?['key']?.toString() ?? '');
  }

  Widget _winnersStrip() {
    final latest = _history.isEmpty ? null : _history.first;
    final winners = latest?['top_winners'];
    final top = winners is List
        ? winners.whereType<Map>().take(3).toList(growable: false)
        : const <Map<String, dynamic>>[];
    return Container(
      key: const Key('fruit-party-winners-strip'),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0F3D),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFD4A017)),
      ),
      child: latest == null
          ? const Center(
              child: Text(
                'Winners will appear here after the round.',
                style: TextStyle(color: Color(0xFFC9BEE8), fontSize: 10),
              ),
            )
          : Row(
              children: [
                Text(
                  _winningGlyph(latest),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Top winners',
                            style: TextStyle(
                              color: Color(0xFFF5C542),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              top.isEmpty
                                  ? 'No winning bet in this round.'
                                  : top
                                      .map(
                                        (w) =>
                                            '${w['display_name'] ?? 'User'} · +${_compact(int.tryParse(w['winning_coins']?.toString() ?? '') ?? 0)}',
                                      )
                                      .join('   '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFEDE7FF),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_myBets.isEmpty)
                        const Text(
                          'You didn\'t select anything in this round.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFC9BEE8),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Round-end popup (Opening result phase): the winning girl — her kiss
  /// video playing — with the top 3 winners beside her. Dismissible with
  /// the × button; it returns for the next round. The winners strip
  /// below stays as well.
  Widget _resultPopup() {
    if (_round['phase']?.toString() != 'result_spin' || _history.isEmpty) {
      return const SizedBox.shrink();
    }
    final roundId = _round['round_id']?.toString() ?? '';
    if (_popupDismissedRound == roundId) return const SizedBox.shrink();
    final latest = _history.first;
    final girl = _winningGirlKey;
    final fruitKey = _winningFruitKey;
    final winLabel = latest['lucky_type'] == 'silver'
        ? 'Silver Lucky'
        : latest['lucky_type'] == 'gold'
        ? 'Gold Lucky'
        : latest['lucky11'] == true
        ? 'Lucky 11'
        : fruitKey == null
        ? 'Result'
        : '${_fruits.firstWhere((f) => f['key'] == fruitKey, orElse: () => {'label': fruitKey})['label'] ?? fruitKey} ×${_fruits.firstWhere((f) => f['key'] == fruitKey, orElse: () => {'multiplier': ''})['multiplier'] ?? ''}';
    final winners = _topWinners;
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF150A2E).withValues(alpha: .72),
        alignment: Alignment.center,
        child: Container(
          key: const Key('fruit-party-result-popup'),
          width: 330,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3D1A6E), Color(0xFF1B0B38)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF5C542), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0xFF000000), blurRadius: 16),
              BoxShadow(color: Color(0xFFF5C542), blurRadius: 12),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'WINNER',
                    style: TextStyle(
                      color: Color(0xFFF5C542),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('fruit-party-result-popup-close'),
                    tooltip: 'Close result',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: () =>
                        setState(() => _popupDismissedRound = roundId),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFFF5C542),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 104,
                      height: 150,
                      child: _KissVideo(
                        videoUrl: fruitPartyGirlKissUrl(girl),
                        stillUrl: fruitPartyGirlStillUrl(girl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          winLabel,
                          style: const TextStyle(
                            color: Color(0xFFEDE7FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'TOP 3 WINNERS',
                          style: TextStyle(
                            color: Color(0xFFF5C542),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          key: const Key('fruit-party-top3-winners'),
                          child: winners.isEmpty
                              ? const Text(
                                  'No winning bet in this round.',
                                  style: TextStyle(
                                    color: Color(0xFFEDE7FF),
                                    fontSize: 11,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0; i < winners.length; i++)
                                      Text(
                                        '${i + 1}. ${winners[i]['display_name'] ?? 'User'} — +${_compact(int.tryParse(winners[i]['winning_coins']?.toString() ?? '') ?? 0)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFEDE7FF),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Phase tab above the grid ("Opening result: 26s" in the result
  /// phase, "Betting: 26s" while betting), like the reference screen.
  Widget _phaseTab(int seconds) {
    final phase = _round['phase']?.toString();
    final padded = seconds.toString().padLeft(2, '0');
    final label = phase == 'result_spin'
        ? 'Opening result: ${padded}s'
        : phase == 'betting'
        ? 'Betting: ${padded}s'
        : 'Result';
    return Container(
      key: const Key('fruit-party-phase-tab'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0F3D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4A017)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF5C542),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_remainingMs / 1000).ceil();
    final wallet =
        int.tryParse(game['wallet_balance']?.toString() ?? '') ??
        widget.state.coins;
    final winnings =
        int.tryParse(game['today_winnings']?.toString() ?? '') ?? 0;
    return Material(
      color: const Color(0xFF150A2E),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  IconButton(
                    tooltip: panel == 'game' ? 'Game records' : 'Back to game',
                    onPressed: () => setState(
                      () => panel = panel == 'game' ? 'records' : 'game',
                    ),
                    icon: Icon(
                      panel == 'game'
                          ? Icons.history_rounded
                          : Icons.arrow_back_rounded,
                      color: const Color(0xFFF5C542),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      panel == 'game'
                          ? 'Girls Party'
                          : panel == 'rules'
                          ? 'How to play'
                          : 'Game records',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF5C542),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rules',
                    onPressed: () => setState(() => panel = 'rules'),
                    icon: const Icon(
                      Icons.help_outline,
                      size: 20,
                      color: Color(0xFFF5C542),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Girls Party',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: DarkVibeXIconPalette.pink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : panel != 'game'
                  ? _detailPanel()
                  : game.isEmpty
                  ? Center(
                      child: TextButton(
                        onPressed: _load,
                        child: const Text('Game unavailable · Retry'),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: 400,
                            height: 480,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        'Round #${_round['round_id'] ?? '-'} of Today',
                                        style: const TextStyle(
                                          color: Color(0xFFEDE7FF),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _phaseTab(seconds),
                                      const SizedBox(height: 4),
                                      _MarqueeFrame(
                                        key: const Key(
                                          'fruit-party-lights-spinning',
                                        ),
                                        spinning: _lightsSpinning,
                                        step: _lightStep,
                                        child: _gridPanel(seconds),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _lucky('silver'),
                                          const SizedBox(width: 8),
                                          _lucky('gold'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _betTray(),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Coin Balance  ${_compact(wallet)}',
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFEDE7FF),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Profits of Today  ${_compact(winnings)}',
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFF5C542),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _winnersStrip(),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: 20,
                                        child: Row(
                                          children: [
                                            const Text(
                                              'Last 7  ',
                                              style: TextStyle(
                                                color: Color(0xFFC9BEE8),
                                                fontSize: 10,
                                              ),
                                            ),
                                            Expanded(
                                              child: ListView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                children: [
                                                  for (final result
                                                      in _history.take(7))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 6,
                                                          ),
                                                      child: _historyThumb(
                                                        result,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  _resultPopup(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyThumb(Map<String, dynamic> result) {
    if (result['lucky_type'] == 'silver' ||
        result['lucky_type'] == 'gold' ||
        result['lucky11'] == true) {
      return Tooltip(
        message: 'Round ${result['round_id']}: ${_resultLabel(result)}',
        child: const Text('⭐', style: TextStyle(fontSize: 18)),
      );
    }
    final key = (result['fruit'] as Map?)?['key']?.toString() ?? '';
    final girl = fruitPartyGirlForFruitKey(key);
    return Tooltip(
      message: 'Round ${result['round_id']}: ${_resultLabel(result)}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.network(
          fruitPartyGirlStillUrl(girl),
          width: 26,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Text(
            _resultLabel(result),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _detailPanel() => ListView(
    padding: const EdgeInsets.all(16),
    children: panel == 'rules'
        ? [
            const Text(
              'Choose a coin amount, then tap a girl to place a bet on her fruit. A winning fruit pays the multiplier shown on its tile.',
              style: TextStyle(color: Color(0xFFEDE7FF)),
            ),
            const SizedBox(height: 14),
            Text(
              'Silver Lucky • ${_fruits.take(4).map((f) => "${f['emoji']} ${f['label']}").join(', ')} all win at their displayed multipliers.',
              style: const TextStyle(color: Color(0xFFEDE7FF)),
            ),
            const SizedBox(height: 14),
            Text(
              'Gold Lucky • ${_fruits.skip(4).map((f) => "${f['emoji']} ${f['label']}").join(', ')} all win at their displayed multipliers.',
              style: const TextStyle(color: Color(0xFFF5C542)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Lucky tiles show special results; bets are placed on fruits. Betting closes when the timer reaches zero. Results settle on the server. Earlier Lucky 11 records retain their original winning fruits.',
              style: TextStyle(color: Color(0xFFEDE7FF)),
            ),
          ]
        : [
            if (_history.isEmpty) const Text('No settled rounds yet.'),
            for (final result in _history)
              Card(
                color: const Color(0xFF221242),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF4A2E7A)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Round #${result['round_id']} · ${_resultLabel(result)}',
                        style: const TextStyle(
                          color: Color(0xFFF5C542),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (result['bonus_fruits'] is List)
                        Text(
                          (result['bonus_fruits'] as List)
                              .whereType<Map>()
                              .map((f) => '${f['emoji']} ${f['multiplier']}×')
                              .join('  '),
                        ),
                      const SizedBox(height: 6),
                      if (result['top_winners'] is List &&
                          (result['top_winners'] as List).isNotEmpty)
                        for (final winner
                            in (result['top_winners'] as List).whereType<Map>())
                          Text(
                            '${winner['display_name'] ?? 'User'} · +${_compact(int.tryParse(winner['winning_coins']?.toString() ?? '') ?? 0)}',
                          )
                      else
                        const Text('No winning bet in this round.'),
                    ],
                  ),
                ),
              ),
          ],
  );
}

/// A Fruit Party grid tile: one girl per fruit. The resting tile shows
/// her still (full girl, contain); the winning tile plays her kiss video
/// (Greedy-Girl style, real video, not an emoji animation). The
/// multiplier reads "N times" under her picture, like the reference
/// screen, and the tile border matches her dress colour.
class _GirlTile extends StatelessWidget {
  const _GirlTile({
    required this.fruit,
    required this.girl,
    required this.won,
    required this.bet,
    required this.compactBet,
    required this.onTap,
  });

  final Map<String, dynamic> fruit;
  final String girl;
  final bool won;
  final int bet;
  final String? compactBet;
  final VoidCallback? onTap;

  /// Tile border colour = the girl's dress colour.
  static const Map<String, Color> _borderByGirl = <String, Color>{
    'purple': Color(0xFFA855F7),
    'blue': Color(0xFF3B82F6),
    'red': Color(0xFFEF4444),
    'green': Color(0xFF22C55E),
    'pink': Color(0xFFEC4899),
    'gold': Color(0xFFF59E0B),
    'teal': Color(0xFF14B8A6),
    'orange': Color(0xFFF97316),
  };

  @override
  Widget build(BuildContext context) {
    final key = fruit['key']?.toString() ?? '';
    final border = _borderByGirl[girl] ?? const Color(0xFF4A2E7A);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          key: Key('fruit-party-$key'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 62,
            decoration: BoxDecoration(
              color: won ? const Color(0xFF3A1E63) : const Color(0xFF1E0F3D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: won ? const Color(0xFFF5C542) : border,
                width: won ? 2 : 1,
              ),
              boxShadow: won
                  ? [
                      const BoxShadow(
                        color: Color(0xFFF5C542),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: won
                      ? _KissVideo(
                          videoUrl: fruitPartyGirlKissUrl(girl),
                          stillUrl: fruitPartyGirlStillUrl(girl),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          fruitPartyGirlStillUrl(girl),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              fruit['emoji']?.toString() ?? '🎰',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                ),
                if (bet > 0)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5C542),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        compactBet ?? '',
                        style: const TextStyle(
                          color: Color(0xFF1A1400),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF000000),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(9),
                      ),
                    ),
                    child: Text(
                      "${fruit['multiplier']} times",
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFF5C542),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
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
}

/// Plays a girl's kiss video (muted, looping) with her still as the
/// fallback while it loads or when the video is unavailable (offline,
/// test). Same pattern as the Greedy Girl kiss emote.
class _KissVideo extends StatefulWidget {
  const _KissVideo({
    required this.videoUrl,
    required this.stillUrl,
    required this.fit,
  });

  final String videoUrl;
  final String stillUrl;
  final BoxFit fit;

  @override
  State<_KissVideo> createState() => _KissVideoState();
}

class _KissVideoState extends State<_KissVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void didUpdateWidget(covariant _KissVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      unawaited(_init());
    }
  }

  Future<void> _init() async {
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = controller;
    try {
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.initialize();
    } catch (_) {
      // Video unavailable (offline / test): keep the still.
      return;
    }
    if (!mounted) return;
    setState(() => _ready = true);
    unawaited(controller.play());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_ready && controller != null && controller.value.isInitialized) {
      return FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    return Image.network(
      widget.stillUrl,
      fit: widget.fit,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// Marquee light frame around the grid panel: bulbs on all four sides.
/// A bright chase comet travels around the panel CONTINUOUSLY, in every
/// phase (Vinay 2026-11-21: lighting continue chalti rehni chahiye),
/// like the running lights on other apps' boards. The chase step
/// advances on the screen's 250ms clock tick; [step] is the comet's
/// head position.
/// The SIDE bulbs are bigger and brighter than the top/bottom ones
/// (more side lighting, per Vinay): 10px with a constant gold glow,
/// versus 7px on the top and bottom.
class _MarqueeFrame extends StatelessWidget {
  const _MarqueeFrame({
    super.key,
    required this.spinning,
    required this.step,
    required this.child,
  });

  final bool spinning;
  final int step;
  final Widget child;

  static const int _topCount = 25;
  static const int _sideCount = 19;

  int get _total => (_topCount + _sideCount) * 2;

  bool _hot(int index) {
    if (!spinning) return false;
    return ((index - step) % _total) < 5;
  }

  Widget _bulb(int index, {bool side = false}) {
    final hot = _hot(index);
    final size = side ? 10.0 : 7.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hot
            ? const Color(0xFFFFE27A)
            : spinning
            ? const Color(0xFF8A6D1B)
            : const Color(0xFFF5C542),
        boxShadow: hot
            ? [
                BoxShadow(
                  color: const Color(0xFFF5C542),
                  blurRadius: side ? 10 : 6,
                  spreadRadius: side ? 2 : 1,
                ),
              ]
            : side
            ? [
                const BoxShadow(
                  color: Color(0xFFF5C542),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Perimeter order: top left->right, right top->bottom, bottom
    // right->left, left bottom->top. The bottom row and left column are
    // built reversed so their visual order matches the index order.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < _topCount; i++) _bulb(i),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _sideCount; i++)
                  _bulb(_total - 1 - i, side: true),
              ],
            ),
            const SizedBox(width: 3),
            Expanded(child: child),
            const SizedBox(width: 3),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _sideCount; i++)
                  _bulb(_topCount + i, side: true),
              ],
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < _topCount; i++)
              _bulb(_topCount + _sideCount + _topCount - 1 - i),
          ],
        ),
      ],
    );
  }
}

class _QueuedFruitBet {
  const _QueuedFruitBet({
    required this.fruitKey,
    required this.amount,
    required this.requestId,
  });

  final String fruitKey;
  final int amount;
  final String requestId;
}
