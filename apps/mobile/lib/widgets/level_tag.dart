import 'package:material_ui/material_ui.dart';

/// 3D pill tags (Vinay, 2026-11-23): the gold "$" wealth tag (wealth IS
/// the dollar level — one tag, not two) and the "Lv.N" ID level pill.
/// Colour changes every 10 levels, so each 10-level band looks distinct;
/// each pill has a top gloss, a bottom shade and a glow in its own
/// colour, like a raised metal badge. The DP always still shows next to
/// the name — these pills never replace it.

/// ID level pill colours, one per 10-level band, from Vinay's Level
/// screenshots: Lv.1-9 silver, Lv.10-19 copper, Lv.20-29 blue,
/// Lv.30-39 green, Lv.40-49 purple, Lv.50-59 blue, Lv.60-69 orange,
/// Lv.70-79 green, Lv.80 purple. Bands repeat every 90 levels; the top
/// level 200 is gold, as in the approved preview.
Color idLevelTagColor(int level) {
  if (level < 1) return const Color(0xFF7C8AA5);
  if (level >= 200) return const Color(0xFFD09A0A);
  const bands = <Color>[
    Color(0xFF7C8AA5), // 1-9 silver
    Color(0xFFB4653A), // 10-19 copper
    Color(0xFF3B82F6), // 20-29 blue
    Color(0xFF22A06B), // 30-39 green
    Color(0xFF8B5CF6), // 40-49 purple
    Color(0xFF3B82F6), // 50-59 blue
    Color(0xFFF59E0B), // 60-69 orange
    Color(0xFF22A06B), // 70-79 green
    Color(0xFF8B5CF6), // 80-89 purple
  ];
  return bands[(level - 1) ~/ 10 % bands.length];
}

/// Wealth (= dollar) tag colours, one per 10 levels, from the SVGA
/// dollar-level pack other apps use: grey, green, teal, blue, purple,
/// indigo, pink, magenta, ice-blue, orange, red — then they repeat.
Color wealthTagColor(int level) {
  if (level < 1) return const Color(0xFF6B7280);
  const bands = <Color>[
    Color(0xFF6B7280), // 1-10 grey
    Color(0xFF22A06B), // 11-20 green
    Color(0xFF0D9488), // 21-30 teal
    Color(0xFF3B82F6), // 31-40 blue
    Color(0xFF8B5CF6), // 41-50 purple
    Color(0xFF6366F1), // 51-60 indigo
    Color(0xFFEC4899), // 61-70 pink
    Color(0xFFD946EF), // 71-80 magenta
    Color(0xFF7DD3FC), // 81-90 ice-blue
    Color(0xFFF97316), // 91-100 orange
    Color(0xFFEF4444), // 101-110 red
  ];
  return bands[(level - 1) ~/ 10 % bands.length];
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.color,
    required this.label,
    required this.icon,
    required this.fontSize,
  });

  final Color color;
  final String label;
  final Widget icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final height = fontSize * 2.2;
    final light = Color.lerp(color, Colors.white, .38)!;
    final dark = Color.lerp(color, Colors.black, .32)!;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: fontSize * .55),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, color, dark],
          stops: const [0, .55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .55),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: fontSize * .25),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _dollarCoin(double size) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE9A8), Color(0xFFFFD34D), Color(0xFFD09A0A)],
      ),
      border: Border.all(color: const Color(0xFFA06E0A), width: .8),
    ),
    child: Text(
      '\$',
      style: TextStyle(
        color: const Color(0xFF5A3C00),
        fontSize: size * .62,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}

/// "Lv.N" ID level pill (grows on sending gifts, 200 levels). Renders
/// nothing below level 1.
class IdLevelTag extends StatelessWidget {
  const IdLevelTag({super.key, required this.level, this.fontSize = 11});

  final int level;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (level < 1) return const SizedBox.shrink();
    return _TagPill(
      color: idLevelTagColor(level),
      label: 'Lv.$level',
      icon: Icon(
        Icons.shield_rounded,
        size: fontSize + 1,
        color: Colors.white,
      ),
      fontSize: fontSize,
    );
  }
}

/// Gold-$ wealth tag (wealth IS the dollar level, 200 levels). Renders
/// nothing below level 1.
class WealthTag extends StatelessWidget {
  const WealthTag({super.key, required this.level, this.fontSize = 11});

  final int level;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (level < 1) return const SizedBox.shrink();
    return _TagPill(
      color: wealthTagColor(level),
      label: '$level',
      icon: _dollarCoin(fontSize + 8),
      fontSize: fontSize,
    );
  }
}
