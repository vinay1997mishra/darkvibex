// Separate game calls (combined game-state removed 2026-11-23, Vinay:
// "combined API hta de, har jagah se"): each game exposes /round (live
// round + timer + config, polled every 3s), /my-bets (own bets + today's
// winnings) and /history (last 7 results) as separate endpoints. The
// wallet balance comes from the wallet call, not the game endpoints.
// The bet response still assembles the fresh state (bet state helper),
// so a bet updates the screen at once. These tests prove each separate
// helper returns exactly its own slice, and the bet helper assembles
// the same shape the screens render.
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
      '\n({ensureFruitPartySchema, fruitPartyRoundState, fruitPartyMyBetsState, fruitPartyHistoryState, fruitPartyBetState, ensureGreedyGirlSchema, greedyGirlRoundState, greedyGirlMyBetsState, greedyGirlHistoryState, greedyGirlBetState});',
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

test('Girls Party: separate round / my-bets / history calls carry their own slices', async () => {
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

  // Round first to learn the current round, then seed a bet in it.
  const round = await api.fruitPartyRoundState(db, ts);
  assert.equal(round.ok, true);
  const roundId = round.round.round_id;
  sqlite
    .prepare(
      'INSERT INTO fruit_party_bets VALUES(?,?,?,?,?,?,?)',
    )
    .run('bet-1', 'req-1', roundId, 'player', 'cherry', 5000, ts);

  // Round + timer + config + totals (no wallet, no bets, no history).
  const roundAfter = await api.fruitPartyRoundState(db, ts);
  assert.equal(roundAfter.ok, true);
  assert.equal(roundAfter.server_time, ts);
  assert.equal(roundAfter.round.round_id, roundId);
  assert.equal(typeof roundAfter.round.round_end, 'number');
  assert.equal(typeof roundAfter.round.cycle_end, 'number');
  assert.equal(roundAfter.round.phase, 'betting');
  assert.equal(roundAfter.round.betting_open, true);
  assert.equal(roundAfter.round.total_bet, 5000);
  assert.equal(roundAfter.round.active_players, 1);
  assert.ok(Array.isArray(roundAfter.config.bet_amounts));
  assert.ok(roundAfter.config.bet_amounts.includes(5000));
  assert.equal(roundAfter.config.fruits.length, 8);
  assert.ok(!('my_bets' in roundAfter), 'round must not carry my bets');
  assert.ok(!('history' in roundAfter), 'round must not carry history');
  assert.ok(!('wallet_balance' in roundAfter), 'round must not carry the wallet');

  // My bets + today's winnings, keyed by every fruit.
  const bets = await api.fruitPartyMyBetsState(db, 'player', ts);
  assert.equal(bets.ok, true);
  assert.equal(bets.round_id, roundId);
  assert.equal(bets.my_bets.cherry, 5000);
  assert.equal(bets.my_bets.lemon, 0);
  assert.equal(Object.keys(bets.my_bets).length, 8);
  assert.equal(typeof bets.today_winnings, 'number');

  // History (with top winners).
  const history = await api.fruitPartyHistoryState(db);
  assert.equal(history.ok, true);
  assert.ok(Array.isArray(history.history));

  // The bet response assembles the same shape the screen renders.
  const betState = await api.fruitPartyBetState(db, 'player', ts);
  assert.equal(betState.ok, true);
  assert.equal(betState.round.round_id, roundId);
  assert.equal(betState.config.fruits.length, 8);
  assert.equal(betState.wallet_balance, 1000000);
  assert.equal(betState.my_bets.cherry, 5000);
  assert.ok(Array.isArray(betState.history));
  sqlite.close();
});

test('Greedy Girl: separate round / my-bets / history calls carry their own slices', async () => {
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

  const round = await api.greedyGirlRoundState(db, ts);
  assert.equal(round.ok, true);
  const roundId = round.round.round_id;
  sqlite
    .prepare(
      'INSERT INTO greedy_girl_bets VALUES(?,?,?,?,?,?,?)',
    )
    .run('bet-1', 'req-1', roundId, 'player', 'skewer', 10000, ts);

  const roundAfter = await api.greedyGirlRoundState(db, ts);
  assert.equal(roundAfter.ok, true);
  assert.equal(roundAfter.server_time, ts);
  assert.equal(roundAfter.round.round_id, roundId);
  assert.equal(typeof roundAfter.round.round_end, 'number');
  assert.equal(typeof roundAfter.round.cycle_end, 'number');
  assert.equal(roundAfter.round.phase, 'betting');
  assert.equal(roundAfter.round.betting_open, true);
  assert.equal(roundAfter.round.total_bet, 10000);
  assert.equal(roundAfter.round.active_players, 1);
  assert.ok(Array.isArray(roundAfter.config.bet_amounts));
  assert.ok(roundAfter.config.bet_amounts.includes(10000));
  assert.equal(roundAfter.config.foods.length, 8);
  assert.ok(!('my_bets' in roundAfter), 'round must not carry my bets');
  assert.ok(!('history' in roundAfter), 'round must not carry history');
  assert.ok(!('wallet_balance' in roundAfter), 'round must not carry the wallet');

  const bets = await api.greedyGirlMyBetsState(db, 'player', ts);
  assert.equal(bets.ok, true);
  assert.equal(bets.round_id, roundId);
  assert.equal(bets.my_bets.skewer, 10000);
  assert.equal(bets.my_bets.tomato, 0);
  assert.equal(Object.keys(bets.my_bets).length, 8);
  assert.equal(typeof bets.today_winnings, 'number');

  const history = await api.greedyGirlHistoryState(db);
  assert.equal(history.ok, true);
  assert.ok(Array.isArray(history.history));

  const betState = await api.greedyGirlBetState(db, 'player', ts);
  assert.equal(betState.ok, true);
  assert.equal(betState.round.round_id, roundId);
  assert.equal(betState.config.foods.length, 8);
  assert.equal(betState.wallet_balance, 2500000);
  assert.equal(betState.my_bets.skewer, 10000);
  assert.ok(Array.isArray(betState.history));
  sqlite.close();
});

test('the combined game-state routes are gone; the six separate routes exist', () => {
  assert.ok(!source.includes('"/api/games/fruit-party/state"'), 'fruit-party /state route must be gone');
  assert.ok(!source.includes('"/api/games/greedy-girl/state"'), 'greedy-girl /state route must be gone');
  assert.ok(!source.includes('async function fruitPartyState('), 'fruitPartyState helper must be gone');
  assert.ok(!source.includes('async function greedyGirlState('), 'greedyGirlState helper must be gone');
  for (const route of [
    '"/api/games/fruit-party/round"',
    '"/api/games/fruit-party/my-bets"',
    '"/api/games/fruit-party/history"',
    '"/api/games/greedy-girl/round"',
    '"/api/games/greedy-girl/my-bets"',
    '"/api/games/greedy-girl/history"',
  ]) {
    assert.ok(source.includes(route), `${route} route must exist`);
  }
});

test('round read still opens when settlement fails (2026-11-23: no game opened at all)', async () => {
  // A failing settle used to 500 the whole game state, so the sheet showed
  // "Game unavailable · Retry" forever. The round is time-derived, so the
  // read must survive: the next tick / bet retries the settle. The trigger
  // below makes every settle write fail deterministically.
  const ts = 270000;
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
  const db = new D1(sqlite);
  const api = makeApi(ts);
  await api.ensureFruitPartySchema(db);
  await api.ensureGreedyGirlSchema(db);
  sqlite
    .prepare(
      "INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES('player','Player',1000000,0,0)",
    )
    .run();
  sqlite.exec(
    "CREATE TRIGGER fruit_settle_block BEFORE INSERT ON fruit_party_results BEGIN SELECT RAISE(ABORT, 'settle blocked'); END",
  );
  sqlite.exec(
    "CREATE TRIGGER greedy_settle_block BEFORE INSERT ON greedy_girl_results BEGIN SELECT RAISE(ABORT, 'settle blocked'); END",
  );

  const fruitRound = await api.fruitPartyRoundState(db, ts);
  assert.equal(fruitRound.ok, true);
  assert.equal(typeof fruitRound.round.round_id, 'number');
  assert.equal(fruitRound.round.phase, 'betting');
  assert.equal(fruitRound.round.betting_open, true);
  assert.ok(Array.isArray(fruitRound.config.bet_amounts));

  const greedyRound = await api.greedyGirlRoundState(db, 191000);
  assert.equal(greedyRound.ok, true);
  assert.equal(typeof greedyRound.round.round_id, 'number');
  assert.equal(greedyRound.round.phase, 'betting');
  assert.equal(greedyRound.round.betting_open, true);
  sqlite.close();
});
