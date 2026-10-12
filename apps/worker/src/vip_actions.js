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
  if(!status.active||status.level<5) throw new Error("vip5_required");
  const customId=String(requestedId??"").trim();
  if(!/^[A-Za-z0-9_-]{3,20}$/.test(customId)) throw new Error("invalid_custom_id");

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

export async function consumeFreeSayHi(db,userId,message,ts=Date.now()){
  const row=await readVipRow(db,userId,ts);
  const status=vipPayload(row,ts);
  if(!status.active||status.level<5) throw new Error("vip5_required");
  const text=String(message??"").trim();
  const words=text?text.split(/\s+/).filter(Boolean):[];
  if(!text||words.length>30) throw new Error("say_hi_max_30_words");

  const cycle=String(status.active_until??"");
  let used=Number(row.free_say_hi_used??0);
  if(String(row.free_say_hi_cycle??"")!==cycle) used=0;
  if(used>=4) throw new Error("say_hi_limit_reached");
  used+=1;
  await db.prepare("UPDATE user_vip SET free_say_hi_used=?,free_say_hi_cycle=?,updated_at=? WHERE user_id=?")
    .bind(used,cycle,ts,userId).run();
  return {used,remaining:Math.max(0,4-used),max_words:30};
}
