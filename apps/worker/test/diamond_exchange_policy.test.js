import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
const start = source.indexOf('if (url.pathname === "/api/wallet/diamonds/convert"');
const end = source.indexOf('if (url.pathname === "/api/wallet/role-detail"', start);
const endpoint = source.slice(start, end);

test('diamond exchange is fixed at 60 percent and keeps coin values whole', () => {
  assert.ok(start >= 0 && end > start, 'diamond exchange endpoint must exist');
  assert.match(endpoint, /const rate\s*=\s*0\.6/);
  assert.match(endpoint, /const coins\s*=\s*\(diamonds\/5\)\*3/);
  assert.match(endpoint, /diamonds % 5 !== 0/);
  assert.match(endpoint, /diamonds_must_be_multiple_of_5/);
});

test('diamond exchange only updates a wallet with enough diamonds in a guarded batch', () => {
  assert.match(endpoint, /await db\.batch\(\[/);
  assert.match(endpoint, /INSERT INTO diamond_conversions[\s\S]*?WHERE EXISTS\(SELECT 1 FROM users WHERE id=\? AND diamonds>=\?\)/);
  assert.match(endpoint, /UPDATE users[\s\S]*?SET diamonds=diamonds-\?,coins=coins\+\?/);
  assert.match(endpoint, /EXISTS\(SELECT 1 FROM diamond_conversions WHERE id=\? AND user_id=\?\)/);
  assert.match(endpoint, /current_diamonds:Number\(current\?\.diamonds/);
});
