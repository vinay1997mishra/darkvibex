export const VIP_LEVELS = Object.freeze([
  [1,50000,50000,30000,30],[2,100000,50000,30000,30],
  [3,300000,100000,90000,30],[4,1000000,800000,500000,30],
  [5,3000000,2000000,1300000,30],[6,7000000,4000000,2600000,30],
  [7,14000000,7000000,4500000,30],[8,26000000,12000000,7800000,30],
  [9,42000000,16000000,11000000,30],[10,62000000,20000000,14000000,30],
  [11,102000000,40000000,28000000,30],[12,220000000,118000000,83000000,30],
  [13,430000000,210000000,150000000,30],[14,820000000,390000000,310000000,30],
  [15,1820000000,1000000000,700000000,30],[16,3820000000,2000000000,1400000000,30],
  [17,7382000000,3500000000,3000000000,30],[18,11882000000,4500000000,4000000000,45],
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
    exp_multiplier: active && level >= 17 ? 1.5 : 1,
    friend_bonus: active ? (level >= 13 ? 1500 : level >= 9 ? 700 : level >= 4 ? 300 : 0) : 0,
    room_seat_limit: active ? (level >= 10 ? 30 : level >= 7 ? 20 : 12) : 12,
    room_background_enabled: active && level >= 3,
    picture_welcome_enabled: active && level >= 5,
    room_images_enabled: active && level >= 10,
    seat_protection_enabled: active && level >= 13,
    kick_protection_enabled: active && level >= 14,
    message_retention_days: active ? (level >= 12 ? 180 : level >= 8 ? 90 : level >= 5 ? 30 : 0) : 0,
    show_id_style_level: !active || level < 5 ? 0 : Math.min(level,14),
    nickname_light_enabled: active && level >= 8 && level <= 17,
    entrance_vehicle_tier: active && level >= 8 ? Math.max(1,level-7) : 0,
    validity_days: level >= 18 ? 45 : 30,
  };
}
