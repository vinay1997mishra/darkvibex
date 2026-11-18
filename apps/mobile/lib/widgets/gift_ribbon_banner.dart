import 'package:flutter/material.dart';

import '../vip/vip_visual_assets.dart';

/// Full-width VIP gift ribbon banner for a room gift (VIP1-18).
///
/// Shows the tier base image (R2, direct) with a centre panel over the
/// baked-in placeholder text, mirroring the verified previews
/// (~/workspace/darkvibex-vip-section/gift-ribbons/make_previews.py):
/// the VIP level written BIG and bold — the most prominent text on the
/// banner — then sender -> receiver on one line with an arrow, then the
/// gift name below.
///
/// Panel geometry (fractions of the 2736x912 image): x 0.315-0.685,
/// y 0.40-0.72. Font sizes scale with the banner width (120pt / 72pt /
/// 52pt at 2736px wide in the previews). Panel colours are per tier:
/// tier 1 gold plaque + dark bronze text; tiers 2 and 4 black + gold
/// text; tier 3 deep purple + gold text (see
/// giftRibbonPanelColorsForVipLevel).
///
/// The ribbon is an ADDITION to the existing gift display (emoji
/// fly-in / video / GLB) — it never replaces it. VIP0 / no-VIP shows
/// the basic (Sleek Gold) tier, mirroring the Worker fallback.
class GiftRibbonBanner extends StatelessWidget {
  const GiftRibbonBanner({
    super.key,
    required this.vipLevel,
    required this.senderName,
    required this.receiverName,
    required this.giftName,
    this.ribbonUrl,
  });

  final int vipLevel;
  final String senderName;
  final String receiverName;
  final String giftName;

  /// Direct R2 URL of the tier image (usually the server's
  /// gift_ribbon.url). When null, the local mapping by [vipLevel] is
  /// used (basic tier for VIP0/no-VIP).
  final String? ribbonUrl;

  @override
  Widget build(BuildContext context) {
    final String url = (ribbonUrl?.trim().isNotEmpty == true)
        ? ribbonUrl!.trim()
        : giftRibbonUrlForVipLevel(vipLevel);
    final GiftRibbonPanelColors colors =
        giftRibbonPanelColorsForVipLevel(vipLevel);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360;
        final double height = width / kGiftRibbonAspectRatio;
        // Font sizes scale with the banner width (preview: 120pt VIP /
        // 72pt names / 52pt gift at 2736px wide).
        final double vipFontSize = width * 0.044;
        final double nameFontSize = width * 0.026;
        final double giftFontSize = width * 0.019;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Image.network(
                  url,
                  width: width,
                  height: height,
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              // Centre panel covering the baked placeholder text.
              Positioned(
                left: width * kGiftRibbonPanelLeft,
                top: height * kGiftRibbonPanelTop,
                width: width *
                    (kGiftRibbonPanelRight - kGiftRibbonPanelLeft),
                height: height *
                    (kGiftRibbonPanelBottom - kGiftRibbonPanelTop),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(colors.panel),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(colors.border),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // VIP level — BIG and bold, the most prominent
                      // text on the banner.
                      Text(
                        'VIP $vipLevel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(colors.vipText),
                          fontWeight: FontWeight.w900,
                          fontSize: vipFontSize,
                          height: 1.1,
                        ),
                      ),
                      // Sender -> receiver (one line, arrow shows the
                      // direction).
                      Text(
                        '$senderName \u2192 $receiverName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(colors.nameText),
                          fontWeight: FontWeight.bold,
                          fontSize: nameFontSize,
                          height: 1.2,
                        ),
                      ),
                      // Gift name (smaller).
                      Text(
                        giftName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(colors.giftText),
                          fontWeight: FontWeight.bold,
                          fontSize: giftFontSize,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
