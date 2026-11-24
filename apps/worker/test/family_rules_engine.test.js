// Family Rules engine (Mr. Wrong, 2026-11-24): gift EXP (1:1, x2 same
// family, 10% Lucky), game EXP (100 coins = 1 EXP), daily sign-in task
// (405,000 EXP + 8,100 coins), stay/mic tasks, leader leave/disband,
// deputy + member limits, monthly settlement, weekly rewards, Trends,
// and the family detail endpoint.
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";
import {
  awardFamilyGameExp,
  awardFamilyGiftExp,
  familyWeekBounds,
  settleFamilyMonthly,
  settleFamilyWeekly,
} from "../src/tinni_social.js";

class D1Mock {
  constructor(database) { this.database = database; }
  prepare(sql) {
    const database = this.database;
    const makeStatement = (values = []) => ({
      bind(...bound) { return makeStatement(bound); },
      async run() { const result = database.prepare(sql).run(...values); return { meta: { changes: Number(result.changes) } }; },
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
  const encode = (value) => base64url(Buffer.from(JSON.stringify(value)));
  const input = `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: userId, exp: Math.floor(Date.now() / 1000) + 3600 })}`;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(input));
  return `${input}.${base64url(signature)}`;
}

async function fixture() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  sqlite.exec(`CREATE TABLE IF NOT EXISTS owner_user_devices (
    device_key TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    last_seen_at INTEGER NOT NULL
  )`);
  const DB = new D1Mock(sqlite);
  const secret = "family-engine-test-secret";
  const env = { DB, SESSION_SECRET: secret };
  const request = async (path, { method = "GET", body, userId } = {}) => {
    const headers = new Headers();
    if (body != null) headers.set("content-type", "application/json");
    if (userId) headers.set("authorization", `Bearer ${await sessionToken(userId, secret)}`);
    const response = await worker.fetch(new Request(`https://test.invalid${path}`, { method, headers, body: body == null ? undefined : JSON.stringify(body) }), env);
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, DB, request };
}

let publicIdCounter = 8770000;
async function makeUser(fx, userId, { coins = 100000, vipLevel = 0 } = {}) {
  const { sqlite } = fx;
  sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(userId, userId, Date.now(), Date.now());
  publicIdCounter += 1;
  sqlite.prepare("UPDATE users SET vip_level=?, coins=?, public_id=? WHERE id=?").run(vipLevel, coins, String(publicIdCounter), userId);
  return userId;
}

function coins(fx, userId) {
  return fx.sqlite.prepare("SELECT coins FROM users WHERE id=?").get(userId).coins;
}

function familyExp(fx, familyId) {
  return fx.sqlite.prepare("SELECT experience FROM families WHERE id=?").get(familyId).experience;
}

async function createFamily(fx, userId, overrides = {}) {
  const res = await fx.request("/api/family/create", {
    method: "POST",
    userId,
    body: { user_id: userId, name: "TIGER FAMILY", tag: "TIGER", approval_required: false, logo_key: "family-logos/demo-logo.jpg", ...overrides },
  });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  return res.body.family_id;
}

async function joinFamily(fx, userId, familyId) {
  const res = await fx.request("/api/family/join-request", {
    method: "POST",
    userId,
    body: { user_id: userId, family_id: familyId },
  });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return res.body;
}

test("gift EXP: same family = 2x send + 2x receive, Lucky = 10%", async () => {
  const fx = await fixture();
  const leaderA = await makeUser(fx, "leader-a", { vipLevel: 6 });
  const memberA = await makeUser(fx, "member-a");
  const leaderB = await makeUser(fx, "leader-b", { vipLevel: 6 });
  const familyA = await createFamily(fx, leaderA, { name: "FAMILY A", tag: "FAMA" });
  const familyB = await createFamily(fx, leaderB, { name: "FAMILY B", tag: "FAMB" });
  await joinFamily(fx, memberA, familyA);

  // Same family: 1,000,000-coin gift -> family A gets 2,000,000 (send)
  // + 2,000,000 (receive) = 4,000,000.
  await awardFamilyGiftExp(fx.DB, memberA, leaderA, 1000000, "normal");
  assert.equal(familyExp(fx, familyA), 4000000);

  // Different families: 1,000,000-coin gift -> 1,000,000 each.
  await awardFamilyGiftExp(fx.DB, memberA, leaderB, 1000000, "normal");
  assert.equal(familyExp(fx, familyA), 5000000);
  assert.equal(familyExp(fx, familyB), 1000000);

  // Lucky gift: only 10% counts, x2 same family -> 200,000 send +
  // 200,000 receive = 400,000 total.
  await awardFamilyGiftExp(fx.DB, memberA, leaderA, 1000000, "lucky");
  assert.equal(familyExp(fx, familyA), 5400000);

  // Nobody in a family: nothing happens.
  const outsider = await makeUser(fx, "outsider");
  const other = await makeUser(fx, "other");
  const res = await awardFamilyGiftExp(fx.DB, outsider, other, 1000000, "normal");
  assert.equal(res.awarded, false);
});

test("game EXP: 100 coins bet = 1 EXP", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const familyId = await createFamily(fx, leader);
  await awardFamilyGameExp(fx.DB, leader, 5000);
  assert.equal(familyExp(fx, familyId), 50);
  await awardFamilyGameExp(fx.DB, leader, 99);
  assert.equal(familyExp(fx, familyId), 50);
});

test("sign-in task: 405,000 EXP + 8,100 coins, once a day", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6, coins: 1000 });
  const familyId = await createFamily(fx, leader);
  const first = await fx.request("/api/family/check-in", { method: "POST", userId: leader, body: { user_id: leader } });
  assert.equal(first.status, 200);
  assert.equal(first.body.exp_awarded, 405000);
  assert.equal(first.body.coins_awarded, 8100);
  assert.equal(familyExp(fx, familyId), 405000);
  assert.equal(coins(fx, leader), 1000 + 8100);
  const second = await fx.request("/api/family/check-in", { method: "POST", userId: leader, body: { user_id: leader } });
  assert.equal(second.body.already_checked_in, true);
  assert.equal(coins(fx, leader), 1000 + 8100);
});

test("stay/mic tasks: only inside a family room, award once at threshold", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const member = await makeUser(fx, "member");
  const familyId = await createFamily(fx, leader);
  await joinFamily(fx, member, familyId);
  const now = Date.now();
  // The leader's room is a family room; the member sits inside it.
  fx.sqlite.prepare("INSERT INTO rooms(id,owner_user_id,name,seat_count,created_at,updated_at) VALUES(?,?,?,?,?,?)")
    .run("room-1", leader, "Leader room", 12, now, now);
  fx.sqlite.prepare("INSERT INTO room_members(room_id,user_id,seat_index,mic_muted,joined_at,updated_at) VALUES(?,?,?,?,?,?)")
    .run("room-1", member, 0, 0, now, now);

  // Not in a family room yet for the leader (not seated) -> error.
  const outside = await fx.request("/api/family/task/progress", {
    method: "POST", userId: leader, body: { user_id: leader, kind: "stay", minutes: 20 },
  });
  assert.equal(outside.status, 400);
  assert.equal(outside.body.error, "not_in_family_room");

  // Stay 15 min: accumulated, not yet awarded.
  const part = await fx.request("/api/family/task/progress", {
    method: "POST", userId: member, body: { user_id: member, kind: "stay", minutes: 15 },
  });
  assert.equal(part.status, 200);
  assert.equal(part.body.minutes, 15);
  assert.equal(part.body.awarded, false);
  // Stay 5 more min: threshold 20 reached -> 1,215,000 EXP + 8,100 coins.
  const done = await fx.request("/api/family/task/progress", {
    method: "POST", userId: member, body: { user_id: member, kind: "stay", minutes: 5 },
  });
  assert.equal(done.body.awarded_now, true);
  assert.equal(done.body.exp_awarded, 1215000);
  assert.equal(done.body.coins_awarded, 8100);
  assert.equal(familyExp(fx, familyId), 1215000);
  // More minutes the same day: no second award.
  const again = await fx.request("/api/family/task/progress", {
    method: "POST", userId: member, body: { user_id: member, kind: "stay", minutes: 20 },
  });
  assert.equal(again.body.awarded_now, false);
  assert.equal(familyExp(fx, familyId), 1215000);

  // Mic 10 min: 2,025,000 EXP + 8,100 coins.
  const mic = await fx.request("/api/family/task/progress", {
    method: "POST", userId: member, body: { user_id: member, kind: "mic", minutes: 10 },
  });
  assert.equal(mic.body.awarded_now, true);
  assert.equal(mic.body.exp_awarded, 2025000);
  assert.equal(familyExp(fx, familyId), 1215000 + 2025000);
});

test("leave: member clears personal EXP, leader only when alone (disband)", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const member = await makeUser(fx, "member");
  const familyId = await createFamily(fx, leader);
  await joinFamily(fx, member, familyId);
  // Member checks in (personal EXP row), then leaves.
  await fx.request("/api/family/check-in", { method: "POST", userId: member, body: { user_id: member } });
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS c FROM family_daily_logins WHERE user_id=?").get(member).c, 1);
  const left = await fx.request("/api/family/leave", { method: "POST", userId: member, body: { user_id: member } });
  assert.equal(left.status, 200);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS c FROM family_daily_logins WHERE user_id=?").get(member).c, 0);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS c FROM family_members WHERE family_id=?").get(familyId).c, 1);

  // Leader cannot leave while a member remains.
  const member2 = await makeUser(fx, "member2");
  await joinFamily(fx, member2, familyId);
  const blocked = await fx.request("/api/family/leave", { method: "POST", userId: leader, body: { user_id: leader } });
  assert.equal(blocked.status, 400);
  assert.equal(blocked.body.error, "family_leader_cannot_leave");
  // Member2 leaves, leader alone -> disband.
  await fx.request("/api/family/leave", { method: "POST", userId: member2, body: { user_id: member2 } });
  const disbanded = await fx.request("/api/family/leave", { method: "POST", userId: leader, body: { user_id: leader } });
  assert.equal(disbanded.body.disbanded, true);
  assert.equal(fx.sqlite.prepare("SELECT COUNT(*) AS c FROM families WHERE id=?").get(familyId).c, 0);
});

test("deputy limit: Lv.1 family allows 3 deputies, 4th fails", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const familyId = await createFamily(fx, leader);
  const members = [];
  for (let i = 0; i < 4; i += 1) {
    const id = await makeUser(fx, `member-${i}`);
    await joinFamily(fx, id, familyId);
    members.push(id);
  }
  for (let i = 0; i < 3; i += 1) {
    const res = await fx.request("/api/family/admin", {
      method: "POST", userId: leader, body: { user_id: leader, target_user_id: members[i], admin: true },
    });
    assert.equal(res.status, 200, JSON.stringify(res.body));
  }
  const fourth = await fx.request("/api/family/admin", {
    method: "POST", userId: leader, body: { user_id: leader, target_user_id: members[3], admin: true },
  });
  assert.equal(fourth.status, 400);
  assert.equal(fourth.body.error, "family_deputy_limit");
});

test("member limit: Lv.1 family (60) refuses the 61st member", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const familyId = await createFamily(fx, leader);
  const now = Date.now();
  // 59 more members directly (leader + 59 = 60 = the Lv.1 limit).
  for (let i = 0; i < 59; i += 1) {
    const id = `bulk-${i}`;
    fx.sqlite.prepare("INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)").run(id, id, now, now);
    fx.sqlite.prepare("INSERT INTO family_members(family_id,user_id,role,joined_at) VALUES(?,?,'member',?)").run(familyId, id, now);
  }
  const extra = await makeUser(fx, "extra");
  const res = await fx.request("/api/family/join-request", {
    method: "POST", userId: extra, body: { user_id: extra, family_id: familyId },
  });
  assert.equal(res.status, 400);
  assert.equal(res.body.error, "family_full");
});

test("monthly settlement: top-10 vault coins, idempotent", async () => {
  const fx = await fixture();
  const leaderA = await makeUser(fx, "leader-a", { vipLevel: 6 });
  const leaderB = await makeUser(fx, "leader-b", { vipLevel: 6 });
  const familyA = await createFamily(fx, leaderA, { name: "FAMILY A", tag: "FAMA" });
  const familyB = await createFamily(fx, leaderB, { name: "FAMILY B", tag: "FAMB" });
  fx.sqlite.prepare("INSERT INTO family_monthly_exp(family_id,month_key,exp) VALUES(?,?,?)").run(familyA, "2026-10", 5000000);
  fx.sqlite.prepare("INSERT INTO family_monthly_exp(family_id,month_key,exp) VALUES(?,?,?)").run(familyB, "2026-10", 3000000);
  const settled = await settleFamilyMonthly(fx.DB, "2026-10");
  assert.equal(settled.settled.length, 2);
  assert.equal(settled.settled[0].vault_coins, 40500000);
  assert.equal(settled.settled[1].vault_coins, 24300000);
  assert.equal(fx.sqlite.prepare("SELECT wallet_coins FROM families WHERE id=?").get(familyA).wallet_coins, 40500000);
  assert.equal(fx.sqlite.prepare("SELECT wallet_coins FROM families WHERE id=?").get(familyB).wallet_coins, 24300000);
  // Second run: no double credit.
  const again = await settleFamilyMonthly(fx.DB, "2026-10");
  assert.equal(again.settled.length, 0);
  assert.equal(fx.sqlite.prepare("SELECT wallet_coins FROM families WHERE id=?").get(familyA).wallet_coins, 40500000);
});

test("monthly ranking: charm = received, wealth = given, active = minutes", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const member = await makeUser(fx, "member");
  const familyId = await createFamily(fx, leader);
  await joinFamily(fx, member, familyId);
  await awardFamilyGiftExp(fx.DB, member, leader, 2000000, "normal");
  const monthKey = new Date().toISOString().slice(0, 7);
  const charm = await fx.request(`/api/family/monthly-ranking?family_id=${familyId}&kind=charm`, { method: "GET", userId: leader });
  assert.equal(charm.status, 200);
  // Leader received 4,000,000 (2x same family); member received 0.
  assert.equal(charm.body.members[0].user_id, leader);
  assert.equal(charm.body.members[0].value, 4000000);
  assert.equal(charm.body.month_key, monthKey);
  const wealth = await fx.request(`/api/family/monthly-ranking?family_id=${familyId}&kind=wealth`, { method: "GET", userId: leader });
  assert.equal(wealth.body.members[0].user_id, member);
  assert.equal(wealth.body.members[0].value, 4000000);
});

test("weekly rewards: totals, tiers, settlement, idempotent", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6, coins: 1000 });
  const memberA = await makeUser(fx, "member-a", { coins: 1000 });
  const memberB = await makeUser(fx, "member-b", { coins: 1000 });
  const familyId = await createFamily(fx, leader);
  await joinFamily(fx, memberA, familyId);
  await joinFamily(fx, memberB, familyId);
  const now = Date.now();
  // This week's gifts: A sends 200,000,000, B sends 50,000,000.
  fx.sqlite.prepare("INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,created_at) VALUES(?,?,?,?,?,?,?,?)")
    .run("gift-a1", null, memberA, leader, "rose", 120000000, 1, now);
  fx.sqlite.prepare("INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,created_at) VALUES(?,?,?,?,?,?,?,?)")
    .run("gift-a2", null, memberA, leader, "rose", 80000000, 1, now);
  fx.sqlite.prepare("INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,created_at) VALUES(?,?,?,?,?,?,?,?)")
    .run("gift-b1", null, memberB, leader, "rose", 50000000, 1, now);

  const state = await fx.request(`/api/family/weekly?family_id=${familyId}`, { method: "GET", userId: leader });
  assert.equal(state.status, 200, JSON.stringify(state.body));
  assert.equal(state.body.total, 250000000);
  assert.equal(state.body.tier_index, 0);
  assert.equal(state.body.tiers[0].reached, true);
  assert.equal(state.body.tiers[1].reached, false);
  assert.equal(state.body.this_period.ranking[0].user_id, memberA);
  assert.equal(state.body.this_period.ranking[0].weekly_gifts, 200000000);
  assert.equal(state.body.my_rank, 3);

  const weekKey = familyWeekBounds(new Date()).weekKey;
  const settled = await settleFamilyWeekly(fx.DB, weekKey);
  // Leader (tier 1): 6,750,000. Top1 A: 2,400,000. Top2 B: 1,800,000.
  const byKind = new Map(settled.settled.map((row) => [`${row.user_id}:${row.kind}`, row.coins]));
  assert.equal(byKind.get(`${leader}:leader`), 6750000);
  assert.equal(byKind.get(`${memberA}:top`), 2400000);
  assert.equal(byKind.get(`${memberB}:top`), 1800000);
  assert.equal(coins(fx, leader), 1000 + 6750000);
  assert.equal(coins(fx, memberA), 1000 + 2400000);
  assert.equal(coins(fx, memberB), 1000 + 1800000);
  // Second run: no double credit.
  const again = await settleFamilyWeekly(fx.DB, weekKey);
  assert.equal(again.settled.length, 0);
  assert.equal(coins(fx, leader), 1000 + 6750000);
});

test("weekly settlement: members under 7,200,000 get no top coins", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6, coins: 1000 });
  const member = await makeUser(fx, "member", { coins: 1000 });
  const familyId = await createFamily(fx, leader);
  await joinFamily(fx, member, familyId);
  const now = Date.now();
  // Only 5,000,000 weekly gifts: under the 7,200,000 eligibility line,
  // and under the first tier (148,500,000), so nothing settles.
  fx.sqlite.prepare("INSERT INTO gift_events(id,room_id,sender_user_id,receiver_user_id,gift_id,coin_cost,count,created_at) VALUES(?,?,?,?,?,?,?,?)")
    .run("gift-1", null, member, leader, "rose", 5000000, 1, now);
  const weekKey = familyWeekBounds(new Date()).weekKey;
  const settled = await settleFamilyWeekly(fx.DB, weekKey);
  assert.equal(settled.settled.length, 0);
  assert.equal(coins(fx, leader), 1000);
  assert.equal(coins(fx, member), 1000);
});

test("trends: auto 'I was born!' on join, post/like/comment, member-only", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const member = await makeUser(fx, "member");
  const outsider = await makeUser(fx, "outsider");
  const familyId = await createFamily(fx, leader);
  await joinFamily(fx, member, familyId);
  // Creator + joiner each posted "I was born!" automatically.
  const feed = await fx.request(`/api/family/trends?family_id=${familyId}`, { method: "GET", userId: leader });
  assert.equal(feed.status, 200);
  assert.equal(feed.body.posts.filter((p) => p.text === "I was born!").length, 2);
  const posted = await fx.request("/api/family/trends/post", {
    method: "POST", userId: member, body: { user_id: member, text: "Hello family!" },
  });
  assert.equal(posted.status, 201);
  const liked = await fx.request("/api/family/trends/like", {
    method: "POST", userId: leader, body: { user_id: leader, post_id: posted.body.post_id },
  });
  assert.equal(liked.body.liked, true);
  const commented = await fx.request("/api/family/trends/comment", {
    method: "POST", userId: leader, body: { user_id: leader, post_id: posted.body.post_id, text: "Welcome!" },
  });
  assert.equal(commented.status, 201);
  const comments = await fx.request(`/api/family/trends/comments?post_id=${posted.body.post_id}`, { method: "GET", userId: leader });
  assert.equal(comments.body.comments.length, 1);
  assert.equal(comments.body.comments[0].text, "Welcome!");
  // Outsider cannot post.
  const blocked = await fx.request("/api/family/trends/post", {
    method: "POST", userId: outsider, body: { user_id: outsider, text: "Hi" },
  });
  assert.equal(blocked.status, 400);
  assert.equal(blocked.body.error, "not_in_family");
});

test("family detail: level, rank, members, room, vault for members only", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const member = await makeUser(fx, "member");
  const outsider = await makeUser(fx, "outsider");
  const familyId = await createFamily(fx, leader);
  await joinFamily(fx, member, familyId);
  const now = Date.now();
  fx.sqlite.prepare("INSERT INTO rooms(id,owner_user_id,name,seat_count,created_at,updated_at) VALUES(?,?,?,?,?,?)")
    .run("room-1", leader, "Leader room", 12, now, now);
  fx.sqlite.prepare("INSERT INTO room_members(room_id,user_id,seat_index,mic_muted,joined_at,updated_at) VALUES(?,?,?,?,?,?)")
    .run("room-1", member, 0, 0, now, now);
  const detail = await fx.request(`/api/family/detail?family_id=${familyId}`, { method: "GET", userId: leader });
  assert.equal(detail.status, 200);
  assert.equal(detail.body.family.level, 1);
  assert.equal(detail.body.family.rank, "Iron III");
  assert.equal(detail.body.family.member_count, 2);
  assert.equal(detail.body.family.is_member, true);
  assert.equal(detail.body.family.wallet_coins, 0);
  assert.equal(detail.body.room.id, "room-1");
  assert.equal(detail.body.room.family_live_count, 1);
  assert.equal(detail.body.members.length, 2);
  // Outsider sees the detail but no vault balance.
  const publicDetail = await fx.request(`/api/family/detail?family_id=${familyId}`, { method: "GET", userId: outsider });
  assert.equal(publicDetail.body.family.is_member, false);
  assert.equal(publicDetail.body.family.wallet_coins, null);
});

test("lucky draw records: empty until the event runs", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const familyId = await createFamily(fx, leader);
  const res = await fx.request(`/api/family/lucky-draw-records?family_id=${familyId}`, { method: "GET", userId: leader });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.records, []);
});

test("family list: member_limit grows with level (join page counts)", async () => {
  const fx = await fixture();
  const leader = await makeUser(fx, "leader", { vipLevel: 6 });
  const familyId = await createFamily(fx, leader);
  const list = await fx.request("/api/family/list?limit=10", { method: "GET", userId: leader });
  assert.equal(list.status, 200);
  const row = list.body.families.find((f) => f.id === familyId);
  assert.equal(row.member_count, 1);
  assert.equal(row.member_limit, 60);
});
