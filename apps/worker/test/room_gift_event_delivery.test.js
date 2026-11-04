import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');

test('room gift event feed requires an authenticated room member', () => {
  const start = source.indexOf('parts[3] === "gift-events"');
  const end = source.indexOf('parts[3] === "messages"', start);
  assert.ok(start >= 0 && end > start, 'gift event endpoint must exist before room messages');
  const endpoint = source.slice(start, end);
  assert.match(endpoint, /requireSession\(request, env\)/);
  assert.match(endpoint, /room_members WHERE room_id=\? AND user_id=\?/);
  assert.match(endpoint, /room_membership_required/);
});

test('room gift event feed uses stable incremental ordering and includes playback metadata', () => {
  const start = source.indexOf('parts[3] === "gift-events"');
  const end = source.indexOf('parts[3] === "messages"', start);
  const endpoint = source.slice(start, end);
  assert.match(endpoint, /g\.created_at>\? OR \(g\.created_at=\? AND g\.id>\?\)/);
  assert.match(endpoint, /ORDER BY g\.created_at ASC,g\.id ASC LIMIT 20/);
  assert.match(endpoint, /video_key:String\(gift\.video_key/);
  assert.match(endpoint, /glb_key:String\(gift\.glb_key/);
  assert.match(endpoint, /receiver_user_id:String\(row\.receiver_user_id\)/);
});
