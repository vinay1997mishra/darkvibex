import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import {
  expBoostForLevel,
  coinsBonusForLevel,
  coinsBonusForPurchase,
  giftDiscountForVipLevel,
  applyGiftDiscount,
  vipCapabilities,
} from "../src/vip_policy.js";
import {
  VIP_BADGE_CATALOG,
  vipBadgeForVipLevel,
  vipBadgeById,
  vipBadgeVisualForVipLevel,
  vipBadgeUrlForVipLevel,
  vipBadgeVariantUrlForVipLevel,
  allVipBadgeUrls,
  R2_PUBLIC_BASE_URL,
} from "../src/vip_badge_catalog.js";

class D1Mock {
  constructor(database) { this.database = database; }
  prepare(sql) {
    const database = this.database;
    const makeStatement = (values = []) => ({
      bind(...bound) { return makeStatement(bound); },
      async run() { const result = database.prepare(sql).run(...values); return { meta: { changes: Number(result.changes) } }; },
      async first() { return database.prepare(sql).get(...values) ?? null; },
      async all() { return { results: database.prepare(sql).all(...values) }; },
    });
    return makeStatement();
  }
  async batch(statements) {
    this.database.exec("BEGIN");
    try {
      const results = [];
      for (const statement of statements) results.push(await statement.run());
      this.database.exec("COMMIT");
      return results;
    } catch (error) {
      this.database.exec("ROLLBACK");
      throw error;
    }
  }
}

const base64url = (bytes) => Buffer.from(bytes).toString("base64url");
async function sessionToken(userId, secret) {
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: userId, exp: Math.floor(Date.now() / 1000) + 3600 })}`;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

const approx = (actual, expected, message) => {
  assert.ok(Math.abs(actual - expected) < 1e-9, `${message ?? "EXP mismatch"}: got ${actual}, expected ${expected}`);
};

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "vip-boosts-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  for (const [id, name] of [["seller", "Seller"], ["receiver", "Receiver"], ["merchant", "Merchant"]]) {
    // Guest login is deleted permanently (Vinay 2026-11-20): test users are
    // created directly in SQLite instead of through the removed endpoint.
    sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(id, name, Date.now(), Date.now());
  }
  sqlite.prepare("UPDATE users SET role='coin_seller',coins=1000000000 WHERE id='seller'").run();
  sqlite.prepare("UPDATE users SET role='merchant',coins=1000000000 WHERE id='merchant'").run();
  for (const [userId, walletType, credential] of [["seller", "coin_seller", "1234"], ["merchant", "merchant", "43214321"]]) {
    const credentialResponse = await request("/api/wallet/role-credential", {
      method: "POST",
      userId,
      body: { user_id: userId, wallet_type: walletType, credential },
    });
    assert.equal(credentialResponse.status, 200);
    sqlite.prepare(
      "UPDATE role_wallets SET balance_coins=1000000000 WHERE user_id=? AND wallet_type=?"
    ).run(userId, walletType);
  }
  // Give a user an ACTIVE VIP level: users.vip_level seeds the user_vip
  // row when /api/vip/:id is read (active_until = now + validity days).
  // ensureRow only seeds on INSERT, so changing the level twice needs
  // the existing row deleted first.
  const setVipLevel = async (userId, level) => {
    await request(`/api/vip/${userId}`, { userId });
    sqlite.prepare("DELETE FROM user_vip WHERE user_id=?").run(userId);
    sqlite.prepare("UPDATE users SET vip_level=? WHERE id=?").run(level, userId);
    const response = await request(`/api/vip/${userId}`, { userId });
    assert.equal(response.status, 200);
    assert.equal(response.body.vip.active, level > 0);
    assert.equal(response.body.vip.level, level);
  };
  return { sqlite, request, setVipLevel };
}

// ---------------------------------------------------------------- EXP boost

test("EXP boost tiers are 1.0x / 1.1x / 1.2x / 1.4x / 1.5x", () => {
  assert.equal(expBoostForLevel(0), 1.0);
  assert.equal(expBoostForLevel(1), 1.1);
  assert.equal(expBoostForLevel(4), 1.1);
  assert.equal(expBoostForLevel(5), 1.2);
  assert.equal(expBoostForLevel(10), 1.2);
  assert.equal(expBoostForLevel(11), 1.4);
  assert.equal(expBoostForLevel(15), 1.4);
  assert.equal(expBoostForLevel(16), 1.5);
  assert.equal(expBoostForLevel(18), 1.5);
  assert.equal(expBoostForLevel(19), 1.5);
  assert.equal(expBoostForLevel(-1), 1.0);
  assert.equal(expBoostForLevel(null), 1.0);
});

// ---------------------------------------------------------------- Coins bonus

test("coins bonus tiers are 0% / 5% / 10% / 20% and floor to whole coins", () => {
  assert.equal(coinsBonusForLevel(0), 0);
  assert.equal(coinsBonusForLevel(4), 0);
  assert.equal(coinsBonusForLevel(5), 0.05);
  assert.equal(coinsBonusForLevel(10), 0.05);
  assert.equal(coinsBonusForLevel(11), 0.10);
  assert.equal(coinsBonusForLevel(15), 0.10);
  assert.equal(coinsBonusForLevel(16), 0.20);
  assert.equal(coinsBonusForLevel(18), 0.20);
  assert.equal(coinsBonusForLevel(19), 0.20);
  assert.equal(coinsBonusForPurchase(8000000, 5), 400000);
  assert.equal(coinsBonusForPurchase(8000000, 11), 800000);
  assert.equal(coinsBonusForPurchase(8000000, 16), 1600000);
  assert.equal(coinsBonusForPurchase(8000000, 0), 0);
  // Floored: 5% of 101 coins is 5.05 -> 5 coins.
  assert.equal(coinsBonusForPurchase(101, 5), 5);
  assert.equal(coinsBonusForPurchase(0, 18), 0);
});

// ---------------------------------------------------------------- Gift discount

test("gift discount tiers are 0% / 10% / 20% / 30% and never below 1 coin", () => {
  assert.equal(giftDiscountForVipLevel(0), 0);
  assert.equal(giftDiscountForVipLevel(7), 0);
  assert.equal(giftDiscountForVipLevel(8), 0.10);
  assert.equal(giftDiscountForVipLevel(13), 0.10);
  assert.equal(giftDiscountForVipLevel(14), 0.20);
  assert.equal(giftDiscountForVipLevel(17), 0.20);
  assert.equal(giftDiscountForVipLevel(18), 0.30);
  assert.equal(giftDiscountForVipLevel(19), 0.30);
  assert.equal(applyGiftDiscount(100, 8), 90);
  assert.equal(applyGiftDiscount(1000, 14), 800);
  assert.equal(applyGiftDiscount(1000, 18), 700);
  assert.equal(applyGiftDiscount(100, 0), 100);
  assert.equal(applyGiftDiscount(1, 18), 1);
  assert.equal(applyGiftDiscount(0, 18), 1);
});

test("vipCapabilities exposes the boost, coins bonus and gift discount", () => {
  const vip5 = vipCapabilities(5, true);
  assert.equal(vip5.exp_multiplier, 1.2);
  assert.equal(vip5.coins_bonus_pct, 0.05);
  assert.equal(vip5.gift_discount_pct, 0);
  const vip8 = vipCapabilities(8, true);
  assert.equal(vip8.exp_multiplier, 1.2);
  assert.equal(vip8.coins_bonus_pct, 0.05);
  assert.equal(vip8.gift_discount_pct, 0.10);
  const vip14 = vipCapabilities(14, true);
  assert.equal(vip14.exp_multiplier, 1.4);
  assert.equal(vip14.coins_bonus_pct, 0.10);
  assert.equal(vip14.gift_discount_pct, 0.20);
  const vip18 = vipCapabilities(18, true);
  assert.equal(vip18.exp_multiplier, 1.5);
  assert.equal(vip18.coins_bonus_pct, 0.20);
  assert.equal(vip18.gift_discount_pct, 0.30);
  // Inactive VIPs get no boost/bonus/discount even at a high level.
  const expired = vipCapabilities(18, false);
  assert.equal(expired.exp_multiplier, 1);
  assert.equal(expired.coins_bonus_pct, 0);
  assert.equal(expired.gift_discount_pct, 0);
});

// ---------------------------------------------------------------- Badge catalog

test("VIP badge catalog covers all 18 levels with play-once videos", () => {
  assert.equal(VIP_BADGE_CATALOG.length, 18);
  const animals = ["cat", "swan", "dolphin", "fox", "deer", "wolf", "eagle", "panther", "cobra", "lion", "tiger", "mammoth", "gorilla", "bear", "kraken", "leviathan", "phoenix", "dragon"];
  for (let level = 1; level <= 18; level++) {
    const entry = vipBadgeForVipLevel(level);
    assert.ok(entry, `VIP${level} badge exists`);
    assert.equal(entry.id, `vip-badge-${level}`);
    assert.equal(entry.kind, "vip_badge");
    assert.equal(entry.animal, animals[level - 1]);
    assert.equal(entry.video_key, `vip-badges/vip${level}-${animals[level - 1]}.mp4`);
    assert.equal(entry.min_vip_level, level);
  }
  assert.equal(vipBadgeForVipLevel(0), null);
  assert.equal(vipBadgeForVipLevel(19), null);
  assert.equal(vipBadgeById("vip-badge-6").animal, "wolf");
  assert.equal(vipBadgeById("vip-badge-99"), null);

  // Durations: Vinay's portrait videos are 5.184 s, Ghost's landscape
  // videos are 10 s, VIP17 gold is 10.144 s.
  assert.equal(vipBadgeVisualForVipLevel(5).animation_ms, 5184);
  assert.equal(vipBadgeVisualForVipLevel(1).animation_ms, 10000);
  assert.equal(vipBadgeVisualForVipLevel(17).animation_ms, 10144);
  for (let level = 1; level <= 18; level++) {
    const visual = vipBadgeVisualForVipLevel(level);
    assert.equal(visual.media_type, "video");
    assert.equal(visual.animation_type, "play_once");
    assert.equal(visual.asset_key, "");
    assert.equal(visual.glb_key, "");
  }
  assert.equal(vipBadgeVisualForVipLevel(0), null);
  assert.equal(vipBadgeVisualForVipLevel(19), null);

  // VIP17 gold is canonical; the purple phoenix is a separate variant.
  const vip17 = vipBadgeVisualForVipLevel(17);
  assert.equal(vip17.video_key, "vip-badges/vip17-phoenix.mp4");
  assert.equal(vip17.variant_video_key, "vip-badges/vip17-phoenix-purple.mp4");
  assert.equal(vip17.variant_animation_ms, 10000);
  for (let level = 1; level <= 18; level++) {
    if (level === 17) continue;
    assert.equal("variant_video_key" in vipBadgeVisualForVipLevel(level), false);
  }
  assert.equal(vipBadgeVariantUrlForVipLevel(17), `${R2_PUBLIC_BASE_URL}/vip-badges/vip17-phoenix-purple.mp4`);
  assert.equal(vipBadgeVariantUrlForVipLevel(6), null);
  assert.equal(vipBadgeVariantUrlForVipLevel(18), null);

  assert.equal(vipBadgeUrlForVipLevel(6), `${R2_PUBLIC_BASE_URL}/vip-badges/vip6-wolf.mp4`);
  assert.equal(vipBadgeUrlForVipLevel(0), null);
  assert.equal(allVipBadgeUrls().length, 18);
  assert.equal(allVipBadgeUrls()[17], `${R2_PUBLIC_BASE_URL}/vip-badges/vip18-dragon.mp4`);
});

// ---------------------------------------------------------------- Endpoints

test("VIP status endpoint exposes the badge video in vip_visuals", async () => {
  const { sqlite, request, setVipLevel } = await fixture();
  await setVipLevel("receiver", 6);
  const response = await request("/api/vip/receiver", { userId: "receiver" });
  assert.equal(response.status, 200);
  const badge = response.body.vip.visuals.vip_badge;
  assert.equal(badge.id, "vip-badge-6");
  assert.equal(badge.kind, "vip_badge");
  assert.equal(badge.name, "Wolf Badge");
  assert.equal(badge.video_key, "vip-badges/vip6-wolf.mp4");
  assert.equal(badge.media_type, "video");
  assert.equal(badge.animation_type, "play_once");
  assert.equal(badge.animation_ms, 5184);

  // VIP17 carries the purple variant alongside the canonical gold.
  await setVipLevel("receiver", 17);
  const vip17 = await request("/api/vip/receiver", { userId: "receiver" });
  assert.equal(vip17.body.vip.visuals.vip_badge.video_key, "vip-badges/vip17-phoenix.mp4");
  assert.equal(vip17.body.vip.visuals.vip_badge.variant_video_key, "vip-badges/vip17-phoenix-purple.mp4");
  sqlite.close();
});

test("Coin Seller purchase at VIP5 earns 1.2x EXP and a 5% coins bonus", async () => {
  const { sqlite, request, setVipLevel } = await fixture();
  await setVipLevel("receiver", 5);
  const receiverCoinsBefore = sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins;
  const result = await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins: 8000000, pin: "1234" },
  });
  assert.equal(result.status, 200);
  // 5% bonus: 8,000,000 purchased + 400,000 free coins.
  assert.equal(result.body.coins_bonus, 400000);
  assert.equal(result.body.receiver_coin_balance, receiverCoinsBefore + 8400000);
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins,
    receiverCoinsBefore + 8400000,
  );
  // The seller is debited only the purchased amount.
  assert.equal(
    sqlite.prepare("SELECT balance_coins FROM role_wallets WHERE user_id='seller' AND wallet_type='coin_seller'").get().balance_coins,
    1000000000 - 8000000,
  );
  // The bonus is a separate ledger entry and is NOT counted in
  // total_received_coins (EXP is based on purchased coins only).
  assert.equal(
    sqlite.prepare("SELECT amount FROM wallet_ledger WHERE user_id='receiver' AND kind='vip_coins_bonus'").get().amount,
    400000,
  );
  assert.equal(
    sqlite.prepare("SELECT total_received_coins FROM user_vip WHERE user_id='receiver'").get().total_received_coins,
    8000000,
  );
  // EXP: 150 per $1 at VIP5 gets the 1.2x boost = 180 EXP.
  approx(result.body.vip_award.awarded_exp, 180, "awarded EXP with 1.2x boost");
  assert.equal(result.body.vip_award.exp_boost, 1.2);
  assert.equal(result.body.vip_award.multiplier, 3 / 160000);
  const vip = sqlite.prepare("SELECT level, exp_balance FROM user_vip WHERE user_id='receiver'").get();
  assert.equal(vip.level, 5);
  approx(vip.exp_balance, 180, "EXP balance after boosted purchase");
  sqlite.close();
});

test("Coin Seller purchase at VIP0 earns no bonus and no boost", async () => {
  const { sqlite, request } = await fixture();
  const receiverCoinsBefore = sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins;
  const result = await request("/api/wallet/coin-seller-transfer", {
    method: "POST", userId: "seller",
    body: { seller_user_id: "seller", receiver_user_id: "receiver", coins: 8000000, pin: "1234" },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.coins_bonus, 0);
  assert.equal(result.body.receiver_coin_balance, receiverCoinsBefore + 8000000);
  approx(result.body.vip_award.awarded_exp, 150, "awarded EXP without boost");
  assert.equal(result.body.vip_award.exp_boost, 1.0);
  sqlite.close();
});

test("Merchant transfers earn no coins bonus even for a VIP", async () => {
  const { sqlite, request, setVipLevel } = await fixture();
  await setVipLevel("receiver", 5);
  const receiverCoinsBefore = sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins;
  const result = await request("/api/wallet/role-coins/transfer", {
    method: "POST", userId: "merchant",
    body: { user_id: "merchant", receiver_user_id: "receiver", wallet_type: "merchant", credential: "43214321", coins: 8000000 },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.coins_bonus, 0);
  assert.equal(result.body.receiver_coin_balance, receiverCoinsBefore + 8000000);
  assert.equal(result.body.vip_award, null);
  sqlite.close();
});

test("gift discount reduces the coin cost at send time (VIP8 10%, VIP18 30%)", async () => {
  const { sqlite, request, setVipLevel } = await fixture();
  // The receiver is the gift SENDER here: VIP8 with coins to spend.
  await setVipLevel("receiver", 8);
  sqlite.prepare("UPDATE users SET coins=100000 WHERE id='receiver'").run();
  // DM gifts need mutual follow (Vinay, 2026-11-21), so the receiver and
  // seller follow each other first.
  const now = Date.now();
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("receiver", "seller", now);
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("seller", "receiver", now);
  const sellerDiamondsBefore = sqlite.prepare("SELECT diamonds FROM users WHERE id='seller'").get().diamonds;
  const gift = await request("/api/gifts/send", {
    method: "POST", userId: "receiver",
    body: { sender_user_id: "receiver", receiver_user_id: "seller", gift_id: "rose" },
  });
  assert.equal(gift.status, 200);
  // Rose lists at 100 coins; VIP8 pays 10% less = 90 coins.
  assert.equal(gift.body.gift_list_price, 100);
  assert.equal(gift.body.gift_discount, 0.10);
  assert.equal(gift.body.gift_cost, 90);
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins,
    100000 - 90,
  );
  // The receiver's diamonds follow the DISCOUNTED cost (90), not the
  // list price — the gift is worth what was paid for it. (New users
  // start with 120 diamonds, so assert the delta.)
  assert.equal(
    sqlite.prepare("SELECT diamonds FROM users WHERE id='seller'").get().diamonds,
    sellerDiamondsBefore + 90,
  );

  // VIP18 pays 30% less: a Crown lists at 1,000 coins, VIP18 pays 700.
  await setVipLevel("receiver", 18);
  sqlite.prepare("UPDATE users SET coins=100000 WHERE id='receiver'").run();
  const crown = await request("/api/gifts/send", {
    method: "POST", userId: "receiver",
    body: { sender_user_id: "receiver", receiver_user_id: "seller", gift_id: "crown" },
  });
  assert.equal(crown.status, 200);
  assert.equal(crown.body.gift_list_price, 1000);
  assert.equal(crown.body.gift_discount, 0.30);
  assert.equal(crown.body.gift_cost, 700);
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='receiver'").get().coins,
    100000 - 700,
  );
  sqlite.close();
});

test("gift discount does not apply below VIP8", async () => {
  const { sqlite, request, setVipLevel } = await fixture();
  await setVipLevel("receiver", 7);
  sqlite.prepare("UPDATE users SET coins=100000 WHERE id='receiver'").run();
  // DM gifts need mutual follow (Vinay, 2026-11-21), so the receiver and
  // seller follow each other first.
  const now = Date.now();
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("receiver", "seller", now);
  sqlite.prepare("INSERT INTO user_follows(follower_id,target_id,created_at) VALUES(?,?,?)").run("seller", "receiver", now);
  const gift = await request("/api/gifts/send", {
    method: "POST", userId: "receiver",
    body: { sender_user_id: "receiver", receiver_user_id: "seller", gift_id: "rose" },
  });
  assert.equal(gift.status, 200);
  assert.equal(gift.body.gift_list_price, 100);
  assert.equal(gift.body.gift_discount, 0);
  assert.equal(gift.body.gift_cost, 100);
  sqlite.close();
});
