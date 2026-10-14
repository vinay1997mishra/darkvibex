import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../i18n/darkvibex_localization.dart';
import 'vip_screen.dart';
import 'app_settings_screen.dart';
import 'recharge_screen.dart';
import 'cosmetics_shop_screen.dart';
import 'mine_social_screens.dart';
import 'conversation_screen.dart';
import 'direct_call_screen.dart';
import 'personal_profile_screen.dart';
import '../widgets/vip_animated_frame.dart';
import '../ui/tinni_style.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
                                  color: Color(0xFFF14A8B),
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
                                    color: Color(0xFFF14A8B),
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
    return '\${value.day.toString().padLeft(2, '0')} \${months[value.month - 1]}';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
  bool loading = true;
  bool isFollowing = false;
  bool isMutual = false;
  bool followBusy = false;

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
    ]);

    final rawStats = values[0] is Map ? values[0] as Map : null;
    final rawLevel = values[1] is Map ? values[1] as Map : null;
    final rawMedals = values[2] is List ? values[2] as List : const [];
    final rawCp = values[3] is Map ? values[3] as Map : null;
    final rawVs = values[4] is Map ? values[4] as Map : null;
    final following = values[5] == true;
    final friends = values[6] is List ? values[6] as List : const [];

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
      isFollowing = following;
      isMutual = friends.whereType<Map>().any(
            (row) => row['id']?.toString() == resolvedId,
          );
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
    final custom = value['vip_custom_id']?.toString().trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final stable = value['public_id']?.toString().trim() ?? '';
    return stable.isNotEmpty ? stable : value['id']?.toString() ?? '';
  }

  String _partnerId(Map<String, dynamic>? relation) {
    if (relation == null || relation?['state']?.toString() != 'active') {
      return '';
    }
    final a = relation?['user_a']?.toString() ?? '';
    final b = relation?['user_b']?.toString() ?? '';
    return a == targetId ? b : a;
  }

  String _partnerName(Map<String, dynamic>? relation) {
    if (relation == null) return '';
    final a = relation?['user_a']?.toString() ?? '';
    return a == targetId
        ? relation?['user_b_name']?.toString() ?? ''
        : relation?['user_a_name']?.toString() ?? '';
  }

  String _partnerAvatar(Map<String, dynamic>? relation) {
    if (relation == null) return '';
    final a = relation?['user_a']?.toString() ?? '';
    return a == targetId
        ? relation?['user_b_avatar_key']?.toString() ?? ''
        : relation?['user_a_avatar_key']?.toString() ?? '';
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
          peerUserId: targetId,
          peerName: user?['display_name']?.toString() ?? 'User',
          peerAvatarKey: user?['avatar_key']?.toString(),
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

  Widget _relationCard({
    required String title,
    required Map<String, dynamic>? relation,
    required bool couple,
  }) {
    final active = relation?['state']?.toString() == 'active';
    final partnerId = active ? _partnerId(relation) : '';
    final partnerName = active ? _partnerName(relation) : '';
    final partnerAvatar = active ? _partnerAvatar(relation) : '';
    final level = int.tryParse(relation?['level']?.toString() ?? '') ?? 0;
    final progress = int.tryParse(
          relation?[couple ? 'intimacy' : 'rivalry']?.toString() ?? '',
        ) ??
        0;
    final next = int.tryParse(
      relation?['next_level_threshold']?.toString() ?? '',
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: LinearGradient(
          colors: couple
              ? const [Color(0xFFFF7AAE), Color(0xFFFFB7D4)]
              : const [Color(0xFF5435A8), Color(0xFF8C73DB)],
        ),
      ),
      child: active
          ? Column(
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Lv.$level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    _avatarCircle(
                      radius: 31,
                      avatarKey: user?['avatar_key']?.toString() ?? '',
                      onTap: null,
                    ),
                    Expanded(
                      child: Center(
                        child: Icon(
                          couple
                              ? Icons.favorite_rounded
                              : Icons.flash_on_rounded,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                    ),
                    _avatarCircle(
                      radius: 31,
                      avatarKey: partnerAvatar,
                      onTap: partnerId.isEmpty
                          ? null
                          : () => _openPartner(relation),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user?['display_name']?.toString() ?? 'User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        partnerName.isEmpty ? 'User' : partnerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: next == null || next <= 0
                      ? 1
                      : (progress / next).clamp(0, 1).toDouble(),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: const Color(0x55FFFFFF),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    next == null ? '$progress' : '$progress / $next',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              height: 95,
              child: Center(
                child: Text(
                  'No $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _intimacyTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 110),
      children: [
        _relationCard(
          title: 'Couple',
          relation: cp,
          couple: true,
        ),
        _relationCard(
          title: 'VS',
          relation: vs,
          couple: false,
        ),
      ],
    );
  }

  Widget _hero() {
    final value = user!;
    final avatarKey = value['avatar_key']?.toString() ?? '';
    final cpActive = cp?['state']?.toString() == 'active';
    final cpPartnerAvatar = cpActive ? _partnerAvatar(cp) : '';
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
                              onTap: () => _openPartner(cp),
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
                                'ID \${_publicId(value)}',
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
                  foregroundColor: const Color(0xFFF14A8B),
                  side: const BorderSide(color: Color(0xFFF14A8B)),
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
                  foregroundColor: const Color(0xFFF14A8B),
                  side: const BorderSide(color: Color(0xFFF14A8B)),
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
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(),
        body: const Center(child: Text('Profile not found')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _hero(),
            const Material(
              color: Colors.white,
              child: TabBar(
                labelColor: Color(0xFFF14A8B),
                unselectedLabelColor: Colors.black54,
                indicatorColor: Color(0xFFF14A8B),
                indicatorWeight: 2.5,
                tabs: [
                  Tab(text: 'Profile'),
                  Tab(text: 'Intimacy'),
                ],
              ),
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
        bottomNavigationBar: _bottomActions(),
      ),
    );
  }
}
