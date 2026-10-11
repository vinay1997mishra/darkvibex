import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'family_screen.dart';
import 'relationships_screen.dart';
import 'store_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  void _info(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD36A),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44FFD36A),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded, size: 40),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('ID ${state.userId} • VIP ${state.vipLevel}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded),
                  title: const Text('VIP'),
                  subtitle: Text('Level ${state.vipLevel}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreScreen(state: state),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_rounded),
                  title: const Text('Unique ID'),
                  subtitle: Text(state.userId),
                  trailing: const Icon(Icons.copy_rounded),
                  onTap: () => _info(
                    context,
                    'Your DarkVibeX ID',
                    'Use ${state.userId} for profile, room and relationship searches.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.family_restroom_rounded),
                  title: const Text('Family'),
                  subtitle: const Text('Family level, members and daily sign-in'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FamilyScreen(state: state),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.favorite_rounded),
                  title: const Text('CP & Enemy'),
                  subtitle: const Text(
                    'Independent relationship levels powered by their own gifts',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RelationshipsScreen(state: state),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.store_rounded),
                  title: const Text('Store'),
                  subtitle: const Text(
                    'VIP, frames, rings, bubbles, profile backgrounds, entries and themes',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreScreen(state: state),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.security_rounded),
                  title: const Text('Privacy & Safety'),
                  subtitle: const Text('Block, report and moderation controls'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _info(
                    context,
                    'Privacy & Safety',
                    'DarkVibeX moderation is controlled by the protected Owner Panel. Account suspension, bans and mute controls are server enforced.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: const Text('Settings'),
                  subtitle: const Text('Account and app settings'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _info(
                    context,
                    'Settings',
                    'DarkVibeX uses owner-controlled feature switches and maintenance settings.',
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text('Sign out'),
                  subtitle: Text(
                    state.authProvider == 'google'
                        ? 'Google account'
                        : 'Guest session',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: state.signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
