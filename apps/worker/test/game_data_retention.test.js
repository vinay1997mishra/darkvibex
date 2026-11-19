import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";

import {
  GAME_DATA_BACKUP_DAYS,
  GAME_DATA_BACKUP_WINDOW_MS,
  gameDataBackupCutoffMs,
  expireOldGameData,
} from "../src/game_data_retention.js";

class D1Mock {
  constructor(database) {
    this.database = database;
  }
  prepare(sql) {
    const database = this.database;
    const makeStatement = (values = []) => ({
      bind(...bound) {
        return makeStatement(bound);
      },
      async run() {
        const result = database.prepare(sql).run(...values);
        return { meta: { changes: Number(result.changes) } };
      },
      async first() {
        return database.prepare(sql).get(...values) ?? null;
      },
      async all() {
        return { results: database.prepare(sql).all(...values) };
      },
    });
    return makeStatement();
  }
}

function makeDb() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(`
    CREATE TABLE ludo_room_sessions (
      room_id TEXT PRIMARY KEY, state_json TEXT NOT NULL,
      version INTEGER NOT NULL DEFAULT 1, updated_at INTEGER NOT NULL
    );
    CREATE TABLE ludo_room_players (
      room_id TEXT NOT NULL, user_id TEXT NOT NULL,
      color TEXT NOT NULL, joined_at INTEGER NOT NULL,
      PRIMARY KEY (room_id, user_id)
    );
    CREATE TABLE greedy_girl_bets (
      id TEXT PRIMARY KEY, request_id TEXT NOT NULL,
      round_id INTEGER NOT NULL, user_id TEXT NOT NULL,
      food_key TEXT NOT NULL, amount INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE greedy_girl_results (
      round_id INTEGER PRIMARY KEY, food_key TEXT NOT NULL,
      total_bet INTEGER NOT NULL DEFAULT 0,
      total_payout INTEGER NOT NULL DEFAULT 0,
      active_players INTEGER NOT NULL DEFAULT 0,
      top_winners_json TEXT NOT NULL DEFAULT '[]',
      settled_at INTEGER NOT NULL
    );
    CREATE TABLE fruit_party_bets (
      id TEXT PRIMARY KEY, request_id TEXT NOT NULL,
      round_id INTEGER NOT NULL, user_id TEXT NOT NULL,
      fruit_key TEXT NOT NULL, amount INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE fruit_party_results (
      round_id INTEGER PRIMARY KEY, fruit_key TEXT NOT NULL,
      mode TEXT NOT NULL, bonus_fruits_json TEXT NOT NULL DEFAULT '[]',
      total_bet INTEGER NOT NULL DEFAULT 0,
      total_payout INTEGER NOT NULL DEFAULT 0,
      active_players INTEGER NOT NULL DEFAULT 0,
      top_winners_json TEXT NOT NULL DEFAULT '[]',
      settled_at INTEGER NOT NULL
    );
    CREATE TABLE fruit_party_lucky_windows (
      window_id INTEGER PRIMARY KEY, rounds_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE room_lucky_pouches (
      id TEXT PRIMARY KEY, room_id TEXT NOT NULL,
      owner_user_id TEXT NOT NULL, total_coins INTEGER NOT NULL,
      total_slots INTEGER NOT NULL, remaining_coins INTEGER NOT NULL,
      remaining_slots INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'open',
      request_id TEXT NOT NULL, last_claim_key TEXT,
      created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL
    );
    CREATE TABLE room_lucky_pouch_claims (
      id TEXT PRIMARY KEY, claim_key TEXT NOT NULL UNIQUE,
      pouch_id TEXT NOT NULL, room_id TEXT NOT NULL,
      user_id TEXT NOT NULL, amount INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE room_lucky_numbers (
      id TEXT PRIMARY KEY, room_id TEXT NOT NULL,
      user_id TEXT NOT NULL, display_name TEXT NOT NULL,
      number_value INTEGER NOT NULL, created_at INTEGER NOT NULL
    );
  `);
  return { sqlite, db: new D1Mock(sqlite) };
}

const DAY = 24 * 60 * 60 * 1000;
const NOW = 1800000000000;

test("game data retention: backup window is exactly 45 days", () => {
  assert.equal(GAME_DATA_BACKUP_DAYS, 45);
  assert.equal(GAME_DATA_BACKUP_WINDOW_MS, 45 * DAY);
  assert.equal(gameDataBackupCutoffMs(NOW), NOW - 45 * DAY);
});

test("game data retention: deletes only game rows older than 45 days", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 46 * DAY;
  const freshTs = NOW - 10 * DAY;

  sqlite.prepare("INSERT INTO ludo_room_sessions VALUES (?,?,1,?)").run("room-old", "{}", oldTs);
  sqlite.prepare("INSERT INTO ludo_room_sessions VALUES (?,?,1,?)").run("room-new", "{}", freshTs);
  sqlite.prepare("INSERT INTO ludo_room_players VALUES (?,?,?,?)").run("room-old", "u1", "red", oldTs);
  sqlite.prepare("INSERT INTO ludo_room_players VALUES (?,?,?,?)").run("room-new", "u2", "blue", freshTs);

  sqlite.prepare("INSERT INTO greedy_girl_bets VALUES (?,?,?,?,?,?,?)").run("gb-old", "r1", 1, "u1", "pizza", 100, oldTs);
  sqlite.prepare("INSERT INTO greedy_girl_bets VALUES (?,?,?,?,?,?,?)").run("gb-new", "r2", 2, "u1", "pizza", 100, freshTs);
  sqlite.prepare("INSERT INTO greedy_girl_results VALUES (?,?,?,?,?,?,?)").run(1, "pizza", 100, 50, 1, "[]", oldTs);
  sqlite.prepare("INSERT INTO greedy_girl_results VALUES (?,?,?,?,?,?,?)").run(2, "pizza", 100, 50, 1, "[]", freshTs);

  sqlite.prepare("INSERT INTO fruit_party_bets VALUES (?,?,?,?,?,?,?)").run("fb-old", "r1", 1, "u1", "apple", 100, oldTs);
  sqlite.prepare("INSERT INTO fruit_party_bets VALUES (?,?,?,?,?,?,?)").run("fb-new", "r2", 2, "u1", "apple", 100, freshTs);
  sqlite.prepare("INSERT INTO fruit_party_results VALUES (?,?,?,?,?,?,?,?,?)").run(1, "apple", "normal", "[]", 100, 50, 1, "[]", oldTs);
  sqlite.prepare("INSERT INTO fruit_party_results VALUES (?,?,?,?,?,?,?,?,?)").run(2, "apple", "normal", "[]", 100, 50, 1, "[]", freshTs);
  sqlite.prepare("INSERT INTO fruit_party_lucky_windows VALUES (?,?,?)").run(1, "[]", oldTs);
  sqlite.prepare("INSERT INTO fruit_party_lucky_windows VALUES (?,?,?)").run(2, "[]", freshTs);

  sqlite.prepare("INSERT INTO room_lucky_pouches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)").run("p-old", "r1", "u1", 100, 2, 50, 1, "open", "rq1", null, oldTs, oldTs + DAY);
  sqlite.prepare("INSERT INTO room_lucky_pouches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)").run("p-new", "r1", "u1", 100, 2, 50, 1, "open", "rq2", null, freshTs, freshTs + DAY);
  sqlite.prepare("INSERT INTO room_lucky_pouch_claims VALUES (?,?,?,?,?,?,?)").run("c-old", "ck1", "p-old", "r1", "u2", 50, oldTs);
  sqlite.prepare("INSERT INTO room_lucky_pouch_claims VALUES (?,?,?,?,?,?,?)").run("c-new", "ck2", "p-new", "r1", "u2", 50, freshTs);
  sqlite.prepare("INSERT INTO room_lucky_numbers VALUES (?,?,?,?,?,?)").run("n-old", "r1", "u1", "Vinay", 7, oldTs);
  sqlite.prepare("INSERT INTO room_lucky_numbers VALUES (?,?,?,?,?,?)").run("n-new", "r1", "u1", "Vinay", 7, freshTs);

  const counts = await expireOldGameData(db, NOW);

  assert.equal(counts.ludoSessions, 1);
  assert.equal(counts.ludoPlayers, 1);
  assert.equal(counts.greedyGirlBets, 1);
  assert.equal(counts.greedyGirlResults, 1);
  assert.equal(counts.fruitPartyBets, 1);
  assert.equal(counts.fruitPartyResults, 1);
  assert.equal(counts.fruitPartyLuckyWindows, 1);
  assert.equal(counts.luckyPouches, 1);
  assert.equal(counts.luckyPouchClaims, 1);
  assert.equal(counts.luckyNumbers, 1);

  // Fresh rows all survive.
  const remaining = (table, col) =>
    sqlite.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE ${col} >= ?`).get(NOW - 45 * DAY).n;
  assert.equal(remaining("ludo_room_sessions", "updated_at"), 1);
  assert.equal(remaining("ludo_room_players", "joined_at"), 1);
  assert.equal(remaining("greedy_girl_bets", "created_at"), 1);
  assert.equal(remaining("greedy_girl_results", "settled_at"), 1);
  assert.equal(remaining("fruit_party_bets", "created_at"), 1);
  assert.equal(remaining("fruit_party_results", "settled_at"), 1);
  assert.equal(remaining("fruit_party_lucky_windows", "created_at"), 1);
  assert.equal(remaining("room_lucky_pouches", "created_at"), 1);
  assert.equal(remaining("room_lucky_pouch_claims", "created_at"), 1);
  assert.equal(remaining("room_lucky_numbers", "created_at"), 1);
});

test("game data retention: claims of an expired pouch go with the pouch", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 46 * DAY;
  // A claim made recently, but on a pouch created 46 days ago: the
  // pouch is past backup, so the claim goes with it.
  sqlite.prepare("INSERT INTO room_lucky_pouches VALUES (?,?,?,?,?,?,?,?,?,?,?,?)").run("p-old", "r1", "u1", 100, 2, 50, 1, "open", "rq1", null, oldTs, oldTs + DAY);
  sqlite.prepare("INSERT INTO room_lucky_pouch_claims VALUES (?,?,?,?,?,?,?)").run("c-fresh", "ck1", "p-old", "r1", "u2", 50, NOW - DAY);
  const counts = await expireOldGameData(db, NOW);
  assert.equal(counts.luckyPouches, 1);
  assert.equal(counts.luckyPouchClaims, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM room_lucky_pouch_claims").get().n, 0);
});

test("game data retention: players of an expired Ludo session go with it", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 46 * DAY;
  // A player who joined recently, but the session itself went stale
  // 46 days ago: the abandoned session and its players go together.
  sqlite.prepare("INSERT INTO ludo_room_sessions VALUES (?,?,1,?)").run("room-old", "{}", oldTs);
  sqlite.prepare("INSERT INTO ludo_room_players VALUES (?,?,?,?)").run("room-old", "u1", "red", NOW - DAY);
  const counts = await expireOldGameData(db, NOW);
  assert.equal(counts.ludoSessions, 1);
  assert.equal(counts.ludoPlayers, 1);
});

test("game data retention: missing tables are skipped, never fatal", async () => {
  const sqlite = new DatabaseSync(":memory:");
  const db = new D1Mock(sqlite);
  const counts = await expireOldGameData(db, NOW);
  assert.deepEqual(counts, {
    ludoSessions: 0,
    ludoPlayers: 0,
    greedyGirlBets: 0,
    greedyGirlResults: 0,
    fruitPartyBets: 0,
    fruitPartyResults: 0,
    fruitPartyLuckyWindows: 0,
    luckyPouches: 0,
    luckyPouchClaims: 0,
    luckyNumbers: 0,
  });
});
