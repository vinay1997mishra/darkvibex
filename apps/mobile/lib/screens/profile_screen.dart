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
import 'games_screen.dart';
import '../widgets/vip_animated_frame.dart';
import '../infra/privacy_screen_protection.dart';
import '../ui/tinni_style.dart';

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
      builder: (context, _) => TinniBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
          children: [
            TinniPanel(
              onTap: () {},
              child: Row(
                children: [
                  VipAnimatedFrame(
                    size: 72,
                    enabled: state.activeFrameId != null ||
                        state.hasVipPrivilege('dynamic_avatar'),
                    styleId: state.activeFrameId,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TinniPalette.brightGold,
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: TinniPalette.panel2,
                        backgroundImage: state.avatarKey == null
                            ? null
                            : NetworkImage(
                                state.backend.fileUrl(state.avatarKey!),
                                headers: state.backend.fileHeaders,
                              ),
                        child: state.avatarKey == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 34,
                                color: TinniPalette.gold,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.vipAnonymousEverywhere
                              ? 'Anonymous'
                              : state.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'UID: ${state.customVipId?.isNotEmpty == true ? state.customVipId : state.userId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TinniPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            _mineTag('Lv.${state.idLevel}'),
                            _mineTag('VIP ${state.vipLevel}'),
                            if (state.hasVipPrivilege('honorary_title'))
                              _mineTag('King of VIP'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _pickAvatar(context),
                    icon: const TinniGlowIcon(
                      icon: Icons.edit_rounded,
                      size: 17,
                      boxSize: 34,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                _mineCount('0', 'Follow'),
                const _MineDivider(),
                _mineCount('0', 'Fans'),
                const _MineDivider(),
                _mineCount(state.diamonds.toString(), 'Charm'),
                const _MineDivider(),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showVisitors(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            color: TinniPalette.gold,
                            size: 20,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Visitors',
                            style: TextStyle(
                              color: TinniPalette.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            TinniPanel(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WalletScreen(state: state),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: TinniPalette.gold,
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coins',
                        style: TextStyle(
                          color: TinniPalette.muted,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        state.coins.toString(),
                        style: const TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${state.diamonds} diamonds',
                        style: const TextStyle(
                          color: TinniPalette.muted,
                          fontSize: 10,
                        ),
                      ),
                      const Text(
                        'Wallet',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _mineStatusCard(
                    title: 'VIP',
                    subtitle: state.vipLevel > 0
                        ? 'VIP ${state.vipLevel}'
                        : 'Not obtained',
                    icon: Icons.workspace_premium_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => VipScreen(state: state),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _mineStatusCard(
                    title: 'ID Level',
                    subtitle: 'LV.${state.idLevel}',
                    icon: Icons.military_tech_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => IdLevelScreen(state: state),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _mineMenuGroup([
              ListTile(
                leading: const Icon(
                  Icons.people_alt_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Friends'),
                subtitle: const Text(
                  '300 without VIP • unlimited with active VIP',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showFriends(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Visitors'),
                subtitle: Text(
                  state.hasVipPrivilege('view_visitors')
                      ? 'See who viewed your profile'
                      : 'Unlocks at VIP1',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showVisitors(context),
              ),
              _item(
                context,
                state,
                Icons.badge_rounded,
                'Unique ID',
                state.customVipId?.isNotEmpty == true
                    ? state.customVipId!
                    : state.userId,
              ),
            ]),
            const SizedBox(height: 9),
            _mineMenuGroup([
              _item(
                context,
                state,
                Icons.store_rounded,
                'Store',
                'Frames, vehicles and entry effects',
              ),
              ListTile(
                leading: const Icon(
                  Icons.sports_esports_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Games'),
                subtitle: const Text('Game center'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => GamesScreen(state: state),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.storefront_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Coin Seller'),
                subtitle: const Text('Coin seller tools'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CoinSellerScreen(state: state),
                  ),
                ),
              ),
            ]),
            if (state.hasVipPrivilege('customer_service')) ...[
              const SizedBox(height: 9),
              _mineMenuGroup([
                ListTile(
                  leading: const Icon(
                    Icons.support_agent_rounded,
                    color: TinniPalette.gold,
                  ),
                  title: const Text('VIP Customer Service'),
                  subtitle: const Text('Create a private support ticket'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => VipSupportScreen(state: state),
                    ),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 9),
            _mineMenuGroup([
              _item(
                context,
                state,
                Icons.family_restroom_rounded,
                'Family',
                'Community and rankings',
              ),
              _item(
                context,
                state,
                Icons.favorite_rounded,
                'CP',
                'Relationship level and gifts',
              ),
              _item(
                context,
                state,
                Icons.security_rounded,
                'Privacy & Safety',
                'Block, report and controls',
              ),
            ]),
            const SizedBox(height: 9),
            _mineMenuGroup([
              _item(
                context,
                state,
                Icons.settings_rounded,
                'Settings',
                'Language, account and app settings',
              ),
              _item(
                context,
                state,
                Icons.description_outlined,
                'Terms & Privacy',
                'Room rules, terms and privacy notice',
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
            ]),
          ],
        ),
      ),
    );
  }

  Widget _mineCount(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: TinniPalette.gold,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: TinniPalette.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );

  Widget _mineTag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: TinniPalette.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TinniPalette.deepGold),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: TinniPalette.gold,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _mineStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      TinniPanel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: SizedBox(
          height: 45,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: TinniPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: TinniPalette.gold, size: 28),
            ],
          ),
        ),
      );

  Widget _mineMenuGroup(List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: const Color(0xE60A0804),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TinniPalette.bronze),
        ),
        child: Column(children: rows),
      );

  Widget _item(BuildContext context, AppState state, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: TinniPalette.gold),
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

class _MineDivider extends StatelessWidget {
  const _MineDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        color: TinniPalette.deepGold.withValues(alpha: .45),
      );
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
