import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';

Future<void> showGreedyGirl(BuildContext context, AppState state) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) => SizedBox(
      key: const Key('greedy-girl-room-overlay'),
      height: MediaQuery.sizeOf(context).height * .69,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GreedyGirlScreen(state: state),
      ),
    ),
  );
}

class GreedyGirlScreen extends StatefulWidget {
  const GreedyGirlScreen({super.key, required this.state});

  final AppState state;

  @override
  State<GreedyGirlScreen> createState() => _GreedyGirlScreenState();
}

class _GreedyGirlScreenState extends State<GreedyGirlScreen> {
  static const List<Map<String, Object>> foods = <Map<String, Object>>[
    {'key': 'tomato', 'emoji': '🍅', 'label': 'Tomato', 'multiplier': 5},
    {'key': 'broccoli', 'emoji': '🥦', 'label': 'Broccoli', 'multiplier': 5},
    {'key': 'cucumber', 'emoji': '🥒', 'label': 'Cucumber', 'multiplier': 5},
    {'key': 'carrot', 'emoji': '🥕', 'label': 'Carrot', 'multiplier': 5},
    {'key': 'hotdog', 'emoji': '🌭', 'label': 'Hot dog', 'multiplier': 10},
    {'key': 'corn', 'emoji': '🌽', 'label': 'Corn', 'multiplier': 15},
    {'key': 'lettuce', 'emoji': '🥬', 'label': 'Lettuce', 'multiplier': 25},
    {'key': 'skewer', 'emoji': '🍢', 'label': 'Skewer', 'multiplier': 45},
  ];

  static const List<Offset> positions = <Offset>[
    Offset(.50, .10),
    Offset(.79, .22),
    Offset(.88, .50),
    Offset(.78, .79),
    Offset(.50, .90),
    Offset(.22, .79),
    Offset(.12, .50),
    Offset(.21, .22),
  ];

  Map<String, dynamic> game = const <String, dynamic>{};
  int selectedBet = 100;
  bool loading = true;
  bool loadingState = false;
  bool drainingBetQueue = false;
  final List<_QueuedGreedyBet> betQueue = <_QueuedGreedyBet>[];
  final Map<String, int> queuedBets = <String, int>{};
  int queuedDebit = 0;
  String? loadError;
  String panel = 'game';
  int serverTimeAtSync = 0;
  int localTimeAtSync = 0;
  Timer? refreshTimer;
  Timer? clockTimer;

  Map<String, dynamic> get round =>
      game['round'] is Map ? Map<String, dynamic>.from(game['round'] as Map) : const <String, dynamic>{};

  Map<String, dynamic> get myBets {
    final base = game['my_bets'] is Map
        ? Map<String, dynamic>.from(game['my_bets'] as Map)
        : <String, dynamic>{};
    for (final entry in queuedBets.entries) {
      final current = int.tryParse(base[entry.key]?.toString() ?? '') ?? 0;
      base[entry.key] = current + entry.value;
    }
    return base;
  }

  List<Map<String, dynamic>> get history {
    final raw = game['history'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  List<int> get betAmounts {
    final raw = game['config'] is Map
        ? Map<String, dynamic>.from(game['config'] as Map)['bet_amounts']
        : null;
    if (raw is! List) {
      return const <int>[100, 1000, 10000, 50000, 100000, 200000, 500000, 1000000, 5000000];
    }
    return raw
        .map((value) => int.tryParse(value.toString()) ?? 0)
        .where((value) => value > 0)
        .toList(growable: false);
  }

  bool get bettingOpen => round['betting_open'] == true;

  int get serverNow {
    if (serverTimeAtSync <= 0 || localTimeAtSync <= 0) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    return serverTimeAtSync +
        (DateTime.now().millisecondsSinceEpoch - localTimeAtSync);
  }

  int get remainingMs {
    final target = round['phase'] == 'result_spin'
        ? int.tryParse(round['cycle_end']?.toString() ?? '') ?? serverNow
        : int.tryParse(round['round_end']?.toString() ?? '') ?? serverNow;
    return math.max(0, target - serverNow);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_load(silent: true)),
    );
    clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && game.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (loadingState || drainingBetQueue || betQueue.isNotEmpty) return;
    if (!widget.state.backendConnected) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'Server connection unavailable. Tap Retry.';
        });
      }
      return;
    }

    loadingState = true;
    Map<String, dynamic>? value;
    Object? failure;
    try {
      value = await widget.state.backend.greedyGirlState();
    } catch (error) {
      failure = error;
    } finally {
      loadingState = false;
    }

    if (!mounted) return;
    if (value == null || value['ok'] != true) {
      final raw = value?['error']?.toString().trim();
      final message = raw == null || raw.isEmpty
          ? (failure == null
              ? 'Greedy Girl server did not respond. Tap Retry.'
              : 'Greedy Girl connection failed. Tap Retry.')
          : switch (raw) {
              'games_disabled' => 'Games are disabled by the owner.',
              'unauthorized' || 'forbidden' =>
                'Login session expired. Sign in again.',
              _ => raw.replaceAll('_', ' '),
            };
      if (!silent || game.isEmpty) {
        setState(() {
          loading = false;
          loadError = message;
        });
      }
      return;
    }
    _applyState(value);
  }

  void _applyState(Map<String, dynamic> value) {
    final time = int.tryParse(value['server_time']?.toString() ?? '') ?? 0;
    final wallet = int.tryParse(value['wallet_balance']?.toString() ?? '');
    if (wallet != null) {
      widget.state.setCoinBalance(math.max(0, wallet - queuedDebit).toInt());
    }
    final allowed = value['config'] is Map
        ? Map<String, dynamic>.from(value['config'] as Map)['bet_amounts']
        : null;
    final parsed = allowed is List
        ? allowed
            .map((entry) => int.tryParse(entry.toString()) ?? 0)
            .where((entry) => entry > 0)
            .toList(growable: false)
        : const <int>[];
    setState(() {
      game = Map<String, dynamic>.from(value);
      loading = false;
      loadError = null;
      if (time > 0) {
        serverTimeAtSync = time;
        localTimeAtSync = DateTime.now().millisecondsSinceEpoch;
      }
      if (parsed.isNotEmpty && !parsed.contains(selectedBet)) {
        selectedBet = parsed.first;
      }
    });
  }

  Future<void> _placeBet(String foodKey) async {
    if (!bettingOpen) return;

    final authoritativeWallet =
        int.tryParse(game['wallet_balance']?.toString() ?? '') ??
            widget.state.coins;
    final availableWallet = math.max(0, authoritativeWallet - queuedDebit).toInt();
    final amount = selectedBet;
    if (availableWallet < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins for this bet.')),
      );
      return;
    }

    final bet = _QueuedGreedyBet(
      foodKey: foodKey,
      amount: amount,
      requestId:
          'gg-${widget.state.userId}-${DateTime.now().microsecondsSinceEpoch}',
    );

    setState(() {
      betQueue.add(bet);
      queuedBets[foodKey] = (queuedBets[foodKey] ?? 0) + amount;
      queuedDebit += amount;
    });
    widget.state.setCoinBalance(
      math.max(0, authoritativeWallet - queuedDebit).toInt(),
    );
    unawaited(_drainBetQueue());
  }

  void _removeQueuedBet(_QueuedGreedyBet bet) {
    if (betQueue.isNotEmpty && identical(betQueue.first, bet)) {
      betQueue.removeAt(0);
    } else {
      betQueue.remove(bet);
    }
    final next = (queuedBets[bet.foodKey] ?? 0) - bet.amount;
    if (next <= 0) {
      queuedBets.remove(bet.foodKey);
    } else {
      queuedBets[bet.foodKey] = next;
    }
    queuedDebit = math.max(0, queuedDebit - bet.amount).toInt();
  }

  void _applyBetAck(
    Map<String, dynamic> result,
    _QueuedGreedyBet bet,
  ) {
    final next = Map<String, dynamic>.from(game);
    final baseBets = next['my_bets'] is Map
        ? Map<String, dynamic>.from(next['my_bets'] as Map)
        : <String, dynamic>{};
    final current =
        int.tryParse(baseBets[bet.foodKey]?.toString() ?? '') ?? 0;
    baseBets[bet.foodKey] = current + bet.amount;
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
        loadError = null;
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
          result = await widget.state.backend.greedyGirlBet(
            userId: widget.state.userId,
            foodKey: bet.foodKey,
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
            _applyState(result!);
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
    if (value >= 1000000) {
      final n = value / 1000000;
      return n == n.roundToDouble()
          ? '${n.toInt()}M'
          : '${n.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final n = value / 1000;
      return n == n.roundToDouble()
          ? '${n.toInt()}K'
          : '${n.toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Map<String, dynamic>? get currentResult {
    if (round['phase'] != 'result_spin' || history.isEmpty) return null;
    final first = history.first;
    if (first['round_id']?.toString() != round['round_id']?.toString()) {
      return null;
    }
    return first;
  }

  int get currentPersonalWin {
    final result = currentResult;
    final food = result?['food'];
    if (food is! Map) return 0;
    final key = food['key']?.toString() ?? '';
    final amount = int.tryParse(myBets[key]?.toString() ?? '') ?? 0;
    final multiplier = int.tryParse(food['multiplier']?.toString() ?? '') ?? 0;
    return amount * multiplier;
  }

  @override
  Widget build(BuildContext context) {
    final authoritativeWallet =
        int.tryParse(game['wallet_balance']?.toString() ?? '') ??
            widget.state.coins;
    final wallet = math.max(0, authoritativeWallet - queuedDebit).toInt();
    final winnings =
        int.tryParse(game['today_winnings']?.toString() ?? '') ?? 0;
    final seconds = (remainingMs / 1000).ceil();

    return Material(
      color: const Color(0xFF160B2B),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : loadError != null && game.isEmpty
                      ? _errorPanel()
                      : panel == 'game'
                          ? _gamePanel(wallet, winnings, seconds)
                          : _detailPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPanel() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFFFD878),
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                loadError ?? 'Greedy Girl is unavailable.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: loadingState
                    ? null
                    : () {
                        setState(() => loading = true);
                        unawaited(_load());
                      },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _header() => Container(
        height: 42,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF1B0B32), Color(0xFF3A146B)],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: panel == 'game' ? 'Game records' : 'Back to game',
              onPressed: () =>
                  setState(() => panel = panel == 'game' ? 'records' : 'game'),
              icon: Icon(
                panel == 'game' ? Icons.history_rounded : Icons.arrow_back_rounded,
                color: const Color(0xFFFFD878),
                size: 20,
              ),
            ),
            Expanded(
              child: Text(
                panel == 'rules'
                    ? 'How to play'
                    : panel == 'records'
                        ? 'Game records'
                        : 'Greedy Girl',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFE09A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Rules',
              onPressed: () => setState(() => panel = 'rules'),
              icon: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFFFFD878),
                size: 20,
              ),
            ),
            IconButton(
              tooltip: 'Close Greedy Girl',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFFFFD878),
                size: 20,
              ),
            ),
          ],
        ),
      );

  Widget _gamePanel(int wallet, int winnings, int seconds) => Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final timerSize =
                    (bounds.maxWidth * .145).clamp(48.0, 62.0).toDouble();
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.05,
                            colors: <Color>[
                              Color(0xFF6B32BD),
                              Color(0xFF2C125D),
                              Color(0xFF130A25),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/greedy_girl_mascot.webp',
                        key: const Key('greedy-girl-mascot'),
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x220C031A),
                                Colors.transparent,
                                Colors.transparent,
                                Color(0x330C031A),
                              ],
                              stops: <double>[0, .18, .76, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _SparklePainter()),
                      ),
                    ),
                    for (var i = 0; i < foods.length; i++)
                      _positionedFood(
                        bounds.maxWidth,
                        bounds.maxHeight,
                        positions[i],
                        foods[i],
                      ),
                    Positioned(
                      key: const Key('greedy-girl-countdown'),
                      left: (bounds.maxWidth - timerSize) / 2,
                      top: bounds.maxHeight * .56 - timerSize / 2,
                      width: timerSize,
                      height: timerSize,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: <Color>[
                                Color(0xFF4C177C),
                                Color(0xFF210833),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFC84A),
                              width: 2.4,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0xAA8B43FF),
                                blurRadius: 13,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Color(0x88FFCF4A),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$seconds',
                              key: const Key('greedy-girl-countdown-number'),
                              style: TextStyle(
                                color: const Color(0xFFFFE7A2),
                                fontSize: timerSize * .44,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (currentResult != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _resultOverlay(currentResult!),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF3A146B), Color(0xFF1B0B32)],
              ),
            ),
            child: Column(
              children: [
                Text(
                  bettingOpen
                      ? 'Choose amount  →  Choose food'
                      : 'Result time • next round in ${(remainingMs / 1000).ceil()}s',
                  style: const TextStyle(
                    color: Color(0xFFFFE4A8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final amount in betAmounts)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: selectedBet == amount,
                            showCheckmark: false,
                            selectedColor: const Color(0xFFFFB33E),
                            backgroundColor: const Color(0xFF5B2C85),
                            side: const BorderSide(color: Color(0xFFAA7EE5)),
                            label: Text(_compact(amount)),
                            labelStyle: TextStyle(
                              color: selectedBet == amount
                                  ? const Color(0xFF32120A)
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                            onSelected: (_) =>
                                setState(() => selectedBet = amount),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Remaining coins  ${_compact(wallet)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'I won today  ${_compact(winnings)}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: Color(0xFFFFD66D),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 22,
                  child: Row(
                    children: [
                      const Text(
                        'Result  ',
                        style: TextStyle(
                          color: Color(0xFFB8A1D8),
                          fontSize: 10,
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final row in history.take(7))
                              Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: Text(
                                  (row['food'] as Map?)?['emoji']?.toString() ?? '•',
                                  style: const TextStyle(fontSize: 17),
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
        ],
      );

  Widget _positionedFood(
    double width,
    double height,
    Offset p,
    Map<String, Object> food,
  ) {
    final bubble =
        (width * .165).clamp(52.0, 66.0).toDouble();
    return Positioned(
      left: p.dx * width - bubble / 2,
      top: p.dy * height - bubble / 2,
      width: bubble,
      height: bubble,
      child: _foodBubble(food),
    );
  }

  Widget _foodBubble(Map<String, Object> food) {
    final key = food['key']!.toString();
    final myAmount = int.tryParse(myBets[key]?.toString() ?? '') ?? 0;
    final resultKey =
        (currentResult?['food'] as Map?)?['key']?.toString() ?? '';
    final active = resultKey == key;
    return InkWell(
      key: Key('greedy-girl-$key'),
      customBorder: const CircleBorder(),
      onTap: bettingOpen ? () => unawaited(_placeBet(key)) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: <Color>[
              Color(0xFFEAF4FF),
              Color(0xFF8ED7FF),
              Color(0xFF4C72D5),
            ],
          ),
          border: Border.all(
            color: active
                ? const Color(0xFFFFD43D)
                : myAmount > 0
                    ? Colors.white
                    : const Color(0xFFB9D7FF),
            width: active ? 4 : 2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: active
                  ? const Color(0xFFFFC400)
                  : const Color(0xFF835BFF),
              blurRadius: active ? 18 : 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (myAmount > 0)
              Text(
                _compact(myAmount),
                style: const TextStyle(
                  color: Color(0xFF2D134B),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            Text(
              food['emoji']!.toString(),
              style: const TextStyle(fontSize: 25),
            ),
            Text(
              '×${food['multiplier']}',
              style: const TextStyle(
                color: Color(0xFF25215A),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultOverlay(Map<String, dynamic> result) {
    final food = result['food'] is Map
        ? Map<String, dynamic>.from(result['food'] as Map)
        : const <String, dynamic>{};
    final win = currentPersonalWin;
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFF160B2B).withValues(alpha: .25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFC342), Color(0xFFFF6B7D)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black54, blurRadius: 14),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              win > 0 ? '⭐ YOU WIN ⭐' : 'RESULT',
              style: const TextStyle(
                color: Color(0xFF43131D),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            Text(
              '${food['emoji'] ?? '🍽️'}  ×${food['multiplier'] ?? '-'}${win > 0 ? '  +${_compact(win)}' : ''}',
              style: const TextStyle(
                color: Color(0xFF301022),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPanel() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF32145E), Color(0xFF140921)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: panel == 'rules'
              ? <Widget>[
                  const Text(
                    '1. Select a coin amount, then tap one food bubble to join the current round.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '2. Each round has 30 seconds for betting, followed by a short result animation.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '3. The winning food pays the multiplier printed on its bubble. Server settlement decides every result and updates the wallet.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final food in foods)
                        Chip(
                          avatar: Text(food['emoji']!.toString()),
                          label: Text(
                            '${food['label']} ×${food['multiplier']}',
                          ),
                        ),
                    ],
                  ),
                ]
              : <Widget>[
                  if (history.isEmpty)
                    const Text(
                      'No settled rounds yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  for (final row in history)
                    Card(
                      color: const Color(0xFF27103F),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Builder(
                          builder: (_) {
                            final food = row['food'] is Map
                                ? Map<String, dynamic>.from(row['food'] as Map)
                                : const <String, dynamic>{};
                            final winners = row['top_winners'];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Round #${row['round_id']}   ${food['emoji'] ?? '🍽️'} ${food['label'] ?? ''} ×${food['multiplier'] ?? '-'}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD66D),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                if (winners is List && winners.isNotEmpty)
                                  for (final winner in winners.whereType<Map>())
                                    Text(
                                      '${winner['display_name'] ?? 'User'}   +${_compact(int.tryParse(winner['winning_coins']?.toString() ?? '') ?? 0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    )
                                else
                                  const Text(
                                    'No winning bet in this round.',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                ],
        ),
      );
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .22);
    const points = <Offset>[
      Offset(.08, .12),
      Offset(.31, .05),
      Offset(.68, .08),
      Offset(.92, .18),
      Offset(.06, .74),
      Offset(.28, .94),
      Offset(.73, .91),
      Offset(.94, .66),
      Offset(.47, .02),
      Offset(.56, .96),
    ];
    for (var i = 0; i < points.length; i++) {
      final p = Offset(points[i].dx * size.width, points[i].dy * size.height);
      canvas.drawCircle(p, i.isEven ? 2.2 : 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _QueuedGreedyBet {
  const _QueuedGreedyBet({
    required this.foodKey,
    required this.amount,
    required this.requestId,
  });

  final String foodKey;
  final int amount;
  final String requestId;
}
