import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.state,
    this.initialEmail = '',
  });

  final AppState state;
  final String initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController emailController;
  final TextEditingController otpController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool busy = false;
  String? requestId;
  String? setupToken;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceAll('_', ' '))),
    );
  }

  Future<void> _sendOtp() async {
    if (busy) return;
    final email = emailController.text.trim();
    if (!email.contains('@')) {
      _notice('Enter a valid email / Gmail ID.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.startEmailOtp(
        email: email,
        purpose: 'reset',
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        setState(() {
          requestId = result?['request_id']?.toString();
          setupToken = null;
          otpController.clear();
        });
        _notice('OTP sent to your email.');
      } else {
        _notice(result?['error']?.toString() ?? 'OTP could not be sent');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final id = requestId;
    final otp = otpController.text.trim();
    if (busy || id == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _notice('Enter the 6-digit OTP.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.verifyEmailOtp(
        requestId: id,
        otp: otp,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        setState(() => setupToken = result?['setup_token']?.toString());
      } else {
        _notice(result?['error']?.toString() ?? 'OTP verification failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _savePassword() async {
    final token = setupToken;
    if (busy || token == null) return;
    if (passwordController.text.length < 8) {
      _notice('Password must be at least 8 characters.');
      return;
    }
    if (passwordController.text != confirmController.text) {
      _notice('Password and confirm password do not match.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.state.backend.completeEmailPassword(
        setupToken: token,
        password: passwordController.text,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        Navigator.of(context).pop(emailController.text.trim());
      } else {
        _notice(result?['error']?.toString() ?? 'Password reset failed');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpSent = requestId != null && setupToken == null;
    final verified = setupToken != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Reset password')),
      body: TinniBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TinniPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TinniGlowIcon(
                      icon: Icons.lock_reset_rounded,
                      size: 36,
                      boxSize: 64,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Reset DarkVibeX Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TinniPalette.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('reset-password-email'),
                      controller: emailController,
                      enabled: !busy && !otpSent && !verified,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email / Gmail ID',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!otpSent && !verified)
                      FilledButton.icon(
                        key: const Key('reset-password-send-otp'),
                        onPressed: busy ? null : _sendOtp,
                        icon: const Icon(Icons.mark_email_read_rounded),
                        label: const Text('Send OTP'),
                      )
                    else if (otpSent) ...[
                      TextField(
                        key: const Key('reset-password-otp'),
                        controller: otpController,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '6-digit OTP',
                        ),
                      ),
                      FilledButton(
                        key: const Key('reset-password-verify-otp'),
                        onPressed: busy ? null : _verifyOtp,
                        child: const Text('Verify OTP'),
                      ),
                      TextButton(
                        onPressed: busy ? null : _sendOtp,
                        child: const Text('Resend OTP'),
                      ),
                    ] else ...[
                      const Text(
                        'Email OTP verified',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('reset-password-new'),
                        controller: passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'New DarkVibeX Password',
                          helperText: 'Minimum 8 characters',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('reset-password-confirm'),
                        controller: confirmController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('reset-password-save'),
                        onPressed: busy ? null : _savePassword,
                        child: const Text('Save New Password'),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'Your Gmail password is never requested or stored.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TinniPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
