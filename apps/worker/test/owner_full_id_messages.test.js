import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");

test("Full ID View exposes an explicit main-Owner private message inspector", () => {
  assert.match(panelHtml, /id="ownerPrivateMessages"/);
  assert.match(panelHtml, /id="loadOwnerMessageInbox"/);
  assert.match(panelHtml, /id="ownerConversationList"/);
  assert.match(panelHtml, /id="ownerMessageThread"/);
  assert.match(panelHtml, /id="ownerMessageRedPockets"/);
  assert.match(panelApp, /async function loadOwnerMessageInbox/);
  assert.match(panelApp, /async function loadOwnerMessageThread/);
  assert.match(panelApp, /state\.actor\?\.type==="owner"/);
});

test("private message inspection is main-Owner only and audited", () => {
  assert.match(ownerApi, /owner_only_message_inspection/);
  assert.match(ownerApi, /actor\.type!=="owner"/);
  assert.match(ownerApi, /owner_message_inbox_view/);
  assert.match(ownerApi, /owner_message_thread_view/);
  assert.match(ownerApi, /owner_message_media_view/);
});

test("Owner inspection reads text photos and red pockets without marking user messages read", () => {
  assert.match(ownerApi, /LEFT JOIN direct_message_images i ON i\.message_id=m\.id/);
  assert.match(ownerApi, /inbox_red_envelopes/);
  assert.match(ownerApi, /inspection_does_not_mark_read:true/);
  assert.doesNotMatch(
    ownerApi.slice(ownerApi.indexOf("async function ownerUserMessageInspection"), ownerApi.indexOf("async function handleOwnerMessageMedia")),
    /UPDATE direct_messages SET read_at/,
  );
});

test("message photos require Owner authorization through protected media route", () => {
  assert.match(ownerApi, /async function handleOwnerMessageMedia/);
  assert.match(ownerApi, /message-media/);
  assert.match(ownerApi, /env\.FILES\.get\(key\)/);
  assert.match(ownerApi, /cache-control":"private, no-store"/);
  assert.match(panelApp, /async function apiBlob/);
  assert.match(panelApp, /async function openOwnerMessageImage/);
});

test("Owner panel control IDs used by message inspector exist in HTML", () => {
  const ids = new Set([...panelHtml.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]));
  for (const id of [
    "ownerPrivateMessages",
    "loadOwnerMessageInbox",
    "ownerMessageSummary",
    "ownerConversationList",
    "ownerMessageThreadPanel",
    "ownerMessageThreadTitle",
    "ownerMessageThreadMeta",
    "closeOwnerMessageThread",
    "ownerMessageThread",
    "ownerMessageRedPockets",
  ]) assert.ok(ids.has(id), "missing control: " + id);
});
