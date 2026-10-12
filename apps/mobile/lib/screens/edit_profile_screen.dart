import 'package:flutter/material.dart';

import '../app/app_state.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.state});
  final AppState state;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name;
  late final TextEditingController country;
  late String gender;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.state.displayName);
    country = TextEditingController(text: widget.state.countryCode);
    gender = const {'male', 'female', 'other'}.contains(widget.state.gender)
        ? widget.state.gender
        : 'other';
  }

  @override
  void dispose() {
    name.dispose();
    country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    final ok = await widget.state.saveProfile(
      displayName: name.text,
      countryCode: country.text,
      gender: gender,
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) {
      Navigator.pop(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a name and a two-letter country code.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: country,
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Country code (for example, IN)'),
            ),
            DropdownButtonFormField<String>(
              value: gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => gender = value ?? 'other'),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving…' : 'Save profile')),
          ],
        ),
      );
}
