// Ranking of the Month (Mr. Wrong, 2026-11-24): the ASTROPHILE monthly
// ranking from the reference videos — Charm Star / Wealth Star / Active
// star tabs, countdown (UTC+3) to the end of the month, top-3 winged
// shields (gold #1 + real crown, blue #2, orange #3), rank rows with
// avatar, name, level, role tag and value. Background: v9 light glass
// purple+gold.
import 'dart:async';

import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:material_ui/material_ui.dart';
import 'family_common.dart';

class FamilyMonthlyRankingScreen extends StatefulWidget {
  const FamilyMonthlyRankingScreen({
    super.key,
    required this.state,
    required this.familyId,
    this.backend,
  });

  final AppState state;
  final String familyId;

  /// Test seam: a fake backend. Defaults to [AppState.backend].
  final BackendApi? backend;

  @override
  State<FamilyMonthlyRankingScreen> createState() =>
      _FamilyMonthlyRankingScreenState();
}

class _FamilyMonthlyRankingScreenState
    extends State<FamilyMonthlyRankingScreen> {
  BackendApi get _backend => widget.backend ?? widget.state.backend;

  String _kind = 'charm';
  bool _loading = true;
  List<Map<String, dynamic>> _members = const [];
  String? _error;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  static const List<(String, String)> _kinds = <(String, String)>[
    ('charm', 'Charm Star'),
    ('wealth', 'Wealth Star'),
    ('active', 'Active star'),
  ];

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Countdown to the end of the month, in UTC+3 (like the other app).
  void _updateCountdown() {
    final nowUtc = DateTime.now().toUtc();
    final nowPlus3 = nowUtc.add(const Duration(hours: 3));
    final endOfMonthPlus3 = DateTime.utc(
      nowPlus3.month == 12 ? nowPlus3.year + 1 : nowPlus3.year,
      nowPlus3.month == 12 ? 1 : nowPlus3.month + 1,
    ).subtract(const Duration(hours: 3));
    final remaining = endOfMonthPlus3.difference(nowUtc);
    if (mounted) setState(() => _remaining = remaining);
  }

  String get _countdownText {
    final total = _remaining.inSeconds;
    if (total <= 0) return '00 Day 00:00:00';
    final days = total ~/ 86400;
    final hours = (total % 86400) ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(days)} Day ${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final value = await _backend.familyMonthlyRanking(
      familyId: widget.familyId,
      kind: _kind,
    );
    if (!mounted) return;
    if (value == null || value['ok'] != true) {
      setState(() {
        _loading = false;
        _error = 'Could not load the ranking';
      });
      return;
    }
    final rows = value['members'];
    setState(() {
      _members = rows is List
          ? rows.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : const <Map<String, dynamic>>[];
      _loading = false;
      _error = null;
    });
  }

  void _selectKind(String kind) {
    if (kind == _kind) return;
    setState(() => _kind = kind);
    _load();
  }

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _valueText(Map<String, dynamic> member) {
    final value = _asInt(member['value']);
    if (_kind == 'active') {
      // Minutes active in the family room this month ("22.17k").
      if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}k';
      return '$value';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _members.take(3).toList();
    final rest = _members.skip(3).toList();
    final me = _members.firstWhere(
      (row) => row['user_id']?.toString() == widget.state.userId,
      orElse: () => const <String, dynamic>{},
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: familyAppBar(
        'Ranking of the Month',
        actions: [
          IconButton(
            key: const Key('family-monthly-ranking-rules'),
            icon: const Icon(Icons.help_outline),
            tooltip: 'Family Rules',
            onPressed: () => openFamilyRules(context),
          ),
        ],
      ),
      body: FamilyBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  for (final (kind, label) in _kinds)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FilledButton(
                          key: Key('family-monthly-ranking-$kind'),
                          onPressed: () => _selectKind(kind),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kind == kind
                                ? const Color(0xFF7E57C2)
                                : const Color(0xFFE8A91C),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(label),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Countdown (UTC+3): $_countdownText',
                style: const TextStyle(
                  color: Color(0xFF2A2140),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFF2A2140)),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            children: [
                              if (top3.isNotEmpty)
                                _Podium(
                                  top3: top3,
                                  backend: _backend,
                                  valueText: _valueText,
                                ),
                              const SizedBox(height: 12),
                              for (final member in rest)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: FamilyCard(
                                    child: _RankingRow(
                                      member: member,
                                      backend: _backend,
                                      valueText: _valueText,
                                    ),
                                  ),
                                ),
                              if (me.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: FamilyCard(
                                    child: _RankingRow(
                                      member: me,
                                      backend: _backend,
                                      valueText: _valueText,
                                      highlight: true,
                                    ),
                                  ),
                                ),
                              if (_members.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 32),
                                  child: Text(
                                    'No rankings this month yet',
                                    style:
                                        TextStyle(color: Color(0xFF2A2140)),
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.top3,
    required this.backend,
    required this.valueText,
  });

  final List<Map<String, dynamic>> top3;
  final BackendApi backend;
  final String Function(Map<String, dynamic> member) valueText;

  @override
  Widget build(BuildContext context) {
    // #1 centre/largest with a real crown, #2 left, #3 right.
    Widget slot(int index, double size, String shield) {
      final member = top3[index];
      return Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/$shield',
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8C96A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              FamilyAvatar(
                backend: backend,
                avatarKey: member['avatar_key']?.toString() ?? '',
                size: size * 0.52,
              ),
              if (index == 0)
                Positioned(
                  top: -size * 0.28,
                  child: Image.asset(
                    'assets/images/gold_crown.png',
                    width: size * 0.55,
                    height: size * 0.35,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: size + 24,
            child: Text(
              member['display_name']?.toString() ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A2140),
              ),
            ),
          ),
          Text(
            valueText(member),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A7390),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (top3.length > 1) slot(1, 110, 'shield_blue.png'),
        if (top3.length > 1) const SizedBox(width: 8),
        slot(0, 150, 'shield_gold.png'),
        if (top3.length > 2) const SizedBox(width: 8),
        if (top3.length > 2) slot(2, 110, 'shield_orange.png'),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.member,
    required this.backend,
    required this.valueText,
    this.highlight = false,
  });

  final Map<String, dynamic> member;
  final BackendApi backend;
  final String Function(Map<String, dynamic> member) valueText;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final role = member['role']?.toString() ?? 'member';
    final roleLabel = switch (role) {
      'leader' => 'Family Leader',
      'admin' => 'Deputy Family Leader',
      _ => null,
    };
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '${member['rank'] ?? ''}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? const Color(0xFFE8A91C)
                  : const Color(0xFF2A2140),
            ),
          ),
        ),
        FamilyAvatar(
          backend: backend,
          avatarKey: member['avatar_key']?.toString() ?? '',
          size: 44,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member['display_name']?.toString() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A2140),
                ),
              ),
              if (roleLabel != null)
                Text(
                  roleLabel,
                  style: const TextStyle(
                    color: Color(0xFF7E57C2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        Text(
          valueText(member),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A2140),
          ),
        ),
      ],
    );
  }
}
