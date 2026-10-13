const allowedRoleWallets = new Set(["coin_seller","merchant"]);

export async function ensureRoleWalletSchema(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS role_wallets (
    user_id TEXT NOT NULL,
    wallet_type TEXT NOT NULL CHECK(wallet_type IN ('coin_seller','merchant')),
    balance_coins INTEGER NOT NULL DEFAULT 0 CHECK(balance_coins>=0),
    usd_cents INTEGER NOT NULL DEFAULT 0 CHECK(usd_cents>=0),
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
    usd_cents_amount INTEGER NOT NULL DEFAULT 0,
    coin_balance_after INTEGER NOT NULL DEFAULT 0,
    usd_cents_after INTEGER NOT NULL DEFAULT 0,
    counterparty_user_id TEXT,
    reference_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS role_wallet_withdrawals (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    wallet_type TEXT NOT NULL CHECK(wallet_type IN ('coin_seller','merchant')),
    destination_type TEXT NOT NULL CHECK(destination_type IN ('company','crypto_usdt')),
    destination_value TEXT NOT NULL DEFAULT '',
    amount_usd_cents INTEGER NOT NULL CHECK(amount_usd_cents>0),
    status TEXT NOT NULL DEFAULT 'pending',
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
    `INSERT INTO role_wallets(user_id,wallet_type,balance_coins,usd_cents,credential_hash,created_at,updated_at)
     VALUES(?,?,0,0,NULL,?,?)
     ON CONFLICT(user_id,wallet_type) DO NOTHING`
  ).bind(userId,type,ts,ts).run();
  return db.prepare(
    "SELECT user_id,wallet_type,balance_coins,usd_cents,credential_hash,created_at,updated_at FROM role_wallets WHERE user_id=? AND wallet_type=?"
  ).bind(userId,type).first();
}

export async function roleWalletDetail(db,userId,walletType,limit=200,ts=Date.now()){
  const wallet=await ensureRoleWallet(db,userId,walletType,ts);
  const rows=await db.prepare(
    `SELECT id,kind,coin_amount,usd_cents_amount,coin_balance_after,usd_cents_after,
            counterparty_user_id,reference_id,created_at
       FROM role_wallet_ledger
      WHERE user_id=? AND wallet_type=?
      ORDER BY created_at DESC LIMIT ?`
  ).bind(userId,walletType,Math.max(1,Math.min(500,Number(limit)||200))).all();
  const withdrawals=await db.prepare(
    `SELECT id,destination_type,destination_value,amount_usd_cents,status,created_at
       FROM role_wallet_withdrawals
      WHERE user_id=? AND wallet_type=?
      ORDER BY created_at DESC LIMIT 100`
  ).bind(userId,walletType).all();
  return {
    wallet_type:walletType,
    balance_coins:Number(wallet?.balance_coins ?? 0),
    total_usd_cents:Number(wallet?.usd_cents ?? 0),
    credential_set:Boolean(wallet?.credential_hash),
    minimum_transfer_usd_cents:walletType==="coin_seller"?30000:100000,
    transactions:rows.results ?? [],
    withdrawals:withdrawals.results ?? [],
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
  if(String(wallet.credential_hash)!==String(credentialHash)) throw new Error("invalid_wallet_credential");
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
  if(Number(wallet.balance_coins ?? 0)<amount) throw new Error("insufficient_role_wallet_coins");
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
        id,user_id,wallet_type,kind,coin_amount,usd_cents_amount,
        coin_balance_after,usd_cents_after,counterparty_user_id,reference_id,created_at
      ) VALUES(?,?,?,?,?,0,?,
        (SELECT usd_cents FROM role_wallets WHERE user_id=? AND wallet_type=?),
        ?,?,?)`
    ).bind(
      crypto.randomUUID(),senderUserId,walletType,"coin_send",-amount,after,
      senderUserId,walletType,receiverUserId,reference,ts,
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

export async function requestRoleDollarWithdrawal(db,{
  userId,
  walletType,
  destinationType,
  destinationValue="",
  amountUsdCents,
  credentialHash,
  ts=Date.now(),
}){
  const amount=Number(amountUsdCents);
  const minimum=walletType==="coin_seller"?30000:100000;
  if(!Number.isSafeInteger(amount)||amount<minimum) throw new Error("minimum_usd_not_met");
  if(!["company","crypto_usdt"].includes(destinationType)) throw new Error("invalid_destination");
  if(destinationType==="crypto_usdt"&&!String(destinationValue).trim()) throw new Error("usdt_address_required");
  const wallet=await verifyRoleWalletCredential(db,userId,walletType,credentialHash,ts);
  if(Number(wallet.usd_cents ?? 0)<amount) throw new Error("insufficient_usd_balance");
  const id=crypto.randomUUID();
  const usdAfter=Number(wallet.usd_cents)-amount;
  await db.batch([
    db.prepare(
      "UPDATE role_wallets SET usd_cents=?,updated_at=? WHERE user_id=? AND wallet_type=? AND usd_cents>=?"
    ).bind(usdAfter,ts,userId,walletType,amount),
    db.prepare(
      "INSERT INTO role_wallet_withdrawals(id,user_id,wallet_type,destination_type,destination_value,amount_usd_cents,status,created_at) VALUES(?,?,?,?,?,?,'pending',?)"
    ).bind(id,userId,walletType,destinationType,String(destinationValue).trim(),amount,ts),
    db.prepare(
      `INSERT INTO role_wallet_ledger(
        id,user_id,wallet_type,kind,coin_amount,usd_cents_amount,
        coin_balance_after,usd_cents_after,counterparty_user_id,reference_id,created_at
      ) VALUES(?,?,?,?,0,?,
        (SELECT balance_coins FROM role_wallets WHERE user_id=? AND wallet_type=?),
        ?,NULL,?,?)`
    ).bind(
      crypto.randomUUID(),userId,walletType,
      destinationType==="company"?"usd_to_company":"usd_to_usdt",
      -amount,userId,walletType,usdAfter,id,ts,
    ),
  ]);
  return {withdrawal_id:id,usd_cents_after:usdAfter,status:"pending"};
}

export async function adjustRoleWallet(db,{
  userId,walletType,coinDelta=0,usdCentsDelta=0,referenceId="owner",ts=Date.now(),
}){
  const wallet=await ensureRoleWallet(db,userId,walletType,ts);
  const nextCoins=Number(wallet.balance_coins ?? 0)+Number(coinDelta);
  const nextUsd=Number(wallet.usd_cents ?? 0)+Number(usdCentsDelta);
  if(!Number.isSafeInteger(nextCoins)||nextCoins<0||!Number.isSafeInteger(nextUsd)||nextUsd<0){
    throw new Error("invalid_role_wallet_adjustment");
  }
  await db.batch([
    db.prepare(
      "UPDATE role_wallets SET balance_coins=?,usd_cents=?,updated_at=? WHERE user_id=? AND wallet_type=?"
    ).bind(nextCoins,nextUsd,ts,userId,walletType),
    db.prepare(
      `INSERT INTO role_wallet_ledger(
        id,user_id,wallet_type,kind,coin_amount,usd_cents_amount,
        coin_balance_after,usd_cents_after,counterparty_user_id,reference_id,created_at
      ) VALUES(?,?,?,?,?,?,?,?,NULL,?,?)`
    ).bind(
      crypto.randomUUID(),userId,walletType,"owner_adjustment",
      Number(coinDelta),Number(usdCentsDelta),nextCoins,nextUsd,referenceId,ts,
    ),
  ]);
  return {balance_coins:nextCoins,usd_cents:nextUsd};
}
