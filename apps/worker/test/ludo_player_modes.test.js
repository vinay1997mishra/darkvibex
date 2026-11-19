import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import worker from "../src/index.js";

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
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(input),
  );
  return `${input}.${base64url(signature)}`;
}

async function fixture(roomId = "ludo-modes-room") {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec(readFileSync(new URL("../schema.sql", import.meta.url), "utf8"));
  const DB = new D1Mock(sqlite);
  const secret = "ludo-modes-test-secret";
  const env = { DB, SESSION_SECRET: secret, ALLOW_GUEST_SESSIONS: true };
  const timestamp = Date.now();
  const insertUser = sqlite.prepare(
    "INSERT INTO users(id,display_name,created_at,updated_at) VALUES(?,?,?,?)",
  );
  const insertMember = sqlite.prepare(
    "INSERT INTO room_members(room_id,user_id,seat_index,mic_muted,joined_at,updated_at) VALUES(?,?,NULL,1,?,?)",
  );
  for (let i = 0; i < 5; i++) {
    insertUser.run(`ludo-user-${i}`, `Ludo User ${i}`, timestamp, timestamp);
  }
  sqlite.prepare(
    "INSERT INTO rooms(id,owner_user_id,name,seat_count,locked,country_code,created_at,updated_at) VALUES(?,?,?,12,0,'',?,?)",
  ).run(roomId, "ludo-user-0", "Ludo modes test room", timestamp, timestamp);
  for (let i = 0; i < 5; i++) {
    insertMember.run(roomId, `ludo-user-${i}`, timestamp + i, timestamp);
  }

  const tokenCache = new Map();
  const getToken = async (userId) => {
    if (!tokenCache.has(userId)) {
      tokenCache.set(userId, await sessionToken(userId, secret));
    }
    return tokenCache.get(userId);
  };
  const request = async (
    path,
    { method = "GET", body, userId = "ludo-user-0" } = {},
  ) => {
    const headers = new Headers({
      authorization: `Bearer ${await getToken(userId)}`,
    });
    if (body != null) headers.set("content-type", "application/json");
    const response = await worker.fetch(
      new Request(`https://test.invalid${path}`, {
        method,
        headers,
        body: body == null ? undefined : JSON.stringify(body),
      }),
      env,
    );
    return { status: response.status, body: await response.json() };
  };
  return { sqlite, roomId, request };
}

const ludo = (roomId, query = "") =>
  `/api/rooms/${roomId}/ludo${query}`;

test("2P red-yellow: join order red then yellow, 3rd player is a spectator and cannot roll", async () => {
  const { sqlite, roomId, request } = await fixture();
  const first = await request(ludo(roomId, "?player_count=2&color_pair=red-yellow"), {
    userId: "ludo-user-0",
  });
  assert.equal(first.status, 200);
  assert.equal(first.body.player_count, 2);
  assert.equal(first.body.color_pair, "red-yellow");
  assert.equal(first.body.player_color, "red");
  assert.equal(first.body.current_player, "red");
  assert.equal(first.body.spectator, false);

  const second = await request(ludo(roomId), { userId: "ludo-user-1" });
  assert.equal(second.status, 200);
  assert.equal(second.body.player_count, 2);
  assert.equal(second.body.color_pair, "red-yellow");
  assert.equal(second.body.player_color, "yellow");

  const third = await request(ludo(roomId), { userId: "ludo-user-2" });
  assert.equal(third.status, 200);
  assert.equal(third.body.spectator, true);
  assert.equal(third.body.player_color, null);
  assert.equal(third.body.player_count, 2);

  const roll = await request(ludo(roomId, "/roll"), {
    method: "POST",
    userId: "ludo-user-2",
  });
  assert.equal(roll.status, 409);
  assert.equal(roll.body.error, "ludo_table_full");
  sqlite.close();
});

test("2P blue-green: join order blue then green, blue starts", async () => {
  const { sqlite, roomId, request } = await fixture();
  const first = await request(ludo(roomId, "?player_count=2&color_pair=blue-green"), {
    userId: "ludo-user-0",
  });
  assert.equal(first.status, 200);
  assert.equal(first.body.player_count, 2);
  assert.equal(first.body.color_pair, "blue-green");
  assert.equal(first.body.player_color, "blue");
  assert.equal(first.body.current_player, "blue");

  const second = await request(ludo(roomId), { userId: "ludo-user-1" });
  assert.equal(second.body.player_color, "green");
  assert.equal(second.body.color_pair, "blue-green");
  sqlite.close();
});

test("4P: join order red, green, yellow, blue; 5th player is a spectator", async () => {
  const { sqlite, roomId, request } = await fixture();
  const colors = ["red", "green", "yellow", "blue"];
  for (let i = 0; i < 4; i++) {
    const res = await request(ludo(roomId), { userId: `ludo-user-${i}` });
    assert.equal(res.status, 200);
    assert.equal(res.body.player_color, colors[i]);
    assert.equal(res.body.player_count, 4);
    assert.equal(res.body.color_pair, null);
  }
  const fifth = await request(ludo(roomId), { userId: "ludo-user-4" });
  assert.equal(fifth.body.spectator, true);
  assert.equal(fifth.body.player_color, null);
  sqlite.close();
});

test("mode sticks: later joiners cannot change the pair or the count", async () => {
  const { sqlite, roomId, request } = await fixture();
  const first = await request(ludo(roomId, "?player_count=2&color_pair=red-yellow"), {
    userId: "ludo-user-0",
  });
  assert.equal(first.body.player_color, "red");

  // Second joiner asks for the other pair — ignored, still yellow.
  const second = await request(ludo(roomId, "?player_count=2&color_pair=blue-green"), {
    userId: "ludo-user-1",
  });
  assert.equal(second.body.player_color, "yellow");
  assert.equal(second.body.color_pair, "red-yellow");
  assert.equal(second.body.player_count, 2);

  // A spectator asking for 4P cannot switch the table either.
  const third = await request(ludo(roomId, "?player_count=4"), {
    userId: "ludo-user-2",
  });
  assert.equal(third.body.spectator, true);
  assert.equal(third.body.player_count, 2);
  assert.equal(third.body.color_pair, "red-yellow");
  sqlite.close();
});

test("invalid mode params are ignored and fall back to 4P", async () => {
  const { sqlite, roomId, request } = await fixture();
  const res = await request(ludo(roomId, "?player_count=3&color_pair=purple"), {
    userId: "ludo-user-0",
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.player_count, 4);
  assert.equal(res.body.color_pair, null);
  assert.equal(res.body.player_color, "red");
  sqlite.close();
});

test("table-empty reset returns to a fresh 4P default", async () => {
  const { sqlite, roomId, request } = await fixture();
  const first = await request(ludo(roomId, "?player_count=2&color_pair=blue-green"), {
    userId: "ludo-user-0",
  });
  assert.equal(first.body.player_color, "blue");
  const second = await request(ludo(roomId), { userId: "ludo-user-1" });
  assert.equal(second.body.player_color, "green");

  const leave0 = await request(ludo(roomId, "/leave"), {
    method: "POST",
    userId: "ludo-user-0",
  });
  assert.equal(leave0.status, 200);
  const leave1 = await request(ludo(roomId, "/leave"), {
    method: "POST",
    userId: "ludo-user-1",
  });
  assert.equal(leave1.status, 200);

  const fresh = await request(ludo(roomId), { userId: "ludo-user-2" });
  assert.equal(fresh.status, 200);
  assert.equal(fresh.body.player_count, 4);
  assert.equal(fresh.body.color_pair, null);
  assert.equal(fresh.body.player_color, "red");
  assert.equal(fresh.body.current_player, "red");
  sqlite.close();
});

test("room-owner reset keeps the current 2P mode", async () => {
  const { sqlite, roomId, request } = await fixture();
  const first = await request(ludo(roomId, "?player_count=2&color_pair=blue-green"), {
    userId: "ludo-user-0",
  });
  assert.equal(first.body.player_color, "blue");
  const second = await request(ludo(roomId), { userId: "ludo-user-1" });
  assert.equal(second.body.player_color, "green");

  const denied = await request(ludo(roomId, "/reset"), {
    method: "POST",
    userId: "ludo-user-1",
  });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, "room_owner_required");

  const reset = await request(ludo(roomId, "/reset"), {
    method: "POST",
    userId: "ludo-user-0",
  });
  assert.equal(reset.status, 200);
  assert.equal(reset.body.player_count, 2);
  assert.equal(reset.body.color_pair, "blue-green");
  assert.equal(reset.body.current_player, "blue");
  assert.deepEqual(reset.body.tokens.blue, [-1, -1, -1, -1]);
  assert.deepEqual(reset.body.tokens.green, [-1, -1, -1, -1]);
  sqlite.close();
});

test("legacy state without a mode normalizes to 4P, corrupt 2P state normalizes to red-yellow", async () => {
  const { sqlite, roomId, request } = await fixture();
  const first = await request(ludo(roomId), { userId: "ludo-user-0" });
  assert.equal(first.body.player_count, 4);

  const legacy = {
    current_player: "red",
    rolled: null,
    winner: null,
    status: "RED starts. Roll the dice.",
    tokens: {
      red: [-1, -1, -1, -1],
      green: [-1, -1, -1, -1],
      yellow: [-1, -1, -1, -1],
      blue: [-1, -1, -1, -1],
    },
  };
  sqlite
    .prepare("UPDATE ludo_room_sessions SET state_json=? WHERE room_id=?")
    .run(JSON.stringify(legacy), roomId);
  const again = await request(ludo(roomId), { userId: "ludo-user-0" });
  assert.equal(again.body.player_count, 4);
  assert.equal(again.body.color_pair, null);
  assert.equal(again.body.current_player, "red");

  const corrupt = {
    ...legacy,
    player_count: 2,
    color_pair: "purple",
    current_player: "green",
  };
  sqlite
    .prepare("UPDATE ludo_room_sessions SET state_json=? WHERE room_id=?")
    .run(JSON.stringify(corrupt), roomId);
  const fixed = await request(ludo(roomId), { userId: "ludo-user-0" });
  assert.equal(fixed.body.player_count, 2);
  assert.equal(fixed.body.color_pair, "red-yellow");
  assert.equal(fixed.body.current_player, "red");
  sqlite.close();
});

test("2P game flow: turns alternate red<->yellow only, unused colors stay home", async () => {
  const { sqlite, roomId, request } = await fixture();
  const red = "ludo-user-0";
  const yellow = "ludo-user-1";
  const userFor = { red, yellow };
  const first = await request(ludo(roomId, "?player_count=2&color_pair=red-yellow"), {
    userId: red,
  });
  assert.equal(first.body.player_color, "red");
  const second = await request(ludo(roomId), { userId: yellow });
  assert.equal(second.body.player_color, "yellow");

  let sawRed = false;
  let sawYellow = false;
  let tokenOut = false;
  for (let step = 0; step < 200; step++) {
    const state = await request(ludo(roomId), { userId: red });
    assert.equal(state.status, 200);
    if (state.body.winner) break;
    const current = state.body.current_player;
    assert.ok(
      current === "red" || current === "yellow",
      `2P turn must be red or yellow, got ${current}`,
    );
    if (current === "red") sawRed = true;
    else sawYellow = true;
    assert.deepEqual(
      state.body.tokens.green,
      [-1, -1, -1, -1],
      "green never plays in red-yellow 2P",
    );
    assert.deepEqual(
      state.body.tokens.blue,
      [-1, -1, -1, -1],
      "blue never plays in red-yellow 2P",
    );
    if (
      state.body.tokens.red.some((p) => p >= 0) ||
      state.body.tokens.yellow.some((p) => p >= 0)
    ) {
      tokenOut = true;
    }
    if (sawRed && sawYellow && tokenOut) break;
    const user = userFor[current];
    if (state.body.rolled == null) {
      const roll = await request(ludo(roomId, "/roll"), {
        method: "POST",
        userId: user,
      });
      assert.equal(roll.status, 200, `roll as ${current} must succeed`);
    } else {
      assert.ok(
        state.body.movable_indexes.length > 0,
        "a rolled die must have a movable token",
      );
      const move = await request(ludo(roomId, "/move"), {
        method: "POST",
        userId: user,
        body: { token_index: state.body.movable_indexes[0] },
      });
      assert.equal(move.status, 200, `move as ${current} must succeed`);
    }
  }
  assert.ok(sawRed, "red took a turn");
  assert.ok(sawYellow, "yellow took a turn");
  assert.ok(tokenOut, "a token left home during the 2P game");
  sqlite.close();
});
