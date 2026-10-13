import 'dart:typed_data';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  late final TextEditingController nameController;
  final ImagePicker picker = ImagePicker();

  DateTime? dob;
  late String countryCode;
  late String countryName;
  late String flagEmoji;
  late String gender;
  Uint8List? avatarBytes;
  String avatarExtension = 'jpg';
  String avatarContentType = 'image/jpeg';
  bool saving = false;
  bool loadingMedia = true;
  String? uploadingSlot;
  Map<String, String?> media = const <String, String?>{};

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: widget.state.displayName);
    final raw = widget.state.dateOfBirth?.trim() ?? '';
    dob = raw.isEmpty ? null : DateTime.tryParse(raw);
    countryCode = widget.state.countryCode;
    countryName = widget.state.countryName;
    flagEmoji = widget.state.flagEmoji;
    gender = widget.state.gender;
    _loadMedia();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  String get dobApiValue {
    final value = dob;
    if (value == null) return '';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String get dobLabel {
    final value = dob;
    if (value == null) return 'Date of birth';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> pickDob() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate:
          dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select date of birth',
    );
    if (selected != null && mounted) {
      setState(() => dob = selected);
    }
  }

  void pickCountry() {
    if (widget.state.countryChangesRemaining <= 0) return;
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      useSafeArea: true,
      onSelect: (country) {
        if (!mounted) return;
        setState(() {
          countryCode = country.countryCode;
          countryName = country.name;
          flagEmoji = country.flagEmoji;
        });
      },
    );
  }

  Future<void> pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TinniPalette.nearBlack,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    final type = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
    if (type == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a JPG, PNG or WebP photo'),
          ),
        );
      }
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      avatarBytes = bytes;
      avatarExtension = ext == 'jpeg' ? 'jpg' : ext;
      avatarContentType = type;
    });
  }

  Future<void> _loadMedia() async {
    final value = await widget.state.backend.profileMedia(
      userId: widget.state.userId,
    );
    if (!mounted) return;
    setState(() {
      media = value;
      loadingMedia = false;
    });
  }

  ImageProvider<Object>? _mediaProvider(String? key) {
    final value = key?.trim() ?? '';
    if (value.isEmpty) return null;
    return NetworkImage(
      widget.state.backend.fileUrl(value),
      headers: widget.state.backend.fileHeaders,
    );
  }

  Future<ImageSource?> _chooseMediaSource() => showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: TinniPalette.nearBlack,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Select from phone album'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  ImageSource.gallery,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  ImageSource.camera,
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _uploadMedia(String slot) async {
    if (uploadingSlot != null || saving) return;
    final source = await _chooseMediaSource();
    if (source == null) return;
    final file = await picker.pickImage(
      source: source,
      imageQuality: 84,
      maxWidth: slot == 'cover' ? 1600 : 1280,
      maxHeight: slot == 'cover' ? 1000 : 1600,
    );
    if (file == null) return;

    final ext = file.name.split('.').last.toLowerCase();
    final normalized = ext == 'jpeg' ? 'jpg' : ext;
    final type = switch (normalized) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' => 'image/jpeg',
      _ => null,
    };
    if (type == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a JPG, PNG or WebP photo'),
          ),
        );
      }
      return;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a photo smaller than 5 MB'),
          ),
        );
      }
      return;
    }

    setState(() => uploadingSlot = slot);
    final key = await widget.state.backend.uploadImage(
      key:
          'users/${widget.state.userId}/profile-media-$slot-${DateTime.now().microsecondsSinceEpoch}.$normalized',
      bytes: bytes,
      contentType: type,
    );
    final ok = key != null &&
        await widget.state.backend.saveProfileMedia(
          slot: slot,
          assetKey: key,
        );
    if (!mounted) return;
    if (ok) {
      setState(() {
        media = <String, String?>{...media, slot: key};
        uploadingSlot = null;
      });
      return;
    }
    setState(() => uploadingSlot = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile photo could not be saved')),
    );
  }

  Future<void> _removeMedia(String slot) async {
    if (uploadingSlot != null || media[slot] == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(slot == 'cover' ? 'Remove cover photo?' : 'Remove photo?'),
        content: const Text(
          'This removes the photo from your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => uploadingSlot = slot);
    final ok = await widget.state.backend.deleteProfileMedia(slot: slot);
    if (!mounted) return;
    setState(() {
      if (ok) media = <String, String?>{...media, slot: null};
      uploadingSlot = null;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo could not be removed')),
      );
    }
  }

  Widget _mediaTile(String slot, String label) {
    final image = _mediaProvider(media[slot]);
    final busy = uploadingSlot == slot;
    return InkWell(
      key: Key('profile-media-$slot'),
      borderRadius: BorderRadius.circular(14),
      onTap: busy ? null : () => _uploadMedia(slot),
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: TinniPalette.panel2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TinniPalette.bronze),
          image: image == null
              ? null
              : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            if (image == null)
              const Center(
                child: Icon(
                  Icons.add_photo_alternate_rounded,
                  color: TinniPalette.gold,
                  size: 32,
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 7,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  busy ? 'Uploading…' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TinniPalette.cream,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (image != null && !busy)
              Positioned(
                top: 3,
                right: 3,
                child: IconButton(
                  tooltip: 'Remove photo',
                  onPressed: () => _removeMedia(slot),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            if (busy)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<void> save() async {
    if (saving) return;
    final name = nameController.text.trim();
    if (name.isEmpty || dob == null || countryCode.isEmpty || gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, age, country and gender are required'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final ok = await widget.state.completeLoginProfile(
      name: name,
      dateOfBirthValue: dobApiValue,
      countryCodeValue: countryCode,
      countryNameValue: countryName,
      flagEmojiValue: flagEmoji,
      genderValue: gender,
      avatarBytes: avatarBytes,
      avatarExtension: avatarExtension,
      avatarContentType: avatarContentType,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.state.authError ?? 'Profile could not be updated',
          ),
        ),
      );
    }
  }

  ImageProvider? currentAvatar() {
    if (avatarBytes != null) return MemoryImage(avatarBytes!);
    final key = widget.state.avatarKey;
    if (key == null || key.isEmpty) return null;
    return NetworkImage(
      widget.state.backend.fileUrl(key),
      headers: widget.state.backend.fileHeaders,
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = currentAvatar();
    final cover = _mediaProvider(media['cover']);
    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: const Text('Personal profile'),
        actions: [
          TextButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: TinniBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
          children: [
            InkWell(
              key: const Key('profile-cover-photo'),
              borderRadius: BorderRadius.circular(16),
              onTap: uploadingSlot == null ? () => _uploadMedia('cover') : null,
              child: Container(
                height: 155,
                decoration: BoxDecoration(
                  color: TinniPalette.panel2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TinniPalette.bronze),
                  image: cover == null
                      ? null
                      : DecorationImage(
                          image: cover,
                          fit: BoxFit.cover,
                        ),
                ),
                child: Stack(
                  children: [
                    if (cover == null)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              color: TinniPalette.gold,
                              size: 38,
                            ),
                            SizedBox(height: 5),
                            Text('Add cover photo'),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 9,
                      bottom: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          uploadingSlot == 'cover'
                              ? 'Uploading…'
                              : cover == null
                                  ? 'Add cover'
                                  : 'Change cover',
                          style: const TextStyle(
                            color: TinniPalette.cream,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (cover != null && uploadingSlot != 'cover')
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          key: const Key('profile-cover-remove'),
                          tooltip: 'Remove cover',
                          onPressed: () => _removeMedia('cover'),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (uploadingSlot == 'cover')
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                key: const Key('personal-profile-avatar'),
                onTap: saving ? null : pickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: TinniPalette.panel2,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: TinniPalette.gold,
                            )
                          : null,
                    ),
                    const Positioned(
                      right: -2,
                      bottom: 0,
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
            ),
            const SizedBox(height: 20),
            TinniPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('DarkVibeX ID'),
                    subtitle: Text(widget.state.userId),
                    trailing: IconButton(
                      tooltip: 'Copy ID',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.state.userId),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID copied')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: nameController,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        counterText: '',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cake_rounded),
                    title: const Text('Age / Date of birth'),
                    subtitle: Text(
                      '$dobLabel • ${widget.state.ageChangesRemaining} changes left',
                    ),
                    trailing: Icon(
                      widget.state.ageChangesRemaining > 0
                          ? Icons.chevron_right_rounded
                          : Icons.lock_rounded,
                    ),
                    onTap: saving || widget.state.ageChangesRemaining <= 0
                        ? null
                        : pickDob,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.public_rounded),
                    title: const Text('Country'),
                    subtitle: Text(
                      countryName.isEmpty
                          ? 'Not selected'
                          : '$flagEmoji $countryName • ${widget.state.countryChangesRemaining} changes left',
                    ),
                    trailing: Icon(
                      widget.state.countryChangesRemaining > 0
                          ? Icons.chevron_right_rounded
                          : Icons.lock_rounded,
                    ),
                    onTap: saving || widget.state.countryChangesRemaining <= 0
                        ? null
                        : pickCountry,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender • ${widget.state.genderChangesRemaining} changes left',
                          style: const TextStyle(
                            color: TinniPalette.cream,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Male'),
                                selected: gender == 'male',
                                onSelected: saving ||
                                        widget.state.genderChangesRemaining <= 0
                                    ? null
                                    : (_) => setState(() => gender = 'male'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Female'),
                                selected: gender == 'female',
                                onSelected: saving ||
                                        widget.state.genderChangesRemaining <= 0
                                    ? null
                                    : (_) => setState(() => gender = 'female'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: const Text('Language'),
                    subtitle: Text(widget.state.languagePreference.value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Photos',
              style: TextStyle(
                color: TinniPalette.gold,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (loadingMedia)
              const Center(child: CircularProgressIndicator())
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.15,
                children: [
                  _mediaTile('life_1', 'Photos of life'),
                  _mediaTile('travel', 'Travel photo'),
                  _mediaTile('life_2', 'Life photo'),
                  _mediaTile('life_3', 'Add another life photo'),
                ],
              ),
            const SizedBox(height: 12),
            TinniPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.login_rounded),
                    title: const Text('Login provider'),
                    subtitle: Text(
                      widget.state.authProvider == 'google'
                          ? 'Google'
                          : 'Guest',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_rounded),
                    title: const Text('VIP'),
                    subtitle: Text(
                      'VIP ${widget.state.vipLevel}/18',
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
