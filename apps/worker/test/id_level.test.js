import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { awardIdLevelDailyActivity, awardIdLevelGiftCoins, ensureIdLevelSchema, getIdLevel, idLevelRequirement } from "../src/id_level.js";

class D1Mock {
  constructor(database) { this.database = database; }
  prepare(sql) {
    const database = this.database;
    const make = (values = []) => ({
      bind(...bound) { return make(bound); },
      async run() { const result = database.prepare(sql).run(...values); return { meta: { changes: Number(result.changes) } }; },
      async first() { return database.prepare(sql).get(...values) ?? null; },
    });
    return make();
  }
  async batch(statements) { for (const statement of statements) await statement.run(); }
}

function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  const db = new D1Mock(sqlite);
  return { sqlite, db };
}

test("ID level requirements match the confirmed early levels and rise afterward", () => {
  assert.deepEqual([1, 2, 3, 4, 5, 6].map(idLevelRequirement), [10000, 13000, 18000, 25000, 36000, 50000]);
  assert.ok(idLevelRequirement(100) > idLevelRequirement(99));
});

test("gift EXP converts every 400 coins and starts the next level at zero", async () => {
  const { sqlite, db } = fixture();
  await ensureIdLevelSchema(db);
  await awardIdLevelGiftCoins(db, "u1", 3_999_600, 1000);
  assert.equal((await getIdLevel(db, "u1", 1000)).exp_in_level, 9999);
  const up = await awardIdLevelGiftCoins(db, "u1", 400, 2000);
  assert.equal(up.level, 1);
  assert.equal(up.exp_in_level, 0);
  const partial = await awardIdLevelGiftCoins(db, "u1", 800, 3000);
  assert.equal(partial.exp_in_level, 2);
  sqlite.close();
});

test("room entry and share grant their daily EXP only once per day", async () => {
  const { sqlite, db } = fixture();
  const day = 20_000;
  const first = await awardIdLevelDailyActivity(db, "u1", "room_entry", day * 86400000);
  const duplicate = await awardIdLevelDailyActivity(db, "u1", "room_entry", day * 86400000 + 5000);
  const share = await awardIdLevelDailyActivity(db, "u1", "room_share", day * 86400000 + 6000);
  assert.equal(first.awarded_exp, 70);
  assert.equal(duplicate.awarded_exp, 0);
  assert.equal(share.awarded_exp, 75);
  assert.equal(share.exp_in_level, 145);
  sqlite.close();
});
