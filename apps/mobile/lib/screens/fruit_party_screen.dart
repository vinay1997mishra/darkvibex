import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';

class FruitPartyScreen extends StatefulWidget {
  const FruitPartyScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FruitPartyScreen> createState() => _FruitPartyScreenState();
}

class _FruitPartyScreenState extends State<FruitPartyScreen> {
  static const stakes = <int>[5000, 25000, 100000, 500000, 2000000, 10000000];
  static const fallbackFruits = <Map<String, dynamic>>[
    {'key':'lemon','emoji':'🍋','label':'Lemon','multiplier':5},
    {'key':'raspberry','emoji':'🫐','label':'Raspberry','multiplier':5},
    {'key':'kiwi','emoji':'🥝','label':'Kiwi','multiplier':5},
    {'key':'plum','emoji':'🍑','label':'Plum','multiplier':5},
    {'key':'banana','emoji':'🍌','label':'Banana','multiplier':10},
    {'key':'strawberry','emoji':'🍓','label':'Strawberry','multiplier':15},
    {'key':'watermelon','emoji':'🍉','label':'Watermelon','multiplier':25},
    {'key':'cherry','emoji':'🍒','label':'Cherry','multiplier':45},
  ];

  Map<String, dynamic>? snapshot;
  Timer? timer;
  int selectedStake = 5000;
  int remainingMs = 0;
  int tick = 0;
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    _sync();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => remainingMs = remainingMs > 1000 ? remainingMs - 1000 : 0);
      tick += 1;
      if (tick % 5 == 0) _sync();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _sync() async {
    if (syncing || !widget.state.backendConnected) return;
    syncing = true;
    final value = await widget.state.backend.fruitPartyState(userId: widget.state.userId);
    syncing = false;
    if (!mounted || value == null) return;
    final balance = int.tryParse(value['wallet_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    final round = value['round'];
    setState(() {
      snapshot = value;
      remainingMs = round is Map ? int.tryParse(round['remaining_ms']?.toString() ?? '') ?? 0 : 0;
    });
  }

  Future<void> _bet(String fruit) async {
    final result = await widget.state.backend.fruitPartyBet(
      userId: widget.state.userId,
      fruit: fruit,
      stake: selectedStake,
    );
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bet unavailable. Betting may be closed.')));
      await _sync();
      return;
    }
    final balance = int.tryParse(result['coin_balance']?.toString() ?? '');
    if (balance != null) widget.state.setCoinBalance(balance);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bet placed • ${_amount(selectedStake)} coins')));
    await _sync();
  }

  String _amount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final round = snapshot?['round'];
    final phase = round is Map ? round['phase']?.toString() ?? 'loading' : 'loading';
    final rawFruits = snapshot?['fruits'];
    final fruits = rawFruits is List
        ? rawFruits.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : fallbackFruits;
    final myBets = snapshot?['my_bets'] is Map ? Map<String, dynamic>.from(snapshot!['my_bets'] as Map) : <String, dynamic>{};
    final history = snapshot?['history'] is List ? snapshot!['history'] as List : const [];
    final top = snapshot?['top_winners'] is List ? snapshot!['top_winners'] as List : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Fruit Party')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [Color(0xFF20102F), Color(0xFF2D1C08)]),
              border: Border.all(color: const Color(0x66FFD36A)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(phase == 'betting' ? 'BETTING OPEN' : 'RESULT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                Text('${(remainingMs / 1000).ceil()}s', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFFD36A))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final stake in stakes)
                ChoiceChip(
                  selected: stake == selectedStake,
                  label: Text(_amount(stake)),
                  onSelected: (_) => setState(() => selectedStake = stake),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fruits.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: .82, crossAxisSpacing: 7, mainAxisSpacing: 7),
            itemBuilder: (context, index) {
              final fruit = fruits[index];
              final key = fruit['key']?.toString() ?? '';
              final mine = int.tryParse(myBets[key]?.toString() ?? '') ?? 0;
              return InkWell(
                onTap: phase == 'betting' ? () => _bet(key) : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: .05),
                    border: Border.all(color: mine > 0 ? const Color(0xFFFFD36A) : Colors.white12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(fruit['emoji']?.toString() ?? '🎮', style: const TextStyle(fontSize: 34)),
                      Text('${fruit['multiplier']}×', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD36A))),
                      if (mine > 0) Text(_amount(mine), style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text('Last 7 results', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final row = history[index] is Map ? Map<String, dynamic>.from(history[index] as Map) : <String,dynamic>{};
                final fruit = row['fruit'] is Map ? Map<String,dynamic>.from(row['fruit'] as Map) : <String,dynamic>{};
                final lucky = row['lucky11'] == true;
                return Container(
                  width: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: lucky ? const Color(0xFFFFD36A) : Colors.white12)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(fruit['emoji']?.toString() ?? '🎮', style: const TextStyle(fontSize: 26)),
                    Text(lucky ? 'LUCKY 11' : '${fruit['multiplier'] ?? ''}×', style: TextStyle(fontSize: lucky ? 8 : 10, fontWeight: FontWeight.w800)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          const Text('Top winners', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (top.isEmpty) const Text('No settled winners yet.')
          else for (var i = 0; i < top.length && i < 3; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text((top[i] as Map)['display_name']?.toString() ?? (top[i] as Map)['user_id']?.toString() ?? 'Player'),
              trailing: Text('+${_amount(int.tryParse((top[i] as Map)['payout']?.toString() ?? '') ?? 0)}', style: const TextStyle(color: Color(0xFFFFD36A), fontWeight: FontWeight.w900)),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Fruit Party uses 21-second betting rounds and a 5-second result phase. Jackpot is not included.', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
