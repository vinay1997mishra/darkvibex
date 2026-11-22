import test from "node:test";
import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";

import {
  MESSAGE_BACKUP_DAYS,
  MESSAGE_BACKUP_WINDOW_MS,
  MESSAGE_KEEP_LAST_COUNT,
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
  // Each conversation / room holds 150 old messages plus 1 fresh one:
  // the last 100 are always kept, so exactly the 51 oldest go.
  const insertDm = sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')");
  const insertRm = sqlite.prepare("INSERT INTO room_messages VALUES (?,?,?,?,?)");
  const insertGm = sqlite.prepare("INSERT INTO game_room_messages VALUES (?,?,?,?,?)");
  for (let i = 0; i < 150; i++) {
    insertDm.run(`dm-old-${String(i).padStart(3, "0")}`, "a", "b", "old", oldTs + i);
    insertRm.run(`rm-old-${String(i).padStart(3, "0")}`, "r1", "a", "old", oldTs + i);
    insertGm.run(`gm-old-${String(i).padStart(3, "0")}`, "r1", "a", "old", oldTs + i);
  }
  insertDm.run("dm-new", "a", "b", "new", freshTs);
  insertRm.run("rm-new", "r1", "a", "new", freshTs);
  insertGm.run("gm-new", "r1", "a", "new", freshTs);

  const counts = await expireOldMessages(db, {}, NOW);
  assert.deepEqual(counts, { direct: 51, room: 51, gameRoom: 51, images: 0 });

  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM direct_messages").get().c, 100);
  assert.equal(sqlite.prepare("SELECT id FROM direct_messages WHERE id='dm-new'").get().id, "dm-new");
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM room_messages").get().c, 100);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM game_room_messages").get().c, 100);
});

test("message retention: a message exactly at the 45-day edge is kept", async () => {
  const { sqlite, db } = makeDb();
  const edgeTs = NOW - 45 * DAY;
  const insertDm = sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')");
  // 100 fresh filler messages push both edge messages beyond the last
  // 100, so the edge rule itself decides: exactly-at-cutoff stays,
  // 1ms older goes.
  for (let i = 0; i < 100; i++) {
    insertDm.run(`dm-fresh-${String(i).padStart(3, "0")}`, "a", "b", "fresh", NOW - 10 * DAY + i);
  }
  insertDm.run("dm-edge", "a", "b", "edge", edgeTs);
  insertDm.run("dm-older", "a", "b", "older", edgeTs - 1);
  const counts = await expireOldMessages(db, {}, NOW);
  assert.equal(counts.direct, 1);
  const remaining = sqlite.prepare("SELECT id FROM direct_messages WHERE id IN ('dm-edge','dm-older')").all();
  assert.deepEqual(remaining.map((r) => r.id), ["dm-edge"]);
});

test("message retention: image rows and R2 files of old messages are deleted", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 50 * DAY;
  const freshTs = NOW - 5 * DAY;
  const insertDm = sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')");
  const insertRm = sqlite.prepare("INSERT INTO room_messages VALUES (?,?,?,?,?)");
  for (let i = 0; i < 101; i++) {
    insertDm.run(`dm-old-${String(i).padStart(3, "0")}`, "a", "b", "old", oldTs + i);
    insertRm.run(`rm-old-${String(i).padStart(3, "0")}`, "r1", "a", "old", oldTs + i);
  }
  insertDm.run("dm-new", "a", "b", "new", freshTs);
  // Images: one on a message that will be deleted, one on a kept one.
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-old-000", "messages/a/old.jpg", oldTs);
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-new", "messages/a/new.jpg", freshTs);
  sqlite.prepare("INSERT INTO room_message_images VALUES (?,?,?)").run("rm-old-000", "messages/a/room-old.jpg", oldTs);

  const deletedKeys = [];
  const env = {
    FILES: {
      async delete(key) {
        deletedKeys.push(key);
      },
    },
  };
  const counts = await expireOldMessages(db, env, NOW);
  assert.equal(counts.direct, 2);
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
  const insertDm = sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')");
  // 105 old text messages: the 5 oldest fall beyond the last 100.
  for (let i = 0; i < 105; i++) {
    insertDm.run(`dm-t-${String(i).padStart(3, "0")}`, "a", "b", "old", oldTs + i);
  }
  // The 3 invite DMs are even older, but the cp_invite exemption
  // keeps them regardless of the last-100 rule.
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'cp_invite')").run("dm-invite", "a", "b", "invite", oldTs - 1000);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'cp_invite_accepted')").run("dm-accepted", "a", "b", "accepted", oldTs - 1000);
  sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'cp_invite_rejected')").run("dm-rejected", "a", "b", "rejected", oldTs - 1000);
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-invite", "messages/a/invite.jpg", oldTs - 1000);

  const counts = await expireOldMessages(db, {}, NOW);
  assert.equal(counts.direct, 5);
  const remaining = sqlite.prepare("SELECT id FROM direct_messages WHERE kind LIKE 'cp_invite%' ORDER BY id").all();
  assert.deepEqual(remaining.map((r) => r.id), ["dm-accepted", "dm-invite", "dm-rejected"]);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM direct_messages").get().c, 103);
  // The invite's image row survives with it.
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM direct_message_images").get().c, 1);
});

// Last 100 are never deleted (Vinay, 2026-11-22: "server per bhi
// last 100msg rahenge delete nhi honge").

test("message retention: last 100 count is 100", () => {
  assert.equal(MESSAGE_KEEP_LAST_COUNT, 100);
});

test("message retention: last 100 DMs of a conversation survive, older ones go", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 60 * DAY;
  // 150 old messages in one conversation, both directions (a->b and
  // b->a are the same conversation). Only the oldest 50 may be deleted.
  const insertDm = sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')");
  for (let i = 0; i < 150; i++) {
    const sender = i % 2 === 0 ? "a" : "b";
    const receiver = i % 2 === 0 ? "b" : "a";
    insertDm.run(`dm-${String(i).padStart(3, "0")}`, sender, receiver, `m${i}`, oldTs + i);
  }
  // A second conversation with only 30 old messages: all survive.
  for (let i = 0; i < 30; i++) {
    insertDm.run(`dm-c-${String(i).padStart(2, "0")}`, "c", "d", `m${i}`, oldTs + i);
  }

  const counts = await expireOldMessages(db, {}, NOW);
  assert.equal(counts.direct, 50);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM direct_messages").get().c, 130);
  // The survivors of the big conversation are exactly its newest 100.
  const remaining = sqlite.prepare("SELECT id FROM direct_messages WHERE sender_user_id IN ('a','b') ORDER BY created_at").all();
  assert.equal(remaining.length, 100);
  assert.equal(remaining[0].id, "dm-050");
  assert.equal(remaining[99].id, "dm-149");
});

test("message retention: last 100 room + game-room messages survive per room", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 60 * DAY;
  const insertRm = sqlite.prepare("INSERT INTO room_messages VALUES (?,?,?,?,?)");
  const insertGm = sqlite.prepare("INSERT INTO game_room_messages VALUES (?,?,?,?,?)");
  for (let i = 0; i < 120; i++) {
    insertRm.run(`rm-${String(i).padStart(3, "0")}`, "r1", "a", `m${i}`, oldTs + i);
    insertGm.run(`gm-${String(i).padStart(3, "0")}`, "r1", "a", `m${i}`, oldTs + i);
  }
  // A small room with 10 old messages: all survive.
  for (let i = 0; i < 10; i++) {
    insertRm.run(`rm-s-${i}`, "r2", "a", `m${i}`, oldTs + i);
  }

  const counts = await expireOldMessages(db, {}, NOW);
  assert.equal(counts.room, 20);
  assert.equal(counts.gameRoom, 20);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM room_messages WHERE room_id='r1'").get().c, 100);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM room_messages WHERE room_id='r2'").get().c, 10);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM game_room_messages").get().c, 100);
  const oldestKept = sqlite.prepare("SELECT id FROM room_messages WHERE room_id='r1' ORDER BY created_at LIMIT 1").get();
  assert.equal(oldestKept.id, "rm-020");
});

test("message retention: images of kept messages are not deleted from R2", async () => {
  const { sqlite, db } = makeDb();
  const oldTs = NOW - 60 * DAY;
  const insertDm = sqlite.prepare("INSERT INTO direct_messages VALUES (?,?,?,?,?,NULL,'text')");
  for (let i = 0; i < 110; i++) {
    insertDm.run(`dm-${String(i).padStart(3, "0")}`, "a", "b", `m${i}`, oldTs + i);
  }
  // Image on a message that will be deleted (one of the oldest 10).
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-005", "messages/a/gone.jpg", oldTs);
  // Image on a message inside the last 100 — must survive.
  sqlite.prepare("INSERT INTO direct_message_images VALUES (?,?,?)").run("dm-105", "messages/a/kept.jpg", oldTs);

  const deletedKeys = [];
  const env = { FILES: { async delete(key) { deletedKeys.push(key); } } };
  const counts = await expireOldMessages(db, env, NOW);
  assert.equal(counts.direct, 10);
  assert.equal(counts.images, 1);
  assert.deepEqual(deletedKeys, ["messages/a/gone.jpg"]);
  assert.equal(sqlite.prepare("SELECT COUNT(*) c FROM direct_message_images").get().c, 1);
  assert.equal(sqlite.prepare("SELECT image_key FROM direct_message_images").get().image_key, "messages/a/kept.jpg");
});
