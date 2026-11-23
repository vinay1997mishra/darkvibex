import test from 'node:test';
import assert from 'node:assert/strict';
import { applyIdLevelExp, idLevelExpToNext, idLevelRewards, ID_LEVEL_MAX } from '../src/id_level_policy.js';

test('ID level starts with the requested EXP requirements', () => {
  assert.deepEqual([0, 1, 2, 3, 4].map(idLevelExpToNext), [10000, 13000, 18000, 25000, 36000]);
});

test('each level begins at zero and overflow from the level-up award is discarded', () => {
  assert.deepEqual(applyIdLevelExp(0, 9990, 20), { level: 1, exp: 0, exp_to_next: 13000 });
  assert.deepEqual(applyIdLevelExp(1, 0, 2), { level: 1, exp: 2, exp_to_next: 13000 });
  assert.deepEqual(applyIdLevelExp(1, 12990, 20), { level: 2, exp: 0, exp_to_next: 18000 });
});

test('higher ID level requirements keep increasing', () => {
  const next = [5, 6, 7, 8].map(idLevelExpToNext);
  assert.deepEqual(next, [50000, 70000, 98000, 137000]);
});

test('ID level rewards run to 200 (Vinay, 2026-11-23)', () => {
  assert.equal(ID_LEVEL_MAX, 200);
  const rewards = idLevelRewards(0);
  assert.equal(rewards.length, 200);
  assert.equal(rewards[0].level, 1);
  assert.equal(rewards[199].level, 200);
  // Milestones continue the same pattern past 100: medal + frame at
  // every 10th level (and Lv.5), vehicle at every 10th level from 40.
  const kinds = (level) => rewards[level - 1].items.map((item) => item.kind);
  assert.deepEqual(kinds(200), ['gift', 'medal', 'frame', 'vehicle']);
  assert.deepEqual(kinds(150), ['gift', 'medal', 'frame', 'vehicle']);
  assert.deepEqual(kinds(199), ['gift']);
  assert.deepEqual(kinds(5), ['gift', 'medal', 'frame']);
});

test('the EXP curve still increases at the top of the 200 levels', () => {
  // The x1.4 curve grows past Number.MAX_SAFE_INTEGER long before 200
  // (L30 already needs 225,473,000 EXP), so the top requirements are
  // finite doubles, not safe integers — the property that must hold is
  // that each level still costs strictly more than the last.
  const next199 = idLevelExpToNext(199);
  const next198 = idLevelExpToNext(198);
  assert.ok(Number.isFinite(next199) && next199 > next198);
  assert.ok(next199 > 0);
});
