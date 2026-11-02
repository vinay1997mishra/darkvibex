import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const schema = await readFile(new URL("../schema.sql", import.meta.url), "utf8");
const appState = await readFile(new URL("../../mobile/lib/app/app_state.dart", import.meta.url), "utf8");
const loginScreen = await readFile(new URL("../../mobile/lib/screens/login_screen.dart", import.meta.url), "utf8");

test("Google onboarding state is durable and defaults existing accounts to direct login", () => {
  assert.match(worker, /profile_setup_required INTEGER NOT NULL DEFAULT 0/);
  assert.match(worker, /\["profile_setup_required", "INTEGER NOT NULL DEFAULT 0"\]/);
  assert.match(worker, /const isNewGoogleAccount =\s*!linkedIdentity && !legacyGoogleUser && !matchedExistingEmailAccount/);
  assert.match(worker, /provider='email' AND \(email=\? OR subject=\?\)/);
  assert.match(worker, /needs_profile_setup: Number\(user\.profile_setup_required \?\? 0\) === 1/);
  assert.match(worker, /profile_setup_required=0/);
  assert.match(schema, /profile_setup_required INTEGER NOT NULL DEFAULT 0/);
});

test("guest login remains unavailable and Google onboarding is not silently auto-started", () => {
  assert.match(worker, /if \(!guestSessionsAllowed\(env\)\)[\s\S]*?guest_login_disabled/);
  assert.doesNotMatch(appState, /attemptLightweightAuthentication\(\)/);
  assert.doesNotMatch(loginScreen, /Guest Login|Continue as Guest/i);
  assert.match(loginScreen, /login-language-selector/);
  assert.match(loginScreen, /Continue with Google/);
});
