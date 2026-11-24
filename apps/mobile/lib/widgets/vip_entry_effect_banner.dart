import 'package:flutter/material.dart';

import '../vip/vip_visual_assets.dart';

/// Wide VIP entry banner for a room arrival (VIP5-18).
///
/// Full-width banner with the arriving user's DP composited into the
/// banner's transparent circle (left) and the level animal on the right.
/// The banner sizes itself automatically to the room width: height =
/// width / aspectRatio (per-level aspect ratios measured from the PNGs),
/// and the DP circle is placed from the per-level measured geometry
/// (vipEntryEffectCircles) — the circle is NOT in the same place on
/// every banner, so the position is never guessed.
/// VIP1-4 (or a missing URL) render nothing.
class VipEntryEffectBanner extends StatelessWidget {
  const VipEntryEffectBanner({
    super.key,
    required this.vipLevel,
    this.avatarUrl,
    this.avatarHeaders,
  });

  final int vipLevel;
  final String? avatarUrl;
  final Map<String, String>? avatarHeaders;

  @override
  Widget build(BuildContext context) {
    final String? url = vipEntryEffectUrlForVipLevel(vipLevel);
    // A bundled asset replaces the R2 banner for a level (VIP17's new
    // golden-phoenix banner, Mr. Wrong 2026-11-24). The R2 URL still
    // decides whether the level HAS an entry banner at all.
    final String? localAsset =
        vipEntryEffectLocalAssetForVipLevel(vipLevel);
    final EntryEffectCircle? circle = vipEntryEffectCircles[vipLevel];
    final double aspectRatio =
        vipEntryEffectAspectRatios[vipLevel] ?? 3.0;
    if (url == null || circle == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360;
        final double height = width / aspectRatio;
        final double diameter = circle.diameter * height;
        final double left = circle.centerX * width - diameter / 2;
        final double top = circle.centerY * height - diameter / 2;
        final String avatar = avatarUrl?.trim() ?? '';
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // The user's DP sits BEHIND the banner, showing through
              // the banner's transparent circle.
              Positioned(
                left: left,
                top: top,
                width: diameter,
                height: diameter,
                child: ClipOval(
                  child: avatar.isEmpty
                      ? Container(
                          color: const Color(0xFF29365D),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white70,
                          ),
                        )
                      : Image.network(
                          avatar,
                          headers: avatarHeaders,
                          width: diameter,
                          height: diameter,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF29365D),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                ),
              ),
              Positioned.fill(
                child: localAsset != null
                    ? Image.asset(
                        localAsset,
                        width: width,
                        height: height,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      )
                    : Image.network(
                        url,
                        width: width,
                        height: height,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
