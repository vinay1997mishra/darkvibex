import 'dart:convert';

import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../i18n/darkvibex_localization.dart';
import 'vip_screen.dart';
import 'app_settings_screen.dart';
import 'invite_share_screen.dart';
import 'recharge_screen.dart';
import 'cosmetics_shop_screen.dart';
import 'mine_social_screens.dart';
import 'conversation_screen.dart';
import 'direct_call_screen.dart';
import 'personal_profile_screen.dart';
import 'room_screen.dart';
import '../widgets/vip_animated_frame.dart';
import '../ui/tinni_style.dart';
import '../widgets/cosmetic_store_previews.dart';
import '../ui/intimacy_vs_art_b64.dart';
import '../ui/intimacy_cp_art_b64.dart';

final _intimacyVsArtBytes = base64Decode(intimacyVsArtBase64);
final _intimacyCpArtBytes = base64Decode(intimacyCpArtBase64);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppState get state => widget.state;
  Map<String, dynamic> socialStats = const <String, dynamic>{};
  Map<String, dynamic>? vsRelation;

  @override
  void initState() {
    super.initState();
    _loadSocialStats();
  }

  Future<void> _loadSocialStats() async {
    final results = await Future.wait<Map<String, dynamic>?>([
      state.backend.socialStats(userId: state.userId),
      state.backend.vsState(userId: state.userId),
    ]);
    final rawStats = results[0]?['stats'];
    final rawVs = results[1]?['vs'];
    if (!mounted) return;
    setState(() {
      socialStats = rawStats is Map
          ? Map<String, dynamic>.from(rawStats)
          : const <String, dynamic>{};
      vsRelation =
          rawVs is Map ? Map<String, dynamic>.from(rawVs) : null;
    });
  }

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
                  itemBuilder: (itemContext, index) {
                    final friend = friends[index];
                    final id = friend['id']?.toString() ?? '';
                    final avatarKey = friend['avatar_key']?.toString() ?? '';
                    final name = friend['display_name']?.toString() ?? 'User';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: avatarKey.isEmpty
                            ? null
                            : NetworkImage(
                                state.backend.fileUrl(avatarKey),
                                headers: state.backend.fileHeaders,
                              ),
                        child: avatarKey.isEmpty
                            ? const Icon(Icons.person_rounded)
                            : null,
                      ),
                      title: Text(name),
                      subtitle: Text('ID $id'),
                      onTap: id.isEmpty
                          ? null
                          : () => Navigator.of(sheetContext).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PublicProfileScreen(
                                    state: state,
                                    userId: id,
                                  ),
                                ),
                              ),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            key: Key('friend-call-$id'),
                            tooltip: 'Voice call',
                            icon: const Icon(
                              Icons.call_rounded,
                              color: TinniPalette.gold,
                            ),
                            onPressed: id.isEmpty
                                ? null
                                : () async {
                                    final value =
                                        await state.backend.startDirectCall(
                                      userId: state.userId,
                                      receiverUserId: id,
                                    );
                                    if (!sheetContext.mounted) return;
                                    final raw = value?['call'];
                                    if (raw is! Map) {
                                      ScaffoldMessenger.of(sheetContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            value?['error']
                                                    ?.toString()
                                                    .replaceAll('_', ' ') ??
                                                'Call could not be started.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final call =
                                        Map<String, dynamic>.from(raw);
                                    await Navigator.of(sheetContext).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => DirectCallScreen(
                                          state: state,
                                          callId:
                                              call['id']?.toString() ?? '',
                                          peerName: name,
                                          initialState:
                                              call['state']?.toString() ??
                                                  'ringing',
                                        ),
                                      ),
                                    );
                                  },
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Friend options',
                            onSelected: (value) async {
                              if (value != 'remove') return;
                              final ok = await state.backend.removeFriend(
                                userId: state.userId,
                                friendUserId: id,
                              );
                              if (!sheetContext.mounted) return;
                              if (ok) Navigator.pop(sheetContext);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'remove',
                                child: Text('Remove friend'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _showPeopleList(
    BuildContext context, {
    required String title,
    required Future<List<Map<String, dynamic>>> Function() load,
  }) async {
    final following = title.toLowerCase().startsWith('following');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SocialPeopleListScreen(
          state: state,
          following: following,
        ),
      ),
    );
    if (mounted) await _loadSocialStats();
  }

  Future<void> _showVisitors(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VisitorsListScreen(state: state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ringId = state.activeCosmetic('ring');
    final profileCardId = state.activeCosmetic('profile_card');
    final profileBackgroundId = state.activeCosmetic('profile_background');
    return ValueListenableBuilder<String>(
      valueListenable: state.languagePreference,
      builder: (context, language, _) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => TinniBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
          children: [
            InkWell(
              key: const Key('mine-profile-card'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(
                    state: state,
                    userId: state.userId,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: profileBackgroundId != null ||
                          profileCardId != null
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xFF281230),
                            Color(0xFF0E0A11),
                            Color(0xFF301E0A),
                          ],
                        )
                      : null,
                  color: profileBackgroundId == null &&
                          profileCardId == null
                      ? TinniPalette.panel
                      : null,
                  border: Border.all(
                    color: profileCardId != null
                        ? const Color(0xFFFFD36A)
                        : TinniPalette.bronze,
                    width: profileCardId != null ? 1.6 : 1,
                  ),
                  boxShadow: profileCardId != null
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x44FFD36A),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                children: [
                  VipAnimatedFrame(
                    size: 72,
                    enabled: state.activeFrameId != null ||
                        state.hasVipPrivilege('dynamic_avatar'),
                    styleId: state.activeFrameId,
                    child: Container(
                      padding: EdgeInsets.all(ringId == null ? 2 : 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ringId == null
                            ? null
                            : const SweepGradient(
                                colors: <Color>[
                                  Color(0xFFFFE47A),
                                  Color(0xFFFF6FB7),
                                  Color(0xFF8C6CFF),
                                  Color(0xFFFFE47A),
                                ],
                              ),
                        border: ringId == null
                            ? Border.all(
                                color: TinniPalette.brightGold,
                                width: 1.5,
                              )
                            : null,
                        boxShadow: ringId == null
                            ? null
                            : const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x66FFB5F1),
                                  blurRadius: 12,
                                ),
                              ],
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
                          'ID: ${state.publicId}',
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
                    key: const Key('mine-edit-profile'),
                    onPressed: () => Navigator.of(context)
                        .push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PersonalProfileScreen(state: state),
                          ),
                        )
                        .then((_) => _loadSocialStats()),
                    icon: const TinniGlowIcon(
                      icon: Icons.edit_rounded,
                      size: 17,
                      boxSize: 34,
                    ),
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                _mineCount(
                  (socialStats['following_count'] ?? 0).toString(),
                  darkVibeXText(language, 'follow'),
                  onTap: () => _showPeopleList(
                    context,
                    title: 'Followings',
                    load: () => state.backend.following(
                      userId: state.userId,
                    ),
                  ),
                ),
                const _MineDivider(),
                _mineCount(
                  (socialStats['followers_count'] ?? 0).toString(),
                  darkVibeXText(language, 'fans'),
                  onTap: () => _showPeopleList(
                    context,
                    title: 'Followers',
                    load: () => state.backend.followers(
                      userId: state.userId,
                    ),
                  ),
                ),
                const _MineDivider(),
                _mineCount(
                  (socialStats['lifetime_received_coins'] ?? 0).toString(),
                  darkVibeXText(language, 'charm'),
                ),
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
                  builder: (_) => RechargeScreen(state: state),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0804),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TinniPalette.deepGold),
                        ),
                        child: const Text(
                          'First Recharge',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        darkVibeXText(language, 'wallet'),
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
            TinniPanel(
              key: const Key('mine-friends-calls'),
              onTap: () => _showFriends(context),
              child: const Row(
                children: [
                  TinniGlowIcon(
                    icon: Icons.call_rounded,
                    size: 27,
                    boxSize: 52,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Friends & Calls',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Only mutual friends can call each other',
                          style: TextStyle(
                            color: TinniPalette.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: TinniPalette.gold,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TinniPanel(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => VsScreen(state: state),
                ),
              ).then((_) => _loadSocialStats()),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFFF202D),
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VS',
                          style: TextStyle(
                            color: Color(0xFFFF202D),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          vsRelation == null
                              ? 'Not connected'
                              : 'Lv.${vsRelation?['level'] ?? 1} • ${vsRelation?['state'] ?? 'pending'}',
                          style: const TextStyle(
                            color: TinniPalette.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFFF202D),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TinniPanel(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CpScreen(state: state),
                ),
              ),
              child: const Row(
                children: [
                  TinniGlowIcon(
                    icon: Icons.favorite_rounded,
                    size: 28,
                    boxSize: 52,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My CP',
                          style: TextStyle(
                            color: TinniPalette.gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'CP Nest • intimacy • memories • details',
                          style: TextStyle(
                            color: TinniPalette.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: TinniPalette.gold,
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
                    title: darkVibeXText(language, 'wealth_level'),
                    subtitle:
                        'LV.${((socialStats['wealth'] is Map ? (socialStats['wealth'] as Map)['level'] : 0) ?? 0)}',
                    icon: Icons.diamond_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => WealthLevelScreen(state: state),
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
                  Icons.hexagon_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text(darkVibeXText(language, 'medal_of_honor')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MedalOfHonorScreen(state: state),
                  ),
                ),
              ),
              _item(
                context,
                state,
                Icons.shopping_bag_rounded,
                darkVibeXText(language, 'shop'),
                'Frames, vehicles and entry effects',
              ),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text(darkVibeXText(language, 'trends')),
                subtitle: const Text(
                  'Profile posts and updates',
                  style: TextStyle(
                    color: TinniPalette.muted,
                    fontSize: 10,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TrendsScreen(state: state),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 9),
            _mineMenuGroup([
              ListTile(
                leading: const Icon(
                  Icons.task_alt_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text(darkVibeXText(language, 'task')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TaskScreen(state: state),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 9),
            _mineMenuGroup([
              ListTile(
                leading: const Icon(
                  Icons.home_work_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text(darkVibeXText(language, 'family')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FamilyScreen(state: state),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.favorite_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text(darkVibeXText(language, 'cp_nest')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CpScreen(state: state),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 9),
            _mineMenuGroup([
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_rounded,
                  color: TinniPalette.gold,
                ),
                title: Text(darkVibeXText(language, 'feedback')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FeedbackScreen(state: state),
                  ),
                ),
              ),
              ListTile(
                key: const Key('mine-invite-share'),
                leading: const Icon(
                  Icons.card_giftcard_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Invite & Share'),
                subtitle: const Text(
                  'Invite friends and earn Coin Seller recharge commission',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => InviteShareScreen(state: state),
                  ),
                ),
              ),
              _item(
                context,
                state,
                Icons.settings_rounded,
                darkVibeXText(language, 'setting'),
                'Language, account, privacy and app settings',
              ),
            ]),
          ],
        ),
      ),
    ),
    );
  }

  Widget _mineCount(
    String value,
    String label, {
    VoidCallback? onTap,
  }) =>
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
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
          ),
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
        if (title == 'Setting') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => AppSettingsScreen(state: state),
          ));
          return;
        }
        if (title == 'Shop') {
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


class _SocialPeopleListScreen extends StatefulWidget {
  const _SocialPeopleListScreen({
    required this.state,
    required this.following,
  });

  final AppState state;
  final bool following;

  @override
  State<_SocialPeopleListScreen> createState() =>
      _SocialPeopleListScreenState();
}

class _SocialPeopleListScreenState extends State<_SocialPeopleListScreen> {
  bool loading = true;
  List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  String get title => widget.following ? 'Followings' : 'Followers';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = widget.following
        ? await widget.state.backend.following(userId: widget.state.userId)
        : await widget.state.backend.followers(userId: widget.state.userId);
    if (!mounted) return;
    setState(() {
      rows = result;
      loading = false;
    });
  }

  ImageProvider<Object>? _avatar(String key) {
    final value = key.trim();
    if (value.isEmpty) return null;
    return NetworkImage(
      widget.state.backend.fileUrl(value),
      headers: widget.state.backend.fileHeaders,
    );
  }

  Future<void> _unfollow(Map<String, dynamic> row) async {
    if (!widget.following) return;
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await widget.state.backend.setUserFollow(
      userId: widget.state.userId,
      targetUserId: id,
      follow: false,
    );
    if (!mounted || !ok) return;
    setState(() => rows.removeWhere((item) => item['id']?.toString() == id));
  }

  void _openProfile(String id) {
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          state: widget.state,
          userId: id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xCCF4E8FE),
      appBar: AppBar(
        backgroundColor: const Color(0xCCF4E8FE),
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: Text(title),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? Center(
                  child: Text(
                    widget.following
                        ? 'No followings yet'
                        : 'No followers yet',
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 82,
                    color: Color(0xFFE9E9E9),
                  ),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final id = row['id']?.toString() ?? '';
                    final name = row['display_name']?.toString().trim();
                    final avatarKey = row['avatar_key']?.toString() ?? '';
                    final mutual = row['mutual'] == true ||
                        row['mutual']?.toString() == '1';
                    return SizedBox(
                      height: 74,
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => _openProfile(id),
                            child: CircleAvatar(
                              radius: 27,
                              backgroundColor: const Color(0xFFF0F0F0),
                              backgroundImage: _avatar(avatarKey),
                              child: avatarKey.isEmpty
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: Colors.black45,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name == null || name.isEmpty ? 'User' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (mutual && widget.following)
                            Padding(
                              padding: const EdgeInsets.only(right: 18),
                              child: TextButton(
                                onPressed: () => _unfollow(row),
                                child: const Text(
                                  'Mutual Friend',
                                  style: TextStyle(
                                    color: Color(0xFFF14A8B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          else if (mutual)
                            const Padding(
                              padding: EdgeInsets.only(right: 18),
                              child: Text(
                                'Mutual Friend',
                                style: TextStyle(
                                  color: Colors.black45,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (widget.following)
                            Padding(
                              padding: const EdgeInsets.only(right: 18),
                              child: TextButton(
                                onPressed: () => _unfollow(row),
                                child: const Text(
                                  'Followed',
                                  style: TextStyle(
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 18),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _VisitorsListScreen extends StatefulWidget {
  const _VisitorsListScreen({required this.state});

  final AppState state;

  @override
  State<_VisitorsListScreen> createState() => _VisitorsListScreenState();
}

class _VisitorsListScreenState extends State<_VisitorsListScreen> {
  bool loading = true;
  List<Map<String, dynamic>> visitors = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.state.backend.profileVisitors(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() {
      visitors = rows;
      loading = false;
    });
  }

  DateTime? _visitDate(dynamic raw) {
    final number = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (number != null && number > 0) {
      final millis = number < 100000000000 ? number * 1000 : number;
      return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    }
    return DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  }

  String _time(DateTime? value) {
    if (value == null) return '';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    const months = <String>[
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]}';
  }

  ImageProvider<Object>? _avatar(String key) {
    final value = key.trim();
    if (value.isEmpty) return null;
    return NetworkImage(
      widget.state.backend.fileUrl(value),
      headers: widget.state.backend.fileHeaders,
    );
  }

  void _open(String id) {
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          state: widget.state,
          userId: id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xCCF4E8FE),
      appBar: AppBar(
        backgroundColor: const Color(0xCCF4E8FE),
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: const Text('Visitors'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : visitors.isEmpty
              ? const Center(
                  child: Text(
                    'No visitors yet',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visitors.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 82,
                    color: Color(0xFFE9E9E9),
                  ),
                  itemBuilder: (context, index) {
                    final row = visitors[index];
                    final id = row['user_id']?.toString() ?? '';
                    final name = row['display_name']?.toString().trim();
                    final avatarKey = row['avatar_key']?.toString() ?? '';
                    final visit = _visitDate(row['last_visited_at']);
                    return SizedBox(
                      height: 74,
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: () => _open(id),
                            child: CircleAvatar(
                              radius: 27,
                              backgroundColor: const Color(0xFFF0F0F0),
                              backgroundImage: _avatar(avatarKey),
                              child: avatarKey.isEmpty
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: Colors.black45,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name == null || name.isEmpty ? 'User' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 18),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _time(visit),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _date(visit),
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.state,
    required this.userId,
  });

  final AppState state;
  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? user;
  Map<String, dynamic> socialStats = const <String, dynamic>{};
  Map<String, dynamic> idLevel = const <String, dynamic>{};
  List<Map<String, dynamic>> medals = const <Map<String, dynamic>>[];
  Map<String, dynamic>? cp;
  Map<String, dynamic>? vs;
  Map<String, dynamic>? currentRoom;
  Map<String, dynamic> intimacyCards = const <String, dynamic>{};
  bool loading = true;
  bool isFollowing = false;
  bool isMutual = false;
  bool followBusy = false;
  bool blockBusy = false;
  bool reportBusy = false;
  bool cpInviteBusy = false;
  bool intimacyCardBusy = false;

  String get targetId => user?['id']?.toString() ?? widget.userId;
  bool get isSelf => targetId == widget.state.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await widget.state.backend.userProfile(
      userId: widget.userId,
    );
    final rawUser = response?['user'];
    final loadedUser = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : null;
    final rawCurrentRoom = response?['current_room'];
    final loadedCurrentRoom = rawCurrentRoom is Map
        ? Map<String, dynamic>.from(rawCurrentRoom)
        : null;
    if (loadedUser == null) {
      if (!mounted) return;
      setState(() {
        user = null;
        loading = false;
      });
      return;
    }

    final resolvedId = loadedUser['id']?.toString() ?? widget.userId;
    final values = await Future.wait<Object?>([
      widget.state.backend.socialStats(userId: resolvedId),
      widget.state.backend.idLevelStatus(userId: resolvedId),
      widget.state.backend.medals(userId: resolvedId),
      widget.state.backend.cpState(userId: resolvedId),
      widget.state.backend.vsState(userId: resolvedId),
      if (resolvedId != widget.state.userId)
        widget.state.backend.followStatus(
          userId: widget.state.userId,
          targetUserId: resolvedId,
        )
      else
        Future<bool>.value(false),
      if (resolvedId != widget.state.userId)
        widget.state.backend.friends(userId: widget.state.userId)
      else
        Future<List<Map<String, dynamic>>>.value(
          const <Map<String, dynamic>>[],
        ),
      widget.state.backend.intimacyCards(userId: resolvedId),
    ]);

    final rawStats = values[0] is Map ? values[0] as Map : null;
    final rawLevel = values[1] is Map ? values[1] as Map : null;
    final rawMedals = values[2] is List ? values[2] as List : const [];
    final rawCp = values[3] is Map ? values[3] as Map : null;
    final rawVs = values[4] is Map ? values[4] as Map : null;
    final following = values[5] == true;
    final friends = values[6] is List ? values[6] as List : const [];
    final rawIntimacyCards = values[7] is Map ? values[7] as Map : null;

    if (!mounted) return;
    setState(() {
      user = loadedUser;
      socialStats = rawStats?['stats'] is Map
          ? Map<String, dynamic>.from(rawStats!['stats'] as Map)
          : const <String, dynamic>{};
      idLevel = rawLevel?['level'] is Map
          ? Map<String, dynamic>.from(rawLevel!['level'] as Map)
          : const <String, dynamic>{};
      medals = rawMedals
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      cp = rawCp?['cp'] is Map
          ? Map<String, dynamic>.from(rawCp!['cp'] as Map)
          : null;
      vs = rawVs?['vs'] is Map
          ? Map<String, dynamic>.from(rawVs!['vs'] as Map)
          : null;
      currentRoom = loadedCurrentRoom;
      isFollowing = following;
      isMutual = friends.whereType<Map>().any(
            (row) => row['id']?.toString() == resolvedId,
          );
      intimacyCards = rawIntimacyCards == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(rawIntimacyCards);
      loading = false;
    });
  }

  ImageProvider<Object>? _avatar(String? key) {
    final value = key?.trim() ?? '';
    if (value.isEmpty) return null;
    return NetworkImage(
      widget.state.backend.fileUrl(value),
      headers: widget.state.backend.fileHeaders,
    );
  }

  String _publicId(Map<String, dynamic> value) {
    final invisible = value['invisible_id'] == true ||
        value['invisible_id']?.toString() == '1';
    if (invisible && !isSelf) return 'Hidden';
    final custom = value['vip_custom_id']?.toString().trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final stable = value['public_id']?.toString().trim() ?? '';
    return stable.isNotEmpty ? stable : value['id']?.toString() ?? '';
  }

  Color _ownerTagColor(String? value) {
    final hex = (value ?? '').replaceAll('#', '').trim();
    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    }
    return const Color(0xFFFFD54F);
  }

  List<Widget> _ownerTagWidgets(Map<String, dynamic> value) {
    final raw = value['owner_tags'] ?? value['tags'];
    if (raw is! List) return const <Widget>[];
    return raw.whereType<Map>().map((item) {
      final tag = Map<String, dynamic>.from(item);
      final kind = tag['kind']?.toString() ?? 'custom';
      final label = (tag['designation']?.toString().trim().isNotEmpty == true
              ? tag['designation']
              : tag['name'])
          ?.toString()
          .trim() ??
          'Tag';
      final color = _ownerTagColor(
        tag['background_color']?.toString().trim().isNotEmpty == true
            ? tag['background_color']?.toString()
            : tag['color']?.toString(),
      );
      if (kind == 'v_official') {
        return Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: .8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD86A),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'V',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: .8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }).toList(growable: false);
  }

  String _partnerId(Map<String, dynamic>? relation) {
    if (relation == null || relation['state']?.toString() != 'active') {
      return '';
    }
    final a = relation['user_a']?.toString() ?? '';
    final b = relation['user_b']?.toString() ?? '';
    return a == targetId ? b : a;
  }

  String _partnerName(Map<String, dynamic>? relation) {
    if (relation == null) return '';
    final a = relation['user_a']?.toString() ?? '';
    return a == targetId
        ? relation['user_b_name']?.toString() ?? ''
        : relation['user_a_name']?.toString() ?? '';
  }

  String _partnerAvatar(Map<String, dynamic>? relation) {
    if (relation == null) return '';
    final a = relation['user_a']?.toString() ?? '';
    return a == targetId
        ? relation['user_b_avatar_key']?.toString() ?? ''
        : relation['user_a_avatar_key']?.toString() ?? '';
  }

  String _partnerPublicId(Map<String, dynamic>? relation) {
    if (relation == null) return '';
    final a = relation['user_a']?.toString() ?? '';
    final publicId = a == targetId
        ? relation['user_b_public_id']?.toString().trim() ?? ''
        : relation['user_a_public_id']?.toString().trim() ?? '';
    return publicId.isNotEmpty ? publicId : _partnerId(relation);
  }

  void _openPartner(Map<String, dynamic>? relation) {
    final id = _partnerId(relation);
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          state: widget.state,
          userId: id,
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (isSelf || followBusy) return;
    setState(() => followBusy = true);
    final next = !isFollowing;
    final ok = await widget.state.backend.setUserFollow(
      userId: widget.state.userId,
      targetUserId: targetId,
      follow: next,
    );
    if (!mounted) return;
    if (ok) {
      final friends = await widget.state.backend.friends(
        userId: widget.state.userId,
      );
      final statsResult = await widget.state.backend.socialStats(
        userId: targetId,
      );
      final stats = statsResult?['stats'];
      if (!mounted) return;
      setState(() {
        isFollowing = next;
        isMutual = friends.any(
          (row) => row['id']?.toString() == targetId,
        );
        if (stats is Map) {
          socialStats = Map<String, dynamic>.from(stats);
        }
      });
    }
    if (mounted) setState(() => followBusy = false);
  }

  void _openChat() {
    if (isSelf || user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          state: widget.state,
          otherUserId: targetId,
          otherName: user?['display_name']?.toString() ?? 'User',
        ),
      ),
    );
  }

  Future<void> _reportUser() async {
    if (isSelf || reportBusy) return;
    const reasons = <String>[
      'Harassment or abuse',
      'Inappropriate content',
      'Spam or scam',
      'Fake profile',
      'Safety concern',
      'Other',
    ];
    var reason = reasons.first;
    final detailsController = TextEditingController();
    final report = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Report user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: reasons
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => reason = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                <String, String>{
                  'reason': reason,
                  'details': detailsController.text.trim(),
                },
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    detailsController.dispose();
    if (report == null || !mounted) return;

    setState(() => reportBusy = true);
    final details = report['details']?.trim() ?? '';
    final message = StringBuffer()
      ..writeln('Target user: $targetId')
      ..writeln('Reason: ${report['reason'] ?? 'Other'}');
    if (details.isNotEmpty) {
      message.write('Details: $details');
    }
    final ok = await widget.state.backend.submitFeedback(
      userId: widget.state.userId,
      category: 'User report',
      message: message.toString().trim(),
    );
    if (!mounted) return;
    setState(() => reportBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Report submitted' : 'Could not submit report',
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    if (isSelf || blockBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'They will be removed from your follow/friend connection and direct interactions will be blocked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => blockBusy = true);
    final ok = await widget.state.backend.setUserBlocked(
      userId: widget.state.userId,
      targetUserId: targetId,
      blocked: true,
    );
    if (!mounted) return;
    setState(() {
      blockBusy = false;
      if (ok) {
        isFollowing = false;
        isMutual = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'User blocked' : 'Could not block user'),
      ),
    );
    if (ok && mounted) {
      Navigator.maybePop(context);
    }
  }

  Widget _profileMoreMenu() {
    if (isSelf) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: const Key('public-profile-more-menu'),
      tooltip: 'More',
      icon: const Icon(
        Icons.more_horiz_rounded,
        color: Colors.white,
        size: 30,
      ),
      onSelected: (value) {
        if (value == 'report') {
          _reportUser();
        } else if (value == 'block') {
          _blockUser();
        }
      },
      itemBuilder: (_) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined),
              SizedBox(width: 10),
              Text('Report'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'block',
          child: Row(
            children: [
              Icon(Icons.block_rounded),
              SizedBox(width: 10),
              Text('Block'),
            ],
          ),
        ),
      ],
    );
  }

  RoomSummary? _currentRoomSummary() {
    final row = currentRoom;
    if (row == null) return null;
    final roomId = row['room_id']?.toString().trim() ?? '';
    if (roomId.isEmpty) return null;

    RoomSummary? cached;
    for (final item in widget.state.rooms) {
      if (item.id == roomId || item.roomNumber == roomId) {
        cached = item;
        break;
      }
    }

    final avatar = row['avatar_key']?.toString().trim() ?? '';
    return RoomSummary(
      id: roomId,
      displayId: row['display_id']?.toString().trim().isNotEmpty == true
          ? row['display_id']?.toString().trim()
          : cached?.displayId,
      name: row['room_name']?.toString().trim().isNotEmpty == true
          ? row['room_name']!.toString().trim()
          : cached?.name ?? 'Room',
      ownerName: row['owner_name']?.toString().trim().isNotEmpty == true
          ? row['owner_name']!.toString().trim()
          : cached?.ownerName ?? 'Owner',
      ownerUserId: row['owner_user_id']?.toString().trim().isNotEmpty == true
          ? row['owner_user_id']!.toString().trim()
          : cached?.ownerUserId ?? '',
      online: int.tryParse(row['online']?.toString() ?? '') ??
          cached?.online ??
          1,
      seatCount: int.tryParse(row['seat_count']?.toString() ?? '') ??
          cached?.seatCount ??
          12,
      avatarKey: avatar.isNotEmpty ? avatar : cached?.avatarKey,
      partyMode: row['party_mode']?.toString().trim().isNotEmpty == true
          ? row['party_mode']!.toString().trim()
          : cached?.partyMode ?? 'Friends-making Party',
      roomMode: row['room_mode']?.toString().trim().isNotEmpty == true
          ? row['room_mode']!.toString().trim()
          : cached?.roomMode ?? 'voice',
    );
  }

  Future<void> _openCurrentRoom() async {
    final room = _currentRoomSummary();
    if (room == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomScreen(
          state: widget.state,
          room: room,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Widget _roomOnlineChip() {
    if (_currentRoomSummary() == null) return const SizedBox.shrink();
    return GestureDetector(
      key: const Key('public-profile-room-online'),
      behavior: HitTestBehavior.opaque,
      onTap: _openCurrentRoom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 7,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              size: 19,
              color: Color(0xFF27C66B),
            ),
            SizedBox(width: 7),
            Text(
              'Room',
              style: TextStyle(
                color: Color(0xFF27C66B),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarCircle({
    required double radius,
    required String avatarKey,
    required VoidCallback? onTap,
  }) {
    final provider = _avatar(avatarKey);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE6E6E6),
          backgroundImage: provider,
          child: provider == null
              ? Icon(
                  Icons.person_rounded,
                  size: radius,
                  color: Colors.black38,
                )
              : null,
        ),
      ),
    );
  }

  Widget _medalStrip() {
    if (medals.isEmpty) return const SizedBox(height: 32);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: medals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final medal = medals[index];
          final name = medal['name']?.toString() ?? 'Medal';
          return Tooltip(
            message: name,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF221B38),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD66B),
                size: 22,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileTab() {
    final value = user!;
    final country = value['country_name']?.toString().trim() ?? '';
    final flag = value['flag_emoji']?.toString().trim() ?? '';
    final bio = value['bio']?.toString().trim() ?? '';
    final countryText =
        country.isEmpty ? '-' : (flag.isEmpty ? country : '$flag $country');
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 82,
              child: Text(
                'Country',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 15,
                ),
              ),
            ),
            Expanded(
              child: Text(
                countryText,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 82,
              child: Text(
                'Bio',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 15,
                ),
              ),
            ),
            Expanded(
              child: Text(
                bio.isEmpty ? '-' : bio,
                style: const TextStyle(
                  color: Colors.black87,
                  height: 1.35,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openRelationManager({required bool couple}) async {
    if (!isSelf) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => couple
            ? CpScreen(state: widget.state)
            : VsScreen(state: widget.state),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openCpRules() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const _CpRuleScreen(),
      ),
    );
  }

  Future<void> _showVsInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Versus'),
        content: const Text(
          'VS is a rivalry relationship between two users. Only gifts sent directly '
          'between the active VS pair count. Lv.1→2 needs 150M sent and 150M received, '
          'Lv.2→3 needs 250M each, and every later level adds 100M. Both directions '
          'must finish the target; after level-up both current-level counters reset to 0.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCpBinding() async {
    if (!isSelf || cpInviteBusy) return;
    final rows = await widget.state.backend.friends(
      userId: widget.state.userId,
    );
    if (!mounted) return;

    final controller = TextEditingController();
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final q = query.trim().toLowerCase();
          final filtered = rows.where((row) {
            if (q.isEmpty) return true;
            final id = row['id']?.toString().toLowerCase() ?? '';
            final publicId = row['public_id']?.toString().toLowerCase() ?? '';
            final name = row['display_name']?.toString().toLowerCase() ?? '';
            return id.contains(q) || publicId.contains(q) || name.contains(q);
          }).toList(growable: false);

          return FractionallySizedBox(
            heightFactor: .76,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Friends that can be bound to CP',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: controller,
                        onChanged: (value) {
                          setModalState(() => query = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter ID',
                          hintStyle: const TextStyle(
                            color: Color(0xFFB6B8BE),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFFAEB2BA),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F8FB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_rounded,
                                    size: 76,
                                    color: Color(0xFF77DDF5),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Oh,There is nothing here~',
                                    style: TextStyle(
                                      color: Color(0xFFC8C8CC),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                2,
                                16,
                                24,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (itemContext, index) {
                                final friend = filtered[index];
                                final avatarKey =
                                    friend['avatar_key']?.toString() ?? '';
                                final id = friend['id']?.toString() ?? '';
                                final displayId =
                                    friend['public_id']?.toString().trim().isNotEmpty == true
                                        ? friend['public_id'].toString()
                                        : id;
                                final name = friend['display_name']
                                        ?.toString()
                                        .trim() ??
                                    '';
                                final image = _avatar(avatarKey);
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 7),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 27,
                                        backgroundColor:
                                            const Color(0xFFF0F0F2),
                                        backgroundImage: image,
                                        child: image == null
                                            ? const Icon(
                                                Icons.person_rounded,
                                                color: Colors.black38,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name.isEmpty ? 'User' : name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'ID:$displayId',
                                              style: const TextStyle(
                                                color: Color(0xFFB3B3B7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: 43,
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF24CCE8),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 23,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                            ),
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(sheetContext);
                                            await Future<void>.delayed(
                                              const Duration(milliseconds: 120),
                                            );
                                            if (!mounted) return;
                                            await _confirmCpInvite(friend);
                                          },
                                          child: const Text(
                                            'Protect',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    controller.dispose();
  }

  Future<void> _openVsBinding() async {
    if (!isSelf || cpInviteBusy) return;
    final rows = await widget.state.backend.friends(
      userId: widget.state.userId,
    );
    if (!mounted) return;

    final controller = TextEditingController();
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final q = query.trim().toLowerCase();
          final filtered = rows.where((row) {
            if (q.isEmpty) return true;
            final id = row['id']?.toString().toLowerCase() ?? '';
            final publicId = row['public_id']?.toString().toLowerCase() ?? '';
            final name = row['display_name']?.toString().toLowerCase() ?? '';
            return id.contains(q) || publicId.contains(q) || name.contains(q);
          }).toList(growable: false);

          return FractionallySizedBox(
            heightFactor: .76,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Friends that can be bound to VS',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: controller,
                        onChanged: (value) {
                          setModalState(() => query = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter ID',
                          hintStyle: const TextStyle(
                            color: Color(0xFFB6B8BE),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFFAEB2BA),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F8FB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No more',
                                style: TextStyle(
                                  color: Color(0xFFC8C8CC),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                2,
                                16,
                                24,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (itemContext, index) {
                                final friend = filtered[index];
                                final avatarKey =
                                    friend['avatar_key']?.toString() ?? '';
                                final id = friend['id']?.toString() ?? '';
                                final displayId =
                                    friend['public_id']?.toString().trim().isNotEmpty == true
                                        ? friend['public_id'].toString()
                                        : id;
                                final name = friend['display_name']
                                        ?.toString()
                                        .trim() ??
                                    '';
                                final image = _avatar(avatarKey);
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 7),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 27,
                                        backgroundColor:
                                            const Color(0xFFF0F0F2),
                                        backgroundImage: image,
                                        child: image == null
                                            ? const Icon(
                                                Icons.person_rounded,
                                                color: Colors.black38,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name.isEmpty ? 'User' : name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'ID:' + displayId,
                                              style: const TextStyle(
                                                color: Color(0xFFB3B3B7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: 43,
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF24CCE8),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 23,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                            ),
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(sheetContext);
                                            await Future<void>.delayed(
                                              const Duration(milliseconds: 120),
                                            );
                                            if (!mounted) return;
                                            await _confirmVsInvite(friend);
                                          },
                                          child: const Text(
                                            'Protect',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    controller.dispose();
  }

  Future<void> _confirmVsInvite(Map<String, dynamic> friend) async {
    if (cpInviteBusy) return;
    final id = friend['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final name = friend['display_name']?.toString().trim() ?? '';
    final avatarKey = friend['avatar_key']?.toString() ?? '';
    final image = _avatar(avatarKey);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 34),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFE7EF),
                Colors.white,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Form VS',
                style: TextStyle(
                  color: Color(0xFFE94B71),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to invite ' +
                    (name.isEmpty ? 'this user' : name) +
                    ' to be your VS?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFFF1F1F3),
                backgroundImage: image,
                child: image == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: Colors.black38,
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                name.isEmpty ? 'User' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'ID:' + id,
                style: const TextStyle(
                  color: Color(0xFFB5B5BA),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE8EF),
                          foregroundColor: const Color(0xFFE84A6F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(dialogContext, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF587D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(dialogContext, true),
                        child: const Text(
                          'Invite',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => cpInviteBusy = true);
    try {
      final result = await widget.state.backend.vsRequest(
        userId: widget.state.userId,
        targetUserId: id,
      );
      if (!mounted) return;

      if (result?['ok'] == true) {
        await _showVsInviteSent();
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']?.toString().replaceAll('_', ' ') ??
                  'VS invitation failed',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => cpInviteBusy = false);
    }
  }

  Future<void> _showVsInviteSent() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 34),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The invitation has been sent and\nis waiting to be received',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF587D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCpInvite(Map<String, dynamic> friend) async {
    if (cpInviteBusy) return;
    final id = friend['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final name = friend['display_name']?.toString().trim() ?? '';
    final avatarKey = friend['avatar_key']?.toString() ?? '';
    final image = _avatar(avatarKey);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 34),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFE7EF),
                Colors.white,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Form Friend',
                style: TextStyle(
                  color: Color(0xFFE94B71),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to invite ${name.isEmpty ? 'this user' : name} to be your Friend?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFFF1F1F3),
                backgroundImage: image,
                child: image == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: Colors.black38,
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                name.isEmpty ? 'User' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'ID:$id',
                style: const TextStyle(
                  color: Color(0xFFB5B5BA),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE8EF),
                          foregroundColor: const Color(0xFFE84A6F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(dialogContext, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF587D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(dialogContext, true),
                        child: const Text(
                          'Invite',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => cpInviteBusy = true);
    try {
      final result = await widget.state.backend.cpRequest(
        userId: widget.state.userId,
        targetUserId: id,
      );
      if (!mounted) return;

      if (result?['ok'] == true) {
        final balance =
            int.tryParse(result?['coin_balance']?.toString() ?? '');
        if (balance != null) widget.state.setCoinBalance(balance);
        await _showCpInviteSent();
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']
                      ?.toString()
                      .replaceAll('_', ' ') ??
                  'CP invitation failed',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => cpInviteBusy = false);
    }
  }

  Future<void> _showCpInviteSent() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 34),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The invitation has been sent and\nis waiting to be received',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF587D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _respondProfileRelation({
    required bool couple,
    required bool accept,
  }) async {
    if (!isSelf || cpInviteBusy) return;
    setState(() => cpInviteBusy = true);
    try {
      final result = couple
          ? await widget.state.backend.cpRespond(
              userId: widget.state.userId,
              accept: accept,
            )
          : await widget.state.backend.vsRespond(
              userId: widget.state.userId,
              accept: accept,
            );
      if (!mounted) return;
      if (result?['ok'] == true) {
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']?.toString().replaceAll('_', ' ') ??
                  'Request could not be updated.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => cpInviteBusy = false);
    }
  }

  Widget _relationRequestStatus({
    required bool couple,
    required Map<String, dynamic>? relation,
  }) {
    final data = relation ?? const <String, dynamic>{};
    if (data['state']?.toString() != 'pending' || !isSelf) {
      return const SizedBox.shrink();
    }
    final incoming =
        data['requested_by']?.toString() != widget.state.userId;

    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F6),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFFFD1DF),
          width: .8,
        ),
      ),
      child: incoming
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    couple
                        ? 'CP invitation received'
                        : 'VS invitation received',
                    style: const TextStyle(
                      color: Color(0xFF6D4A55),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: cpInviteBusy
                      ? null
                      : () => _respondProfileRelation(
                            couple: couple,
                            accept: false,
                          ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5B80),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: cpInviteBusy
                      ? null
                      : () => _respondProfileRelation(
                            couple: couple,
                            accept: true,
                          ),
                  child: const Text('Accept'),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFFF6B8D),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    couple
                        ? 'CP invitation sent — waiting to be received'
                        : 'VS invitation sent — waiting to be received',
                    style: const TextStyle(
                      color: Color(0xFF6D4A55),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _manageBoundIntimacyCard(
    int slotIndex,
    Map<String, dynamic> bound,
  ) async {
    if (!isSelf || intimacyCardBusy) return;
    final targetId = bound['target_user_id']?.toString() ?? '';
    final name = bound['display_name']?.toString() ?? 'User';
    final relation = _relationLabel(
      bound['relation_type']?.toString() ?? 'friend',
    );

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF7E9F),
              ),
              title: Text(name),
              subtitle: Text(relation),
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: const Text('Open profile'),
              onTap: () => Navigator.pop(sheetContext, 'profile'),
            ),
            ListTile(
              leading: const Icon(
                Icons.link_off_rounded,
                color: Color(0xFFE45468),
              ),
              title: const Text(
                'Remove from card',
                style: TextStyle(color: Color(0xFFE45468)),
              ),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'profile' && targetId.isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            state: widget.state,
            userId: targetId,
          ),
        ),
      );
      return;
    }
    if (action != 'remove') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove relationship card'),
        content: Text('Remove $name from this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5B80),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => intimacyCardBusy = true);
    try {
      final result = await widget.state.backend.unbindIntimacyCard(
        userId: widget.state.userId,
        slotIndex: slotIndex,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        setState(() => intimacyCards = Map<String, dynamic>.from(result!));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']?.toString().replaceAll('_', ' ') ??
                  'Card could not be removed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => intimacyCardBusy = false);
    }
  }

  Widget _intimacyHeading(
    String title, {
    VoidCallback? onHelp,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF202025),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onHelp,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F4),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '?',
              style: TextStyle(
                color: Color(0xFFB8B8BC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _intimacyRelationCircle({
    required double size,
    required ImageProvider<Object>? image,
    required bool empty,
    required VoidCallback? onTap,
    required bool versus,
  }) {
    final outerGradient = versus
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF2C68),
              Color(0xFF6F001E),
              Color(0xFFFF6B94),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFEEF2),
              Color(0xFFD97D8C),
              Color(0xFFFFDDE5),
            ],
          );
    final innerColor =
        versus ? const Color(0xFF17060C) : const Color(0xFFCF7C89);
    final innerBorder =
        versus ? const Color(0xFFFF91AE) : const Color(0xFFFBE7EC);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .065),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: outerGradient,
          border: Border.all(
            color: versus
                ? const Color(0xFFFF5A85)
                : const Color(0xFFF8DCE3),
            width: size * .018,
          ),
          boxShadow: [
            BoxShadow(
              color: versus
                  ? const Color(0x99FF174F)
                  : const Color(0x66F4A3B5),
              blurRadius: size * .13,
              spreadRadius: size * .018,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: innerColor,
            border: Border.all(
              color: innerBorder,
              width: size * .018,
            ),
            image: !empty && image != null
                ? DecorationImage(
                    image: image,
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: empty
              ? Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: size * .33,
                )
              : image == null
                  ? Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: size * .33,
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _intimacyIdentityLabel({
    required String name,
    required String id,
    required bool versus,
  }) {
    final safeName = name.trim().isEmpty ? 'None' : name.trim();
    final safeId = id.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: versus
            ? const Color(0xB314030A)
            : const Color(0xB35F2635),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: versus
              ? const Color(0x99FF4B79)
              : const Color(0x99FFF0F4),
          width: .8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            safeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          if (safeId.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'ID $safeId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: versus
                    ? const Color(0xFFFFC6D5)
                    : const Color(0xFFFFE7EC),
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _versusCard() {
    final data = vs ?? const <String, dynamic>{};
    final active = data['state']?.toString() == 'active';
    final rivalId = active ? _partnerId(vs) : '';
    final rivalPublicId = active ? _partnerPublicId(vs) : '';
    final rivalAvatar = active ? _partnerAvatar(vs) : '';
    final rivalName = active ? _partnerName(vs) : '';
    final ownAvatar = user?['avatar_key']?.toString() ?? '';
    final ownName = user?['display_name']?.toString().trim() ?? '';
    final ownPublicId = user == null ? '' : _publicId(user!);

    return AspectRatio(
      aspectRatio: 867 / 282,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final relationCircleSize = w * .18;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: active && isSelf
                ? () => _openRelationManager(couple: false)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _intimacyVsArtBytes,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                  Positioned(
                    left: w * .245 - relationCircleSize / 2,
                    top: h * .49 - relationCircleSize / 2,
                    width: relationCircleSize,
                    height: relationCircleSize,
                    child: _intimacyRelationCircle(
                      size: relationCircleSize,
                      image: _avatar(ownAvatar),
                      empty: false,
                      onTap: null,
                      versus: true,
                    ),
                  ),
                  Positioned(
                    left: w * .755 - relationCircleSize / 2,
                    top: h * .49 - relationCircleSize / 2,
                    width: relationCircleSize,
                    height: relationCircleSize,
                    child: _intimacyRelationCircle(
                      size: relationCircleSize,
                      image: _avatar(rivalAvatar),
                      empty: !active,
                      onTap: active && rivalId.isNotEmpty
                          ? () => _openPartner(vs)
                          : isSelf
                              ? _openVsBinding
                              : null,
                      versus: true,
                    ),
                  ),
                  Positioned(
                    left: w * .105,
                    bottom: h * .035,
                    width: w * .28,
                    child: _intimacyIdentityLabel(
                      name: ownName.isEmpty ? 'DarkVibeX User' : ownName,
                      id: ownPublicId,
                      versus: true,
                    ),
                  ),
                  Positioned(
                    right: w * .105,
                    bottom: h * .035,
                    width: w * .28,
                    child: _intimacyIdentityLabel(
                      name: active && rivalName.isNotEmpty ? rivalName : 'None',
                      id: active ? rivalPublicId : '',
                      versus: true,
                    ),
                  ),
                  Positioned(
                    key: const Key('profile-intimacy-vs-level-badge'),
                    left: w * .43,
                    top: h * .68,
                    width: w * .14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE61A020A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xCCFF4B79),
                          width: .8,
                        ),
                      ),
                      child: Text(
                        'Lv.${data['level'] ?? 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _loveStoreStrip() {
    return InkWell(
      key: const Key('profile-intimacy-love-store'),
      onTap: isSelf
          ? () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CosmeticsShopScreen(
                    state: widget.state,
                    initialKind: 'ring',
                  ),
                ),
              )
          : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: const Color(0xFFFFF2F7),
          border: Border.all(
            color: const Color(0xFFFFE1EB),
            width: .8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF4C74),
                size: 15,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Love Store',
                style: TextStyle(
                  color: Color(0xFFFF758F),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Go',
                style: TextStyle(
                  color: Color(0xFFFF718B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coupleCard() {
    final data = cp ?? const <String, dynamic>{};
    final active = data['state']?.toString() == 'active';
    final partnerId = active ? _partnerId(cp) : '';
    final partnerPublicId = active ? _partnerPublicId(cp) : '';
    final partnerAvatar = active ? _partnerAvatar(cp) : '';
    final partnerName = active ? _partnerName(cp) : '';
    final ownAvatar = user?['avatar_key']?.toString() ?? '';
    final ownName = user?['display_name']?.toString().trim() ?? '';
    final ownPublicId = user == null ? '' : _publicId(user!);

    return AspectRatio(
      aspectRatio: 635 / 258,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final relationCircleSize = w * .18;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: active && isSelf
                ? () => _openRelationManager(couple: true)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _intimacyCpArtBytes,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                  Positioned(
                    left: w * .205 - relationCircleSize / 2,
                    top: h * .46 - relationCircleSize / 2,
                    width: relationCircleSize,
                    height: relationCircleSize,
                    child: _intimacyRelationCircle(
                      size: relationCircleSize,
                      image: _avatar(ownAvatar),
                      empty: false,
                      onTap: null,
                      versus: false,
                    ),
                  ),
                  Positioned(
                    left: w * .795 - relationCircleSize / 2,
                    top: h * .46 - relationCircleSize / 2,
                    width: relationCircleSize,
                    height: relationCircleSize,
                    child: _intimacyRelationCircle(
                      size: relationCircleSize,
                      image: _avatar(partnerAvatar),
                      empty: !active,
                      onTap: active && partnerId.isNotEmpty
                          ? () => _openPartner(cp)
                          : isSelf
                              ? _openCpBinding
                              : null,
                      versus: false,
                    ),
                  ),
                  if (active &&
                      data['ring_id']?.toString().isNotEmpty == true)
                    Positioned(
                      key: const Key('profile-intimacy-cp-ring'),
                      left: w * .5 - w * .10,
                      top: h * .25,
                      width: w * .20,
                      height: w * .20,
                      child: JewelryRingPreview(
                        styleId: data['ring_id'].toString(),
                        size: w * .20,
                        imageProvider:
                            data['ring_asset_key']?.toString().isNotEmpty == true
                                ? NetworkImage(
                                    widget.state.backend.fileUrl(
                                      data['ring_asset_key'].toString(),
                                    ),
                                    headers: widget.state.backend.fileHeaders,
                                  )
                                : null,
                      ),
                    ),
                  Positioned(
                    left: w * .055,
                    bottom: h * .055,
                    width: w * .30,
                    child: _intimacyIdentityLabel(
                      name: ownName.isEmpty ? 'DarkVibeX User' : ownName,
                      id: ownPublicId,
                      versus: false,
                    ),
                  ),
                  Positioned(
                    right: w * .055,
                    bottom: h * .055,
                    width: w * .30,
                    child: _intimacyIdentityLabel(
                      name: active && partnerName.isNotEmpty
                          ? partnerName
                          : 'None',
                      id: active ? partnerPublicId : '',
                      versus: false,
                    ),
                  ),
                  if (active)
                    Positioned(
                      key: const Key('profile-intimacy-cp-level-badge'),
                      left: w * .435,
                      top: h * .66,
                      width: w * .13,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xD9FFF5F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0x99CB6076),
                            width: .8,
                          ),
                        ),
                        child: Text(
                          'Lv.${data['level'] ?? 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB63F5C),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<int, Map<String, dynamic>> _intimacyCardBindings() {
    final raw = intimacyCards['cards'];
    if (raw is! List) return <int, Map<String, dynamic>>{};
    final result = <int, Map<String, dynamic>>{};
    for (final row in raw.whereType<Map>()) {
      final slot = int.tryParse(row['slot_index']?.toString() ?? '');
      if (slot != null) result[slot] = Map<String, dynamic>.from(row);
    }
    return result;
  }

  String _relationLabel(String raw) {
    if (raw == 'brother_sister') return 'Brother/Sister';
    if (raw == 'enemy') return 'Enemy';
    return 'Friend';
  }

  Future<String?> _chooseIntimacyRelation() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Choose relationship',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final item in const <MapEntry<String, String>>[
              MapEntry('friend', 'Friend'),
              MapEntry('brother_sister', 'Brother/Sister'),
              MapEntry('enemy', 'Enemy'),
            ])
              ListTile(
                leading: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF8EAE),
                ),
                title: Text(item.value),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, item.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _bindIntimacyFriendCard(int slotIndex) async {
    if (!isSelf || intimacyCardBusy) return;
    final rows = await widget.state.backend.friends(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    final controller = TextEditingController();
    var query = '';

    final friend = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final q = query.trim().toLowerCase();
          final filtered = rows.where((item) {
            if (q.isEmpty) return true;
            final id = item['id']?.toString().toLowerCase() ?? '';
            final publicId = item['public_id']?.toString().toLowerCase() ?? '';
            final name = item['display_name']?.toString().toLowerCase() ?? '';
            return id.contains(q) || publicId.contains(q) || name.contains(q);
          }).toList(growable: false);

          return FractionallySizedBox(
            heightFactor: .72,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'Friends that can be bound',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: controller,
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        decoration: InputDecoration(
                          hintText: 'Enter ID',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF7F8FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No more',
                                style: TextStyle(color: Colors.black26),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                              itemCount: filtered.length,
                              itemBuilder: (itemContext, index) {
                                final item = filtered[index];
                                final avatarKey =
                                    item['avatar_key']?.toString() ?? '';
                                final image = _avatar(avatarKey);
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 27,
                                    backgroundImage: image,
                                    child: image == null
                                        ? const Icon(Icons.person_rounded)
                                        : null,
                                  ),
                                  title: Text(
                                    item['display_name']?.toString() ?? 'User',
                                  ),
                                  subtitle: Text(
                                    'ID:' +
                                        (item['public_id']?.toString().trim().isNotEmpty == true
                                            ? item['public_id'].toString()
                                            : (item['id']?.toString() ?? '')),
                                  ),
                                  trailing: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF24CCE8),
                                    ),
                                    onPressed: () => Navigator.pop(
                                      sheetContext,
                                      Map<String, dynamic>.from(item),
                                    ),
                                    child: const Text('Add'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
    if (friend == null || !mounted) return;

    final relationType = slotIndex == 1
        ? 'brother_sister'
        : await _chooseIntimacyRelation();
    if (relationType == null || !mounted) return;

    setState(() => intimacyCardBusy = true);
    try {
      final result = await widget.state.backend.bindIntimacyCard(
        userId: widget.state.userId,
        slotIndex: slotIndex,
        targetUserId: friend['id']?.toString() ?? '',
        relationType: relationType,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        setState(() => intimacyCards = Map<String, dynamic>.from(result!));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']?.toString().replaceAll('_', ' ') ??
                  'Card could not be bound.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => intimacyCardBusy = false);
    }
  }

  Future<void> _unlockNextIntimacyCard() async {
    if (!isSelf || intimacyCardBusy) return;
    final cost = int.tryParse(
          intimacyCards['next_unlock_cost']?.toString() ?? '',
        ) ??
        100000;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Unlock position',
                style: TextStyle(
                  color: Color(0xFFFF668A),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Make sure to spend ' +
                    cost.toString() +
                    ' gold to unlock friend locations',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5E82),
                      ),
                      onPressed: () =>
                          Navigator.pop(dialogContext, true),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => intimacyCardBusy = true);
    try {
      final result = await widget.state.backend.unlockIntimacyCard(
        userId: widget.state.userId,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        final balance =
            int.tryParse(result?['coin_balance']?.toString() ?? '');
        if (balance != null) widget.state.setCoinBalance(balance);
        setState(() => intimacyCards = Map<String, dynamic>.from(result!));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['error']?.toString().replaceAll('_', ' ') ??
                  'Position could not be unlocked.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => intimacyCardBusy = false);
    }
  }

  Widget _intimacyFriendCards() {
    final unlocked = (int.tryParse(
              intimacyCards['unlocked_count']?.toString() ?? '',
            ) ??
            3)
        .clamp(3, 20)
        .toInt();
    final total = (int.tryParse(
              intimacyCards['total_slots']?.toString() ?? '',
            ) ??
            20)
        .clamp(3, 20)
        .toInt();
    final bindings = _intimacyCardBindings();
    final visibleCount = unlocked + (unlocked < total ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final cardWidth = (constraints.maxWidth - gap * 2) / 3;
        final cardHeight = cardWidth * (274 / 158);

        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: List<Widget>.generate(visibleCount, (index) {
            final slotIndex = index + 1;
            final isLock = slotIndex > unlocked;

            if (isLock) {
              return GestureDetector(
                key: const Key('intimacy-card-unlock'),
                behavior: HitTestBehavior.opaque,
                onTap: isSelf ? _unlockNextIntimacyCard : null,
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: Image.asset(
                    'assets/images/friend_lock_card_ref.webp',
                    fit: BoxFit.fill,
                  ),
                ),
              );
            }

            final bound = bindings[slotIndex];
            final relation = slotIndex == 1
                ? 'Brother/Sister'
                : bound == null
                    ? 'Add'
                    : _relationLabel(
                        bound['relation_type']?.toString() ?? 'friend',
                      );
            final image =
                _avatar(bound?['avatar_key']?.toString() ?? '');
            final targetId =
                bound?['target_user_id']?.toString() ?? '';

            return GestureDetector(
              key: Key('intimacy-card-' + slotIndex.toString()),
              behavior: HitTestBehavior.opaque,
              onTap: bound == null
                  ? isSelf
                      ? () => _bindIntimacyFriendCard(slotIndex)
                      : null
                  : isSelf
                      ? () => _manageBoundIntimacyCard(slotIndex, bound)
                      : targetId.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PublicProfileScreen(
                                    state: widget.state,
                                    userId: targetId,
                                  ),
                                ),
                              ),
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/friend_add_card_ref.webp',
                      fit: BoxFit.fill,
                    ),
                    if (bound != null)
                      Align(
                        alignment: const Alignment(0, -0.22),
                        child: CircleAvatar(
                          radius: cardWidth * .22,
                          backgroundColor: const Color(0xFFFFE8EF),
                          backgroundImage: image,
                          child: image == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFFFF91AF),
                                )
                              : null,
                        ),
                      ),
                    if (slotIndex == 1 || bound != null)
                      Positioned(
                        left: cardWidth * .06,
                        right: cardWidth * .06,
                        top: cardHeight * .57,
                        height: cardHeight * .18,
                        child: Container(
                          alignment: Alignment.center,
                          color: Colors.white.withOpacity(.96),
                          child: Text(
                            relation,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF55555A),
                              fontSize: cardWidth * .10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _intimacyTab() {
    return ListView(
      key: const Key('profile-intimacy-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
      children: [
        _intimacyHeading(
          'Versus',
          onHelp: _showVsInfo,
        ),
        const SizedBox(height: 7),
        _versusCard(),
        _relationRequestStatus(couple: false, relation: vs),
        const SizedBox(height: 10),
        _loveStoreStrip(),
        const SizedBox(height: 15),
        _intimacyHeading(
          'Couple',
          onHelp: _openCpRules,
        ),
        const SizedBox(height: 7),
        _coupleCard(),
        _relationRequestStatus(couple: true, relation: cp),
        Offstage(
          offstage: true,
          child: _intimacyFriendCards(),
        ),
      ],
    );
  }

  List<Color> _profileCardColors(String? styleId) {
    final match = RegExp(r'^profile-vip-(\\d{2})
    final avatarKey = value['avatar_key']?.toString() ?? '';
    final cpRelation = cp;
    final cpActive =
        cpRelation != null && cpRelation['state']?.toString() == 'active';
    final cpPartnerAvatar =
        cpActive ? _partnerAvatar(cpRelation) : '';
    final followers =
        int.tryParse(socialStats['followers_count']?.toString() ?? '') ?? 0;
    final level = int.tryParse(idLevel['level']?.toString() ?? '') ?? 0;
    final gender = value['gender']?.toString().trim().toLowerCase() ?? '';
    return Container(
      height: 310,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasProfileCard
              ? <Color>[profileColors[0], profileColors[1], profileColors[2]]
              : const <Color>[
                  Color(0xFF10101A),
                  Color(0xFF37275C),
                  Color(0xFF8B5D82),
                ],
        ),
        border: hasProfileCard
            ? Border.all(color: profileColors[0], width: 2)
            : null,
        boxShadow: hasProfileCard
            ? <BoxShadow>[
                BoxShadow(
                  color: profileColors[0].withValues(alpha: .36),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            if (!isSelf)
              Positioned(
                top: 0,
                right: 4,
                child: _profileMoreMenu(),
              ),
            if (currentRoom != null)
              Positioned(
                top: 52,
                right: 12,
                child: _roomOnlineChip(),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 25,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: cpActive ? 138 : 88,
                    height: 94,
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        if (cpActive)
                          Positioned(
                            left: 51,
                            bottom: 0,
                            child: _avatarCircle(
                              radius: 39,
                              avatarKey: cpPartnerAvatar,
                              onTap: () => _openPartner(cpRelation),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: _avatarCircle(
                            radius: 43,
                            avatarKey: avatarKey,
                            onTap: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value['display_name']?.toString() ?? 'User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'ID ${_publicId(value)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$followers Followers',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xAA16A36A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Lv.$level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (gender == 'male' || gender == 'female')
                              Container(
                                width: 23,
                                height: 23,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: gender == 'male'
                                      ? const Color(0xFF4789E7)
                                      : const Color(0xFFE868A7),
                                ),
                                child: Text(
                                  gender == 'male' ? '♂' : '♀',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ..._ownerTagWidgets(value),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _medalStrip(),
                      ],
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

  String get _followLabel {
    if (isMutual) return 'Mutual Friend';
    if (isFollowing) return 'Followed';
    return 'Follow';
  }

  Widget _bottomActions() {
    if (isSelf) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 10),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: followBusy ? null : _toggleFollow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF22BED8),
                  side: const BorderSide(color: Color(0xFF22BED8)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: followBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _followLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _openChat,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF22BED8),
                  side: const BorderSide(color: Color(0xFF22BED8)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Chat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xCCF4E8FE),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xCCF4E8FE),
        appBar: AppBar(backgroundColor: const Color(0xCCF4E8FE)),
        body: const Center(child: Text('Profile not found')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xCCF4E8FE),
        body: Column(
          children: [
            _hero(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xE6F4E8FE),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.black45,
                      indicatorColor: Colors.transparent,
                      labelStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(text: 'Profile'),
                        Tab(text: 'Intimacy'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _profileTab(),
                          _intimacyTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _bottomActions(),
      ),
    );
  }
}


class _CpRuleScreen extends StatelessWidget {
  const _CpRuleScreen();

  static const List<List<String>> _levels = [
    ['LV1 → LV2', '150M', '150M'],
    ['LV2 → LV3', '250M', '250M'],
    ['LV3 → LV4', '350M', '350M'],
    ['LV4 → LV5', '450M', '450M'],
    ['LV5 → LV6', '550M', '550M'],
    ['LV6 → LV7', '650M', '650M'],
    ['LV7 → LV8', '750M', '750M'],
    ['LV8 → LV9', '850M', '850M'],
    ['LV9 → LV10', '950M', '950M'],
    ['LV10 → LV11', '1.05B', '1.05B'],
    ['LV11 → LV12', '1.15B', '1.15B'],
    ['LV12 → LV13', '1.25B', '1.25B'],
  ];

  static const List<List<String>> _privileges = [
    ['LV1', 'Lv1 star cover background', 'Online remind'],
    ['LV2', 'Lv2 star cover background', 'On Mic moving effect'],
    ['LV3', 'Lv3 star cover background', 'On Mic moving effect'],
    ['LV4', 'Lv4 star cover background', 'On Mic moving effect'],
    ['LV5', 'Lv5 star cover background', 'On Mic moving effect'],
    ['LV6', 'Lv6 star cover background', 'On Mic moving effect'],
    ['LV7', 'Lv7 star cover background', 'On Mic moving effect'],
    ['LV8', 'Lv8 star cover background', 'On Mic moving effect'],
    ['LV9', 'Lv9 star cover background', 'On Mic moving effect'],
    ['LV10', 'Lv10 star cover background', 'On Mic moving effect'],
    ['LV11', 'Lv11 star cover background', 'On Mic moving effect'],
    ['LV12', 'Lv12 star cover background', 'On Mic moving effect'],
    ['Marry', 'Marry Cover background', 'Online remind & On mic effect'],
  ];

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 23,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6536),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _ruleBox(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F3FD),
          borderRadius: BorderRadius.circular(15),
        ),
        child: child,
      );

  Widget _table(List<List<String>> rows, List<String> headers) {
    return Table(
      border: TableBorder.all(color: const Color(0xFFEDE7F2), width: .8),
      columnWidths: const {
        0: FlexColumnWidth(.75),
        1: FlexColumnWidth(1.55),
        2: FlexColumnWidth(2.45),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF2E2FF)),
          children: [
            for (final header in headers)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Text(
                  header,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  child: Text(
                    cell,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const paragraph = TextStyle(
      color: Colors.black54,
      fontSize: 15,
      height: 1.5,
    );
    return Scaffold(
      backgroundColor: const Color(0xCCF4E8FE),
      appBar: AppBar(
        backgroundColor: const Color(0xCCF4E8FE),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CP Rule',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
        children: [
          _sectionTitle('What is CP?'),
          _ruleBox(
            const Text(
              '1. CP can be formed with an eligible mutual friend through the CP invitation flow. The CP invitation costs 2,222,222 coins.\n\n'
              '2. My Heart is available as a 44,444-coin CP gift.\n\n'
              '3. CP level progress only comes from gifts exchanged directly between the two active CP partners. Gifts from any third user add 0 CP level progress.',
              style: paragraph,
            ),
          ),
          _sectionTitle('What is marriage?'),
          _ruleBox(
            const Text(
              '1. After becoming CP LV 1, you can purchase a ring to initiate a marriage proposal;\n\n'
              '2. After a successful proposal, friends can be invited to participate, and the wedding room mode can be enabled in the room of the proposing party or on the wedding day. Gifts received in the wedding room on the day have a 1.1 time bonus to blessing value and intimacy value;\n\n'
              '3. Love House: after getting married, you can upload themes in Love House, send and collect wedding rings to each other.\n\n'
              '4. Divorce: after divorce, the CP relationship will also be terminated and the CP and marriage procedures need to be completed again. After restoring CP and getting married, intimacy value and blessing value can be restored.',
              style: paragraph,
            ),
          ),
          _sectionTitle(
            'What is intimacy level and how to maintain and improve intimacy level?',
          ),
          _ruleBox(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Every CP level has two separate counters: Sending and Receiving. Both counters must reach the current target before the CP level increases. Lv.1→2 requires 150M sent and 150M received; Lv.2→3 requires 250M each; every next level increases the target by 100M. After level-up, both counters start again from 0 and extra progress is not carried forward. Total intimacy remains available for relationship history and ranking.',
                  style: paragraph,
                ),
                const SizedBox(height: 14),
                _table(
                  _levels,
                  const ['level', 'Sending target', 'Receiving target'],
                ),
              ],
            ),
          ),
          _sectionTitle('Relationship tools'),
          _ruleBox(
            const Text(
              'Active CP includes Love Days, Ring Cabinet, Memories, CP Ranking, Heartbeat matching, and partner-confirmed disconnect. Disconnect requests time out after 24 hours if the partner does not respond.',
              style: paragraph,
            ),
          ),
          _sectionTitle('What are the privileges of intimate relationships?'),
          _ruleBox(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Close friends with different levels of intimacy have different privileges, as follows:',
                  style: paragraph,
                ),
                const SizedBox(height: 14),
                _table(
                  _privileges,
                  const ['level', 'Background', 'Effects'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
).firstMatch(styleId ?? '');
    const palettes = <List<Color>>[
      <Color>[Color(0xFFFFD36A), Color(0xFF8B4D18), Color(0xFF150D18)],
      <Color>[Color(0xFFFF3D98), Color(0xFF7B1B7C), Color(0xFF140B21)],
      <Color>[Color(0xFF52C7FF), Color(0xFF4B36C9), Color(0xFF100D24)],
      <Color>[Color(0xFFE9C4FF), Color(0xFFAD49FF), Color(0xFF220B3D)],
      <Color>[Color(0xFFD8FF9C), Color(0xFF267C2E), Color(0xFF0A1716)],
      <Color>[Color(0xFFFF8A38), Color(0xFF9B210D), Color(0xFF150808)],
      <Color>[Color(0xFFDBF7FF), Color(0xFF2468D8), Color(0xFF07152E)],
      <Color>[Color(0xFFFFB6D9), Color(0xFFC42D72), Color(0xFF210A18)],
      <Color>[Color(0xFFD7BDFF), Color(0xFF6332C4), Color(0xFF160B2A)],
      <Color>[Color(0xFFB7F4FF), Color(0xFF1677B8), Color(0xFF06182A)],
      <Color>[Color(0xFFFFB0B0), Color(0xFF9F1637), Color(0xFF21070D)],
      <Color>[Color(0xFFFFD17A), Color(0xFFB94A0C), Color(0xFF2A1000)],
      <Color>[Color(0xFFE2B5FF), Color(0xFF7028C4), Color(0xFF1C0930)],
      <Color>[Color(0xFFFFF0A3), Color(0xFFC17A05), Color(0xFF2B1900)],
      <Color>[Color(0xFFFFA8FF), Color(0xFF7131C7), Color(0xFF1A0730)],
      <Color>[Color(0xFFB4F8FF), Color(0xFF007DAA), Color(0xFF041E2E)],
      <Color>[Color(0xFFFFB17D), Color(0xFFB92510), Color(0xFF2B0800)],
      <Color>[Color(0xFFFFE7A8), Color(0xFFDA8B08), Color(0xFF321500)],
    ];
    if (match != null) {
      final level = (int.tryParse(match.group(1) ?? '') ?? 1).clamp(1, 18);
      return palettes[level - 1];
    }
    return switch (styleId) {
      'profile-card-pink-heart' => palettes[1],
      'profile-card-crystal-star' => palettes[2],
      'profile-card-vip-queen' => palettes[13],
      'profile-card-family-leader' => palettes[4],
      'profile-card-birthday' => palettes[7],
      'profile-card-winner' => palettes[11],
      _ => palettes[0],
    };
  }

  Widget _hero() {
    final value = user!;
    final profileCardId = value['active_profile_card_id']?.toString();
    final profileColors = _profileCardColors(profileCardId);
    final hasProfileCard = profileCardId != null && profileCardId.isNotEmpty;
    final avatarKey = value['avatar_key']?.toString() ?? '';
    final cpRelation = cp;
    final cpActive =
        cpRelation != null && cpRelation['state']?.toString() == 'active';
    final cpPartnerAvatar =
        cpActive ? _partnerAvatar(cpRelation) : '';
    final followers =
        int.tryParse(socialStats['followers_count']?.toString() ?? '') ?? 0;
    final level = int.tryParse(idLevel['level']?.toString() ?? '') ?? 0;
    final gender = value['gender']?.toString().trim().toLowerCase() ?? '';
    return Container(
      height: 310,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF10101A),
            Color(0xFF37275C),
            Color(0xFF8B5D82),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            if (!isSelf)
              Positioned(
                top: 0,
                right: 4,
                child: _profileMoreMenu(),
              ),
            if (currentRoom != null)
              Positioned(
                top: 52,
                right: 12,
                child: _roomOnlineChip(),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 25,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: cpActive ? 138 : 88,
                    height: 94,
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        if (cpActive)
                          Positioned(
                            left: 51,
                            bottom: 0,
                            child: _avatarCircle(
                              radius: 39,
                              avatarKey: cpPartnerAvatar,
                              onTap: () => _openPartner(cpRelation),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: _avatarCircle(
                            radius: 43,
                            avatarKey: avatarKey,
                            onTap: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value['display_name']?.toString() ?? 'User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'ID ${_publicId(value)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$followers Followers',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xAA16A36A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Lv.$level',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (gender == 'male' || gender == 'female')
                              Container(
                                width: 23,
                                height: 23,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: gender == 'male'
                                      ? const Color(0xFF4789E7)
                                      : const Color(0xFFE868A7),
                                ),
                                child: Text(
                                  gender == 'male' ? '♂' : '♀',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ..._ownerTagWidgets(value),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _medalStrip(),
                      ],
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

  String get _followLabel {
    if (isMutual) return 'Mutual Friend';
    if (isFollowing) return 'Followed';
    return 'Follow';
  }

  Widget _bottomActions() {
    if (isSelf) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 9, 18, 10),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: followBusy ? null : _toggleFollow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF22BED8),
                  side: const BorderSide(color: Color(0xFF22BED8)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: followBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _followLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _openChat,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF22BED8),
                  side: const BorderSide(color: Color(0xFF22BED8)),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Chat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xCCF4E8FE),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xCCF4E8FE),
        appBar: AppBar(backgroundColor: const Color(0xCCF4E8FE)),
        body: const Center(child: Text('Profile not found')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xCCF4E8FE),
        body: Column(
          children: [
            _hero(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xE6F4E8FE),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.black45,
                      indicatorColor: Colors.transparent,
                      labelStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(text: 'Profile'),
                        Tab(text: 'Intimacy'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _profileTab(),
                          _intimacyTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _bottomActions(),
      ),
    );
  }
}


class _CpRuleScreen extends StatelessWidget {
  const _CpRuleScreen();

  static const List<List<String>> _levels = [
    ['LV1 → LV2', '150M', '150M'],
    ['LV2 → LV3', '250M', '250M'],
    ['LV3 → LV4', '350M', '350M'],
    ['LV4 → LV5', '450M', '450M'],
    ['LV5 → LV6', '550M', '550M'],
    ['LV6 → LV7', '650M', '650M'],
    ['LV7 → LV8', '750M', '750M'],
    ['LV8 → LV9', '850M', '850M'],
    ['LV9 → LV10', '950M', '950M'],
    ['LV10 → LV11', '1.05B', '1.05B'],
    ['LV11 → LV12', '1.15B', '1.15B'],
    ['LV12 → LV13', '1.25B', '1.25B'],
  ];

  static const List<List<String>> _privileges = [
    ['LV1', 'Lv1 star cover background', 'Online remind'],
    ['LV2', 'Lv2 star cover background', 'On Mic moving effect'],
    ['LV3', 'Lv3 star cover background', 'On Mic moving effect'],
    ['LV4', 'Lv4 star cover background', 'On Mic moving effect'],
    ['LV5', 'Lv5 star cover background', 'On Mic moving effect'],
    ['LV6', 'Lv6 star cover background', 'On Mic moving effect'],
    ['LV7', 'Lv7 star cover background', 'On Mic moving effect'],
    ['LV8', 'Lv8 star cover background', 'On Mic moving effect'],
    ['LV9', 'Lv9 star cover background', 'On Mic moving effect'],
    ['LV10', 'Lv10 star cover background', 'On Mic moving effect'],
    ['LV11', 'Lv11 star cover background', 'On Mic moving effect'],
    ['LV12', 'Lv12 star cover background', 'On Mic moving effect'],
    ['Marry', 'Marry Cover background', 'Online remind & On mic effect'],
  ];

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 23,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6536),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _ruleBox(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F3FD),
          borderRadius: BorderRadius.circular(15),
        ),
        child: child,
      );

  Widget _table(List<List<String>> rows, List<String> headers) {
    return Table(
      border: TableBorder.all(color: const Color(0xFFEDE7F2), width: .8),
      columnWidths: const {
        0: FlexColumnWidth(.75),
        1: FlexColumnWidth(1.55),
        2: FlexColumnWidth(2.45),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF2E2FF)),
          children: [
            for (final header in headers)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Text(
                  header,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                  child: Text(
                    cell,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const paragraph = TextStyle(
      color: Colors.black54,
      fontSize: 15,
      height: 1.5,
    );
    return Scaffold(
      backgroundColor: const Color(0xCCF4E8FE),
      appBar: AppBar(
        backgroundColor: const Color(0xCCF4E8FE),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CP Rule',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
        children: [
          _sectionTitle('What is CP?'),
          _ruleBox(
            const Text(
              '1. CP can be formed with an eligible mutual friend through the CP invitation flow. The CP invitation costs 2,222,222 coins.\n\n'
              '2. My Heart is available as a 44,444-coin CP gift.\n\n'
              '3. CP level progress only comes from gifts exchanged directly between the two active CP partners. Gifts from any third user add 0 CP level progress.',
              style: paragraph,
            ),
          ),
          _sectionTitle('What is marriage?'),
          _ruleBox(
            const Text(
              '1. After becoming CP LV 1, you can purchase a ring to initiate a marriage proposal;\n\n'
              '2. After a successful proposal, friends can be invited to participate, and the wedding room mode can be enabled in the room of the proposing party or on the wedding day. Gifts received in the wedding room on the day have a 1.1 time bonus to blessing value and intimacy value;\n\n'
              '3. Love House: after getting married, you can upload themes in Love House, send and collect wedding rings to each other.\n\n'
              '4. Divorce: after divorce, the CP relationship will also be terminated and the CP and marriage procedures need to be completed again. After restoring CP and getting married, intimacy value and blessing value can be restored.',
              style: paragraph,
            ),
          ),
          _sectionTitle(
            'What is intimacy level and how to maintain and improve intimacy level?',
          ),
          _ruleBox(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Every CP level has two separate counters: Sending and Receiving. Both counters must reach the current target before the CP level increases. Lv.1→2 requires 150M sent and 150M received; Lv.2→3 requires 250M each; every next level increases the target by 100M. After level-up, both counters start again from 0 and extra progress is not carried forward. Total intimacy remains available for relationship history and ranking.',
                  style: paragraph,
                ),
                const SizedBox(height: 14),
                _table(
                  _levels,
                  const ['level', 'Sending target', 'Receiving target'],
                ),
              ],
            ),
          ),
          _sectionTitle('Relationship tools'),
          _ruleBox(
            const Text(
              'Active CP includes Love Days, Ring Cabinet, Memories, CP Ranking, Heartbeat matching, and partner-confirmed disconnect. Disconnect requests time out after 24 hours if the partner does not respond.',
              style: paragraph,
            ),
          ),
          _sectionTitle('What are the privileges of intimate relationships?'),
          _ruleBox(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Close friends with different levels of intimacy have different privileges, as follows:',
                  style: paragraph,
                ),
                const SizedBox(height: 14),
                _table(
                  _privileges,
                  const ['level', 'Background', 'Effects'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
