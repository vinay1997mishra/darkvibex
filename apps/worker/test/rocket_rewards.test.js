import test from "node:test";
import assert from "node:assert/strict";
import {
  ROCKET_FRAME_REWARDS,
  ROCKET_MILESTONE_TARGETS,
  ROCKET_REWARD_TIERS,
  assignRocketReward,
  rocketFrameRewardForGroup,
  rocketRewardConfigForLevel,
  rocketTargetForLevel,
} from "../src/rocket_rewards.js";

test("rocket reward tiers match the configured winner and coin ranges", () => {
  assert.equal(rocketRewardConfigForLevel(1).group, "1-3");
  assert.equal(rocketRewardConfigForLevel(2).group, "1-3");
  assert.equal(rocketRewardConfigForLevel(3).group, "1-3");
  assert.equal(rocketRewardConfigForLevel(4).group, "4-6");
  assert.equal(rocketRewardConfigForLevel(6).group, "4-6");
  assert.equal(rocketRewardConfigForLevel(7).group, "7-9");
  assert.equal(rocketRewardConfigForLevel(9).group, "7-9");
  assert.equal(rocketRewardConfigForLevel(10).group, "10-12");
  assert.equal(rocketRewardConfigForLevel(12).group, "10-12");
  assert.deepEqual(
    ROCKET_REWARD_TIERS.map((tier) => [
      tier.minLevel, tier.maxLevel, tier.maxWinners, tier.frameWinners,
      tier.coinMin, tier.coinMax, tier.frameDays,
    ]),
    [
      [1, 3, 50, 25, 10_000, 20_000, 1],
      [4, 6, 70, 25, 30_000, 60_000, 5],
      [7, 9, 80, 25, 30_000, 200_000, 7],
      [10, 12, 100, 25, 50_000, 300_000, 10],
    ],
  );
});

test("only the first 25 successful claims in a level pool are frame slots", () => {
  const tier = rocketRewardConfigForLevel(1);
  assert.deepEqual(assignRocketReward(tier, 0, 0.5), {
    reward_type: "frame",
    coin_amount: 0,
    frame_days: 1,
    frame_delivery_status: "pending_assets",
  });
  assert.deepEqual(assignRocketReward(tier, 24, 0.5), {
    reward_type: "frame",
    coin_amount: 0,
    frame_days: 1,
    frame_delivery_status: "pending_assets",
  });
  assert.deepEqual(assignRocketReward(tier, 25, 0), {
    reward_type: "coins",
    coin_amount: 10_000,
    frame_days: 0,
    frame_delivery_status: "not_applicable",
  });
  assert.deepEqual(assignRocketReward(tier, 49, 1), {
    reward_type: "coins",
    coin_amount: 20_000,
    frame_days: 0,
    frame_delivery_status: "not_applicable",
  });
  assert.equal(assignRocketReward(tier, 50, 0.5), null);
});

test("coin range and frame duration follow the level group", () => {
  const level4 = rocketRewardConfigForLevel(4);
  const level7 = rocketRewardConfigForLevel(7);
  const level10 = rocketRewardConfigForLevel(10);
  assert.equal(assignRocketReward(level4, 25, 0).coin_amount, 30_000);
  assert.equal(assignRocketReward(level4, 25, 1).coin_amount, 60_000);
  assert.equal(assignRocketReward(level7, 25, 1).coin_amount, 200_000);
  assert.equal(assignRocketReward(level10, 25, 1).coin_amount, 300_000);
  assert.equal(assignRocketReward(level4, 0).frame_days, 5);
  assert.equal(assignRocketReward(level7, 0).frame_days, 7);
  assert.equal(assignRocketReward(level10, 0).frame_days, 10);
});

test("all 12 Rocket milestone thresholds are configured", () => {
  assert.equal(rocketRewardConfigForLevel(0), null);
  assert.equal(rocketRewardConfigForLevel(13), null);
  assert.equal(ROCKET_MILESTONE_TARGETS.length, 12);
  assert.equal(rocketTargetForLevel(1), 8_000_000);
  assert.equal(rocketTargetForLevel(10), 500_000_000);
  assert.equal(rocketTargetForLevel(11), 650_000_000);
  assert.equal(rocketTargetForLevel(12), 800_000_000);
});

test("each Rocket reward group maps to a matching circular frame asset", () => {
  assert.deepEqual(ROCKET_FRAME_REWARDS, {
    "1-3": { id: "rocket_frame_aurora", name: "Rocket Aurora" },
    "4-6": { id: "rocket_frame_neon_wings", name: "Rocket Neon Wings" },
    "7-9": { id: "rocket_frame_golden_comet", name: "Rocket Golden Comet" },
    "10-12": { id: "rocket_frame_purple_nova", name: "Rocket Purple Nova" },
  });
  assert.equal(rocketFrameRewardForGroup("1-3").id, "rocket_frame_aurora");
  assert.equal(rocketFrameRewardForGroup("10-12").id, "rocket_frame_purple_nova");
  assert.equal(rocketFrameRewardForGroup("unknown"), null);
});
