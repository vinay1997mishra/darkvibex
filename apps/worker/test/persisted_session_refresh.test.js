import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const workerSource = readFileSync(
  fileURLToPath(new URL("../src/index.js", import.meta.url)),
  "utf8",
);
const stateSource = readFileSync(
  fileURLToPath(new URL("../../mobile/lib/app/app_state.dart", import.meta.url)),
  "utf8",
);
const apiSource = readFileSync(
  fileURLToPath(new URL("../../mobile/lib/infra/backend_api.dart", import.meta.url)),
  "utf8",
);

test("expired persisted access tokens can refresh without changing account ID", () => {
  assert.ok(workerSource.includes('url.pathname === "/api/session/refresh"'));
  assert.ok(workerSource.includes("verifyRefreshableSessionToken"));
  assert.ok(workerSource.includes("createSessionToken(env, userId, user.display_name)"));
  assert.ok(apiSource.includes("'/api/session/refresh'"));
  assert.ok(stateSource.includes("backend.refreshSession(token: token)"));
  assert.ok(stateSource.includes("provider: provider"));
});

test("transient restore failures do not clear the saved session", () => {
  const restoreStart = stateSource.indexOf("Future<bool> _restorePersistedSession()");
  const restoreEnd = stateSource.indexOf("Future<void> _persistSession()", restoreStart);
  assert.ok(restoreStart >= 0 && restoreEnd > restoreStart);
  const restore = stateSource.slice(restoreStart, restoreEnd);
  assert.ok(restore.includes("Session refresh temporarily unavailable"));
  assert.ok(restore.includes("await _clearPersistedSession()"));
  assert.ok(restore.includes("user_not_found"));
});

test("room close/leave is not wired to account sign-out", () => {
  const roomSource = readFileSync(
    fileURLToPath(new URL("../../mobile/lib/screens/room_screen.dart", import.meta.url)),
    "utf8",
  );
  const leaveStart = roomSource.indexOf("Future<void> _leaveRoom()");
  const leaveEnd = roomSource.indexOf("Future<void> _openGames()", leaveStart);
  assert.ok(leaveStart >= 0 && leaveEnd > leaveStart);
  const leave = roomSource.slice(leaveStart, leaveEnd);
  assert.ok(leave.includes("_leaveServerMembership()"));
  assert.ok(leave.includes("_disconnectRoomRuntime()"));
  assert.ok(!leave.includes("signOut()"));
});
