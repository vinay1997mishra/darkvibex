import test from "node:test";
import assert from "node:assert/strict";

import {
  USER_ID_FILE_CATEGORIES,
  USER_ID_FILE_CATEGORY_LABELS,
  isUserIdFileCategory,
  userIdFileKeyForCategory,
  userIdFileCategoryFromKey,
  userIdFileOwnerFromKey,
  isUserIdFileKey,
  userIdFileKeyBelongsTo,
} from "../src/user_id_files_catalog.js";

test("user id files: exactly the 4 categories Vinay named", () => {
  assert.deepEqual(USER_ID_FILE_CATEGORIES, [
    "id-number",
    "dp",
    "sms",
    "misc",
  ]);
  for (const category of USER_ID_FILE_CATEGORIES) {
    assert.equal(typeof USER_ID_FILE_CATEGORY_LABELS[category], "string");
  }
});

test("user id files: keys follow users/<userId>/<category>/<file>", () => {
  assert.equal(
    userIdFileKeyForCategory("u123", "id-number", "1731936000000.jpg"),
    "users/u123/id-number/1731936000000.jpg",
  );
  assert.equal(
    userIdFileKeyForCategory("u123", "dp", "1731936000000.png"),
    "users/u123/dp/1731936000000.png",
  );
  assert.equal(
    userIdFileKeyForCategory("u123", "sms", "1731936000000.webp"),
    "users/u123/sms/1731936000000.webp",
  );
  assert.equal(
    userIdFileKeyForCategory("u123", "misc", "note-1.jpg"),
    "users/u123/misc/note-1.jpg",
  );
});

test("user id files: bad keys are rejected", () => {
  assert.equal(userIdFileKeyForCategory("u123", "avatar", "a.jpg"), null);
  assert.equal(userIdFileKeyForCategory("u123", "dp", "../a.jpg"), null);
  assert.equal(userIdFileKeyForCategory("u123", "dp", "a/b.jpg"), null);
  assert.equal(userIdFileKeyForCategory("u123", "dp", "/a.jpg"), null);
  assert.equal(userIdFileKeyForCategory("", "dp", "a.jpg"), null);
  assert.equal(userIdFileKeyForCategory("u123", "dp", ""), null);
  assert.equal(userIdFileKeyForCategory("u123", "", "a.jpg"), null);
  assert.equal(userIdFileKeyForCategory(null, "dp", "a.jpg"), null);
});

test("user id files: category and owner parse back from a key", () => {
  const key = "users/u123/dp/1731936000000.png";
  assert.equal(userIdFileCategoryFromKey(key), "dp");
  assert.equal(userIdFileOwnerFromKey(key), "u123");
  assert.equal(isUserIdFileKey(key), true);
  assert.equal(userIdFileKeyBelongsTo(key, "u123"), true);
  assert.equal(userIdFileKeyBelongsTo(key, "u999"), false);
});

test("user id files: non user-info keys are rejected", () => {
  assert.equal(userIdFileCategoryFromKey("vehicles/vip5-deer.mp4"), null);
  assert.equal(userIdFileCategoryFromKey("users/u123/avatar-1.jpg"), null);
  assert.equal(userIdFileOwnerFromKey("users/u123/avatar-1.jpg"), null);
  assert.equal(isUserIdFileKey("users/u123/avatar-1.jpg"), false);
  assert.equal(isUserIdFileKey("users/u123/dp/"), false);
  assert.equal(isUserIdFileKey("users//dp/a.jpg"), false);
  assert.equal(isUserIdFileKey(""), false);
  assert.equal(isUserIdFileKey(null), false);
  assert.equal(userIdFileKeyBelongsTo("vehicles/vip5-deer.mp4", "u123"), false);
});

test("user id files: isUserIdFileCategory only accepts the 4", () => {
  assert.equal(isUserIdFileCategory("id-number"), true);
  assert.equal(isUserIdFileCategory("dp"), true);
  assert.equal(isUserIdFileCategory("sms"), true);
  assert.equal(isUserIdFileCategory("misc"), true);
  assert.equal(isUserIdFileCategory("avatar"), false);
  assert.equal(isUserIdFileCategory("DP"), false);
  assert.equal(isUserIdFileCategory(""), false);
  assert.equal(isUserIdFileCategory(null), false);
});
