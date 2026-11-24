// Family detail page — NEW design (Mr. Wrong, 2026-11-24): a single
// scroll page, same-to-same as the other app's family page, built with
// DarkVibeX's own original purple+gold models. The OLD detail page
// (HOME / TASK / TRENDS tabs) is REMOVED — his words: "jo pehle add tha
// usko hta de". The Daily Lucky Wheel SPIN is live now (event hold lifted:
// "wheel bhi"). Animation effects (the other app's family SVGA: lottery
// spin, today sign-in, level backgrounds) are done in Flutter, with
// original art — no copied assets: the wheel spins (ease-out rotation),
// the win shows a gold celebration, the cover has a shine sweep, the
// sign-in button pops when done.
// Sections, in order: cover hero (cover model + golden ring logo),
// family head + notice banner (banner model), level card (badge + EXP
// crystal models), stats, actions (Daily Sign-in / Wheel / Members /
// Room), spinnable Lucky Wheel (wheel model), Lucky Draw Records, Top
// Members, Members (search), Family Room.
import 'dart:math' as math;

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
    with TickerProviderStateMixin {
  BackendApi get _backend => widget.backend ?? widget.state.backend;

  bool _loading = true;
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _tasks;
  List<Map<String, dynamic>> _records = const [];
  String? _error;

  // Lucky Wheel spin animation: the wheel turns several full rounds and
  // eases out to a stop (easeOutCubic), like the other app's lottery.
  late final AnimationController _spinController = AnimationController(
    duration: const Duration(milliseconds: 3200),
    vsync: this,
  );
  late final Animation<double> _spinCurve = CurvedAnimation(
    parent: _spinController,
    curve: Curves.easeOutCubic,
  );
  double _wheelAngle = 0; // accumulated wheel rotation, radians
  double _spinFrom = 0;
  double _spinTo = 0;
  bool _spinning = false;
  int? _spinWonCoins;
  String? _spinError;

  // Win celebration: the result pops in (scale + fade).
  late final AnimationController _winController = AnimationController(
    duration: const Duration(milliseconds: 450),
    vsync: this,
  );

  // Cover shine sweep: a soft diagonal light that crosses the cover
  // once when the page loads. One-shot on purpose (not repeating): a
  // repeating ticker would keep scheduling frames forever, and the
  // render test's pumpAndSettle would never settle.
  late final AnimationController _shineController = AnimationController(
    duration: const Duration(milliseconds: 1600),
    vsync: this,
  );

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final GlobalKey _wheelKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _load();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _winController.dispose();
    _shineController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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
    final records =
        await _backend.familyLuckyDrawRecords(familyId: widget.familyId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _tasks = tasks;
      _records = records;
      _loading = false;
    });
    // Cover shine sweep, once the page is on screen.
    _shineController.forward(from: 0);
  }

  Map<String, dynamic> get _family {
    final family = _detail?['family'];
    return family is Map ? Map<String, dynamic>.from(family) : const {};
  }

  bool get _isMember => _family['is_member'] == true;

  Map<String, dynamic> get _wheel {
    final wheel = _detail?['wheel'];
    return wheel is Map ? Map<String, dynamic>.from(wheel) : const {};
  }

  int get _wheelSpinsLeft => _asInt(_wheel['spins_left']);
  int get _wheelDrawsLeft => _asInt(_wheel['draws_left']);
  int get _wheelDrawsTotal => _asInt(_wheel['draws_total']);
  int get _wheelTopPrize => _asInt(_wheel['top_prize']);
  bool get _wheelHasSpun => _wheel['has_spun'] == true;

  /// The 8 wheel prizes (server-driven segment values). The wheel model
  /// itself has no numbers painted on it, so the coins must be written
  /// out under the wheel (Mr. Wrong, 2026-11-24: "Spin per coins bhi
  /// likhe nhi dikh rahe hain").
  List<int> get _wheelSegments {
    final segments = _wheel['segments'];
    if (segments is! List) return const <int>[];
    return segments.map(_asInt).where((value) => value > 0).toList();
  }

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _formatNumber(num value) {
    final v = value.toDouble();
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(2)}B';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)}K';
    return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 2);
  }

  String _lastSeenLabel(int lastSeenAt) {
    if (lastSeenAt <= 0) return 'Never logged in';
    final diff = DateTime.now().millisecondsSinceEpoch - lastSeenAt;
    if (diff < 86400000) return 'Today';
    final days = diff ~/ 86400000;
    return days == 1 ? '1 day ago' : '$days days ago';
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _join() async {
    final result = await _backend.requestFamilyJoin(
      userId: widget.state.userId,
      familyId: widget.familyId,
    );
    if (!mounted) return;
    if (result.joined) {
      _showMessage('Joined the family!');
      await _load();
    } else if (result.ok) {
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

  Future<void> _spin() async {
    if (_spinning) return;
    if (!_isMember) {
      _showMessage('Join the family first to spin');
      return;
    }
    if (_wheelHasSpun) {
      _showMessage('You already spun today — come back tomorrow');
      return;
    }
    if (_wheelDrawsLeft <= 0) {
      _showMessage('No draws left today');
      return;
    }
    setState(() {
      _spinning = true;
      _spinWonCoins = null;
      _spinError = null;
    });
    final value = await _backend.familyLuckyWheelSpin(
      userId: widget.state.userId,
      familyId: widget.familyId,
    );
    if (!mounted) return;
    if (value == null || value['ok'] != true) {
      final error = value?['error']?.toString() ?? '';
      setState(() {
        _spinning = false;
        _spinError = error == 'already_spun'
            ? 'You already spun today'
            : error == 'no_draws_left'
                ? 'No draws left today'
                : 'Could not spin';
      });
      await _load();
      return;
    }
    final won = _asInt(value['coins']);
    // The wheel lands on the won prize (Mr. Wrong, 2026-11-24: "Wheel
    // ghumna bhi chahiye" + "Random coins amount win ke liye"): the
    // server rolls a RANDOM segment (weighted random over the 8
    // prizes), and the wheel turns 5 full rounds, then eases out so
    // the pointer stops on that segment. 8 segments of 45 degrees;
    // segment i is centred i*45 + 22.5 degrees clockwise from the top
    // in the artwork, so the wheel must turn 360 - (i*45 + 22.5)
    // degrees past the full rounds (plus a small jitter inside the
    // segment so it never stops dead-centre twice in a row).
    final responseSegments = value['segments'];
    final segments = responseSegments is List
        ? responseSegments.map(_asInt).where((v) => v > 0).toList()
        : _wheelSegments;
    final winIndex = segments.indexOf(won);
    final random = math.Random();
    final double landing;
    if (winIndex >= 0) {
      final jitter = (random.nextDouble() - 0.5) * (math.pi / 7.5);
      landing = 5 * 2 * math.pi +
          (2 * math.pi - (winIndex * math.pi / 4 + math.pi / 8)) +
          jitter;
    } else {
      landing = (5 + random.nextDouble()) * 2 * math.pi;
    }
    _spinFrom = _wheelAngle;
    _spinTo = _wheelAngle + landing;
    await _spinController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _wheelAngle = _spinTo;
      _spinning = false;
      _spinWonCoins = won;
    });
    _winController.forward(from: 0);
    await _load();
  }

  void _scrollToWheel() {
    final context = _wheelKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        alignment: 0.1,
      );
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
  // The members page also carries everything the Management page has
  // (admin controls, join requests, Leave Family), so it gets the
  // viewer's role and the pending requests from this detail snapshot.
  void _openMembers(List<Map<String, dynamic>> members) {
    final requests = _detail?['join_requests'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyMembersScreen(
          state: widget.state,
          familyId: widget.familyId,
          familyName: _family['name']?.toString() ?? 'Family',
          members: members,
          myRole: _family['my_role']?.toString(),
          joinRequests: requests is List
              ? requests
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : const [],
          backend: widget.backend,
        ),
      ),
    ).then((_) => _load());
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
                : _buildPage(),
      ),
    );
  }

  Widget _buildPage() {
    final family = _family;
    final experience = _asInt(family['experience']);
    final level = _asInt(family['level']);
    final nextExp = family['next_exp'];
    final nextExpValue = nextExp is num ? nextExp.toDouble() : null;
    final expProgress = nextExpValue == null || nextExpValue <= 0
        ? 1.0
        : (experience / nextExpValue).clamp(0.0, 1.0);
    final topMembers = _detail?['top_members'];
    final top = topMembers is Map
        ? Map<String, dynamic>.from(topMembers)
        : const <String, dynamic>{};
    final members = _detail?['members'];
    final memberList = members is List
        ? members.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];
    final filteredMembers = _searchQuery.isEmpty
        ? memberList
        : memberList
            .where(
              (m) => (m['display_name']?.toString() ?? '')
                  .toLowerCase()
                  .contains(_searchQuery),
            )
            .toList();
    final room = _detail?['room'];
    final roomMap = room is Map ? Map<String, dynamic>.from(room) : null;
    final signedIn = _tasks?['signed_in'] == true;
    final totalWinnings = _records.fold<int>(
      0,
      (sum, record) => sum + _asInt(record['coins']),
    );

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCover(family, memberList),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHead(family, memberList),
                _buildLevelCard(family, level, experience, nextExpValue,
                    expProgress),
                _buildStats(family, level, memberList),
                _buildActions(signedIn, memberList, roomMap),
                _buildTasksCard(signedIn),
                _buildWheelCard(totalWinnings),
                _buildRecordsCard(),
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
                                ? Map<String, dynamic>.from(
                                    top[entry.$2] as Map,
                                  )
                                : null,
                            backend: _backend,
                            formatNumber: _formatNumber,
                          ),
                        ),
                      ),
                  ],
                ),
                _buildMembersCard(memberList, filteredMembers),
                if (roomMap != null) ...[
                  const FamilySectionTitle('Family room'),
                  _buildRoomCard(roomMap),
                ],
                if (!_isMember) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: FamilyGoldButton(
                      key: const Key('family-detail-join'),
                      label: 'Join',
                      onPressed: _join,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cover hero: the original cover model (2:1, golden ring centred) with
  // the family logo sitting inside the ring, a ROOM LIVE chip, the family
  // ID, and the member avatars along the bottom — plus a shine sweep.
  Widget _buildCover(
    Map<String, dynamic> family,
    List<Map<String, dynamic>> memberList,
  ) {
    final room = _detail?['room'];
    final roomMap = room is Map ? Map<String, dynamic>.from(room) : null;
    final liveCount = _asInt(roomMap?['live_count']);
    final shownAvatars = memberList.take(5).toList();
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/family_cover_new.webp',
            fit: BoxFit.cover,
          ),
          // Shine sweep animation.
          AnimatedBuilder(
            animation: _shineController,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width;
              final t = _shineController.value;
              final dx = (t * 1.8 - 0.4) * width;
              return ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: dx - 45,
                      top: -50,
                      bottom: -50,
                      width: 90,
                      child: Transform.rotate(
                        angle: 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.16),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (liveCount > 0)
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'ROOM LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ID: ${family['id']?.toString() ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Family logo, centred inside the golden ring.
          Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD54A),
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: FamilyAvatar(
                backend: _backend,
                avatarKey: family['logo_key']?.toString() ?? '',
                size: 88,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 28,
                  child: Stack(
                    children: [
                      for (var i = 0; i < shownAvatars.length; i++)
                        Positioned(
                          left: i * 20,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: FamilyAvatar(
                              backend: _backend,
                              avatarKey: shownAvatars[i]['avatar_key']
                                      ?.toString() ??
                                  '',
                              size: 26,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${memberList.length} members',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Family head: name, rank/member/tag pills, and the notice on the
  // original banner model.
  Widget _buildHead(
    Map<String, dynamic> family,
    List<Map<String, dynamic>> memberList,
  ) {
    final notice = family['notice']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          family['name']?.toString() ?? 'Family',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2A2140),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pill(family['rank']?.toString() ?? '', const Color(0xFF7E57C2)),
            const SizedBox(width: 8),
            _pill('${memberList.length} Members', const Color(0xFFE8A91C)),
            const SizedBox(width: 8),
            _pill(family['tag']?.toString() ?? '', const Color(0xFF2A2140)),
          ],
        ),
        if (notice.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: AssetImage('assets/images/family_banner_new.webp'),
                fit: BoxFit.cover,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              notice,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pill(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // Level card: the original level-badge model, Level N, rank, EXP bar
  // with the original EXP crystal model, and my contributed EXP.
  Widget _buildLevelCard(
    Map<String, dynamic> family,
    int level,
    int experience,
    double? nextExpValue,
    double expProgress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FamilySectionTitle('Family level'),
        FamilyCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/family_level_badge.webp',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Level $level',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2A2140),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            family['rank']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Family EXP',
                          style: TextStyle(color: Color(0xFF7A7390)),
                        ),
                        const Spacer(),
                        Text(
                          nextExpValue == null
                              ? _formatNumber(experience)
                              : '${_formatNumber(experience)} / ${_formatNumber(nextExpValue)}',
                          style: const TextStyle(color: Color(0xFF7A7390)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: FamilyProgressBar(progress: expProgress),
                        ),
                        const SizedBox(width: 8),
                        Image.asset(
                          'assets/images/family_exp_crystal.webp',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Experience I contributed: ${_formatNumber(_asInt(family['my_contributed_exp']))}',
                      style: const TextStyle(color: Color(0xFF4A4458)),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('family-detail-monthly-ranking'),
                        onPressed: _openMonthlyRanking,
                        child: const Text('Ranking of the Month >'),
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
  }

  Widget _buildStats(
    Map<String, dynamic> family,
    int level,
    List<Map<String, dynamic>> memberList,
  ) {
    Widget stat(String value, String label) => Expanded(
          child: FamilyCard(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2A2140),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A7390),
                  ),
                ),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          stat('${memberList.length}', 'Members'),
          const SizedBox(width: 8),
          stat('Lv.$level', 'Family Level'),
          const SizedBox(width: 8),
          stat(family['rank']?.toString() ?? '-', 'Rank'),
        ],
      ),
    );
  }

  // Action buttons: Daily Sign-in, Lucky Wheel (scrolls to the wheel),
  // Members (full members page), Family Room.
  Widget _buildActions(
    bool signedIn,
    List<Map<String, dynamic>> memberList,
    Map<String, dynamic>? roomMap,
  ) {
    Widget action({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FilledButton.icon(
              key: key,
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          action(
            key: const Key('family-detail-sign-in'),
            icon: signedIn ? Icons.check_circle : Icons.calendar_today,
            label: signedIn ? 'Signed In' : 'Daily Sign-in',
            onPressed: signedIn ? null : _checkIn,
          ),
          action(
            key: const Key('family-detail-goto-wheel'),
            icon: Icons.casino,
            label: 'Lucky Wheel',
            onPressed: _scrollToWheel,
          ),
          action(
            key: const Key('family-detail-goto-members'),
            icon: Icons.group,
            label: 'Members',
            onPressed: () => _openMembers(memberList),
          ),
          action(
            key: const Key('family-detail-goto-room'),
            icon: Icons.meeting_room,
            label: 'Family Room',
            onPressed: roomMap == null ? null : () => _openRoom(roomMap),
          ),
        ],
      ),
    );
  }

  // Daily tasks (Mr. Wrong, 2026-11-24): TASK stays, TRENDS goes. The
  // daily tasks live on the detail page as a section in the single
  // scroll: sign-in, stay 20 min, mic 10 min, gift EXP, game EXP.
  // (TRENDS — family posts — is gone from this page, by his word.)
  Widget _buildTasksCard(bool signedIn) {
    final stay = _tasks?['stay'];
    final stayMap = stay is Map ? Map<String, dynamic>.from(stay) : const {};
    final stayMinutes = _asInt(stayMap['minutes']);
    final stayTarget =
        _asInt(stayMap['target']) == 0 ? 20 : _asInt(stayMap['target']);
    final mic = _tasks?['mic'];
    final micMap = mic is Map ? Map<String, dynamic>.from(mic) : const {};
    final micMinutes = _asInt(micMap['minutes']);
    final micTarget =
        _asInt(micMap['target']) == 0 ? 10 : _asInt(micMap['target']);
    final walletCoins = _family['wallet_coins'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FamilySectionTitle('Daily tasks'),
        FamilyCard(
          child: Column(
            children: [
              if (_isMember && walletCoins != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Family vault',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A2140),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_formatNumber(_asInt(walletCoins))} coins',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE8A91C),
                        ),
                      ),
                    ],
                  ),
                ),
              _taskRow(
                title: 'Sign in',
                reward: '405,000 EXP + 8,100 coins',
                trailing: signedIn
                    ? const Text(
                        'Signed In ✓',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : FilledButton(
                        key: const Key('family-task-sign-in'),
                        onPressed: _checkIn,
                        child: const Text('Sign in'),
                      ),
              ),
              const Divider(),
              _taskRow(
                title: 'Stay in family room 20 min',
                reward: '1,215,000 EXP + 8,100 coins',
                progress: stayMinutes / stayTarget,
                progressLabel: stayMinutes >= stayTarget
                    ? 'Done'
                    : '$stayMinutes/$stayTarget min',
              ),
              const Divider(),
              _taskRow(
                title: 'Mic on 10 min',
                reward: '2,025,000 EXP + 8,100 coins',
                progress: micMinutes / micTarget,
                progressLabel: micMinutes >= micTarget
                    ? 'Done'
                    : '$micMinutes/$micTarget min',
              ),
              const Divider(),
              _taskRow(
                title: 'Send gift',
                reward: '1 coin = 1 EXP (own family ×2)',
              ),
              const Divider(),
              _taskRow(
                title: 'Receive gift',
                reward: '1 coin = 1 EXP (own family ×2)',
              ),
              const Divider(),
              _taskRow(
                title: 'Play games',
                reward: '100 coins = 1 EXP',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskRow({
    required String title,
    required String reward,
    Widget? trailing,
    double? progress,
    String? progressLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  reward,
                  style: const TextStyle(
                    color: Color(0xFF7A7390),
                    fontSize: 12,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 4),
                  FamilyProgressBar(progress: progress.clamp(0.0, 1.0)),
                  if (progressLabel != null)
                    Text(
                      progressLabel,
                      style: const TextStyle(
                        color: Color(0xFF7A7390),
                        fontSize: 12,
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }

  // Daily Lucky Wheel: the original wheel model, spinning on SPIN FREE,
  // with draws left, top prize, and the win celebration.
  Widget _buildWheelCard(int totalWinnings) {
    final canSpin = _isMember && !_wheelHasSpun && _wheelDrawsLeft > 0;
    final spinLabel = !_isMember
        ? 'Join to Spin'
        : _wheelHasSpun
            ? 'Come Back Tomorrow'
            : _wheelDrawsLeft <= 0
                ? 'No Draws Left'
                : _spinning
                    ? 'Spinning...'
                    : 'SPIN FREE';
    return Column(
      key: _wheelKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FamilySectionTitle('Daily Lucky Wheel'),
        FamilyCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Family Winnings Today: ${_formatNumber(totalWinnings)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A2140),
                    ),
                  ),
                  const Text(
                    'Resets 12:00 AM',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7A7390)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tapping the wheel itself spins it too (Mr. Wrong,
              // 2026-11-24: "Wheel ghumna bhi chahiye") — same guards
              // as the SPIN button (members only, once a day).
              GestureDetector(
                key: const Key('family-wheel'),
                onTap: _spin,
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _spinCurve,
                        builder: (context, child) {
                          final angle = _spinFrom +
                              (_spinTo - _spinFrom) * _spinCurve.value;
                          return Transform.rotate(angle: angle, child: child);
                        },
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/family_lucky_wheel.webp',
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Pointer at the top.
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 0,
                          height: 0,
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.transparent,
                                width: 10,
                              ),
                              right: BorderSide(
                                color: Colors.transparent,
                                width: 10,
                              ),
                              top: BorderSide(
                                color: Color(0xFFE8A91C),
                                width: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Prizes written out: the wheel artwork has no numbers on
              // its segments, so the 8 coin values are shown as chips
              // under the wheel (Mr. Wrong, 2026-11-24).
              if (_wheelSegments.isNotEmpty) ...[
                Wrap(
                  key: const Key('family-wheel-prizes'),
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final prize in _wheelSegments)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3C4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE8A91C),
                          ),
                        ),
                        child: Text(
                          '${_formatNumber(prize)} coins',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5A3E00),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_spinWonCoins != null)
                ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _winController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFFFFD54A),
                          Color(0xFFE8A91C),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'You won ${_formatNumber(_spinWonCoins!)} coins!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5A3E00),
                      ),
                    ),
                  ),
                ),
              if (_spinError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _spinError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_spinWonCoins != null || _spinError != null)
                const SizedBox(height: 8),
              FamilyGoldButton(
                key: const Key('family-detail-spin'),
                label: spinLabel,
                onPressed: canSpin && !_spinning ? _spin : null,
                enabled: canSpin && !_spinning,
              ),
              const SizedBox(height: 10),
              Text(
                '$_wheelSpinsLeft free spin left today • Top prize ${_formatNumber(_wheelTopPrize == 0 ? 217688 : _wheelTopPrize)} coins • Family draws left: $_wheelDrawsLeft/$_wheelDrawsTotal',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF7A7390)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FamilySectionTitle('Lucky Draw Records'),
        FamilyCard(
          child: _records.isEmpty
              ? const Text(
                  'No lucky draw records today yet.',
                  style: TextStyle(color: Color(0xFF7A7390)),
                )
              : Column(
                  children: [
                    for (final record in _records)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF7E57C2),
                              child: Text(
                                (record['display_name']?.toString() ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                record['display_name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2A2140),
                                ),
                              ),
                            ),
                            Text(
                              '+${_formatNumber(_asInt(record['coins']))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE8A91C),
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
  }

  Widget _buildMembersCard(
    List<Map<String, dynamic>> memberList,
    List<Map<String, dynamic>> filteredMembers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FamilySectionTitle('Member list'),
        FamilyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: const Key('family-detail-member-list'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openMembers(memberList),
                child: Row(
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
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('family-detail-member-search'),
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              if (filteredMembers.isEmpty)
                const Text(
                  'No members found',
                  style: TextStyle(color: Color(0xFF7A7390)),
                )
              else
                Column(
                  children: [
                    for (final member in filteredMembers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            FamilyAvatar(
                              backend: _backend,
                              avatarKey:
                                  member['avatar_key']?.toString() ?? '',
                              size: 40,
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
                                  Text(
                                    '${member['role']?.toString() ?? 'member'} • ${_lastSeenLabel(_asInt(member['last_seen_at']))}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7A7390),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Coins: ${_formatNumber(_asInt(member['received_coins']))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7A7390),
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
      ],
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> roomMap) {
    return FamilyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: const DecorationImage(
                image: AssetImage('assets/images/family_banner_new.webp'),
                fit: BoxFit.cover,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              roomMap['name']?.toString() ?? 'Family room',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_asInt(roomMap['live_count'])} in room',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7A7390)),
          ),
          const SizedBox(height: 10),
          Center(
            child: FamilyGoldButton(
              key: const Key('family-detail-room'),
              label: 'Enter Family Room',
              onPressed: () => _openRoom(roomMap),
            ),
          ),
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
