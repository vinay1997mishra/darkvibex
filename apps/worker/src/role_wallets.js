import { coinsBonusForPurchase } from "./vip_policy.js";
import { claimTransferIdempotency } from "./transfer_idempotency.js";

const allowedRoleWallets = new Set(["coin_seller","merchant"]);

export async function ensureRoleWalletSchema(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS role_wallets (
    user_id TEXT NOT NULL,
    wallet_type TEXT NOT NULL CHECK(wallet_type IN ('coin_seller','merchant')),
    balance_coins INTEGER NOT NULL DEFAULT 0 CHECK(balance_coins>=0),
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','banned')),
    credential_hash TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(user_id,wallet_type),
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  try {
    await db.prepare("ALTER TABLE role_wallets ADD COLUMN status TEXT NOT NULL DEFAULT 'active'").run();
  } catch (_) {}
  await db.prepare(`CREATE TABLE IF NOT EXISTS role_wallet_ledger (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    wallet_type TEXT NOT NULL CHECK(wallet_type IN ('coin_seller','merchant')),
    kind TEXT NOT NULL,
    coin_amount INTEGER NOT NULL DEFAULT 0,
    coin_balance_after INTEGER NOT NULL DEFAULT 0,
    counterparty_user_id TEXT,
    reference_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
}

export async function ensureRoleWallet(db,userId,walletType,ts=Date.now()){
  await ensureRoleWalletSchema(db);
  const type=String(walletType ?? "");
  if(!allowedRoleWallets.has(type)) throw new Error("invalid_role_wallet");
  const user=await db.prepare("SELECT role FROM users WHERE id=?").bind(userId).first();
  if(!user) throw new Error("user_not_found");
  if(String(user.role)!==type && String(user.role)!=="platform_owner") {
    throw new Error(type+"_role_required");
  }
  await db.prepare(
    `INSERT INTO role_wallets(user_id,wallet_type,balance_coins,status,credential_hash,created_at,updated_at)
     VALUES(?,?,0,'active',NULL,?,?)
     ON CONFLICT(user_id,wallet_type) DO NOTHING`
  ).bind(userId,type,ts,ts).run();
  return db.prepare(
    "SELECT user_id,wallet_type,balance_coins,status,credential_hash,created_at,updated_at FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).bind(userId,type).first();
}

export async function roleWalletDetail(db,userId,walletType,limit=200,ts=Date.now()){
  const wallet=await ensureRoleWallet(db,userId,walletType,ts);
  const rows=await db.prepare(
    `SELECT l.id,l.kind,l.coin_amount,l.coin_balance_after,
            l.counterparty_user_id,u.public_id AS counterparty_public_id,
            l.reference_id,l.created_at
       FROM role_wallet_ledger l
       LEFT JOIN users u ON u.id=l.counterparty_user_id
      WHERE l.user_id=? AND l.wallet_type=?
      ORDER BY l.created_at DESC LIMIT ?`
  ).bind(userId,walletType,Math.max(1,Math.min(500,Number(limit)||200))).all();
  return {
    wallet_type:walletType,
    balance_coins:Number(wallet?.balance_coins ?? 0),
    status:String(wallet?.status ?? "active"),
    banned:String(wallet?.status ?? "active")==="banned",
    credential_set:Boolean(wallet?.credential_hash),
    transactions:rows.results ?? [],
  };
}

export async function setRoleWalletCredential(db,userId,walletType,credentialHash,ts=Date.now()){
  await ensureRoleWallet(db,userId,walletType,ts);
  if(!credentialHash) throw new Error("credential_hash_required");
  await db.prepare(
    "UPDATE role_wallets SET credential_hash=?,updated_at=? WHERE user_id=? AND wallet_type=?"
  ).bind(credentialHash,ts,userId,walletType).run();
  return {ok:true};
}

export async function verifyRoleWalletCredential(db,userId,walletType,credentialHash,ts=Date.now()){
  const wallet=await ensureRoleWallet(db,userId,walletType,ts);
  if(String(wallet?.status ?? "active")==="banned") throw new Error("role_wallet_banned");
  if(!wallet?.credential_hash) throw new Error("wallet_credential_not_set");
  if(String(wallet.credential_hash)!==String(credentialHash)) {
    throw new Error("invalid_wallet_credential");
  }
  return wallet;
}

export async function transferRoleCoins(db,{
  senderUserId,
  walletType,
  receiverUserId,
  coins,
  credentialHash,
  // Idempotency (Wallet audit H1, 2026-11-22): a client-supplied key
  // makes a retry return the SAME transfer instead of a second one.
  // The key is claimed atomically before the money moves; the
  // transfer_id is stable per key, which is also what makes the
  // invite commission's UNIQUE(source_transfer_id) and the VIP EXP
  // award record dedup across retries.
  idempotencyKey=null,
  transferId=null,
  ts=Date.now(),
}){
  const amount=Number(coins);
  if(!Number.isSafeInteger(amount)||amount<=0) throw new Error("invalid_coin_amount");
  // Self-transfer is ALLOWED (Vinay, 2026-11-23): a seller / merchant
  // may move coins from their own seller wallet into their own normal
  // wallet, and the receiver (themselves) still earns VIP EXP. Only a
  // missing receiver is invalid now.
  if(!receiverUserId) throw new Error("invalid_receiver");
  const wallet=await verifyRoleWalletCredential(
    db,senderUserId,walletType,credentialHash,ts,
  );
  const receiver=await db.prepare("SELECT coins FROM users WHERE id=?").bind(receiverUserId).first();
  if(!receiver) throw new Error("receiver_not_found");
  if(Number(wallet.balance_coins ?? 0)<amount) {
    throw new Error("insufficient_role_wallet_coins");
  }
  // Coins bonus on purchase (Vinay, 2026-11-19): on a Coin Seller
  // purchase the receiver gets extra coins on top of the purchased
  // amount — VIP5-10 +5%, VIP11-15 +10%, VIP16-18 +20%, VIP0-4 none.
  // The bonus is FREE coins created by the platform: the seller's role
  // wallet is debited only the purchased amount, and the bonus is
  // credited to the receiver in the same batch with its own ledger
  // entry (kind vip_coins_bonus). The bonus is NOT counted in
  // total_received_coins and earns NO EXP (EXP is 150 per $1 spent).
  // The receiver's VIP level is read from user_vip; the bonus applies
  // only while the VIP is active (active_until in the future) — an
  // expired VIP whose level has not been settled yet gets no bonus.
  let coinsBonus=0;
  // No bonus on a self-transfer (Vinay, 2026-11-23: only VIP EXP is
  // earned on self-transfer): the bonus is free platform coins, and a
  // seller moving their own coins to themselves would otherwise mint
  // free coins out of their own balance.
  if(walletType==="coin_seller" && receiverUserId!==senderUserId){
    try {
      const vipRow=await db.prepare("SELECT level, active_until FROM user_vip WHERE user_id=?").bind(receiverUserId).first();
      const vipLevel=Number(vipRow?.level ?? 0);
      const vipActive=vipLevel>0&&vipRow?.active_until!=null&&Number(vipRow.active_until)>ts;
      coinsBonus=vipActive?coinsBonusForPurchase(amount,vipLevel):0;
    } catch (_) {
      coinsBonus=0;
    }
  }
  const reference=String(transferId ?? "").trim() || crypto.randomUUID();
  const key=String(idempotencyKey ?? "").trim();
  // Claim the idempotency key BEFORE the money moves: the plain
  // INSERT is the atomic guard — a concurrent duplicate loses the
  // claim and the caller returns the stored result instead.
  if (key) {
    const claim = await claimTransferIdempotency(db, {
      senderUserId, walletType, idempotencyKey: key, transferId: reference,
      receiverUserId, coins: amount, ts,
    });
    if (!claim.claimed) {
      const error = new Error("duplicate_transfer");
      error.existing = claim.existing;
      throw error;
    }
  }
  // Atomic, relative moves (audit 2026-11-20): the old batch SET absolute
  // balances from stale reads, so two concurrent sends to the same
  // receiver overwrote each other and lost coins — and in real D1 a
  // failed sender guard would not have stopped the receiver credit in
  // the same batch. Balances for the ledgers are re-read after the move.
  //
  // Atomicity (Wallet audit H4, 2026-11-22): the debit, the receiver
  // credit and all three ledger rows now ride ONE db.batch, so a crash
  // can no longer leave the seller debited with the receiver uncredited
  // (or credited with no ledger row). Each step after the debit is
  // gated on changes()=1 — the same gating the gift/diamond/game paths
  // already use — so a failed debit makes the whole batch a no-op.
  // The ledger balances are read from the tables inside the batch
  // (subqueries), i.e. the post-debit / post-credit values.
  const ledgerKind = walletType==="coin_seller" ? "coin_seller_received" : "merchant_received";
  const batchResults = await db.batch([
    db.prepare(
      "UPDATE role_wallets SET balance_coins=balance_coins-?,updated_at=? WHERE user_id=? AND wallet_type=? AND balance_coins>=?"
    ).bind(amount,ts,senderUserId,walletType,amount),
    db.prepare(
      "UPDATE users SET coins=coins+?,updated_at=? WHERE id=? AND changes()=1"
    ).bind(amount + coinsBonus, ts, receiverUserId),
    db.prepare(
      `INSERT INTO role_wallet_ledger(
        id,user_id,wallet_type,kind,coin_amount,
        coin_balance_after,counterparty_user_id,reference_id,created_at
      ) SELECT ?,?,?,?,?,(SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?),?,?,? WHERE changes()=1`
    ).bind(
      crypto.randomUUID(),senderUserId,walletType,"coin_send",-amount,
      senderUserId,walletType,receiverUserId,reference,ts,
    ),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) " +
      "SELECT ?,u.id,?,?,(SELECT coins FROM users WHERE id=?)-?, ?,? FROM users u WHERE u.id=? AND changes()=1"
    ).bind(
      crypto.randomUUID(),ledgerKind,amount,receiverUserId,coinsBonus,reference,ts,receiverUserId,
    ),
    ...(coinsBonus > 0 ? [
      db.prepare(
        "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) " +
        "SELECT ?,u.id,'vip_coins_bonus',?,u.coins,?,? FROM users u WHERE u.id=? AND EXISTS(SELECT 1 FROM wallet_ledger WHERE reference_id=? AND kind=?)"
      ).bind(
        crypto.randomUUID(),coinsBonus,reference,ts,receiverUserId,reference,ledgerKind,
      ),
    ] : []),
  ]);
  const debitedChanges = Number(batchResults?.[0]?.meta?.changes ?? -1);
  // Belt and braces: the sender ledger row is the ground truth that
  // the transfer happened. If it is missing and the debit changed
  // nothing, the sender could not pay; if the debit did change a row
  // but the ledger is missing, the gating misfired and the transfer
  // is in an unknown state, so fail loudly instead of reporting
  // success (the idempotency claim lets a retry resolve it).
  const senderLedger = await db.prepare(
    "SELECT 1 AS yes FROM role_wallet_ledger WHERE reference_id=? AND kind='coin_send' LIMIT 1"
  ).bind(reference).first();
  if (!senderLedger && debitedChanges === 0) {
    throw new Error("insufficient_role_wallet_coins");
  }
  if (!senderLedger) {
    throw new Error("transfer_ledger_missing");
  }
  const receiverRow = await db.prepare(
    "SELECT coins FROM users WHERE id=?"
  ).bind(receiverUserId).first();
  const receiverBalance = Number(receiverRow?.coins ?? 0);
  const senderRow = await db.prepare(
    "SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).bind(senderUserId,walletType).first();
  const senderBalance = Number(senderRow?.balance_coins ?? 0);
  return {
    transfer_id:reference,
    sender_role_coin_balance:senderBalance,
    receiver_coin_balance:receiverBalance,
    coins_bonus:coinsBonus,
  };
}

export async function adjustRoleWallet(db,{
  userId,
  walletType,
  coinDelta=0,
  referenceId="owner",
  ts=Date.now(),
}){
  const wallet=await ensureRoleWallet(db,userId,walletType,ts);
  const nextCoins=Number(wallet.balance_coins ?? 0)+Number(coinDelta);
  if(!Number.isSafeInteger(nextCoins)||nextCoins<0){
    throw new Error("invalid_role_wallet_adjustment");
  }
  // Relative update guarded by the funds check (audit 2026-11-20: the
  // old absolute SET from a stale read lost concurrent adjustments).
  const updated = await db.prepare(
    "UPDATE role_wallets SET balance_coins=balance_coins+?,updated_at=? WHERE user_id=? AND wallet_type=? AND balance_coins+?>=0"
  ).bind(Number(coinDelta),ts,userId,walletType,Number(coinDelta)).run();
  if (Number(updated.meta?.changes ?? 0) !== 1) {
    throw new Error("invalid_role_wallet_adjustment");
  }
  const afterRow = await db.prepare(
    "SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).bind(userId,walletType).first();
  const balanceAfter = Number(afterRow?.balance_coins ?? 0);
  await db.prepare(
    `INSERT INTO role_wallet_ledger(
      id,user_id,wallet_type,kind,coin_amount,
      coin_balance_after,counterparty_user_id,reference_id,created_at
    ) VALUES(?,?,?,?,?,?,NULL,?,?)`
  ).bind(
    crypto.randomUUID(),userId,walletType,"owner_adjustment",
    Number(coinDelta),balanceAfter,referenceId,ts,
  ).run();
  return {balance_coins:balanceAfter};
}
