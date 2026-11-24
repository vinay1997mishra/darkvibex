// Family rules (Mr. Wrong, 2026-11-24): the full Family Rules from the
// other app, with every number scaled x1.5 for DarkVibeX — the other app
// gives 6M coins where ours gives 9M (ratio 6:9 = 1.5x). The create cost
// 90,000,000 is already final and is NOT scaled again here.
//
// Sources (read from the reference videos, frame by frame):
// - Levels Lv.1-Lv.50, member limits + deputy counts: Family Rules video
//   (video/9a/9afc1fb4...), "How many levels are there in the family?"
//   Member limit (other app): Lv.1 40, +5/level to Lv.41 (240), then
//   +10/level to Lv.50 (330). Deputies (other app): Lv.1-5: 2, then +1 at
//   levels 6, 9, 12, 15, 18, 21, 24, 26, 28, 30, capped at 12.
// - Family EXP thresholds: only TWO points are visible in the videos —
//   POWER OF FRIENDS Lv.3: 1,770,101,722/2,160,000,000 (so Lv.4 needs
//   2,160,000,000) and ASTROPHILE Lv.16: 98,331,042,566/104,750,000,000
//   (so Lv.17 needs 104,750,000,000). The ladder between/around them is a
//   geometric fit through those two points (x1.3479 per level); the two
//   observed points are exact after the x1.5 scale, the rest are fitted.
// - Monthly vault rewards (other app): No.1 27,000,000, No.2 16,200,000,
//   No.3 10,800,000, No.4-6 5,400,000, No.7-10 2,700,000.
// - Level-up vault rewards (other app): Lv.2 4,050,000, Lv.3 5,400,000,
//   Lv.4 6,750,000, Lv.5 8,100,000, Lv.6-10 9,000,000, Lv.11-15 11,250,000,
//   Lv.16-20 13,500,000, Lv.21-25 18,900,000, Lv.26-30 27,000,000,
//   Lv.31-35 37,800,000, Lv.36-40 54,000,000, Lv.41-45 67,500,000,
//   Lv.46-50 81,000,000.
// - Daily tasks (TASK tab, POWER OF FRIENDS video): sign-in 270,000 EXP +
//   5,400 coins; stay in a family room 20 min 810,000 EXP + 5,400 coins;
//   mic on 10 min 1,350,000 EXP + 5,400 coins; send gift 1 coin = 1 EXP
//   (family gift x2), no limit; receive gift 1 coin = 1 EXP (family gift
//   x2), no limit; play games 100 coins = 1 EXP, no limit.
// - Family Rank: ASTROPHILE Lv.16 shows "Silver III, to level-up you
//   need: 1,921,483,000/7,380,000,000". The rank ladder below is OUR
//   ladder, anchored on that one observed band width (7,380,000,000
//   x1.5 = 11,070,000,000 for Silver III -> Silver II); the other bands
//   follow the same doubling shape. Rank points are the family's EXP
//   this month.

export const FAMILY_MAX_LEVEL = 50;

// Total family EXP needed to BE at each level (index = level - 1).
// Lv.1 = 0, Lv.4 = 3,240,000,000 and Lv.17 = 157,125,000,000 are the two
// observed points x1.5; the rest are the geometric fit, rounded to the
// nearest 1,000,000.
export const FAMILY_LEVEL_EXP = [
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

export function familyLevelForExp(experience) {
  const exp = Math.max(0, Math.floor(Number(experience ?? 0)));
  let level = 1;
  for (let i = 1; i < FAMILY_LEVEL_EXP.length; i += 1) {
    if (exp >= FAMILY_LEVEL_EXP[i]) level = i + 1;
    else break;
  }
  const nextExp = level < FAMILY_MAX_LEVEL ? FAMILY_LEVEL_EXP[level] : null;
  return { level, next_exp: nextExp };
}

// Member limit per level (other app x1.5, rounded half up): Lv.1 60,
// +7.5/level to Lv.41 (360), then +15/level to Lv.50 (495).
export function familyMemberLimit(level) {
  const l = Math.max(1, Math.min(FAMILY_MAX_LEVEL, Math.floor(Number(level ?? 1))));
  const base = l <= 41 ? 35 + 5 * l : 240 + 10 * (l - 41);
  return Math.floor(base * 1.5 + 0.5);
}

// Deputy (admin) limit per level (other app x1.5, rounded half up).
// Other app: 2 deputies at Lv.1-5, +1 at levels 6, 9, 12, 15, 18, 21,
// 24, 26, 28, 30, capped at 12. Ours: 3 at Lv.1-5 ... 18 at Lv.30+.
export function familyDeputyLimit(level) {
  const l = Math.max(1, Math.min(FAMILY_MAX_LEVEL, Math.floor(Number(level ?? 1))));
  const thresholds = [6, 9, 12, 15, 18, 21, 24, 26, 28, 30];
  const base = 2 + thresholds.filter((t) => t <= l).length;
  return Math.floor(Math.min(12, base) * 1.5 + 0.5);
}

// Vault coins the family vault receives when the family reaches a level
// (other app x1.5). No reward for Lv.1 (creation).
export function familyUpgradeVaultReward(level) {
  const l = Math.floor(Number(level ?? 1));
  if (l <= 1) return 0;
  if (l === 2) return 6075000;
  if (l === 3) return 8100000;
  if (l === 4) return 10125000;
  if (l === 5) return 12150000;
  if (l <= 10) return 13500000;
  if (l <= 15) return 16875000;
  if (l <= 20) return 20250000;
  if (l <= 25) return 28350000;
  if (l <= 30) return 40500000;
  if (l <= 35) return 56700000;
  if (l <= 40) return 81000000;
  if (l <= 45) return 101250000;
  return 121500000;
}

// Monthly vault coins for the top-10 families of the month (other app
// x1.5). Rank 1: 40,500,000; 2: 24,300,000; 3: 16,200,000; 4-6:
// 8,100,000; 7-10: 4,050,000.
export function familyMonthlyVaultReward(rank) {
  const r = Math.floor(Number(rank ?? 0));
  if (r === 1) return 40500000;
  if (r === 2) return 24300000;
  if (r === 3) return 16200000;
  if (r >= 4 && r <= 6) return 8100000;
  if (r >= 7 && r <= 10) return 4050000;
  return 0;
}

// Daily task rewards (other app x1.5): EXP for the family + coins for
// the user who completes the task. Gift/game tasks have no upper limit
// and no coin reward.
export const FAMILY_TASK_REWARDS = {
  signIn: { exp: 405000, coins: 8100 },
  stay20: { exp: 1215000, coins: 8100 },
  mic10: { exp: 2025000, coins: 8100 },
};

// Gift EXP: 1 coin = 1 EXP; x2 when giver and receiver are in the same
// family; only 10% counts for Lucky gifts (and rebate gifts, if the
// catalog ever gains that category — today only 'lucky' exists).
export function familyGiftExp(coins, sameFamily, giftCategory) {
  const base = Math.max(0, Math.floor(Number(coins ?? 0)));
  const factor = giftCategory === "lucky" || giftCategory === "rebate" ? 0.1 : 1;
  const multiplier = sameFamily ? 2 : 1;
  return Math.floor(base * multiplier * factor);
}

// Games: 100 coins bet = 1 EXP.
export function familyGameExp(coins) {
  return Math.floor(Math.max(0, Number(coins ?? 0)) / 100);
}

// Family Rank ladder, by the family's EXP this month (rank points).
// Cumulative monthly-EXP thresholds; the Silver III -> Silver II band
// width (11,070,000,000) is the one observed band (7,380,000,000 x1.5).
export const FAMILY_RANK_LADDER = [
  { name: "Iron III", threshold: 0 },
  { name: "Iron II", threshold: 225000000 },
  { name: "Iron I", threshold: 450000000 },
  { name: "Bronze III", threshold: 900000000 },
  { name: "Bronze II", threshold: 1800000000 },
  { name: "Bronze I", threshold: 3600000000 },
  { name: "Silver III", threshold: 7200000000 },
  { name: "Silver II", threshold: 18270000000 },
  { name: "Silver I", threshold: 29340000000 },
  { name: "Gold III", threshold: 45000000000 },
  { name: "Gold II", threshold: 67500000000 },
  { name: "Gold I", threshold: 101000000000 },
  { name: "Platinum III", threshold: 152000000000 },
  { name: "Platinum II", threshold: 228000000000 },
  { name: "Platinum I", threshold: 342000000000 },
  { name: "Diamond III", threshold: 513000000000 },
  { name: "Diamond II", threshold: 770000000000 },
  { name: "Diamond I", threshold: 1155000000000 },
];

export function familyRankForMonthlyExp(monthlyExp) {
  const exp = Math.max(0, Math.floor(Number(monthlyExp ?? 0)));
  let index = 0;
  for (let i = 1; i < FAMILY_RANK_LADDER.length; i += 1) {
    if (exp >= FAMILY_RANK_LADDER[i].threshold) index = i;
    else break;
  }
  const current = FAMILY_RANK_LADDER[index];
  const next = FAMILY_RANK_LADDER[index + 1] ?? null;
  return {
    rank: current.name,
    // Progress inside this rank, like the other app's
    // "To leve-up, you need: 1921483000/7380000000".
    progress: exp - current.threshold,
    need: next ? next.threshold - current.threshold : 0,
    next_rank: next ? next.name : null,
  };
}

// The level-band art (Rank Medal / Family tag / Profile photo frame) the
// other app shows per 5-level band. Our app reuses the same band colours
// for the family level badge.
export const FAMILY_LEVEL_BANDS = [
  { min: 1, max: 5, colour: "teal" },
  { min: 6, max: 10, colour: "blue" },
  { min: 11, max: 15, colour: "gold" },
  { min: 16, max: 20, colour: "pink" },
  { min: 21, max: 25, colour: "blue-gold" },
  { min: 26, max: 30, colour: "green" },
  { min: 31, max: 35, colour: "purple-gold" },
  { min: 36, max: 40, colour: "pink-gold" },
  { min: 41, max: 45, colour: "gold" },
  { min: 46, max: 50, colour: "red-gold" },
];

export function familyLevelBand(level) {
  const l = Math.max(1, Math.min(FAMILY_MAX_LEVEL, Math.floor(Number(level ?? 1))));
  return FAMILY_LEVEL_BANDS.find((b) => l >= b.min && l <= b.max) ?? FAMILY_LEVEL_BANDS[0];
}

// ---------------------------------------------------------------------------
// Family Weekly Rewards (Mr. Wrong, 2026-11-24): "Send gifts and win
// rewards!" — the family's gift total each week (Monday 00:00 to Sunday
// 23:59 in UTC+3) unlocks tier rewards. Every number is the other app's
// x1.5 (6M there = 9M here).
//
// Observed in the video (other app):
// - Tiers: 99,000,000 / 210,000,000 / 510,000,000 weekly gift coins.
// - Reward-Family Leader: 99M tier = 4,500,000 coins + Super Leader
//   medal + Bronze Family frame + Tag-Bronze Family (all x7d); 210M tier
//   = 10,100,000 coins + the same items. The 510M tier leader coins
//   were NOT visible — 25,250,000 is interpolated from the 99M->210M
//   slope (5,600,000 more coins per 111,000,000 more tier), NOT observed.
// - Reward-members: Bronze Family frame + Tag-Bronze Family (x7d).
// - Reward-top1: 1,600,000 coins + Super Sponsor medal + Blue star
//   vehicle (x7d); top2: 1,200,000; top3: 710,000; top4-top15:
//   260,000 down to 90,000 — only top3 (710,000), top4 (260,000) and
//   top5 (260,000) were directly visible; the top6-top15 steps are a
//   straight line from 260,000 (top4) to 90,000 (top15), NOT observed.
// - Eligibility note: "* Weekly gifts require >4800,000 to be received"
//   — a member's weekly gifts must be over 4,800,000 to receive a top
//   reward.
// - The frame / medal / tag / vehicle items are 7-day grants. Our app
//   has no family-frame/tag/vehicle grant system yet, so settlement
//   credits the COINS for real and records the items in the weekly
//   reward history as granted display items.
// ---------------------------------------------------------------------------

export const FAMILY_WEEKLY_ELIGIBILITY_COINS = 7200000;

export const FAMILY_WEEKLY_TIERS = [
  { threshold: 148500000, leader_coins: 6750000 },
  { threshold: 315000000, leader_coins: 15150000 },
  { threshold: 765000000, leader_coins: 37875000 },
];

export function familyWeeklyTierForTotal(total) {
  const value = Math.max(0, Math.floor(Number(total ?? 0)));
  let tier = -1;
  for (let i = 0; i < FAMILY_WEEKLY_TIERS.length; i += 1) {
    if (value >= FAMILY_WEEKLY_TIERS[i].threshold) tier = i;
    else break;
  }
  return tier;
}

// Top-15 weekly coins (other app x1.5). Top1 2,400,000; top2 1,800,000;
// top3 1,065,000; top4-top15 straight line 390,000 down to 135,000.
export function familyWeeklyTopCoins(rank) {
  const r = Math.floor(Number(rank ?? 0));
  if (r === 1) return 2400000;
  if (r === 2) return 1800000;
  if (r === 3) return 1065000;
  if (r >= 4 && r <= 15) return Math.round((390000 - (r - 4) * (255000 / 11)) / 1000) * 1000;
  return 0;
}

// ---------------------------------------------------------------------------
// Daily Lucky Wheel (Mr. Wrong, 2026-11-24): the EVENT hold is LIFTED —
// "sab kuch add kar de, wheel bhi". Same-to-same as the other app's wheel,
// every number x1.5 (Family 6M:9M rule).
// ---------------------------------------------------------------------------

// Wheel segments from the reference video, x1.5:
// 23,220 / 29,025 / 38,700 / 48,375 / 58,050 / 72,563 / 96,750 / 145,125
// -> 34,830 / 43,538 / 58,050 / 72,563 / 87,075 / 108,845 / 145,125 / 217,688.
// Every spin wins coins (no zero segment); smaller prizes are likelier.
export const FAMILY_LUCKY_WHEEL_SEGMENTS = [
  { coins: 34830, weight: 30 },
  { coins: 43538, weight: 25 },
  { coins: 58050, weight: 18 },
  { coins: 72563, weight: 12 },
  { coins: 87075, weight: 7 },
  { coins: 108845, weight: 4 },
  { coins: 145125, weight: 2.5 },
  { coins: 217688, weight: 1.5 },
];

export function familyLuckyWheelTopPrize() {
  return Math.max(...FAMILY_LUCKY_WHEEL_SEGMENTS.map((s) => s.coins));
}

// Weighted roll: returns one segment. `random` is injectable for tests.
export function familyLuckyWheelRoll(random = Math.random) {
  const total = FAMILY_LUCKY_WHEEL_SEGMENTS.reduce((sum, s) => sum + s.weight, 0);
  let roll = random() * total;
  for (const segment of FAMILY_LUCKY_WHEEL_SEGMENTS) {
    roll -= segment.weight;
    if (roll < 0) return segment;
  }
  return FAMILY_LUCKY_WHEEL_SEGMENTS[FAMILY_LUCKY_WHEEL_SEGMENTS.length - 1];
}

// Daily draws for the whole family, by rank (video rule: draws depend on
// rank; a rank change updates that day's total at once). Iron III gets 5
// draws a day, each higher rank one more, Diamond I gets 22.
export function familyLuckyWheelDrawsForRank(rankName) {
  const index = FAMILY_RANK_LADDER.findIndex((r) => r.name === rankName);
  if (index < 0) return 5;
  return 5 + index;
}
