import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";

import {
  MESSAGE_BACKUP_DAYS,
  MESSAGE_BACKUP_WINDOW_MS,
  messageBackupCutoffMs,
  expireOldMessages,
} from "../src/message_retention.js";

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
    CREATE TABLE direct_messages (
      id TEXT PRIMARY KEY, sender_user_id TEXT, receiver_user_id TEXT,
      text TEXT, created_at INTEGER, read_at INTEGER,
      kind TEXT NOT NULL DEFAULT 'text'
    );
    CREATE TABLE room_messages (
      id TEXT PRIMARY KEY, room_id TEXT, user_id TEXT,
      text TEXT, created_at INTEGER
    );
    CREATE TABLE game_room_messages (
      id TEXT PRIMARY KEY, room_id TEXT, user_id TEXT,
      text TEXT, created_at INTEGER
    );
    CREATE TABLE direct_message_images (
      message_id TEXT PRIMARY KEY, image_key TEXT, created_at INTEGER
    );
    CREATE TABLE room_message_images (
      message_id TEXT PRIMARY KEY, image_key TEXT, created_at INTEGER
    );
  `);
  return { sqlite, db: new D1Mock(sqlite) };
}

const DAY = 24 * 60 * 60 * 1000;
const NOW = 1800000000000;

test("message retention: backup window is exactly 45 days", () => {
  assert.equal(MESSAGE_BACKUP_DAYS, 45);
  assert.equal(MESSAGE_BACKUP_WINDOW_MS, 45 * DAY);
  assert.equal(messageBackupCutoffMs(NOW), NOW - 45 * DAY);
});

test("message retention: deletes only messages older than 45 days", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 46 * DAY;
  const freshTs = NOW - 10 * DAY;
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')").run("dm-old", "a", "b", "old", oldTs);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')").run("dm-new", "a", "b", "new", freshTs);
  sqlite.prepare("INSERT INTO room_messages VALUES (?,?,?,?,?)").run("rm-old", "r1", "a", "old", oldTs);
  sqlite.prepare("INSERT INTO room_messages VALUES (?,?,?,?,?)").run("rm-new", "r1", "a", "new", freshTs);
  sqlite.prepare("INSERT INTO game_room_messages VALUES (?,?,?,?,?)").run("gm-old", "r1", "a", "old", oldTs);
  sqlite.prepare("INSERT INTO game_room_messages VALUES (?,?,?,?,?)").run("gm-new", "r1", "a", "new", freshTs);

  const counts = await expireOldMessages(db, {}, NOW);
  assert.deepEqual(counts, { direct: 1, room: 1, gameRoom: 1, images: 0 });

  const remaining = sqlite.prepare("SELECT id FROM direct_messages").all();
  assert.deepEqual(remaining.map((r) => r.id), ["dm-new"]);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM room_messages").get().c, 1);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM game_room_messages").get().c, 1);
});

test("message retention: a message exactly at the 45-day edge is kept", async () => {
  const { sqlite, db } = makeDb();
  const edgeTs = NOW - 45 * DAY;
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')").run("dm-edge", "a", "b", "edge", edgeTs);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')").run("dm-older", "a", "b", "older", edgeTs - 1);
  const counts = await expireOldMessages(db, {}, NOW);
  assert.equal(counts.direct, 1);
  const remaining = sqlite.prepare("SELECT id FROM direct_messages").all();
  assert.deepEqual(remaining.map((r) => r.id), ["dm-edge"]);
});

test("message retention: image rows and R2 files of old messages are deleted", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 50 * DAY;
  const freshTs = NOW - 5 * DAY;
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')").run("dm-old", "a", "b", "old", oldTs);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')").run("dm-new", "a", "b", "new", freshTs);
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-old", "messages/a/old.jpg", oldTs);
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-new", "messages/a/new.jpg", freshTs);
  sqlite.prepare("INSERT INTO room_messages VALUES (?,?,?,?,?)").run("rm-old", "r1", "a", "old", oldTs);
  sqlite.prepare("INSERT INTO room_message_images VALUES (?,?,?)").run("rm-old", "messages/a/room-old.jpg", oldTs);

  const deletedKeys = [];
  const env = {
    FILES: {
      async delete(key) {
        deletedKeys.push(key);
      },
    },
  };
  const counts = await expireOldMessages(db, env, NOW);
  assert.equal(counts.direct, 1);
  assert.equal(counts.room, 1);
  assert.equal(counts.images, 2);
  assert.deepEqual(deletedKeys.sort(), [
    "messages/a/old.jpg",
    "messages/a/room-old.jpg",
  ]);
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) c FROM direct_message_images").get().c,
    1,
  );
  assert.equal(
    sqlite.prepare("SELECT COUNT(*) c FROM room_message_images").get().c,
    0,
  );
});

test("message retention: works with no R2 binding (R2 deletes skipped)", async () => {
  const { db } = makeDb();
  const counts = await expireOldMessages(db, {}, NOW);
  assert.deepEqual(counts, { direct: 0, room: 0, gameRoom: 0, images: 0 });
});

test("message retention: CP invite DMs survive the 45-day cleanup", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 60 * DAY;
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')").run("dm-old", "a", "b", "old", oldTs);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'cp_invite')").run("dm-invite", "a", "b", "invite", oldTs);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'cp_invite_accepted')").run("dm-accepted", "a", "b", "accepted", oldTs);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'cp_invite_rejected')").run("dm-rejected", "a", "b", "rejected", oldTs);
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-invite", "messages/a/invite.jpg", oldTs);

  const counts = await expireOldMessages(db, {}, NOW);
  assert.equal(counts.direct, 1);
  const remaining = sqlite.prepare("SELECT id FROM direct_messages ORDER BY id").all();
  assert.deepEqual(remaining.map((r) => r.id), ["dm-accepted", "dm-invite", "dm-rejected"]);
  // The invite's image row survives with it.
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM direct_message_images").get().c, 1);
});
