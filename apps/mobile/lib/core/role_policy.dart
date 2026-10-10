enum DarkVibeXRole {
  user,
  roomOwner,
  roomAdmin,
  moderator,
  coinSeller,
  merchant,
  platformOwner,
}

class RolePolicy {
  const RolePolicy._();

  static const Set<String> blockedLegacyRoles = {
    'host',
    'agency',
    'bd',
  };

  static DarkVibeXRole parse(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();

    if (blockedLegacyRoles.contains(normalized)) {
      throw StateError('Legacy hierarchy role is not supported by DarkVibeX.');
    }

    return switch (normalized) {
      'room_owner' => DarkVibeXRole.roomOwner,
      'room_admin' => DarkVibeXRole.roomAdmin,
      'moderator' => DarkVibeXRole.moderator,
      'coin_seller' => DarkVibeXRole.coinSeller,
      'merchant' => DarkVibeXRole.merchant,
      'platform_owner' => DarkVibeXRole.platformOwner,
      _ => DarkVibeXRole.user,
    };
  }
}
