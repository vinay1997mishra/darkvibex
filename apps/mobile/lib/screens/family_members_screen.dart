// Family members page (Mr. Wrong, 2026-11-24): tapping the "N members"
// section on the Family Detail page opens this full members list, like
// in the reference video — leader first, then admins, then members,
// each with coins and last login.
import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:darkvibex/infra/family_rules.dart';
import 'package:flutter/material.dart';
import 'family_common.dart';

class FamilyMembersScreen extends StatelessWidget {
  const FamilyMembersScreen({
    super.key,
    required this.state,
    required this.familyId,
    required this.familyName,
    required this.members,
    this.backend,
  });

  final AppState state;
  final String familyId;
  final String familyName;
  final List<Map<String, dynamic>> members;
  final BackendApi? backend;

  BackendApi get _backend => backend ?? state.backend;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: familyAppBar(familyName),
      body: FamilyBackground(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: members.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${members.length} members',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF2A2140),
                  ),
                ),
              );
            }
            final member = members[index - 1];
            final role = member['role']?.toString() ?? 'member';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FamilyCard(
                child: Row(
                  children: [
                    FamilyAvatar(
                      backend: _backend,
                      avatarKey: member['avatar_key']?.toString() ?? '',
                      size: 48,
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
                              _roleLabel(role),
                              'Coins: ${formatFamilyCoins(_asInt(member['received_coins']))}',
                              _lastLoginText(_asInt(member['last_seen_at'])),
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A7390),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
