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

test("room messages carry the numeric dollar + ID levels for the 3D tag pills "
    + "(Vinay, 2026-11-23)", () => {
  // Wealth IS the dollar level — one gold-$ tag, batched per author so
  // the chat tag and the profile always agree. The ID level rides
  // alongside it; the app renders the "Lv.N" pill from the number, and
  // the medal names stay only as the fallback.
  assert.match(worker, /dollarLevelsByUser\(db, userIds\)/);
  assert.match(worker, /dollar_level: anonymous \? 0 : \(dollarLevelByUser\.get\(userId\) \?\? 0\)/);
  assert.match(worker, /id_level: anonymous \? 0 : \(idLevelByUser\.get\(userId\) \?\? 0\)/);
  // The room screen feeds both numbers into the sender header.
  assert.match(room, /dollarLevel: int\.tryParse\(message\['dollar_level'\]\?\.toString\(\) \?\? ''\) \?\? 0/);
  assert.match(room, /idLevel: int\.tryParse\(message\['id_level'\]\?\.toString\(\) \?\? ''\)/);
  assert.match(header, /final int dollarLevel;/);
  assert.match(header, /final int\? idLevel;/);
  assert.match(header, /WealthTag\(level: dollarLevel, fontSize: 11\)/);
  assert.match(header, /IdLevelTag\(level: idLevelNumber, fontSize: 11\)/);
});

test("room sender header stays above the bubble and message content excludes sender name", () => {
  assert.match(room, /RoomChatSenderHeader\(/);
  assert.match(room, /BubbleChatText\(text: text\)/);
  assert.match(room, /tags: profileTags/);
  assert.match(room, /medals: profileMedals/);
  assert.doesNotMatch(room, /\$\{name == null \|\| name\.isEmpty \? 'User' : name\}: \$text/);
  // The sender-name Text keeps its stable test key — since PR #161 it
  // goes through VipNameText's textKey (the name colour widget), which
  // passes it to the inner Text's key.
  assert.match(header, /(textKey|key): const Key\('room-chat-sender-name'\)/);
  assert.match(header, /Image\.network\(/);
  assert.match(header, /_tagChip/);
  assert.match(header, /_medalChip/);
});

test("room messages carry the owner-assigned role tag so the chat header "
    + "can show the tag image", () => {
  // The tag comes from owner_user_tags (kind 'role_tag'), NOT from
  // users.role — the Owner Panel assigns one tag per ID, and the room
  // poll carries it live. The room-messages SELECT must not read
  // users.role for this any more.
  assert.doesNotMatch(worker, /u\.avatar_key,\s*\n\s*u\.role,/);
  assert.match(worker, /String\(tag\.kind \?\? ""\) === "role_tag"/);
  assert.match(worker, /roleTagByUser\.set\(userId, String\(tag\.tag_id \?\? ""\)\.replace\(\/\^role-\/, ""\)\)/);
  assert.match(worker, /role_tag: anonymous \? null : \(roleTagByUser\.get\(userId\) \?\? null\)/);
  // The profile endpoint serves the same assigned tag, so the room
  // profile card and the user's own profile show it without a new APK.
  assert.match(worker, /user\.role_tag=ownerIdentity\.role_tag;/);
  assert.match(worker, /role_tag: roleTagRow \? String\(roleTagRow\.tag_id \?\? ""\)\.replace\(\/\^role-\/,""\) : null,/);
  // The app feeds that slug into the sender header, which renders the
  // role tag image next to the VIP tag.
  assert.match(room, /roleTag: message\['role_tag'\]\?\.toString\(\)/);
  assert.match(header, /final String\? roleTag;/);
  assert.match(header, /RoleTagImage\(roleTag: roleTag, fontSize: 11\)/);
});
