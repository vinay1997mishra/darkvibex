import { VIP_PREF_LEVEL } from "./vip_policy.js";
import { logVipEvent, readVipRow, vipPayload } from "./vip_store.js";

const parsePrefs=(value)=>{try{return JSON.parse(String(value??"{}"))||{};}catch(_){return {};}};

export async function setVipPreference(db,userId,key,enabled,ts=Date.now()){
  const required=VIP_PREF_LEVEL[String(key??"")];
  if(!required) throw new Error("invalid_vip_preference");
  const row=await readVipRow(db,userId,ts);
  const status=vipPayload(row,ts);
  if(!status.active||status.level<required) throw new Error("vip_privilege_locked");
  const prefs=parsePrefs(row.preferences_json);
  prefs[String(key)]=Boolean(enabled);
  await db.prepare("UPDATE user_vip SET preferences_json=?,updated_at=? WHERE user_id=?")
    .bind(JSON.stringify(prefs),ts,userId).run();
  return {...status,preferences:prefs};
}

export async function changeVipUniqueId(db,userId,requestedId,ts=Date.now()){
  const row=await readVipRow(db,userId,ts);
  const status=vipPayload(row,ts);
  if(!status.active||status.level<15) throw new Error("vip15_required");
  const customId=String(requestedId??"").trim();
  if(!/^[A-Za-z0-9_-]{3,20}$/.test(customId)) throw new Error("invalid_custom_id");

  const publicOwner=await db.prepare("SELECT id FROM users WHERE public_id=? AND id<>? LIMIT 1")
    .bind(customId,userId).first();
  if(publicOwner) throw new Error("custom_id_taken");
  try{
    const historicalOwner=await db.prepare(
      "SELECT user_id FROM owner_public_id_history WHERE public_id=? AND user_id<>? LIMIT 1"
    ).bind(customId,userId).first();
    if(historicalOwner) throw new Error("custom_id_taken");
  }catch(error){
    if(String(error?.message ?? error)==="custom_id_taken") throw error;
    if(!String(error?.message ?? error).includes("no such table")) throw error;
  }
  try{
    const purchaseOwner=await db.prepare(
      "SELECT buyer_user_id FROM unique_id_purchases WHERE public_id=? AND buyer_user_id<>? LIMIT 1"
    ).bind(customId,userId).first();
    if(purchaseOwner) throw new Error("custom_id_taken");
  }catch(error){
    if(String(error?.message ?? error)==="custom_id_taken") throw error;
    if(!String(error?.message ?? error).includes("no such table")) throw error;
  }

  const previousAt=Number(row.last_id_change_at??0);
  const previousLevel=Number(row.id_change_level??0);
  const nowDate=new Date(ts);
  const previousDate=previousAt>0?new Date(previousAt):null;
  const sameMonth=previousDate!=null &&
    previousDate.getUTCFullYear()===nowDate.getUTCFullYear() &&
    previousDate.getUTCMonth()===nowDate.getUTCMonth();
  const levelUpCredit=status.level>previousLevel;
  if(sameMonth&&!levelUpCredit) throw new Error("unique_id_monthly_limit");

  try{
    await db.prepare("UPDATE user_vip SET custom_id=?,last_id_change_at=?,id_change_level=?,updated_at=? WHERE user_id=?")
      .bind(customId,ts,status.level,ts,userId).run();
  }catch(error){
    if(String(error?.message??error).toLowerCase().includes("unique")) throw new Error("custom_id_taken");
    throw error;
  }
  await logVipEvent(db,userId,"unique_id_change",0,0,status.level,status.level,ts);
  return customId;
}

export async function consumeFreeSayHi(db,userId,receiverId,message,ts=Date.now()){
  const row=await readVipRow(db,userId,ts);
  const status=vipPayload(row,ts);
  if(!status.active||status.level<5) throw new Error("vip5_required");
  if(!receiverId||String(receiverId)===String(userId)) throw new Error("invalid_receiver");
  const receiver=await readVipRow(db,String(receiverId),ts);
  if(receiver&&vipPayload(receiver,ts).active&&vipPayload(receiver,ts).level>=8&&
     parsePrefs(receiver.preferences_json).disable_say_hi===true){
    throw new Error("say_hi_disabled_by_receiver");
  }
  const text=String(message??"").trim();
  const words=text?text.split(/\s+/).filter(Boolean):[];
  if(!text||words.length>30) throw new Error("say_hi_max_30_words");

  const cycle=String(status.active_until??"");
  const update=await db.prepare("UPDATE user_vip SET free_say_hi_used=CASE WHEN free_say_hi_cycle=? THEN free_say_hi_used+1 ELSE 1 END,free_say_hi_cycle=?,updated_at=? WHERE user_id=? AND (free_say_hi_cycle<>? OR free_say_hi_used<4)")
    .bind(cycle,cycle,ts,userId,cycle).run();
  if(Number(update.meta?.changes??0)!==1) throw new Error("say_hi_limit_reached");
  const updated=await db.prepare("SELECT free_say_hi_used FROM user_vip WHERE user_id=?").bind(userId).first();
  const used=Number(updated?.free_say_hi_used??1);
  const messageId=crypto.randomUUID();
  try{
    await db.prepare("INSERT INTO direct_messages (id,sender_user_id,receiver_user_id,text,created_at,read_at) VALUES (?,?,?,?,?,NULL)")
      .bind(messageId,userId,String(receiverId),text,ts).run();
  }catch(error){
    await db.prepare("UPDATE user_vip SET free_say_hi_used=MAX(0,free_say_hi_used-1),updated_at=? WHERE user_id=? AND free_say_hi_cycle=? AND free_say_hi_used=?")
      .bind(ts,userId,cycle,used).run();
    throw error;
  }
  return {used,remaining:Math.max(0,4-used),max_words:30,message_id:messageId};
}
