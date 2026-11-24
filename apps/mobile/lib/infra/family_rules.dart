// Family rules (Mr. Wrong, 2026-11-24): the other app's numbers x1.5
// (6M there = 9M here). Pure Dart mirror of apps/worker/src/family_rules.js
// — keep the two in sync. The create cost 90,000,000 is already final
// and is NOT scaled again here.
//
// Observed points (exact after x1.5): Lv.4 needs 3,240,000,000 EXP,
// Lv.17 needs 157,125,000,000 EXP. The rest of the ladder is a geometric
// fit through those two points (x1.3479 per level). Member/deputy limits,
// vault rewards, task rewards and weekly rewards come from the Family
// Rules video tables and the Family Weekly Rewards video; the 510M-tier
// leader coins (37,875,000) and the top6-top15 weekly steps are
// interpolated, NOT observed — see family_rules.js.

/// Total family EXP needed to BE at each level (index = level - 1).
const List<int> familyLevelExp = <int>[
  0, 1783000000, 2404000000, 3240000000, 4367000000, 5887000000,
  7935000000, 10696000000, 14418000000, 19434000000, 26196000000,
  35310000000, 47596000000, 64156000000, 86478000000, 116567000000,
  157125000000, 211794000000, 285485000000, 384816000000, 518707000000,
  699184000000, 942455000000, 1270369000000, 1712377000000, 2308174000000,
  3111271000000, 4193794000000, 5652965000000, 7619835000000,
  10271050000000, 13844717000000, 18661791000000, 25154899000000,
  33907193000000, 45704723000000, 61607039000000, 83042342000000,
  111935757000000, 150882230000000, 203379580000000, 274142645000000,
  369526724000000, 498098351000000, 671404668000000, 905010481000000,
  1219896151000000, 1644341862000000, 2216467490000000, 2987656185000000,
];

const int familyMaxLevel = 50;

({int level, int? nextExp}) familyLevelForExp(num experience) {
  final exp = experience < 0 ? 0 : experience.floor();
  var level = 1;
  for (var i = 1; i < familyLevelExp.length; i++) {
    if (exp >= familyLevelExp[i]) {
      level = i + 1;
    } else {
      break;
    }
  }
  return (
    level: level,
    nextExp: level < familyMaxLevel ? familyLevelExp[level] : null,
  );
}

/// Member limit per level (other app x1.5): Lv.1 60 ... Lv.50 495.
int familyMemberLimit(int level) {
  final l = level.clamp(1, familyMaxLevel);
  final base = l <= 41 ? 35 + 5 * l : 240 + 10 * (l - 41);
  return (base * 1.5 + 0.5).floor();
}

/// Deputy (admin) limit per level (other app x1.5): Lv.1-5: 3 ... Lv.30+: 18.
int familyDeputyLimit(int level) {
  final l = level.clamp(1, familyMaxLevel);
  const thresholds = <int>[6, 9, 12, 15, 18, 21, 24, 26, 28, 30];
  final base = 2 + thresholds.where((t) => t <= l).length;
  return (base.clamp(0, 12) * 1.5 + 0.5).floor();
}

/// Vault coins the family vault receives on reaching [level].
int familyUpgradeVaultReward(int level) {
  if (level <= 1) return 0;
  if (level == 2) return 6075000;
  if (level == 3) return 8100000;
  if (level == 4) return 10125000;
  if (level == 5) return 12150000;
  if (level <= 10) return 13500000;
  if (level <= 15) return 16875000;
  if (level <= 20) return 20250000;
  if (level <= 25) return 28350000;
  if (level <= 30) return 40500000;
  if (level <= 35) return 56700000;
  if (level <= 40) return 81000000;
  if (level <= 45) return 101250000;
  return 121500000;
}

/// Monthly vault coins for the top-10 families of the month.
int familyMonthlyVaultReward(int rank) {
  if (rank == 1) return 40500000;
  if (rank == 2) return 24300000;
  if (rank == 3) return 16200000;
  if (rank >= 4 && rank <= 6) return 8100000;
  if (rank >= 7 && rank <= 10) return 4050000;
  return 0;
}

/// Daily task rewards (other app x1.5): EXP for the family + coins for
/// the user who completes the task.
const Map<String, ({int exp, int coins})> familyTaskRewards = <String, ({int exp, int coins})>{
  'signIn': (exp: 405000, coins: 8100),
  'stay20': (exp: 1215000, coins: 8100),
  'mic10': (exp: 2025000, coins: 8100),
};

/// Gift EXP: 1 coin = 1 EXP; x2 when giver and receiver are in the same
/// family; only 10% counts for Lucky gifts.
int familyGiftExp(num coins, bool sameFamily, String giftCategory) {
  final base = coins < 0 ? 0 : coins.floor();
  final factor =
      giftCategory == 'lucky' || giftCategory == 'rebate' ? 0.1 : 1.0;
  return (base * (sameFamily ? 2 : 1) * factor).floor();
}

/// Games: 100 coins bet = 1 EXP.
int familyGameExp(num coins) => (coins < 0 ? 0 : coins.floor()) ~/ 100;

// ---------------------------------------------------------------------------
// Family Weekly Rewards (Mr. Wrong, 2026-11-24): "Send gifts and win
// rewards!" Week = Monday 00:00 to Sunday 23:59 UTC+3.
// ---------------------------------------------------------------------------

/// A member's weekly gifts must be over this to receive a top reward.
const int familyWeeklyEligibilityCoins = 7200000;

/// Weekly tiers: threshold (weekly gift coins) + leader coins.
const List<({int threshold, int leaderCoins})> familyWeeklyTiers =
    <({int threshold, int leaderCoins})>[
  (threshold: 148500000, leaderCoins: 6750000),
  (threshold: 315000000, leaderCoins: 15150000),
  (threshold: 765000000, leaderCoins: 37875000),
];

/// Weekly top-15 coins (other app x1.5).
int familyWeeklyTopCoins(int rank) {
  if (rank == 1) return 2400000;
  if (rank == 2) return 1800000;
  if (rank == 3) return 1065000;
  if (rank >= 4 && rank <= 15) {
    return ((390000 - (rank - 4) * (255000 / 11)) / 1000).round() * 1000;
  }
  return 0;
}

/// Family Rank ladder, by the family's EXP this month. The Silver III ->
/// Silver II band width (11,070,000,000) is the one observed band
/// (7,380,000,000 x1.5); the other bands follow the same doubling shape.
const List<({String name, int threshold})> familyRankLadder =
    <({String name, int threshold})>[
  (name: 'Iron III', threshold: 0),
  (name: 'Iron II', threshold: 225000000),
  (name: 'Iron I', threshold: 450000000),
  (name: 'Bronze III', threshold: 900000000),
  (name: 'Bronze II', threshold: 1800000000),
  (name: 'Bronze I', threshold: 3600000000),
  (name: 'Silver III', threshold: 7200000000),
  (name: 'Silver II', threshold: 18270000000),
  (name: 'Silver I', threshold: 29340000000),
  (name: 'Gold III', threshold: 45000000000),
  (name: 'Gold II', threshold: 67500000000),
  (name: 'Gold I', threshold: 101000000000),
  (name: 'Platinum III', threshold: 152000000000),
  (name: 'Platinum II', threshold: 228000000000),
  (name: 'Platinum I', threshold: 342000000000),
  (name: 'Diamond III', threshold: 513000000000),
  (name: 'Diamond II', threshold: 770000000000),
  (name: 'Diamond I', threshold: 1155000000000),
];

({String rank, int progress, int need, String? nextRank})
    familyRankForMonthlyExp(num monthlyExp) {
  final exp = monthlyExp < 0 ? 0 : monthlyExp.floor();
  var index = 0;
  for (var i = 1; i < familyRankLadder.length; i++) {
    if (exp >= familyRankLadder[i].threshold) {
      index = i;
    } else {
      break;
    }
  }
  final current = familyRankLadder[index];
  final next =
      index + 1 < familyRankLadder.length ? familyRankLadder[index + 1] : null;
  return (
    rank: current.name,
    progress: exp - current.threshold,
    need: next != null ? next.threshold - current.threshold : 0,
    nextRank: next?.name,
  );
}

/// Format a big coin/EXP number like the other app: 58876.59M, 185.85M,
/// 9.09M, 710.00K, 1.60M.
String formatFamilyCoins(num value) {
  final v = value.toDouble();
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)}K';
  return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 2);
}

// ---------------------------------------------------------------------------
// Family Rules text (the "?" button, Mr. Wrong 2026-11-24). The full set
// from the other app's Family Rules, with our numbers (90M create cost,
// x1.5 levels/rewards). Shared by TopFamiliesScreen (PR #218) and the
// family pages so they all show the same rules.
// ---------------------------------------------------------------------------

const List<({String title, String body})> familyRulesSections =
    <({String title, String body})>[
  (
    title: 'What is family?',
    body: 'A family is an organization that connects users. After joining '
        'a family, you will have a common identity and goal, and work '
        'together for the family. Each user can only join one family.',
  ),
  (
    title: 'How to create a family?',
    body: 'Users who do not have a family yet can click \'Create\' at the '
        'bottom of the monthly ranking to create a family. Users whose '
        'wealth level is ≥30, or whose VIP level is VIP 6, can create it '
        'for free. Other users need to pay 90,000,000 coins to create.',
  ),
  (
    title: 'What is family experience?',
    body: 'After joining a family, users can gain experience points by '
        'completing daily tasks, giving gifts, receiving gifts, playing '
        'games or participating in special family events. Giving gifts '
        'gains experience points at a 1:1 ratio (giving gifts to the '
        'family gains experience points x2), and receiving gifts gains '
        'experience points at a 1:1 ratio (receiving gifts to the family '
        'gains experience points x2). If the gift giver and the gift '
        'receiver are in the same family, the experience points will be '
        'calculated. Please note that only 10% of the experience points '
        'for the rebate gifts and the Lucky gifts are counted.',
  ),
  (
    title: 'What are Family Daily Tasks?',
    body: 'After joining the family, users can complete designated tasks '
        'every day to gain experience points. The task is refreshed at '
        '0 o\'clock every day (0 o\'clock in the time zone of the '
        'family\'s region). After completion, you can accumulate more Exp '
        'by giving and receiving gifts.\n'
        '• Sign in on the family homepage — 405,000 EXP + 8,100 coins\n'
        '• Enter any family room and stay for 20 minutes — 1,215,000 EXP + 8,100 coins\n'
        '• Enter any family room and turn on the mic for 10 minutes — 2,025,000 EXP + 8,100 coins\n'
        '• Send gift: 1 coin = 1 EXP (family gift experience x2) — no upper limit\n'
        '• Receive gift: 1 coin = 1 EXP (family gift experience x2) — no upper limit\n'
        '• Play games: 100 coins = 1 EXP — no upper limit',
  ),
  (
    title: 'What is the identity of the family?',
    body: 'Family Leader can: remove members, review the joining '
        'application, edit basic family information, edit family '
        'declaration, appoint management, edit family notice.\n'
        'Deputy Family Leader can: remove members, review the joining '
        'application, edit family notice.',
  ),
  (
    title: 'How many levels are there in the family?',
    body: 'There are currently 50 levels of families. High-level families '
        'have more gorgeous level logos, higher number limit of members, '
        'and more management appointments.\n'
        '• Lv.1: 60 members, 3 deputies\n'
        '• Lv.5: 90 members, 3 deputies\n'
        '• Lv.10: 128 members, 6 deputies\n'
        '• Lv.20: 203 members, 11 deputies\n'
        '• Lv.30: 278 members, 18 deputies\n'
        '• Lv.50: 495 members, 18 deputies',
  ),
  (
    title: 'What is a family member ranking list?',
    body: 'This month\'s Charm Star is ranked based on the family member\'s '
        'contribution to receiving gifts this month, and this month\'s '
        'Wealth Star is ranked based on the family member\'s contribution '
        'to giving gifts this month. This month\'s Active Star is ranked '
        'based on the number of minutes the family members are active in '
        'the family room. On the 1st of every month, the top three '
        'families in the Charm, Wealth, and Active Star rankings will '
        'receive avatar frame rewards.',
  ),
  (
    title: 'What are the benefits of the family?',
    body: '1. Family tag: the family tag will be shown on the room '
        'profile card, room comments, personal homepage and other places.\n'
        '2. Send family gifts in the room with the family\'s special logo.\n'
        '3. The monthly list will be settled on the 1st of each month, '
        'and the monthly list will be ranked according to the family\'s '
        'experience value this month. Families in the top 3 of the '
        'monthly list will receive family vault rewards. The coins '
        'rewarded by the family vault are at the disposal of the family '
        'leader.\n'
        'Monthly vault: No.1 40,500,000; No.2 24,300,000; No.3 16,200,000; '
        'No.4-6 8,100,000; No.7-10 4,050,000.\n'
        '4. Family upgrade rewards: the family vault receives coins when '
        'the family levels up — Lv.2 6,075,000 up to Lv.46-50 121,500,000.',
  ),
  (
    title: 'How to quit the family?',
    body: 'Click on the upper right corner of the family homepage to exit '
        'the family. The family leader can only withdraw when there is '
        'only one person left in the family. After leaving the family, '
        'the family will disappear from the monthly ranking, and your '
        'personal family EXP will be cleared.',
  ),
  (
    title: 'Family Weekly Rewards',
    body: 'Send gifts and win rewards! Every week (Monday 00:00 to Sunday '
        '23:59, UTC+3) the family\'s gift total unlocks tier rewards.\n'
        '• Tier 1 (148,500,000 weekly gifts): Leader 6,750,000 coins + '
        'Super Leader medal + Bronze Family frame + Tag-Bronze Family (7 days)\n'
        '• Tier 2 (315,000,000): Leader 15,150,000 coins + the same items\n'
        '• Tier 3 (765,000,000): Leader 37,875,000 coins + the same items\n'
        '• All members get the Bronze Family frame + Tag-Bronze Family (7 days) when a tier is reached.\n'
        '• Weekly top 1-15 (each member\'s weekly gifts must be over '
        '7,200,000): Top1 2,400,000 coins, Top2 1,800,000, Top3 1,065,000, '
        'Top4-15 390,000 down to 135,000 — plus the Super Sponsor medal '
        'and Blue star vehicle (7 days).',
  ),
  (
    title: 'Family rules',
    body: '• Family names can only be changed once a month, please '
        'consider carefully.\n'
        '• Family tags can only be revised once a month, please consider '
        'carefully.\n'
        '• After creating a family, if you do not log in for 15 days, the '
        'position of family leader will automatically transfer.',
  ),
];
