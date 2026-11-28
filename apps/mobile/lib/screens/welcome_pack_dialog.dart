import 'package:material_ui/material_ui.dart';

import '../app/app_state.dart';

/// Welcome-pack pop-up (Vinay, 2026-11-24): a new user gets 500,000
/// coins + VIP1 free for 15 days, once, at signup. The pack is
/// granted by the server at signup — this dialog only announces it.
/// Shown once by the home shell (per-user local flag); after the
/// button tap it never appears again, even though the trial runs
/// for the full 15 days.
Future<void> showWelcomePackDialog(
  BuildContext context, {
  required AppState state,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB300020C),
    builder: (_) => _WelcomePackDialog(state: state),
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

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _WelcomePackDialog extends StatelessWidget {
  const _WelcomePackDialog({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final expiresAt = state.welcomePackExpiresAt;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
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
              Icons.card_giftcard_rounded,
              color: Color(0xFFFFD88A),
              size: 44,
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to DarkVibeX!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Welcome Pack is ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFD88A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '+${_formatCoins(500000)} coins',
              style: const TextStyle(
                color: Color(0xFFFFD88A),
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'added to your wallet',
              style: TextStyle(color: Color(0xFFDAD0FF)),
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x88FFD88A)),
                color: const Color(0x22FFD88A),
              ),
              child: Column(
                children: [
                  const Text(
                    'VIP 1 FREE for 15 days',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (expiresAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'until ${_formatDate(expiresAt)}',
                      style: const TextStyle(color: Color(0xFFDAD0FF)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await state.markWelcomePackSeen();
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                child: const Text(
                  'Start Exploring',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
