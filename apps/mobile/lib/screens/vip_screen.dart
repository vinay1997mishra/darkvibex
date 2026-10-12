import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../vip/vip_policy.dart';
import 'id_level_screen.dart';

class VipScreen extends StatelessWidget {
  const VipScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final level = state.vipLevel.clamp(0, VipPolicy.maxLevel).toInt();
        final active = state.vipActiveUntil == null ||
            state.vipActiveUntil!.isAfter(DateTime.now());
        final next = level < VipPolicy.maxLevel
            ? VipPolicy.ruleFor(level + 1)
            : VipPolicy.ruleFor(VipPolicy.maxLevel);
        final target = next?.upgradeExp ?? 1;
        final progress = level >= VipPolicy.maxLevel
            ? 1.0
            : (state.vipExpBalance / target).clamp(0.0, 1.0).toDouble();

        return Scaffold(
          backgroundColor: const Color(0xFF070707),
          appBar: AppBar(
            backgroundColor: const Color(0xFF070707),
            title: const Text('VIP'),
            actions: [
              IconButton(
                tooltip: 'Refresh VIP',
                onPressed: state.backendConnected ? state.refreshVip : null,
                icon: const Icon(Icons.refresh_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'rules') {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const VipRulesScreen(),
                      ),
                    );
                  } else if (value == 'exp') {
                    _showExp(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rules', child: Text('Rules')),
                  PopupMenuItem(value: 'exp', child: Text('My VIP Exp')),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: state.refreshVip,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              children: [
                _HeroCard(
                  level: level,
                  active: active,
                  exp: state.vipExpBalance,
                  target: target,
                  progress: progress,
                  activeUntil: state.vipActiveUntil,
                ),
                Card(
                  color: const Color(0xFF151515),
                  child: ListTile(
                    leading: const Icon(Icons.trending_up_rounded, color: Color(0xFF67D9FF)),
                    title: const Text('ID Level'),
                    subtitle: Text('Level ${state.idLevelState['level'] ?? 0}/100 • earn EXP to level up'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => IdLevelScreen(state: state),
                    )),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'VIP exclusive privileges',
                  style: TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  itemCount: VipPolicy.privileges.length,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: .82,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final privilege = VipPolicy.privileges[index];
                    final unlocked = privilege.isUnlockedAt(level) && active;
                    return _PrivilegeTile(
                      privilege: privilege,
                      unlocked: unlocked,
                      onTap: () => _showPrivilege(context, privilege, unlocked),
                    );
                  },
                ),
                if (level >= 2) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'VIP controls',
                    style: TextStyle(
                      color: Color(0xFFFFD88A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TogglePrivilege(
                    title: 'Hide Last Online',
                    subtitle: 'Hide your last-online time on the profile.',
                    value: state.vipPreference('hide_last_online'),
                    enabled: active && level >= 2,
                    onChanged: (value) =>
                        state.setVipPreference('hide_last_online', value),
                  ),
                  if (level >= 8)
                    _TogglePrivilege(
                      title: 'Hide Country',
                      subtitle: 'Hide country information from your profile.',
                      value: state.vipPreference('hide_country'),
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('hide_country', value),
                    ),
                  if (level >= 8)
                    _TogglePrivilege(
                      title: 'Disable Say Hi',
                      subtitle: 'Stop other users from starting Say Hi with you.',
                      value: state.vipPreference('disable_say_hi'),
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('disable_say_hi', value),
                    ),
                  if (level >= 10)
                    _TogglePrivilege(
                      title: 'Hide Charm Level',
                      subtitle: 'Hide your charm level on public surfaces.',
                      value: state.vipPreference('hide_charm'),
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('hide_charm', value),
                    ),
                  if (level >= 11)
                    _TogglePrivilege(
                      title: 'Hide Visitor Records',
                      subtitle: 'Hide your visitor records.',
                      value: state.vipPreference('hide_visitors'),
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('hide_visitors', value),
                    ),
                  if (level >= 11)
                    _TogglePrivilege(
                      title: 'Anonymous on Ranking List',
                      subtitle: 'Show a mysterious identity on ranking lists.',
                      value: state.vipPreference('anonymous_ranking'),
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('anonymous_ranking', value),
                    ),
                  if (level >= 14)
                    _TogglePrivilege(
                      title: 'Invisible Room Entry',
                      subtitle: 'Enter rooms without a public join notice.',
                      value: state.vipPreference('invisible_entry'),
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('invisible_entry', value),
                    ),
                  if (level >= 15)
                    _TogglePrivilege(
                      title: 'Privacy Protection',
                      subtitle: 'Protect profile and avatar media where supported.',
                      value: state.vipPreference('privacy_protection'),
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('privacy_protection', value),
                    ),
                  if (level >= 18)
                    _TogglePrivilege(
                      title: 'Anonymous Everywhere',
                      subtitle:
                          'Hide your name on game wins, banners, room history and public activity.',
                      value: state.vipAnonymousEverywhere,
                      enabled: active,
                      onChanged: (value) =>
                          state.setVipPreference('anonymous_everywhere', value),
                    ),
                ],
                if (level >= 5) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF151515),
                    child: ListTile(
                      leading: const Icon(
                        Icons.badge_rounded,
                        color: Color(0xFFFFD88A),
                      ),
                      title: const Text('Unique ID'),
                      subtitle: Text(
                        state.customVipId?.isNotEmpty == true
                            ? state.customVipId!
                            : 'Change once per month + once after each VIP level-up',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _changeId(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExp(BuildContext context) {
    final until = state.vipActiveUntil;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My VIP Exp',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Text('VIP level: ${state.vipLevel}/${VipPolicy.maxLevel}'),
            Text('Available VIP Exp: ${_compact(state.vipExpBalance)}'),
            Text('Total eligible coins received: ${_compact(state.vipTotalReceivedCoins)}'),
            Text(
              'Coin Seller EXP rate: 1 VIP EXP per coin received',
            ),
            if (until != null) Text('Active until: ${_date(until)}'),
            const SizedBox(height: 8),
            const Text(
              'Only eligible coins received into the wallet from a Coin Seller earn VIP Exp.',
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeId(BuildContext context) async {
    final controller = TextEditingController(text: state.customVipId ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Unique ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            hintText: 'Letters and numbers',
            helperText: '1 change/month + extra change after a VIP level-up',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    final result = await state.changeVipUniqueId(value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result ? 'Unique ID updated' : (state.vipError ?? 'ID change is not available yet'),
        ),
      ),
    );
  }

  void _showPrivilege(
    BuildContext context,
    VipPrivilege privilege,
    bool unlocked,
  ) {
    final levelText = privilege.maxLevel == null
        ? 'VIP${privilege.minLevel}+'
        : 'VIP${privilege.minLevel}–VIP${privilege.maxLevel}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF2B261C),
              child: Icon(
                _iconFor(privilege.id),
                size: 34,
                color: const Color(0xFFFFD88A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              privilege.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(levelText, style: const TextStyle(color: Color(0xFFFFD88A))),
            const SizedBox(height: 12),
            Text(
              privilege.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 20),
            Chip(
              avatar: Icon(
                unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 18,
              ),
              label: Text(unlocked ? 'Unlocked' : 'Locked'),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String id) => switch (id) {
        'vip_logo' => Icons.workspace_premium_rounded,
        'headframe' => Icons.account_circle_rounded,
        'display_front' => Icons.vertical_align_top_rounded,
        'view_visitors' => Icons.visibility_rounded,
        'chat_bubble' => Icons.chat_bubble_rounded,
        'hide_last_online' => Icons.schedule_rounded,
        'room_background' => Icons.wallpaper_rounded,
        'friends_limit' => Icons.group_add_rounded,
        'entrance_effect' => Icons.auto_awesome_rounded,
        'fantasy_card' => Icons.badge_rounded,
        'free_say_hi' => Icons.waving_hand_rounded,
        'picture_welcome' => Icons.photo_rounded,
        'message_roaming' => Icons.cloud_sync_rounded,
        'show_id' => Icons.badge_outlined,
        'red_envelope' => Icons.card_giftcard_rounded,
        'dynamic_avatar' => Icons.motion_photos_on_rounded,
        'many_seats' => Icons.chair_alt_rounded,
        'hide_country' => Icons.public_off_rounded,
        'nickname_light' => Icons.light_mode_rounded,
        'disable_say_hi' => Icons.front_hand_rounded,
        'entrance_vehicle' => Icons.directions_car_filled_rounded,
        'customer_service' => Icons.support_agent_rounded,
        'send_pictures' => Icons.add_photo_alternate_rounded,
        'hide_charm' => Icons.favorite_border_rounded,
        'hide_visitors' => Icons.person_off_rounded,
        'anonymous_ranking' => Icons.theater_comedy_rounded,
        'vip_news' => Icons.local_fire_department_rounded,
        'seat_protection' => Icons.chair_rounded,
        'invisible_entry' => Icons.visibility_off_rounded,
        'kick_protection' => Icons.security_rounded,
        'unique_id' => Icons.fingerprint_rounded,
        'splash_recommend' => Icons.recommend_rounded,
        'privacy_protection' => Icons.shield_rounded,
        'custom_avatar_frame' => Icons.filter_frames_rounded,
        'exclusive_mic_effect' => Icons.mic_external_on_rounded,
        'card_background' => Icons.style_rounded,
        'vip_exp_150' => Icons.trending_up_rounded,
        'customized_vehicles' => Icons.time_to_leave_rounded,
        'mic_chair' => Icons.chair_alt_rounded,
        'anonymous_everywhere' => Icons.masks_rounded,
        'honorary_title' => Icons.military_tech_rounded,
        'valid_45_days' => Icons.event_available_rounded,
        _ => Icons.star_rounded,
      };

  static String _compact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toString();
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.level,
    required this.active,
    required this.exp,
    required this.target,
    required this.progress,
    required this.activeUntil,
  });

  final int level;
  final bool active;
  final int exp;
  final int target;
  final double progress;
  final DateTime? activeUntil;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF28231B), Color(0xFF0B0B0B)],
        ),
        border: Border.all(color: const Color(0x55FFD88A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                level == 0 ? 'VIP 0' : 'VIP $level',
                style: const TextStyle(
                  fontSize: 34,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                width: 86,
                height: 86,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFFFE7A7), Color(0xFF8A6429)],
                  ),
                ),
                child: Text(
                  level == 0 ? 'VIP' : 'VIP$level',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            level >= VipPolicy.maxLevel
                ? 'Top VIP level reached'
                : '${VipScreen._compact(target - exp > 0 ? target - exp : 0)} VIP Exp to the next level',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(30),
            color: const Color(0xFFFFD88A),
            backgroundColor: Colors.white12,
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text('EXP ${VipScreen._compact(exp)}/${VipScreen._compact(target)}'),
              const Spacer(),
              Text(
                active ? 'ACTIVE' : 'EXPIRED',
                style: TextStyle(
                  color: active ? const Color(0xFF8EF0A5) : Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (activeUntil != null) ...[
            const SizedBox(height: 4),
            Text(
              'Valid until ${VipScreen._date(activeUntil!)}',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivilegeTile extends StatelessWidget {
  const _PrivilegeTile({
    required this.privilege,
    required this.unlocked,
    required this.onTap,
  });

  final VipPrivilege privilege;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xFF222222),
                  child: Icon(
                    VipScreen._iconFor(privilege.id),
                    color: unlocked ? const Color(0xFFFFD88A) : Colors.white38,
                  ),
                ),
                if (!unlocked)
                  const Positioned(
                    right: -3,
                    bottom: -3,
                    child: Icon(Icons.lock_rounded, size: 17, color: Colors.white54),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              privilege.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: unlocked ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              privilege.maxLevel == null
                  ? 'VIP${privilege.minLevel}'
                  : 'VIP${privilege.minLevel}-${privilege.maxLevel}',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePrivilege extends StatelessWidget {
  const _TogglePrivilege({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151515),
      child: SwitchListTile(
        activeThumbColor: const Color(0xFFFFD88A),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class VipRulesScreen extends StatelessWidget {
  const VipRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07070A),
        title: const Text('VIP Rules'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
        children: [
          const Text(
            'What is VIP?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'DarkVibeX VIP has 18 levels. Coins received from a Coin Seller earn exactly 1 VIP Exp per coin at every VIP level, with no monthly or total EXP cap.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          const Text(
            'Upgrade and maintain EXP',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                color: Color(0xFFFFD88A),
                fontWeight: FontWeight.w800,
              ),
              columns: const [
                DataColumn(label: Text('Level')),
                DataColumn(label: Text('Total coins')),
                DataColumn(label: Text('Upgrade EXP')),
                DataColumn(label: Text('Maintain EXP')),
                DataColumn(label: Text('Validity')),
              ],
              rows: [
                for (final item in VipPolicy.levels)
                  DataRow(
                    cells: [
                      DataCell(Text('VIP${item.level}')),
                      DataCell(Text(VipScreen._compact(item.totalRechargeCoins))),
                      DataCell(Text(VipScreen._compact(item.upgradeExp))),
                      DataCell(Text(VipScreen._compact(item.maintainExp))),
                      DataCell(Text('${item.validityDays} days')),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Validity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'VIP1–VIP17 use a 30-day active period. VIP18 uses 45 days. At expiry, the maintenance EXP for the active level is deducted when available; otherwise the account drops one VIP level and the maintainable EXP balance is cleared. Leftover EXP after a successful upgrade or maintenance remains available.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 14),
          const Text(
            'Unique ID',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'VIP5+ can change the Unique ID once each calendar month. Every VIP level-up grants one additional immediate change, even if the monthly change was already used.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }
}
