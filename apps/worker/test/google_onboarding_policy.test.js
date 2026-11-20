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
  assert.match(worker, /profileSetupRequired = false/);
  assert.match(worker, /matchedExistingEmailAccount \? "" : displayName,[\s\S]*?isNewGoogleAccount/);
  assert.match(worker, /provider='email' AND \(email=\? OR subject=\?\)/);
  assert.match(worker, /needs_profile_setup: Number\(user\.profile_setup_required \?\? 0\) === 1/);
  assert.match(appState, /needsProfileSetup = provider == 'google'\s*\?\s*googleProfileSetupRequired/);
  assert.match(worker, /profile_setup_required=0/);
  assert.match(schema, /profile_setup_required INTEGER NOT NULL DEFAULT 0/);
});

test("guest login remains unavailable and Google onboarding is not silently auto-started", () => {
  // Guest login was deleted permanently (Vinay 2026-11-20): no endpoint,
  // no flag, no way to bring it back.
  assert.doesNotMatch(worker, /guestSessionsAllowed/);
  assert.doesNotMatch(worker, /\/api\/session\/guest/);
  assert.doesNotMatch(worker, /ALLOW_GUEST_SESSIONS/);
  assert.doesNotMatch(appState, /attemptLightweightAuthentication\(\)/);
  assert.doesNotMatch(loginScreen, /Guest Login|Continue as Guest/i);
  assert.match(loginScreen, /login-language-selector/);
  assert.match(loginScreen, /Continue with Google/);
});
