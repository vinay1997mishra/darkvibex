// Google Play Billing coin purchases (Vinay, 2026-11-20).
//
// Flow: the app buys a one-time product with Play Billing, then calls
// POST /api/play/verify with the purchaseToken. The worker verifies the
// purchase with the Google Play Android Publisher API (service-account
// OAuth2, RS256 JWT — same shape as the FCM service-account flow in
// index.js), credits the coins + EXP, consumes the purchase, and records
// it in play_purchases (idempotent by purchase_token).
//
// First recharge (once per user, ever): DOUBLE coins + a VIP1 grant for
// 10 days. EXP (150 per $1) is earned on ALL coins credited, including
// the doubled bonus.
//
// Refunds arrive as RTDN on POST /api/webhooks/google-play (Pub/Sub
// push, OIDC bearer token verified via tokeninfo). A refund/cancel
// revokes the granted coins (never below zero) and PERMANENTLY bans the
// user ID (Vinay, 2026-11-20).
//
// India prices (Rs.110/220/550/1,100) are set in Play Console, not in code. The
// service-account JSON key lives in the Worker secret
// PLAY_SERVICE_ACCOUNT_JSON and is never committed.
//
// Only 4 packs (Vinay, 2026-11-21): Rs.110 ($1), Rs.220 ($2), Rs.550 ($5)
// and Rs.1,100 ($10). The Rs.5,500 product was removed from the packs
// list; it must also be removed/archived in Play Console (Vinay's
// side) before it stops being buyable in the store.
import { awardSellerVipExp, createVipGrant, ensureVipSchema, getVipStatus } from "./vip_store.js";
import {
  recordRechargeInviteCommission,
  reverseRechargeInviteCommission,
} from "./invite_rewards.js";

// Referral dollars (Vinay, 2026-11-23): 5% of every recharge, in
// dollars, to the inviter for 3 months from the invite bind. Best
// effort by design: a commission failure must never fail the purchase
// (the verify is idempotent on the purchase token, so a later retry
// re-attempts the commission).
async function recordInviteRechargeCommission(db, userId, token, usdCents, ts) {
  try {
    await recordRechargeInviteCommission(db, {
      inviteeUserId: userId,
      purchaseToken: token,
      usdCents,
      ts,
    });
  } catch (error) {
    console.error("DarkVibeX invite recharge commission failed", {
      userId,
      token,
      error: String(error?.message ?? error),
    });
  }
}

export const PLAY_PACKAGE_NAME = "com.darkvibex.app";

// $1 = Rs.110 (Vinay's set rate, not the market rate). usd_value is the
// $ amount the EXP rule (150 EXP per $1) is based on; the INR price is
// set per product in Play Console.
export const PLAY_PACKS = [
  { product_id: "coins_8000000", coins: 8000000, usd_value: 1 },
  { product_id: "coins_16000000", coins: 16000000, usd_value: 2 },
  { product_id: "coins_40000000", coins: 40000000, usd_value: 5 },
  { product_id: "coins_80000000", coins: 80000000, usd_value: 10 },
];

const PLAY_PACKS_BY_ID = new Map(PLAY_PACKS.map((pack) => [pack.product_id, pack]));

export function playPackById(productId) {
  return PLAY_PACKS_BY_ID.get(String(productId ?? "")) ?? null;
}

const PLAY_OAUTH_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const PLAY_OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";
const PLAY_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo";
const PLAY_PUBLISHER_BASE = "https://androidpublisher.googleapis.com/androidpublisher/v3";
const PLAY_WEBHOOK_PATH_SUFFIX = "/api/webhooks/google-play";
const FIRST_RECHARGE_GRANT_LEVEL = 1;
const FIRST_RECHARGE_GRANT_DAYS = 10;
// A verify whose grant is still being written by another request: the
// app retries after this window and gets the stored result.
const PENDING_STALE_MS = 60_000;

export async function ensurePlayBillingSchema(db) {
  await db.prepare(`CREATE TABLE IF NOT EXISTS play_purchases (
    purchase_token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    coins_credited INTEGER NOT NULL,
    bonus_coins INTEGER NOT NULL DEFAULT 0,
    exp_awarded REAL NOT NULL DEFAULT 0,
    first_recharge INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','granted','refunded')),
    created_at INTEGER NOT NULL
  )`).run();
  await db.prepare("CREATE INDEX IF NOT EXISTS idx_play_purchases_user ON play_purchases(user_id, created_at DESC)").run();
  // owner_user_controls: same DDL as owner_api.js ensureOwnerSchema. The
  // refund webhook must be able to ban even when no owner-panel call has
  // ever created the table in this database.
  await db.prepare(`CREATE TABLE IF NOT EXISTS owner_user_controls (
    user_id TEXT PRIMARY KEY,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','banned')),
    muted_until INTEGER,
    banned_until INTEGER,
    note TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  )`).run();
}

// --- Google service-account OAuth2 (same shape as the FCM flow) ---

function playBase64UrlBytes(bytes) {
  let binary = "";
  for (const value of bytes) binary += String.fromCharCode(value);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function playBase64UrlText(value) {
  return playBase64UrlBytes(new TextEncoder().encode(value));
}

function playPemPkcs8Bytes(pem) {
  const body = String(pem ?? "")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  if (!body) throw new Error("play_private_key_missing");
  const binary = atob(body);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function playServiceAccount(env) {
  const raw = String(env.PLAY_SERVICE_ACCOUNT_JSON ?? "").trim();
  if (!raw) return null;
  let service;
  try {
    service = JSON.parse(raw);
  } catch {
    return null;
  }
  const clientEmail = String(service.client_email ?? "").trim();
  const privateKey = String(service.private_key ?? "");
  const projectId = String(service.project_id ?? "").trim();
  if (!clientEmail || !privateKey) return null;
  return { clientEmail, privateKey, projectId };
}

let cachedPlayAccessToken = "";
let cachedPlayAccessTokenUntil = 0;
let cachedPlayProjectId = "";

export async function playAccessToken(env) {
  const service = playServiceAccount(env);
  if (!service) return null;
  const currentSeconds = Math.floor(Date.now() / 1000);
  if (
    cachedPlayAccessToken &&
    cachedPlayProjectId === service.projectId &&
    cachedPlayAccessTokenUntil > currentSeconds + 60
  ) {
    return cachedPlayAccessToken;
  }
  const header = playBase64UrlText(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = playBase64UrlText(JSON.stringify({
    iss: service.clientEmail,
    scope: PLAY_OAUTH_SCOPE,
    aud: PLAY_OAUTH_TOKEN_URL,
    iat: currentSeconds,
    exp: currentSeconds + 3600,
  }));
  const unsigned = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    playPemPkcs8Bytes(service.privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );
  const assertion = `${unsigned}.${playBase64UrlBytes(signature)}`;
  const tokenResponse = await fetch(PLAY_OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!tokenResponse.ok) throw new Error(`play_oauth_${tokenResponse.status}`);
  const tokenBody = await tokenResponse.json();
  const accessToken = String(tokenBody.access_token ?? "").trim();
  const expiresIn = Number(tokenBody.expires_in ?? 3600);
  if (!accessToken) throw new Error("play_oauth_token_missing");
  cachedPlayAccessToken = accessToken;
  cachedPlayProjectId = service.projectId;
  cachedPlayAccessTokenUntil = currentSeconds + Math.max(300, expiresIn);
  return accessToken;
}

// Android Publisher API, purchases.products.get (v3): purchaseState
// 0 = Purchased, 1 = Canceled, 2 = Pending; consumptionState
// 0 = Yet to be consumed, 1 = Consumed.
export async function getPlayProductPurchase(env, productId, purchaseToken) {
  const accessToken = await playAccessToken(env);
  if (!accessToken) throw new Error("play_not_configured");
  const url = `${PLAY_PUBLISHER_BASE}/applications/${encodeURIComponent(PLAY_PACKAGE_NAME)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) throw new Error(`play_verification_failed:${response.status}`);
  return response.json();
}

// purchases.products.consume. Returns 204 No Content on success (no
// body to parse). Best-effort: a failed consume must never lose the
// user's coins — the grant is already recorded and idempotent.
export async function consumePlayProductPurchase(env, productId, purchaseToken) {
  try {
    const accessToken = await playAccessToken(env);
    if (!accessToken) return false;
    const url = `${PLAY_PUBLISHER_BASE}/applications/${encodeURIComponent(PLAY_PACKAGE_NAME)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:consume`;
    const response = await fetch(url, {
      method: "POST",
      headers: { authorization: `Bearer ${accessToken}` },
    });
    return response.ok;
  } catch {
    return false;
  }
}

// --- Coins / EXP grant ---

export async function firstRechargeAvailable(db, userId) {
  await ensurePlayBillingSchema(db);
  const row = await db.prepare(
    "SELECT purchase_token FROM play_purchases WHERE user_id=? AND status IN ('granted','refunded') LIMIT 1"
  ).bind(userId).first();
  return !row;
}

// Credit path mirroring walletChange (index.js) for positive amounts:
// relative UPDATE + balance re-read + ledger row with the real
// balance_after. Positive credits cannot fail on funds.
async function creditPlayCoins(db, userId, amount, kind, referenceId) {
  const user = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
  if (!user) throw new Error("user_not_found");
  const current = Number(user.coins ?? 0);
  const next = current + Number(amount);
  if (!Number.isSafeInteger(next) || next < 0) throw new Error("insufficient_coins");
  const ts = Date.now();
  // Atomicity (Wallet audit H4, 2026-11-22): the credit and its
  // ledger row now ride ONE db.batch, so a crash can no longer leave
  // coins credited with no ledger row (or vice versa). The ledger
  // balance is read inside the batch (post-credit).
  const batchResults = await db.batch([
    db.prepare(
      "UPDATE users SET coins = coins + ?, updated_at = ? WHERE id = ?"
    ).bind(amount, ts, userId),
    db.prepare(
      "INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) " +
      "SELECT ?,u.id,?,?,u.coins,?,? FROM users u WHERE u.id=? AND changes()=1"
    ).bind(crypto.randomUUID(), kind, amount, referenceId, ts, userId),
  ]);
  if (Number(batchResults?.[0]?.meta?.changes ?? 0) !== 1) throw new Error("user_not_found");
  const after = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
  return Number(after?.coins ?? 0);
}

export async function verifyPlayPurchase(db, env, userId, productId, purchaseToken, ts = Date.now()) {
  const pack = playPackById(productId);
  if (!pack) throw new Error("invalid_product");
  const token = String(purchaseToken ?? "").trim();
  if (!token) throw new Error("invalid_purchase_token");
  if (!playServiceAccount(env)) throw new Error("play_not_configured");
  await ensurePlayBillingSchema(db);
  await ensureVipSchema(db);

  // 1. Verify with Google first. This call is read-only, so a retry is
  // harmless. purchaseState 0 = Purchased is the only grantable state.
  // An already-consumed token is still grantable here: consumption
  // happens after the grant, so a consumed token with no local row means
  // the grant was recorded elsewhere, never double-granted (the claim
  // below is the single source of truth).
  const purchase = await getPlayProductPurchase(env, pack.product_id, token);
  if (String(purchase.productId ?? pack.product_id) !== pack.product_id) {
    throw new Error("purchase_verification_failed");
  }
  const purchaseState = Number(purchase.purchaseState);
  if (purchaseState === 1) throw new Error("purchase_canceled");
  if (purchaseState === 2) throw new Error("purchase_not_completed");
  if (purchaseState !== 0) throw new Error("purchase_verification_failed");

  // 2. Claim the token first (INSERT OR IGNORE): exactly one verify can
  // own a token. A repeat verify of a granted token returns the stored
  // result without crediting again. A pending row this call just created
  // (meta.changes === 1) is ours to grant; a fresh pending row from
  // another in-flight verify returns 409 so the app retries; a stale
  // pending row (>= 60 s) is resumed below.
  const claim = await db.prepare(
    "INSERT OR IGNORE INTO play_purchases (purchase_token, user_id, product_id, coins_credited, bonus_coins, exp_awarded, first_recharge, status, created_at) VALUES (?, ?, ?, ?, 0, 0, 0, 'pending', ?)"
  ).bind(token, userId, pack.product_id, pack.coins, ts).run();
  const claimed = Number(claim?.meta?.changes ?? 0) === 1;
  let row = await db.prepare("SELECT * FROM play_purchases WHERE purchase_token=?").bind(token).first();
  if (!row) throw new Error("purchase_claim_failed");
  if (String(row.user_id) !== String(userId)) throw new Error("purchase_token_owner_mismatch");
  if (row.status === "granted") {
    const vip = await getVipStatus(db, userId, ts);
    // Crash-window recovery: if the first verify granted the coins but
    // crashed before recording the referral commission, a duplicate
    // verify re-attempts it here (dedupe on the purchase token makes
    // this a no-op when it already exists).
    await recordInviteRechargeCommission(db, userId, token, pack.usd_value * 100, ts);
    return {
      ok: true,
      duplicate: true,
      coins_credited: Number(row.coins_credited),
      bonus_coins: Number(row.bonus_coins),
      exp_awarded: Number(row.exp_awarded),
      vip_level: Number(vip.level ?? 0),
      first_recharge: Number(row.first_recharge) === 1,
    };
  }
  if (row.status === "refunded") throw new Error("purchase_refunded");
  if (!claimed && ts - Number(row.created_at ?? 0) < PENDING_STALE_MS) {
    throw new Error("purchase_processing");
  }

  // 3. First recharge is decided by insertion order, not by a pre-claim
  // read: the user's earliest play_purchases row (by rowid) is the first
  // recharge. Deterministic for fresh claims and for resumes of a stale
  // pending row alike.
  const firstRow = await db.prepare(
    "SELECT purchase_token FROM play_purchases WHERE user_id=? ORDER BY rowid ASC LIMIT 1"
  ).bind(userId).first();
  const isFirst = String(firstRow?.purchase_token ?? "") === token;
  const bonus = isFirst ? pack.coins : 0;
  if (Number(row.bonus_coins) !== bonus || Number(row.first_recharge) !== (isFirst ? 1 : 0)) {
    await db.prepare(
      "UPDATE play_purchases SET bonus_coins=?, first_recharge=? WHERE purchase_token=? AND status='pending'"
    ).bind(bonus, isFirst ? 1 : 0, token).run();
    row = { ...row, bonus_coins: bonus, first_recharge: isFirst ? 1 : 0 };
  }
  const grantedCoins = Number(row.coins_credited);
  const grantedBonus = Number(row.bonus_coins);
  const total = grantedCoins + grantedBonus;

  // 4. Credits are ledger-guarded: a resume only credits kinds that have
  // no wallet_ledger row for this token yet, so a retry after a crash
  // can never double-pay.
  const creditedPurchase = await db.prepare(
    "SELECT 1 AS done FROM wallet_ledger WHERE reference_id=? AND kind='play_purchase' LIMIT 1"
  ).bind(token).first();
  if (!creditedPurchase) await creditPlayCoins(db, userId, grantedCoins, "play_purchase", token);
  if (grantedBonus > 0) {
    const creditedBonus = await db.prepare(
      "SELECT 1 AS done FROM wallet_ledger WHERE reference_id=? AND kind='play_purchase_bonus' LIMIT 1"
    ).bind(token).first();
    if (!creditedBonus) await creditPlayCoins(db, userId, grantedBonus, "play_purchase_bonus", token);
  }

  // 5. EXP on ALL credited coins, including the doubled bonus (Vinay,
  // 2026-11-20). awardSellerVipExp applies the user's level boost to the
  // total. Guarded by the stored exp_awarded so a resume never re-awards.
  // The peer-seller "bonus earns NO EXP" rule in role_wallets.js /
  // vip_policy.js is untouched — only this Play path passes the total.
  let expAwarded = Number(row.exp_awarded ?? 0);
  if (expAwarded <= 0) {
    // The purchase token is the award's dedup key (Wallet audit M2,
    // 2026-11-22): if the worker crashes between the award and the
    // exp_awarded flag update below, the resume re-calls the award
    // with the same token and gets the stored award instead of
    // awarding EXP a second time.
    const vipResult = await awardSellerVipExp(db, userId, total, ts, { referenceId: token });
    expAwarded = Number(vipResult.awarded_exp ?? 0);
    await db.prepare(
      "UPDATE play_purchases SET exp_awarded=? WHERE purchase_token=? AND status='pending'"
    ).bind(expAwarded, token).run();
  }

  // 6. First-recharge VIP1 grant for 10 days. INSERT OR IGNORE on
  // UNIQUE(user_id, source) makes a resume a no-op; the grant never
  // touches user_vip.level / exp_balance.
  if (isFirst) {
    await createVipGrant(db, userId, FIRST_RECHARGE_GRANT_LEVEL, FIRST_RECHARGE_GRANT_DAYS, "play_first_recharge", token, ts);
  }

  // 6b. Referral dollars (Vinay, 2026-11-23): 5% of this recharge, in
  // dollars, to the inviter — every recharge within 3 months of the
  // invite bind. Best-effort; never fails the purchase.
  await recordInviteRechargeCommission(db, userId, token, pack.usd_value * 100, ts);

  await db.prepare(
    "UPDATE play_purchases SET status='granted' WHERE purchase_token=? AND status='pending'"
  ).bind(token).run();
  const vip = await getVipStatus(db, userId, ts);

  // 7. Consume on Google AFTER granting, best-effort.
  await consumePlayProductPurchase(env, pack.product_id, token);

  return {
    ok: true,
    duplicate: false,
    coins_credited: grantedCoins,
    bonus_coins: grantedBonus,
    exp_awarded: expAwarded,
    vip_level: Number(vip.level ?? 0),
    first_recharge: isFirst,
  };
}

// --- Refund / cancel revocation (RTDN) ---

// Revoke one granted purchase: take the granted coins back (never below
// zero) and permanently ban the user ID. Idempotent: the CAS claim on
// status='granted' means exactly one RTDN delivery revokes, duplicate
// deliveries are ignored.
export async function revokePlayPurchase(db, purchaseToken, ts = Date.now()) {
  await ensurePlayBillingSchema(db);
  const token = String(purchaseToken ?? "").trim();
  if (!token) return { ok: false, handled: false, reason: "invalid_token" };
  const row = await db.prepare("SELECT * FROM play_purchases WHERE purchase_token=?").bind(token).first();
  if (!row) return { ok: true, handled: false, reason: "unknown_token" };
  if (row.status === "refunded") return { ok: true, handled: false, reason: "already_refunded" };
  if (row.status !== "granted") return { ok: true, handled: false, reason: "not_granted" };
  const claimed = await db.prepare(
    "UPDATE play_purchases SET status='refunded' WHERE purchase_token=? AND status='granted'"
  ).bind(token).run();
  if (Number(claimed.meta?.changes ?? 0) !== 1) {
    return { ok: true, handled: false, reason: "already_refunded" };
  }
  const userId = String(row.user_id);
  const grantedTotal = Number(row.coins_credited ?? 0) + Number(row.bonus_coins ?? 0);
  let deducted = 0;
  if (grantedTotal > 0) {
    // Guarded relative debit (same pattern as walletChange): deduct
    // min(balance, granted) and no more. If the balance moved between
    // the read and the debit, re-read once and deduct what is there.
    const user = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
    const balance = Number(user?.coins ?? 0);
    let amount = Math.min(balance, grantedTotal);
    if (amount > 0) {
      const updated = await db.prepare(
        "UPDATE users SET coins = coins - ?, updated_at = ? WHERE id=? AND coins >= ?"
      ).bind(amount, ts, userId, amount).run();
      if (Number(updated.meta?.changes ?? 0) === 1) {
        deducted = amount;
      } else {
        const fresh = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
        amount = Math.min(Number(fresh?.coins ?? 0), grantedTotal);
        if (amount > 0) {
          const retried = await db.prepare(
            "UPDATE users SET coins = coins - ?, updated_at = ? WHERE id=? AND coins >= ?"
          ).bind(amount, ts, userId, amount).run();
          if (Number(retried.meta?.changes ?? 0) === 1) deducted = amount;
        }
      }
    }
    if (deducted > 0) {
      const after = await db.prepare("SELECT coins FROM users WHERE id=?").bind(userId).first();
      await db.prepare(
        "INSERT INTO wallet_ledger (id, user_id, kind, amount, balance_after, reference_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
      ).bind(crypto.randomUUID(), userId, "play_refund_revoke", -deducted, Number(after?.coins ?? 0), token, ts).run();
    }
  }
  // Referral-dollar reversal (Vinay, 2026-11-23): a refund also claws
  // back the 5% commission this purchase paid the inviter — only the
  // balance still held, never below zero, and never what was already
  // withdrawn. Best-effort; a failure here never breaks the revoke.
  try {
    await reverseRechargeInviteCommission(db, { purchaseToken: token, ts });
  } catch (error) {
    console.error("DarkVibeX invite commission reversal failed", {
      token,
      error: String(error?.message ?? error),
    });
  }
  // Permanent ID ban (Vinay, 2026-11-20): refund lete hi ID permanent
  // ban. Same upsert shape as the owner moderation endpoint;
  // banned_until NULL = permanent. ensureUserAllowed 403s the user
  // everywhere (including login) from the next call on.
  await db.prepare(
    `INSERT INTO owner_user_controls (user_id, status, muted_until, banned_until, note, updated_at)
     VALUES (?, 'banned', NULL, NULL, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET status='banned', muted_until=NULL, banned_until=NULL, note=excluded.note, updated_at=excluded.updated_at`
  ).bind(userId, "play_purchase_refund", ts).run();
  return { ok: true, handled: true, user_id: userId, coins_revoked: deducted, granted_coins: grantedTotal };
}

// --- RTDN webhook (Cloud Pub/Sub push) ---

// Verify the Pub/Sub push OIDC bearer token via Google's tokeninfo
// endpoint (same aud/iss checks as verifyGoogleIdToken in index.js).
// The push subscription's audience is the webhook URL itself.
async function verifyPlayPushToken(env, authorization) {
  const token = String(authorization ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return false;
  try {
    const response = await fetch(
      `${PLAY_TOKENINFO_URL}?id_token=${encodeURIComponent(token)}`,
      { headers: { accept: "application/json" } },
    );
    if (!response.ok) return false;
    const info = await response.json();
    const iss = String(info.iss ?? "");
    if (iss !== "https://accounts.google.com" && iss !== "accounts.google.com") return false;
    const aud = String(info.aud ?? "");
    if (!aud.endsWith(PLAY_WEBHOOK_PATH_SUFFIX)) return false;
    const exp = Number(info.exp ?? 0);
    if (!Number.isFinite(exp) || exp * 1000 <= Date.now()) return false;
    return true;
  } catch {
    return false;
  }
}

function decodePubSubData(data) {
  const binary = atob(String(data ?? ""));
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
}

// Handle one RTDN DeveloperNotification. Always returns ok:true for any
// parseable message (Pub/Sub redelivers on non-2xx, so only a bad OIDC
// token throws). Throws Error("webhook_unauthorized") on bad auth.
export async function handlePlayWebhook(db, env, authorization, body) {
  await ensurePlayBillingSchema(db);
  if (!(await verifyPlayPushToken(env, authorization))) {
    throw Object.assign(new Error("webhook_unauthorized"), { status: 401 });
  }
  const message = body?.message ?? null;
  if (!message || typeof message.data !== "string") {
    return { ok: true, ignored: "no_message_data" };
  }
  let notification;
  try {
    notification = decodePubSubData(message.data);
  } catch {
    return { ok: true, ignored: "bad_message_data" };
  }
  if (!notification || typeof notification !== "object") {
    return { ok: true, ignored: "bad_notification" };
  }
  if (notification.packageName && notification.packageName !== PLAY_PACKAGE_NAME) {
    console.error("DarkVibeX Play webhook wrong package", String(notification.packageName));
    return { ok: true, ignored: "wrong_package" };
  }
  // Test notification sent from Play Console (Monetization setup).
  if (notification.testNotification) return { ok: true, ignored: "test_notification" };

  const oneTime = notification.oneTimeProductNotification;
  if (oneTime) {
    // RTDN reference: notificationType 1 = ONE_TIME_PRODUCT_PURCHASED,
    // 2 = ONE_TIME_PRODUCT_CANCELED.
    const type = Number(oneTime.notificationType);
    const token = String(oneTime.purchaseToken ?? "");
    if (type === 1) {
      // Granting happens via /api/play/verify (the token carries no
      // user mapping), so a purchase RTDN is only acknowledged here.
      return { ok: true, ignored: "purchase" };
    }
    if (type === 2) {
      const result = await revokePlayPurchase(db, token);
      return { ok: true, revoked: result.handled, reason: result.reason ?? null, user_id: result.user_id ?? null, coins_revoked: result.coins_revoked ?? 0 };
    }
    return { ok: true, ignored: "unknown_one_time_type" };
  }

  const voided = notification.voidedPurchaseNotification;
  if (voided) {
    // Refunds surface here too: the one-time lifecycle doc says a
    // refunded Purchased order "will also be made aware using the
    // Voided Purchases API". productType 2 = PRODUCT_TYPE_ONE_TIME,
    // refundType 1 = FULL_REFUND, 2 = quantity-based partial refund
    // (our packs are single-quantity, so any void is a full revoke).
    // We sell no subscriptions, so subscription voids are ignored.
    if (Number(voided.productType) === 2) {
      const result = await revokePlayPurchase(db, String(voided.purchaseToken ?? ""));
      return { ok: true, revoked: result.handled, reason: result.reason ?? null, user_id: result.user_id ?? null, coins_revoked: result.coins_revoked ?? 0 };
    }
    return { ok: true, ignored: "voided_subscription" };
  }

  return { ok: true, ignored: "unhandled_notification" };
}
