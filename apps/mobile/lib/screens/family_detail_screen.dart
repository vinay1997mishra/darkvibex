// Family detail page (Mr. Wrong, 2026-11-24): the ASTROPHILE detail
// from the reference videos, on the v9 light glass purple+gold
// background. Tabs: HOME / TASK / TRENDS — NO FAMILY EVENT tab, the
// Daily Lucky Wheel spin event is on HOLD (his words: "event ka chod
// diyo abhi"), so the wheel section is display-only (today's winnings +
// check-ins + the Lucky Draw Records list, which is empty until the
// event runs).
import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:flutter/material.dart';
import 'family_common.dart';
import 'family_members_screen.dart';
import 'family_monthly_ranking_screen.dart';
import 'room_screen.dart';

class FamilyDetailScreen extends StatefulWidget {
  const FamilyDetailScreen({
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
  State<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends State<FamilyDetailScreen>
    with SingleTickerProviderStateMixin {
  BackendApi get _backend => widget.backend ?? widget.state.backend;

  late final TabController _tabs = TabController(length: 3, vsync: this);

  bool _loading = true;
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _tasks;
  List<Map<String, dynamic>> _posts = const [];
  List<Map<String, dynamic>> _records = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final detail = await _backend.familyDetail(familyId: widget.familyId);
    if (!mounted) return;
    if (detail == null || detail['ok'] != true) {
      setState(() {
        _loading = false;
        _error = 'Could not load this family';
      });
      return;
    }
    final tasks = await _backend.familyTasks();
    final posts = await _backend.familyTrends(familyId: widget.familyId);
    final records =
        await _backend.familyLuckyDrawRecords(familyId: widget.familyId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _tasks = tasks;
      _posts = posts;
      _records = records;
      _loading = false;
    });
  }

  Map<String, dynamic> get _family {
    final family = _detail?['family'];
    return family is Map ? Map<String, dynamic>.from(family) : const {};
  }

  bool get _isMember => _family['is_member'] == true;

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _formatNumber(num value) {
    final v = value.toDouble();
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(2)}B';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)}K';
    return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 2);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _join() async {
    final ok = await _backend.requestFamilyJoin(
      userId: widget.state.userId,
      familyId: widget.familyId,
    );
    if (!mounted) return;
    if (ok) {
      _showMessage('Join request sent');
      await _load();
    } else {
      _showMessage('Could not send the join request');
    }
  }

  Future<void> _checkIn() async {
    final value = await _backend.familyCheckIn(userId: widget.state.userId);
    if (!mounted) return;
    if (value?['ok'] == true) {
      _showMessage('Signed in! +405,000 EXP + 8,100 coins');
      await _load();
    } else {
      _showMessage('Could not sign in');
    }
  }

  void _openMonthlyRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyMonthlyRankingScreen(
          state: widget.state,
          familyId: widget.familyId,
          backend: widget.backend,
        ),
      ),
    );
  }

  void _openRoom(Map<String, dynamic> room) {
    final roomId = room['id']?.toString() ?? '';
    if (roomId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomScreen(
          state: widget.state,
          room: RoomSummary(
            id: roomId,
            name: room['name']?.toString() ?? 'Family room',
            ownerName: _family['leader_name']?.toString() ?? '',
            ownerUserId: room['owner_user_id']?.toString() ?? '',
            online: _asInt(room['live_count']),
            seatCount: _asInt(room['seat_count']) == 0
                ? 12
                : _asInt(room['seat_count']),
          ),
        ),
      ),
    );
  }

  // Member list tap (Mr. Wrong, 2026-11-24): tapping the "N members"
  // section opens the full members page, like in the reference video.
  void _openMembers(List<Map<String, dynamic>> members) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyMembersScreen(
          state: widget.state,
          familyId: widget.familyId,
          familyName: _family['name']?.toString() ?? 'Family',
          members: members,
          backend: widget.backend,
        ),
      ),
    );
  }

  void _openRecords() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Today's Family Lucky Draw Records"),
        content: _records.isEmpty
            ? const Text(
                'No lucky draw records today yet.\nThe Daily Lucky Wheel '
                'event has not started.',
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    return ListTile(
                      title: Text(record['display_name']?.toString() ?? ''),
                      trailing: Text(
                        '+${_formatNumber(_asInt(record['coins']))}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyName = _family['name']?.toString() ?? 'Family';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: familyAppBar(
        familyName,
        actions: [
          IconButton(
            key: const Key('family-detail-rules'),
            icon: const Icon(Icons.help_outline),
            tooltip: 'Family Rules',
            onPressed: () => openFamilyRules(context),
          ),
        ],
      ),
      body: FamilyBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF2A2140)),
                    ),
                  )
                : Column(
                    children: [
                      TabBar(
                        controller: _tabs,
                        labelColor: const Color(0xFF2A2140),
                        unselectedLabelColor: const Color(0xFF7A7390),
                        indicatorColor: const Color(0xFFE8A91C),
                        tabs: const [
                          Tab(text: 'HOME'),
                          Tab(text: 'TASK'),
                          Tab(text: 'TRENDS'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _HomeTab(
                              detail: _detail!,
                              backend: _backend,
                              isMember: _isMember,
                              records: _records,
                              onJoin: _join,
                              onOpenMonthlyRanking: _openMonthlyRanking,
                              onOpenRoom: _openRoom,
                              onOpenRecords: _openRecords,
                              onOpenMembers: _openMembers,
                              formatNumber: _formatNumber,
                            ),
                            _TaskTab(
                              detail: _detail!,
                              tasks: _tasks,
                              onCheckIn: _checkIn,
                              formatNumber: _formatNumber,
                            ),
                            _TrendsTab(
                              backend: _backend,
                              state: widget.state,
                              posts: _posts,
                              isMember: _isMember,
                              onReload: _load,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME tab
// ---------------------------------------------------------------------------

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.detail,
    required this.backend,
    required this.isMember,
    required this.records,
    required this.onJoin,
    required this.onOpenMonthlyRanking,
    required this.onOpenRoom,
    required this.onOpenRecords,
    required this.onOpenMembers,
    required this.formatNumber,
  });

  final Map<String, dynamic> detail;
  final BackendApi backend;
  final bool isMember;
  final List<Map<String, dynamic>> records;
  final VoidCallback onJoin;
  final VoidCallback onOpenMonthlyRanking;
  final void Function(Map<String, dynamic> room) onOpenRoom;
  final VoidCallback onOpenRecords;
  final void Function(List<Map<String, dynamic>> members) onOpenMembers;
  final String Function(num value) formatNumber;

  Map<String, dynamic> get _family {
    final family = detail['family'];
    return family is Map ? Map<String, dynamic>.from(family) : const {};
  }

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final family = _family;
    final experience = _asInt(family['experience']);
    final level = _asInt(family['level']);
    final nextExp = family['next_exp'];
    final nextExpValue = nextExp is num ? nextExp.toDouble() : null;
    final expProgress = nextExpValue == null || nextExpValue <= 0
        ? 1.0
        : (experience / nextExpValue).clamp(0.0, 1.0);
    final rankProgress = _asInt(family['rank_progress']);
    final rankNeed = _asInt(family['rank_need']);
    final rankProgressValue = rankNeed <= 0
        ? 1.0
        : (rankProgress / rankNeed).clamp(0.0, 1.0);
    final topMembers = detail['top_members'];
    final top = topMembers is Map
        ? Map<String, dynamic>.from(topMembers)
        : const <String, dynamic>{};
    final members = detail['members'];
    final memberList = members is List
        ? members.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];
    final room = detail['room'];
    final roomMap = room is Map ? Map<String, dynamic>.from(room) : null;
    final totalWinnings = records.fold<int>(
      0,
      (sum, record) => sum + _asInt(record['coins']),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: logo, name, tag, ID, declaration.
          FamilyCard(
            child: Row(
              children: [
                FamilyAvatar(
                  backend: backend,
                  avatarKey: family['logo_key']?.toString() ?? '',
                  size: 72,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family['name']?.toString() ?? 'Family',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A2140),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E57C2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              family['tag']?.toString() ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ID:${family['id']?.toString() ?? ''}',
                            style: const TextStyle(color: Color(0xFF7A7390)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        family['notice']?.toString() ?? '',
                        style: const TextStyle(color: Color(0xFF4A4458)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const FamilySectionTitle('Family EXP'),
          FamilyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lv.$level',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A2140),
                      ),
                    ),
                    Text(
                      nextExpValue == null
                          ? formatNumber(experience)
                          : '${formatNumber(experience)} / ${formatNumber(nextExpValue)}',
                      style: const TextStyle(color: Color(0xFF7A7390)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FamilyProgressBar(progress: expProgress),
                const SizedBox(height: 8),
                Text(
                  'Experience I contributed: ${formatNumber(_asInt(family['my_contributed_exp']))}',
                  style: const TextStyle(color: Color(0xFF4A4458)),
                ),
              ],
            ),
          ),
          const FamilySectionTitle('Family Rank'),
          FamilyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Current rank: ${family['rank']?.toString() ?? 'Iron III'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A2140),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('family-detail-monthly-ranking'),
                      onPressed: onOpenMonthlyRanking,
                      child: const Text('Ranking of the Month >'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FamilyProgressBar(progress: rankProgressValue),
                const SizedBox(height: 6),
                Text(
                  rankNeed <= 0
                      ? 'Top rank reached'
                      : 'To level-up, you need: ${formatNumber(rankProgress)}/${formatNumber(rankNeed)}',
                  style: const TextStyle(color: Color(0xFF7A7390)),
                ),
              ],
            ),
          ),
          const FamilySectionTitle('Daily Lucky Wheel'),
          FamilyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Family Winnings Today: ${formatNumber(totalWinnings)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A2140),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Family Daily Check-ins: ${_asInt(family['check_ins_today'])}/${memberList.length}',
                  style: const TextStyle(color: Color(0xFF4A4458)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('family-detail-lucky-records'),
                  onPressed: onOpenRecords,
                  child: const Text("Today's Family Lucky Draw Records >"),
                ),
              ],
            ),
          ),
          const FamilySectionTitle('Top members of the family'),
          Row(
            children: [
              for (final entry in <(String, String)>[
                ('Charm Star', 'charm'),
                ('Wealth Star', 'wealth'),
                ('Active Star', 'active'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _TopMemberCard(
                      label: entry.$1,
                      member: top[entry.$2] is Map
                          ? Map<String, dynamic>.from(top[entry.$2] as Map)
                          : null,
                      backend: backend,
                      formatNumber: formatNumber,
                    ),
                  ),
                ),
            ],
          ),
          const FamilySectionTitle('Member list'),
          InkWell(
            key: const Key('family-detail-member-list'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => onOpenMembers(memberList),
            child: FamilyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${memberList.length} members',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A2140),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF7A7390),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: memberList.length,
                    itemBuilder: (context, index) {
                      final member = memberList[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Column(
                          children: [
                            FamilyAvatar(
                              backend: backend,
                              avatarKey:
                                  member['avatar_key']?.toString() ?? '',
                              size: 44,
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: 56,
                              child: Text(
                                member['display_name']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
          if (roomMap != null) ...[
            const FamilySectionTitle('Family room'),
            FamilyCard(
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  key: const Key('family-detail-room'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.meeting_room,
                    color: Color(0xFF7E57C2),
                    size: 36,
                  ),
                  title: Text(
                    roomMap['name']?.toString() ?? 'Family room',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${_asInt(roomMap['live_count'])} in room • ${_asInt(roomMap['family_live_count'])} family members',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenRoom(roomMap),
                ),
              ),
            ),
          ],
          if (!isMember) ...[
            const SizedBox(height: 20),
            Center(
              child: FamilyGoldButton(
                key: const Key('family-detail-join'),
                label: 'Join',
                onPressed: onJoin,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TopMemberCard extends StatelessWidget {
  const _TopMemberCard({
    required this.label,
    required this.member,
    required this.backend,
    required this.formatNumber,
  });

  final String label;
  final Map<String, dynamic>? member;
  final BackendApi backend;
  final String Function(num value) formatNumber;

  @override
  Widget build(BuildContext context) => FamilyCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF7E57C2),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            if (member == null)
              const Text(
                'No one yet',
                style: TextStyle(color: Color(0xFF7A7390)),
              )
            else ...[
              FamilyAvatar(
                backend: backend,
                avatarKey: member?['avatar_key']?.toString() ?? '',
                size: 48,
              ),
              const SizedBox(height: 6),
              Text(
                member?['display_name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                formatNumber(
                  int.tryParse(member?['value']?.toString() ?? '') ?? 0,
                ),
                style: const TextStyle(color: Color(0xFF7A7390)),
              ),
            ],
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// TASK tab
// ---------------------------------------------------------------------------

class _TaskTab extends StatelessWidget {
  const _TaskTab({
    required this.detail,
    required this.tasks,
    required this.onCheckIn,
    required this.formatNumber,
  });

  final Map<String, dynamic> detail;
  final Map<String, dynamic>? tasks;
  final VoidCallback onCheckIn;
  final String Function(num value) formatNumber;

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final family = detail['family'];
    final familyMap =
        family is Map ? Map<String, dynamic>.from(family) : const {};
    final walletCoins = _asInt(familyMap['wallet_coins']);
    final signedIn = tasks?['signed_in'] == true;
    final stay = tasks?['stay'];
    final stayMap = stay is Map ? Map<String, dynamic>.from(stay) : const {};
    final mic = tasks?['mic'];
    final micMap = mic is Map ? Map<String, dynamic>.from(mic) : const {};

    Widget taskRow({
      required String title,
      required String progress,
      required String reward,
      required bool done,
      Widget? action,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A2140),
                      ),
                    ),
                    Text(
                      '$progress • $reward',
                      style: const TextStyle(color: Color(0xFF7A7390)),
                    ),
                  ],
                ),
              ),
              if (action != null) action,
              if (action == null)
                Text(
                  done ? 'Done' : 'Not done',
                  style: TextStyle(
                    color: done ? Colors.green : const Color(0xFF7A7390),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FamilyCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Family vault',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A2140),
                  ),
                ),
                Text(
                  'Current Balance: ${formatNumber(walletCoins)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A7390),
                  ),
                ),
              ],
            ),
          ),
          const FamilySectionTitle('Daily tasks'),
          FamilyCard(
            child: Column(
              children: [
                taskRow(
                  title: 'Sign in on the family homepage',
                  progress: signedIn ? '1/1' : '0/1',
                  reward: 'EXP 405,000 + 8,100 coins',
                  done: signedIn,
                  action: signedIn
                      ? null
                      : FilledButton(
                          key: const Key('family-task-sign-in'),
                          onPressed: onCheckIn,
                          child: const Text('Sign in'),
                        ),
                ),
                taskRow(
                  title: 'Enter any family room and stay for 20 minutes',
                  progress:
                      '${_asInt(stayMap['minutes'])}/20',
                  reward: 'EXP 1,215,000 + 8,100 coins',
                  done: stayMap['awarded'] == true,
                ),
                taskRow(
                  title: 'Enter any family room and turn on the mic for 10 minutes',
                  progress: '${_asInt(micMap['minutes'])}/10',
                  reward: 'EXP 2,025,000 + 8,100 coins',
                  done: micMap['awarded'] == true,
                ),
                taskRow(
                  title: 'Send gift 1 coin = 1 EXP (family gift x2)',
                  progress: 'No upper limit',
                  reward: 'EXP only',
                  done: false,
                ),
                taskRow(
                  title: 'Receive gift 1 coin = 1 EXP (family gift x2)',
                  progress: 'No upper limit',
                  reward: 'EXP only',
                  done: false,
                ),
                taskRow(
                  title: 'Play games 100 coins = 1 EXP',
                  progress: 'No upper limit',
                  reward: 'EXP only',
                  done: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TRENDS tab
// ---------------------------------------------------------------------------

class _TrendsTab extends StatefulWidget {
  const _TrendsTab({
    required this.backend,
    required this.state,
    required this.posts,
    required this.isMember,
    required this.onReload,
  });

  final BackendApi backend;
  final AppState state;
  final List<Map<String, dynamic>> posts;
  final bool isMember;
  final Future<void> Function() onReload;

  @override
  State<_TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<_TrendsTab> {
  final TextEditingController _composer = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _post() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    final value = await widget.backend.createFamilyTrendPost(
      userId: widget.state.userId,
      text: text,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (value?['ok'] == true) {
      _composer.clear();
      await widget.onReload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value?['error'] == 'content_blocked'
                ? 'This post has a word that is not allowed'
                : 'Could not post',
          ),
        ),
      );
    }
  }

  Future<void> _like(Map<String, dynamic> post) async {
    final value = await widget.backend.likeFamilyTrendPost(
      userId: widget.state.userId,
      postId: post['id']?.toString() ?? '',
    );
    if (!mounted || value?['ok'] != true) return;
    await widget.onReload();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (widget.isMember)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('family-trends-composer'),
                      controller: _composer,
                      decoration: const InputDecoration(
                        hintText: 'Share something with your family...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('family-trends-post'),
                    onPressed: _posting ? null : _post,
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: widget.posts.isEmpty
                ? const Center(
                    child: Text(
                      'No posts yet',
                      style: TextStyle(color: Color(0xFF2A2140)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: widget.posts.length,
                    itemBuilder: (context, index) {
                      final post = widget.posts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FamilyCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  FamilyAvatar(
                                    backend: widget.backend,
                                    avatarKey:
                                        post['avatar_key']?.toString() ?? '',
                                    size: 40,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      post['display_name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2A2140),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post['text']?.toString() ?? '',
                                style:
                                    const TextStyle(color: Color(0xFF4A4458)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    key: Key(
                                      'family-trends-like-${post['id']}',
                                    ),
                                    onPressed: widget.isMember
                                        ? () => _like(post)
                                        : null,
                                    icon: Icon(
                                      post['liked_by_me'] == true
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: post['liked_by_me'] == true
                                          ? Colors.red
                                          : null,
                                    ),
                                    label: Text(
                                      '${_asInt(post['like_count'])}',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_asInt(post['comment_count'])} comments',
                                    style: const TextStyle(
                                      color: Color(0xFF7A7390),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
}
