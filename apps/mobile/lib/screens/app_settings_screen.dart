import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';
import 'legal_policy_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool roomNotifications = true;
  bool messageNotifications = true;
  String language = 'English';

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Setting')),
        body: TinniBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              const TinniPanel(
                child: ListTile(
                  leading: TinniGlowIcon(
                    icon: Icons.settings_rounded,
                    size: 18,
                    boxSize: 34,
                  ),
                  title: Text(
                    'App settings',
                    style: TextStyle(
                      color: TinniPalette.cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text('DarkVibeX account and preferences'),
                ),
              ),
              const SizedBox(height: 9),
              TinniPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: TinniPalette.gold,
                      ),
                      title: const Text('Room notifications'),
                      value: roomNotifications,
                      onChanged: (value) =>
                          setState(() => roomNotifications = value),
                    ),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.mark_chat_unread_outlined,
                        color: TinniPalette.gold,
                      ),
                      title: const Text('Message notification'),
                      value: messageNotifications,
                      onChanged: (value) =>
                          setState(() => messageNotifications = value),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.language_rounded,
                        color: TinniPalette.gold,
                      ),
                      title: const Text('Language'),
                      subtitle: Text(language),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final selected =
                            await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: TinniPalette.nearBlack,
                          builder: (sheetContext) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final value in const [
                                  'English',
                                  'हिन्दी',
                                ])
                                  ListTile(
                                    title: Text(value),
                                    onTap: () => Navigator.pop(
                                      sheetContext,
                                      value,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (selected != null) {
                          setState(() => language = selected);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              TinniPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.security_rounded,
                        color: TinniPalette.gold,
                      ),
                      title: const Text('Privacy & Safety'),
                      subtitle: const Text(
                        'Account protection, reports and privacy controls',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LegalPolicyScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.privacy_tip_outlined,
                        color: TinniPalette.gold,
                      ),
                      title: const Text('Terms & Privacy'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LegalPolicyScreen(),
                        ),
                      ),
                    ),
                    const ListTile(
                      leading: Icon(
                        Icons.info_outline_rounded,
                        color: TinniPalette.gold,
                      ),
                      title: Text('About DarkVibeX'),
                      subtitle: Text('Free social voice-room app'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              TinniPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text('Sign out'),
                  subtitle: Text(
                    widget.state.authProvider == 'google'
                        ? 'Google account'
                        : 'Guest session',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await widget.state.signOut();
                    if (context.mounted) {
                      Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
