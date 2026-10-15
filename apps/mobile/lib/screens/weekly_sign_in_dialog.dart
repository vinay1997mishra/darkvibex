import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

Future<void> showWeeklySignInDialog(
  BuildContext context, {
  required AppState state,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB300020C),
    builder: (_) => _WeeklySignInDialog(state: state),
  );
}

class _WeeklySignInDialog extends StatelessWidget {
  const _WeeklySignInDialog({required this.state});

  final AppState state;

  static const _rewards = <int>[
    70000,
    90000,
    100000,
    120000,
    150000,
    180000,
    250000,
  ];

  String _amount(int value) {
    if (value == 100000) return '100k';
    return '${value ~/ 1000}k';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 26),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final claimedThrough = state.weeklySignInClaimedThrough.clamp(0, 7);
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage(DarkVibeXGlobalBackground.assetPath),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF8E52FF),
                    width: 2.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA4B20FF),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Color(0x773BCAFF),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xB50B0B4A),
                        Color(0xE511083B),
                        Color(0xF20A0826),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            key: const Key('weekly-signin-close'),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFFFD04A),
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Weekly sign-in',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0xFF784CFF),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have signed in for $claimedThrough days',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFD9CEFF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 8.0;
                            final cardWidth =
                                (constraints.maxWidth - (gap * 3)) / 4;
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    for (var i = 0; i < 4; i++) ...[
                                      SizedBox(
                                        width: cardWidth,
                                        child: _RewardCard(
                                          day: i + 1,
                                          amount: _amount(_rewards[i]),
                                          claimed: i + 1 <= claimedThrough,
                                          highlighted:
                                              state.weeklySignInDay == i + 1,
                                        ),
                                      ),
                                      if (i != 3)
                                        const SizedBox(width: gap),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: gap),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: cardWidth,
                                      child: _RewardCard(
                                        day: 5,
                                        amount: _amount(_rewards[4]),
                                        claimed: claimedThrough >= 5,
                                        highlighted:
                                            state.weeklySignInDay == 5,
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    SizedBox(
                                      width: cardWidth,
                                      child: _RewardCard(
                                        day: 6,
                                        amount: _amount(_rewards[5]),
                                        claimed: claimedThrough >= 6,
                                        highlighted:
                                            state.weeklySignInDay == 6,
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    Expanded(
                                      child: _RewardCard(
                                        day: 7,
                                        amount: _amount(_rewards[6]),
                                        claimed: claimedThrough >= 7,
                                        highlighted:
                                            state.weeklySignInDay == 7,
                                        special: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        if ((state.weeklySignInError ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            state.weeklySignInError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFA9B7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            key: const Key('weekly-signin-claim'),
                            onPressed: state.weeklySignInLoading ||
                                    state.weeklySignInClaimedToday
                                ? null
                                : () async {
                                    final ok =
                                        await state.claimWeeklySignIn();
                                    if (!context.mounted || !ok) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '+${state.weeklySignInLastReward} coins claimed',
                                        ),
                                      ),
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC83D),
                              disabledBackgroundColor:
                                  const Color(0xFF7A632A),
                              foregroundColor: const Color(0xFF251333),
                              disabledForegroundColor:
                                  const Color(0xFFD8CBA2),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            child: state.weeklySignInLoading
                                ? const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF251333),
                                    ),
                                  )
                                : Text(
                                    state.weeklySignInClaimedToday
                                        ? 'Claimed  ✓'
                                        : 'Sign in',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.day,
    required this.amount,
    required this.claimed,
    required this.highlighted,
    this.special = false,
  });

  final int day;
  final String amount;
  final bool claimed;
  final bool highlighted;
  final bool special;

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFFFC83D);
    final borderColor = (highlighted || special)
        ? gold
        : const Color(0xFF7144E8);
    return AspectRatio(
      aspectRatio: special ? 1.75 : .76,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 7, 6, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: special
                ? const [Color(0xFF3A1646), Color(0xFF160A3E)]
                : const [Color(0xFF171052), Color(0xFF0D0A32)],
          ),
          border: Border.all(
            color: borderColor,
            width: highlighted || special ? 2 : 1.25,
          ),
          boxShadow: [
            if (highlighted || special)
              BoxShadow(
                color: gold.withValues(alpha: .30),
                blurRadius: 12,
              ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 30,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (highlighted || special)
                      ? gold
                      : const Color(0xFF5130CE),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: (highlighted || special)
                        ? const Color(0xFF271331)
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 14),
                  _GoldCoinPile(large: special),
                  const SizedBox(height: 5),
                  if (claimed)
                    const Icon(
                      Icons.check_rounded,
                      key: Key('weekly-signin-check'),
                      color: Color(0xFFFFD54A),
                      size: 24,
                    )
                  else
                    const SizedBox(height: 24),
                  Text(
                    amount,
                    style: TextStyle(
                      color: special ? gold : Colors.white,
                      fontSize: special ? 24 : 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldCoinPile extends StatelessWidget {
  const _GoldCoinPile({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 48.0;
    final coin = large ? 30.0 : 23.0;
    Widget goldCoin(double iconSize) => Container(
          width: iconSize,
          height: iconSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color(0xFFFFF2A8),
                Color(0xFFFFC42E),
                Color(0xFFB86B00),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x88FFB600),
                blurRadius: 7,
              ),
            ],
          ),
          child: Icon(
            Icons.monetization_on_rounded,
            size: iconSize * .82,
            color: const Color(0xFFFFE17A),
          ),
        );

    return SizedBox(
      width: size,
      height: size * .72,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(left: 1, bottom: 0, child: goldCoin(coin)),
          Positioned(right: 1, bottom: 0, child: goldCoin(coin)),
          Positioned(
            left: (size - coin) / 2,
            bottom: large ? 10 : 8,
            child: goldCoin(coin),
          ),
          Positioned(
            left: (size - coin) / 2,
            bottom: large ? 25 : 19,
            child: goldCoin(coin),
          ),
        ],
      ),
    );
  }
}
