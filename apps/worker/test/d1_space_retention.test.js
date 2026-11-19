import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";

import {
  EMAIL_OTP_BACKUP_DAYS,
  D1_SPACE_BACKUP_DAYS,
  GAME_BETS_BACKUP_DAYS,
  d1SpaceCutoffMs,
  expireOldD1SpaceData,
} from "../src/d1_space_retention.js";

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
    CREATE TABLE email_otp_requests (
      id TEXT PRIMARY KEY, email TEXT NOT NULL,
      purpose TEXT NOT NULL, otp_hash TEXT NOT NULL,
      expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
      verified INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
    );
    CREATE TABLE direct_calls (
      id TEXT PRIMARY KEY, caller_user_id TEXT NOT NULL,
      receiver_user_id TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'ringing',
      created_at INTEGER NOT NULL, answered_at INTEGER,
      ended_at INTEGER, updated_at INTEGER NOT NULL
    );
    CREATE TABLE profile_visitors (
      viewed_user_id TEXT NOT NULL, visitor_user_id TEXT NOT NULL,
      first_visited_at INTEGER NOT NULL, last_visited_at INTEGER NOT NULL,
      visit_count INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (viewed_user_id, visitor_user_id)
    );
    CREATE TABLE game_bets (
      id TEXT PRIMARY KEY, game_id TEXT NOT NULL,
      user_id TEXT NOT NULL, stake INTEGER NOT NULL,
      result TEXT NOT NULL, payout INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE owner_notifications (
      id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'platform',
      title TEXT NOT NULL, body TEXT NOT NULL, user_id TEXT,
      read_at INTEGER, created_at INTEGER NOT NULL
    );
  `);
  return { sqlite, db: new D1Mock(sqlite) };
}

const DAY = 24 * 60 * 60 * 1000;
const NOW = 1800000000000;

test("d1 space retention: backup windows are 1 / 45 / 30 days", () => {
  assert.equal(EMAIL_OTP_BACKUP_DAYS, 1);
  assert.equal(D1_SPACE_BACKUP_DAYS, 45);
  assert.equal(GAME_BETS_BACKUP_DAYS, 30);
  assert.equal(d1SpaceCutoffMs(1, NOW), NOW - 1 * DAY);
  assert.equal(d1SpaceCutoffMs(45, NOW), NOW - 45 * DAY);
  assert.equal(d1SpaceCutoffMs(30, NOW), NOW - 30 * DAY);
});

test("d1 space retention: deletes only rows past their window", async () => {
  const { sqlite, db } = makeDb();
  const oldOtp = NOW - 2 * DAY;
  const freshOtp = NOW - 12 * 60 * 60 * 1000;
  const old45 = NOW - 46 * DAY;
  const fresh45 = NOW - 10 * DAY;
  const old30 = NOW - 31 * DAY;
  const fresh30 = NOW - 10 * DAY;

  sqlite.prepare("INSERT INTO email_otp_requests VALUES (?,?,?,?,?,0,0,?)").run("otp-old", "a@x.com", "login", "h1", oldOtp + 600000, oldOtp);
  sqlite.prepare("INSERT INTO email_otp_requests VALUES (?,?,?,?,?,0,0,?)").run("otp-new", "a@x.com", "login", "h2", freshOtp + 600000, freshOtp);

  sqlite.prepare("INSERT INTO direct_calls VALUES (?,?,?,?,?,NULL,NULL,?)").run("call-old", "u1", "u2", "ended", old45, old45);
  sqlite.prepare("INSERT INTO direct_calls VALUES (?,?,?,?,?,NULL,NULL,?)").run("call-new", "u1", "u2", "ended", fresh45, fresh45);

  sqlite.prepare("INSERT INTO profile_visitors VALUES (?,?,?,?,1)").run("u1", "u2", old45, old45);
  sqlite.prepare("INSERT INTO profile_visitors VALUES (?,?,?,?,1)").run("u1", "u3", fresh45, fresh45);

  sqlite.prepare("INSERT INTO game_bets VALUES (?,?,?,?,?,?,?)").run("bet-old", "g1", "u1", 100, "win", 50, old30);
  sqlite.prepare("INSERT INTO game_bets VALUES (?,?,?,?,?,?,?)").run("bet-new", "g1", "u1", 100, "win", 50, fresh30);

  sqlite.prepare("INSERT INTO owner_notifications VALUES (?,?,?,?,NULL,?,?)").run("n-old", "platform", "t", "b", "u1", old45);
  sqlite.prepare("INSERT INTO owner_notifications VALUES (?,?,?,?,NULL,?,?)").run("n-new", "platform", "t", "b", "u1", fresh45);

  const counts = await expireOldD1SpaceData(db, NOW);

  assert.equal(counts.emailOtps, 1);
  assert.equal(counts.directCalls, 1);
  assert.equal(counts.profileVisitors, 1);
  assert.equal(counts.gameBets, 1);
  assert.equal(counts.ownerNotifications, 1);

  // Fresh rows all survive.
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM email_otp_requests").get().n, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM direct_calls").get().n, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM profile_visitors").get().n, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM game_bets").get().n, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM owner_notifications").get().n, 1);
});

test("d1 space retention: a game bet inside the 30-day window survives", async () => {
  const { sqlite, db } = makeDb();
  // 29 days old: still inside the rankings month window, must stay.
  sqlite.prepare("INSERT INTO game_bets VALUES (?,?,?,?,?,?,?)").run("bet-29d", "g1", "u1", 100, "win", 50, NOW - 29 * DAY);
  const counts = await expireOldD1SpaceData(db, NOW);
  assert.equal(counts.gameBets, 0);
  assert.equal(sqlite.prepare("SELECT COUNT(*) AS n FROM game_bets").get().n, 1);
});

test("d1 space retention: missing tables are skipped, never fatal", async () => {
  const sqlite = new DatabaseSync(":memory:");
  const db = new D1Mock(sqlite);
  const counts = await expireOldD1SpaceData(db, NOW);
  assert.deepEqual(counts, {
    emailOtps: 0,
    directCalls: 0,
    profileVisitors: 0,
    gameBets: 0,
    ownerNotifications: 0,
  });
});
