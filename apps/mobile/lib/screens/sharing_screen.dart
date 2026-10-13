import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/tinni_style.dart';

class SharingScreen extends StatelessWidget {
  const SharingScreen({
    super.key,
    required this.title,
    required this.roomId,
    this.onShared,
  });

  final String title;
  final String roomId;
  final Future<void> Function(String platform)? onShared;

  String get shareText =>
      'Join my DarkVibeX room: $title\nRoom ID: $roomId';

  Future<void> _record(String platform) async {
    try {
      await onShared?.call(platform);
    } catch (_) {}
  }

  Future<void> _systemShare(String platform) async {
    await SharePlus.instance.share(ShareParams(text: shareText));
    await _record(platform);
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: roomId));
    await _record('copy');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room ID copied.')),
    );
  }

  Future<void> _launchOrShare(
    BuildContext context, {
    required String platform,
    required Uri uri,
  }) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await _record(platform);
        return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    await _systemShare(platform);
  }

  @override
  Widget build(BuildContext context) {
    final encoded = Uri.encodeComponent(shareText);
    final telegramText = Uri.encodeComponent(
      'Join my DarkVibeX room: $title — Room ID: $roomId',
    );

    final actions = <(String, IconData, Future<void> Function())>[
      (
        'Android Share',
        Icons.share_rounded,
        () => _systemShare('system'),
      ),
      (
        'Copy Room ID',
        Icons.link_rounded,
        () => _copy(context),
      ),
      (
        'WhatsApp',
        Icons.chat_rounded,
        () => _launchOrShare(
          context,
          platform: 'whatsapp',
          uri: Uri.parse('https://wa.me/?text=$encoded'),
        ),
      ),
      (
        'Telegram',
        Icons.send_rounded,
        () => _launchOrShare(
          context,
          platform: 'telegram',
          uri: Uri.parse(
            'https://t.me/share/url?url=&text=$telegramText',
          ),
        ),
      ),
      (
        'Facebook',
        Icons.facebook_rounded,
        () => _systemShare('facebook'),
      ),
      (
        'Instagram',
        Icons.camera_alt_rounded,
        () => _systemShare('instagram'),
      ),
      (
        'Snapchat',
        Icons.photo_camera_front_rounded,
        () => _systemShare('snapchat'),
      ),
    ];

    return Scaffold(
      key: const Key('sharing-screen'),
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: const Text(
          'Share',
          style: TextStyle(
            color: TinniPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: TinniBackground(
        child: GridView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (_, index) {
            final item = actions[index];
            return TinniPanel(
              onTap: () => item.$3(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TinniGlowIcon(
                    icon: item.$2,
                    size: 30,
                    boxSize: 54,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.$1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TinniPalette.cream,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
