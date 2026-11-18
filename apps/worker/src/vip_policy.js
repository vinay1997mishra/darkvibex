// VIP pricing ladder (Vinay, 2026-11-18): $1 = 8,000,000 coins.
// Each level's total is the CUMULATIVE coins to reach it; the $ price
// is total / 8,000,000. VIP1-8 are Vinay's exact prices ($3, $8, $20,
// $50, $150, $400, $900, $1,500); VIP9-14 step $600/$700; VIP15-18
// were raised by Vinay ("vip 15 se price badha de") to $6,500 / $7,600
// / $8,800 / $10,000, so the ladder lands on VIP18 = $10,000
// (80,000,000,000 coins).
// Upgrade EXP is the incremental total / 400 (400 coins = 1 VIP EXP),
// matching the Dart client (VipPolicy.levels[].upgradeExp) — e.g. VIP1
// needs 24,000,000 / 400 = 60,000 EXP.
// Validity: each level lasts from the day of level-up — 30 days for
// VIP1-15, 60 days for VIP16-18 (days column). At expiry the level is
// re-evaluated in vip_store.js settle(): up if leftover EXP qualifies
// for the next level, maintained if EXP covers `maintain`, else down 1.
// Legacy maintenance targets keep their original values, already
// converted to EXP.
const VIP_LEVEL_ROWS = [
  [1,24000000,75,30],[2,64000000,75,30],
  [3,160000000,225,30],[4,400000000,1250,30],
  [5,1200000000,3250,30],[6,3200000000,6500,30],
  [7,7200000000,11250,30],[8,12000000000,19500,30],
  [9,16800000000,27500,30],[10,22400000000,35000,30],
  [11,27200000000,70000,30],[12,32800000000,207500,30],
  [13,37600000000,375000,30],[14,43200000000,775000,30],
  [15,52000000000,1750000,30],[16,60800000000,3500000,60],
  [17,70400000000,7500000,60],[18,80000000000,10000000,60],
];
export const VIP_LEVELS = Object.freeze(
  VIP_LEVEL_ROWS.map(([level,total,maintain,days],index,rows)=>({
    level,
    total,
    upgrade:Math.floor((total-(index>0?rows[index-1][1]:0))/400),
    maintain,
    days,
  })),
);

export const VIP_PREF_LEVEL = Object.freeze({
  hide_last_online:2,
  hide_country:8,
  disable_say_hi:8,
  hide_charm:10,
  hide_visitors:11,
  anonymous_ranking:11,
  invisible_entry:14,
  privacy_protection:15,
  anonymous_everywhere:18,
});

export function vipRule(level){
  return level >= 1 && level <= 18 ? VIP_LEVELS[level-1] : null;
}

export function vipCapabilities(level, active){
  return {
    exp_multiplier: 1,
    friend_bonus: 0,
    friend_limit: active ? null : 300,
    friends_unlimited: active,
    exclusive_gifts_enabled: active && level >= 3,
    exclusive_mic_emoticon_enabled: active && level >= 9,
    honorary_title_enabled: active && level >= 18,
    room_seat_limit: active ? (level >= 10 ? 30 : level >= 7 ? 20 : 12) : 12,
    room_background_enabled: active && level >= 3,
    picture_welcome_enabled: active && level >= 5,
    red_envelope_enabled: active && level >= 6,
    room_images_enabled: active && level >= 10,
    customer_service_enabled: active && level >= 9,
    seat_protection_enabled: active && level >= 13,
    kick_protection_enabled: active && level >= 14,
    message_retention_days: active ? (level >= 12 ? 120 : level >= 8 ? 60 : level >= 5 ? 30 : 0) : 0,
    show_id_style_level: !active || level < 5 ? 0 : Math.min(level,14),
    nickname_light_enabled: active && level >= 8 && level <= 17,
    entrance_vehicle_tier: active && level >= 5 ? Math.max(1,level-4) : 0,
    validity_days: level >= 16 ? 60 : 30,
  };
}

