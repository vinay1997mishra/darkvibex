// Create Family page (Mr. Wrong, 2026-11-24): the full create-family
// page from the other app's design, on the SAME light glass purple+gold
// background as the v9 Family main page (family_bg_light.png) — NOT the
// other app's dark background. Cost 90,000,000 coins, free for Wealth
// Level >= 30 or VIP Level >= 6 (same numbers as the worker).
import 'package:darkvibex/app/app_state.dart';
import 'package:darkvibex/infra/backend_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Cost of creating a family, in coins (Mr. Wrong, 2026-11-24: 90M).
/// Keep in sync with FAMILY_CREATE_COST_COINS in apps/worker/src/tinni_social.js.
const int kFamilyCreateCostCoins = 90000000;

/// Free creation thresholds (Mr. Wrong, 2026-11-24). Keep in sync with
/// FAMILY_CREATE_FREE_WEALTH_LEVEL / FAMILY_CREATE_FREE_VIP_LEVEL.
const int kFamilyCreateFreeWealthLevel = 30;
const int kFamilyCreateFreeVipLevel = 6;

String _formatCoins(int value) => value.toString();

const _labelShadow = <Shadow>[
  Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
];

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key, required this.state, this.backend});

  final AppState state;

  /// Test seam: a fake backend. Defaults to [AppState.backend].
  final BackendApi? backend;

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  BackendApi get _backend => widget.backend ?? widget.state.backend;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _tag = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // No default (Mr. Wrong, 2026-11-24: "Bina choose kiye na chale") —
  // the user must pick an application setting before create works.
  bool? _approvalRequired;
  String? _logoKey;
  bool _uploadingLogo = false;
  bool _creating = false;
  int? _wealthLevel;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onPreviewChanged);
    _tag.addListener(_onPreviewChanged);
    _loadWealthLevel();
  }

  void _onPreviewChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadWealthLevel() async {
    final value = await _backend.socialStats(userId: widget.state.userId);
    if (!mounted) return;
    final stats = value;
    if (stats == null) return;
    final wealth = stats['wealth'];
    final level = wealth is Map
        ? int.tryParse(wealth['level']?.toString() ?? '')
        : null;
    if (level != null) setState(() => _wealthLevel = level);
  }

  bool get _isFree =>
      widget.state.vipLevel >= kFamilyCreateFreeVipLevel ||
      (_wealthLevel ?? 0) >= kFamilyCreateFreeWealthLevel;

  /// Create works only when EVERY detail is filled (Mr. Wrong,
  /// 2026-11-24: "jab tak sab kuch fill up nhi hoga tab tak family
  /// create nhi hogi" + "Bina choose kiye na chale" + "Insufficient
  /// coins me create nhin honi chahiye") — name + tag + logo + an
  /// explicitly chosen application setting + enough coins (unless
  /// creation is free via VIP 6 / Wealth 30), all required. The button
  /// stays disabled (not clickable) until then.
  bool get _canCreate =>
      !_creating &&
      _name.text.trim().length >= 2 &&
      _tag.text.trim().length >= 2 &&
      _logoKey != null &&
      _logoKey!.isNotEmpty &&
      _approvalRequired != null &&
      (_isFree || widget.state.coins >= kFamilyCreateCostCoins);

  String get _previewName =>
      _name.text.trim().isEmpty ? 'Family name' : _name.text.trim();
  String get _previewTag =>
      _tag.text.trim().isEmpty ? 'Family tag' : _tag.text.trim().toUpperCase();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickLogo() async {
    if (_uploadingLogo || _creating) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    final normalized = ext == 'jpeg' ? 'jpg' : ext;
    final contentType = switch (normalized) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' => 'image/jpeg',
      _ => null,
    };
    if (contentType == null) {
      _showMessage('Choose a JPG, PNG or WebP photo');
      return;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage('Choose a photo smaller than 5 MB');
      return;
    }
    setState(() => _uploadingLogo = true);
    final key = await _backend.uploadImage(
      key:
          'family-logos/${widget.state.userId}-${DateTime.now().microsecondsSinceEpoch}.$normalized',
      bytes: bytes,
      contentType: contentType,
    );
    if (!mounted) return;
    setState(() => _uploadingLogo = false);
    if (key == null || key.isEmpty) {
      _showMessage('Family logo could not be uploaded');
      return;
    }
    setState(() => _logoKey = key);
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _name.text.trim();
    final tag = _tag.text.trim().toUpperCase();
    if (name.length < 2) {
      _showMessage('Family name must be at least 2 characters');
      return;
    }
    if (tag.length < 2) {
      _showMessage('Family tag must be at least 2 characters');
      return;
    }
    // Logo is mandatory (Mr. Wrong, 2026-11-24: "Logo ke bina family
    // create hi nhi hogi") — a family cannot be created without one.
    if (_logoKey == null || _logoKey!.isEmpty) {
      _showMessage('Family logo is required');
      return;
    }
    // Application setting must be explicitly chosen (Mr. Wrong,
    // 2026-11-24: "Bina choose kiye na chale").
    final approvalRequired = _approvalRequired;
    if (approvalRequired == null) {
      _showMessage('Choose an application setting');
      return;
    }
    setState(() => _creating = true);
    final value = await _backend.createFamily(
      userId: widget.state.userId,
      name: name,
      tag: tag,
      approvalRequired: approvalRequired,
      logoKey: _logoKey,
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (value?['ok'] == true) {
      _showMessage('Family created');
      Navigator.pop(context, value?['family_id']?.toString());
      return;
    }
    final error = value?['error']?.toString() ?? '';
    _showMessage(switch (error) {
      'already_in_family' => 'You are already in a family',
      'family_name_or_tag_in_use' =>
        'That family name or tag is already in use',
      'invalid_family_name_or_tag' =>
        'Family name and tag must be at least 2 characters',
      'logo_required' => 'Family logo is required',
      'content_blocked' =>
        'Family name or tag has a word that is not allowed',
      'insufficient_coins' => 'Not enough coins to create a family',
      _ => 'Could not create family',
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    super.dispose();
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            shadows: _labelShadow,
          ),
        ),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          style: const TextStyle(
            // Black, not gold (Mr. Wrong, 2026-11-24): the gold note text
            // was unreadable on the light glass background. No shadow —
            // a dark shadow under black text would only blur it.
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _familyEmblem({double size = 56}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFD9A441)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: const Color(0xFF8A5A10), width: 2),
        ),
        child: Icon(
          Icons.shield_rounded,
          size: size * 0.6,
          color: const Color(0xFF3A2A00),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nameLength = _name.text.length;
    final tagLength = _tag.text.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('create'),
        centerTitle: true,
        backgroundColor: const Color(0xFF17112E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        // Full-screen height so the v9 glass background covers the whole
        // page even though the form content is shorter than the screen.
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/family_bg_light.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Upload family logo.
              Center(
                child: GestureDetector(
                  key: const Key('create-family-logo'),
                  onTap: _pickLogo,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2140),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD9A441),
                        width: 3,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _uploadingLogo
                        ? const Center(child: CircularProgressIndicator())
                        : _logoKey != null && _logoKey!.isNotEmpty
                            ? Image.network(
                                _backend.fileUrl(_logoKey!),
                                headers: _backend.fileHeaders,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person_rounded,
                                  size: 64,
                                  color: Color(0xFFFFE082),
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 64,
                                color: Color(0xFFFFE082),
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Upload family logo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    shadows: _labelShadow,
                  ),
                ),
              ),
              _sectionLabel('Family name'),
              TextField(
                key: const Key('create-family-name'),
                controller: _name,
                maxLength: 20,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'Unfilled',
                  hintStyle: const TextStyle(color: Color(0xFF1A1A1A)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  counterText: '',
                  suffixText: '$nameLength/20',
                  suffixStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _note(
                '*Family names can only be changed once a month, please consider carefully',
              ),
              _sectionLabel('Family tag'),
              TextField(
                key: const Key('create-family-tag'),
                controller: _tag,
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
                ],
                onChanged: (value) {
                  final upper = value.toUpperCase();
                  if (upper != value) {
                    _tag.value = _tag.value.copyWith(
                      text: upper,
                      selection: TextSelection.collapsed(
                        offset: upper.length,
                      ),
                    );
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Unfilled',
                  hintStyle: const TextStyle(color: Color(0xFF1A1A1A)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  counterText: '',
                  suffixText: '$tagLength/10',
                  suffixStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _note(
                '*It can only be revised once a month, please consider carefully',
              ),
              _sectionLabel('Preview'),
              Container(
                key: const Key('create-family-preview'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD9A441),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    _familyEmblem(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _previewName,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D28D9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _previewTag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _sectionLabel('Application settings'),
              RadioListTile<bool>(
                key: const Key('create-family-approval-required'),
                title: const Text(
                  'Approval required to join the family',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: _labelShadow,
                  ),
                ),
                activeColor: const Color(0xFFD9A441),
                value: true,
                groupValue: _approvalRequired,
                onChanged: (value) {
                  if (value != null) setState(() => _approvalRequired = value);
                },
              ),
              RadioListTile<bool>(
                key: const Key('create-family-no-approval'),
                title: const Text(
                  'No approval required, join the family directly',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: _labelShadow,
                  ),
                ),
                activeColor: const Color(0xFFD9A441),
                value: false,
                groupValue: _approvalRequired,
                onChanged: (value) {
                  if (value != null) setState(() => _approvalRequired = value);
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 280,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFE082), Color(0xFFD9A441)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8A5A10),
                        width: 1,
                      ),
                    ),
                    child: FilledButton(
                      key: const Key('create-family-submit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: const Color(0xFF3A2A00),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Create works only when every detail is filled
                      // (Mr. Wrong, 2026-11-24) — the button stays
                      // disabled until name + tag + logo are all set.
                      onPressed: _canCreate ? _create : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'create',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.monetization_on_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isFree
                                    ? 'Free'
                                    : _formatCoins(kFamilyCreateCostCoins),
                                key: const Key('create-family-cost'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Free creation is available for users with Wealth Level ≥ 30 or VIP Level ≥ 6',
                key: Key('create-family-free-note'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: _labelShadow,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '*After creating a family, if you do not log in for 15 days, the position of family leader will automatically transfer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: _labelShadow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
