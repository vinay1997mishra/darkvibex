import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// VIP-tier restyle of the 8 existing DarkVibeX chat bubbles.
///
/// Source of truth: `apps/worker/src/cosmetics.js:74-81` (catalogue tiers)
/// and `apps/mobile/lib/widgets/cosmetic_store_previews.dart`
/// (`StretchableCosmeticBubble:439`, `_BubbleTheme:674`, `_BubblePainter:751`,
/// `_AnimatedBubbleEdgeEffect:564`, `BubbleChatText:313`).
///
/// What this file does:
/// - Restyles each of the 8 existing bubbles by VIP tier, keeping its name,
///   motif, minimum VIP level and duration. Nothing here re-gates a bubble.
/// - The restyle applies to the painted fallback, the animated edge effect
///   and the new VIP badge. It does NOT replace the PNG artwork in
///   `bubble_artwork_data.dart`; when built-in artwork is present the app
///   still shows it, exactly as `StretchableCosmeticBubble` does today.
/// - The bubble shows the message text ONLY. The sender's name, medals and
///   VIP tag stay OUTSIDE the bubble (in the sender header above it). The
///   VIP badge pill on the bubble's top edge is part of the VIP bubble
///   design and stays.
///
/// Tier rule (follows the catalogue `tier` field):
/// - Basic (tier 1-4): thinner 2px border, soft glow, slow 2.4s sweep,
///   small dark VIP badge.
/// - Premium (tier 5-6): 2.8px border, stronger glow, 1.8s sweep,
///   gold-outlined VIP badge.
/// - More premium (tier 8-10): 3.5px border + inner gold hairline,
///   strong glow, fast 1.2s sweep, filled gold VIP badge.
/// - Super premium (tier 16-18): no bubble reaches it yet. The enum value
///   exists so a future VIP 16+ bubble (e.g. a King variant) can use it;
///   `bubbleStyleForVipTier(VipBubbleTier.superPremium)` returns null today.
///
/// How to use (drop-in, same sizing as `StretchableCosmeticBubble`):
/// ```dart
/// VipChatBubble(
///   styleId: message['active_bubble_id'] as String? ?? 'bubble-dream',
///   child: BubbleChatText(text: message['text'] as String? ?? ''),
/// )
/// ```
/// In room chat replace the `StretchableCosmeticBubble` at
/// `room_screen.dart:7918-8030`; in DMs replace it at
/// `conversation_screen.dart:423-520`. Keep passing `maxWidth: 280` in room
/// chat (292 in DMs) and the same `contentPadding` (44 horizontal, 10
/// vertical) so message layout does not change.
///
/// This file was NOT compiled in the VM (no Flutter SDK there). It must be
/// compiled in the real Flutter project before merging, as with the
/// vehicle-entry files.

enum VipBubbleTier {
  basic,
  premium,
  morePremium,
  superPremium,
}

/// Restyle tier for a catalogue tier number (from `cosmetics.js`).
VipBubbleTier vipBubbleTierForCatalogueTier(int catalogueTier) {
  if (catalogueTier >= 16) return VipBubbleTier.superPremium;
  if (catalogueTier >= 8) return VipBubbleTier.morePremium;
  if (catalogueTier >= 5) return VipBubbleTier.premium;
  return VipBubbleTier.basic;
}

/// One restyled bubble: new gradient, border/glow/edge treatment, badge.
class VipBubbleTheme {
  const VipBubbleTheme({
    required this.styleId,
    required this.displayName,
    required this.motif,
    required this.motifGlyph,
    required this.minVipLevel,
    required this.catalogueTier,
    required this.colors,
    required this.borderWidth,
    required this.glowOpacity,
    required this.edgeDurationMs,
    required this.edgeDotCount,
    required this.badgeLabel,
    required this.badgeIsFilledGold,
    required this.isPermanent,
  });

  final String styleId;
  final String displayName;
  final String motif;
  final String motifGlyph;
  final int minVipLevel;
  final int catalogueTier;
  final List<Color> colors;
  final double borderWidth;
  final double glowOpacity;
  final int edgeDurationMs;
  final int edgeDotCount;
  final String badgeLabel;
  final bool badgeIsFilledGold;
  final bool isPermanent;

  VipBubbleTier get tier => vipBubbleTierForCatalogueTier(catalogueTier);
}

/// Restyled theme table for the 8 existing bubbles. Unknown ids fall back
/// to the Golden Bubble, matching `_bubbleTheme` in
/// `cosmetic_store_previews.dart`.
VipBubbleTheme restyledBubbleTheme(String styleId) {
  switch (styleId) {
    case 'bubble-heart':
      return const VipBubbleTheme(
        styleId: 'bubble-heart',
        displayName: 'Heart Bubble',
        motif: 'heart',
        motifGlyph: '\u2665',
        minVipLevel: 2,
        catalogueTier: 2,
        colors: <Color>[
          Color(0xFFFFD0E6),
          Color(0xFFFF4D9E),
          Color(0xFFA80F8A),
        ],
        borderWidth: 2.0,
        glowOpacity: 0.18,
        edgeDurationMs: 2400,
        edgeDotCount: 3,
        badgeLabel: 'VIP 2',
        badgeIsFilledGold: false,
        isPermanent: false,
      );
    case 'bubble-dream':
      return const VipBubbleTheme(
        styleId: 'bubble-dream',
        displayName: 'Dream Bubble',
        motif: 'butterfly + stars',
        motifGlyph: '\u{1F98B}',
        minVipLevel: 0,
        catalogueTier: 4,
        colors: <Color>[
          Color(0xFFF6D9FF),
          Color(0xFFA84DFF),
          Color(0xFF4E1BB0),
        ],
        borderWidth: 2.0,
        glowOpacity: 0.18,
        edgeDurationMs: 2400,
        edgeDotCount: 3,
        badgeLabel: 'VIP 0',
        badgeIsFilledGold: false,
        isPermanent: false,
      );
    case 'bubble-nature':
      return const VipBubbleTheme(
        styleId: 'bubble-nature',
        displayName: 'Nature Bubble',
        motif: 'leaf',
        motifGlyph: '\u{1F343}',
        minVipLevel: 0,
        catalogueTier: 5,
        colors: <Color>[
          Color(0xFFC9FFD2),
          Color(0xFF2ED95E),
          Color(0xFF067A2E),
        ],
        borderWidth: 2.8,
        glowOpacity: 0.30,
        edgeDurationMs: 1800,
        edgeDotCount: 5,
        badgeLabel: 'VIP 0 \u00B7 PERMANENT',
        badgeIsFilledGold: false,
        isPermanent: true,
      );
    case 'bubble-ice':
      return const VipBubbleTheme(
        styleId: 'bubble-ice',
        displayName: 'Ice Bubble',
        motif: 'snowflake',
        motifGlyph: '\u2744',
        minVipLevel: 0,
        catalogueTier: 6,
        colors: <Color>[
          Color(0xFFD2F4FF),
          Color(0xFF35B6FF),
          Color(0xFF1B4FE0),
        ],
        borderWidth: 2.8,
        glowOpacity: 0.30,
        edgeDurationMs: 1800,
        edgeDotCount: 5,
        badgeLabel: 'VIP 0',
        badgeIsFilledGold: false,
        isPermanent: false,
      );
    case 'bubble-dragon':
      return const VipBubbleTheme(
        styleId: 'bubble-dragon',
        displayName: 'Dragon Bubble',
        motif: 'dragon',
        motifGlyph: '\u{1F409}',
        minVipLevel: 8,
        catalogueTier: 8,
        colors: <Color>[
          Color(0xFFFFD27A),
          Color(0xFFFF2E1A),
          Color(0xFF6E0812),
        ],
        borderWidth: 3.5,
        glowOpacity: 0.45,
        edgeDurationMs: 1200,
        edgeDotCount: 7,
        badgeLabel: 'VIP 8',
        badgeIsFilledGold: true,
        isPermanent: false,
      );
    case 'bubble-sakura':
      return const VipBubbleTheme(
        styleId: 'bubble-sakura',
        displayName: 'Sakura Bubble',
        motif: 'sakura',
        motifGlyph: '\u{1F338}',
        minVipLevel: 5,
        catalogueTier: 5,
        colors: <Color>[
          Color(0xFFFFD9EC),
          Color(0xFFFF5FAE),
          Color(0xFFB81E72),
        ],
        borderWidth: 2.8,
        glowOpacity: 0.30,
        edgeDurationMs: 1800,
        edgeDotCount: 5,
        badgeLabel: 'VIP 5',
        badgeIsFilledGold: false,
        isPermanent: false,
      );
    case 'bubble-king':
      return const VipBubbleTheme(
        styleId: 'bubble-king',
        displayName: 'King Bubble',
        motif: 'crown',
        motifGlyph: '\u265A',
        minVipLevel: 10,
        catalogueTier: 10,
        colors: <Color>[
          Color(0xFFCDEEFF),
          Color(0xFF2D77FF),
          Color(0xFFFFB11B),
        ],
        borderWidth: 3.5,
        glowOpacity: 0.45,
        edgeDurationMs: 1200,
        edgeDotCount: 7,
        badgeLabel: 'VIP 10 \u00B7 KING',
        badgeIsFilledGold: true,
        isPermanent: false,
      );
    case 'bubble-gold':
    default:
      return const VipBubbleTheme(
        styleId: 'bubble-gold',
        displayName: 'Golden Bubble',
        motif: 'crown',
        motifGlyph: '\u265B',
        minVipLevel: 0,
        catalogueTier: 1,
        colors: <Color>[
          Color(0xFFFFE98A),
          Color(0xFFFFB11B),
          Color(0xFFE85D04),
        ],
        borderWidth: 2.0,
        glowOpacity: 0.18,
        edgeDurationMs: 2400,
        edgeDotCount: 3,
        badgeLabel: 'VIP 0',
        badgeIsFilledGold: false,
        isPermanent: false,
      );
  }
}

/// All 8 restyled style ids, in catalogue order.
const List<String> restyledBubbleStyleIds = <String>[
  'bubble-gold',
  'bubble-heart',
  'bubble-dream',
  'bubble-nature',
  'bubble-ice',
  'bubble-dragon',
  'bubble-sakura',
  'bubble-king',
];

/// First restyled style id in a tier, or null when no bubble reaches it.
/// Today: basic -> bubble-gold, premium -> bubble-nature,
/// morePremium -> bubble-dragon, superPremium -> null (no bubble yet).
String? bubbleStyleForVipTier(VipBubbleTier tier) {
  for (final String styleId in restyledBubbleStyleIds) {
    if (restyledBubbleTheme(styleId).tier == tier) return styleId;
  }
  return null;
}

/// All restyled style ids in a tier.
List<String> bubbleStylesForVipTier(VipBubbleTier tier) {
  return restyledBubbleStyleIds
      .where((String id) => restyledBubbleTheme(id).tier == tier)
      .toList(growable: false);
}

/// VIP badge shown on a restyled bubble. Basic: dark pill. Premium:
/// gold-outlined pill. More premium: filled gold gradient pill.
class VipBubbleBadge extends StatelessWidget {
  const VipBubbleBadge({super.key, required this.theme});

  final VipBubbleTheme theme;

  @override
  Widget build(BuildContext context) {
    final bool filled = theme.badgeIsFilledGold;
    final bool premium = theme.tier == VipBubbleTier.premium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: filled
            ? const LinearGradient(
                colors: <Color>[Color(0xFFFFD36A), Color(0xFFFF9D00)],
              )
            : null,
        color: filled
            ? null
            : premium
                ? const Color(0xFF3A2A00)
                : const Color(0xFF2B2340),
        border: Border.all(
          color: filled
              ? const Color(0xFFFFF2A6)
              : premium
                  ? const Color(0xFFFFD36A)
                  : Colors.white.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: filled
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFFFB11B).withValues(alpha: 0.55),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Text(
        theme.badgeLabel,
        style: TextStyle(
          color: filled ? const Color(0xFF1A0B00) : const Color(0xFFFFE9A8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Text style for bubble messages. Identical to `BubbleChatText` in
/// `cosmetic_store_previews.dart:313` (white bold with a dark shadow, so it
/// stays readable over the artwork). Use the existing `BubbleChatText`
/// wherever it is already imported; this is only a local fallback.
class VipBubbleText extends StatelessWidget {
  const VipBubbleText({super.key, required this.text, this.fontSize = 14});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.25,
          fontWeight: FontWeight.w800,
          shadows: const <Shadow>[
            Shadow(
              color: Color(0xEE000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
            Shadow(
              color: Color(0x99000000),
              blurRadius: 1,
              offset: Offset.zero,
            ),
          ],
        ),
      );
}

/// Restyled chat bubble. Same sizing contract as
/// `StretchableCosmeticBubble`: max width 292 (pass 280 in room chat),
/// min 100 x 44, content padding 44 horizontal / 10 vertical.
class VipChatBubble extends StatelessWidget {
  const VipChatBubble({
    super.key,
    required this.styleId,
    required this.child,
    this.maxWidth = 292,
    this.minWidth = 100,
    this.minHeight = 44,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 44,
      vertical: 10,
    ),
    this.showBadge = true,
    this.showMotif = true,
  });

  final String styleId;
  final Widget child;
  final double maxWidth;
  final double minWidth;
  final double minHeight;
  final EdgeInsetsGeometry contentPadding;
  final bool showBadge;
  final bool showMotif;

  @override
  Widget build(BuildContext context) {
    final VipBubbleTheme theme = restyledBubbleTheme(styleId);
    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minWidth,
          maxWidth: maxWidth,
          minHeight: minHeight,
        ),
        child: CustomPaint(
          painter: _VipBubblePainter(theme),
          child: Stack(
            // The badge and motif straddle the top edge, so let them
            // paint outside the bubble body instead of being cut off.
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: _VipBubbleEdgeEffect(theme: theme),
              ),
              if (showMotif)
                Positioned(
                  right: 10,
                  top: -15,
                  child: Text(
                    theme.motifGlyph,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              if (showBadge)
                Positioned(
                  left: 14,
                  top: -11,
                  child: VipBubbleBadge(theme: theme),
                ),
              Padding(
                padding: contentPadding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painted fallback body, mirroring `_BubblePainter` in
/// `cosmetic_store_previews.dart:751`: dark gradient body, gradient border
/// in the restyled theme colours, outer glow, white top-left highlight arc.
/// Border width, glow and highlight strength come from the tier.
class _VipBubblePainter extends CustomPainter {
  const _VipBubblePainter(this.theme);

  final VipBubbleTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final double horizontalInset = math.min(18.0, size.width * 0.10);
    final double verticalInset = math.min(12.0, size.height * 0.16);
    final Rect bodyRect = Rect.fromLTWH(
      horizontalInset,
      verticalInset,
      size.width - horizontalInset * 2,
      size.height - verticalInset * 2,
    );
    final double radius = math.min(22.0, size.height * 0.30);
    final RRect body = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(radius),
    );

    final Paint glowPaint = Paint()
      ..color = theme.colors[1].withValues(alpha: theme.glowOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(body, glowPaint);

    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          theme.colors[2],
          const Color(0xFF120A1D),
          Colors.black,
        ],
        stops: const <double>[0.0, 0.42, 1.0],
      ).createShader(bodyRect);
    canvas.drawRRect(body, bodyPaint);

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: theme.colors,
      ).createShader(bodyRect);
    canvas.drawRRect(body, borderPaint);

    // More premium only: inner gold hairline inside the gradient border.
    if (theme.tier == VipBubbleTier.morePremium ||
        theme.tier == VipBubbleTier.superPremium) {
      final RRect inner = RRect.fromRectAndRadius(
        bodyRect.deflate(theme.borderWidth + 1),
        Radius.circular(math.max(0, radius - theme.borderWidth - 1)),
      );
      final Paint hairline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFFD36A).withValues(alpha: 0.55);
      canvas.drawRRect(inner, hairline);
    }

    final Paint highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(
        alpha: theme.tier == VipBubbleTier.basic ? 0.75 : 0.95,
      );
    final Path arc = Path()
      ..moveTo(bodyRect.left + 14, bodyRect.top + 2)
      ..quadraticBezierTo(
        bodyRect.left + bodyRect.width * 0.25,
        bodyRect.top - 6,
        bodyRect.left + bodyRect.width * 0.42,
        bodyRect.top + 2,
      );
    canvas.drawPath(arc, highlight);
  }

  @override
  bool shouldRepaint(covariant _VipBubblePainter oldDelegate) =>
      oldDelegate.theme.styleId != theme.styleId;
}

/// Animated sweep-gradient edge, mirroring `_AnimatedBubbleEdgeEffect`
/// (1.8s loop, 5 glow dots) with the tier's own speed and dot count.
class _VipBubbleEdgeEffect extends StatefulWidget {
  const _VipBubbleEdgeEffect({required this.theme});

  final VipBubbleTheme theme;

  @override
  State<_VipBubbleEdgeEffect> createState() => _VipBubbleEdgeEffectState();
}

class _VipBubbleEdgeEffectState extends State<_VipBubbleEdgeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.theme.edgeDurationMs),
  )..repeat();

  @override
  void didUpdateWidget(covariant _VipBubbleEdgeEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme.styleId != widget.theme.styleId) {
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              painter: _VipBubbleEdgePainter(
                theme: widget.theme,
                phase: _controller.value,
              ),
            ),
          ),
        ),
      );
}

class _VipBubbleEdgePainter extends CustomPainter {
  const _VipBubbleEdgePainter({required this.theme, required this.phase});

  final VipBubbleTheme theme;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 16 || size.height < 12) return;
    final Rect rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final double radius = math.min(14.0, size.height * 0.24);
    final RRect rounded = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius),
    );
    final Paint gradient = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = SweepGradient(
        transform: GradientRotation(phase * math.pi * 2),
        colors: <Color>[
          theme.colors.first.withValues(alpha: 0.12),
          theme.colors[1].withValues(alpha: 0.46),
          theme.colors.last.withValues(alpha: 0.20),
          theme.colors.first.withValues(alpha: 0.12),
        ],
      ).createShader(rect);
    canvas.drawRRect(rounded, gradient);

    final Path path = Path()..addRRect(rounded);
    final List<ui.PathMetric> metrics = path.computeMetrics().toList(
          growable: false,
        );
    if (metrics.isEmpty) return;
    final ui.PathMetric metric = metrics.first;
    for (var index = 0; index < theme.edgeDotCount; index++) {
      final double progress =
          (phase + index / theme.edgeDotCount) % 1.0;
      final Offset? point = metric
          .getTangentForOffset(metric.length * progress)
          ?.position;
      if (point == null) continue;
      final double pulse =
          0.6 + 0.4 * math.sin((phase + index / theme.edgeDotCount) * math.pi * 2).abs();
      canvas.drawCircle(
        point,
        3.2 * pulse,
        Paint()
          ..color = theme.colors[1].withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        point,
        1.25 * pulse,
        Paint()..color = Colors.white.withValues(alpha: 0.72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VipBubbleEdgePainter oldDelegate) =>
      oldDelegate.theme.styleId != theme.styleId ||
      oldDelegate.phase != phase;
}
