// VIP EXP ladder (Vinay, 2026-11-18): levels are defined in EXP, NOT in
// $ or coins. Each level's total is the CUMULATIVE EXP to reach it and
// equals the level's $ price x 150 (VIP1 $3 = 450 EXP ... VIP18 $10,000
// = 1,500,000 EXP; $ prices: VIP1 3, VIP2 8, VIP3 20, VIP4 50, VIP5 150,
// VIP6 400, VIP7 900, VIP8 1,500, VIP9 2,100, VIP10 2,800, VIP11 3,400,
// VIP12 4,100, VIP13 4,700, VIP14 5,400, VIP15 6,500, VIP16 7,600,
// VIP17 8,800, VIP18 10,000).
// EXP is earned ONLY when coins are PURCHASED and transferred to the
// user's wallet (Coin Seller transfer) — 150 EXP per $1 spent ($1 =
// 8,000,000 coins, so 150 EXP per 8,000,000 coins bought). Spending
// coins on gifts earns NO EXP. See awardSellerVipExp in vip_store.js.
// `upgrade` is the incremental EXP to reach the level from the previous
// one (total minus previous total). `maintain` is kept as data only
// (same incremental EXP); the expiry review no longer has a maintain
// branch — at expiry you either promote or drop by 1 (see settle()).
// Validity: each level lasts from the day of level-up — 30 days for
// VIP1-15, 60 days for VIP16-18 (days column).
const VIP_LEVEL_ROWS = [
  [1,450,450,30],[2,1200,750,30],
  [3,3000,1800,30],[4,7500,4500,30],
  [5,22500,15000,30],[6,60000,37500,30],
  [7,135000,75000,30],[8,225000,90000,30],
  [9,315000,90000,30],[10,420000,105000,30],
  [11,510000,90000,30],[12,615000,105000,30],
  [13,705000,90000,30],[14,810000,105000,30],
  [15,975000,165000,30],[16,1140000,165000,60],
  [17,1320000,180000,60],[18,1500000,180000,60],
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

// VIP EXP boost (Vinay, 2026-11-19): VIPs earn extra EXP on coin
// purchases — the boost grows with the level. VIP0 (no VIP) gets no
// boost. The base rate stays 150 EXP per $1 (see awardSellerVipExp);
// the boost multiplies the awarded EXP only. Thresholds, the base
// rate and the expiry/drop rules are unchanged.
export function expBoostForLevel(level){
  const vipLevel = Math.max(0, Math.min(18, Number(level) || 0));
  if (vipLevel >= 16) return 1.5;
  if (vipLevel >= 11) return 1.4;
  if (vipLevel >= 5) return 1.2;
  if (vipLevel >= 1) return 1.1;
  return 1.0;
}

// Coins bonus on purchase (Vinay, 2026-11-19): VIPs get extra coins
// credited on every coin purchase (Coin Seller transfer) — free coins
// on top of the purchased amount. VIP0-4 get no bonus. The bonus is a
// fraction of the PURCHASED coins only; it is not itself eligible for
// EXP (EXP is 150 per $1 spent, bonus coins are free).
export function coinsBonusForLevel(level){
  const vipLevel = Math.max(0, Math.min(18, Number(level) || 0));
  if (vipLevel >= 16) return 0.20;
  if (vipLevel >= 11) return 0.10;
  if (vipLevel >= 5) return 0.05;
  return 0;
}

/// Extra coins credited on a purchase of [coinAmount] coins by a user
/// at VIP [level]. Floored to whole coins (coins are integers).
export function coinsBonusForPurchase(coinAmount, level){
  const amount = Number(coinAmount ?? 0);
  if (!Number.isSafeInteger(amount) || amount <= 0) return 0;
  return Math.floor(amount * coinsBonusForLevel(level));
}

// Gift discount (Vinay, 2026-11-19): VIPs pay less for every gift
// they send — the discount applies to the gift's coin cost at send
// time. VIP0-7 get no discount. The gift catalog prices themselves
// are unchanged; only the amount debited at send is reduced.
export function giftDiscountForVipLevel(level){
  const vipLevel = Math.max(0, Math.min(18, Number(level) || 0));
  if (vipLevel >= 18) return 0.30;
  if (vipLevel >= 14) return 0.20;
  if (vipLevel >= 8) return 0.10;
  return 0;
}

/// Coin cost actually charged for a gift listed at [priceCoins] when
/// the sender is at VIP [level]. Never below 1 coin (a gift is shown
/// with a minimum price of one coin, and the send endpoint must debit
/// that same authoritative amount).
export function applyGiftDiscount(priceCoins, level){
  const price = Number(priceCoins ?? 0);
  if (!Number.isSafeInteger(price) || price <= 0) return 1;
  return Math.max(1, Math.floor(price * (1 - giftDiscountForVipLevel(level))));
}

export function vipCapabilities(level, active){
  return {
    exp_multiplier: active ? expBoostForLevel(level) : 1,
    coins_bonus_pct: active ? coinsBonusForLevel(level) : 0,
    gift_discount_pct: active ? giftDiscountForVipLevel(level) : 0,
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
    // Capped at 45 days (Vinay, 2026-11-22: "Cap kar de 45 din per") —
    // the VIP message-history promise never exceeds the 45-day server
    // backup window. VIP8+ gets 45 days, VIP5-7 get 30 days.
    message_retention_days: active ? (level >= 8 ? 45 : level >= 5 ? 30 : 0) : 0,
    show_id_style_level: !active || level < 5 ? 0 : Math.min(level,14),
    nickname_light_enabled: active && level >= 8 && level <= 17,
    entrance_vehicle_tier: active && level >= 5 ? Math.max(1,level-4) : 0,
    validity_days: level >= 16 ? 60 : 30,
  };
}

