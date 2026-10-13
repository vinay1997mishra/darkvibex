import 'dart:typed_data';

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
  Uint8List? avatarBytes;
  String avatarExtension = 'jpg';
  String avatarContentType = 'image/jpeg';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: widget.state.displayName);
    final raw = widget.state.dateOfBirth?.trim() ?? '';
    dob = raw.isEmpty ? null : DateTime.tryParse(raw);
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

  Future<void> save() async {
    if (saving) return;
    final name = nameController.text.trim();
    if (name.isEmpty || dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and date of birth are required'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    final ok = await widget.state.completeLoginProfile(
      name: name,
      dateOfBirthValue: dobApiValue,
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
                    title: const Text('Date of birth'),
                    subtitle: Text(dobLabel),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: saving ? null : pickDob,
                  ),
                ],
              ),
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
