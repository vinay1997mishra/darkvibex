import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_state.dart';
import '../i18n/darkvibex_localization.dart';
import '../ui/tinni_style.dart';
import 'cosmetics_shop_screen.dart';
import 'profile_screen.dart';

class MessageNotificationScreen extends StatefulWidget {
  const MessageNotificationScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MessageNotificationScreen> createState() =>
      _MessageNotificationScreenState();
}

class _MessageNotificationScreenState extends State<MessageNotificationScreen> {
  bool roomNotifications = true;
  bool messageNotifications = true;
  bool voice = true;
  bool vibration = true;
  bool floatingRoomOnly = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      roomNotifications =
          prefs.getBool('dvx.notifications.rooms') ?? true;
      messageNotifications =
          prefs.getBool('dvx.notifications.messages') ?? true;
      voice = prefs.getBool('dvx.notifications.voice') ?? true;
      vibration = prefs.getBool('dvx.notifications.vibration') ?? true;
      floatingRoomOnly =
          prefs.getBool('dvx.notifications.floating_room_only') ?? false;
      loading = false;
    });
  }

  Future<void> _set(String key, bool value, VoidCallback apply) async {
    apply();
    await (await SharedPreferences.getInstance()).setBool(key, value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Message notification')),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    TinniPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Message notification'),
                            subtitle:
                                const Text('Private chat and inbox alerts'),
                            value: messageNotifications,
                            onChanged: (value) => _set(
                              'dvx.notifications.messages',
                              value,
                              () => setState(
                                () => messageNotifications = value,
                              ),
                            ),
                          ),
                          SwitchListTile(
                            title: const Text('Room notifications'),
                            subtitle:
                                const Text('Room activity and invitations'),
                            value: roomNotifications,
                            onChanged: (value) => _set(
                              'dvx.notifications.rooms',
                              value,
                              () => setState(() => roomNotifications = value),
                            ),
                          ),
                          SwitchListTile(
                            title: const Text('Voice'),
                            subtitle: const Text('Notification sound'),
                            value: voice,
                            onChanged: (value) => _set(
                              'dvx.notifications.voice',
                              value,
                              () => setState(() => voice = value),
                            ),
                          ),
                          SwitchListTile(
                            title: const Text('Vibration'),
                            value: vibration,
                            onChanged: (value) => _set(
                              'dvx.notifications.vibration',
                              value,
                              () => setState(() => vibration = value),
                            ),
                          ),
                          SwitchListTile(
                            title: const Text(
                              'Only receive floating screen in the room',
                            ),
                            value: floatingRoomOnly,
                            onChanged: (value) => _set(
                              'dvx.notifications.floating_room_only',
                              value,
                              () => setState(() => floatingRoomOnly = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      );
}

class BindAccountScreen extends StatefulWidget {
  const BindAccountScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BindAccountScreen> createState() => _BindAccountScreenState();
}

class _BindAccountScreenState extends State<BindAccountScreen> {
  bool busy = false;

  Future<void> _bindGoogle() async {
    if (busy) return;
    setState(() => busy = true);
    final ok = await widget.state.bindGoogleAccount();
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Google account linked to ID ${widget.state.userId}'
              : widget.state.authError ?? 'Google account could not be linked',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Bind account')),
        body: TinniBackground(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              TinniPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DarkVibeX ID',
                      style: TextStyle(color: TinniPalette.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.state.userId,
                      style: const TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.state.authProvider == 'google'
                          ? 'Google account linked'
                          : 'Guest account',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Binding Google keeps this same DarkVibeX ID and profile.',
                      style: TextStyle(
                        color: TinniPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.state.authProvider == 'google' || busy
                    ? null
                    : _bindGoogle,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.account_circle_rounded),
                label: Text(
                  widget.state.authProvider == 'google'
                      ? 'Google linked'
                      : 'Bind Google account',
                ),
              ),
            ],
          ),
        ),
      );
}

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  late String selected;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selected = widget.state.languagePreference.value;
    if (!darkVibeXIsSupportedLanguage(selected)) selected = 'English';
  }

  Future<void> _select(String value) async {
    if (saving || value == selected) return;
    final old = selected;
    setState(() {
      selected = value;
      saving = true;
    });

    final ok = await widget.state.saveLanguagePreference(value);
    if (!mounted) return;
    setState(() {
      saving = false;
      if (!ok) selected = old;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Language preference saved: $value'
              : (widget.state.authError ??
                  'Language preference could not be saved'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('Language settings')),
        body: TinniBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              for (final value in darkVibeXSupportedLanguages)
                Card(
                  color: const Color(0xE60A0804),
                  child: RadioListTile<String>(
                    key: Key('language-' + value.toLowerCase()),
                    value: value,
                    groupValue: selected,
                    title: Text(
                      value,
                      style: TextStyle(
                        color: selected == value
                            ? TinniPalette.gold
                            : TinniPalette.cream,
                        fontWeight: selected == value
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                    secondary: saving && selected == value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onChanged: saving
                        ? null
                        : (next) {
                            if (next != null) _select(next);
                          },
                  ),
                ),
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'This language is saved to your DarkVibeX account. '
                  'Create ID and Settings use the same language list. '
                  'User names, room text, chat and numeric IDs are not auto-translated.',
                  style: TextStyle(
                    color: TinniPalette.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class AboutDarkVibeXScreen extends StatelessWidget {
  const AboutDarkVibeXScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(title: const Text('About DarkVibeX')),
        body: TinniBackground(
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              TinniPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DarkVibeX',
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Social voice rooms, live room controls, messaging, Family, CP, gifts, games, VIP, wallet and profile features.',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'BD, Agency, Host, Guardian and country-specific modules are intentionally not part of DarkVibeX.',
                      style: TextStyle(
                        color: TinniPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class BlocklistScreen extends StatefulWidget {
  const BlocklistScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  bool loading = true;
  List<Map<String, dynamic>> rows = const [];
  final Set<String> busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values =
        await widget.state.backend.blockedUsers(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      rows = values;
      loading = false;
    });
  }

  Future<void> _unblock(String userId) async {
    if (busy.contains(userId)) return;
    setState(() => busy.add(userId));
    final ok = await widget.state.backend.setUserBlocked(
      userId: widget.state.userId,
      targetUserId: userId,
      blocked: false,
    );
    if (!mounted) return;
    setState(() => busy.remove(userId));
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(
          title: const Text('Blocklist'),
          actions: [
            IconButton(
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
                  ? const Center(child: Text('No blocked users'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final id = row['user_id']?.toString() ?? '';
                        final avatar = row['avatar_key']?.toString() ?? '';
                        return Card(
                          color: const Color(0xE60A0804),
                          child: ListTile(
                            onTap: id.isEmpty
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PublicProfileScreen(
                                          state: widget.state,
                                          userId: id,
                                        ),
                                      ),
                                    ),
                            leading: CircleAvatar(
                              backgroundImage: avatar.isEmpty
                                  ? null
                                  : NetworkImage(
                                      widget.state.backend.fileUrl(avatar),
                                      headers:
                                          widget.state.backend.fileHeaders,
                                    ),
                              child: avatar.isEmpty
                                  ? const Icon(Icons.person_rounded)
                                  : null,
                            ),
                            title: Text(
                              row['display_name']?.toString() ?? 'User',
                            ),
                            subtitle: Text('ID $id'),
                            trailing: TextButton(
                              onPressed: id.isEmpty || busy.contains(id)
                                  ? null
                                  : () => _unblock(id),
                              child: const Text('Unblock'),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      );
}

class PropsScreen extends StatefulWidget {
  const PropsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<PropsScreen> createState() => _PropsScreenState();
}

class _PropsScreenState extends State<PropsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> items = const [];
  List<Map<String, dynamic>> owned = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await widget.state.backend.cosmetics(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      items = (result?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      owned = (result?['owned'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      loading = false;
    });
  }

  Map<String, dynamic>? _item(String id) {
    for (final row in items) {
      if (row['id']?.toString() == id) return row;
    }
    return null;
  }

  Future<void> _equip(String id) async {
    final result = await widget.state.backend.equipCosmetic(
      userId: widget.state.userId,
      itemId: id,
    );
    if (result?['ok'] == true) {
      await widget.state.refreshCosmetics();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TinniPalette.black,
        appBar: AppBar(
          title: const Text('Props'),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CosmeticsShopScreen(state: widget.state),
                    ),
                  )
                  .then((_) => _load()),
              icon: const Icon(Icons.storefront_rounded),
              tooltip: 'Shop',
            ),
          ],
        ),
        body: TinniBackground(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : owned.isEmpty
                  ? const Center(child: Text('No owned props yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: owned.length,
                      itemBuilder: (context, index) {
                        final row = owned[index];
                        final id = row['item_id']?.toString() ?? '';
                        final item = _item(id);
                        final active = row['active'] == true ||
                            row['active']?.toString() == '1';
                        return Card(
                          color: const Color(0xE60A0804),
                          child: ListTile(
                            leading: const TinniGlowIcon(
                              icon: Icons.auto_awesome_rounded,
                              size: 19,
                              boxSize: 36,
                            ),
                            title: Text(item?['name']?.toString() ?? id),
                            subtitle: Text(
                              '${row['kind'] ?? item?['kind'] ?? 'prop'}'
                              '${row['expires_at'] == null ? '' : ' • owned'}',
                            ),
                            trailing: active
                                ? const Chip(label: Text('Using'))
                                : TextButton(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _equip(id),
                                    child: const Text('Use'),
                                  ),
                          ),
                        );
                      },
                    ),
        ),
      );
}
