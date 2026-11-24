import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/weekly_signin_panel_data.dart';
import '../ui/weekly_reward_images_b64.dart';

/// Daily light colour for the weekly sign-in panel (Vinay, 2026-11-24):
/// the glow on top of the panel follows the SIGN-IN day — Day 1 gets
/// the first colour, Day 2 the second, ... Day 7 the seventh — so the
/// light changes every day of the week. The approved panel artwork
/// itself is untouched; only this overlay glow changes.
const List<Color> weeklySignInLightColors = <Color>[
  Color(0xFFFFD88A), // gold
  Color(0xFFB388FF), // purple
  Color(0xFF4DC3FF), // sky blue
  Color(0xFF00E5FF), // cyan
  Color(0xFFFF5C8A), // rose
  Color(0xFFFF9A3D), // orange
  Color(0xFF7ED491), // green
];

Color weeklySignInLightColorForDay(int day) {
  final signInDay = day.clamp(1, 7).toInt();
  return weeklySignInLightColors[signInDay - 1];
}

Future<void> showWeeklySignInDialog(
  BuildContext context, {
  required AppState state,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB300020C),
    builder: (_) => _WeeklySignInDialog(state: state),
  );
}

Future<bool> _showWeeklyRewardReceipt(
  BuildContext context, {
  required int day,
}) async {
  final rewardDay = day.clamp(1, 7).toInt();
  final imageBytes = weeklyRewardImageBytes(rewardDay);

  // Returns true when the user taps OK (close the whole popup) and
  // false when the user taps X (close only this receipt).
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB800020C),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: AspectRatio(
            aspectRatio: .8,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  gaplessPlayback: true,
                ),

                // Invisible touch target over the X that is already part of
                // the approved Day 1-7 receipt pictures.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 72,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: FractionallySizedBox(
                      widthFactor: .18,
                      heightFactor: 1,
                      child: GestureDetector(
                        key: const Key('weekly-signin-reward-close'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.of(dialogContext).pop(false),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),

                // Invisible touch target over the OK button drawn inside
                // each day-specific picture. OK closes the whole popup
                // (Vinay, 2026-11-24); X above closes only this receipt.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 92,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: .66,
                      heightFactor: 1,
                      child: GestureDetector(
                        key: const Key('weekly-signin-reward-ok'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            Navigator.of(dialogContext).pop(true),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

class _WeeklySignInDialog extends StatelessWidget {
  const _WeeklySignInDialog({required this.state});


  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.clamp(280.0, 520.0).toDouble();
              final height = width * (450 / 360);
              // Sign-in-day light (Vinay, 2026-11-24): Day 1 gold,
              // Day 2 purple, ... Day 7 green.
              final light =
                  weeklySignInLightColorForDay(state.weeklySignInDay);

              return SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.memory(
                        weeklySignInPanelBytes,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                        gaplessPlayback: true,
                      ),
                    ),

                    // Daily light (Vinay, 2026-11-24): a glow over the top
                    // of the panel whose colour follows the sign-in day.
                    // The artwork underneath is not touched.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: height * .42,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, -1),
                              radius: 1.05,
                              colors: [
                                light.withValues(alpha: .55),
                                light.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 7th-day light (Vinay, 2026-11-24): the Day 7 box
                    // has no permanent highlight in the artwork any
                    // more — the light comes on only when the user is
                    // on the 7th sign-in day.
                    if (state.weeklySignInDay == 7)
                      Positioned(
                        key: const Key('weekly-signin-day7-light'),
                        left: width * .63,
                        top: height * .51,
                        width: width * .31,
                        height: height * .21,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: .75,
                                colors: [
                                  light.withValues(alpha: .7),
                                  light.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Invisible hit target over the X already drawn in the
                    // approved artwork. No extra close button is painted.
                    // Measured on the new purple+gold panel (2026-11-24):
                    // the X glyph sits at x .86-.92, y .06-.10.
                    Positioned(
                      left: width * .845,
                      top: height * .055,
                      width: width * .12,
                      height: height * .10,
                      child: GestureDetector(
                        key: const Key('weekly-signin-close'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // Invisible hit target over the gold Sign in button
                    // already present in the approved artwork. This keeps the
                    // button visually 100% identical to the supplied picture.
                    // Measured on the new purple+gold panel (2026-11-24):
                    // the pill spans x .21-.79, y .82-.90.
                    Positioned(
                      left: width * .18,
                      top: height * .815,
                      width: width * .64,
                      height: height * .10,
                      child: GestureDetector(
                        key: const Key('weekly-signin-claim'),
                        behavior: HitTestBehavior.opaque,
                        onTap: state.weeklySignInLoading ||
                                state.weeklySignInClaimedToday
                            ? null
                            : () async {
                                final ok = await state.claimWeeklySignIn();
                                if (!context.mounted || !ok) return;
                                final receiptOk =
                                    await _showWeeklyRewardReceipt(
                                  context,
                                  day: state.weeklySignInLastClaimedDay > 0
                                      ? state.weeklySignInLastClaimedDay
                                      : state.weeklySignInDay,
                                );
                                // OK on the received-coins receipt closes
                                // the whole popup (Vinay, 2026-11-24); X
                                // on the receipt closes only the receipt.
                                if (receiptOk && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // Claimed-day ticks. The new purple+gold artwork has
                    // no tick baked in any more, so Day 1 gets a marker
                    // like every other day (Vinay, 2026-11-24).
                    for (final marker in _claimedMarkers(
                      state.weeklySignInClaimedThrough,
                    ))
                      Positioned(
                        left: width * marker.dx - width * .027,
                        top: height * marker.dy - width * .027,
                        child: IgnorePointer(
                          child: Icon(
                            Icons.check_rounded,
                            // Gold tick (Vinay, 2026-11-24): the old cyan
                            // tick did not match the purple+gold panel.
                            color: const Color(0xFFFFD88A),
                            size: width * .054,
                            shadows: const [
                              Shadow(
                                color: Color(0x88FFD88A),
                                blurRadius: 7,
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
        },
      ),
    );
  }

  List<Offset> _claimedMarkers(int claimedThrough) {
    final claimed = claimedThrough.clamp(0, 7).toInt();
    if (claimed < 1) return const <Offset>[];

    const positions = <Offset>[
      Offset(.16, .455), // Day 1
      Offset(.381, .455), // Day 2
      Offset(.586, .455), // Day 3
      Offset(.805, .455), // Day 4
      Offset(.176, .665), // Day 5
      Offset(.395, .665), // Day 6
      Offset(.728, .665), // Day 7
    ];

    return positions.take(claimed).toList(growable: false);
  }
}
