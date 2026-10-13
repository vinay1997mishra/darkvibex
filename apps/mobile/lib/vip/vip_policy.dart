class VipLevelRule {
  const VipLevelRule({
    required this.level,
    required this.totalRechargeCoins,
    required this.upgradeExp,
    required this.maintainExp,
    this.validityDays = 30,
  });

  final int level;
  final int totalRechargeCoins;
  final int upgradeExp;
  final int maintainExp;
  final int validityDays;
}

class VipPrivilege {
  const VipPrivilege({
    required this.id,
    required this.title,
    required this.description,
    required this.minLevel,
    this.maxLevel,
  });

  final String id;
  final String title;
  final String description;
  final int minLevel;
  final int? maxLevel;

  bool isUnlockedAt(int level) =>
      level >= minLevel && (maxLevel == null || level <= maxLevel!);
}

class VipPolicy {
  VipPolicy._();

  static const int maxLevel = 18;
  static const int freeSayHiUses = 4;
  static const int freeSayHiMaxWords = 30;

  static const List<VipLevelRule> levels = <VipLevelRule>[
    VipLevelRule(level: 1, totalRechargeCoins: 35000000, upgradeExp: 87500, maintainExp: 75),
    VipLevelRule(level: 2, totalRechargeCoins: 135000000, upgradeExp: 250000, maintainExp: 75),
    VipLevelRule(level: 3, totalRechargeCoins: 335000000, upgradeExp: 500000, maintainExp: 225),
    VipLevelRule(level: 4, totalRechargeCoins: 735000000, upgradeExp: 1000000, maintainExp: 1250),
    VipLevelRule(level: 5, totalRechargeCoins: 1735000000, upgradeExp: 2500000, maintainExp: 3250),
    VipLevelRule(level: 6, totalRechargeCoins: 3235000000, upgradeExp: 3750000, maintainExp: 6500),
    VipLevelRule(level: 7, totalRechargeCoins: 5985000000, upgradeExp: 6875000, maintainExp: 11250),
    VipLevelRule(level: 8, totalRechargeCoins: 9485000000, upgradeExp: 8750000, maintainExp: 19500),
    VipLevelRule(level: 9, totalRechargeCoins: 13985000000, upgradeExp: 11250000, maintainExp: 27500),
    VipLevelRule(level: 10, totalRechargeCoins: 20235000000, upgradeExp: 15625000, maintainExp: 35000),
    VipLevelRule(level: 11, totalRechargeCoins: 27735000000, upgradeExp: 18750000, maintainExp: 70000),
    VipLevelRule(level: 12, totalRechargeCoins: 36735000000, upgradeExp: 22500000, maintainExp: 207500),
    VipLevelRule(level: 13, totalRechargeCoins: 47235000000, upgradeExp: 26250000, maintainExp: 375000),
    VipLevelRule(level: 14, totalRechargeCoins: 57735000000, upgradeExp: 26250000, maintainExp: 775000),
    VipLevelRule(level: 15, totalRechargeCoins: 69235000000, upgradeExp: 28750000, maintainExp: 1750000),
    VipLevelRule(level: 16, totalRechargeCoins: 80735000000, upgradeExp: 28750000, maintainExp: 3500000),
    VipLevelRule(level: 17, totalRechargeCoins: 92235000000, upgradeExp: 28750000, maintainExp: 7500000),
    VipLevelRule(level: 18, totalRechargeCoins: 103735000000, upgradeExp: 28750000, maintainExp: 10000000, validityDays: 45),
  ];

  static const List<VipPrivilege> privileges = <VipPrivilege>[
    VipPrivilege(id: 'vip_logo', title: 'VIP Logo', description: 'Level-specific VIP identity logo.', minLevel: 1),
    VipPrivilege(id: 'headframe', title: 'Headframe', description: 'Premium avatar headframe that improves with VIP level.', minLevel: 1),
    VipPrivilege(id: 'display_front', title: 'Display at the front', description: 'Priority placement in online/member lists.', minLevel: 1),
    VipPrivilege(id: 'view_visitors', title: 'View Visitors', description: 'See profile visitors.', minLevel: 1),
    VipPrivilege(id: 'chat_bubble', title: 'Chat Bubble', description: 'VIP chat bubble with richer styles at higher levels.', minLevel: 2),
    VipPrivilege(id: 'hide_last_online', title: 'Hide Last Online', description: 'Hide last-online information from the profile.', minLevel: 2),
    VipPrivilege(id: 'room_background', title: 'Change Room Background', description: 'Use a custom background in your own room.', minLevel: 3),
    VipPrivilege(id: 'friends_limit', title: 'Friends Limit Expanded', description: '300 friends for non-VIP; unlimited friends while VIP is active.', minLevel: 4),
    VipPrivilege(id: 'entrance_effect', title: 'Entrance Effect', description: 'Level-specific room entrance banner/effect.', minLevel: 4),
    VipPrivilege(id: 'fantasy_card', title: 'Fantasy Card', description: 'Premium profile/fantasy card that improves with level.', minLevel: 5),
    VipPrivilege(id: 'free_say_hi', title: 'Free Say Hi', description: '4 free Say Hi messages; each message is limited to 30 words.', minLevel: 5),
    VipPrivilege(id: 'picture_welcome', title: 'Picture Welcome', description: 'Set a picture in the room welcome message.', minLevel: 5),
    VipPrivilege(id: 'message_roaming', title: 'Message Roaming', description: 'Cloud message history: VIP5-7 30 days, VIP8-11 60 days, VIP12+ 120 days.', minLevel: 5),
    VipPrivilege(id: 'show_id', title: 'Show ID', description: 'Decorative Show-ID skin. VIP14 style remains for VIP15-18.', minLevel: 5),
    VipPrivilege(id: 'exclusive_gifts', title: 'Exclusive Gifts', description: 'Send special VIP gifts with exclusive effects.', minLevel: 3),
    VipPrivilege(id: 'red_envelope', title: 'Message Red Envelope', description: 'Send red-envelope rewards in private messages.', minLevel: 6),
    VipPrivilege(id: 'dynamic_avatar', title: 'Dynamic Avatar', description: 'Use an animated/dynamic avatar.', minLevel: 7),
    VipPrivilege(id: 'many_seats', title: 'Room With Many Seats', description: 'DarkVibeX rooms use the Tinnistar 8–42 seat layouts.', minLevel: 7),
    VipPrivilege(id: 'hide_country', title: 'Hide Country', description: 'Hide country information from the profile.', minLevel: 8),
    VipPrivilege(id: 'nickname_light', title: 'Nickname Light Effect', description: 'Exclusive nickname light effect from VIP8 through VIP17.', minLevel: 8, maxLevel: 17),
    VipPrivilege(id: 'disable_say_hi', title: 'Disable Say Hi', description: 'Prevent other users from initiating Say Hi with you.', minLevel: 8),
    VipPrivilege(id: 'entrance_vehicle', title: 'Entrance Vehicle', description: 'Level-specific entrance vehicle; higher VIP means more premium vehicles.', minLevel: 8),
    VipPrivilege(id: 'exclusive_mic_emoticon', title: 'Exclusive Mic Emoticon', description: 'Use a special animated microphone emoticon while speaking.', minLevel: 9),
    VipPrivilege(id: 'customer_service', title: 'Exclusive Customer Service', description: 'Dedicated VIP support channel.', minLevel: 9),
    VipPrivilege(id: 'send_pictures', title: 'Send Pictures in Chatroom', description: 'Send picture messages inside chatrooms.', minLevel: 10),
    VipPrivilege(id: 'hide_charm', title: 'Hide Charm Level', description: 'Hide charm level on public surfaces.', minLevel: 10),
    VipPrivilege(id: 'hide_visitors', title: 'Hide Visitor Records', description: 'Hide your visitor records.', minLevel: 11),
    VipPrivilege(id: 'anonymous_ranking', title: 'Anonymous on Ranking List', description: 'Appear as a mysterious/anonymous user on rankings.', minLevel: 11),
    VipPrivilege(id: 'vip_news', title: 'Display in News', description: 'VIP upgrades can be highlighted in DarkVibeX News.', minLevel: 12),
    VipPrivilege(id: 'seat_protection', title: 'Remove From Seat Protection', description: 'Protect your occupied seat from forced removal.', minLevel: 13),
    VipPrivilege(id: 'invisible_entry', title: 'Enter Chat Room Invisible', description: 'Enter rooms without a public join notice.', minLevel: 14),
    VipPrivilege(id: 'kick_protection', title: 'Kick Out Protection', description: 'Protection from normal room kick actions.', minLevel: 14),
    VipPrivilege(id: 'unique_id', title: 'Unique ID', description: 'Unique ID customization unlocked from VIP15.', minLevel: 15),
    VipPrivilege(id: 'splash_recommend', title: 'Recommend on Splash', description: 'One-day featured recommendation on the splash surface.', minLevel: 15),
    VipPrivilege(id: 'privacy_protection', title: 'Privacy Protection', description: 'Protect profile/avatar media from ordinary save/screenshot flows where supported.', minLevel: 15),
    VipPrivilege(id: 'custom_avatar_frame', title: 'Customized Avatar Frame', description: 'Use a premium customized avatar frame.', minLevel: 16),
    VipPrivilege(id: 'exclusive_mic_effect', title: 'Exclusive Mic Effect', description: 'Premium effect around your mic/avatar while speaking.', minLevel: 16),
    VipPrivilege(id: 'card_background', title: 'Exclusive Card Background', description: 'Use an exclusive VIP profile-card background.', minLevel: 17),
    VipPrivilege(id: 'mic_chair', title: 'Mic Chair', description: 'Personal premium chair/effect while on mic.', minLevel: 18),
    VipPrivilege(id: 'anonymous_everywhere', title: 'Anonymous Everywhere', description: 'When enabled, hide your name on game wins, banners, room history and other public activity surfaces.', minLevel: 18),
    VipPrivilege(id: 'honorary_title', title: 'Honorary Title', description: 'Top-tier honorary VIP title.', minLevel: 18),
    VipPrivilege(id: 'valid_45_days', title: '45-Day Validity', description: 'VIP18 validity extends from 30 days to 45 days.', minLevel: 18),
  ];

  static VipLevelRule? ruleFor(int level) {
    if (level < 1 || level > maxLevel) return null;
    return levels[level - 1];
  }

  static List<VipPrivilege> unlockedAt(int level) =>
      privileges.where((item) => item.isUnlockedAt(level)).toList(growable: false);

  static int? friendLimit(int level, {required bool active}) => active ? null : 300;

  static int friendBonus(int level) => 0;


  static int maxRoomSeats(int level) => 42;

  static int messageRetentionDays(int level) {
    if (level >= 12) return 120;
    if (level >= 8) return 60;
    if (level >= 5) return 30;
    return 0;
  }

  static int showIdStyleLevel(int level) {
    if (level < 5) return 0;
    return level > 14 ? 14 : level;
  }

  static double expMultiplier(int level, {required bool active}) => 1.0;

  static int validityDays(int level) => level >= 18 ? 45 : 30;
}

