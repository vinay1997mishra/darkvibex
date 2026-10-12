// Each upgrade amount is a per-level target based on the supplied USD schedule
// at 5,000,000 coins/USD and 400 coins per VIP EXP. Total coins remain cumulative.
// Legacy maintenance targets are kept at the same coin cost and converted to EXP.
export const VIP_LEVELS = Object.freeze([
  [1,35000000,87500,75,30],[2,135000000,250000,75,30],
  [3,335000000,500000,225,30],[4,735000000,1000000,1250,30],
  [5,1735000000,2500000,3250,30],[6,3235000000,3750000,6500,30],
  [7,5985000000,6875000,11250,30],[8,9485000000,8750000,19500,30],
  [9,13985000000,11250000,27500,30],[10,20235000000,15625000,35000,30],
  [11,27735000000,18750000,70000,30],[12,36735000000,22500000,207500,30],
  [13,47235000000,26250000,375000,30],[14,57735000000,26250000,775000,30],
  [15,69235000000,28750000,1750000,30],[16,80735000000,28750000,3500000,30],
  [17,92235000000,28750000,7500000,30],[18,103735000000,28750000,10000000,45],
].map(([level,total,upgrade,maintain,days])=>({level,total,upgrade,maintain,days})));

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
    friend_bonus: active ? (level >= 13 ? 1500 : level >= 9 ? 700 : level >= 4 ? 300 : 0) : 0,
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
    entrance_vehicle_tier: active && level >= 8 ? Math.max(1,level-7) : 0,
    validity_days: level >= 18 ? 45 : 30,
  };
}
