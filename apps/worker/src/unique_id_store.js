import { ensureVipSchema, getVipStatus } from "./vip_store.js";

const seeds = [
  { public_id: "1111", price_coins: 500000, duration_days: 30 },
  { public_id: "2222", price_coins: 750000, duration_days: 30 },
  { public_id: "7777", price_coins: 1500000, duration_days: 30 },
  { public_id: "8888", price_coins: 2000000, duration_days: 30 },
  { public_id: "9999", price_coins: 2500000, duration_days: 30 },
  { public_id: "131313", price_coins: 5000000, duration_days: 0 },
];

export async function ensureUniqueIdStoreSchema(db) {
  await ensureVipSchema(db);
  await db.prepare(`CREATE TABLE IF NOT EXISTS unique_id_catalog (
    public_id TEXT PRIMARY KEY,
    price_coins INTEGER NOT NULL CHECK(price_coins>=0),
    duration_days INTEGER NOT NULL DEFAULT 0 CHECK(duration_days>=0),
    enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`).run();
  await db.prepare(`CREATE TABLE IF NOT EXISTS unique_id_purchases (
    id TEXT PRIMARY KEY,
    public_id TEXT NOT NULL,
    buyer_user_id TEXT NOT NULL,
    activated_at INTEGER NOT NULL,
    expires_at INTEGER,
    price_coins INTEGER NOT NULL,
    FOREIGN KEY (buyer_user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  await db.prepare(
    "CREATE INDEX IF NOT EXISTS idx_unique_id_purchase_owner ON unique_id_purchases(buyer_user_id,activated_at DESC)"
  ).run();
  const ts=Date.now();
  for (const item of seeds) {
    await db.prepare(
      `INSERT INTO unique_id_catalog(public_id,price_coins,duration_days,enabled,created_at,updated_at)
       VALUES(?,?,?,1,?,?)
       ON CONFLICT(public_id) DO NOTHING`
    ).bind(item.public_id,item.price_coins,item.duration_days,ts,ts).run();
  }
}

export async function uniqueIdCatalog(db, ts=Date.now()) {
  await ensureUniqueIdStoreSchema(db);
  const rows=await db.prepare(
    `SELECT public_id,price_coins,duration_days,enabled
       FROM unique_id_catalog
      WHERE enabled=1 AND public_id GLOB '[0-9]*'
      ORDER BY LENGTH(public_id),CAST(public_id AS INTEGER)`
  ).all();
  const active=await db.prepare(
    `SELECT custom_id,custom_id_expires_at
       FROM user_vip
      WHERE custom_id IS NOT NULL`
  ).all();
  const taken=new Set();
  for (const row of active.results ?? []) {
    const id=String(row.custom_id ?? "");
    const expiry=row.custom_id_expires_at==null?null:Number(row.custom_id_expires_at);
    if (id && (expiry==null || expiry===0 || expiry>ts)) taken.add(id);
  }
  return (rows.results ?? [])
    .filter(row=>/^\d{4,8}$/.test(String(row.public_id ?? "")))
    .map(row=>({
      public_id:String(row.public_id),
      price_coins:Number(row.price_coins ?? 0),
      duration_days:Number(row.duration_days ?? 0),
      permanent:Number(row.duration_days ?? 0)===0,
      available:!taken.has(String(row.public_id)),
    }));
}

export async function purchaseUniqueId(db,userId,publicId,ts=Date.now()) {
  await ensureUniqueIdStoreSchema(db);
  await getVipStatus(db,userId,ts);
  const requested=String(publicId ?? "").trim();
  if(!/^\d{4,8}$/.test(requested)) throw new Error("invalid_unique_id");
  const item=await db.prepare(
    "SELECT * FROM unique_id_catalog WHERE public_id=? AND enabled=1 LIMIT 1"
  ).bind(requested).first();
  if(!item) throw new Error("unique_id_not_available");

  const active=await db.prepare(
    "SELECT user_id,custom_id_expires_at FROM user_vip WHERE custom_id=? LIMIT 1"
  ).bind(requested).first();
  if(active && String(active.user_id)!==String(userId)){
    const expiry=active.custom_id_expires_at==null?null:Number(active.custom_id_expires_at);
    if(expiry==null || expiry===0 || expiry>ts) throw new Error("unique_id_taken");
  }

  const price=Number(item.price_coins ?? 0);
  const duration=Number(item.duration_days ?? 0);
  const expiresAt=duration>0 ? ts+duration*86400000 : null;
  const debit=await db.prepare(
    "UPDATE users SET coins=coins-?,updated_at=? WHERE id=? AND coins>=?"
  ).bind(price,ts,userId,price).run();
  if(Number(debit.meta?.changes ?? 0)!==1) throw new Error("insufficient_coins");

  try{
    await db.prepare(
      "UPDATE user_vip SET custom_id=?,custom_id_expires_at=?,last_id_change_at=?,updated_at=? WHERE user_id=?"
    ).bind(requested,expiresAt,ts,ts,userId).run();
    const purchaseId=crypto.randomUUID();
    await db.prepare(
      "INSERT INTO unique_id_purchases(id,public_id,buyer_user_id,activated_at,expires_at,price_coins) VALUES(?,?,?,?,?,?)"
    ).bind(purchaseId,requested,userId,ts,expiresAt,price).run();
    const wallet=await db.prepare("SELECT coins,diamonds FROM users WHERE id=?").bind(userId).first();
    await db.prepare(
      "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
    ).bind(crypto.randomUUID(),userId,"unique_id_purchase",-price,Number(wallet?.coins ?? 0),purchaseId,ts).run();
    return {
      public_id:requested,
      expires_at:expiresAt,
      wallet:{
        coins:Number(wallet?.coins ?? 0),
        diamonds:Number(wallet?.diamonds ?? 0),
      },
    };
  }catch(error){
    await db.prepare("UPDATE users SET coins=coins+?,updated_at=? WHERE id=?")
      .bind(price,Date.now(),userId).run();
    throw error;
  }
}

export async function upsertUniqueIdCatalogItem(db,input,ts=Date.now()){
  await ensureUniqueIdStoreSchema(db);
  const publicId=String(input?.public_id ?? "").trim();
  if(!/^\d{4,8}$/.test(publicId)) throw new Error("numeric_unique_id_required");
  const price=Math.max(0,Number(input?.price_coins ?? 0));
  const days=Math.max(0,Number(input?.duration_days ?? 0));
  const enabled=input?.enabled===false?0:1;
  if(!Number.isSafeInteger(price)||!Number.isSafeInteger(days)) throw new Error("invalid_unique_id_policy");
  await db.prepare(
    `INSERT INTO unique_id_catalog(public_id,price_coins,duration_days,enabled,created_at,updated_at)
     VALUES(?,?,?,?,?,?)
     ON CONFLICT(public_id) DO UPDATE SET
       price_coins=excluded.price_coins,
       duration_days=excluded.duration_days,
       enabled=excluded.enabled,
       updated_at=excluded.updated_at`
  ).bind(publicId,price,days,enabled,ts,ts).run();
  return {public_id:publicId,price_coins:price,duration_days:days,enabled:Boolean(enabled)};
}
