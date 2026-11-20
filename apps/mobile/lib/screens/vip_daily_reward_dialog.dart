import 'package:flutter/material.dart';

import '../app/app_state.dart';

/// Daily reward pop-up (Vinay, 2026-11-20): when the app opens, a VIP5+
/// user who has not claimed today sees this dialog with today's coins
/// and a Claim button. Shown once per app open by the home shell; after
/// a claim it shows the claimed amount instead of the button.
Future<void> showVipDailyRewardDialog(
  BuildContext context, {
  required AppState state,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB300020C),
    builder: (_) => _VipDailyRewardDialog(state: state),
  );
}

String _formatCoins(int value) {
  final text = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return (value < 0 ? '-' : '') + buffer.toString();
}

class _VipDailyRewardDialog extends StatelessWidget {
  const _VipDailyRewardDialog({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final claimed = state.dailyRewardClaimedToday;
          final level = state.vipLevel.clamp(0, 18).toInt();
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF28231B), Color(0xFF0B0B0B)],
              ),
              border: Border.all(color: const Color(0x88FFD88A)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFFFFD88A),
                  size: 44,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Daily Reward',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VIP $level',
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (claimed) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF7ED491),
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Claimed',
                    style: TextStyle(
                      color: Color(0xFF7ED491),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+${_formatCoins(state.dailyRewardClaimedCoins)} coins added to your wallet.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFDAD0FF),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ] else if (!state.dailyRewardEligible) ...[
                  const Text(
                    'Unlocks at VIP 5 — claim coins every day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFDAD0FF)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    '${_formatCoins(state.dailyRewardAmount)} coins',
                    style: const TextStyle(
                      color: Color(0xFFFFD88A),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Claim your coins for today.',
                    style: TextStyle(color: Color(0xFFDAD0FF)),
                  ),
                  if (state.vipError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.vipError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFF9B9B)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.dailyRewardLoading
                          ? null
                          : () => state.claimDailyReward(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                      ),
                      child: state.dailyRewardLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Claim',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Later',
                      style: TextStyle(color: Color(0xFFDAD0FF)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
