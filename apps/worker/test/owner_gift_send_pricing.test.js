import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');

test('Owner Panel gift overrides are present in the catalog used by gift sending', () => {
  const catalogStart = source.indexOf('async function effectiveGiftCatalog(db)');
  const catalogEnd = source.indexOf('// Resolve the visual bundle', catalogStart);
  assert.ok(catalogStart >= 0 && catalogEnd > catalogStart);
  const catalog = source.slice(catalogStart, catalogEnd);

  assert.match(catalog, /ownerStoreOverrides\(db\)/);
  assert.match(catalog, /String\(row\.kind\) !== "gift"/);
  assert.match(catalog, /coin_cost: Number\(row\.price_coins \?\? previous\.coin_cost \?\? 0\)/);

  const sendStart = source.indexOf('if (url.pathname === "/api/gifts/send"');
  const sendEnd = source.indexOf(
    'if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo"',
    sendStart,
  );
  assert.ok(sendStart >= 0 && sendEnd > sendStart);
  const endpoint = source.slice(sendStart, sendEnd);
  assert.match(endpoint, /effectiveGiftCatalog\(db\)\)\.find\(\(item\) => item\.id === giftId\)/);
});

test('gift sending charges the same minimum one-coin price displayed in the catalog', () => {
  const catalogStart = source.indexOf('if (url.pathname === "/api/gifts/catalog"');
  const catalogEnd = source.indexOf('if (url.pathname === "/api/gifts/send"', catalogStart);
  const catalogEndpoint = source.slice(catalogStart, catalogEnd);
  assert.match(catalogEndpoint, /Math\.max\(1,Number\(pricing\.price_coins \?\? gift\.coin_cost \?\? 0\)\)/);

  const sendStart = source.indexOf('if (url.pathname === "/api/gifts/send"');
  const sendEnd = source.indexOf(
    'if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo"',
    sendStart,
  );
  const sendEndpoint = source.slice(sendStart, sendEnd);
  assert.match(sendEndpoint, /Math\.max\(1, Number\(pricing\.price_coins \?\? gift\.coin_cost \?\? 0\)\)/);
  assert.match(sendEndpoint, /if \(!Number\.isSafeInteger\(cost\) \|\| cost <= 0\)/);
});
