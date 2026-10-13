import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import 'vip_screen.dart';
import 'app_settings_screen.dart';
import 'recharge_screen.dart';
import 'cosmetics_shop_screen.dart';
import 'mine_social_screens.dart';
import 'conversation_screen.dart';
import 'direct_call_screen.dart';
import 'personal_profile_screen.dart';
import '../widgets/vip_animated_frame.dart';
import '../infra/privacy_screen_protection.dart';
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
    final rows = await load();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .68,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text('${rows.length}'),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(child: Text('No $title yet'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (itemContext, index) {
                          final row = rows[index];
                          final id = (row['id'] ??
                                  row['user_id'] ??
                                  row['target_user_id'] ??
                                  row['follower_id'])
                              ?.toString() ??
                              '';
                          final avatarKey =
                              row['avatar_key']?.toString() ?? '';
                          final name =
                              row['display_name']?.toString().trim();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: TinniPalette.panel2,
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
                            title: Text(
                              name == null || name.isEmpty
                                  ? (id.isEmpty ? 'User' : 'User $id')
                                  : name,
                            ),
                            subtitle:
                                id.isEmpty ? null : Text('ID $id'),
                            trailing:
                                const Icon(Icons.chevron_right_rounded),
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
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showVisitors(BuildContext context) async {
    final visitors = await state.backend.profileVisitors(userId: state.userId);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .65,
          child: visitors.isEmpty
              ? const Center(child: Text('No visitors yet'))
              : ListView.builder(
                  itemCount: visitors.length,
                  itemBuilder: (itemContext, index) {
                    final visitor = visitors[index];
                    final userId = visitor['user_id']?.toString() ?? '';
                    final name = visitor['display_name']?.toString() ?? 'User';
                    final avatarKey = visitor['avatar_key']?.toString() ?? '';
                    final count =
                        int.tryParse(visitor['visit_count']?.toString() ?? '') ?? 1;
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
                      subtitle: Text(
                        '${_formatVisitTime(visitor['last_visited_at'])} • '
                        '${count == 1 ? '1 visit' : '$count visits'}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: userId.isEmpty
                          ? null
                          : () => Navigator.of(sheetContext).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PublicProfileScreen(
                                    state: state,
                                    userId: userId,
                                  ),
                                ),
                              ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _formatVisitTime(dynamic raw) {
    DateTime? value;
    final numeric = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (numeric != null && numeric > 0) {
      final millis = numeric < 100000000000 ? numeric * 1000 : numeric;
      value = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    } else {
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      value = parsed?.toLocal();
    }
    if (value == null) return 'Recently';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
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
    final ringId = state.activeCosmetic('ring');
    final profileCardId = state.activeCosmetic('profile_card');
    final profileBackgroundId = state.activeCosmetic('profile_background');
    return AnimatedBuilder(
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
                  'Follow',
                  onTap: () => _showPeopleList(
                    context,
                    title: 'Following',
                    load: () => state.backend.following(
                      userId: state.userId,
                    ),
                  ),
                ),
                const _MineDivider(),
                _mineCount(
                  (socialStats['followers_count'] ?? 0).toString(),
                  'Fans',
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
                  'Charm',
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
                    title: 'Wealth level',
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
                title: const Text('Medal of Honor'),
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
                'Shop',
                'Frames, vehicles and entry effects',
              ),
              ListTile(
                leading: const Icon(
                  Icons.auto_awesome_rounded,
                  color: TinniPalette.gold,
                ),
                title: const Text('Trends'),
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
                title: const Text('Task'),
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
                title: const Text('Family'),
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
                title: const Text('CP Nest'),
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
                title: const Text('Feedback'),
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
                'Setting',
                'Language, account, privacy and app settings',
              ),
            ]),
          ],
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

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.state, required this.userId});

  final AppState state;
  final String userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicStat extends StatelessWidget {
  const _PublicStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: TinniPalette.gold,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: TinniPalette.muted,
              fontSize: 9,
            ),
          ),
        ],
      );
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final Object _privacyScope = Object();
  Map<String, dynamic>? user;
  Map<String, dynamic> socialStats = const <String, dynamic>{};
  List<Map<String, dynamic>> trends = const <Map<String, dynamic>>[];
  bool loading = true;
  bool isFriend = false;
  bool isFollowing = false;
  bool isBlocked = false;
  bool followBusy = false;
  bool blockBusy = false;
  bool startingCall = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _resolvedUserId =>
      user?['id']?.toString() ?? widget.userId;

  bool get _isSelf => _resolvedUserId == widget.state.userId;

  Future<void> _load() async {
    final response = await widget.state.backend.userProfile(
      userId: widget.userId,
    );
    final loadedUser = response?['user'] is Map
        ? Map<String, dynamic>.from(response!['user'] as Map)
        : null;
    final targetId = loadedUser?['id']?.toString() ?? widget.userId;

    var friendStatus = false;
    var blockedStatus = false;
    var following = false;
    Map<String, dynamic> stats = const <String, dynamic>{};
    if (loadedUser != null) {
      final values = await Future.wait<Object?>([
        widget.state.backend.friends(userId: widget.state.userId),
        widget.state.backend.blockedUsers(userId: widget.state.userId),
        widget.state.backend.socialStats(userId: targetId),
        if (targetId != widget.state.userId)
          widget.state.backend.followStatus(
            userId: widget.state.userId,
            targetUserId: targetId,
          )
        else
          Future<bool>.value(false),
        widget.state.backend.profileTrends(userId: targetId),
      ]);
      final friends = values[0] is List
          ? (values[0] as List).whereType<Map>().toList()
          : const <Map>[];
      final blocked = values[1] is List
          ? (values[1] as List).whereType<Map>().toList()
          : const <Map>[];
      friendStatus =
          friends.any((row) => row['id']?.toString() == targetId);
      blockedStatus =
          blocked.any((row) => row['user_id']?.toString() == targetId);
      if (values[2] is Map) {
        stats = Map<String, dynamic>.from(values[2] as Map);
      }
      following = values[3] == true;
      final trendRows = values[4] is List
          ? (values[4] as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      trends = trendRows;
    }

    if (!mounted) return;
    setState(() {
      user = loadedUser;
      socialStats = stats;
      loading = false;
      isFriend = friendStatus;
      isFollowing = following;
      isBlocked = blockedStatus;
    });
    await PrivacyScreenProtection.setProtected(
      _privacyScope,
      user?['privacy_protection_enabled'] == true,
    );
  }

  String _trendTime(dynamic raw) {
    final value = int.tryParse(raw?.toString() ?? '') ?? 0;
    if (value <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  Future<void> _showTrends() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: TinniPalette.nearBlack,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .68,
          child: trends.isEmpty
              ? const Center(
                  child: Text(
                    'No Trends yet.',
                    style: TextStyle(color: TinniPalette.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  children: [
                    const ListTile(
                      title: Text(
                        'Trends',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    for (final row in trends)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TinniPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['text']?.toString() ?? ''),
                              const SizedBox(height: 6),
                              Text(
                                _trendTime(row['created_at']),
                                style: const TextStyle(
                                  color: TinniPalette.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
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
        appBar: AppBar(
          title: Text(user?['display_name']?.toString() ?? 'Profile'),
          actions: [
            if (!_isSelf)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'block') _toggleBlock();
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Text(isBlocked ? 'Unblock user' : 'Block user'),
                  ),
                ],
              ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : user == null
                ? const Center(child: Text('Profile could not be loaded'))
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            user!['active_ring_id']?.toString().isNotEmpty == true
                                ? 4
                                : 0,
                          ),
                          decoration: user!['active_ring_id']
                                      ?.toString()
                                      .isNotEmpty ==
                                  true
                              ? const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: <Color>[
                                      Color(0xFFFFE47A),
                                      Color(0xFFFF6FB7),
                                      Color(0xFF8C6CFF),
                                      Color(0xFFFFE47A),
                                    ],
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Color(0x66FFB5F1),
                                      blurRadius: 12,
                                    ),
                                  ],
                                )
                              : null,
                          child: VipAnimatedFrame(
                            size: 88,
                            enabled: user!['active_frame_id']
                                        ?.toString()
                                        .isNotEmpty ==
                                    true ||
                                (int.tryParse(
                                          user!['active_vip_level']
                                                  ?.toString() ??
                                              '',
                                        ) ??
                                        0) >=
                                    7,
                            styleId: user!['active_frame_id']?.toString(),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: user!['avatar_key']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? NetworkImage(
                                      widget.state.backend.fileUrl(
                                        user!['avatar_key'].toString(),
                                      ),
                                      headers:
                                          widget.state.backend.fileHeaders,
                                    )
                                  : null,
                              child: user!['avatar_key']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? null
                                  : Text(
                                      displayName.isEmpty
                                          ? 'U'
                                          : displayName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(user!['display_name']?.toString() ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('ID ${user!['public_id'] ?? user!['id']} • VIP ${user!['vip_level'] ?? 0}/18'),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 18,
                          runSpacing: 8,
                          children: [
                            _PublicStat(
                              label: 'Follow',
                              value: '${socialStats['following_count'] ?? 0}',
                            ),
                            _PublicStat(
                              label: 'Fans',
                              value: '${socialStats['followers_count'] ?? 0}',
                            ),
                            _PublicStat(
                              label: 'Charm',
                              value:
                                  '${socialStats['lifetime_received_coins'] ?? 0}',
                            ),
                            _PublicStat(
                              label: 'Wealth',
                              value:
                                  '${(socialStats['wealth'] is Map ? (socialStats['wealth'] as Map)['level'] : 0) ?? 0}',
                            ),
                          ],
                        ),
                        if ((int.tryParse(user!['active_vip_level']?.toString() ?? user!['vip_level']?.toString() ?? '') ?? 0) >= 18)
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.military_tech_rounded, size: 16, color: Color(0xFFFFD36A)),
                              SizedBox(width: 4),
                              Text('King of VIP', style: TextStyle(color: Color(0xFFFFD36A), fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: OutlinedButton.icon(
                            onPressed: _showTrends,
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text('Trends (${trends.length})'),
                          ),
                        ),
                        if (!_isSelf) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: followBusy || isBlocked ? null : _toggleFollow,
                                  icon: Icon(
                                    isFollowing
                                        ? Icons.person_remove_alt_1_rounded
                                        : Icons.person_add_rounded,
                                  ),
                                  label: Text(
                                    isFollowing ? 'Following' : 'Follow',
                                  ),
                                ),
                                if (isFriend)
                                  const Chip(
                                    avatar: Icon(Icons.people_alt_rounded, size: 16),
                                    label: Text('Friends'),
                                  ),
                                OutlinedButton.icon(
                                  key: const Key('public-profile-message'),
                                  onPressed: isBlocked ? null : _openConversation,
                                  icon: const Icon(Icons.chat_bubble_rounded),
                                  label: const Text('Message'),
                                ),
                                if (isFriend)
                                  OutlinedButton.icon(
                                    key: const Key('public-profile-call'),
                                    onPressed:
                                        !isBlocked && !startingCall ? _startCall : null,
                                    icon: startingCall
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.call_rounded),
                                    label: const Text('Call'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (!_isSelf && widget.state.hasVipPrivilege('free_say_hi'))
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

  Future<void> _openConversation() async {
    final name = user?['display_name']?.toString().trim();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          state: widget.state,
          otherUserId: _resolvedUserId,
          otherName:
              name == null || name.isEmpty ? 'User $_resolvedUserId' : name,
        ),
      ),
    );
  }

  Future<void> _startCall() async {
    if (!isFriend || startingCall || !widget.state.backendConnected) return;
    setState(() => startingCall = true);
    final value = await widget.state.backend.startDirectCall(
      userId: widget.state.userId,
      receiverUserId: _resolvedUserId,
    );
    if (!mounted) return;
    setState(() => startingCall = false);
    final raw = value?['call'];
    if (value?['ok'] != true || raw is! Map) {
      final error = value?['error']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switch (error) {
              'friends_required' =>
                'Both users must be friends before calling.',
              'user_busy' => 'This user is busy on another call.',
              _ => 'Call could not be started.',
            },
          ),
        ),
      );
      return;
    }
    final call = Map<String, dynamic>.from(raw);
    final name = user?['display_name']?.toString().trim();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectCallScreen(
          state: widget.state,
          callId: call['id']?.toString() ?? '',
          peerName:
              name == null || name.isEmpty ? 'User ${widget.userId}' : name,
          initialState: call['state']?.toString() ?? 'ringing',
        ),
      ),
    );
  }

  Future<void> _toggleBlock() async {
    if (blockBusy) return;
    setState(() => blockBusy = true);
    final next = !isBlocked;
    final ok = await widget.state.backend.setUserBlocked(
      userId: widget.state.userId,
      targetUserId: _resolvedUserId,
      blocked: next,
    );
    if (!mounted) return;
    setState(() {
      blockBusy = false;
      if (ok) {
        isBlocked = next;
        if (next) {
          isFriend = false;
          isFollowing = false;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (next ? 'User blocked' : 'User unblocked')
              : 'Block setting could not be updated',
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (followBusy) return;
    setState(() => followBusy = true);
    final next = !isFollowing;
    final ok = await widget.state.backend.setUserFollow(
      userId: widget.state.userId,
      targetUserId: _resolvedUserId,
      follow: next,
    );
    if (!mounted) return;
    setState(() {
      followBusy = false;
      if (ok) isFollowing = next;
    });
    if (ok) {
      final friends = await widget.state.backend.friends(
        userId: widget.state.userId,
      );
      if (mounted) {
        setState(() {
          isFriend =
              friends.any((row) => row['id']?.toString() == _resolvedUserId);
        });
      }
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow could not be updated')),
      );
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
    final ok = await widget.state.sendVipSayHi(receiverUserId: _resolvedUserId, message: text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Free Say Hi sent' : widget.state.vipError ?? 'Could not send Say Hi')));
    setState(() {});
  }
}
