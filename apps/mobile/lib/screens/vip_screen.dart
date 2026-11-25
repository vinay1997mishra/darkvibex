import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../vip/vip_policy.dart';
import '../vip/vip_visual_assets.dart';
import 'vip_support_screen.dart';
import 'medal_gallery_screen.dart';
import '../widgets/vip_animated_frame.dart';
import '../widgets/vip_badge_video.dart';
import '../widgets/vip_entry_effect_banner.dart';

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
        // VIP page rule (Vinay, 2026-11-19): show ONLY the privileges
        // the user has at their level, cumulative (VIP1's + VIP2's +
        // ... up to their level). Higher-level privileges must NOT
        // appear at all — not even as locked tiles.
        final shownPrivileges = VipPolicy.unlockedAt(level);

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
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
                const SizedBox(height: 12),
                _DailyRewardCard(state: state),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MedalGalleryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('VIP & Rocket Medal Collection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDAD0FF),
                    side: const BorderSide(color: Color(0x665B65D8)),
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  ),
                ),
                if (state.hasVipPrivilege('customer_service')) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.support_agent_rounded,
                        color: Color(0xFF9D7BFF),
                      ),
                      title: const Text('VIP Customer Service'),
                      subtitle: const Text('Private VIP support tickets'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VipSupportScreen(state: state),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _IdentificationSection(
                  level: level,
                  active: active,
                  activeUntil: state.vipActiveUntil,
                  avatarUrl: state.avatarKey?.isNotEmpty == true
                      ? state.backend.fileUrl(state.avatarKey!)
                      : null,
                  onShowExp: () => _showExp(context),
                ),
                const SizedBox(height: 20),
                const Text(
                  'VIP exclusive privileges',
                  style: TextStyle(
                    color: Color(0xFF9D7BFF),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  itemCount: shownPrivileges.length,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: .82,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final privilege = shownPrivileges[index];
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
                      color: Color(0xFF9D7BFF),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        color: Color(0xFF9D7BFF),
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
              'Coin Seller EXP rate: 150 VIP EXP per \$1 of coins bought',
            ),
            if (until != null) Text('Active until: ${_date(until)}'),
            const SizedBox(height: 8),
            const Text(
              'Only coins bought from a Coin Seller earn VIP Exp. Spending coins on gifts does not earn EXP.',
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
                color: const Color(0xFF9D7BFF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              privilege.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(levelText, style: const TextStyle(color: Color(0xFF9D7BFF))),
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
        'room_background' => Icons.wallpaper_rounded,
        'entrance_effect' => Icons.auto_awesome_rounded,
        'fantasy_card' => Icons.badge_rounded,
        'free_say_hi' => Icons.waving_hand_rounded,
        'picture_welcome' => Icons.photo_rounded,
        'message_roaming' => Icons.cloud_sync_rounded,
        'show_id' => Icons.badge_outlined,
        'red_envelope' => Icons.card_giftcard_rounded,
        'dynamic_avatar' => Icons.motion_photos_on_rounded,
        'hide_country' => Icons.public_off_rounded,
        'nickname_light' => Icons.light_mode_rounded,
        'disable_say_hi' => Icons.front_hand_rounded,
        'entrance_vehicle' => Icons.directions_car_filled_rounded,
        'customer_service' => Icons.support_agent_rounded,
        'send_pictures' => Icons.add_photo_alternate_rounded,
        'hide_charm' => Icons.favorite_border_rounded,
        'hide_visitors' => Icons.person_off_rounded,
        'anonymous_ranking' => Icons.theater_comedy_rounded,
        'seat_protection' => Icons.chair_rounded,
        'invisible_entry' => Icons.visibility_off_rounded,
        'kick_protection' => Icons.security_rounded,
        'unique_id' => Icons.fingerprint_rounded,
        'privacy_protection' => Icons.shield_rounded,
        'custom_avatar_frame' => Icons.filter_frames_rounded,
        'exclusive_mic_effect' => Icons.mic_external_on_rounded,
        'card_background' => Icons.style_rounded,
        'vip_exp_150' => Icons.trending_up_rounded,
        'customized_vehicles' => Icons.time_to_leave_rounded,
        'mic_chair' => Icons.chair_alt_rounded,
        'anonymous_everywhere' => Icons.masks_rounded,
        'honorary_title' => Icons.military_tech_rounded,
        'exp_boost_1_1x' => Icons.trending_up_rounded,
        'daily_rewards' => Icons.calendar_month_rounded,
        'exp_boost_1_2x' => Icons.trending_up_rounded,
        'coins_bonus_5' => Icons.monetization_on_rounded,
        'name_colour' => Icons.format_color_text_rounded,
        'gift_discount_10' => Icons.local_offer_rounded,
        'priority_message' => Icons.priority_high_rounded,
        'vip_only_rooms' => Icons.meeting_room_rounded,
        'exp_boost_1_4x' => Icons.trending_up_rounded,
        'coins_bonus_10' => Icons.monetization_on_rounded,
        'anti_mute' => Icons.mic_off_rounded,
        'gift_discount_20' => Icons.local_offer_rounded,
        'exp_boost_1_5x' => Icons.trending_up_rounded,
        'coins_bonus_20' => Icons.monetization_on_rounded,
        'gift_discount_30' => Icons.local_offer_rounded,
        'valid_60_days' => Icons.event_available_rounded,
        _ => Icons.star_rounded,
      };

  static String _compact(num value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(1);
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
  final num exp;
  final num target;
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
              // Metallic gold "VIP N" (Vinay, 2026-11-19): a real gold
              // gradient (deep gold -> bright gold -> pale highlight),
              // not flat yellow. ShaderMask srcIn paints the gradient
              // through the white glyphs.
              ShaderMask(
                shaderCallback: (Rect bounds) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFFB8860B),
                    Color(0xFFFFD700),
                    Color(0xFFFFF3B0),
                    Color(0xFFFFC125),
                    Color(0xFFB8860B),
                  ],
                  stops: <double>[0.0, 0.3, 0.5, 0.7, 1.0],
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  level == 0 ? 'VIP 0' : 'VIP $level',
                  style: const TextStyle(
                    fontSize: 34,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              // VIP badge video (Vinay, 2026-11-19): the premium 3D
              // animated badge plays on the RIGHT SIDE next to the
              // "VIP N" text + EXP, BIG (150px, replacing the 86px
              // LevelMedal slot). It plays once and falls back to the
              // LevelMedal SVG on completion/error — never a black box.
              if (level > 0)
                VipBadgeVideo.forVipLevel(level: level, size: 150)
              else
                Container(
                  width: 150,
                  height: 150,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF7B82C9), Color(0xFF282B5A)],
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 42,
                    color: Color(0xFFE8E3FF),
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
            color: const Color(0xFF9D7BFF),
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

/// Identification section (Vinay, 2026-11-19): the three identity
/// items grouped together under one heading, like other VIP pages —
/// Membership (the VIP membership card), Customized Avatar Frame (the
/// user's frame with their DP inside it) and Entrance Effects (the
/// entry banner). Tapping a card shows a bigger preview.
class _DailyRewardCard extends StatelessWidget {
  const _DailyRewardCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final level = state.vipLevel.clamp(0, VipPolicy.maxLevel).toInt();
    final locked = !state.vipIsActive || level < 5;
    final claimed = state.dailyRewardClaimedToday;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
              const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFFFFD88A),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daily Rewards',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (claimed)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF7ED491),
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Claimed',
                      style: TextStyle(
                        color: Color(0xFF7ED491),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (locked)
            const Text(
              'Unlocks at VIP 5 — claim coins every day.',
              style: TextStyle(color: Color(0xFFDAD0FF)),
            )
          else if (claimed)
            Text(
              'Claimed today: +${_formatCoins(state.dailyRewardClaimedCoins)} coins.',
              style: const TextStyle(color: Color(0xFFDAD0FF)),
            )
          else
            Text(
              'Today: ${_formatCoins(state.dailyRewardAmount)} coins',
              style: const TextStyle(
                color: Color(0xFFFFD88A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (!locked && !claimed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.dailyRewardLoading
                    ? null
                    : () async {
                        final ok = await state.claimDailyReward();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                state.vipError ??
                                    'Daily reward could not be claimed.',
                              ),
                            ),
                          );
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                child: state.dailyRewardLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Claim',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatCoins(int value) {
  final text = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return (value < 0 ? '-' : '') + buffer.toString();
}

class _IdentificationSection extends StatelessWidget {
  const _IdentificationSection({
    required this.level,
    required this.active,
    required this.activeUntil,
    required this.avatarUrl,
    required this.onShowExp,
  });

  final int level;
  final bool active;
  final DateTime? activeUntil;
  final String? avatarUrl;
  final VoidCallback onShowExp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✨ Identification',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _IdentificationCard(
                title: 'Membership',
                onTap: onShowExp,
                child: _MembershipPreview(
                  level: level,
                  active: active,
                  activeUntil: activeUntil,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _IdentificationCard(
                title: 'Customized Avatar Frame',
                onTap: () => _showFramePreview(context),
                child: _FramePreview(level: level, avatarUrl: avatarUrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _IdentificationCard(
                title: 'Entrance Effects',
                onTap: () => _showEntryPreview(context),
                child: _EntryPreview(level: level, avatarUrl: avatarUrl),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFramePreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text('VIP $level Avatar Frame'),
        content: Center(
          heightFactor: 1,
          child: _FramePreview(
            level: level,
            avatarUrl: avatarUrl,
            radius: 60,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEntryPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          level >= 5 ? 'VIP $level Entrance Effect' : 'Entrance Effects',
        ),
        content: level >= 5
            ? VipEntryEffectBanner(vipLevel: level, avatarUrl: avatarUrl)
            : const Text(
                'Entrance effects unlock at VIP 5.',
                style: TextStyle(color: Colors.white70),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _IdentificationCard extends StatelessWidget {
  const _IdentificationCard({
    required this.title,
    required this.child,
    required this.onTap,
  });

  final String title;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x66D4AF37)),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Gold VIP membership card: metallic gold "VIP N" + validity.
class _MembershipPreview extends StatelessWidget {
  const _MembershipPreview({
    required this.level,
    required this.active,
    required this.activeUntil,
  });

  final int level;
  final bool active;
  final DateTime? activeUntil;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFB8860B),
                Color(0xFFFFD700),
                Color(0xFFFFF3B0),
                Color(0xFFFFC125),
              ],
              stops: <double>[0.0, 0.35, 0.6, 1.0],
            ),
          ),
          child: Column(
            children: [
              Text(
                'VIP $level',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3A2A00),
                ),
              ),
              const Text(
                'MEMBER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: Color(0xFF5A4200),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          level <= 0
              ? 'Not a VIP member yet'
              : active
                  ? 'Valid until ${activeUntil == null ? '—' : VipScreen._date(activeUntil!)}'
                  : 'Expired',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

/// The user's avatar frame with their DP inside it (the DP sits
/// BEHIND the frame, showing through the frame's transparent centre —
/// never on top of the frame).
class _FramePreview extends StatelessWidget {
  const _FramePreview({
    required this.level,
    required this.avatarUrl,
    this.radius = 30,
  });

  final int level;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF29365D),
      backgroundImage:
          avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Icon(
              Icons.person_rounded,
              size: radius,
              color: Colors.white70,
            )
          : null,
    );
    if (level <= 0) return avatar;
    return VipAnimatedFrame.auto(
      level: level,
      assetUrl: vipFrameStillUrlForVipLevel(level),
      videoUrl: vipFrameVapUrlForVipLevel(level),
      child: avatar,
    );
  }
}

/// The user's entry banner (VIP5-18). Below VIP 5 there is no entry
/// banner, so a note is shown instead of an empty box.
class _EntryPreview extends StatelessWidget {
  const _EntryPreview({required this.level, required this.avatarUrl});

  final int level;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (level < 5) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Unlocks at VIP 5',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      );
    }
    return VipEntryEffectBanner(vipLevel: level, avatarUrl: avatarUrl);
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
                    color: unlocked ? const Color(0xFF9D7BFF) : Colors.white38,
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
        activeThumbColor: const Color(0xFF9D7BFF),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
            'DarkVibeX VIP has 18 levels. You earn VIP EXP only by buying coins from a Coin Seller — 150 EXP per \$1 spent (\$1 = 8,000,000 coins). Spending coins on gifts does not earn EXP. VIP lasts 1 month (VIP16–18: 2 months) from the day you level up; on the expiry date you either level up by buying more coins or drop by 1 level.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          const Text(
            'Upgrade EXP by level',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                color: Color(0xFF9D7BFF),
                fontWeight: FontWeight.w800,
              ),
              columns: const [
                DataColumn(label: Text('Level')),
                DataColumn(label: Text('Upgrade EXP')),
                DataColumn(label: Text('Total EXP')),
                DataColumn(label: Text('Validity')),
              ],
              rows: [
                for (final item in VipPolicy.levels)
                  DataRow(
                    cells: [
                      DataCell(Text('VIP${item.level}')),
                      DataCell(Text(VipScreen._compact(item.upgradeExp))),
                      DataCell(Text(VipScreen._compact(item.totalExp))),
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
            'VIP1–VIP17 use a 30-day active period. VIP18 uses 45 days. Every VIP level-up resets EXP to 0; extra EXP does not carry into the next level. At expiry, the maintenance EXP for the active level is deducted when available; otherwise the account drops one VIP level and the maintainable EXP balance is cleared.',
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
