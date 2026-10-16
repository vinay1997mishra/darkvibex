import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const worker = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");

test("intimacy cards expose 20 slots with 3 unlocked and a one-at-a-time unlock cost", () => {
  assert.match(worker, /const INTIMACY_CARD_UNLOCK_COST = 100000/);
  assert.match(worker, /const INTIMACY_CARD_TOTAL_SLOTS = 20/);
  assert.match(worker, /const INTIMACY_CARD_INITIAL_UNLOCKED = 3/);
  assert.match(worker, /unlocked_count: unlockedCount/);
  assert.match(worker, /unlocked_count=unlocked_count\+1/);
  assert.match(worker, /all_intimacy_cards_unlocked/);
  assert.match(worker, /intimacy_card_locked/);
});

test("first card is always Brother/Sister and relation type is selected when binding", () => {
  assert.match(worker, /const relationType = slotIndex === 1\s*\? "brother_sister"\s*:\s*normalizeIntimacyCardRelation\(relationRaw\)/);
  assert.match(worker, /async function bindIntimacyCard\(db, userId, slotIndexRaw, targetUserIdRaw, relationRaw\)/);
  assert.match(worker, /UNIQUE\(owner_user_id, target_user_id\)/);
  assert.match(worker, /mutual_friend_required/);
});

test("unlock spending is recorded in wallet ledger and unbind checks account eligibility", () => {
  assert.match(worker, /"intimacy_card_unlock"/);
  assert.match(worker, /async function unbindIntimacyCard\(db, userId, slotIndexRaw\)\s*\{\s*await ensureUser\(db, userId\);\s*await ensureUserAllowed\(db, userId\)/);
});
