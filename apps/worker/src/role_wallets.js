const allowedRoleWallets = new Set(["coin_seller","merchant"]);

export async function ensureRoleWalletSchema(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS role_wallets (
    user_id TEXT NOT NULL,
    wallet_type TEXT NOT NULL CHECK(wallet_type IN ('coin_seller','merchant')),
    balance_coins INTEGER NOT NULL DEFAULT 0 CHECK(balance_coins>=0),
    credential_hash TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(user_id,wallet_type),
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
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
    `INSERT INTO role_wallets(user_id,wallet_type,balance_coins,credential_hash,created_at,updated_at)
     VALUES(?,?,0,NULL,?,?)
     ON CONFLICT(user_id,wallet_type) DO NOTHING`
  ).bind(userId,type,ts,ts).run();
  return db.prepare(
    "SELECT user_id,wallet_type,balance_coins,credential_hash,created_at,updated_at FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).bind(userId,type).first();
}

export async function roleWalletDetail(db,userId,walletType,limit=200,ts=Date.now()){
  const wallet=await ensureRoleWallet(db,userId,walletType,ts);
  const rows=await db.prepare(
    `SELECT id,kind,coin_amount,coin_balance_after,
            counterparty_user_id,reference_id,created_at
       FROM role_wallet_ledger
      WHERE user_id=? AND wallet_type=?
      ORDER BY created_at DESC LIMIT ?`
  ).bind(userId,walletType,Math.max(1,Math.min(500,Number(limit)||200))).all();
  return {
    wallet_type:walletType,
    balance_coins:Number(wallet?.balance_coins ?? 0),
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
  ts=Date.now(),
}){
  const amount=Number(coins);
  if(!Number.isSafeInteger(amount)||amount<=0) throw new Error("invalid_coin_amount");
  if(!receiverUserId||receiverUserId===senderUserId) throw new Error("invalid_receiver");
  const wallet=await verifyRoleWalletCredential(
    db,senderUserId,walletType,credentialHash,ts,
  );
  const receiver=await db.prepare("SELECT coins FROM users WHERE id=?").bind(receiverUserId).first();
  if(!receiver) throw new Error("receiver_not_found");
  if(Number(wallet.balance_coins ?? 0)<amount) {
    throw new Error("insufficient_role_wallet_coins");
  }
  const reference=crypto.randomUUID();
  const after=Number(wallet.balance_coins)-amount;
  const receiverAfter=Number(receiver.coins ?? 0)+amount;
  await db.batch([
    db.prepare(
      "UPDATE role_wallets SET balance_coins=?,updated_at=? WHERE user_id=? AND wallet_type=? AND balance_coins>=?"
    ).bind(after,ts,senderUserId,walletType,amount),
    db.prepare("UPDATE users SET coins=?,updated_at=? WHERE id=?")
      .bind(receiverAfter,ts,receiverUserId),
    db.prepare(
      `INSERT INTO role_wallet_ledger(
        id,user_id,wallet_type,kind,coin_amount,
        coin_balance_after,counterparty_user_id,reference_id,created_at
      ) VALUES(?,?,?,?,?,?,?,?,?)`
    ).bind(
      crypto.randomUUID(),senderUserId,walletType,"coin_send",-amount,after,
      receiverUserId,reference,ts,
    ),
    db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(
      crypto.randomUUID(),receiverUserId,
      walletType==="coin_seller"?"coin_seller_received":"merchant_received",
      amount,receiverAfter,reference,ts,
    ),
  ]);
  return {
    transfer_id:reference,
    sender_role_coin_balance:after,
    receiver_coin_balance:receiverAfter,
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
  await db.batch([
    db.prepare(
      "UPDATE role_wallets SET balance_coins=?,updated_at=? WHERE user_id=? AND wallet_type=?"
    ).bind(nextCoins,ts,userId,walletType),
    db.prepare(
      `INSERT INTO role_wallet_ledger(
        id,user_id,wallet_type,kind,coin_amount,
        coin_balance_after,counterparty_user_id,reference_id,created_at
      ) VALUES(?,?,?,?,?,?,NULL,?,?)`
    ).bind(
      crypto.randomUUID(),userId,walletType,"owner_adjustment",
      Number(coinDelta),nextCoins,referenceId,ts,
    ),
  ]);
  return {balance_coins:nextCoins};
}
