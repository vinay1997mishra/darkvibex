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
              TinniPalette.gold.withValues(alpha: .18),
              TinniPalette.brightGold.withValues(alpha: .08),
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
