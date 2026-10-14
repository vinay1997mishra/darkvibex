import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');

test('gift endpoint permits sender and receiver to be the same user', () => {
  const start = source.indexOf('if (url.pathname === "/api/gifts/send"');
  const end = source.indexOf('if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo"', start);
  assert.ok(start >= 0 && end > start, 'gift endpoint must be present');
  const giftEndpoint = source.slice(start, end);

  assert.match(giftEndpoint, /await ensureUser\(db, sender\)/);
  assert.match(giftEndpoint, /await ensureUser\(db, receiver\)/);
  assert.match(giftEndpoint, /UPDATE users SET diamonds = diamonds \+ \?/);
  assert.doesNotMatch(giftEndpoint, /sender\s*===\s*receiver/);
  assert.doesNotMatch(giftEndpoint, /sender\s*!==\s*receiver/);
});
