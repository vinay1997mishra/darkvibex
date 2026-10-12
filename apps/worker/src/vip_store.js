import { vipCapabilities, vipRule } from "./vip_policy.js";

const DAY_MS=86400000;
const parsed=(value)=>{try{return JSON.parse(String(value??"{}"))||{};}catch(_){return {};}};

export async function ensureVipSchema(db){
  await db.prepare("CREATE TABLE IF NOT EXISTS user_vip (user_id TEXT PRIMARY KEY, level INTEGER NOT NULL DEFAULT 0, exp_balance INTEGER NOT NULL DEFAULT 0, total_received_coins INTEGER NOT NULL DEFAULT 0, active_until INTEGER, custom_id TEXT UNIQUE, last_id_change_at INTEGER, id_change_level INTEGER NOT NULL DEFAULT 0, preferences_json TEXT NOT NULL DEFAULT '{}', free_say_hi_used INTEGER NOT NULL DEFAULT 0, free_say_hi_cycle TEXT NOT NULL DEFAULT '', exp_rate_version INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)").run();
  try {
    await db.prepare("SELECT exp_rate_version FROM user_vip LIMIT 1").first();
  } catch (error) {
    if (!/no such column/i.test(String(error?.message ?? error))) throw error;
    await db.prepare("ALTER TABLE user_vip ADD COLUMN exp_rate_version INTEGER NOT NULL DEFAULT 0").run();
  }
  await db.prepare("UPDATE user_vip SET exp_balance=CAST(exp_balance / 400 AS INTEGER), exp_rate_version=1 WHERE exp_rate_version=0").run();
  await db.prepare("CREATE TABLE IF NOT EXISTS vip_events (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, kind TEXT NOT NULL, coin_amount INTEGER NOT NULL DEFAULT 0, exp_delta INTEGER NOT NULL DEFAULT 0, level_before INTEGER NOT NULL DEFAULT 0, level_after INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)").run();
  await db.prepare("CREATE TABLE IF NOT EXISTS profile_visitors (viewed_user_id TEXT NOT NULL, visitor_user_id TEXT NOT NULL, first_visited_at INTEGER NOT NULL, last_visited_at INTEGER NOT NULL, visit_count INTEGER NOT NULL DEFAULT 1, PRIMARY KEY (viewed_user_id, visitor_user_id))").run();
}

async function logEvent(db,userId,kind,coins,exp,before,after,ts){
  await db.prepare("INSERT INTO vip_events (id,user_id,kind,coin_amount,exp_delta,level_before,level_after,created_at) VALUES (?,?,?,?,?,?,?,?)")
    .bind(crypto.randomUUID(),userId,kind,coins||0,exp||0,before||0,after||0,ts).run();
}

async function ensureRow(db,userId,ts=Date.now()){
  await ensureVipSchema(db);
  const user=await db.prepare("SELECT vip_level FROM users WHERE id=?").bind(userId).first();
  if(!user) throw new Error("user_not_found");
  const seed=Math.max(0,Math.min(18,Number(user.vip_level??0)));
  const rule=vipRule(seed);
  const until=seed>0?ts+Number(rule?.days??30)*DAY_MS:null;
  await db.prepare("INSERT INTO user_vip (user_id,level,exp_balance,total_received_coins,active_until,custom_id,last_id_change_at,id_change_level,preferences_json,free_say_hi_used,free_say_hi_cycle,created_at,updated_at) VALUES (?,?,0,0,?,NULL,NULL,0,'{}',0,'',?,?) ON CONFLICT(user_id) DO NOTHING")
    .bind(userId,seed,until,ts,ts).run();
  return db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(userId).first();
}

async function settle(db,row,ts=Date.now()){
  let level=Number(row.level??0);
  let exp=Number(row.exp_balance??0);
  let until=row.active_until==null?null:Number(row.active_until);
  if(level<=0||until==null||until>ts) return row;
  const before=level;
  const rule=vipRule(level);
  const maintain=Number(rule?.maintain??0);
  if(maintain>0&&exp>=maintain){
    exp-=maintain;
    until=ts+Number(rule?.days??30)*DAY_MS;
    await db.prepare("UPDATE user_vip SET exp_balance=?,active_until=?,free_say_hi_used=0,free_say_hi_cycle=?,updated_at=? WHERE user_id=?")
      .bind(exp,until,String(until),ts,row.user_id).run();
    await logEvent(db,row.user_id,"maintain",0,-maintain,before,before,ts);
  }else{
    level=Math.max(0,level-1);
    const next=vipRule(level);
    until=level>0?ts+Number(next?.days??30)*DAY_MS:null;
    await db.batch([
      db.prepare("UPDATE user_vip SET level=?,exp_balance=0,active_until=?,free_say_hi_used=0,free_say_hi_cycle=?,updated_at=? WHERE user_id=?").bind(level,until,String(until??""),ts,row.user_id),
      db.prepare("UPDATE users SET vip_level=?,updated_at=? WHERE id=?").bind(level,ts,row.user_id),
    ]);
    await logEvent(db,row.user_id,"expire_drop",0,0,before,level,ts);
  }
  return db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(row.user_id).first();
}

function payload(row,ts=Date.now()){
  const level=Math.max(0,Math.min(18,Number(row.level??0)));
  const until=row.active_until==null?null:Number(row.active_until);
  const active=level>0&&until!=null&&until>ts;
  return {
    level,
    exp_balance:Number(row.exp_balance??0),
    total_received_coins:Number(row.total_received_coins??0),
    active_until:until,
    active,
    custom_id:row.custom_id??null,
    preferences:parsed(row.preferences_json),
    free_say_hi_remaining:Math.max(0,4-Number(row.free_say_hi_used??0)),
    free_say_hi_max_words:30,
    ...vipCapabilities(level,active),
  };
}

export async function getVipStatus(db,userId,ts=Date.now()){
  let row=await ensureRow(db,userId,ts);
  row=await settle(db,row,ts);
  return payload(row,ts);
}

export async function awardSellerVipExp(db,userId,coinAmount,ts=Date.now()){
  const coins=Number(coinAmount??0);
  if(!Number.isSafeInteger(coins)||coins<=0) throw new Error("invalid_coin_amount");
  let row=await ensureRow(db,userId,ts);
  row=await settle(db,row,ts);
  let level=Number(row.level??0);
  let exp=Number(row.exp_balance??0);
  let total=Number(row.total_received_coins??0);
  let until=row.active_until==null?null:Number(row.active_until);
  const active=level>0&&until!=null&&until>ts;
  const multiplier=1/400;
  // Carry sub-400 coin amounts across transfers using the existing lifetime
  // coin counter, so 399 + 1 coins correctly produce 1 VIP EXP.
  const awarded=Math.floor((total+coins)/400)-Math.floor(total/400);
  const before=level;
  exp+=awarded;
  total+=coins;
  while(level<18){
    const next=vipRule(level+1);
    if(!next||exp<next.upgrade) break;
    // Every VIP tier starts from zero; excess EXP is not carried forward.
    exp=0;
    level+=1;
    until=ts+next.days*DAY_MS;
    break;
  }
  const changed=level!==before;
  await db.batch([
    db.prepare("UPDATE user_vip SET level=?,exp_balance=?,total_received_coins=?,active_until=?,free_say_hi_used=CASE WHEN ? THEN 0 ELSE free_say_hi_used END,free_say_hi_cycle=CASE WHEN ? THEN ? ELSE free_say_hi_cycle END,updated_at=? WHERE user_id=?")
      .bind(level,exp,total,until,changed?1:0,changed?1:0,String(until??""),ts,userId),
    db.prepare("UPDATE users SET vip_level=?,updated_at=? WHERE id=?").bind(level,ts,userId),
  ]);
  await logEvent(db,userId,"coin_seller_received",coins,awarded,before,level,ts);
  const updated=await db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(userId).first();
  return {vip:payload(updated,ts),awarded_exp:awarded,multiplier,level_up:changed,previous_level:before,new_level:level};
}

export async function readVipRow(db,userId,ts=Date.now()){
  let row=await ensureRow(db,userId,ts);
  return settle(db,row,ts);
}

export function vipPayload(row,ts=Date.now()){return payload(row,ts);}
export async function logVipEvent(db,...args){return logEvent(db,...args);}
