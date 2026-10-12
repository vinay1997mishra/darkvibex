import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateIdLevel, idLevelExpToNext } from '../src/id_level_policy.js';

test('ID level starts with the requested EXP requirements', () => {
  assert.deepEqual([0, 1, 2, 3, 4].map(idLevelExpToNext), [10000, 13000, 18000, 25000, 36000]);
});

test('ID level awards carry EXP across level ups', () => {
  assert.deepEqual(calculateIdLevel(10000), { level: 1, exp: 0, exp_to_next: 13000 });
  assert.deepEqual(calculateIdLevel(23000), { level: 2, exp: 0, exp_to_next: 18000 });
  assert.deepEqual(calculateIdLevel(23001), { level: 2, exp: 1, exp_to_next: 18000 });
});

test('higher ID level requirements keep increasing', () => {
  const next = [5, 6, 7, 8].map(idLevelExpToNext);
  assert.deepEqual(next, [50000, 70000, 98000, 137000]);
});
