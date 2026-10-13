import 'package:flutter/material.dart';

abstract final class TinniPalette {
  static const black = Color(0xFF030201);
  static const nearBlack = Color(0xFF090603);
  static const panel = Color(0xFF0D0A05);
  static const panel2 = Color(0xFF151006);
  static const gold = Color(0xFFD09A0A);
  static const brightGold = Color(0xFFFFC928);
  static const deepGold = Color(0xFF8C6500);
  static const bronze = Color(0xFF5F4600);
  static const cream = Color(0xFFF4E9C7);
  static const muted = Color(0xFFAA9460);
  static const danger = Color(0xFFB95E5B);
}

ThemeData buildTinniStyleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TinniPalette.gold,
    brightness: Brightness.dark,
    primary: TinniPalette.gold,
    secondary: TinniPalette.cream,
    surface: TinniPalette.panel,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: TinniPalette.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: TinniPalette.black,
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
        foregroundColor: Colors.black,
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
  });

  final IconData icon;
  final double size;
  final double boxSize;

  @override
  Widget build(BuildContext context) => Container(
        width: boxSize,
        height: boxSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: TinniPalette.gold.withValues(alpha: .55)),
          boxShadow: [
            BoxShadow(
              color: TinniPalette.gold.withValues(alpha: .16),
              blurRadius: 12,
            ),
          ],
          gradient: RadialGradient(
            colors: [
              TinniPalette.gold.withValues(alpha: .16),
              Colors.transparent,
            ],
          ),
        ),
        child: Icon(icon, color: TinniPalette.gold, size: size),
      );
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
          colors: [Color(0xE60A0804), Color(0xD9060503)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: TinniPalette.bronze),
        boxShadow: const [
          BoxShadow(color: Color(0x443D2A00), blurRadius: 10),
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

class TinniBackground extends StatelessWidget {
  const TinniBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF050402),
              Color(0xFF090603),
              Color(0xFF020201),
              Color(0xFF000000),
            ],
            stops: [0, .24, .58, 1],
          ),
        ),
        child: child,
      );
}
