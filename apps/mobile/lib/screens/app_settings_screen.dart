import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'legal_policy_screen.dart';
import 'mine_social_screens.dart';
import 'settings_function_screens.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key, required this.state});

  final AppState state;

  Widget _row(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      key: key,
      leading: Icon(icon, color: TinniPalette.gold),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Setting')),
        body: TinniBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              TinniPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _row(
                      context,
                      key: const Key('setting-message-notification'),
                      icon: Icons.notifications_active_rounded,
                      title: 'Message notification',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MessageNotificationScreen(state: state),
                        ),
                      ),
                    ),
                    _row(
                      context,
                      key: const Key('setting-bind-account'),
                      icon: Icons.link_rounded,
                      title: 'Bind account',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BindAccountScreen(state: state),
                        ),
                      ),
                    ),
                    _row(
                      context,
                      key: const Key('setting-language'),
                      icon: Icons.language_rounded,
                      title: 'Language settings',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LanguageSettingsScreen(),
                        ),
                      ),
                    ),
                    _row(
                      context,
                      key: const Key('setting-about'),
                      icon: Icons.info_outline_rounded,
                      title: 'About DarkVibeX',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutDarkVibeXScreen(),
                        ),
                      ),
                    ),
                    _row(
                      context,
                      key: const Key('setting-feedback'),
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Feedback',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FeedbackScreen(state: state),
                        ),
                      ),
                    ),
                    _row(
                      context,
                      key: const Key('setting-blocklist'),
                      icon: Icons.block_rounded,
                      title: 'Blocklist',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BlocklistScreen(state: state),
                        ),
                      ),
                    ),
                    _row(
                      context,
                      key: const Key('setting-privacy-statement'),
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy statement',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LegalPolicyScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TinniPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  key: const Key('setting-sign-out'),
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text('Sign out'),
                  subtitle: Text(
                    switch (state.authProvider) {
                      'google' => 'Google account',
                      'email' => 'Email account',
                      _ => 'Guest session',
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await state.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
