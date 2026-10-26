import 'package:flutter/material.dart';

abstract final class TinniPalette {
  static const black = Color(0xFF030518);
  static const nearBlack = Color(0xE60A0D24);
  static const panel = Color(0xE6121230);
  static const panel2 = Color(0xE61A123A);
  static const gold = Color(0xFF8B7CFF);
  static const brightGold = Color(0xFF50D8FF);
  static const deepGold = Color(0xFF5146A8);
  static const bronze = Color(0xFF37376F);
  static const cream = Color(0xFFF0F2FF);
  static const muted = Color(0xFFA5B0D8);
  static const danger = Color(0xFFB95E5B);
}


/// Semantic, non-yellow accent colours used for DarkVibeX feature logos.
abstract final class DarkVibeXIconPalette {
  static const cyan = Color(0xFF53D9FF);
  static const electricBlue = Color(0xFF4BA8FF);
  static const violet = Color(0xFF8B7CFF);
  static const lavender = Color(0xFFBFA7FF);
  static const pink = Color(0xFFFF83D8);
  static const mint = Color(0xFF62FFD1);
  static const coral = Color(0xFFFF6F91);

  static DarkVibeXIconAccent forIcon(IconData icon) {
    if (icon == Icons.groups_rounded ||
        icon == Icons.group_rounded ||
        icon == Icons.mic_rounded ||
        icon == Icons.mic_external_on_rounded ||
        icon == Icons.headset_mic_rounded ||
        icon == Icons.meeting_room_rounded) {
      return const DarkVibeXIconAccent(cyan, electricBlue);
    }
    if (icon == Icons.explore_rounded ||
        icon == Icons.search_rounded ||
        icon == Icons.navigation_rounded ||
        icon == Icons.auto_awesome_rounded) {
      return const DarkVibeXIconAccent(violet, lavender);
    }
    if (icon == Icons.mail_rounded ||
        icon == Icons.chat_rounded ||
        icon == Icons.chat_bubble_rounded ||
        icon == Icons.forum_rounded ||
        icon == Icons.send_rounded ||
        icon == Icons.sms_rounded) {
      return const DarkVibeXIconAccent(electricBlue, cyan);
    }
    if (icon == Icons.call_rounded ||
        icon == Icons.call_end_rounded ||
        icon == Icons.call_made_rounded ||
        icon == Icons.call_received_rounded) {
      return const DarkVibeXIconAccent(mint, cyan);
    }
    if (icon == Icons.person_rounded ||
        icon == Icons.face_rounded ||
        icon == Icons.account_circle_rounded ||
        icon == Icons.badge_rounded) {
      return const DarkVibeXIconAccent(pink, violet);
    }
    if (icon == Icons.favorite_rounded ||
        icon == Icons.card_giftcard_rounded ||
        icon == Icons.redeem_rounded ||
        icon == Icons.favorite_border_rounded) {
      return const DarkVibeXIconAccent(pink, coral);
    }
    if (icon == Icons.diamond_rounded ||
        icon == Icons.workspace_premium_rounded ||
        icon == Icons.military_tech_rounded ||
        icon == Icons.emoji_events_rounded ||
        icon == Icons.rocket_launch_rounded ||
        icon == Icons.stars_rounded) {
      return const DarkVibeXIconAccent(violet, cyan);
    }
    if (icon == Icons.account_balance_wallet_rounded ||
        icon == Icons.currency_exchange_rounded ||
        icon == Icons.monetization_on_rounded ||
        icon == Icons.payments_rounded) {
      return const DarkVibeXIconAccent(cyan, electricBlue);
    }
    if (icon == Icons.notifications_rounded ||
        icon == Icons.notifications_active_rounded ||
        icon == Icons.notifications_none_rounded) {
      return const DarkVibeXIconAccent(lavender, electricBlue);
    }
    if (icon == Icons.settings_rounded ||
        icon == Icons.tune_rounded ||
        icon == Icons.build_rounded) {
      return const DarkVibeXIconAccent(electricBlue, violet);
    }
    return const DarkVibeXIconAccent(violet, cyan);
  }
}

class DarkVibeXIconAccent {
  const DarkVibeXIconAccent(this.primary, this.secondary);

  final Color primary;
  final Color secondary;
}

ThemeData buildTinniStyleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TinniPalette.gold,
    brightness: Brightness.dark,
    primary: TinniPalette.gold,
    secondary: TinniPalette.brightGold,
    surface: TinniPalette.panel,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xB3080B20),
      foregroundColor: TinniPalette.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: TinniPalette.nearBlack,
      indicatorColor: TinniPalette.gold.withValues(alpha: .14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? TinniPalette.gold
              : TinniPalette.muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? TinniPalette.gold
              : TinniPalette.muted,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: TinniPalette.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: TinniPalette.bronze),
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TinniPalette.nearBlack,
      labelStyle: const TextStyle(color: TinniPalette.gold),
      hintStyle: const TextStyle(color: TinniPalette.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TinniPalette.bronze),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TinniPalette.gold, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TinniPalette.gold,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TinniPalette.gold,
        side: const BorderSide(color: TinniPalette.deepGold),
      ),
    ),
    dividerColor: TinniPalette.bronze,
  );
}

class TinniGlowIcon extends StatelessWidget {
  const TinniGlowIcon({
    super.key,
    required this.icon,
    this.size = 20,
    this.boxSize = 36,
    this.accentColor,
    this.secondaryColor,
  });

  final IconData icon;
  final double size;
  final double boxSize;
  final Color? accentColor;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final semantic = DarkVibeXIconPalette.forIcon(icon);
    final primary = accentColor ?? semantic.primary;
    final secondary = secondaryColor ?? semantic.secondary;

    return Container(
      width: boxSize,
      height: boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: primary.withValues(alpha: .68)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .22),
            blurRadius: 12,
          ),
          BoxShadow(
            color: secondary.withValues(alpha: .10),
            blurRadius: 16,
          ),
        ],
        gradient: RadialGradient(
          colors: [
            primary.withValues(alpha: .24),
            secondary.withValues(alpha: .15),
            Colors.transparent,
          ],
          stops: const [0, .58, 1],
        ),
      ),
      child: Icon(icon, color: primary, size: size),
    );
  }
}

class TinniPanel extends StatelessWidget {
  const TinniPanel({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.radius = 14,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE6161740), Color(0xD90A0D28)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: TinniPalette.bronze),
        boxShadow: const [
          BoxShadow(color: Color(0x442F36FF), blurRadius: 10),
          BoxShadow(color: Color(0x332A0B54), blurRadius: 16),
        ],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: body,
    );
  }
}

class DarkVibeXGlobalBackground extends StatelessWidget {
  const DarkVibeXGlobalBackground({
    super.key,
    required this.child,
  });

  static const assetPath = 'assets/images/darkvibex_global_bg.webp';

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: TinniPalette.black,
          image: DecorationImage(
            image: AssetImage(assetPath),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x2601061A),
                Color(0x120A0B28),
                Color(0x42020518),
              ],
              stops: [0, .48, 1],
            ),
          ),
          child: child,
        ),
      );
}

class TinniBackground extends StatelessWidget {
  const TinniBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
