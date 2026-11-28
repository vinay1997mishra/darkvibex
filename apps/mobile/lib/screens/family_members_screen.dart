// Family members page (Mr. Wrong, 2026-11-24): tapping the "N members"
// section on the Family Detail page opens this full members list, like
// in the reference video — leader first, then admins, then members, each
// with coins and last login. And everything the Management page has:
// admin controls (make/remove admin, remove member), join requests
// (approve/reject) and Leave Family — exactly as they are there.
import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/infra/family_rules.dart';
import 'package:material_ui/material_ui.dart';
import 'family_common.dart';
import 'profile_screen.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({
    super.key,
    required this.state,
    required this.familyId,
    required this.familyName,
    required this.members,
    this.myRole,
    this.joinRequests = const [],
    this.backend,
  });

  final AppState state;
  final String familyId;
  final String familyName;

  /// Snapshot from the Detail page (first paint); refreshed after actions.
  final List<Map<String, dynamic>> members;

  /// The viewer's role in this family ('leader' / 'admin' / 'member'),
  /// null when the viewer is not a member of this family.
  final String? myRole;

  /// Pending join requests (leader/admin only, from familyDetail).
  final List<Map<String, dynamic>> joinRequests;

  final BackendApi? backend;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  BackendApi get _backend => widget.backend ?? widget.state.backend;

  late List<Map<String, dynamic>> _members;
  late List<Map<String, dynamic>> _requests;
  late String? _myRole;

  @override
  void initState() {
    super.initState();
    _members = widget.members
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _requests = widget.joinRequests
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _myRole = widget.myRole;
  }

  bool get _canManage => _myRole == 'leader' || _myRole == 'admin';

  int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  // Same last-login text as the Family Management page ("Today",
  // "1 day ago", "Never logged in").
  String _lastLoginText(int lastSeenAt) {
    if (lastSeenAt <= 0) return 'Never logged in';
    final days = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastSeenAt))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'leader':
        return 'Leader';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Members page (Mr. Wrong, 2026-11-24): tapping a member's DP opens
  // their ID (public profile) — the same screen the ranking rows open.
  // Family members see each other's real names/DPs here, so there is no
  // anonymous-row guard like the public rankings have.
  Future<void> _openMemberProfile(Map<String, dynamic> member) async {
    final userId = member['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          state: widget.state,
          userId: userId,
        ),
      ),
    );
  }

  Future<void> _reload() async {
    final detail = await _backend.familyDetail(familyId: widget.familyId);
    if (!mounted || detail == null || detail['ok'] != true) return;
    final family = detail['family'];
    final members = detail['members'];
    final requests = detail['join_requests'];
    setState(() {
      if (members is List) {
        _members = members
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (requests is List) {
        _requests = requests
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (family is Map) _myRole = family['my_role']?.toString();
    });
  }

  Future<void> _resolveRequest(
    Map<String, dynamic> request,
    bool approve,
  ) async {
    final ok = await _backend.resolveFamilyJoin(
      userId: widget.state.userId,
      targetUserId: request['user_id'].toString(),
      approve: approve,
    );
    if (!mounted) return;
    if (ok) {
      await _reload();
    } else {
      _showMessage('Could not update the join request');
    }
  }

  Future<void> _setAdmin(Map<String, dynamic> member, bool admin) async {
    final ok = await _backend.setFamilyAdmin(
      userId: widget.state.userId,
      targetUserId: member['user_id'].toString(),
      admin: admin,
    );
    if (!mounted) return;
    if (ok) {
      await _reload();
    } else {
      _showMessage('Could not update admin');
    }
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final ok = await _backend.removeFamilyMember(
      userId: widget.state.userId,
      targetUserId: member['user_id'].toString(),
    );
    if (!mounted) return;
    if (ok) {
      await _reload();
    } else {
      _showMessage('Could not remove member');
    }
  }

  Future<void> _leave() async {
    final ok = await _backend.leaveFamily(userId: widget.state.userId);
    if (!mounted) return;
    if (ok) {
      // Back to the Detail page, which refreshes itself on pop.
      Navigator.pop(context);
    } else {
      _showMessage('Could not leave the family');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: familyAppBar(widget.familyName),
      body: FamilyBackground(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                '${_members.length} members',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF2A2140),
                ),
              ),
              if (_canManage && _requests.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Join requests',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF2A2140),
                  ),
                ),
                const SizedBox(height: 8),
                for (final request in _requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FamilyCard(
                      child: Row(
                        children: [
                          FamilyAvatar(
                            backend: _backend,
                            avatarKey: request['avatar_key']?.toString() ?? '',
                            size: 48,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              request['display_name']?.toString() ??
                                  request['user_id'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A2140),
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key(
                              'family-join-approve-${request['user_id']}',
                            ),
                            onPressed: () => _resolveRequest(request, true),
                            icon: const Icon(Icons.check_rounded),
                          ),
                          IconButton(
                            key: Key(
                              'family-join-reject-${request['user_id']}',
                            ),
                            onPressed: () => _resolveRequest(request, false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              for (final member in _members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FamilyCard(
                    child: Row(
                      children: [
                        GestureDetector(
                          key: Key(
                            'family-member-dp-${member['user_id']}',
                          ),
                          onTap: () => _openMemberProfile(member),
                          child: FamilyAvatar(
                            backend: _backend,
                            avatarKey: member['avatar_key']?.toString() ?? '',
                            size: 48,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member['display_name']?.toString() ?? 'User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2A2140),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  _roleLabel(
                                    member['role']?.toString() ?? 'member',
                                  ),
                                  'Coins: ${formatFamilyCoins(_asInt(member['received_coins']))}',
                                  _lastLoginText(
                                    _asInt(member['last_seen_at']),
                                  ),
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7A7390),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_canManage &&
                            member['user_id']?.toString() !=
                                widget.state.userId &&
                            member['role']?.toString() != 'leader')
                          PopupMenuButton<String>(
                            key: Key(
                              'family-member-menu-${member['user_id']}',
                            ),
                            onSelected: (action) async {
                              if (action == 'admin') {
                                await _setAdmin(
                                  member,
                                  member['role'] != 'admin',
                                );
                              } else if (action == 'remove') {
                                await _removeMember(member);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'admin',
                                child: Text(
                                  member['role'] == 'admin'
                                      ? 'Remove admin'
                                      : 'Make admin',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove member'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              if (_myRole != null && _myRole != 'leader') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('family-members-leave'),
                  onPressed: _leave,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Leave Family'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
