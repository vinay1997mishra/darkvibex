import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../ui/tinni_style.dart';

/// Top-3 winged-shield display for the inside ranking views
/// (Mr. Wrong, 2026-11-23 — his screenshots of the other app's ranking):
/// #1 centre, big, with a REAL gold crown on top and a NO.1 ribbon,
/// #2 blue shield left, #3 orange shield right; the list below starts at
/// rank 4. The shield frames are PIL-built PNGs — wings + gold ring +
/// an ORNATE plaque under the ring, glass gloss, transparent centre for
/// the DP (v6, 840x1120); the name, badges and coins are Flutter text
/// sitting ON the plaque. The crown is the existing gold_crown.png asset.
/// Shared by RankingScreen (all 4 tabs, #1 shield coloured per tab) and
/// TopFamiliesScreen (gold #1 shield; each family's LV badge takes
/// that family's level colour — TinniPalette.familyLevelColors).
///
/// Shield PNG geometry (canvas 840x1120): ring centre at (0.5, 0.2768)
/// of the image, ring outer radius 0.2024 of the image width, avatar hole
/// radius 0.1571 of the image width. Text sits on the plaque at
/// y ~0.56-0.69 of the image height.
class RankingShieldEntry {
  const RankingShieldEntry({
    required this.name,
    required this.score,
    this.avatarUrl,
    this.avatarHeaders = const {},
    this.fallbackIcon = Icons.person_rounded,
    this.scoreIcon = Icons.monetization_on_rounded,
    this.vipLevel,
    this.idLevel,
    this.familyLevel,
  });

  final String name;
  final String score;

  final String? avatarUrl;
  final Map<String, String> avatarHeaders;
  final IconData fallbackIcon;

  /// Icon in front of the score pill: coin for ranking points,
  /// star for the family EXP score.
  final IconData scoreIcon;

  /// Badges under the name ("VIP N" + "Lv.N"), shown when provided.
  final int? vipLevel;
  final int? idLevel;

  /// Family level (TopFamiliesScreen only): shows an "LV.N" pill in
  /// that level's colour (TinniPalette.familyLevelColors).
  final int? familyLevel;
}

class RankingShield extends StatelessWidget {
  const RankingShield({
    super.key,
    required this.entries,
    required this.firstShieldAsset,
    this.onTap,
  });

  /// Exactly the top 3, in rank order: [1st, 2nd, 3rd].
  final List<RankingShieldEntry> entries;

  /// Shield frame for #1, coloured per tab (e.g. green for Room,
  /// gold for Send gifts, purple for Charm, red for Game).
  /// #2 is always shield_blue.png, #3 always shield_orange.png.
  final String firstShieldAsset;

  /// Called with the rank index (0 = 1st) when a column is tapped.
  /// Null = display only (no tap on the family shields).
  final void Function(int index)? onTap;

  static const scoreGold = Color(0xFFFFD36A);

  static const _shieldByRank = [
    '', // filled in from firstShieldAsset
    'assets/images/shield_blue.png',
    'assets/images/shield_orange.png',
  ];

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();
    final top = entries.take(3).toList(growable: false);
    final shields = [firstShieldAsset, _shieldByRank[1], _shieldByRank[2]];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // #1 is wider and taller; #2/#3 tuck their wings behind it.
        final w1 = width * 0.60;
        final w23 = width * 0.42;
        final h1 = w1 * 1120 / 840;
        final h23 = w23 * 1120 / 840;
        final height = math.max(22 + h1, 58 + h23);
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Soft gold glow behind #1.
              Positioned(
                top: 6,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x55FFD36A), Color(0x00FFD36A)],
                    ),
                  ),
                ),
              ),
              // #1 centre — painted FIRST so its wings sit behind the
              // side shields, like the other app (its wings spread
              // behind #2/#3, not over their rings).
              Positioned(
                left: (width - w1) / 2,
                top: 22,
                width: w1,
                child: _ShieldColumn(
                  key: const Key('ranking-shield-entry-0'),
                  entry: top[0],
                  rank: 1,
                  shieldAsset: shields[0],
                  imageWidth: w1,
                  imageHeight: h1,
                  onTap: onTap == null ? null : () => onTap!(0),
                ),
              ),
              // #2 left.
              Positioned(
                left: 0,
                top: 58,
                width: w23,
                child: _ShieldColumn(
                  key: const Key('ranking-shield-entry-1'),
                  entry: top[1],
                  rank: 2,
                  shieldAsset: shields[1],
                  imageWidth: w23,
                  imageHeight: h23,
                  onTap: onTap == null ? null : () => onTap!(1),
                ),
              ),
              // #3 right.
              Positioned(
                right: 0,
                top: 58,
                width: w23,
                child: _ShieldColumn(
                  key: const Key('ranking-shield-entry-2'),
                  entry: top[2],
                  rank: 3,
                  shieldAsset: shields[2],
                  imageWidth: w23,
                  imageHeight: h23,
                  onTap: onTap == null ? null : () => onTap!(2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShieldColumn extends StatelessWidget {
  const _ShieldColumn({
    super.key,
    required this.entry,
    required this.rank,
    required this.shieldAsset,
    required this.imageWidth,
    required this.imageHeight,
    this.onTap,
  });

  final RankingShieldEntry entry;
  final int rank;
  final String shieldAsset;
  final double imageWidth;
  final double imageHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    // Ring centre / radii as fractions of the shield image (840x1120).
    final ringCx = imageWidth * 0.5;
    final ringCy = imageHeight * (310 / 1120);
    final ringOuter = imageWidth * 0.2024;
    final avatarRadius = imageWidth * 0.1571 * 0.94;
    final crownWidth = imageWidth * 0.24;
    final crownHeight = crownWidth * 36 / 58;
    final column = SizedBox(
      width: imageWidth,
      height: imageHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            shieldAsset,
            width: imageWidth,
            height: imageHeight,
            fit: BoxFit.contain,
          ),
          // Avatar in the ring's transparent centre.
          Positioned(
            left: ringCx - avatarRadius,
            top: ringCy - avatarRadius,
            child: Container(
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: TinniPalette.panel2,
              ),
              child: ClipOval(
                child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                    ? Icon(
                        entry.fallbackIcon,
                        size: avatarRadius,
                        color: TinniPalette.muted,
                      )
                    : Image.network(
                        entry.avatarUrl!,
                        headers: entry.avatarHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          entry.fallbackIcon,
                          size: avatarRadius,
                          color: TinniPalette.muted,
                        ),
                      ),
              ),
            ),
          ),
          // The other app puts the REAL crown on #1's shield.
          if (isFirst)
            Positioned(
              left: ringCx - crownWidth / 2,
              top: ringCy - ringOuter - crownHeight * 0.35,
              child: Image.asset(
                'assets/images/gold_crown.png',
                width: crownWidth,
                height: crownHeight,
                fit: BoxFit.contain,
              ),
            ),
          // #1: NO.1 ribbon across the ring's bottom edge.
          // #2/#3: small rank medallion in the same spot.
          Positioned(
            left: ringCx - (isFirst ? 26 : 12),
            top: ringCy + ringOuter - 10,
            child: isFirst
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFE9A8), Color(0xFFD09A0A)],
                      ),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: const Color(0xFF8A5A10),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'NO.1',
                      style: TextStyle(
                        color: Color(0xFF3A2A00),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 12,
                    backgroundColor: rank == 2
                        ? const Color(0xFF1D4E9E)
                        : const Color(0xFFB25A10),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          // Name, badges and coins ON the plaque (y ~0.56-0.69).
          Positioned(
            left: imageWidth * 0.19,
            top: imageHeight * 0.56,
            width: imageWidth * 0.62,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isFirst
                        ? RankingShield.scoreGold
                        : TinniPalette.cream,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                if (entry.vipLevel != null ||
                    entry.idLevel != null ||
                    entry.familyLevel != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.vipLevel != null)
                        Flexible(
                          child: Text(
                            'VIP ${entry.vipLevel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: RankingShield.scoreGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      if (entry.vipLevel != null && entry.idLevel != null)
                        const SizedBox(width: 6),
                      if (entry.idLevel != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: TinniPalette.panel2,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'Lv.${entry.idLevel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: TinniPalette.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      if (entry.familyLevel != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: TinniPalette.familyLevelColor(
                                entry.familyLevel!,
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'LV.${entry.familyLevel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: TinniPalette.familyLevelColor(
                                  entry.familyLevel!,
                                ).computeLuminance() >
                                        0.6
                                    ? const Color(0xFF1A1A1A)
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: RankingShield.scoreGold.withValues(alpha: .4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.scoreIcon,
                        size: 13,
                        color: RankingShield.scoreGold,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.score,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: RankingShield.scoreGold,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return column;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: column,
      ),
    );
  }
}
