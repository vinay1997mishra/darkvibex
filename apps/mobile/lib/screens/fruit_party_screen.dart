import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

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
  bool placingBet = false;
  int serverTimeAtSync = 0;
  int localTimeAtSync = 0;

  static const _fallbackFruits = <Map<String, dynamic>>[
    {'key': 'lemon', 'emoji': '🍋', 'label': 'Lemon', 'multiplier': 5},
    {'key': 'raspberry', 'emoji': '🫐', 'label': 'Raspberry', 'multiplier': 5},
    {'key': 'kiwi', 'emoji': '🥝', 'label': 'Kiwi', 'multiplier': 5},
    {'key': 'plum', 'emoji': '🍑', 'label': 'Plum', 'multiplier': 5},
    {'key': 'banana', 'emoji': '🍌', 'label': 'Banana', 'multiplier': 10},
    {'key': 'strawberry', 'emoji': '🍓', 'label': 'Strawberry', 'multiplier': 15},
    {'key': 'watermelon', 'emoji': '🍉', 'label': 'Watermelon', 'multiplier': 25},
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
    clockTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (mounted && game.isNotEmpty) setState(() {});
      },
    );
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
    if (!widget.state.backendConnected) {
      if (!silent && mounted) {
        setState(() => loading = false);
      }
      return;
    }
    final value = await widget.state.backend.fruitPartyState();
    if (!mounted || value == null) return;
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
    final balance =
        int.tryParse(value['wallet_balance']?.toString() ?? '');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
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

  @override
  Widget build(BuildContext context) {
    final phase = _round['phase']?.toString() ?? 'betting';
    final seconds = (_remainingMs / 1000).ceil();
    final history = _history;
    final latest = history.isNotEmpty ? history.first : null;
    final wallet =
        int.tryParse(game['wallet_balance']?.toString() ?? '') ??
            widget.state.coins;
    final winnings =
        int.tryParse(game['today_winnings']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: const Text(
          'Fruit Party',
          style: TextStyle(
            color: TinniPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TinniBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _metric(
                            'Balance',
                            _compact(wallet),
                            Icons.monetization_on_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metric(
                            'Today win',
                            _compact(winnings),
                            Icons.emoji_events_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metric(
                            phase == 'result_spin' ? 'Result' : 'Bet time',
                            '${seconds}s',
                            phase == 'result_spin'
                                ? Icons.casino_rounded
                                : Icons.timer_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TinniPanel(
                      child: Column(
                        children: [
                          Text(
                            phase == 'result_spin'
                                ? 'RESULT SPIN'
                                : 'BETTING OPEN',
                            style: TextStyle(
                              color: phase == 'result_spin'
                                  ? Colors.orangeAccent
                                  : TinniPalette.gold,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            phase == 'result_spin' && latest != null
                                ? (latest['lucky11'] == true
                                    ? 'LUCKY 11 • 4 FRUITS WIN'
                                    : '${_fruitEmoji((latest['fruit'] as Map?)?['key']?.toString() ?? '')} ${(latest['fruit'] as Map?)?['label'] ?? 'Result'}')
                                : 'Round #${_round['round_id'] ?? '-'}',
                            style: const TextStyle(
                              fontSize: 20,
                              color: TinniPalette.cream,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active ${_round['active_players'] ?? 0} • Total bet ${_compact(int.tryParse(_round['total_bet']?.toString() ?? '') ?? 0)}',
                            style: const TextStyle(
                              color: TinniPalette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bet amount',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final amount in _betAmounts)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                selected: selectedBet == amount,
                                label: Text(_compact(amount)),
                                onSelected: placingBet
                                    ? null
                                    : (_) =>
                                        setState(() => selectedBet = amount),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _fruits.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 7,
                        mainAxisSpacing: 7,
                        childAspectRatio: .78,
                      ),
                      itemBuilder: (context, index) {
                        final fruit = _fruits[index];
                        final key = fruit['key']?.toString() ?? '';
                        final myBet = int.tryParse(
                              _myBets[key]?.toString() ?? '',
                            ) ??
                            0;
                        return InkWell(
                          key: Key('fruit-party-$key'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: _bettingOpen && !placingBet
                              ? () => _placeBet(key)
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF17120B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: myBet > 0
                                    ? TinniPalette.gold
                                    : TinniPalette.deepGold,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 9,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  fruit['emoji']?.toString() ?? '🎰',
                                  style: const TextStyle(fontSize: 30),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  fruit['label']?.toString() ?? key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: TinniPalette.cream,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'x${fruit['multiplier'] ?? 0}',
                                  style: const TextStyle(
                                    color: TinniPalette.gold,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  myBet > 0 ? _compact(myBet) : 'Tap to bet',
                                  style: TextStyle(
                                    color: myBet > 0
                                        ? TinniPalette.gold
                                        : TinniPalette.muted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Last 7',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (history.isEmpty)
                      const TinniPanel(
                        child: Text(
                          'Results will appear after the first settled round.',
                          style: TextStyle(color: TinniPalette.muted),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final row in history)
                              Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: Container(
                                  width: 62,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF17120B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: row['lucky11'] == true
                                          ? Colors.orangeAccent
                                          : TinniPalette.deepGold,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        row['lucky11'] == true
                                            ? '11'
                                            : _fruitEmoji(
                                                (row['fruit'] as Map?)?['key']
                                                        ?.toString() ??
                                                    '',
                                              ),
                                        style:
                                            const TextStyle(fontSize: 24),
                                      ),
                                      Text(
                                        '#${row['round_id'] ?? '-'}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: TinniPalette.muted,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (latest != null) ...[
                      const SizedBox(height: 14),
                      _winnerPanel(latest),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon) => TinniPanel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Icon(icon, color: TinniPalette.gold, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TinniPalette.cream,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: TinniPalette.muted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      );

  Widget _winnerPanel(Map<String, dynamic> latest) {
    final raw = latest['top_winners'];
    final winners = raw is List
        ? raw
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final bonusRaw = latest['bonus_fruits'];
    final bonus = bonusRaw is List
        ? bonusRaw
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return TinniPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            latest['lucky11'] == true ? 'Lucky 11 Result' : 'Latest Winners',
            style: const TextStyle(
              color: TinniPalette.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (bonus.isNotEmpty) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              children: [
                for (final fruit in bonus)
                  Chip(
                    label: Text(
                      '${fruit['emoji'] ?? '🎰'} x${fruit['multiplier'] ?? 0}',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          if (winners.isEmpty)
            const Text(
              'No winning bet in this round.',
              style: TextStyle(color: TinniPalette.muted),
            )
          else
            for (var index = 0; index < winners.length; index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: TinniPalette.nearBlack,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  winners[index]['display_name']?.toString() ?? 'User',
                ),
                subtitle: Text(
                  'ID ${winners[index]['user_id'] ?? '-'}',
                ),
                trailing: Text(
                  '+${_compact(int.tryParse(winners[index]['winning_coins']?.toString() ?? '') ?? 0)}',
                  style: const TextStyle(
                    color: TinniPalette.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
