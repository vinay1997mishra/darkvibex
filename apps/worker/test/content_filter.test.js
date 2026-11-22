import test from "node:test";
import assert from "node:assert/strict";

import { checkContent, CONTENT_CATEGORIES } from "../src/content_filter.js";

test("content filter: categories are the four Vinay named", () => {
  assert.deepEqual(CONTENT_CATEGORIES, ["profanity", "porn", "political", "other_app"]);
});

test("content filter: ordinary chat passes", () => {
  for (const text of [
    "hello kaise ho",
    "good morning dost",
    "class start ho gayi",
    "pass the ball",
    "aap kaise ho", // "aap" = respectful "you", NOT the party
    "yaha aao", // "yaha" = "here", NOT the app
    "vote karo", // "vote" is deliberately not blocked
    "sarkar", // ordinary word, not blocked
    "saala", // kinship term, not blocked
    "Dickens ki book", // surname, not the slur
    "blunder ho gaya", // contains "lund" — token-only, must pass
    "modification", // contains "modi" — token-only, must pass
    "document bhej do", // contains "cum" — token-only, must pass
    "random number", // contains "rand" — token-only, must pass
    "chutney khayi", // contains "chut" — token-only, must pass
    "Gandhi ji", // contains "gand" — token-only, must pass
    "cocktail party", // contains "cock" — token-only, must pass
    "in line", // "line" is an everyday word, not blocked
    "imo best hai", // "in my opinion", not blocked
    "",
    "   ",
  ]) {
    assert.deepEqual(checkContent(text), { blocked: false, category: null, matched: null }, text);
  }
});

test("content filter: Hindi + English gaaliyan are blocked as profanity", () => {
  for (const text of [
    "tu behenchod hai",
    "bhenchod",
    "madarchod",
    "chutiya",
    "fuck you",
    "bc", // standalone token
    "mc sale",
    "बहनचोद",
    "मादरचोद",
    "चूतिया",
    "गांडू",
    "harami",
  ]) {
    const result = checkContent(text);
    assert.equal(result.blocked, true, text);
    assert.equal(result.category, "profanity", text);
  }
});

test("content filter: porn terms are blocked", () => {
  for (const text of [
    "porn video dekh",
    "pornhub",
    "xvideos",
    "sex chat",
    "nude pic",
    "onlyfans",
    "पोर्न",
    "सेक्स",
    "चुदाई",
  ]) {
    const result = checkContent(text);
    assert.equal(result.blocked, true, text);
    assert.equal(result.category, "porn", text);
  }
});

test("content filter: political content is blocked", () => {
  for (const text of [
    "bjp jeet gayi",
    "congress party",
    "rahul gandhi",
    "amit shah",
    "modi ji",
    "election kab hai",
    "राजनीति",
    "नेता log",
    "aam aadmi party",
  ]) {
    const result = checkContent(text);
    assert.equal(result.blocked, true, text);
    assert.equal(result.category, "political", text);
  }
});

test("content filter: other apps' names are blocked", () => {
  for (const text of [
    "bigo pe aao",
    "mico live",
    "poppo download karo",
    "tiktok pe video hai",
    "yalla",
    "mera whatsapp number",
    "telegram pe msg karo",
    "instagram id",
    "tinni star",
    "bigo live",
  ]) {
    const result = checkContent(text);
    assert.equal(result.blocked, true, text);
    assert.equal(result.category, "other_app", text);
  }
});

test("content filter: obfuscation still gets caught", () => {
  for (const text of [
    "b.e.h.e.n.c.h.o.d", // separators
    "behen-chod", // hyphen
    "fuuuck you", // repeated letters
    "beeehenchod",
    "p0rnhub", // leet 0 -> o
    "sh1t", // leet 1 -> i
    "b1g0 pe aao", // leet in an app name
  ]) {
    assert.equal(checkContent(text).blocked, true, text);
  }
});

test("content filter: phrases need word boundaries", () => {
  // "sex video" inside a longer word must not match.
  assert.equal(checkContent("xxsex video").blocked, false);
  // But on a boundary it must.
  assert.equal(checkContent("sex video").blocked, true);
  assert.equal(checkContent("dekho sex video").blocked, true);
});
