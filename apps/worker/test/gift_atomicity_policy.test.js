import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');

test('gift debit, sender ledger, receipt and receiver diamonds are committed together', () => {
  const start = source.indexOf('if (url.pathname === "/api/gifts/send"');
  const end = source.indexOf(
    'if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo"',
    start,
  );
  assert.ok(start >= 0 && end > start, 'gift endpoint must be present');
  const endpoint = source.slice(start, end);
  const batchStart = endpoint.indexOf('await db.batch([');
  const batchEnd = endpoint.indexOf(']);', batchStart);
  assert.ok(batchStart >= 0 && batchEnd > batchStart, 'gift ledger batch must be present');
  const batch = endpoint.slice(batchStart, batchEnd);

  assert.match(batch, /UPDATE users SET coins=coins-\?,updated_at=\? WHERE id=\? AND coins>=\?/);
  assert.match(batch, /INSERT INTO wallet_ledger/);
  assert.match(batch, /changes\(\)=1/);
  assert.match(batch, /INSERT INTO gift_events/);
  assert.match(batch, /UPDATE users SET diamonds = diamonds \+ \?/);
  assert.match(batch, /SELECT 1 FROM gift_events WHERE id=\?/);
});

test('failed secondary gift progression does not report the committed gift as failed', () => {
  const start = source.indexOf('if (url.pathname === "/api/gifts/send"');
  const end = source.indexOf(
    'if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo"',
    start,
  );
  const endpoint = source.slice(start, end);
  assert.match(endpoint, /if \(!committedGift\)[\s\S]*?status: 409/);
  assert.match(endpoint, /catch \(error\)[\s\S]*?progressPending = true/);
  assert.match(endpoint, /progress_pending: progressPending/);
});
