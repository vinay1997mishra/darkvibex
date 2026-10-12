import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_state.dart';
import 'legal_policy_screen.dart';
import 'mine_feature_screen.dart';

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
  bool loaded = false;
  bool linking = false;
  List<Map<String, dynamic>> identities = const [];

  String get _prefix => 'darkvibex.${widget.state.userId}.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final linked = await widget.state.backend.mineIdentities(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      identities = linked;
      roomNotifications = prefs.getBool('${_prefix}room_notifications') ?? true;
      messageNotifications = prefs.getBool('${_prefix}message_notifications') ?? true;
      language = prefs.getString('${_prefix}language') ?? 'English';
      loaded = true;
    });
  }

  Future<void> _save(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool('$_prefix$key', value);
    if (value is String) await prefs.setString('$_prefix$key', value);
  }

  bool get _googleLinked => identities.any((row) => row['provider']?.toString() == 'google');

  Future<void> _linkGoogle() async {
    if (_googleLinked || linking) return;
    setState(() => linking = true);
    final ok = await widget.state.linkGoogleAccount();
    final linked = await widget.state.backend.mineIdentities(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      linking = false;
      identities = linked;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Google account linked' : 'Google account could not be linked'),
    ));
  }

  Future<void> _openMine(String kind) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MineFeatureScreen(state: widget.state, kind: kind),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const ListTile(
                    title: Text('App settings', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('DarkVibeX account and preferences'),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Room notifications'),
                    value: roomNotifications,
                    onChanged: (value) {
                      setState(() => roomNotifications = value);
                      _save('room_notifications', value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.mark_chat_unread_outlined),
                    title: const Text('Message notifications'),
                    value: messageNotifications,
                    onChanged: (value) {
                      setState(() => messageNotifications = value);
                      _save('message_notifications', value);
                    },
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
                      if (selected != null) {
                        setState(() => language = selected);
                        await _save('language', selected);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.link_rounded),
                    title: const Text('Bind Google account'),
                    subtitle: Text(_googleLinked
                        ? 'Google identity linked'
                        : widget.state.authProvider == 'google'
                            ? 'Google sign-in account'
                            : linking ? 'Connecting…' : 'Link Google sign-in for account recovery'),
                    trailing: _googleLinked ? const Icon(Icons.check_circle_outline_rounded) : const Icon(Icons.chevron_right_rounded),
                    onTap: _googleLinked || linking ? null : _linkGoogle,
                  ),
                  ListTile(
                    leading: const Icon(Icons.block_rounded),
                    title: const Text('Blacklist'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openMine('Blacklist'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: const Text('Feedback'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openMine('Feedback'),
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
                    child: Text('Preferences are saved on this device. Notification switches store your choice; push delivery depends on app notification service support.'),
                  ),
                ],
              ),
      );
}
