import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { DatabaseSync } from 'node:sqlite';

// Run the production settlement implementation against a transactional SQLite D1 adapter.
const source = readFileSync(new URL('../src/index.js', import.meta.url), 'utf8');
const core = source.slice(source.indexOf('const FRUIT_PARTY_ROUND_MS'), source.indexOf('async function handleApi'));
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
    } catch (error) { this.sqlite.exec('ROLLBACK'); throw error; }
  }
}
for (const [roll, type, keys, payout] of [
  [0, 'silver', ['lemon', 'raspberry', 'kiwi', 'plum'], 100000],
  [1, 'gold', ['banana', 'strawberry', 'watermelon', 'cherry'], 475000],
]) {
  test(`${type} Lucky settles the correct four fruits once with ledger-backed payouts`, async () => {
    const sqlite = new DatabaseSync(':memory:');
    sqlite.exec(readFileSync(new URL('../schema.sql', import.meta.url), 'utf8'));
    const db = new D1(sqlite);
    let sequence = 0;
    const api = runInNewContext(core + '\n({ensureFruitPartySchema, settleFruitPartyRound, fruitPartyState});', {
      crypto: { getRandomValues: (values) => { values[0] = roll; return values; } },
      now: () => 281000, id: () => `ledger-${sequence++}`,
    });
    await api.ensureFruitPartySchema(db);
    sqlite.prepare("INSERT INTO users(id,display_name,coins,created_at,updated_at) VALUES('player','Player',1000000,0,0)").run();
    sqlite.prepare("INSERT INTO fruit_party_lucky_windows VALUES(0,'[10]',0)").run();
    for (const fruit of ['lemon','raspberry','kiwi','plum','banana','strawberry','watermelon','cherry']) {
      sqlite.prepare('INSERT INTO fruit_party_bets VALUES(?,?,10,?,?,5000,0)').run(fruit, fruit, 'player', fruit);
    }
    await api.settleFruitPartyRound(db, 10);
    await api.settleFruitPartyRound(db, 10);
    const result = sqlite.prepare('SELECT * FROM fruit_party_results WHERE round_id=10').get();
    assert.equal(result.mode, `lucky_11_${type}`);
    assert.deepEqual(JSON.parse(result.bonus_fruits_json), keys);
    assert.equal(result.total_payout, payout);
    assert.equal(sqlite.prepare("SELECT coins FROM users WHERE id='player'").get().coins, 1000000 + payout);
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM wallet_ledger').get().n, 1);
    const state = await api.fruitPartyState(db, 'player', 281000);
    assert.equal(state.history[0].lucky_type, type);
    assert.deepEqual(Array.from(state.history[0].bonus_fruits, fruit => fruit.key), keys);
    sqlite.close();
  });
}
