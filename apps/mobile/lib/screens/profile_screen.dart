import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import 'vip_screen.dart';
import 'legal_policy_screen.dart';
import 'app_settings_screen.dart';
import 'wallet_screen.dart';
import 'coin_seller_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

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
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: state.hasVipPrivilege('card_background')
                  ? const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF35204F), Color(0xFF171326), Color(0xFF4C3419)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    )
                  : null,
              child: Row(
                children: [
              Container(
                width: 76,
                height: 76,
                padding: EdgeInsets.all(
                  state.hasVipPrivilege('headframe') ? 4 : 0,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: state.hasVipPrivilege('headframe')
                      ? Border.all(
                          color: const Color(0xFFFFD36A),
                          width: 3,
                        )
                      : null,
                  boxShadow: state.hasVipPrivilege('exclusive_mic_effect')
                      ? const [
                          BoxShadow(
                            color: Color(0x66FFD36A),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: CircleAvatar(
                  backgroundImage: state.avatarKey == null
                      ? null
                      : NetworkImage(state.backend.fileUrl(state.avatarKey!)),
                  child: state.avatarKey == null
                      ? const Icon(Icons.person_rounded, size: 40)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.vipAnonymousEverywhere ? 'Anonymous' : state.displayName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: state.hasVipPrivilege('nickname_light')
                            ? const Color(0xFFFFD36A)
                            : null,
                      ),
                    ),
                    Text(
                      'ID ${state.customVipId?.isNotEmpty == true ? state.customVipId : state.userId} • VIP ${state.vipLevel}/18',
                    ),
                    if (state.hasVipPrivilege('honorary_title'))
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.military_tech_rounded, size: 16, color: Color(0xFFFFD36A)),
                            SizedBox(width: 4),
                            Text('King of VIP', style: TextStyle(color: Color(0xFFFFD36A), fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
                  IconButton(onPressed: () => _pickAvatar(context), icon: const Icon(Icons.edit_rounded)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: const Text('Wallet'),
                  subtitle: Text('${state.coins} coins • ${state.diamonds} diamonds'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => WalletScreen(state: state),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_rounded),
                  title: const Text('Coin Seller'),
                  subtitle: const Text('Coin seller tools'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => CoinSellerScreen(state: state),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded),
                  title: const Text('VIP'),
                  subtitle: Text('Level ${state.vipLevel}/18'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => VipScreen(state: state),
                    ),
                  ),
                ),
                _item(context, state, Icons.badge_rounded, 'Unique ID', state.customVipId?.isNotEmpty == true ? state.customVipId! : state.userId),
                _item(context, state, Icons.family_restroom_rounded, 'Family', 'Community and rankings'),
                _item(context, state, Icons.favorite_rounded, 'CP', 'Relationship level and gifts'),
                _item(context, state, Icons.store_rounded, 'Store', 'Frames, effects and themes'),
                _item(context, state, Icons.security_rounded, 'Privacy & Safety', 'Block, report and controls'),
                _item(context, state, Icons.settings_rounded, 'Settings', 'Language, account and app settings'),
                _item(context, state, Icons.description_outlined, 'Terms & Privacy', 'Room rules, terms and privacy notice'),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text('Sign out'),
                  subtitle: Text(state.authProvider == 'google' ? 'Google account' : 'Guest session'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: state.signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, AppState state, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon),
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
