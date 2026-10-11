import 'package:flutter/material.dart';

import '../app/app_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD36A);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: state,
          builder: (context, _) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x88FFD36A)),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1F12), Color(0xFF111217)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        size: 48,
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'DarkVibeX',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Voice rooms, chat, games and your vibe in one place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: state.signingIn
                            ? null
                            : () => state.signInWithGoogle(),
                        icon: state.signingIn
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: state.signingIn
                            ? null
                            : () => state.continueAsGuest(),
                        child: const Text('Continue as guest'),
                      ),
                    ),
                    if (state.authError != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.red.withValues(alpha: 0.12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          state.authError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      'By continuing, you agree to use DarkVibeX responsibly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
