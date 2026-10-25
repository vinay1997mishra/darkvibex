import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

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
  bool placingBet = false;
  int serverTimeAtSync = 0;
  int localTimeAtSync = 0;

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    stateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_load(silent: true)),
    );
    clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && game.isNotEmpty) setState(() {});
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

  List<int> get _betAmounts {
    final raw = _config['bet_amounts'];
    if (raw is! List) {
      return const [5000, 25000, 100000, 500000, 2000000, 10000000];
    }
    final values = raw
        .map((value) => int.tryParse(value.toString()) ?? 0)
        .where((value) => value > 0)
        .toList(growable: false);
    return values.isEmpty
        ? const [5000, 25000, 100000, 500000, 2000000, 10000000]
        : values;
  }

  Map<String, dynamic> get _myBets {
    final raw = game['my_bets'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
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

  int get _remainingMs {
    final phase = _round['phase']?.toString();
    final targetKey = phase == 'result_spin' ? 'cycle_end' : 'round_end';
    final target = int.tryParse(_round[targetKey]?.toString() ?? '') ?? 0;
    return (target - _estimatedServerNow).clamp(0, 1 << 31).toInt();
  }

  Future<void> _load({bool silent = false}) async {
    if (loadingState || placingBet) return;
    if (!widget.state.backendConnected) {
      if (!silent && mounted) {
        setState(() => loading = false);
      }
      return;
    }
    loadingState = true;
    Map<String, dynamic>? value;
    try {
      value = await widget.state.backend.fruitPartyState();
    } finally {
      loadingState = false;
    }
    if (!mounted) return;
    if (value == null) {
      setState(() => loading = false);
      return;
    }
    if (value['ok'] != true) {
      if (!silent) {
        setState(() => loading = false);
      }
      return;
    }
    _applyState(value);
  }

  void _applyState(Map<String, dynamic> value) {
    final serverTime =
        int.tryParse(value['server_time']?.toString() ?? '') ?? 0;
    final balance = int.tryParse(value['wallet_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    final bets = value['config'] is Map
        ? Map<String, dynamic>.from(value['config'] as Map)['bet_amounts']
        : null;
    final allowed = bets is List
        ? bets
              .map((entry) => int.tryParse(entry.toString()) ?? 0)
              .where((entry) => entry > 0)
              .toList(growable: false)
        : const <int>[];
    setState(() {
      game = Map<String, dynamic>.from(value);
      serverTimeAtSync = serverTime;
      localTimeAtSync = DateTime.now().millisecondsSinceEpoch;
      loading = false;
      if (allowed.isNotEmpty && !allowed.contains(selectedBet)) {
        selectedBet = allowed.first;
      }
    });
  }

  Future<void> _placeBet(String fruitKey) async {
    if (placingBet || !_bettingOpen) return;
    setState(() => placingBet = true);
    final requestId =
        'fp_${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}';
    final result = await widget.state.backend.fruitPartyBet(
      userId: widget.state.userId,
      fruitKey: fruitKey,
      amount: selectedBet,
      requestId: requestId,
    );
    if (!mounted) return;
    setState(() => placingBet = false);

    if (result?['ok'] == true) {
      _applyState(Map<String, dynamic>.from(result!));
      return;
    }
    final nested = result?['state'];
    if (nested is Map && nested['ok'] == true) {
      _applyState(Map<String, dynamic>.from(nested));
    }
    final error =
        result?['error']?.toString().replaceAll('_', ' ') ?? 'Bet failed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: silver
                  ? const [Color(0xFFE2E8FF), Color(0xFF625DD5)]
                  : const [Color(0xFF6D63F5), Color(0xFF2C8FE8)],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? Colors.white : const Color(0xFF776DFF),
              width: active ? 3 : 1,
            ),
            boxShadow: active
                ? [const BoxShadow(color: Color(0xFF776DFF), blurRadius: 14)]
                : null,
          ),
          child: Text(
            silver ? 'Silver\nLucky' : 'Gold\nLucky',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF291208),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fruitTile(Map<String, dynamic> fruit) {
    final key = fruit['key']?.toString() ?? '';
    final bet = int.tryParse(_myBets[key]?.toString() ?? '') ?? 0;
    final latest = _history.isEmpty ? null : _history.first;
    final bonus = latest?['bonus_fruits'];
    final won =
        _round['phase'] == 'result_spin' &&
        latest != null &&
        (latest['lucky11'] == true
            ? bonus is List &&
                  bonus.whereType<Map>().any((f) => f['key'] == key)
            : (latest['fruit'] as Map?)?['key'] == key);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
          key: Key('fruit-party-$key'),
          onTap: _bettingOpen && !placingBet ? () => _placeBet(key) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 79,
            decoration: BoxDecoration(
              color: won ? const Color(0xFF273C82) : const Color(0xFF121932),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: won || bet > 0
                    ? const Color(0xFF85E7FF)
                    : const Color(0xFF46457C),
                width: won ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bet > 0 ? _compact(bet) : fruit['label']?.toString() ?? key,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    color: bet > 0 ? Color(0xFF776DFF)Accent : Color(0xFFF1F5FF),
                  ),
                ),
                Text(
                  fruit['emoji']?.toString() ?? '🍒',
                  style: const TextStyle(fontSize: 29),
                ),
                Text(
                  '${fruit['multiplier']}×',
                  style: const TextStyle(
                    color: Color(0xFFBBD8FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
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
      color: const Color(0xFF0B1028),
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
                      color: Color(0xFF9A8CFF),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      panel == 'game'
                          ? 'Fruit Party'
                          : panel == 'rules'
                          ? 'How to play'
                          : 'Game records',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFBBD8FF),
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
                      color: Color(0xFF9A8CFF),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Fruit Party',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF9A8CFF),
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
                            height: 360,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Round #${_round['round_id'] ?? '-'}',
                                    style: const TextStyle(
                                      color: Color(0xFFF1F5FF),
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF342F82),
                                          Color(0xFF151A3A),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF786CFF),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            for (final fruit in _fruits.take(4))
                                              _fruitTile(fruit),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 3,
                                          ),
                                          child: Row(
                                            children: [
                                              _lucky('silver'),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  height: 54,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFF6258E8),
                                                            Color(0xFF25275F),
                                                          ],
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          9,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFFFFCF84,
                                                      ),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        seconds
                                                            .toString()
                                                            .padLeft(2, '0'),
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFFFFE598,
                                                          ),
                                                          fontSize: 30,
                                                          height: 1,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                      Text(
                                                        _bettingOpen
                                                            ? 'PLACE YOUR BET'
                                                            : 'RESULT',
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _lucky('gold'),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            for (final fruit in _fruits.skip(4))
                                              _fruitTile(fruit),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 38,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        for (final amount in _betAmounts)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: ChoiceChip(
                                              selected: amount == selectedBet,
                                              selectedColor: const Color(
                                                0xFF7662D5,
                                              ),
                                              backgroundColor: const Color(
                                                0xFF784A22,
                                              ),
                                              labelStyle: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              label: Text(_compact(amount)),
                                              onSelected: placingBet
                                                  ? null
                                                  : (_) => setState(
                                                      () =>
                                                          selectedBet = amount,
                                                    ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Text(
                                        'Balance  ${_compact(wallet)}',
                                        style: const TextStyle(
                                          color: Color(0xFFF1F5FF),
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Today win  ${_compact(winnings)}',
                                        style: const TextStyle(
                                          color: Color(0xFF9A8CFF),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  SizedBox(
                                    height: 25,
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Last 7  ',
                                          style: TextStyle(
                                            color: Color(0xFFA3AED6),
                                            fontSize: 10,
                                          ),
                                        ),
                                        Expanded(
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            children: [
                                              for (final result
                                                  in _history.take(7))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: Tooltip(
                                                    message:
                                                        'Round ${result['round_id']}: ${_resultLabel(result)}',
                                                    child: Text(
                                                      _resultLabel(result),
                                                      style: TextStyle(
                                                        fontSize:
                                                            result['lucky11'] ==
                                                                true
                                                            ? 11
                                                            : 18,
                                                        color:
                                                            result['lucky_type'] ==
                                                                'silver'
                                                            ? const Color(
                                                                0xFFCCC9FF,
                                                              )
                                                            : Color(0xFF9A8CFF),
                                                      ),
                                                    ),
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

  Widget _detailPanel() => ListView(
    padding: const EdgeInsets.all(16),
    children: panel == 'rules'
        ? [
            const Text(
              'Choose a coin amount, then tap a fruit to place a bet. A winning fruit pays the multiplier shown on its tile.',
              style: TextStyle(color: Color(0xFFF1F5FF)),
            ),
            const SizedBox(height: 14),
            Text(
              'Silver Lucky • ${_fruits.take(4).map((f) => "${f['emoji']} ${f['label']}").join(', ')} all win at their displayed multipliers.',
              style: const TextStyle(color: Color(0xFFCCC9FF)),
            ),
            const SizedBox(height: 14),
            Text(
              'Gold Lucky • ${_fruits.skip(4).map((f) => "${f['emoji']} ${f['label']}").join(', ')} all win at their displayed multipliers.',
              style: const TextStyle(color: Color(0xFF9A8CFF)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Lucky tiles show special results; bets are placed on fruits. Betting closes when the timer reaches zero. Results settle on the server. Earlier Lucky 11 records retain their original winning fruits.',
              style: TextStyle(color: Color(0xFFF1F5FF)),
            ),
          ]
        : [
            if (_history.isEmpty) const Text('No settled rounds yet.'),
            for (final result in _history)
              Card(
                color: const Color(0xFF161D3D),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF494780)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Round #${result['round_id']} · ${_resultLabel(result)}',
                        style: const TextStyle(
                          color: Color(0xFF9A8CFF),
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
