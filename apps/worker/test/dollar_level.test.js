// Dollar level (Vinay, 2026-11-23): a level based on the user's total
// recharge in dollars — L1 $2, L2 $5, L3 $12, L4 $20, L5 $40, L6 $70,
// L7 $110, L8 $150, L9 $190, L10 $250, then the same shape to L200
// (L10 step +$60, step grows by $20 every 10 levels; L200 $45,850).
// Counts granted Play purchases + coins received from a coin seller /
// merchant transfer into the normal wallet ($1 = 8,000,000 coins).
// Refunded/pending purchases and the VIP purchase bonus do not count.
// The Wealth level is untouched — it still grows from gifts sent.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import {
  dollarLevelThresholdsCents,
  dollarLevelsByUser,
  profileStats,
} from "../src/tinni_social.js";
import { ensurePlayBillingSchema } from "../src/play_billing.js";

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

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  await ensurePlayBillingSchema(DB);
  return { sqlite, DB };
}

test("dollar level ladder: 200 levels, Vinay's first 10, milestones", () => {
  const thresholds = dollarLevelThresholdsCents();
  assert.equal(thresholds.length, 200);
  assert.deepEqual(
    thresholds.slice(0, 10),
    [200, 500, 1200, 2000, 4000, 7000, 11000, 15000, 19000, 25000],
  );
  assert.equal(thresholds[19], 144400); // L20 $1,444
  assert.equal(thresholds[49], 502800); // L50 $5,028
  assert.equal(thresholds[99], 1100000); // L100 $11,000
  assert.equal(thresholds[149], 1800000); // L150 $18,000
  assert.equal(thresholds[199], 2500000); // L200 $25,000
  for (let i = 1; i < thresholds.length; i += 1) {
    assert.ok(thresholds[i] > thresholds[i - 1], `not increasing at ${i}`);
  }
});

test("dollar level counts Play + seller transfers, excludes refunds and bonus", async () => {
  const { sqlite, DB } = await fixture();
  const now = Date.now();
  // wallet_ledger and gift_events both have FKs to users.
  sqlite.prepare(
    "INSERT INTO users(id,created_at,updated_at) VALUES('user-1',?,?),('user-2',?,?)"
  ).run(now, now, now, now);
  const insert = sqlite.prepare(
    "INSERT INTO play_purchases (purchase_token,user_id,product_id,coins_credited,bonus_coins,exp_awarded,first_recharge,status,created_at) VALUES (?,?,?,?,?,?,?,?,?)"
  );
  insert.run("tok-1", "user-1", "coins_8000000", 8000000, 0, 0, 0, "granted", now);
  insert.run("tok-2", "user-1", "coins_80000000", 80000000, 0, 0, 0, "granted", now);
  insert.run("tok-3", "user-1", "coins_40000000", 40000000, 0, 0, 0, "refunded", now);
  insert.run("tok-4", "user-1", "coins_16000000", 16000000, 0, 0, 0, "pending", now);
  insert.run("tok-5", "user-1", "coins_unknown", 0, 0, 0, 0, "granted", now);

  const ledger = sqlite.prepare(
    "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
  );
  ledger.run(crypto.randomUUID(), "user-1", "coin_seller_received", 8000000, 8000000, "ref-1", now);
  ledger.run(crypto.randomUUID(), "user-1", "merchant_received", 4000000, 12000000, "ref-2", now);
  ledger.run(crypto.randomUUID(), "user-1", "vip_coins_bonus", 400000, 12400000, "ref-1", now);

  // A gift sent: raises Wealth, must NOT raise the dollar level.
  sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,created_at) VALUES(?,?,?,?,?,?,?,?)"
  ).run(crypto.randomUUID(), "room-1", "user-1", "user-2", "rose", 150000, 1, now);

  const stats = await profileStats(DB, "user-1");
  // $1 + $10 granted = 1100 cents; refunded $5, pending $2 and the
  // unknown product count for nothing. Seller transfers add $1.00 +
  // $0.50 = 150 cents; the 400,000-coin VIP bonus is not a recharge.
  assert.equal(stats.total_recharged_usd_cents, 1250);
  // $12.50 passes L1 $2, L2 $5, L3 $12 — next is L4 $20.
  assert.equal(stats.dollar_level.level, 3);
  assert.equal(stats.dollar_level.next_threshold, 2000);
  // Wealth still comes from the gift sent (150,000 >= 100,000).
  assert.equal(stats.wealth.level, 1);
  assert.equal(stats.lifetime_sent_coins, 150000);
});

test("dollar level is zero with no recharge and honours the owner override", async () => {
  const { sqlite, DB } = await fixture();
  const empty = await profileStats(DB, "user-9");
  assert.equal(empty.total_recharged_usd_cents, 0);
  assert.equal(empty.dollar_level.level, 0);
  assert.equal(empty.dollar_level.next_threshold, 200);

  sqlite.prepare(
    "INSERT INTO owner_settings(key,value_json,updated_at) VALUES(?,?,?)"
  ).run("dollar_level_thresholds", JSON.stringify([100]), Date.now());
  const insert = sqlite.prepare(
    "INSERT INTO play_purchases (purchase_token,user_id,product_id,coins_credited,bonus_coins,exp_awarded,first_recharge,status,created_at) VALUES (?,?,?,?,?,?,?,?,?)"
  );
  insert.run("tok-1", "user-9", "coins_8000000", 8000000, 0, 0, 0, "granted", Date.now());
  const overridden = await profileStats(DB, "user-9");
  assert.equal(overridden.dollar_level.level, 1);
  assert.equal(overridden.dollar_level.next_threshold, null);
});

test("dollarLevelsByUser batches the chat tag levels and matches profileStats", async () => {
  const { sqlite, DB } = await fixture();
  const now = Date.now();
  sqlite.prepare(
    "INSERT INTO users(id,created_at,updated_at) VALUES('user-1',?,?),('user-2',?,?),('user-3',?,?)"
  ).run(now, now, now, now, now, now);
  const insert = sqlite.prepare(
    "INSERT INTO play_purchases (purchase_token,user_id,product_id,coins_credited,bonus_coins,exp_awarded,first_recharge,status,created_at) VALUES (?,?,?,?,?,?,?,?,?)"
  );
  // user-1: $1 + $10 granted = $11, refunded $5 ignored.
  insert.run("tok-1", "user-1", "coins_8000000", 8000000, 0, 0, 0, "granted", now);
  insert.run("tok-2", "user-1", "coins_80000000", 80000000, 0, 0, 0, "granted", now);
  insert.run("tok-3", "user-1", "coins_40000000", 40000000, 0, 0, 0, "refunded", now);
  // user-3: exactly $2.
  insert.run("tok-4", "user-3", "coins_16000000", 16000000, 0, 0, 0, "granted", now);
  const ledger = sqlite.prepare(
    "INSERT INTO wallet_ledger(id,user_id,kind,amount,balance_after,reference_id,created_at) VALUES(?,?,?,?,?,?,?)"
  );
  // user-1: +$1.50 from a seller transfer; the VIP bonus is not a recharge.
  ledger.run(crypto.randomUUID(), "user-1", "coin_seller_received", 8000000, 8000000, "ref-1", now);
  ledger.run(crypto.randomUUID(), "user-1", "merchant_received", 4000000, 12000000, "ref-2", now);
  ledger.run(crypto.randomUUID(), "user-1", "vip_coins_bonus", 400000, 12400000, "ref-1", now);

  const levels = await dollarLevelsByUser(DB, ["user-1", "user-2", "user-3", "user-1"]);
  // $12.50 -> L3; no recharge -> 0; $2.00 -> L1. Duplicated ids collapse.
  assert.equal(levels.size, 3);
  assert.equal(levels.get("user-1"), 3);
  assert.equal(levels.get("user-2"), 0);
  assert.equal(levels.get("user-3"), 1);
  // Same numbers as the single-user path, so the chat tag and the
  // profile can never disagree.
  assert.equal((await profileStats(DB, "user-1")).dollar_level.level, 3);
  assert.equal((await profileStats(DB, "user-3")).dollar_level.level, 1);

  // The owner override applies to the batch too.
  sqlite.prepare(
    "INSERT INTO owner_settings(key,value_json,updated_at) VALUES(?,?,?)"
  ).run("dollar_level_thresholds", JSON.stringify([100]), Date.now());
  const overridden = await dollarLevelsByUser(DB, ["user-3"]);
  assert.equal(overridden.get("user-3"), 1);
  assert.equal((await dollarLevelsByUser(DB, [])).size, 0);
});
