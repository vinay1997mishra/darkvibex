/// Public, user-facing IDs are eight digits across the app.
/// Legacy seven-digit IDs are left-padded for display only; their stored
/// values are not rewritten because existing rooms can reference them.
String formatPublicUserId(dynamic value, {String fallback = '—'}) {
  final raw = value?.toString().trim() ?? '';
  if (raw == 'Hidden') return raw;
  if (RegExp(r'^[1-9]\d{6}$').hasMatch(raw) &&
      (int.tryParse(raw) ?? 0) >= 1000001) {
    return raw.padLeft(8, '0');
  }
  // Also accept already-formatted legacy IDs such as 01000001.
  if (RegExp(r'^\d{8}$').hasMatch(raw)) return raw;
  return fallback;
}

/// The ID a user types when blocking by ID: digits only, so "ID 07654001",
/// "0765 4001" and "7654001" all resolve to the same lookup.
String normalizePublicIdInput(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}
