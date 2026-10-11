import 'package:flutter/material.dart';

import 'legal_policy_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool roomNotifications = true;
  bool messageNotifications = true;
  String language = 'English';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            const ListTile(
              title: Text('App settings', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('DarkVibeX account and preferences'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Room notifications'),
              value: roomNotifications,
              onChanged: (value) => setState(() => roomNotifications = value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.mark_chat_unread_outlined),
              title: const Text('Message notifications'),
              value: messageNotifications,
              onChanged: (value) => setState(() => messageNotifications = value),
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: const Text('Language'),
              subtitle: Text(language),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  builder: (sheetContext) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final value in ['English', 'हिन्दी'])
                          ListTile(title: Text(value), onTap: () => Navigator.pop(sheetContext, value)),
                      ],
                    ),
                  ),
                );
                if (selected != null) setState(() => language = selected);
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Terms & Privacy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const LegalPolicyScreen(),
              )),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('About DarkVibeX'),
              subtitle: Text('Free social voice-room app'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Text('Notification and language choices apply on this device while the app is open.'),
            ),
          ],
        ),
      );
}
