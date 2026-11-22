// DarkVibeX — idempotent money transfers + wallet PIN throttling.
//
// Wallet audit 2026-11-22 (H1, M6): a client retry / double-tap /
// replay of a Coin Seller transfer used to double-debit, double-credit
// and re-award EXP + invite commission, because transferRoleCoins
// minted a fresh UUID per call and neither transfer route accepted an
// idempotency key. Every money-moving call now carries a
// client-supplied idempotency key; the key is claimed atomically
// (plain INSERT, UNIQUE on the key) BEFORE the money moves, so a
// concurrent duplicate loses the claim and gets the stored result
// instead of a second transfer. The transfer_id is stable per key,
// which is also what makes the invite commission's
// UNIQUE(source_transfer_id) and the VIP EXP award record actually
// dedup across retries.
//
// PIN throttling (M6): the Coin Seller PIN is 4 digits with a fast
// hash and no lockout, so an attacker holding a seller's session token
// could brute-force it online. 5 failed attempts now lock the PIN for
// 15 minutes (same shape as the owner staff login lockout).

export const PIN_MAX_FAILURES = 5;
export const PIN_LOCK_MS = 15 * 60 * 1000;
// A claim with no result older than this is treated as abandoned
// (the first attempt crashed before / during the money batch) and
// may be taken over by a retry with the same key.
export const IDEMPOTENCY_STALE_MS = 60 * 1000;

export async function ensureTransferIdempotencySchema(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS role_transfer_idempotency (
    sender_user_id TEXT NOT NULL,
    wallet_type TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    transfer_id TEXT NOT NULL,
    receiver_user_id TEXT NOT NULL,
    coins INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'processing',
    result_json TEXT,
    claimed_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(sender_user_id, wallet_type, idempotency_key)
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS wallet_pin_attempts (
    user_id TEXT NOT NULL,
    wallet_type TEXT NOT NULL,
    failed_count INTEGER NOT NULL DEFAULT 0,
    locked_until INTEGER,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(user_id, wallet_type)
  )`).run();
}

export async function findTransferIdempotency(db, { senderUserId, walletType, idempotencyKey }) {
  await ensureTransferIdempotencySchema(db);
  return db.prepare(
    "SELECT sender_user_id,wallet_type,idempotency_key,transfer_id,receiver_user_id,coins,status,result_json,claimed_at,updated_at FROM role_transfer_idempotency WHERE sender_user_id=? AND wallet_type=? AND idempotency_key=?"
  ).bind(senderUserId, walletType, idempotencyKey).first();
}

/// Claims an idempotency key atomically. Returns
/// `{ claimed: true }` when this caller owns the transfer, or
/// `{ claimed: false, existing }` when the key was already claimed
/// (a retry / concurrent duplicate). Any other error is rethrown.
export async function claimTransferIdempotency(db, {
  senderUserId, walletType, idempotencyKey, transferId, receiverUserId, coins, ts = Date.now(),
}) {
  await ensureTransferIdempotencySchema(db);
  try {
    await db.prepare(
      "INSERT INTO role_transfer_idempotency(sender_user_id,wallet_type,idempotency_key,transfer_id,receiver_user_id,coins,status,claimed_at,updated_at) VALUES(?,?,?,?,?,?, 'processing',?,?)"
    ).bind(senderUserId, walletType, idempotencyKey, transferId, receiverUserId, coins, ts, ts).run();
    return { claimed: true };
  } catch (error) {
    const existing = await findTransferIdempotency(db, { senderUserId, walletType, idempotencyKey });
    if (existing) return { claimed: false, existing };
    throw error;
  }
}

export async function completeTransferIdempotency(db, {
  senderUserId, walletType, idempotencyKey, resultJson, ts = Date.now(),
}) {
  await db.prepare(
    "UPDATE role_transfer_idempotency SET status='done',result_json=?,updated_at=? WHERE sender_user_id=? AND wallet_type=? AND idempotency_key=?"
  ).bind(resultJson, ts, senderUserId, walletType, idempotencyKey).run();
}

export async function deleteTransferIdempotency(db, { senderUserId, walletType, idempotencyKey }) {
  await db.prepare(
    "DELETE FROM role_transfer_idempotency WHERE sender_user_id=? AND wallet_type=? AND idempotency_key=?"
  ).bind(senderUserId, walletType, idempotencyKey).run();
}

/// Resolves a duplicate claim row. Returns one of:
/// - `{ status: 'done', result }` — the original finished; reuse it.
/// - `{ status: 'in_progress' }` — the original is still running;
///   the caller should answer 409 and let the client retry later.
/// - `{ status: 'abandoned' }` — the original crashed before the
///   money moved (stale claim, no ledger rows for its transfer_id);
///   the caller may delete the row and retry the transfer.
/// - `{ status: 'done', result }` (rebuilt) — the money moved but the
///   result was never stored (crash after the batch); the result is
///   rebuilt from the ledger + current balances.
export async function resolveDuplicateTransfer(db, row, ts = Date.now()) {
  if (row?.result_json) {
    try {
      return { status: "done", result: JSON.parse(String(row.result_json)) };
    } catch (_) {
      // Corrupt stored result: fall through to the ledger rebuild.
    }
  }
  const claimedAt = Number(row?.claimed_at ?? 0);
  if (ts - claimedAt < IDEMPOTENCY_STALE_MS) {
    return { status: "in_progress" };
  }
  const transferId = String(row?.transfer_id ?? "");
  const senderLedger = transferId
    ? await db.prepare(
        "SELECT 1 AS yes FROM role_wallet_ledger WHERE reference_id=? LIMIT 1"
      ).bind(transferId).first()
    : null;
  if (!senderLedger) return { status: "abandoned" };
  // The money moved but the result was never stored: rebuild it from
  // the ledger + current balances (the same shape transferRoleCoins
  // returns).
  const bonusRow = await db.prepare(
    "SELECT coin_amount FROM wallet_ledger WHERE reference_id=? AND kind='vip_coins_bonus' LIMIT 1"
  ).bind(transferId).first();
  const senderRow = await db.prepare(
    "SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).bind(row.sender_user_id, row.wallet_type).first();
  const receiverRow = await db.prepare(
    "SELECT coins FROM users WHERE id=?"
  ).bind(row.receiver_user_id).first();
  return {
    status: "done",
    result: {
      transfer_id: transferId,
      sender_role_coin_balance: Number(senderRow?.balance_coins ?? 0),
      receiver_coin_balance: Number(receiverRow?.coins ?? 0),
      coins_bonus: Number(bonusRow?.coin_amount ?? 0),
    },
  };
}

// --- Wallet PIN throttling (M6) ---------------------------------------

export async function checkPinLock(db, userId, walletType, ts = Date.now()) {
  await ensureTransferIdempotencySchema(db);
  const row = await db.prepare(
    "SELECT failed_count,locked_until FROM wallet_pin_attempts WHERE user_id=? AND wallet_type=?"
  ).bind(userId, walletType).first();
  if (row?.locked_until != null && Number(row.locked_until) > ts) {
    throw new Error("pin_locked");
  }
  return row;
}

export async function recordPinFailure(db, userId, walletType, ts = Date.now()) {
  await ensureTransferIdempotencySchema(db);
  const row = await db.prepare(
    "SELECT failed_count FROM wallet_pin_attempts WHERE user_id=? AND wallet_type=?"
  ).bind(userId, walletType).first();
  const failures = Number(row?.failed_count ?? 0) + 1;
  if (failures >= PIN_MAX_FAILURES) {
    await db.prepare(
      "INSERT INTO wallet_pin_attempts(user_id,wallet_type,failed_count,locked_until,updated_at) VALUES(?,?,0,?,?) ON CONFLICT(user_id,wallet_type) DO UPDATE SET failed_count=0,locked_until=?,updated_at=?"
    ).bind(userId, walletType, ts + PIN_LOCK_MS, ts, ts + PIN_LOCK_MS, ts).run();
    return { locked: true, lockedUntil: ts + PIN_LOCK_MS };
  }
  await db.prepare(
    "INSERT INTO wallet_pin_attempts(user_id,wallet_type,failed_count,locked_until,updated_at) VALUES(?,?,?,NULL,?) ON CONFLICT(user_id,wallet_type) DO UPDATE SET failed_count=?,locked_until=NULL,updated_at=?"
  ).bind(userId, walletType, failures, ts, failures, ts).run();
  return { locked: false, failures };
}

export async function clearPinFailures(db, userId, walletType) {
  await ensureTransferIdempotencySchema(db);
  await db.prepare(
    "DELETE FROM wallet_pin_attempts WHERE user_id=? AND wallet_type=?"
  ).bind(userId, walletType).run();
}
