// Live parity: Greedy Girl must self-heal a missing wallet_ledger table.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { DatabaseSync } from 'node:sqlite';

const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
const core = source.slice(
  source.indexOf('const FRUIT_PARTY_ROUND_MS'),
  source.indexOf('let cachedFcmAccessToken'),
);

class D1 {
  constructor(sqlite) { this.sqlite = sqlite; }

  prepare(sql) {
    const sqlite = this.sqlite;
    const statement = (args = []) => ({
      bind: (...values) => statement(values),
      run: async () => sqlite.prepare(sql).run(...args),
      first: async () => sqlite.prepare(sql).get(...args),
      all: async () => ({ results: sqlite.prepare(sql).all(...args) }),
    });
    return statement();
  }

  async batch(statements) {
    this.sqlite.exec('BEGIN');
    try {
      const result = [];
      for (const statement of statements) result.push(await statement.run());
      this.sqlite.exec('COMMIT');
      return result;
    } catch (error) {
      this.sqlite.exec('ROLLBACK');
      throw error;
    }
  }
}

test('Greedy Girl settles a 30-second round once with ledger-backed payout', async () => {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
  sqlite.exec('DROP TABLE wallet_ledger');
  const db = new D1(sqlite);
  let sequence = 0;
  const api = runInNewContext(
    core + '\n({ensureGreedyGirlSchema, settleGreedyGirlRound, greedyGirlState, GREEDY_GIRL_ROUND_MS});',
    {
      crypto: {
        getRandomValues: (values) => {
          values[0] = 0;
          return values;
        },
      },
      now: () => 191000,
      id: () => `ledger-${sequence++}`,
    },
  );

  assert.equal(api.GREEDY_GIRL_ROUND_MS, 30000);
  await api.ensureGreedyGirlSchema(db);
  assert.equal(
    sqlite.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='wallet_ledger'").get().name,
    'wallet_ledger',
  );
  sqlite.prepare(
    "INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES('player','Player',1000000,0,0)"
  ).run();
  sqlite.prepare(
    'INSERT INTO greedy_girl_bets VALUES(?,?,?,?,?,?,?)'
  ).run('bet-1', 'request-0000000001', 5, 'player', 'tomato', 1000, 0);

  await api.settleGreedyGirlRound(db, 5);
  await api.settleGreedyGirlRound(db, 5);

  const result = sqlite.prepare(
    'SELECT * FROM greedy_girl_results WHERE round_id=5'
  ).get();
  assert.equal(result.food_key, 'tomato');
  assert.equal(result.total_payout, 5000);
  assert.equal(
    sqlite.prepare("SELECT coins FROM users WHERE id='player'").get().coins,
    1005000,
  );
  assert.equal(
    sqlite.prepare(
      "SELECT COUNT(*) AS n FROM wallet_ledger WHERE kind='greedy_girl_win'"
    ).get().n,
    1,
  );

  const state = await api.greedyGirlState(db, 'player', 191000);
  assert.equal(state.history[0].food.key, 'tomato');
  assert.equal(state.config.foods.length, 8);
  sqlite.close();
});
