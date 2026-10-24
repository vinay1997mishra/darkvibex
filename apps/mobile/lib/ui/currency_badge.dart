import 'package:flutter/material.dart';

/// Distinct, colorful wallet currency artwork for Coins and Diamonds.
class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge({
    super.key,
    required this.icon,
    required this.isDiamond,
    this.size = 42,
  });

  final IconData icon;
  final bool isDiamond;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = isDiamond
        ? const [Color(0xFF8DEBFF), Color(0xFF438BFF), Color(0xFF7545E8)]
        : const [Color(0xFFFFF2A6), Color(0xFFFFC928), Color(0xFFE47B18)];
    final edge = isDiamond ? const Color(0xFF9CEBFF) : const Color(0xFFFFE27A);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.35, -.45),
          radius: 1.15,
          colors: colors,
        ),
        border: Border.all(color: edge.withValues(alpha: .9), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: colors[1].withValues(alpha: .38),
            blurRadius: size * .32,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: size * .58, color: const Color(0xFF20203F)),
          Positioned(
            top: size * .13,
            right: size * .17,
            child: Container(
              width: size * .12,
              height: size * .12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
