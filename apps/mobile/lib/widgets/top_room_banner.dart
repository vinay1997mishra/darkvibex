import 'package:flutter/material.dart';

import 'level_medal.dart';

/// Top-of-room banner (Vinay, 2026-11-22): the room's banner at the
/// top, styled after the Oyaar video Vinay sent (2026-11-22 12:21 IST).
///
/// EVERY banner kind has its OWN design (Vinay, 2026-11-22 12:23 IST:
/// "Haan alag alag design hona chahiye"):
/// - Lucky win: red/gold gradient, gold "WIN" label on top, "Lucky
///   gift won X" + the multiplier ("x100") on the right.
/// - Gift: pink/magenta gradient, "Sent gifts worth X".
/// - Game win: purple gradient, gold crown on top, "won X in the game".
/// - Rocket: blue gradient, "Room ID: X Rocket ready for launch!".
/// - VIP entry: gold/purple gradient, crown + "entered the room".
/// - Event: orange gradient.
///
/// Banners SLIDE in from the right and slide out to the left (like
/// Oyaar), one message at a time — NOT a continuously scrolling
/// marquee. The room keeps a queue and rotates the message every
/// few seconds; when the queue is empty the banner hides.
///
/// A banner that names another room (a Rocket launch, big gift or
/// 100x+ Lucky win elsewhere) is tappable — tapping it asks
/// "Enter this room?" (Cancel / Confirm, like Oyaar) and Confirm
/// takes the user into that room. In-room banners and game-win
/// banners (no room) are not tappable.
enum TopBannerKind { gift, lucky, game, rocket, vip, event }

class TopRoomBanner extends StatelessWidget {
  const TopRoomBanner({
    super.key,
    required this.text,
    required this.kind,
    this.rocketLevel,
    this.avatarUrl,
    this.onTap,
  });

  /// The banner message, e.g. "Rahul sent Crown to Priya".
  final String text;

  /// Which design this banner uses.
  final TopBannerKind kind;

  /// Rocket level (only for kind == rocket): every rocket level has
  /// its own banner design (Vinay, 2026-11-22).
  final int? rocketLevel;

  /// Avatar image URL to show at the left (VIP entry banner, Vinay
  /// 2026-11-22 13:42 IST: "jo bhi user name hoga aur uski dp bhi
  /// show hogi" — the entering user's DP shows in the banner).
  final String? avatarUrl;

  /// Tap handler for cross-room banners (null = not tappable).
  final VoidCallback? onTap;

  /// Gradient colours per kind (Oyaar video, Vinay 2026-11-22).
  static const Map<TopBannerKind, List<Color>> kindGradients = {
    TopBannerKind.gift: [Color(0xFFE91E63), Color(0xFF9C27B0)],
    TopBannerKind.lucky: [Color(0xFFD32F2F), Color(0xFFFF8F00)],
    TopBannerKind.game: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
    TopBannerKind.rocket: [Color(0xFF7E57C2), Color(0xFF5E35B1)],
    TopBannerKind.vip: [Color(0xFFFFB300), Color(0xFF6A1B9A)],
    TopBannerKind.event: [Color(0xFFFF6D00), Color(0xFFE65100)],
  };

  /// Rocket banner gradient per rocket level (Vinay, 2026-11-22
  /// 12:35 IST: "Rocket wale me har rocket ka alag banner hota
  /// hai") — every rocket level has its OWN banner design, so the
  /// gradient changes as the level rises: blue → teal → purple →
  /// pink → orange → gold.
  static List<Color> rocketGradientForLevel(int level) {
    return switch (level) {
      <= 3 => [const Color(0xFF7E57C2), const Color(0xFF5E35B1)],
      <= 6 => [const Color(0xFF00897B), const Color(0xFF00695C)],
      <= 9 => [const Color(0xFF7B1FA2), const Color(0xFF4A148C)],
      <= 12 => [const Color(0xFFE91E63), const Color(0xFF880E4F)],
      <= 15 => [const Color(0xFFFF6D00), const Color(0xFFBF360C)],
      _ => [const Color(0xFFFFB300), const Color(0xFFFF6F00)],
    };
  }

  /// Top label per kind (shown above the text, like Oyaar's gold
  /// "WIN" on the Lucky banner and the crown on the game banner).
  static const Map<TopBannerKind, String> kindLabels = {
    TopBannerKind.lucky: 'WIN',
    TopBannerKind.game: '👑',
    TopBannerKind.rocket: '🚀',
    TopBannerKind.vip: '👑',
  };

  @override
  Widget build(BuildContext context) {
    // Every rocket level has its own banner design (Vinay,
    // 2026-11-22) — the gradient comes from the level, not the kind.
    final gradient = kind == TopBannerKind.rocket && rocketLevel != null
        ? rocketGradientForLevel(rocketLevel!)
        : kindGradients[kind] ?? kindGradients[TopBannerKind.event]!;
    final label = kindLabels[kind];
    // Ribbon-style banner (Vinay, 2026-11-22 12:31 IST: "Thoda
    // rebbon benner hai to isme design bhi add kar ek dum simple
    // mat rakh") — NOT plain: ornate gold border, glossy highlight
    // at the top, ribbon folds at both ends, sparkles, and a soft
    // shadow so the banner reads as a celebration ribbon.
    final content = Container(
      key: const Key('top-room-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy highlight at the top (ribbon shine).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.35),
                    Colors.white.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              Row(
                children: [
                  // Ribbon fold notch at the left end.
                  const Icon(
                    Icons.bookmark_rounded,
                    size: 12,
                    color: Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 4),
                  // VIP entry DP (Vinay, 2026-11-22 13:42 IST: "jo
                  // bhi user name hoga aur uski dp bhi show hogi").
                  if (avatarUrl != null && avatarUrl!.isNotEmpty) ...[
                    CircleAvatar(
                      radius: 11,
                      backgroundImage: NetworkImage(avatarUrl!),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Rocket banner (Vinay, 2026-11-22 13:30 IST: "Inke
                  // Rocket bhi bani hui dikhni chahiye") — the built
                  // rocket medal for that level shows in the banner,
                  // not just a small icon.
                  if (kind == TopBannerKind.rocket && rocketLevel != null) ...[
                    LevelMedal(
                      series: MedalSeries.rocket,
                      level: rocketLevel!,
                      size: 28,
                      animated: false,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Sparkle at the right end.
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: Color(0xFFFFD700),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
