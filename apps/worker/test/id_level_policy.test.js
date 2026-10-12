import test from 'node:test';
import assert from 'node:assert/strict';
import { applyIdLevelExp, idLevelExpToNext } from '../src/id_level_policy.js';

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
