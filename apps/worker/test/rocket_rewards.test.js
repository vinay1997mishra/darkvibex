import test from "node:test";
import assert from "node:assert/strict";
import {
  ROCKET_MILESTONE_TARGETS,
  ROCKET_REWARD_TIERS,
  assignRocketReward,
  rocketFrameIdForGroup,
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
    frame_id: "rocket_frame_g1_01",
    frame_delivery_status: "delivered",
  });
  assert.deepEqual(assignRocketReward(tier, 24, 0.5), {
    reward_type: "frame",
    coin_amount: 0,
    frame_days: 1,
    frame_id: "rocket_frame_g1_25",
    frame_delivery_status: "delivered",
  });
  assert.deepEqual(assignRocketReward(tier, 25, 0), {
    reward_type: "coins",
    coin_amount: 10_000,
    frame_days: 0,
    frame_id: null,
    frame_delivery_status: "not_applicable",
  });
  assert.deepEqual(assignRocketReward(tier, 49, 1), {
    reward_type: "coins",
    coin_amount: 20_000,
    frame_days: 0,
    frame_id: null,
    frame_delivery_status: "not_applicable",
  });
  assert.equal(assignRocketReward(tier, 50, 0.5), null);
});

test("Rocket frame IDs are unique across the 100 catalog slots", () => {
  const ids = new Set();
  for (const tier of ROCKET_REWARD_TIERS) {
    for (let slot = 1; slot <= 25; slot++) {
      const id = rocketFrameIdForGroup(tier.group, slot);
      assert.match(id, /^rocket_frame_g[1-4]_(?:0[1-9]|1[0-9]|2[0-5])$/);
      ids.add(id);
    }
  }
  assert.equal(ids.size, 100);
  assert.equal(rocketFrameIdForGroup("10-12", 25), "rocket_frame_g4_25");
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

test("unknown levels and unconfigured 11–12 thresholds stay explicit", () => {
  assert.equal(rocketRewardConfigForLevel(0), null);
  assert.equal(rocketRewardConfigForLevel(13), null);
  assert.equal(ROCKET_MILESTONE_TARGETS.length, 10);
  assert.equal(rocketTargetForLevel(1), 8_000_000);
  assert.equal(rocketTargetForLevel(10), 500_000_000);
  assert.equal(rocketTargetForLevel(11), null);
  assert.equal(rocketTargetForLevel(12), null);
});
