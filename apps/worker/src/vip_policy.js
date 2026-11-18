// VIP EXP ladder (Vinay, 2026-11-18): levels are defined in EXP, NOT in
// $ or coins. Each level's total is the CUMULATIVE EXP to reach it and
// equals the level's $ price x 1.5 (VIP1 $3 = 4.5 EXP ... VIP18 $10,000
// = 15,000 EXP; $ prices: VIP1 3, VIP2 8, VIP3 20, VIP4 50, VIP5 150,
// VIP6 400, VIP7 900, VIP8 1,500, VIP9 2,100, VIP10 2,800, VIP11 3,400,
// VIP12 4,100, VIP13 4,700, VIP14 5,400, VIP15 6,500, VIP16 7,600,
// VIP17 8,800, VIP18 10,000).
// EXP is earned ONLY when coins are PURCHASED and transferred to the
// user's wallet (Coin Seller transfer) — 1.5 EXP per $1 spent ($1 =
// 8,000,000 coins, so 1.5 EXP per 8,000,000 coins bought). Spending
// coins on gifts earns NO EXP. See awardSellerVipExp in vip_store.js.
// `upgrade` is the incremental EXP to reach the level from the previous
// one (total minus previous total). `maintain` is kept as data only
// (same incremental EXP); the expiry review no longer has a maintain
// branch — at expiry you either promote or drop by 1 (see settle()).
// Validity: each level lasts from the day of level-up — 30 days for
// VIP1-15, 60 days for VIP16-18 (days column).
const VIP_LEVEL_ROWS = [
  [1,4.5,4.5,30],[2,12,7.5,30],
  [3,30,18,30],[4,75,45,30],
  [5,225,150,30],[6,600,375,30],
  [7,1350,750,30],[8,2250,900,30],
  [9,3150,900,30],[10,4200,1050,30],
  [11,5100,900,30],[12,6150,1050,30],
  [13,7050,900,30],[14,8100,1050,30],
  [15,9750,1650,30],[16,11400,1650,60],
  [17,13200,1800,60],[18,15000,1800,60],
];
export const VIP_LEVELS = Object.freeze(
  VIP_LEVEL_ROWS.map(([level,total,maintain,days],index,rows)=>({
    level,
    total,
    upgrade:total-(index>0?rows[index-1][1]:0),
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

