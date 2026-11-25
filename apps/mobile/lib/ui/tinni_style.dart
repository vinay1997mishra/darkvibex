import 'package:flutter/material.dart';

abstract final class TinniPalette {
  static const black = Color(0xFF030518);
  static const nearBlack = Color(0xE60A0D24);
  static const panel = Color(0xE6121230);
  static const panel2 = Color(0xE61A123A);
  static const gold = Color(0xFF8B7CFF);
  static const brightGold = Color(0xFF9D7BFF);
  static const deepGold = Color(0xFF5146A8);
  static const bronze = Color(0xFF37376F);
  static const cream = Color(0xFFF0F2FF);
  static const muted = Color(0xFFA5B0D8);
  static const danger = Color(0xFFB95E5B);

  /// Family level colours (Mr. Wrong, 2026-11-23): every family level
  /// has its own colour — sampled from the family medal art on R2
  /// (medals/family-lv01..lv10.png). Index = level - 1.
  static const familyLevelColors = [
    Color(0xFF8D5D32), // L1 bronze
    Color(0xFFC3C1B8), // L2 silver
    Color(0xFFCEB055), // L3 gold
    Color(0xFFA057C3), // L4 purple
    Color(0xFFC35151), // L5 red
    Color(0xFF588AC3), // L6 blue
    Color(0xFF58C369), // L7 green
    Color(0xFFCE5692), // L8 pink
    Color(0xFFCE7F44), // L9 orange
    Color(0xFF58BAC3), // L10 cyan
  ];

  static Color familyLevelColor(int level) {
    if (level < 1) return familyLevelColors[0];
    if (level > familyLevelColors.length) return familyLevelColors.last;
    return familyLevelColors[level - 1];
  }
}

/// Semantic, non-yellow accent colours used for DarkVibeX feature logos.
abstract final class DarkVibeXIconPalette {
  static const cyan = Color(0xFFAB8CFF);
  static const electricBlue = Color(0xFF7E57C2);
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

/// Light purple-gold glass theme (Mr. Wrong, 2026-11-25): the whole
/// app uses the new light look — dark text on the purple-gold glass
/// background. The dark theme below (buildTinniStyleTheme) stays for
/// the voice room only: RoomScreen is wrapped in it at every push
/// site, so the room main background is untouched.
ThemeData buildLightTinniStyleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TinniPalette.gold,
    brightness: Brightness.light,
    primary: TinniPalette.deepGold,
    secondary: TinniPalette.brightGold,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
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
      // Black glass (Mr. Wrong, 2026-11-25): the VIP black-glass card
      // style everywhere — dark translucent black, gold border.
      color: const Color(0xA6000000),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE8C96A)),
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xF2FFFFFF),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFF2A2140),
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: TextStyle(color: Color(0xFF4A4458), fontSize: 14),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFFE8C96A), width: 1.2),
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xF2FFFFFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFFE8C96A)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: TinniPalette.deepGold),
      hintStyle: const TextStyle(color: Color(0xFF6E6880)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8C96A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TinniPalette.deepGold, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFE8A91C),
        foregroundColor: const Color(0xFF5A3E00),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TinniPalette.deepGold,
        side: const BorderSide(color: TinniPalette.deepGold),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF2A2140),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    dividerColor: TinniPalette.bronze,
  );
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
          BoxShadow(color: primary.withValues(alpha: .22), blurRadius: 12),
          BoxShadow(color: secondary.withValues(alpha: .10), blurRadius: 16),
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
    // Black glass 3D panel (Mr. Wrong, 2026-11-25): the VIP black-glass
    // card style everywhere — dark translucent black (the page background
    // shows faintly through), gold border, top gloss highlight and bottom
    // shadow. Text inside panels is light (gold titles, cream body) — the
    // DefaultTextStyle below covers unstyled text; explicitly dark text
    // was flipped per file when the panels went black.
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        // Single-colour gradient, NOT a solid color: a solid
        // `BoxDecoration.color` makes Flutter's ListTile debug check fire
        // ("background color or ink splashes may be invisible") for the
        // ListTiles inside panels (Messages rows, feed panel). A gradient
        // with identical stops paints the same black glass.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xA6000000), Color(0xA6000000)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE8C96A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: DefaultTextStyle.merge(
        // .merge, NOT a plain DefaultTextStyle: a plain one REPLACES
        // the ambient style (theme font included), so unstyled text
        // inside a panel would fall back to the test/platform default
        // font (Ahem bars in renders). .merge keeps the theme font
        // and only recolours the text.
        style: const TextStyle(color: Color(0xFFF0F2FF)),
        child: IconTheme(
          data: const IconThemeData(color: Color(0xFFFFD700)),
          // ListTile paints its title/subtitle/icons from the theme,
          // NOT from the DefaultTextStyle/IconTheme above — so without
          // this, ListTile rows inside a black panel get dark text
          // (light theme) on black. Explicit colours on a row still win.
          child: ListTileTheme(
            data: const ListTileThemeData(
              textColor: Color(0xFFF0F2FF),
              iconColor: Color(0xFFFFD700),
            ),
            child: child,
          ),
        ),
      ),
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
  const DarkVibeXGlobalBackground({super.key, required this.child});

  /// Family background everywhere (Mr. Wrong, 2026-11-25): the whole
  /// app uses the SAME background as the Family pages — the
  /// `family_bg_light.png` image, plain, with NO gold wash and NO
  /// gold glow ("har jagah aise hi add kar de" + "light purple kar
  /// de, yellow achha nhi lag raha"). Soft light purple, blended
  /// like the Family pages. The room paints its own opaque
  /// background over this (Scaffold backgroundColor `_roomThemeColor`),
  /// so the room main background is untouched.
  static const assetPath = 'assets/images/family_bg_light.png';

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage(assetPath),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      ),
    ),
    child: child,
  );
}

class TinniBackground extends StatelessWidget {
  const TinniBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
