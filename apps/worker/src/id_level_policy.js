export const ID_LEVEL_GIFT_COINS_PER_EXP = 400;
export const ID_LEVEL_ROOM_ENTRY_EXP_PER_DAY = 70;
export const ID_LEVEL_ROOM_SHARE_EXP_PER_DAY = 75;

const FIXED_LEVEL_EXP = [10000, 13000, 18000, 25000, 36000];

export function idLevelExpToNext(currentLevel) {
  const level = Math.max(0, Math.floor(Number(currentLevel) || 0));
  if (level < FIXED_LEVEL_EXP.length) return FIXED_LEVEL_EXP[level];
  let next = FIXED_LEVEL_EXP[FIXED_LEVEL_EXP.length - 1];
  for (let reached = FIXED_LEVEL_EXP.length; reached <= level; reached += 1) {
    next = Math.max(next + 1000, Math.round((next * 1.4) / 1000) * 1000);
  }
  return next;
}

export function applyIdLevelExp(currentLevel, currentExp, awardedExp) {
  let level = Math.max(0, Math.floor(Number(currentLevel) || 0));
  const exp = Math.max(0, Math.floor(Number(currentExp) || 0));
  const award = Math.max(0, Math.floor(Number(awardedExp) || 0));
  const required = idLevelExpToNext(level);
  if (exp + award >= required) {
    level += 1;
    return { level, exp: 0, exp_to_next: idLevelExpToNext(level) };
  }
  return { level, exp: exp + award, exp_to_next: required };
}

export function idLevelRewards(level) {
  const unlocked = Math.max(0, Math.floor(Number(level) || 0));
  const rewards = [];
  for (let rewardLevel = 1; rewardLevel <= 100; rewardLevel += 1) {
    const items = [{ id: `gift-${rewardLevel}`, label: `Level ${rewardLevel} gift`, kind: 'gift' }];
    if (rewardLevel === 5 || (rewardLevel >= 10 && rewardLevel % 10 === 0)) {
      items.push({ id: `medal-${rewardLevel}`, label: `Lv.${rewardLevel} medal`, kind: 'medal' });
      items.push({ id: `frame-${rewardLevel}`, label: `Lv.${rewardLevel} profile frame`, kind: 'frame' });
    }
    if (rewardLevel >= 40 && rewardLevel % 10 === 0) {
      items.push({ id: `vehicle-${rewardLevel}`, label: `Lv.${rewardLevel} entrance vehicle`, kind: 'vehicle' });
    }
    rewards.push({ level: rewardLevel, unlocked: rewardLevel <= unlocked, items });
  }
  return rewards;
}
