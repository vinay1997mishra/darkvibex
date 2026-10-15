import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/weekly_signin_panel_data.dart';
import '../ui/tinni_style.dart';

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
  required int reward,
}) async {
  String formatCoins(int value) {
    final raw = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return out.toString();
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB800020C),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: AspectRatio(
            aspectRatio: .76,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Image(
                    image: AssetImage(DarkVibeXGlobalBackground.assetPath),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xD91A0B48),
                          Color(0xD90D1A5A),
                          Color(0xE60A0628),
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFF8A63FF),
                        width: 1.4,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x663F39FF),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      key: const Key('weekly-signin-reward-close'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 38, 24, 30),
                    child: Column(
                      children: [
                        const Text(
                          'Reward received',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .2,
                            shadows: [
                              Shadow(
                                color: Color(0xAA7A4DFF),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Weekly sign-in reward',
                          style: TextStyle(
                            color: Color(0xFFD8D1FF),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 178,
                          height: 178,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0x66FFD54A),
                                Color(0x227B5DFF),
                                Colors.transparent,
                              ],
                              stops: [0, .56, 1],
                            ),
                            border: Border.all(
                              color: const Color(0x668A63FF),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.translate(
                                offset: const Offset(-34, 22),
                                child: const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Color(0xFFFFB300),
                                  size: 72,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99FF8F00),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(26, 18),
                                child: const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Color(0xFFFFC928),
                                  size: 78,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99FF8F00),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(2, -24),
                                child: const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Color(0xFFFFD54A),
                                  size: 84,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xAAFFB300),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '+${formatCoins(reward)}',
                          key: const Key('weekly-signin-reward-amount'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFD54A),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                            shadows: [
                              Shadow(
                                color: Color(0x99FF8F00),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'coins received',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Added to your wallet',
                          style: TextStyle(
                            color: Color(0xFFC7C1E8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            key: const Key('weekly-signin-reward-ok'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC928),
                              foregroundColor: const Color(0xFF221500),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('OK'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                                  reward: state.weeklySignInLastReward,
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
