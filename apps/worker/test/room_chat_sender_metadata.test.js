import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const read = async (path) => readFile(new URL(path, import.meta.url), "utf8");
const worker = await read("../src/index.js");
const room = await read("../../mobile/lib/screens/room_screen.dart");
const header = await read("../../mobile/lib/widgets/room_chat_sender_header.dart");

test("room chat API returns sender DP, owner tags, VIP role tags and earned medals", () => {
  assert.match(worker, /async function decorateRoomChatProfileMetadata/);
  assert.match(worker, /FROM owner_user_tags/);
  assert.match(worker, /has_gifter_medal/);
  assert.match(worker, /has_charm_medal/);
  assert.match(worker, /active_vip_level/);
  assert.match(worker, /is_room_owner/);
  assert.match(worker, /is_room_admin/);
  assert.match(worker, /avatar_key: anonymous \? ""/);
  assert.match(worker, /profile_tags: anonymous \? \[\] : profileTags/);
  assert.match(worker, /medals: anonymous \? \[\] :/);
  assert.match(worker, /decorateRoomChatProfileMetadata\(/);
});

test("room sender header stays above the bubble and message content excludes sender name", () => {
  assert.match(room, /RoomChatSenderHeader\(/);
  assert.match(room, /BubbleChatText\(text: text\)/);
  assert.match(room, /tags: profileTags/);
  assert.match(room, /medals: profileMedals/);
  assert.doesNotMatch(room, /\$\{name == null \|\| name\.isEmpty \? 'User' : name\}: \$text/);
  assert.match(header, /key: const Key\('room-chat-sender-name'\)/);
  assert.match(header, /Image\.network\(/);
  assert.match(header, /_tagChip/);
  assert.match(header, /_medalChip/);
});
