import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import 'vip_screen.dart';
import 'legal_policy_screen.dart';
import 'app_settings_screen.dart';
import 'wallet_screen.dart';
import 'coin_seller_screen.dart';
import 'vip_support_screen.dart';
import 'cosmetics_shop_screen.dart';
import 'id_level_screen.dart';
import '../widgets/vip_animated_frame.dart';
import '../infra/privacy_screen_protection.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  Future<void> _showFriends(BuildContext context) async {
    final friends = await state.backend.friends(userId: state.userId);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .65,
          child: friends.isEmpty
              ? const Center(child: Text('No friends yet'))
              : ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final id = friend['id']?.toString() ?? '';
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                      title: Text(friend['display_name']?.toString() ?? 'User'),
                      subtitle: Text('ID $id'),
                      trailing: IconButton(
                        tooltip: 'Remove friend',
                        icon: const Icon(Icons.person_remove_alt_1_rounded),
                        onPressed: () async {
                          final ok = await state.backend.removeFriend(userId: state.userId, friendUserId: id);
                          if (!sheetContext.mounted) return;
                          if (ok) Navigator.pop(sheetContext);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _showVisitors(BuildContext context) async {
    if (!state.hasVipPrivilege('view_visitors')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Active VIP1 unlocks profile visitors')));
      return;
    }
    final visitors = await state.backend.profileVisitors(userId: state.userId);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .6,
          child: visitors.isEmpty
              ? const Center(child: Text('No visitors yet'))
              : ListView.builder(
                  itemCount: visitors.length,
                  itemBuilder: (context, index) {
                    final visitor = visitors[index];
                    final name = visitor['display_name']?.toString() ?? 'User';
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                      title: Text(name),
                      subtitle: Text('Visited ${visitor['visit_count'] ?? 1} times'),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    final type = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
    if (type == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPG, PNG or WebP image')),
        );
      }
      return;
    }
    final key = await state.backend.uploadImage(
      key: 'users/${state.userId}/avatar-${DateTime.now().microsecondsSinceEpoch}.${ext == 'jpeg' ? 'jpg' : ext}',
      bytes: await file.readAsBytes(),
      contentType: type,
    );
    if (key == null || !await state.backend.setUserAvatar(
      userId: state.userId,
      avatarKey: key,
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo could not be saved')),
        );
      }
      return;
    }
    state.setAvatarKey(key);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: state.hasVipPrivilege('card_background')
                  ? const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF35204F), Color(0xFF171326), Color(0xFF4C3419)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    )
                  : null,
              child: Row(
                children: [
              VipAnimatedFrame(
                size: 76,
                enabled: state.activeFrameId != null || state.hasVipPrivilege('dynamic_avatar'),
                styleId: state.activeFrameId,
                child: Container(
                  padding: EdgeInsets.all(state.hasVipPrivilege('headframe') ? 3 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: state.hasVipPrivilege('headframe')
                        ? Border.all(color: const Color(0xFFFFD36A), width: 2)
                        : null,
                    boxShadow: state.hasVipPrivilege('exclusive_mic_effect')
                        ? const [BoxShadow(color: Color(0x66FFD36A), blurRadius: 18, spreadRadius: 2)]
                        : null,
                  ),
                  child: CircleAvatar(
                    backgroundImage: state.avatarKey == null ? null : NetworkImage(state.backend.fileUrl(state.avatarKey!), headers: state.backend.fileHeaders),
                    child: state.avatarKey == null ? const Icon(Icons.person_rounded, size: 40) : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.vipAnonymousEverywhere ? 'Anonymous' : state.displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: state.hasVipPrivilege('nickname_light')
                            ? const Color(0xFFFFD36A)
                            : null,
                      ),
                    ),
                    Text(
                      'ID ${state.customVipId?.isNotEmpty == true ? state.customVipId : state.userId} • Lv.${state.idLevel} • VIP ${state.vipLevel}/18',
                    ),
                    if (state.hasVipPrivilege('honorary_title'))
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.military_tech_rounded, size: 16, color: Color(0xFFFFD36A)),
                            SizedBox(width: 4),
                            Text('King of VIP', style: TextStyle(color: Color(0xFFFFD36A), fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
                  IconButton(onPressed: () => _pickAvatar(context), icon: const Icon(Icons.edit_rounded)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: const Text('Wallet'),
                  subtitle: Text('${state.coins} coins • ${state.diamonds} diamonds'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => WalletScreen(state: state),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_rounded),
                  title: const Text('Coin Seller'),
                  subtitle: const Text('Coin seller tools'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => CoinSellerScreen(state: state),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded),
                  title: const Text('VIP'),
                  subtitle: Text('Level ${state.vipLevel}/18'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => VipScreen(state: state),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD88A)),
                  title: const Text('ID Level'),
                  subtitle: Text('Level ${state.idLevel} • ${state.idLevelExp}/${state.idLevelExpToNext} EXP'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => IdLevelScreen(state: state),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt_rounded),
                  title: const Text('Friends'),
                  subtitle: const Text('300 without VIP • unlimited with active VIP'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showFriends(context),
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_rounded),
                  title: const Text('Profile visitors'),
                  subtitle: Text(state.hasVipPrivilege('view_visitors') ? 'See who viewed your profile' : 'Unlocks at VIP1'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showVisitors(context),
                ),
                if (state.hasVipPrivilege('customer_service'))
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded),
                    title: const Text('VIP Customer Service'),
                    subtitle: const Text('Create a private support ticket'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => VipSupportScreen(state: state))),
                  ),
                _item(context, state, Icons.badge_rounded, 'Unique ID', state.customVipId?.isNotEmpty == true ? state.customVipId! : state.userId),
                _item(context, state, Icons.family_restroom_rounded, 'Family', 'Community and rankings'),
                _item(context, state, Icons.favorite_rounded, 'CP', 'Relationship level and gifts'),
                _item(context, state, Icons.store_rounded, 'Store', 'Frames, vehicles and entry effects'),
                _item(context, state, Icons.security_rounded, 'Privacy & Safety', 'Block, report and controls'),
                _item(context, state, Icons.settings_rounded, 'Settings', 'Language, account and app settings'),
                _item(context, state, Icons.description_outlined, 'Terms & Privacy', 'Room rules, terms and privacy notice'),
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

  Widget _item(BuildContext context, AppState state, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        if (title == 'Settings') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const AppSettingsScreen(),
          ));
          return;
        }
        if (title == 'Terms & Privacy' || title == 'Privacy & Safety') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const LegalPolicyScreen(),
          ));
          return;
        }
        if (title == 'Unique ID') {
          final currentId = state.customVipId?.isNotEmpty == true
              ? state.customVipId!
              : state.userId;
          await Clipboard.setData(ClipboardData(text: currentId));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unique ID copied')),
          );
          return;
        }
        if (title == 'Store') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CosmeticsShopScreen(state: state),
          ));
          return;
        }
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text('$subtitle is not connected to the current DarkVibeX server yet.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.state, required this.userId});

  final AppState state;
  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final Object _privacyScope = Object();
  Map<String, dynamic>? user;
  bool loading = true;
  bool isFriend = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await widget.state.backend.userProfile(userId: widget.userId);
    final friends = await widget.state.backend.friends(userId: widget.state.userId);
    final friendStatus = friends.any((row) => row['id']?.toString() == widget.userId);
    if (!mounted) return;
    setState(() {
      user = response?['user'] is Map ? Map<String, dynamic>.from(response!['user'] as Map) : null;
      loading = false;
      isFriend = friendStatus;
    });
    await PrivacyScreenProtection.setProtected(
      _privacyScope,
      user?['privacy_protection_enabled'] == true,
    );
  }

  @override
  void dispose() {
    unawaited(PrivacyScreenProtection.setProtected(_privacyScope, false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?['display_name']?.toString() ?? '';
    return Scaffold(
        appBar: AppBar(title: Text(user?['display_name']?.toString() ?? 'Profile')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : user == null
                ? const Center(child: Text('Profile could not be loaded'))
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VipAnimatedFrame(
                          size: 88,
                          enabled: (int.tryParse(user!['active_vip_level']?.toString() ?? '') ?? 0) >= 7,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: user!['avatar_key']?.toString().isNotEmpty == true
                                ? NetworkImage(widget.state.backend.fileUrl(user!['avatar_key'].toString()), headers: widget.state.backend.fileHeaders)
                                : null,
                            child: user!['avatar_key']?.toString().isNotEmpty == true
                                ? null
                                : Text(displayName.isEmpty ? 'U' : displayName.substring(0, 1).toUpperCase()),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user!['display_name']?.toString() ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('ID ${user!['id']} • VIP ${user!['vip_level'] ?? 0}/18'),
                        if ((int.tryParse(user!['active_vip_level']?.toString() ?? user!['vip_level']?.toString() ?? '') ?? 0) >= 18)
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.military_tech_rounded, size: 16, color: Color(0xFFFFD36A)),
                              SizedBox(width: 4),
                              Text('King of VIP', style: TextStyle(color: Color(0xFFFFD36A), fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        if (widget.userId != widget.state.userId)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: FilledButton.icon(
                              onPressed: isFriend ? null : _addFriend,
                              icon: Icon(isFriend ? Icons.check_rounded : Icons.person_add_alt_1_rounded),
                              label: Text(isFriend ? 'Friend' : 'Add friend'),
                            ),
                          ),
                        if (widget.state.hasVipPrivilege('free_say_hi'))
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: FilledButton.icon(
                              onPressed: widget.state.vipFreeSayHiRemaining > 0
                                  ? () => _sayHi(context)
                                  : null,
                              icon: const Icon(Icons.waving_hand_rounded),
                              label: Text('Free Say Hi (${widget.state.vipFreeSayHiRemaining} left)'),
                            ),
                          ),
                      ],
                    ),
                  ),
      );
  }

  Future<void> _addFriend() async {
    final result = await widget.state.backend.addFriend(userId: widget.state.userId, friendUserId: widget.userId);
    if (!mounted) return;
    if (result?['ok'] == true) {
      setState(() => isFriend = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend added')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add friend. The 300-friend base limit may be full.')));
    }
  }

  Future<void> _sayHi(BuildContext context) async {
    final input = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Free Say Hi'),
        content: TextField(controller: input, maxLength: 300, maxLines: 3, decoration: const InputDecoration(hintText: 'Up to 30 words')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, input.text.trim()), child: const Text('Send')),
        ],
      ),
    );
    input.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    final ok = await widget.state.sendVipSayHi(receiverUserId: widget.userId, message: text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Free Say Hi sent' : widget.state.vipError ?? 'Could not send Say Hi')));
    setState(() {});
  }
}
