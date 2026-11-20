import 'dart:ui';

class VipLevelRule {
  const VipLevelRule({
    required this.level,
    required this.totalExp,
    required this.upgradeExp,
    required this.maintainExp,
    this.validityDays = 30,
  });

  final int level;
  final double totalExp;
  final double upgradeExp;
  final double maintainExp;
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

  // VIP EXP ladder (Vinay, 2026-11-18): levels are defined in EXP, not in
  // $ or coins. totalExp is the CUMULATIVE EXP to reach the level and
  // equals the level's $ price x 150 (VIP1 $3 = 450 EXP ... VIP18 $10,000
  // = 1,500,000 EXP). upgradeExp is the incremental EXP from the previous
  // level. EXP is earned ONLY by buying coins from a Coin Seller — 150 EXP
  // per $1 spent ($1 = 8,000,000 coins); spending coins on gifts earns no
  // EXP. maintainExp is kept for parity with the worker; the expiry review
  // no longer has a maintain branch — at expiry you either level up by
  // buying coins or drop by exactly 1 level.
  // Must match apps/worker/src/vip_policy.js exactly — the EXP bug was
  // this table disagreeing with the worker. Validity: 30 days for
  // VIP1-15, 60 days for VIP16-18 (from the day of level-up).
  static const List<VipLevelRule> levels = <VipLevelRule>[
    VipLevelRule(level: 1, totalExp: 450, upgradeExp: 450, maintainExp: 450),
    VipLevelRule(level: 2, totalExp: 1200, upgradeExp: 750, maintainExp: 750),
    VipLevelRule(level: 3, totalExp: 3000, upgradeExp: 1800, maintainExp: 1800),
    VipLevelRule(level: 4, totalExp: 7500, upgradeExp: 4500, maintainExp: 4500),
    VipLevelRule(level: 5, totalExp: 22500, upgradeExp: 15000, maintainExp: 15000),
    VipLevelRule(level: 6, totalExp: 60000, upgradeExp: 37500, maintainExp: 37500),
    VipLevelRule(level: 7, totalExp: 135000, upgradeExp: 75000, maintainExp: 75000),
    VipLevelRule(level: 8, totalExp: 225000, upgradeExp: 90000, maintainExp: 90000),
    VipLevelRule(level: 9, totalExp: 315000, upgradeExp: 90000, maintainExp: 90000),
    VipLevelRule(level: 10, totalExp: 420000, upgradeExp: 105000, maintainExp: 105000),
    VipLevelRule(level: 11, totalExp: 510000, upgradeExp: 90000, maintainExp: 90000),
    VipLevelRule(level: 12, totalExp: 615000, upgradeExp: 105000, maintainExp: 105000),
    VipLevelRule(level: 13, totalExp: 705000, upgradeExp: 90000, maintainExp: 90000),
    VipLevelRule(level: 14, totalExp: 810000, upgradeExp: 105000, maintainExp: 105000),
    VipLevelRule(level: 15, totalExp: 975000, upgradeExp: 165000, maintainExp: 165000),
    VipLevelRule(level: 16, totalExp: 1140000, upgradeExp: 165000, maintainExp: 165000, validityDays: 60),
    VipLevelRule(level: 17, totalExp: 1320000, upgradeExp: 180000, maintainExp: 180000, validityDays: 60),
    VipLevelRule(level: 18, totalExp: 1500000, upgradeExp: 180000, maintainExp: 180000, validityDays: 60),
  ];

  static const List<VipPrivilege> privileges = <VipPrivilege>[
    VipPrivilege(id: 'vip_logo', title: 'VIP Logo', description: 'Level-specific VIP identity logo.', minLevel: 1),
    VipPrivilege(id: 'headframe', title: 'Headframe', description: 'Premium avatar headframe that improves with VIP level.', minLevel: 1),
    VipPrivilege(id: 'display_front', title: 'Display at the front', description: 'Priority placement in online/member lists.', minLevel: 1),
    VipPrivilege(id: 'view_visitors', title: 'View Visitors', description: 'See profile visitors.', minLevel: 1),
    VipPrivilege(id: 'exp_boost_1_1x', title: 'EXP Boost 1.1x', description: 'Earn 1.1x VIP EXP on every coin purchase.', minLevel: 1),
    VipPrivilege(id: 'chat_bubble', title: 'Chat Bubble', description: 'VIP chat bubble with richer styles at higher levels.', minLevel: 2),
    VipPrivilege(id: 'hide_last_online', title: 'Hide Last Online', description: 'Hide last-online information from the profile.', minLevel: 2),
    VipPrivilege(id: 'daily_rewards', title: 'Daily Rewards', description: 'Daily coin rewards, claimable every day from VIP5.', minLevel: 5),
    VipPrivilege(id: 'room_background', title: 'Change Room Background', description: 'Use a custom background in your own room.', minLevel: 3),
    // Friends Limit Expanded was REMOVED (Vinay, 2026-11-19):
    // "Friends limit nhi rakhni" — VIP4 keeps only Entrance Effect.
    VipPrivilege(id: 'entrance_effect', title: 'Entrance Effect', description: 'Level-specific room entrance banner/effect.', minLevel: 4),
    VipPrivilege(id: 'fantasy_card', title: 'Fantasy Card', description: 'Premium profile/fantasy card that improves with level.', minLevel: 5),
    VipPrivilege(id: 'free_say_hi', title: 'Free Say Hi', description: '4 free Say Hi messages; each message is limited to 30 words.', minLevel: 5),
    VipPrivilege(id: 'picture_welcome', title: 'Picture Welcome', description: 'Set a picture in the room welcome message.', minLevel: 5),
    VipPrivilege(id: 'message_roaming', title: 'Message Roaming', description: 'Cloud message history: VIP5-7 30 days, VIP8-11 60 days, VIP12+ 120 days.', minLevel: 5),
    VipPrivilege(id: 'show_id', title: 'Show ID', description: 'Decorative Show-ID skin. VIP14 style remains for VIP15-18.', minLevel: 5),
    VipPrivilege(id: 'exp_boost_1_2x', title: 'EXP Boost 1.2x', description: 'Earn 1.2x VIP EXP on every coin purchase.', minLevel: 5),
    VipPrivilege(id: 'coins_bonus_5', title: 'Coins Bonus +5%', description: 'Get 5% extra coins free on every coin purchase.', minLevel: 5),
    VipPrivilege(id: 'name_colour', title: 'Name Colour', description: 'Show your name in a custom VIP colour (VIP5-18).', minLevel: 5, maxLevel: 18),
    VipPrivilege(id: 'exclusive_gifts', title: 'Exclusive Gifts', description: 'Send special VIP gifts with exclusive effects.', minLevel: 3),
    VipPrivilege(id: 'red_envelope', title: 'Message Red Envelope', description: 'Send red-envelope rewards in private messages.', minLevel: 6),
    VipPrivilege(id: 'dynamic_avatar', title: 'Dynamic Avatar', description: 'Use an animated/dynamic avatar.', minLevel: 7),
    VipPrivilege(id: 'many_seats', title: 'Room With Many Seats', description: 'DarkVibeX rooms use the Tinnistar 8–42 seat layouts.', minLevel: 7),
    VipPrivilege(id: 'nickname_light', title: 'Nickname Light Effect', description: 'Exclusive nickname light effect from VIP8 through VIP17.', minLevel: 8, maxLevel: 17),
    VipPrivilege(id: 'disable_say_hi', title: 'Disable Say Hi', description: 'Prevent other users from initiating Say Hi with you.', minLevel: 8),
    VipPrivilege(id: 'gift_discount_10', title: 'Gift Discount 10%', description: 'Pay 10% less for every gift you send.', minLevel: 8),
    VipPrivilege(id: 'entrance_vehicle', title: 'Entrance Vehicle', description: 'Level-specific entrance vehicle; higher VIP means more premium vehicles. VIP5-15 bottom 40%, VIP16-18 full-screen.', minLevel: 5),
    VipPrivilege(id: 'exclusive_mic_emoticon', title: 'Exclusive Mic Emoticon', description: 'Use a special animated microphone emoticon while speaking.', minLevel: 9),
    VipPrivilege(id: 'customer_service', title: 'Exclusive Customer Service', description: 'Dedicated VIP support channel.', minLevel: 9),
    VipPrivilege(id: 'priority_message', title: 'Priority Message', description: 'Your messages appear at the top in crowded rooms.', minLevel: 9),
    VipPrivilege(id: 'send_pictures', title: 'Send Pictures in Chatroom', description: 'Send picture messages inside chatrooms.', minLevel: 10),
    VipPrivilege(id: 'hide_charm', title: 'Hide Charm Level', description: 'Hide charm level on public surfaces.', minLevel: 10),
    VipPrivilege(id: 'vip_only_rooms', title: 'VIP-Only Rooms', description: 'Enter rooms reserved for VIP members.', minLevel: 10),
    VipPrivilege(id: 'hide_visitors', title: 'Hide Visitor Records', description: 'Hide your visitor records.', minLevel: 11),
    VipPrivilege(id: 'anonymous_ranking', title: 'Anonymous on Ranking List', description: 'Appear as a mysterious/anonymous user on rankings.', minLevel: 11),
    VipPrivilege(id: 'exp_boost_1_4x', title: 'EXP Boost 1.4x', description: 'Earn 1.4x VIP EXP on every coin purchase.', minLevel: 11),
    VipPrivilege(id: 'coins_bonus_10', title: 'Coins Bonus +10%', description: 'Get 10% extra coins free on every coin purchase.', minLevel: 11),
    VipPrivilege(id: 'vip_news', title: 'Display in News', description: 'VIP upgrades can be highlighted in DarkVibeX News.', minLevel: 12),
    VipPrivilege(id: 'seat_protection', title: 'Remove From Seat Protection', description: 'Protect your occupied seat from forced removal.', minLevel: 13),
    VipPrivilege(id: 'anti_mute', title: 'Anti-Mute', description: 'Protection from being muted in rooms.', minLevel: 13),
    VipPrivilege(id: 'invisible_entry', title: 'Enter Chat Room Invisible', description: 'Enter rooms without a public join notice.', minLevel: 14),
    VipPrivilege(id: 'kick_protection', title: 'Kick Out Protection', description: 'Protection from normal room kick actions.', minLevel: 14),
    VipPrivilege(id: 'gift_discount_20', title: 'Gift Discount 20%', description: 'Pay 20% less for every gift you send.', minLevel: 14),
    VipPrivilege(id: 'unique_id', title: 'Unique ID', description: 'Unique ID customization unlocked from VIP15.', minLevel: 15),
    VipPrivilege(id: 'splash_recommend', title: 'Recommend on Splash', description: 'One-day featured recommendation on the splash surface.', minLevel: 15),
    VipPrivilege(id: 'privacy_protection', title: 'Privacy Protection', description: 'Protect profile/avatar media from ordinary save/screenshot flows where supported.', minLevel: 15),
    VipPrivilege(id: 'custom_avatar_frame', title: 'Customized Avatar Frame', description: 'Use a premium customized avatar frame.', minLevel: 16),
    VipPrivilege(id: 'exclusive_mic_effect', title: 'Exclusive Mic Effect', description: 'Premium effect around your mic/avatar while speaking.', minLevel: 16),
    VipPrivilege(id: 'card_background', title: 'Exclusive Card Background', description: 'Use an exclusive VIP profile-card background.', minLevel: 17),
    VipPrivilege(id: 'mic_chair', title: 'Mic Chair', description: 'Personal premium chair/effect while on mic.', minLevel: 18),
    VipPrivilege(id: 'anonymous_everywhere', title: 'Anonymous Everywhere', description: 'When enabled, hide your name on game wins, banners, room history and other public activity surfaces.', minLevel: 18),
    VipPrivilege(id: 'honorary_title', title: 'Honorary Title', description: 'Top-tier honorary VIP title.', minLevel: 18),
    VipPrivilege(id: 'gift_discount_30', title: 'Gift Discount 30%', description: 'Pay 30% less for every gift you send.', minLevel: 18),
    VipPrivilege(id: 'valid_60_days', title: '60-Day Validity', description: 'VIP16-18 validity extends from 30 days to 60 days.', minLevel: 16),
    VipPrivilege(id: 'exp_boost_1_5x', title: 'EXP Boost 1.5x', description: 'Earn 1.5x VIP EXP on every coin purchase.', minLevel: 16),
    VipPrivilege(id: 'coins_bonus_20', title: 'Coins Bonus +20%', description: 'Get 20% extra coins free on every coin purchase.', minLevel: 16),
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

  // VIP EXP boost (Vinay, 2026-11-19): the EXP earned on a coin
  // purchase is multiplied by the level boost — VIP1-4 1.1x, VIP5-10
  // 1.2x, VIP11-15 1.4x, VIP16-18 1.5x. Inactive VIPs earn at the base
  // 1.0x rate. The base rate (150 EXP per $1) and the thresholds are
  // unchanged; keep this in sync with expBoostForLevel in
  // apps/worker/src/vip_policy.js.
  static double expMultiplier(int level, {required bool active}) {
    if (!active) return 1.0;
    if (level >= 16) return 1.5;
    if (level >= 11) return 1.4;
    if (level >= 5) return 1.2;
    if (level >= 1) return 1.1;
    return 1.0;
  }

  // Coins bonus on purchase (Vinay, 2026-11-19): extra coins credited
  // free on every coin purchase — VIP5-10 +5%, VIP11-15 +10%,
  // VIP16-18 +20%. Keep in sync with coinsBonusForLevel in
  // apps/worker/src/vip_policy.js.
  static double coinsBonusRate(int level, {required bool active}) {
    if (!active) return 0;
    if (level >= 16) return 0.20;
    if (level >= 11) return 0.10;
    if (level >= 5) return 0.05;
    return 0;
  }

  // Gift discount (Vinay, 2026-11-19): the sender pays less for every
  // gift — VIP8-13 10%, VIP14-17 20%, VIP18 30%. Keep in sync with
  // giftDiscountForVipLevel in apps/worker/src/vip_policy.js.
  static double giftDiscountRate(int level, {required bool active}) {
    if (!active) return 0;
    if (level >= 18) return 0.30;
    if (level >= 14) return 0.20;
    if (level >= 8) return 0.10;
    return 0;
  }

  // Name colours (Vinay, 2026-11-20): a VIP-active user's name shows
  // in their level colour in room chat and on profiles, VIP5-18 only.
  // One distinct colour per level, gold at the bottom rising to a
  // gold-to-red gradient at VIP18. Levels below 5 have no colour.
  static const Map<int, Color> nameColours = <int, Color>{
    5: Color(0xFFFFD700), // Gold
    6: Color(0xFFFFB11B), // Amber
    7: Color(0xFFFF8C00), // Orange
    8: Color(0xFFC07DFF), // Light Violet
    9: Color(0xFF9B32FF), // Purple
    10: Color(0xFFA64DFF), // Bright Purple
    11: Color(0xFF4DC3FF), // Sky Blue
    12: Color(0xFF00E5FF), // Cyan
    13: Color(0xFF3D7BFF), // Royal Blue
    14: Color(0xFFFF5C8A), // Rose
    15: Color(0xFFFF2E4D), // Crimson
    16: Color(0xFFFF2EA6), // Magenta
    17: Color(0xFFFF4D00), // Phoenix Fire
  };

  /// Solid name colour for an active VIP [level], or null when the
  /// level has no colour (below VIP5, or VIP18 which is a gradient).
  static Color? nameColourForLevel(int level) {
    if (level < 5 || level > 18) return null;
    return nameColours[level];
  }

  /// Gradient name colours for an active VIP [level], or null when the
  /// level uses a solid colour. Only VIP18 is a gradient (gold to red).
  static List<Color>? nameGradientForLevel(int level) {
    if (level != 18) return null;
    return const <Color>[Color(0xFFFFD700), Color(0xFFFF2E4D)];
  }

  // Anti-Mute (Vinay, 2026-11-20): an active VIP13+ member cannot be
  // muted by anyone else. Muting your own seat is unaffected.
  static bool hasAntiMute(int level, {required bool active}) =>
      active && level >= 13;

  // VIP-only room entry (Vinay, 2026-11-20): a room with entry
  // threshold 1 admits any active VIP, threshold 5 admits VIP5+.
  static bool canEnterVipOnlyRoom(
    int level, {
    required bool active,
    required int requiredLevel,
  }) =>
      active && level >= requiredLevel;

  static int validityDays(int level) => level >= 16 ? 60 : 30;
}

