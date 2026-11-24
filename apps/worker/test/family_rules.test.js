// Family Rules (Mr. Wrong, 2026-11-24): every number is the other app's
// x1.5 (6M there = 9M here). The two observed EXP points are exact after
// the scale (Lv.4 = 3,240,000,000; Lv.17 = 157,125,000,000); member and
// deputy limits come straight from the Family Rules video tables.
import test from "node:test";
import assert from "node:assert/strict";
import {
  FAMILY_LUCKY_WHEEL_SEGMENTS,
  FAMILY_MAX_LEVEL,
  FAMILY_LEVEL_EXP,
  FAMILY_TASK_REWARDS,
  familyDeputyLimit,
  familyGameExp,
  familyGiftExp,
  familyLevelForExp,
  familyLuckyWheelDrawsForRank,
  familyLuckyWheelRoll,
  familyLuckyWheelTopPrize,
  familyMemberLimit,
  familyMonthlyVaultReward,
  familyRankForMonthlyExp,
  familyUpgradeVaultReward,
} from "../src/family_rules.js";

test("family EXP ladder: observed points are exact after x1.5", () => {
  assert.equal(FAMILY_MAX_LEVEL, 50);
  assert.equal(FAMILY_LEVEL_EXP.length, 50);
  // Lv.1 = 0, Lv.4 = 2,160,000,000 x1.5, Lv.17 = 104,750,000,000 x1.5.
  assert.equal(FAMILY_LEVEL_EXP[0], 0);
  assert.equal(FAMILY_LEVEL_EXP[3], 3240000000);
  assert.equal(FAMILY_LEVEL_EXP[16], 157125000000);
  // Strictly increasing.
  for (let i = 1; i < FAMILY_LEVEL_EXP.length; i += 1) {
    assert.ok(FAMILY_LEVEL_EXP[i] > FAMILY_LEVEL_EXP[i - 1], `level ${i + 1}`);
  }
  assert.equal(familyLevelForExp(0).level, 1);
  assert.equal(familyLevelForExp(3239999999).level, 3);
  assert.equal(familyLevelForExp(3240000000).level, 4);
  assert.equal(familyLevelForExp(157124999999).level, 16);
  assert.equal(familyLevelForExp(157125000000).level, 17);
  assert.equal(familyLevelForExp(3240000000).next_exp, 4367000000);
  assert.equal(familyLevelForExp(2987656185000000).level, 50);
  assert.equal(familyLevelForExp(2987656185000000).next_exp, null);
});

test("member limits: other app x1.5 (Lv.1 60 ... Lv.50 495)", () => {
  assert.equal(familyMemberLimit(1), 60);
  assert.equal(familyMemberLimit(2), 68);
  assert.equal(familyMemberLimit(5), 90);
  assert.equal(familyMemberLimit(10), 128);
  assert.equal(familyMemberLimit(41), 360);
  assert.equal(familyMemberLimit(42), 375);
  assert.equal(familyMemberLimit(50), 495);
});

test("deputy limits: other app x1.5 (Lv.1-5: 3 ... Lv.30+: 18)", () => {
  assert.equal(familyDeputyLimit(1), 3);
  assert.equal(familyDeputyLimit(5), 3);
  assert.equal(familyDeputyLimit(6), 5);
  assert.equal(familyDeputyLimit(9), 6);
  assert.equal(familyDeputyLimit(12), 8);
  assert.equal(familyDeputyLimit(18), 11);
  assert.equal(familyDeputyLimit(21), 12);
  assert.equal(familyDeputyLimit(24), 14);
  assert.equal(familyDeputyLimit(26), 15);
  assert.equal(familyDeputyLimit(28), 17);
  assert.equal(familyDeputyLimit(30), 18);
  assert.equal(familyDeputyLimit(50), 18);
});

test("vault rewards: monthly top-10 and level-up, other app x1.5", () => {
  assert.equal(familyMonthlyVaultReward(1), 40500000);
  assert.equal(familyMonthlyVaultReward(2), 24300000);
  assert.equal(familyMonthlyVaultReward(3), 16200000);
  assert.equal(familyMonthlyVaultReward(4), 8100000);
  assert.equal(familyMonthlyVaultReward(6), 8100000);
  assert.equal(familyMonthlyVaultReward(7), 4050000);
  assert.equal(familyMonthlyVaultReward(10), 4050000);
  assert.equal(familyMonthlyVaultReward(11), 0);
  assert.equal(familyUpgradeVaultReward(1), 0);
  assert.equal(familyUpgradeVaultReward(2), 6075000);
  assert.equal(familyUpgradeVaultReward(5), 12150000);
  assert.equal(familyUpgradeVaultReward(10), 13500000);
  assert.equal(familyUpgradeVaultReward(15), 16875000);
  assert.equal(familyUpgradeVaultReward(25), 28350000);
  assert.equal(familyUpgradeVaultReward(50), 121500000);
});

test("daily task rewards: other app x1.5", () => {
  assert.deepEqual(FAMILY_TASK_REWARDS.signIn, { exp: 405000, coins: 8100 });
  assert.deepEqual(FAMILY_TASK_REWARDS.stay20, { exp: 1215000, coins: 8100 });
  assert.deepEqual(FAMILY_TASK_REWARDS.mic10, { exp: 2025000, coins: 8100 });
});

test("gift EXP: 1 coin = 1 EXP, x2 same family, 10% Lucky", () => {
  assert.equal(familyGiftExp(1000000, false, "normal"), 1000000);
  assert.equal(familyGiftExp(1000000, true, "normal"), 2000000);
  assert.equal(familyGiftExp(1000000, false, "lucky"), 100000);
  assert.equal(familyGiftExp(1000000, true, "lucky"), 200000);
  assert.equal(familyGiftExp(1000000, true, "cp"), 2000000);
  assert.equal(familyGiftExp(0, true, "normal"), 0);
});

test("game EXP: 100 coins bet = 1 EXP", () => {
  assert.equal(familyGameExp(100), 1);
  assert.equal(familyGameExp(5000), 50);
  assert.equal(familyGameExp(99), 0);
  assert.equal(familyGameExp(20000000), 200000);
});

test("family rank: Silver III band width is the observed 7.38B x1.5", () => {
  // ASTROPHILE Lv.16 shows "1,921,483,000/7,380,000,000" in Silver III.
  const silver = familyRankForMonthlyExp(7200000000 + 1921483000);
  assert.equal(silver.rank, "Silver III");
  assert.equal(silver.progress, 1921483000);
  assert.equal(silver.need, 11070000000);
  assert.equal(silver.next_rank, "Silver II");
  assert.equal(familyRankForMonthlyExp(0).rank, "Iron III");
  assert.equal(familyRankForMonthlyExp(18270000000).rank, "Silver II");
});

test("lucky wheel: 8 segments, video values x1.5, every spin wins", () => {
  // Reference video segments: 23,220 / 29,025 / 38,700 / 48,375 /
  // 58,050 / 72,563 / 96,750 / 145,125 -> x1.5.
  assert.equal(FAMILY_LUCKY_WHEEL_SEGMENTS.length, 8);
  assert.deepEqual(
    FAMILY_LUCKY_WHEEL_SEGMENTS.map((s) => s.coins),
    [34830, 43538, 58050, 72563, 87075, 108845, 145125, 217688],
  );
  assert.equal(familyLuckyWheelTopPrize(), 217688);
  // Weights sum to 100; every segment is a prize (no zero).
  assert.equal(
    FAMILY_LUCKY_WHEEL_SEGMENTS.reduce((sum, s) => sum + s.weight, 0),
    100,
  );
  assert.ok(FAMILY_LUCKY_WHEEL_SEGMENTS.every((s) => s.coins > 0));
  // Seeded rolls: 0.0 -> smallest, 0.6 -> third segment, 0.999 -> top.
  assert.equal(familyLuckyWheelRoll(() => 0).coins, 34830);
  assert.equal(familyLuckyWheelRoll(() => 0.6).coins, 58050);
  assert.equal(familyLuckyWheelRoll(() => 0.999).coins, 217688);
});

test("lucky wheel: daily draws grow with rank (Iron III 5, Diamond I 22)", () => {
  assert.equal(familyLuckyWheelDrawsForRank("Iron III"), 5);
  assert.equal(familyLuckyWheelDrawsForRank("Iron II"), 6);
  assert.equal(familyLuckyWheelDrawsForRank("Silver III"), 11);
  assert.equal(familyLuckyWheelDrawsForRank("Gold I"), 16);
  assert.equal(familyLuckyWheelDrawsForRank("Diamond I"), 22);
  assert.equal(familyLuckyWheelDrawsForRank("No Such Rank"), 5);
});
