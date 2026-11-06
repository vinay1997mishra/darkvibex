import 'package:flutter/material.dart';

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
  });

  final String displayName;
  final String? avatarUrl;
  final Map<String, String>? avatarHeaders;
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
    final url = avatarUrl?.trim() ?? '';
    if (url.isEmpty) return _fallbackAvatar();
    return SizedBox(
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
    final visibleTags = tags.where((tag) {
      return (tag['name']?.toString().trim().isNotEmpty ?? false) ||
          (tag['designation']?.toString().trim().isNotEmpty ?? false);
    }).toList(growable: false);
    final visibleMedals = medals
        .where((medal) => medal['name']?.toString().trim().isNotEmpty == true)
        .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            _avatar(),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                key: const Key('room-chat-sender-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          ],
        ),
        if (visibleTags.isNotEmpty || visibleMedals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 3),
            child: Wrap(
              spacing: 4,
              runSpacing: 3,
              children: [
                for (final tag in visibleTags) _tagChip(tag),
                for (final medal in visibleMedals) _medalChip(medal),
              ],
            ),
          ),
      ],
    );
  }
}
