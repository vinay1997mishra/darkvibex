import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../call/call_ringtone.dart';
import '../ui/tinni_style.dart';

/// Call settings (Vinay, 2026-11-21): mute ALL incoming calls, mute
/// calls from SELECTED persons, and pick the caller tune that rings
/// on an incoming unmuted call. Everything is stored server-side so
/// it survives reinstall. A muted call never rings and never
/// notifies the receiver.
class CallSettingsScreen extends StatefulWidget {
  const CallSettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CallSettingsScreen> createState() => _CallSettingsScreenState();
}

class _CallSettingsScreenState extends State<CallSettingsScreen> {
  AppState get state => widget.state;

  final CallRingtonePlayer _player = CallRingtonePlayer();
  List<Map<String, dynamic>> mutedUsers = const [];
  bool loading = true;
  String? previewingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await state.refreshCallSettings(notify: false);
    final users = await state.backend.mutedCallUsers(userId: state.userId);
    if (!mounted) return;
    setState(() {
      mutedUsers = users;
      loading = false;
    });
  }

  Future<void> _setMuteAll(bool value) async {
    setState(() => state.callMuteAll = value);
    final ok = await state.setCallMuteAll(value);
    if (!mounted) return;
    if (!ok) {
      setState(() => state.callMuteAll = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call mute setting could not be saved')),
      );
    } else {
      setState(() {});
    }
  }

  Future<void> _selectRingtone(String id) async {
    setState(() => previewingId = id);
    await _player.preview(id);
    final ok = await state.setCallRingtone(id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ringtone could not be saved')),
      );
    }
    setState(() => previewingId = null);
  }

  Future<void> _unmuteUser(String otherUserId) async {
    final ok = await state.unmuteCallUser(otherUserId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not unmute calls from this user')),
      );
      return;
    }
    final users = await state.backend.mutedCallUsers(userId: state.userId);
    if (!mounted) return;
    setState(() => mutedUsers = users);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Call settings')),
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
                            key: const Key('call-mute-all'),
                            title: const Text('Mute all calls'),
                            subtitle: const Text(
                              'No incoming call rings or notifies you.',
                            ),
                            value: state.callMuteAll,
                            onChanged: _setMuteAll,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TinniPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ListTile(
                            title: Text(
                              'Muted people',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              'Calls from these people never ring or notify you.',
                            ),
                          ),
                          if (mutedUsers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                'Nobody muted. Mute a person from their chat or profile.',
                                style: TextStyle(color: TinniPalette.muted),
                              ),
                            )
                          else
                            for (final user in mutedUsers)
                              ListTile(
                                key: Key(
                                  'call-muted-user-${user['id']?.toString() ?? ''}',
                                ),
                                leading: const Icon(
                                  Icons.volume_off_rounded,
                                  color: TinniPalette.gold,
                                ),
                                title: Text(
                                  user['display_name']?.toString() ?? 'User',
                                ),
                                subtitle: Text(
                                  user['public_id']?.toString() ?? '',
                                ),
                                trailing: TextButton(
                                  onPressed: () => _unmuteUser(
                                    user['id']?.toString() ?? '',
                                  ),
                                  child: const Text('Unmute'),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TinniPanel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ListTile(
                            title: Text(
                              'Ringtone',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              'This tune rings when a call comes in.',
                            ),
                          ),
                          for (final tone in callRingtones)
                            ListTile(
                              key: Key('call-ringtone-${tone.id}'),
                              leading: Icon(
                                state.callRingtoneId == tone.id
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: TinniPalette.gold,
                              ),
                              title: Text(tone.name),
                              trailing: previewingId == tone.id
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow_rounded),
                              onTap: () => _selectRingtone(tone.id),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
