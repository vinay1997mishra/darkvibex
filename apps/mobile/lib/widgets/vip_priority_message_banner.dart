import 'package:material_ui/material_ui.dart';

import '../vip/vip_visual_assets.dart';
import 'vip_name_text.dart';

/// The latest VIP9+ text message in a room, pinned at the top of the
/// room chat (Vinay, 2026-11-20): "Your messages appear at the top in
/// crowded rooms." Only text messages qualify — below VIP9, empty
/// text, image-only messages and panda emote markers never pin.
Map<String, dynamic>? latestPriorityMessage(
  List<Map<String, dynamic>> chat,
) {
  for (final message in chat.reversed) {
    final level =
        int.tryParse(message['active_vip_level']?.toString() ?? '') ?? 0;
    if (level < 9) continue;
    final text = message['text']?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    if (pandaEmoteNameFromMarker(text) != null) continue;
    return message;
  }
  return null;
}

/// Pinned strip at the top of the room chat showing [message] — the
/// latest VIP9+ message. The sender's name shows in their VIP colour
/// (VipNameText); tapping X hides it until a newer priority message
/// arrives.
class VipPriorityMessageBanner extends StatelessWidget {
  const VipPriorityMessageBanner({
    super.key,
    required this.message,
    required this.onDismissed,
  });

  final Map<String, dynamic> message;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final name = message['display_name']?.toString().trim() ?? '';
    final text = message['text']?.toString().trim() ?? '';
    final vipLevel =
        int.tryParse(message['active_vip_level']?.toString() ?? '') ?? 0;
    return Container(
      key: const Key('vip-priority-banner'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PRIORITY',
              style: TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                VipNameText(
                  name: name.isEmpty ? 'User' : name,
                  vipLevel: vipLevel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  key: const Key('vip-priority-banner-text'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            key: const Key('vip-priority-banner-close'),
            onTap: onDismissed,
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
