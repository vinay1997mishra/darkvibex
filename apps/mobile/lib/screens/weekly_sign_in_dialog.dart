import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/weekly_signin_panel_data.dart';
import '../ui/weekly_reward_images_b64.dart';

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

Future<void> _showWeeklyRewardReceipt(
  BuildContext context, {
  required int day,
}) async {
  final rewardDay = day.clamp(1, 7).toInt();
  final imageBytes = weeklyRewardImageBytes(rewardDay);

  await showDialog<void>(
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
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),

                // Invisible touch target over the OK button drawn inside
                // each day-specific picture. OK closes only this reward panel.
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
                        onTap: () => Navigator.of(dialogContext).pop(),
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

                    // Invisible hit target over the X already drawn in the
                    // approved artwork. No extra close button is painted.
                    Positioned(
                      left: width * .845,
                      top: height * .075,
                      width: width * .12,
                      height: height * .11,
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
                    Positioned(
                      left: width * .18,
                      top: height * .745,
                      width: width * .64,
                      height: height * .125,
                      child: GestureDetector(
                        key: const Key('weekly-signin-claim'),
                        behavior: HitTestBehavior.opaque,
                        onTap: state.weeklySignInLoading ||
                                state.weeklySignInClaimedToday
                            ? null
                            : () async {
                                final ok = await state.claimWeeklySignIn();
                                if (!context.mounted || !ok) return;
                                await _showWeeklyRewardReceipt(
                                  context,
                                  day: state.weeklySignInLastClaimedDay > 0
                                      ? state.weeklySignInLastClaimedDay
                                      : state.weeklySignInDay,
                                );
                              },
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // The approved artwork already contains the Day-1 tick.
                    // For later claimed days, add the same gold right-mark
                    // without changing the supplied card/button artwork.
                    for (final marker in _claimedMarkers(
                      state.weeklySignInClaimedThrough,
                    ))
                      Positioned(
                        left: width * marker.dx - width * .027,
                        top: height * marker.dy - width * .027,
                        child: IgnorePointer(
                          child: Icon(
                            Icons.check_rounded,
                            color: const Color(0xFFFFD54A),
                            size: width * .054,
                            shadows: const [
                              Shadow(
                                color: Color(0xAAFFB300),
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
    if (claimed < 2) return const <Offset>[];

    const positions = <Offset>[
      // Day 1 tick is baked into the approved image.
      Offset(.381, .455), // Day 2
      Offset(.586, .455), // Day 3
      Offset(.805, .455), // Day 4
      Offset(.176, .665), // Day 5
      Offset(.395, .665), // Day 6
      Offset(.728, .665), // Day 7
    ];

    return positions.take(claimed - 1).toList(growable: false);
  }
}
