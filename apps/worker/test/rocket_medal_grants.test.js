import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import {
  ROCKET_MEDAL_TIER_NAMES,
  grantRocketMedalsOnLaunch,
  rocketLevelReached,
  rocketMedalNameForLevel,
  rocketMedalTierForLevel,
  topRocketGifters,
  userRocketMedals,
} from "../src/rocket_medal_grants.js";

class D1Mock {
  constructor(database) { this.database = database; }
  prepare(sql) {
    const database = this.database;
    const makeStatement = (values = []) => ({
      bind(...bound) { return makeStatement(bound); },
      async run() {
        const result = database.prepare(sql).run(...values);
        return { meta: { changes: Number(result.changes) } };
      },
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

const base64url = (bytes) => Buffer.from(bytes).toString("base64url");
async function sessionToken(userId, secret) {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({
    sub: userId,
    exp: Math.floor(Date.now() / 1000) + 3600,
  })}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

const TS = 1_800_000_000_000;

function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const db = new D1Mock(sqlite);
  let n = 0;
  const newId = () => `medal-test-id-${++n}`;
  const insertUser = sqlite.prepare(
    "INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)",
  );
  const insertRoom = sqlite.prepare(
    "INSERT INTO rooms(id,owner_user_id,name,seat_count,locked,country_code,created_at,updated_at) VALUES(?,?,?,12,0,'',?,?)",
  );
  const insertGift = sqlite.prepare(
    "INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,created_at) VALUES(?,?,?,?,?,?,?)",
  );
  const addUser = (userId) => insertUser.run(userId, `Medal User ${userId}`, TS, TS);
  // Gift receivers must exist (gift_events has a foreign key): every
  // test gift in this file is received by this user.
  insertUser.run("receiver-user", "Medal Receiver", TS, TS);
  const addRoom = (roomId, ownerId) =>
    insertRoom.run(roomId, ownerId, `Medal test room ${roomId}`, TS, TS);
  const addGift = (giftId, roomId, senderId, coins) =>
    insertGift.run(giftId, roomId, senderId, "receiver-user", "rose", coins, TS);
  const medalRows = () => {
    try {
      return sqlite.prepare("SELECT user_id,series,level,room_id FROM user_medals ORDER BY level,user_id").all();
    } catch {
      return []; // table is created lazily on the first launch
    }
  };
  const launchRows = () => {
    try {
      return sqlite.prepare("SELECT room_id,rocket_level FROM rocket_launches ORDER BY rocket_level").all();
    } catch {
      return []; // table is created lazily on the first launch
    }
  };
  return { sqlite, db, newId, addUser, addRoom, addGift, medalRows, launchRows };
}

test("rocket medal tier names match the app gallery list", () => {
  assert.equal(ROCKET_MEDAL_TIER_NAMES.length, 18);
  assert.equal(rocketMedalTierForLevel(1), "Launch");
  assert.equal(rocketMedalTierForLevel(6), "Gold Rush");
  assert.equal(rocketMedalTierForLevel(12), "Orbit King");
  assert.equal(rocketMedalTierForLevel(13), "Star Forge");
  assert.equal(rocketMedalTierForLevel(18), "Rocket Apex");
  assert.equal(rocketMedalTierForLevel(0), null);
  assert.equal(rocketMedalTierForLevel(19), null);
  assert.equal(rocketMedalNameForLevel(6), "Rocket Lv.6 — Gold Rush");
  assert.equal(rocketMedalNameForLevel(1), "Rocket Lv.1 — Launch");
  assert.equal(rocketMedalNameForLevel(0), null);
});

test("rocketLevelReached follows the milestone targets", async () => {
  const { db, addUser, addRoom, addGift } = fixture();
  addUser("u1");
  addRoom("room-a", "u1");
  assert.equal(await rocketLevelReached(db, "room-a"), null);
  assert.equal(await rocketLevelReached(db, "missing-room"), null);
  assert.equal(await rocketLevelReached(db, ""), null);
  addGift("g1", "room-a", "u1", 11_999_999);
  assert.equal(await rocketLevelReached(db, "room-a"), null);
  addGift("g2", "room-a", "u1", 1);
  assert.equal(await rocketLevelReached(db, "room-a"), 1);
  addGift("g3", "room-a", "u1", 6_000_000);
  assert.equal(await rocketLevelReached(db, "room-a"), 2);
  addGift("g4", "room-a", "u1", 232_000_000);
  assert.equal(await rocketLevelReached(db, "room-a"), 18);
});

test("topRocketGifters ranks by sent coins, gift count breaks ties", async () => {
  const { db, addUser, addRoom, addGift } = fixture();
  for (const u of ["u1", "u2", "u3", "u4"]) addUser(u);
  addRoom("room-a", "u1");
  addGift("g1", "room-a", "u1", 5_000_000);
  addGift("g2", "room-a", "u2", 2_000_000);
  addGift("g3", "room-a", "u2", 2_000_000);
  addGift("g4", "room-a", "u2", 1_000_000);
  addGift("g5", "room-a", "u3", 9_000_000);
  addGift("g6", "room-a", "u4", 100);
  const top = await topRocketGifters(db, "room-a", 3);
  assert.deepEqual(top.map((row) => row.user_id), ["u3", "u2", "u1"]);
  assert.equal(top[1].gift_count, 3);
  assert.deepEqual(await topRocketGifters(db, "room-a", 0), []);
  assert.deepEqual(await topRocketGifters(db, "missing-room", 3), []);
});

test("launch grants Lv.N medals to Top 1/2/3, once per user per level", async () => {
  const { db, newId, addUser, addRoom, addGift, medalRows, launchRows } = fixture();
  for (const u of ["u1", "u2", "u3", "u4"]) addUser(u);
  addRoom("room-a", "u1");
  addGift("g1", "room-a", "u1", 7_000_000);
  addGift("g2", "room-a", "u2", 4_000_000);
  addGift("g3", "room-a", "u3", 1_000_000);

  // Total 12M = Lv.1 reached: Top 3 get the Lv.1 medal.
  const first = await grantRocketMedalsOnLaunch(db, "room-a", TS, newId);
  assert.equal(first.launched, true);
  assert.deepEqual(first.levels, [1]);
  assert.deepEqual(first.winners.map((w) => [w.rank, w.user_id]), [[1, "u1"], [2, "u2"], [3, "u3"]]);
  assert.deepEqual(
    medalRows().map((r) => [r.user_id, r.series, r.level, r.room_id]),
    [["u1", "rocket", 1, "room-a"], ["u2", "rocket", 1, "room-a"], ["u3", "rocket", 1, "room-a"]],
  );
  assert.deepEqual(launchRows().map((r) => [r.room_id, r.rocket_level]), [["room-a", 1]]);

  // Re-granting the same level is a no-op (no duplicate medals).
  const again = await grantRocketMedalsOnLaunch(db, "room-a", TS, newId);
  assert.equal(again.launched, false);
  assert.deepEqual(again.levels, []);
  assert.equal(medalRows().length, 3);

  // U4 sends 6M: total 18M = Lv.2 reached. New Top 3 (u1 7M, u4 6M,
  // u2 4M) get Lv.2; u3 keeps only Lv.1; u1 now holds Lv.1 + Lv.2.
  addGift("g4", "room-a", "u4", 6_000_000);
  const second = await grantRocketMedalsOnLaunch(db, "room-a", TS, newId);
  assert.equal(second.launched, true);
  assert.deepEqual(second.levels, [2]);
  assert.deepEqual(second.winners.map((w) => [w.rank, w.user_id]), [[1, "u1"], [2, "u4"], [3, "u2"]]);
  assert.deepEqual(
    (await userRocketMedals(db, "u1")).map((r) => r.level),
    [1, 2],
  );
  assert.deepEqual(
    (await userRocketMedals(db, "u3")).map((r) => r.level),
    [1],
  );
  assert.deepEqual((await userRocketMedals(db, "u4")).map((r) => r.level), [2]);
});

test("one gift crossing several levels launches each of them", async () => {
  const { db, newId, addUser, addRoom, addGift, medalRows } = fixture();
  for (const u of ["u1", "u2", "u3"]) addUser(u);
  addRoom("room-b", "u1");
  addGift("g1", "room-b", "u1", 12_000_000);
  addGift("g2", "room-b", "u2", 8_000_000);
  // Total 20M crosses Lv.1 (12M) and Lv.2 (18M) in one go.
  const result = await grantRocketMedalsOnLaunch(db, "room-b", TS, newId);
  assert.equal(result.launched, true);
  assert.deepEqual(result.levels, [1, 2]);
  assert.deepEqual(
    medalRows().map((r) => [r.user_id, r.level]).sort(),
    [["u1", 1], ["u1", 2], ["u2", 1], ["u2", 2]],
  );
});

test("no grant below the first target, and none without a room", async () => {
  const { db, newId, addUser, addRoom, addGift, medalRows } = fixture();
  addUser("u1");
  addRoom("room-a", "u1");
  addGift("g1", "room-a", "u1", 1_000_000);
  assert.deepEqual(await grantRocketMedalsOnLaunch(db, "room-a", TS, newId), {
    launched: false, levels: [], winners: [],
  });
  assert.deepEqual(await grantRocketMedalsOnLaunch(db, "", TS, newId), {
    launched: false, levels: [], winners: [],
  });
  assert.equal(medalRows().length, 0);
});

test("same user reaching the same level in another room gets no duplicate", async () => {
  const { db, newId, addUser, addRoom, addGift, medalRows } = fixture();
  for (const u of ["u1", "u2", "u3"]) addUser(u);
  addRoom("room-a", "u1");
  addRoom("room-b", "u1");
  addGift("g1", "room-a", "u1", 12_000_000);
  addGift("g2", "room-b", "u1", 12_000_000);
  await grantRocketMedalsOnLaunch(db, "room-a", TS, newId);
  await grantRocketMedalsOnLaunch(db, "room-b", TS, newId);
  // u1 was Top 1 in both rooms at Lv.1, but the medal is once per
  // user per level — one row only.
  assert.equal(medalRows().filter((r) => r.user_id === "u1" && r.level === 1).length, 1);
});

test("gift send hooks the medal grant after commit, without failing the send", () => {
  // No live gift-send test exists in this repo (the send endpoint is
  // covered by source assertions in gift_atomicity_policy.test.js), so
  // the wiring is pinned the same way: the grant call sits after the
  // gift commit, in its own try/catch, so a grant failure can neither
  // fail the paid send nor mark progress pending.
  const source = readFileSync(new URL("../src/index.js", import.meta.url), "utf8");
  const start = source.indexOf('if (url.pathname === "/api/gifts/send"');
  const end = source.indexOf(
    'if (parts[0] === "api" && parts[1] === "rooms" && parts[3] === "ludo"',
    start,
  );
  assert.ok(start >= 0 && end > start, "gift endpoint must be present");
  const endpoint = source.slice(start, end);
  const committedAt = endpoint.indexOf("if (!committedGift)");
  const grantAt = endpoint.indexOf("grantRocketMedalsOnLaunch(db, String(body.room_id");
  assert.ok(committedAt >= 0 && grantAt > committedAt, "grant runs after the gift commits");
  assert.match(endpoint, /grantRocketMedalsOnLaunch\(db, String\(body\.room_id \?\? ""\), giftCreatedAt, id\)/);
  const grantBlock = endpoint.slice(grantAt - 400, grantAt + 300);
  assert.match(grantBlock, /try \{/);
  assert.match(grantBlock, /rocket_medal_grant_failed/);
  // The grant's own catch must not touch progressPending.
  assert.doesNotMatch(grantBlock, /progressPending = true/);
});

test("/api/medals lists earned Rocket medals with series and level", async () => {
  const { sqlite, db, newId, addUser, addRoom, addGift } = fixture();
  for (const u of ["u1", "u2", "u3", "u4"]) addUser(u);
  addRoom("room-a", "u1");
  addGift("g1", "room-a", "u1", 7_000_000);
  addGift("g2", "room-a", "u2", 4_000_000);
  addGift("g3", "room-a", "u3", 1_000_000);

  const secret = "rocket-medal-test-secret";
  const env = { DB: db, SESSION_SECRET: secret, ALLOW_GUEST_SESSIONS: true };
  const request = async (path, userId) => {
    const token = await sessionToken(userId, secret);
    const response = await worker.fetch(
      new Request(`https://test.invalid${path}`, {
        method: "GET",
        headers: new Headers({ authorization: `Bearer ${token}` }),
      }),
      env,
    );
    return { status: response.status, body: await response.json() };
  };

  // Before any launch the medals endpoint still works (no user_medals
  // table yet) and lists no Rocket medal.
  const before = await request("/api/medals?user_id=u1", "u1");
  assert.equal(before.status, 200);
  assert.equal(before.body.ok, true);
  assert.equal(before.body.medals.some((m) => String(m.id ?? "").startsWith("rocket-")), false);

  await grantRocketMedalsOnLaunch(db, "room-a", TS, newId);

  const after = await request("/api/medals?user_id=u1", "u1");
  assert.equal(after.status, 200);
  const rocket = after.body.medals.filter((m) => String(m.id ?? "").startsWith("rocket-"));
  assert.deepEqual(rocket, [{
    id: "rocket-1",
    name: "Rocket Lv.1 — Launch",
    color: "#69C9FF",
    series: "rocket",
    level: 1,
  }]);
  // A user with no Rocket medal sees none.
  const other = await request("/api/medals?user_id=u4", "u4");
  assert.equal(other.body.medals.filter((m) => String(m.id ?? "").startsWith("rocket-")).length, 0);
  void sqlite;
});
