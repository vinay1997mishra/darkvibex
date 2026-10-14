import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

Future<void> showGreedyGirl(BuildContext context, AppState state) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .56,
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
  bool placingBet = false;
  String panel = 'game';
  int serverTimeAtSync = 0;
  int localTimeAtSync = 0;
  Timer? refreshTimer;
  Timer? clockTimer;

  Map<String, dynamic> get round =>
      game['round'] is Map ? Map<String, dynamic>.from(game['round'] as Map) : const <String, dynamic>{};

  Map<String, dynamic> get myBets =>
      game['my_bets'] is Map ? Map<String, dynamic>.from(game['my_bets'] as Map) : const <String, dynamic>{};

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
      const Duration(seconds: 5),
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
    if (loadingState || placingBet) return;
    if (!widget.state.backendConnected) {
      if (!silent && mounted) setState(() => loading = false);
      return;
    }
    loadingState = true;
    Map<String, dynamic>? value;
    try {
      value = await widget.state.backend.greedyGirlState();
    } finally {
      loadingState = false;
    }
    if (!mounted) return;
    if (value == null || value['ok'] != true) {
      if (!silent) setState(() => loading = false);
      return;
    }
    _applyState(value);
  }

  void _applyState(Map<String, dynamic> value) {
    final time = int.tryParse(value['server_time']?.toString() ?? '') ?? 0;
    final wallet = int.tryParse(value['wallet_balance']?.toString() ?? '');
    if (wallet != null) widget.state.setCoinBalance(wallet);
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
    if (!bettingOpen || placingBet) return;
    placingBet = true;
    try {
      final requestId =
          'gg-${widget.state.userId}-${DateTime.now().microsecondsSinceEpoch}';
      final result = await widget.state.backend.greedyGirlBet(
        userId: widget.state.userId,
        foodKey: foodKey,
        amount: selectedBet,
        requestId: requestId,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        _applyState(result!);
        return;
      }
      final error =
          result?['error']?.toString().replaceAll('_', ' ') ?? 'Bet failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } finally {
      if (mounted) {
        setState(() => placingBet = false);
      } else {
        placingBet = false;
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
    final wallet =
        int.tryParse(game['wallet_balance']?.toString() ?? '') ?? widget.state.coins;
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
                  : panel == 'game'
                      ? _gamePanel(wallet, winnings, seconds)
                      : _detailPanel(),
            ),
          ],
        ),
      ),
    );
  }

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
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: .9,
                        colors: <Color>[
                          Color(0xFF522C9D),
                          Color(0xFF25104D),
                          Color(0xFF130A25),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _SparklePainter()),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, bounds) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < foods.length; i++)
                          _positionedFood(
                            bounds.maxWidth,
                            bounds.maxHeight,
                            positions[i],
                            foods[i],
                          ),
                        Positioned(
                          left: bounds.maxWidth / 2 - 57,
                          top: bounds.maxHeight / 2 - 68,
                          child: _adultAnimeCharacter(seconds),
                        ),
                        if (currentResult != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _resultOverlay(currentResult!),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
                            onSelected: placingBet
                                ? null
                                : (_) => setState(() => selectedBet = amount),
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
    const bubble = 64.0;
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
      onTap: bettingOpen && !placingBet ? () => _placeBet(key) : null,
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

  Widget _adultAnimeCharacter(int seconds) => SizedBox(
        width: 114,
        height: 136,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _AdultAnimeGirlPainter(),
              ),
            ),
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF180A2C).withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD56A)),
                ),
                child: const Text(
                  '21+',
                  style: TextStyle(
                    color: Color(0xFFFFE8AE),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: Container(
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFFB938), Color(0xFFEA5A7B)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white70),
                ),
                child: Text(
                  '${round['phase'] == 'result_spin' ? 'Result' : 'Bet'}  ${seconds}s',
                  style: const TextStyle(
                    color: Color(0xFF2A0D21),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

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

class _AdultAnimeGirlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 42);
    final hair = Paint()..color = const Color(0xFF32102F);
    final hairGlow = Paint()..color = const Color(0xFF7A2C78);
    final skin = Paint()..color = const Color(0xFFF4C3A6);
    final outline = Paint()
      ..color = const Color(0xFF4A213A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final outfit = Paint()..color = const Color(0xFF8B274E);
    final outfitDark = Paint()..color = const Color(0xFF4B1632);
    final eye = Paint()..color = const Color(0xFF24162C);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, 52), width: 79, height: 103),
      hairGlow,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, 48), width: 70, height: 96),
      hair,
    );

    canvas.drawOval(
      Rect.fromCenter(center: center, width: 42, height: 50),
      skin,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 42, height: 50),
      outline,
    );

    final leftEye = Offset(center.dx - 9, center.dy - 2);
    final rightEye = Offset(center.dx + 9, center.dy - 2);
    canvas.drawOval(
      Rect.fromCenter(center: leftEye, width: 6, height: 9),
      eye,
    );
    canvas.drawOval(
      Rect.fromCenter(center: rightEye, width: 6, height: 9),
      eye,
    );
    final shine = Paint()..color = Colors.white;
    canvas.drawCircle(leftEye.translate(1, -2), 1.2, shine);
    canvas.drawCircle(rightEye.translate(1, -2), 1.2, shine);

    final mouth = Paint()
      ..color = const Color(0xFFB84962)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 10),
        width: 11,
        height: 7,
      ),
      .15,
      math.pi - .3,
      false,
      mouth,
    );

    final body = Path()
      ..moveTo(center.dx - 16, 66)
      ..quadraticBezierTo(center.dx - 32, 76, center.dx - 28, 99)
      ..lineTo(center.dx - 24, 122)
      ..lineTo(center.dx + 24, 122)
      ..lineTo(center.dx + 28, 99)
      ..quadraticBezierTo(center.dx + 32, 76, center.dx + 16, 66)
      ..close();
    canvas.drawPath(body, skin);
    canvas.drawPath(body, outline);

    final top = Path()
      ..moveTo(center.dx - 24, 81)
      ..quadraticBezierTo(center.dx - 10, 70, center.dx, 81)
      ..quadraticBezierTo(center.dx + 10, 70, center.dx + 24, 81)
      ..lineTo(center.dx + 19, 101)
      ..quadraticBezierTo(center.dx, 95, center.dx - 19, 101)
      ..close();
    canvas.drawPath(top, outfit);
    canvas.drawPath(top, outline);

    final shorts = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, 113),
        width: 49,
        height: 25,
      ),
      const Radius.circular(7),
    );
    canvas.drawRRect(shorts, outfitDark);
    canvas.drawRRect(shorts, outline);

    final hairFront = Paint()
      ..color = const Color(0xFF3A1337)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - 17, 21),
      Offset(center.dx - 23, 71),
      hairFront,
    );
    canvas.drawLine(
      Offset(center.dx + 17, 21),
      Offset(center.dx + 25, 72),
      hairFront,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
