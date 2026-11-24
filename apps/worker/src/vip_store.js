import { vipCapabilities, vipRule, expBoostForLevel } from "./vip_policy.js";

const DAY_MS=86400000;
const parsed=(value)=>{try{return JSON.parse(String(value??"{}"))||{};}catch(_){return {};}};

export async function vipRuleForDb(db,level){
  const base=vipRule(level);
  if(!base) return null;
  try{
    const row=await db.prepare(
      "SELECT enabled,name,json_data FROM owner_catalog WHERE kind='vip_rule' AND id=? LIMIT 1"
    ).bind(String(level)).first();
    if(!row) return {...base,enabled:true,name:"VIP "+level};
    const data=parsed(row.json_data);
    const upgrade=Number(data.upgrade_exp ?? data.upgrade ?? base.upgrade);
    const maintain=Number(data.maintain_exp ?? data.maintain ?? base.maintain);
    const days=Number(data.validity_days ?? data.days ?? base.days);
    return {
      ...base,
      enabled:Number(row.enabled ?? 1)!==0,
      name:String(row.name ?? ("VIP "+level)),
      upgrade:Number.isFinite(upgrade)&&upgrade>=0?upgrade:base.upgrade,
      maintain:Number.isFinite(maintain)&&maintain>=0?maintain:base.maintain,
      days:Number.isSafeInteger(days)&&days>=1&&days<=3650?days:base.days,
      entry_id:String(data.entry_id ?? ""),
      frame_id:String(data.frame_id ?? ""),
    };
  }catch(error){
    if(String(error?.message ?? error).includes("no such table")){
      return {...base,enabled:true,name:"VIP "+level};
    }
    throw error;
  }
}

export async function ensureVipSchema(db){
  await db.prepare("CREATE TABLE IF NOT EXISTS user_vip (user_id TEXT PRIMARY KEY, level INTEGER NOT NULL DEFAULT 0, exp_balance REAL NOT NULL DEFAULT 0, total_received_coins INTEGER NOT NULL DEFAULT 0, active_until INTEGER, custom_id TEXT UNIQUE, last_id_change_at INTEGER, id_change_level INTEGER NOT NULL DEFAULT 0, preferences_json TEXT NOT NULL DEFAULT '{}', free_say_hi_used INTEGER NOT NULL DEFAULT 0, free_say_hi_cycle TEXT NOT NULL DEFAULT '', exp_rate_version INTEGER NOT NULL DEFAULT 3, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)").run();
  try {
    await db.prepare("SELECT custom_id_expires_at FROM user_vip LIMIT 1").first();
  } catch (error) {
    if (!/no such column/i.test(String(error?.message ?? error))) throw error;
    await db.prepare("ALTER TABLE user_vip ADD COLUMN custom_id_expires_at INTEGER").run();
  }
  try {
    await db.prepare("SELECT exp_rate_version FROM user_vip LIMIT 1").first();
  } catch (error) {
    if (!/no such column/i.test(String(error?.message ?? error))) throw error;
    await db.prepare("ALTER TABLE user_vip ADD COLUMN exp_rate_version INTEGER NOT NULL DEFAULT 0").run();
  }
  await db.prepare("UPDATE user_vip SET exp_balance=CAST(exp_balance / 400 AS INTEGER), exp_rate_version=1 WHERE exp_rate_version=0").run();
  // EXP rate version 3 (Vinay, 2026-11-18): EXP is now 150 EXP per $1
  // (150 EXP per 8,000,000 coins), replacing the 1.5 EXP per $1 rate of
  // version 2 — a 100x rescale of the whole ladder (VIP1 4.5 -> 450 EXP,
  // VIP18 15,000 -> 1,500,000 EXP). Two migration paths, both exact:
  // - v1 (1 EXP per 400 coins) -> v3: old upgrade / new upgrade is
  //   60,000 / 450 = 400/3 for every level, so exp_balance x 3 / 400
  //   preserves progress toward the next level (e.g. VIP1: 60,000 old
  //   EXP = 450 new EXP). Also covers v0 (1 EXP per coin) via the v0->v1
  //   step above (e.g. 80,000 v0 EXP = 200 v1 EXP = 1.5 v3 EXP, which is
  //   80,000 coins = $0.01 x 150).
  // - v2 (1.5 EXP per $1, PR #128) -> v3: x100 exactly (4.5 -> 450).
  // Without rescaling, existing balances would instantly max at VIP18
  // (old balances are ~100x the v2 scale and ~13,333x the v1 scale).
  // (SQLite columns accept REAL values regardless of the declared
  // INTEGER type on old tables.)
  await db.prepare("UPDATE user_vip SET exp_balance=exp_balance*3.0/400.0, exp_rate_version=3 WHERE exp_rate_version=1").run();
  await db.prepare("UPDATE user_vip SET exp_balance=exp_balance*100.0, exp_rate_version=3 WHERE exp_rate_version=2").run();
  await db.prepare("CREATE TABLE IF NOT EXISTS vip_events (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, kind TEXT NOT NULL, coin_amount INTEGER NOT NULL DEFAULT 0, exp_delta REAL NOT NULL DEFAULT 0, level_before INTEGER NOT NULL DEFAULT 0, level_after INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)").run();
  // Temporary VIP grants (Google Play first recharge, Vinay 2026-11-20):
  // a VIP1 grant for 10 days. Grants are SEPARATE from the EXP level —
  // they never touch user_vip.level / exp_balance / active_until (the
  // owner manual grant resets EXP to 0, so it cannot be reused here).
  // One grant per (user, source): the first-recharge grant is once per
  // user ever. The effective level is max(EXP level, active grant).
  await db.prepare("CREATE TABLE IF NOT EXISTS vip_grants (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, level INTEGER NOT NULL, granted_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, source TEXT NOT NULL, reference_id TEXT, created_at INTEGER NOT NULL, UNIQUE(user_id, source))").run();
  await db.prepare("CREATE INDEX IF NOT EXISTS idx_vip_grants_user ON vip_grants(user_id, expires_at)").run();
  // EXP award records (Wallet audit H2 + H3, 2026-11-22): one row per
  // money event that awarded EXP, keyed by the event's stable id —
  // the Coin Seller transfer_id, or the Google Play purchase token.
  // A retry / crash-resume that finds its row returns the stored
  // award instead of awarding EXP a second time (Play M2: the old
  // code awarded EXP, then persisted exp_awarded in a SEPARATE
  // update, so a crash between the two re-awarded on resume).
  await db.prepare("CREATE TABLE IF NOT EXISTS vip_exp_awards (reference_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, coins INTEGER NOT NULL, awarded_exp REAL NOT NULL, exp_boost REAL NOT NULL DEFAULT 1, level_before INTEGER NOT NULL, level_after INTEGER NOT NULL, created_at INTEGER NOT NULL)").run();
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
  const rule=await vipRuleForDb(db,seed);
  const until=seed>0?ts+Number(rule?.days??30)*DAY_MS:null;
  await db.prepare("INSERT INTO user_vip (user_id,level,exp_balance,total_received_coins,active_until,custom_id,last_id_change_at,id_change_level,preferences_json,free_say_hi_used,free_say_hi_cycle,created_at,updated_at) VALUES (?,?,0,0,?,NULL,NULL,0,'{}',0,'',?,?) ON CONFLICT(user_id) DO NOTHING")
    .bind(userId,seed,until,ts,ts).run();
  return db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(userId).first();
}

async function settle(db,row,ts=Date.now()){
  const customExpiry=row.custom_id_expires_at==null?null:Number(row.custom_id_expires_at);
  if(row.custom_id && customExpiry!=null && customExpiry>0 && customExpiry<=ts){
    await db.prepare("UPDATE user_vip SET custom_id=NULL,custom_id_expires_at=NULL,updated_at=? WHERE user_id=?")
      .bind(ts,row.user_id).run();
    row={...row,custom_id:null,custom_id_expires_at:null};
  }
  let level=Number(row.level??0);
  let exp=Number(row.exp_balance??0);
  let until=row.active_until==null?null:Number(row.active_until);
  if(level<=0||until==null||until>ts) return row;
  const before=level;
  // Expiry review (Vinay, 2026-11-18): VIP activates on a date and
  // expires on the SAME DATE next month (30 days, 60 for VIP16-18). At
  // expiry there are only two outcomes. First, level UP if leftover EXP
  // qualifies for the next level(s) — same carry-over rule as
  // awardSellerVipExp, so a user who levelled up during the period by
  // buying coins keeps the new level, with a fresh validity period from
  // today. Otherwise the level DROPS BY EXACTLY 1 — there is NO maintain
  // in place; the only way to avoid dropping is to level up by buying
  // coins. The drop consumes the period's banked EXP (exp set to 0):
  // keeping it would let the same EXP re-promote the user at the next
  // expiry without any new purchase (a 5→4→5 yo-yo), so progress toward
  // the next level resets with the drop.
  let promoted=false;
  while(level<18){
    const next=await vipRuleForDb(db,level+1);
    if(!next||next.enabled===false||exp<next.upgrade) break;
    exp-=next.upgrade;
    level+=1;
    promoted=true;
  }
  if(promoted){
    const rule=await vipRuleForDb(db,level);
    until=ts+Number(rule?.days??30)*DAY_MS;
    await db.batch([
      db.prepare("UPDATE user_vip SET level=?,exp_balance=?,active_until=?,free_say_hi_used=0,free_say_hi_cycle=?,updated_at=? WHERE user_id=?").bind(level,exp,until,String(until),ts,row.user_id),
      db.prepare("UPDATE users SET vip_level=?,updated_at=? WHERE id=?").bind(level,ts,row.user_id),
    ]);
    await logEvent(db,row.user_id,"expire_promote",0,0,before,level,ts);
    return db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(row.user_id).first();
  }
  level=Math.max(0,level-1);
  const next=await vipRuleForDb(db,level);
  until=level>0?ts+Number(next?.days??30)*DAY_MS:null;
  await db.batch([
    db.prepare("UPDATE user_vip SET level=?,exp_balance=0,active_until=?,free_say_hi_used=0,free_say_hi_cycle=?,updated_at=? WHERE user_id=?").bind(level,until,String(until??""),ts,row.user_id),
    db.prepare("UPDATE users SET vip_level=?,updated_at=? WHERE id=?").bind(level,ts,row.user_id),
  ]);
  await logEvent(db,row.user_id,"expire_drop",0,0,before,level,ts);
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
    custom_id_expires_at:row.custom_id_expires_at==null?null:Number(row.custom_id_expires_at),
    preferences:parsed(row.preferences_json),
    free_say_hi_remaining:Math.max(0,4-Number(row.free_say_hi_used??0)),
    free_say_hi_max_words:30,
    ...vipCapabilities(level,active),
  };
}

export async function getVipStatus(db,userId,ts=Date.now()){
  let row=await ensureRow(db,userId,ts);
  row=await settle(db,row,ts);
  // Temporary grants (Google Play first recharge): the effective level is
  // max(EXP level, active grant). The users.vip_level mirror must track
  // the EFFECTIVE level, not just the EXP level — enforcement paths read
  // getVipStatus, but display paths read the mirror directly. Sync it
  // here (up on grant, back down when the grant expires) so it can never
  // stay stale in either direction.
  const grant=await activeVipGrant(db,userId,ts);
  const expLevel=Math.max(0,Math.min(18,Number(row.level??0)));
  const grantLevel=grant?Math.max(0,Math.min(18,Number(grant.level??0))):0;
  const effectiveLevel=Math.max(expLevel,grantLevel);
  const mirror=await db.prepare("SELECT vip_level FROM users WHERE id=?").bind(userId).first();
  if(mirror&&Number(mirror.vip_level??0)!==effectiveLevel){
    await db.prepare("UPDATE users SET vip_level=?,updated_at=? WHERE id=?").bind(effectiveLevel,ts,userId).run();
  }
  if(!grant||grantLevel<=expLevel) return payload(row,ts);
  return {
    ...payload({...row,level:grantLevel,active_until:grant.expires_at},ts),
    grant_level:grantLevel,
    grant_expires_at:Number(grant.expires_at),
    grant_source:String(grant.source??""),
  };
}

// Highest active temporary VIP grant for a user, or null. Grants never
// touch the EXP row; they only lift the effective level while unexpired.
export async function activeVipGrant(db,userId,ts=Date.now()){
  try{
    return await db.prepare(
      "SELECT * FROM vip_grants WHERE user_id=? AND expires_at>? ORDER BY level DESC, expires_at DESC LIMIT 1"
    ).bind(userId,ts).first();
  }catch(error){
    if(String(error?.message ?? error).includes("no such table")) return null;
    throw error;
  }
}

// Welcome pack (Vinay, 2026-11-24): every NEW user gets, once, at
// signup — 500,000 coins (the starting balance ensureUser already
// credits) + VIP1 free for 15 days. The trial is a temporary grant
// (same mechanism as the Play first-recharge grant): it never touches
// EXP, so it earns no EXP and never triggers the first-recharge
// double — those apply to PURCHASES only. UNIQUE(user_id, source)
// makes the grant once per user ever; the wallet_ledger row is
// guarded by its reference_id so a retry can never double-record it.
export const WELCOME_PACK_COINS = 500000;
export const WELCOME_PACK_VIP_LEVEL = 1;
export const WELCOME_PACK_VIP_DAYS = 15;
export const WELCOME_PACK_SOURCE = "welcome_pack";

export async function grantWelcomePack(db, userId, ts = Date.now()) {
  await ensureVipSchema(db);
  await db.prepare(`CREATE TABLE IF NOT EXISTS wallet_ledger (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    reference_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
  const user = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
  if (!user) throw new Error("user_not_found");
  const referenceId = `${WELCOME_PACK_SOURCE}:${userId}`;
  const grant = await createVipGrant(db, userId, WELCOME_PACK_VIP_LEVEL, WELCOME_PACK_VIP_DAYS, WELCOME_PACK_SOURCE, userId, ts);
  await db.prepare(
    "INSERT INTO wallet_ledger (id,user_id,kind,amount,balance_after,reference_id,created_at) " +
    "SELECT ?,?,?,?,u.coins,?,? FROM users u WHERE u.id=? AND NOT EXISTS (SELECT 1 FROM wallet_ledger WHERE user_id=? AND reference_id=?)"
  ).bind(crypto.randomUUID(), userId, WELCOME_PACK_SOURCE, WELCOME_PACK_COINS, referenceId, ts, userId, userId, referenceId).run();
  return { coins: WELCOME_PACK_COINS, vip_level: grant.level, vip_expires_at: grant.expires_at, source: WELCOME_PACK_SOURCE };
}

// Create a temporary VIP grant. INSERT OR IGNORE on UNIQUE(user_id,
// source) makes a re-grant a no-op (first recharge is once per user
// ever). Raises the users.vip_level mirror when the grant is higher.
export async function createVipGrant(db,userId,level,days,source,referenceId=null,ts=Date.now()){
  await ensureVipSchema(db);
  // The user_vip row MUST exist before the mirror is raised: ensureRow
  // seeds the EXP level from users.vip_level (the mirror), so creating
  // the row after the raise would bake the GRANT level into the EXP
  // row for 30 days — the trial would outlive the grant and hide its
  // source. (The Play flow never hit this because awardSellerVipExp
  // creates the row first; the welcome pack has no EXP award, so the
  // grant itself must create it.)
  await ensureRow(db,userId,ts);
  const grantLevel=Math.max(0,Math.min(18,Number(level??0)));
  const expiresAt=ts+Math.max(1,Number(days??0))*DAY_MS;
  await db.prepare(
    "INSERT OR IGNORE INTO vip_grants (id,user_id,level,granted_at,expires_at,source,reference_id,created_at) VALUES (?,?,?,?,?,?,?,?)"
  ).bind(crypto.randomUUID(),userId,grantLevel,ts,expiresAt,source,referenceId,ts).run();
  await db.prepare(
    "UPDATE users SET vip_level=?,updated_at=? WHERE id=? AND vip_level<?"
  ).bind(grantLevel,ts,userId,grantLevel).run();
  return {level:grantLevel,expires_at:expiresAt,source};
}

export async function awardSellerVipExp(db,userId,coinAmount,ts=Date.now(),options={}){
  const coins=Number(coinAmount??0);
  if(!Number.isSafeInteger(coins)||coins<=0) throw new Error("invalid_coin_amount");
  // Dedup key (Wallet audit H2 + H3, 2026-11-22): the Coin Seller
  // transfer_id, or the Google Play purchase token. A retry /
  // crash-resume with the same key returns the stored award instead
  // of awarding EXP a second time.
  const referenceId=String(options?.referenceId ?? "").trim() || crypto.randomUUID();
  await ensureVipSchema(db);
  const existingAward=await db.prepare(
    "SELECT reference_id,user_id,coins,awarded_exp,exp_boost,level_before,level_after,created_at FROM vip_exp_awards WHERE reference_id=?"
  ).bind(referenceId).first();
  if (existingAward) {
    const currentRow=await db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(userId).first();
    return {
      vip:payload(currentRow,ts),
      awarded_exp:Number(existingAward.awarded_exp ?? 0),
      multiplier:3/160000,
      exp_boost:Number(existingAward.exp_boost ?? 1),
      level_up:Number(existingAward.level_after ?? 0)!==Number(existingAward.level_before ?? 0),
      previous_level:Number(existingAward.level_before ?? 0),
      new_level:Number(existingAward.level_after ?? 0),
      duplicate:true,
    };
  }
  // Optimistic locking (H3): the old code read the row, computed the
  // new level / exp / total in JS, then wrote them back with absolute
  // SETs — so two concurrent awards overwrote each other and lost
  // EXP. The UPDATE is now a compare-and-swap on the pre-read
  // (level, exp_balance) and the balances move relatively
  // (exp_balance=exp_balance+delta, total_received_coins=+coins), so
  // a concurrent award either retries (CAS miss) or composes
  // correctly. The award record is written in the SAME batch, gated
  // on the CAS having changed a row, so a crashed / retried award
  // can never be applied without its record.
  const multiplier=3/160000;
  for (let attempt=0; attempt<3; attempt+=1) {
    let row=await ensureRow(db,userId,ts);
    row=await settle(db,row,ts);
    let level=Number(row.level??0);
    const expBefore=Number(row.exp_balance??0);
    let exp=expBefore;
    const until0=row.active_until==null?null:Number(row.active_until);
    let until=until0;
    // Purchase-only EXP (Vinay, 2026-11-18): 150 EXP per $1 of coins bought
    // from a Coin Seller ($1 = 8,000,000 coins), i.e. 150 EXP per 8,000,000
    // coins received. Computed as coins*3/160,000 so the numerator stays
    // an exact integer; EXP can still be fractional for odd coin amounts
    // (e.g. 1,000,000 coins = 18.75 EXP), so no flooring — fractions
    // accumulate in exp_balance. Spending coins on gifts never calls this
    // function, so it earns no EXP.
    // EXP BOOST (Vinay, 2026-11-19): the awarded EXP is multiplied by
    // the user's VIP level boost at purchase time (pre-award level):
    // VIP1-4 1.1x, VIP5-10 1.2x, VIP11-15 1.4x, VIP16-18 1.5x, VIP0 1.0x.
    // The base rate (150 per $1), the thresholds and the expiry/drop
    // rules are unchanged — only the awarded amount grows.
    const expBoost=expBoostForLevel(level);
    const awarded=(coins*3)/160000*expBoost;
    const before=level;
    exp+=awarded;
    let thresholdsCrossed=0;
    while(level<18){
      const next=await vipRuleForDb(db,level+1);
      if(!next||next.enabled===false||exp<next.upgrade) break;
      // Excess EXP carries toward the next tier, so one large award can
      // level up more than once (the old code reset exp to 0 and broke
      // after a single level, discarding the excess).
      exp-=next.upgrade;
      thresholdsCrossed+=next.upgrade;
      level+=1;
      until=ts+next.days*DAY_MS;
    }
    const changed=level!==before;
    const expDelta=awarded-thresholdsCrossed;
    // The users.vip_level mirror tracks the EFFECTIVE level: if a temporary
    // grant (e.g. Play first recharge VIP1) is active and higher than the
    // EXP level, the mirror must not drop below it.
    const grant=await activeVipGrant(db,userId,ts);
    const mirrorLevel=Math.max(level,grant?Math.max(0,Math.min(18,Number(grant.level??0))):0);
    let batchResults;
    try {
      batchResults=await db.batch([
        db.prepare("UPDATE user_vip SET level=?,exp_balance=exp_balance+?,total_received_coins=total_received_coins+?,active_until=?,free_say_hi_used=CASE WHEN ? THEN 0 ELSE free_say_hi_used END,free_say_hi_cycle=CASE WHEN ? THEN ? ELSE free_say_hi_cycle END,updated_at=? WHERE user_id=? AND level=? AND exp_balance=?")
          .bind(level,expDelta,coins,until,changed?1:0,changed?1:0,String(until??""),ts,userId,before,expBefore),
        db.prepare("INSERT INTO vip_exp_awards(reference_id,user_id,coins,awarded_exp,exp_boost,level_before,level_after,created_at) SELECT ?,?,?,?,?,?,?,? WHERE changes()=1")
          .bind(referenceId,userId,coins,awarded,expBoost,before,level,ts),
        db.prepare("UPDATE users SET vip_level=?,updated_at=? WHERE id=? AND EXISTS(SELECT 1 FROM vip_exp_awards WHERE reference_id=?)").bind(mirrorLevel,ts,userId,referenceId),
        db.prepare("INSERT INTO vip_events (id,user_id,kind,coin_amount,exp_delta,level_before,level_after,created_at) SELECT ?,?,?,?,?,?,?,? WHERE EXISTS(SELECT 1 FROM vip_exp_awards WHERE reference_id=?)")
          .bind(crypto.randomUUID(),userId,"coin_seller_received",coins,awarded,before,level,ts,referenceId),
      ]);
    } catch (error) {
      // The award record already exists (a concurrent call for the
      // same reference won the race): return the stored award.
      const raced=await db.prepare(
        "SELECT reference_id,user_id,coins,awarded_exp,exp_boost,level_before,level_after,created_at FROM vip_exp_awards WHERE reference_id=?"
      ).bind(referenceId).first();
      if (raced) {
        const currentRow=await db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(userId).first();
        return {
          vip:payload(currentRow,ts),
          awarded_exp:Number(raced.awarded_exp ?? 0),
          multiplier,
          exp_boost:Number(raced.exp_boost ?? 1),
          level_up:Number(raced.level_after ?? 0)!==Number(raced.level_before ?? 0),
          previous_level:Number(raced.level_before ?? 0),
          new_level:Number(raced.level_after ?? 0),
          duplicate:true,
        };
      }
      throw error;
    }
    if (Number(batchResults?.[0]?.meta?.changes ?? 0) !== 1) {
      // CAS miss: another award changed the row first. Re-read and
      // recompute (the award record was not written — the INSERT is
      // gated on the CAS — so the retry is safe).
      continue;
    }
    const updated=await db.prepare("SELECT * FROM user_vip WHERE user_id=?").bind(userId).first();
    return {vip:payload(updated,ts),awarded_exp:awarded,multiplier,exp_boost:expBoost,level_up:changed,previous_level:before,new_level:level};
  }
  throw new Error("vip_exp_award_conflict");
}

export async function readVipRow(db,userId,ts=Date.now()){
  let row=await ensureRow(db,userId,ts);
  return settle(db,row,ts);
}

export function vipPayload(row,ts=Date.now()){return payload(row,ts);}
export async function logVipEvent(db,...args){return logEvent(db,...args);}
