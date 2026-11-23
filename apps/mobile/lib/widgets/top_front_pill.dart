import 'package:flutter/material.dart';

/// Party-page top front pill (Vinay, 2026-11-23): the two fronts Top Rooms
/// (gold) and Top Family (purple), styled like the other apps' pill tabs —
/// tiny avatars on the left, label on the right. The old Room / CP Ranking /
/// Family card row is permanently removed; the CP front is gone with it.
class TopFrontPill extends StatelessWidget {
  const TopFrontPill({
    super.key,
    required this.label,
    required this.gradientColors,
    required this.textColor,
    required this.avatarUrls,
    required this.avatarHeaders,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String label;
  final List<Color> gradientColors;
  final Color textColor;

  /// Up to 3 avatar image URLs shown overlapping on the left of the pill.
  final List<String> avatarUrls;

  /// Headers for the avatar image requests (session auth).
  final Map<String, String> avatarHeaders;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatars = avatarUrls.take(3).toList(growable: false);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(34),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
            boxShadow: const [
              BoxShadow(color: Color(0x332F36FF), blurRadius: 10),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _AvatarStack(
                avatarUrls: avatars,
                avatarHeaders: avatarHeaders,
                fallbackIcon: fallbackIcon,
                iconColor: textColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({
    required this.avatarUrls,
    required this.avatarHeaders,
    required this.fallbackIcon,
    required this.iconColor,
  });

  final List<String> avatarUrls;
  final Map<String, String> avatarHeaders;
  final IconData fallbackIcon;
  final Color iconColor;

  static const double _size = 30;
  static const double _step = 20;

  @override
  Widget build(BuildContext context) {
    if (avatarUrls.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .22),
          border: Border.all(color: Colors.white.withValues(alpha: .5)),
        ),
        child: Icon(fallbackIcon, size: 17, color: iconColor),
      );
    }
    final width = _size + (avatarUrls.length - 1) * _step;
    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < avatarUrls.length; i++)
            Positioned(
              left: i * _step,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .85), width: 2),
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrls[i],
                    headers: avatarHeaders,
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: .22),
                      child: Icon(fallbackIcon, size: 15, color: iconColor),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
