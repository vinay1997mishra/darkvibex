/// Top 1/2/3 rewards for a Rocket launch (direct VIP + launch coins).
///
/// This is the ONLY place that knows the Top 1/2/3 VIP and coin numbers for
/// the Rocket Room Page. The confirmed rules (Vinay, 2026-11-19) are:
/// - NO frames for anyone — every winner gets random coins only, and
///   Top 1/2/3 ALSO get DIRECT VIP + launch coins.
/// - Rocket Lv.6 = VIP 4 (Top 1 for 10 days, Top 2 for 7 days,
///   Top 3 for 5 days). VIP rises with Rocket level and caps at VIP 8,
///   never more. At Lv.18, VIP 8 is for 1 MONTH (30 days).
/// - Launch coins: Lv.1 Top 1 = 5L, Top 2 = 3L, Top 3 = 2L.
///   Lv.10 Top 1 = 14L, Top 2 = 10L, Top 3 = 8L. Top 2 caps at 10L,
///   Top 3 caps at 8L.
///
/// UNCONFIRMED — Vinay has NOT confirmed these steps, so they are guesses
/// that must be changeable in this one file:
/// - VIP level = Rocket level - 2, floored at VIP 1, capped at VIP 8.
/// - Launch coins = base + 1L per level above Lv.1 for all three ranks
///   (so Top 1 reaches 22L at Lv.18).
/// - VIP days = base + 2 days per level above Lv.6, capped at
///   Top 1 = 30, Top 2 = 21, Top 3 = 15 days; below Lv.6 the days step
///   down 2 per level, floored at 1 day.
///
/// The launch targets (Lv.1 12M ... Lv.18 250M) and the random-coin pool
/// (pool sizes + coin ranges + entry order) are NOT duplicated here — they
/// live in apps/worker/src/rocket_rewards.js and
/// apps/mobile/lib/utils/rocket_progress.dart, and the pool numbers reach
/// the page through the live rocket-reward status endpoint.

/// One rank's launch reward: direct VIP for [vipDays] days plus
/// [launchCoins] coins (in coins, e.g. 500000 = 5L).
class RocketTopReward {
  const RocketTopReward({
    required this.rank,
    required this.vipLevel,
    required this.vipDays,
    required this.launchCoins,
  });

  /// 1, 2 or 3.
  final int rank;

  /// Direct VIP level granted on launch.
  final int vipLevel;

  /// VIP validity in days.
  final int vipDays;

  /// Coins granted on launch (not the random pool).
  final int launchCoins;
}

const List<int> _baseVipDays = <int>[10, 7, 5];
const List<int> _maxVipDays = <int>[30, 21, 15];
const List<int> _baseLaunchCoinsLakh = <int>[5, 3, 2];
const List<int> _maxLaunchCoinsLakh = <int>[22, 10, 8];

RocketTopReward? _rewardForRank(int level, int rank) {
  final index = rank - 1;
  // UNCONFIRMED: VIP = Rocket level - 2, floor VIP 1, cap VIP 8.
  final vipLevel = (level - 2).clamp(1, 8);
  // UNCONFIRMED: days = base + 2 per level above Lv.6 (capped), or
  // base - 2 per level below Lv.6 (floored at 1 day).
  final int vipDays;
  if (level >= 6) {
    vipDays = (_baseVipDays[index] + 2 * (level - 6))
        .clamp(1, _maxVipDays[index]);
  } else {
    vipDays = (_baseVipDays[index] - 2 * (6 - level)).clamp(1, 30);
  }
  // UNCONFIRMED: coins = base + 1L per level above Lv.1 (capped).
  final launchCoinsLakh =
      (_baseLaunchCoinsLakh[index] + (level - 1)).clamp(0, _maxLaunchCoinsLakh[index]);
  return RocketTopReward(
    rank: rank,
    vipLevel: vipLevel,
    vipDays: vipDays,
    launchCoins: launchCoinsLakh * 100000,
  );
}

/// Top 1/2/3 launch rewards for [level] (1-18), in rank order.
/// Returns null when [level] is outside 1-18.
List<RocketTopReward>? rocketTopRewardsForLevel(int level) {
  if (level < 1 || level > 18) return null;
  return <RocketTopReward>[
    _rewardForRank(level, 1)!,
    _rewardForRank(level, 2)!,
    _rewardForRank(level, 3)!,
  ];
}

/// Launch reward for one rank (1-3) at [level] (1-18), or null when
/// either is out of range.
RocketTopReward? rocketTopRewardForRank(int level, int rank) {
  if (level < 1 || level > 18 || rank < 1 || rank > 3) return null;
  return _rewardForRank(level, rank);
}
