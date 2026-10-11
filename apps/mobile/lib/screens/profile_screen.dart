import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'vip_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

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
              const CircleAvatar(
                radius: 36,
                child: Icon(Icons.person_rounded, size: 40),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.displayName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    Text('ID ${state.userId} • VIP ${state.vipLevel}'),
                  ],
                ),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.edit_rounded)),
            ],
          ),
          const SizedBox(height: 22),
          Card(
            child: Column(
              children: [
                _item(Icons.workspace_premium_rounded, 'VIP', 'Level ${state.vipLevel}/18'),
                _item(Icons.badge_rounded, 'Unique ID', state.userId),
                _item(Icons.family_restroom_rounded, 'Family', 'Community and rankings'),
                _item(Icons.favorite_rounded, 'CP', 'Relationship level and gifts'),
                _item(Icons.store_rounded, 'Store', 'Frames, effects and themes'),
                _item(Icons.security_rounded, 'Privacy & Safety', 'Block, report and controls'),
                _item(Icons.settings_rounded, 'Settings', 'Language, account and app settings'),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text('Sign out'),
                  subtitle: Text(state.authProvider == 'google' ? 'Google account' : 'Guest session'),
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

  Widget _item(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {},
    );
  }
}
