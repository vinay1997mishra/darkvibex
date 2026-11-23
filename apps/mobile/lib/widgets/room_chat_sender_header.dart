import 'package:flutter/material.dart';

import 'vip_animated_frame.dart';
import 'vip_name_text.dart';
import 'vip_tag_image.dart';
import 'role_tag_image.dart';
import 'level_tag.dart';

/// Sender identity shown above each room chat bubble.
///
/// Message text and images stay inside the bubble; profile data, Owner Panel
/// tags and earned medals are kept in this separate header.
class RoomChatSenderHeader extends StatelessWidget {
  const RoomChatSenderHeader({
    super.key,
    required this.displayName,
    required this.tags,
    required this.medals,
    this.avatarUrl,
    this.avatarHeaders,
    this.avatarAsset,
    this.vipLevel = 0,
    this.dollarLevel = 0,
    this.idLevel,
    this.roleTag,
    this.frameAssetUrl,
    this.frameVideoUrl,
    this.onAvatarTap,
  });

  final String displayName;
  final String? avatarUrl;
  final Map<String, String>? avatarHeaders;

  /// Bundled asset used as the DP instead of [avatarUrl] — system
  /// messages (the DarkVibeX welcome row) have no network avatar.
  /// Null = the network DP (or the fallback icon when that is empty).
  final String? avatarAsset;

  /// Fired when the sender's avatar (DP) is tapped — the room chat opens
  /// the sender's profile card. Null = the avatar is not tappable.
  final VoidCallback? onAvatarTap;

  /// Sender's active VIP level (0 = none). Drives the golden "VIP N"
  /// text (VIP1-18) next to the name and the frame level.
  final int vipLevel;

  /// Sender's wealth level (0 = none). Wealth IS the dollar level
  /// (Vinay, 2026-11-23) — one gold-$ tag next to the name, 3D + glow,
  /// colour changing every 10 levels. 0 = no tag.
  final int dollarLevel;

  /// Sender's ID level (null = not sent by the server, e.g. an old
  /// cached message). Drives the "Lv.N" pill next to the name; when
  /// null the number is parsed from the level medal's name instead.
  final int? idLevel;

  /// The owner-assigned role-tag slug for the sender, e.g.
  /// 'coin-seller' (from the message's `role_tag`). Drives the role
  /// tag next to the name; null = no tag assigned to this ID.
  final String? roleTag;

  /// Direct URL of the sender's frame image (already resolved to a
  /// direct R2 URL by the caller). Empty/null = no frame on the avatar.
  final String? frameAssetUrl;

  /// Direct R2 URL of the sender's Tencent VAP alpha-video for the
  /// frame (vap/vip<N>-<animal>.mp4). Null/empty = no video: the PNG
  /// still is shown directly. Only the animal frames (VIP5-18) have one.
  final String? frameVideoUrl;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> medals;

  Color _color(dynamic value, {Color fallback = Colors.white70}) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return fallback;
    final hex = raw.replaceFirst('#', '');
    try {
      if (hex.length == 6) return Color(0xFF000000 | int.parse(hex, radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
    return fallback;
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF29365D),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 18,
        color: Colors.white70,
      ),
    );
  }

  Widget _avatar() {
    final String asset = avatarAsset?.trim() ?? '';
    final String url = avatarUrl?.trim() ?? '';
    final Widget avatar;
    if (asset.isNotEmpty) {
      avatar = SizedBox(
        width: 28,
        height: 28,
        child: ClipOval(
          child: Image.asset(
            asset,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (url.isEmpty) {
      avatar = _fallbackAvatar();
    } else {
      avatar = SizedBox(
        width: 28,
        height: 28,
        child: ClipOval(
          child: Image.network(
            url,
            headers: avatarHeaders,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackAvatar(),
          ),
        ),
      );
    }
    // The frame auto-sizes to the 28px chat avatar (VipAnimatedFrame.auto
    // measures the avatar at runtime). No frame when frameAssetUrl is empty.
    final String frameUrl = frameAssetUrl?.trim() ?? '';
    return frameUrl.isEmpty
        ? avatar
        : VipAnimatedFrame.auto(
            enabled: true,
            level: vipLevel,
            assetUrl: frameUrl,
            videoUrl: frameVideoUrl,
            child: avatar,
          );
  }

  Widget _tagChip(Map<String, dynamic> tag) {
    final name = tag['name']?.toString().trim() ?? '';
    final designation = tag['designation']?.toString().trim() ?? '';
    final label = [name, designation]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    if (label.isEmpty) return const SizedBox.shrink();

    final foreground = _color(tag['color']);
    final background = _color(
      tag['background_color'],
      fallback: foreground.withValues(alpha: .16),
    );
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: foreground.withValues(alpha: .72), width: .7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  IconData _medalIcon(String id) => switch (id) {
        'vip' => Icons.workspace_premium_rounded,
        'gifter' => Icons.card_giftcard_rounded,
        'charm' => Icons.favorite_rounded,
        'level' => Icons.military_tech_rounded,
        _ => Icons.emoji_events_rounded,
      };

  Widget _medalChip(Map<String, dynamic> medal) {
    final name = medal['name']?.toString().trim() ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    final color = _color(medal['color'], fallback: const Color(0xFFFFD36A));
    return Container(
      constraints: const BoxConstraints(maxWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .58), width: .7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _medalIcon(medal['id']?.toString() ?? ''),
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().isEmpty ? 'User' : displayName.trim();
    // Role badges are icons in the name row, not text chips (Vinay,
    // 2026-11-23): the room owner gets a red house, a room admin a blue
    // shield, and neither shows its name as text.
    final isRoomOwner =
        tags.any((tag) => tag['id']?.toString() == 'room-owner');
    final isRoomAdmin =
        tags.any((tag) => tag['id']?.toString() == 'room-admin');
    // The VIP level already shows as gold "VIP N" text next to the name
    // (VipTagImage), so the "VIP N" tag and the "VIP" medal are filtered
    // out here instead of repeating below.
    final visibleTags = tags.where((tag) {
      final id = tag['id']?.toString() ?? '';
      if (id == 'room-owner' || id == 'room-admin' || id == 'active-vip') {
        return false;
      }
      return (tag['name']?.toString().trim().isNotEmpty ?? false) ||
          (tag['designation']?.toString().trim().isNotEmpty ?? false);
    }).toList(growable: false);
    // The ID Level medal renders as the 3D "Lv.N" pill next to the name
    // (Vinay, 2026-11-23), not a ribbon chip. The numeric level comes
    // from the server (idLevel); old cached messages carry only the
    // medal name ("ID Level N"), so the number is parsed from it as a
    // fallback. If neither gives a number, the plain text stays below.
    final levelMedal = medals.firstWhere(
      (medal) => medal['id']?.toString() == 'level',
      orElse: () => const <String, dynamic>{},
    );
    final levelName = levelMedal['name']?.toString().trim() ?? '';
    final parsedLevel = int.tryParse(
      RegExp(r'(\d+)').firstMatch(levelName)?.group(1) ?? '',
    );
    final idLevelNumber =
        (idLevel ?? 0) > 0 ? idLevel! : (parsedLevel ?? 0);
    final visibleMedals = medals.where((medal) {
      final id = medal['id']?.toString() ?? '';
      // The written "Charm" tag is removed permanently (Vinay,
      // 2026-11-23): only the wealth and dollar tags stay.
      if (id == 'vip' || id == 'level' || id == 'charm') return false;
      return medal['name']?.toString().trim().isNotEmpty == true;
    }).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Like other live apps, the whole sender line (DP + name) opens
        // the profile card; the tag/medal chips below stay untappable.
        GestureDetector(
          onTap: onAvatarTap,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              _avatar(),
              const SizedBox(width: 6),
              Expanded(
                child: VipNameText(
                  name: name,
                  vipLevel: vipLevel,
                  textKey: const Key('room-chat-sender-name'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    shadows: <Shadow>[
                      Shadow(color: Colors.black87, blurRadius: 4),
                    ],
                  ),
                ),
              ),
              // Golden "VIP N" text (no ribbon plaque), sized from the
              // 11pt name text. VipTagImage renders nothing below VIP1.
              if (vipLevel >= 1) ...<Widget>[
                const SizedBox(width: 4),
                VipTagImage(vipLevel: vipLevel, fontSize: 11),
              ],
              // Room owner: a red house, no "Room Owner" text.
              if (isRoomOwner) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(
                  Icons.home_rounded,
                  color: Colors.red,
                  size: 14,
                ),
              ],
              // Room admin: a blue shield, no "admin" text.
              if (isRoomAdmin) ...<Widget>[
                const SizedBox(width: 4),
                const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF73CFFF),
                  size: 14,
                ),
              ],
              // Wealth tag: gold $ + dollar level, 3D + glow, colour
              // every 10 levels (Vinay, 2026-11-23). WealthTag renders
              // nothing at level 0.
              if (dollarLevel > 0) ...<Widget>[
                const SizedBox(width: 4),
                WealthTag(level: dollarLevel, fontSize: 11),
              ],
              // ID Level pill: "Lv.N", 3D + glow, emblem + colour every
              // 10 levels (Vinay, 2026-11-23). IdLevelTag renders
              // nothing at level 0.
              if (idLevelNumber > 0) ...<Widget>[
                const SizedBox(width: 4),
                IdLevelTag(level: idLevelNumber, fontSize: 11),
              ],
              // Role tag (owner-assigned), sized from the 11pt name text.
              const SizedBox(width: 4),
              RoleTagImage(roleTag: roleTag, fontSize: 11),
            ],
          ),
        ),
        if (visibleTags.isNotEmpty ||
            visibleMedals.isNotEmpty ||
            (idLevelNumber <= 0 && levelName.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 3),
            child: Wrap(
              spacing: 4,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // ID Level as plain blue text — only when the pill could
                // not be built (no numeric level anywhere).
                if (idLevelNumber <= 0 && levelName.isNotEmpty)
                  Text(
                    levelName,
                    style: const TextStyle(
                      color: Color(0xFF45AAF2),
                      fontSize: 9,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                for (final tag in visibleTags) _tagChip(tag),
                for (final medal in visibleMedals) _medalChip(medal),
              ],
            ),
          ),
      ],
    );
  }
}
