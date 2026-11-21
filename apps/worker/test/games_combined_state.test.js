// Combined game state (Vinay, 2026-11-21): ONE worker call every 3s per
// game carrying round + timer + config + wallet + my bets + history, so
// everything updates together in one go — same pattern as the room
// combined API. These tests prove a SINGLE state call per game returns
// everything its screen renders (no separate state calls needed).
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
  constructor(sqlite) {
    this.sqlite = sqlite;
  }

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

function makeApi(ts) {
  // Deterministic but VARYING random values: the lucky-round picker fills
  // a Set with secureIndex() draws, so a constant stub (values[0] = 0)
  // would spin forever waiting for a second distinct draw.
  let seed = 12345;
  return runInNewContext(
    core +
      '\n({ensureFruitPartySchema, fruitPartyState, ensureGreedyGirlSchema, greedyGirlState});',
    {
      crypto: {
        getRandomValues: (values) => {
          for (let i = 0; i < values.length; i++) {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            values[i] = seed;
          }
          return values;
        },
      },
      now: () => ts,
      id: () => 'combined-test-id',
    },
  );
}

test('Girls Party: one combined state call carries round, timer, config, wallet, my bets and history', async () => {
  const ts = 270000; // Mid-betting window of round 10 (starts 260000, bets close 281000).
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
  const db = new D1(sqlite);
  const api = makeApi(ts);
  await api.ensureFruitPartySchema(db);
  sqlite
    .prepare(
      "INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES('player','Player',1000000,0,0)",
    )
    .run();

  // One call first to learn the current round, then seed a bet in it.
  const first = await api.fruitPartyState(db, 'player', ts);
  assert.equal(first.ok, true);
  const roundId = first.round.round_id;
  sqlite
    .prepare(
      'INSERT INTO fruit_party_bets VALUES(?,?,?,?,?,?,?)',
    )
    .run('bet-1', 'req-1', roundId, 'player', 'cherry', 5000, ts);

  const state = await api.fruitPartyState(db, 'player', ts);
  assert.equal(state.ok, true);
  assert.equal(state.server_time, ts);
  // Round + timer.
  assert.equal(state.round.round_id, roundId);
  assert.equal(typeof state.round.round_end, 'number');
  assert.equal(typeof state.round.cycle_end, 'number');
  assert.equal(state.round.phase, 'betting');
  assert.equal(state.round.betting_open, true);
  assert.equal(state.round.total_bet, 5000);
  assert.equal(state.round.active_players, 1);
  // Config (bet amounts + the 8 girls' fruits).
  assert.ok(Array.isArray(state.config.bet_amounts));
  assert.ok(state.config.bet_amounts.includes(5000));
  assert.equal(state.config.fruits.length, 8);
  // Wallet + today's winnings ride along — no separate balance call.
  assert.equal(state.wallet_balance, 1000000);
  assert.equal(typeof state.today_winnings, 'number');
  // My bets for this round, keyed by every fruit.
  assert.equal(state.my_bets.cherry, 5000);
  assert.equal(state.my_bets.lemon, 0);
  assert.equal(Object.keys(state.my_bets).length, 8);
  // History (with top winners) rides along — no separate history call.
  assert.ok(Array.isArray(state.history));
  sqlite.close();
});

test('Greedy Girl: one combined state call carries round, timer, config, wallet, my bets and history', async () => {
  const ts = 191000;
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
  const db = new D1(sqlite);
  const api = makeApi(ts);
  await api.ensureGreedyGirlSchema(db);
  sqlite
    .prepare(
      "INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES('player','Player',2500000,0,0)",
    )
    .run();

  const first = await api.greedyGirlState(db, 'player', ts);
  assert.equal(first.ok, true);
  const roundId = first.round.round_id;
  sqlite
    .prepare(
      'INSERT INTO greedy_girl_bets VALUES(?,?,?,?,?,?,?)',
    )
    .run('bet-1', 'req-1', roundId, 'player', 'skewer', 10000, ts);

  const state = await api.greedyGirlState(db, 'player', ts);
  assert.equal(state.ok, true);
  assert.equal(state.server_time, ts);
  // Round + timer.
  assert.equal(state.round.round_id, roundId);
  assert.equal(typeof state.round.round_end, 'number');
  assert.equal(typeof state.round.cycle_end, 'number');
  assert.equal(state.round.phase, 'betting');
  assert.equal(state.round.betting_open, true);
  assert.equal(state.round.total_bet, 10000);
  assert.equal(state.round.active_players, 1);
  // Config (bet amounts + the 8 foods).
  assert.ok(Array.isArray(state.config.bet_amounts));
  assert.ok(state.config.bet_amounts.includes(10000));
  assert.equal(state.config.foods.length, 8);
  // Wallet + today's winnings ride along — no separate balance call.
  assert.equal(state.wallet_balance, 2500000);
  assert.equal(typeof state.today_winnings, 'number');
  // My bets for this round, keyed by every food.
  assert.equal(state.my_bets.skewer, 10000);
  assert.equal(state.my_bets.tomato, 0);
  assert.equal(Object.keys(state.my_bets).length, 8);
  // History (with top winners) rides along — no separate history call.
  assert.ok(Array.isArray(state.history));
  sqlite.close();
});
