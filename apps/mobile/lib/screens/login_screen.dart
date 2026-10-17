import 'dart:typed_data';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import '../i18n/darkvibex_localization.dart';
import '../ui/tinni_style.dart';
import 'reset_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _dateOfBirth;
  Country? _selectedCountry;
  String? _selectedGender;
  String _selectedLanguage = 'English';
  Uint8List? _avatarBytes;
  String _avatarExtension = 'jpg';
  String _avatarContentType = 'image/jpeg';
  bool _savingProfile = false;
  bool _emailSignupDraft = false;
  String _pendingSignupEmail = '';

  AppState get state => widget.state;
  bool get _showProfileForm => state.needsProfileSetup || _emailSignupDraft;

  @override
  void initState() {
    super.initState();
    _hydrateProfileFields();
  }

  void _hydrateProfileFields() {
    final savedName = state.displayName.trim();
    if (_nameController.text.trim().isEmpty &&
        savedName.isNotEmpty &&
        savedName != 'DarkVibeX User') {
      _nameController.text = savedName;
    }
    final savedDob = DateTime.tryParse(state.dateOfBirth?.trim() ?? '');
    if (_dateOfBirth == null && savedDob != null) _dateOfBirth = savedDob;
    final savedCountryCode = state.countryCode.trim();
    if (_selectedCountry == null && savedCountryCode.isNotEmpty) {
      _selectedCountry = CountryParser.tryParseCountryCode(savedCountryCode);
    }
    final savedGender = state.gender.trim().toLowerCase();
    if (_selectedGender == null &&
        const <String>{'male', 'female'}.contains(savedGender)) {
      _selectedGender = savedGender;
    }
    final savedLanguage = state.languagePreference.value.trim();
    if (darkVibeXIsSupportedLanguage(savedLanguage)) {
      _selectedLanguage = savedLanguage;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _dobLabel {
    final value = _dateOfBirth;
    if (value == null) return 'Date of birth';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String get _dobApiValue {
    final value = _dateOfBirth;
    if (value == null) return '';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const TinniGlowIcon(icon: Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const TinniGlowIcon(icon: Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(
      source: source,
      imageQuality: 72,
      maxWidth: 768,
      maxHeight: 768,
    );
    if (file == null) return;

    final ext = file.name.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
    if (contentType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a JPG, PNG or WebP photo')),
        );
      }
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarExtension = ext == 'jpeg' ? 'jpg' : ext;
      _avatarContentType = contentType;
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select date of birth',
    );
    if (selected != null && mounted) {
      setState(() => _dateOfBirth = selected);
    }
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      useSafeArea: true,
      onSelect: (country) {
        if (!mounted) return;
        setState(() => _selectedCountry = country);
      },
    );
  }

  bool _validateProfile() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name')),
      );
      return false;
    }
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your date of birth')),
      );
      return false;
    }
    if (_selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your country and flag')),
      );
      return false;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select male or female')),
      );
      return false;
    }
    if (!darkVibeXIsSupportedLanguage(_selectedLanguage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a supported language')),
      );
      return false;
    }
    return true;
  }

  Future<void> _finishProfile() async {
    if (!_validateProfile() || state.signingIn || _savingProfile) return;
    if (mounted) setState(() => _savingProfile = true);
    try {
      final country = _selectedCountry!;
      final saved = await state.completeLoginProfile(
        name: _nameController.text.trim(),
        dateOfBirthValue: _dobApiValue,
        countryCodeValue: country.countryCode,
        countryNameValue: country.name,
        flagEmojiValue: country.flagEmoji,
        genderValue: _selectedGender,
        languageValue: _selectedLanguage,
        avatarBytes: _avatarBytes,
        avatarExtension: _avatarExtension,
        avatarContentType: _avatarContentType,
      );
      if (!saved && mounted && state.authError != null) {
        _notice(state.authError!);
      }
    } catch (error) {
      _notice('Profile could not be saved. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _googleLogin() async {
    if (state.signingIn || _savingProfile) return;
    final ok = await state.signInWithGoogle();
    if (ok && state.needsProfileSetup && mounted) {
      _hydrateProfileFields();
      setState(() {});
    }
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.replaceAll('_', ' '))),
    );
  }

  Future<void> _emailLogin() async {
    if (state.signingIn || _savingProfile) return;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Email / Gmail Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('email-login-address'),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email / Gmail ID',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('email-login-password'),
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'DarkVibeX Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('reset-password-link'),
            onPressed: () => Navigator.pop(dialogContext, 'reset'),
            child: const Text('Reset password'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'create'),
            child: const Text('Create Email ID'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'login'),
            child: const Text('Login'),
          ),
        ],
      ),
    );
    final email = emailController.text.trim();
    final password = passwordController.text;
    emailController.dispose();
    passwordController.dispose();
    if (!mounted || action == null) return;

    if (action == 'reset') {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => ResetPasswordScreen(
            state: state,
            initialEmail: email,
          ),
        ),
      );
      if (result != null && mounted) {
        _notice('Password reset successfully. Login with your new password.');
      }
      return;
    }

    if (action == 'create') {
      await _createEmailAccount(initialEmail: email);
      return;
    }

    if (!email.contains('@') || password.isEmpty) {
      _notice('Enter your email and DarkVibeX password.');
      return;
    }
    final ok = await state.signInWithEmail(email: email, password: password);
    if (ok && state.needsProfileSetup && mounted) {
      _hydrateProfileFields();
      setState(() {});
    }
  }

  Future<void> _createEmailAccount({
    String initialEmail = '',
    bool profileAlreadyCollected = false,
  }) async {
    if (state.signingIn || _savingProfile) return;
    if (!profileAlreadyCollected) {
      _pendingSignupEmail = initialEmail;
      _hydrateProfileFields();
      if (mounted) setState(() => _emailSignupDraft = true);
      return;
    }
    if (!_validateProfile()) return;
    final emailController = TextEditingController(text: initialEmail);
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Email ID'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email / Gmail ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = emailController.text.trim();
              if (value.contains('@')) Navigator.pop(dialogContext, value);
            },
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || !mounted) return;

    final started = await state.backend.startEmailOtp(
      email: email,
      purpose: 'signup',
    );
    if (!mounted) return;
    if (started?['ok'] != true) {
      _notice(started?['error']?.toString() ?? 'OTP could not be sent');
      return;
    }
    final requestId = started?['request_id']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final otpController = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify Email OTP'),
        content: TextField(
          key: const Key('email-otp-field'),
          controller: otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: '6-digit OTP',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = otpController.text.trim();
              if (RegExp(r'^\d{6}$').hasMatch(value)) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    otpController.dispose();
    if (otp == null || !mounted) return;

    final verified = await state.backend.verifyEmailOtp(
      requestId: requestId,
      otp: otp,
    );
    if (!mounted) return;
    if (verified?['ok'] != true) {
      _notice(verified?['error']?.toString() ?? 'OTP verification failed');
      return;
    }
    final setupToken = verified?['setup_token']?.toString() ?? '';
    if (setupToken.isEmpty) return;

    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create DarkVibeX Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('email-new-password'),
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'New Password',
                helperText: 'Minimum 8 characters',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('email-confirm-password'),
              controller: confirmController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = passwordController.text;
              if (value.length >= 8 && value == confirmController.text) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    confirmController.dispose();
    if (password == null || !mounted) return;

    final ok = await state.completeEmailSignup(
      setupToken: setupToken,
      password: password,
      name: _nameController.text.trim(),
      dateOfBirthValue: _dobApiValue,
    );
    if (ok && mounted) {
      setState(() => _emailSignupDraft = false);
      if (state.needsProfileSetup) await _finishProfile();
    } else if (mounted && !state.isAuthenticated) {
      setState(() => _emailSignupDraft = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = state.signingIn || _savingProfile;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TinniBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      const Text(
                        'DarkVibeX',
                        style: TextStyle(
                          color: TinniPalette.gold,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _showProfileForm
                            ? 'Complete your profile to continue'
                            : 'Sign in or create your account',
                        style: const TextStyle(
                          color: TinniPalette.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (_showProfileForm) ...[
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap: busy ? null : _pickAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 98,
                              height: 98,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: TinniPalette.brightGold,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x55D09A0A),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: TinniPalette.panel2,
                                backgroundImage: _avatarBytes == null
                                    ? null
                                    : MemoryImage(_avatarBytes!),
                                child: _avatarBytes == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 46,
                                        color: TinniPalette.gold,
                                      )
                                    : null,
                              ),
                            ),
                            const Positioned(
                              right: -2,
                              bottom: 2,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: TinniPalette.gold,
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 17,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to add DP',
                        style: TextStyle(
                          color: TinniPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TinniPanel(
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              maxLength: 60,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                prefixIcon: Icon(Icons.badge_rounded),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: busy ? null : _pickDateOfBirth,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date of birth',
                                  prefixIcon: Icon(Icons.cake_rounded),
                                  suffixIcon: Icon(Icons.calendar_month_rounded),
                                ),
                                child: Text(
                                  _dobLabel,
                                  style: TextStyle(
                                    color: _dateOfBirth == null
                                        ? TinniPalette.muted
                                        : TinniPalette.cream,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              key: const Key('create-id-country'),
                              onTap: busy ? null : _pickCountry,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Country',
                                  prefixIcon: Icon(Icons.public_rounded),
                                  suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                                ),
                                child: Text(
                                  _selectedCountry == null
                                      ? 'Choose country'
                                      : '${_selectedCountry!.flagEmoji} ${_selectedCountry!.name}',
                                  style: TextStyle(
                                    color: _selectedCountry == null
                                        ? TinniPalette.muted
                                        : TinniPalette.cream,
                                    fontWeight: _selectedCountry == null
                                        ? FontWeight.w500
                                        : FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    key: const Key('create-id-gender-male'),
                                    label: const Text('Male'),
                                    selected: _selectedGender == 'male',
                                    onSelected: busy
                                        ? null
                                        : (_) => setState(
                                              () => _selectedGender = 'male',
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    key: const Key('create-id-gender-female'),
                                    label: const Text('Female'),
                                    selected: _selectedGender == 'female',
                                    onSelected: busy
                                        ? null
                                        : (_) => setState(
                                              () => _selectedGender = 'female',
                                            ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: const Key('create-id-language'),
                              initialValue: _selectedLanguage,
                              decoration: const InputDecoration(
                                labelText: 'Language',
                                prefixIcon: Icon(Icons.language_rounded),
                              ),
                              items: darkVibeXSupportedLanguages
                                  .map(
                                    (language) => DropdownMenuItem<String>(
                                      value: language,
                                      child: Text(language),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(
                                        () => _selectedLanguage = value,
                                      );
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          key: const Key('complete-profile-button'),
                          onPressed: busy
                              ? null
                              : _emailSignupDraft
                                  ? () => _createEmailAccount(
                                        initialEmail: _pendingSignupEmail,
                                        profileAlreadyCollected: true,
                                      )
                                  : _finishProfile,
                          icon: _savingProfile
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _emailSignupDraft
                                ? 'Continue to Email Sign-up'
                                : 'Save Profile & Enter DarkVibeX',
                          ),
                        ),
                      ),
                      if (_emailSignupDraft)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    _emailSignupDraft = false;
                                    _pendingSignupEmail = '';
                                  }),
                          child: const Text('Back to Login'),
                        ),
                      ],
                      if (!_showProfileForm) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: busy ? null : _googleLogin,
                          icon: busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                      const SizedBox(height: 11),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          key: const Key('email-login-button'),
                          onPressed: busy ? null : _emailLogin,
                          icon: const Icon(Icons.email_rounded),
                          label: const Text('Email / Gmail Login'),
                        ),
                      ),
                      const SizedBox(height: 11),
                      ],
                      if (state.authError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: TinniPalette.danger.withValues(alpha: .14),
                            border: Border.all(
                              color: TinniPalette.danger.withValues(alpha: .55),
                            ),
                          ),
                          child: Text(
                            state.authError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFF8D8D),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'By continuing, you agree to use DarkVibeX responsibly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TinniPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
