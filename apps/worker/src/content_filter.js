// DarkVibeX — Content filter (strong security, text)
//
// Vinay, 2026-11-22: "Dm, dp, room dp, room msg, inbox, room
// background, id background khi bhi porn or gaaliyan, poltics
// political use nhi hongi iske liye strong security badha de" —
// abusive words, porn-related content and political content may not
// be used ANYWHERE in the app, neither in text nor in pictures.
// "Pure app me ye sab kahi bhi use nhi ho sakta" + "Na hi text me
// na hi pic me". Other apps' names and pics may not be sent in DM.
//
// This module covers TEXT. It runs server-side, on every user-typed
// text the worker accepts: DM send, room message send, game-room
// message send, profile display name + bio, room name + announcement,
// room-theme name.
//
// Picture-content detection (porn inside an image) cannot be done by
// the Worker — there is no image-classification model in the stack.
// That needs a paid moderation API or an on-device ML model, decided
// separately by Vinay. What the server DOES enforce on images: only
// the app's own upload flow can produce a message/DP image key, every
// upload is tied to the uploader's account, and a reported image can
// be traced, removed, and the uploader muted/banned by the owner.
//
// Matching design (false positives kept low on purpose):
// - Text is normalised: lowercase, leet-speak folding (0->o, 1->i,
//   3->e, 4->a, 5->s, 7->t, @->a, $->s), runs of 3+ identical letters
//   collapsed to one ("fuuuck" -> "fuck"), punctuation stripped.
// - Single words match as whole tokens only, so "class" never trips
//   on "ass" and "pass" never trips on "ass" either.
// - Multi-word phrases match with word boundaries ("bigo live").
// - Long severe words (>= 6 letters) are ALSO matched against the
//   fully squashed text (all separators removed), so "b.e.h.e.n.c.h.o.d"
//   and "behen-chod" are still caught.
// - Deliberately NOT blocked: mild/ambiguous words that are also
//   ordinary words (saala/saale = brother-in-law, kutta = dog, vote,
//   sarkar, damn, hell). The lists are a starting point — Vinay can
//   add or remove words without touching the callers.

/// Categories a hit can belong to.
export const CONTENT_CATEGORIES = ["profanity", "porn", "political", "other_app"];

// --- Profanity: abusive / gaali words ---------------------------------
// Hindi (Roman + Devanagari) and English. "bc"/"mc" are token-only
// (they are the standard Hinglish abbreviations for behenchod /
// madarchod); they never match inside another word.
const PROFANITY_WORDS = [
  // Hindi, Roman
  "behenchod", "bhenchod", "madarchod", "chutiya", "chutia", "chut",
  "lund", "gandu", "gaand", "gand", "randi", "harami", "bhosdike",
  "bhosdi", "bhosda", "bc", "mc", "laude", "loda", "lauda", "jhatu",
  "kameena", "kamina", "bhadwa", "tatte", "chutmarika", "rand",
  "chod", "chud", "gaandu", "lundbaaz",
  // Hindi, Devanagari
  "बहनचोद", "मादरचोद", "चूतिया", "चुतिया", "चूत", "लंड", "गांडू",
  "गांड", "रंडी", "हरामी", "भोसड़ी", "भोसडी", "भोसड़ीके", "लौड़े",
  "लौड़ा", "झाटू", "कमीना", "भड़वा", "टट्टे", "चोद", "चुद",
  // English
  "fuck", "fucker", "fucking", "shit", "bitch", "bastard", "asshole",
  "dick", "pussy", "cunt", "whore", "slut", "motherfucker", "bullshit",
  "cock", "prick", "douchebag", "fag", "faggot", "nigger", "nigga",
  "wank", "wanker", "arsehole", "slutty",
];

// --- Porn / sex-related ------------------------------------------------
const PORN_WORDS = [
  "porn", "pornhub", "xvideos", "xnxx", "xhamster", "redtube",
  "pornstar", "pornographic", "xxx", "nude", "naked", "boobs",
  "vagina", "penis", "blowjob", "handjob", "masturbate", "masturbation",
  "orgasm", "erotic", "hentai", "onlyfans", "camgirl", "escort",
  "callgirl", "sex", "sexy", "sucking", "dildo", "vibrator",
  "threesome", "gangbang", "creampie", "cum", "cumming",
  // Hindi, Roman + Devanagari
  "chudai", "chodna", "chodne", "nangi", "nanga",
  "चुदाई", "चोदना", "चोद", "पोर्न", "सेक्स", "नंगी", "नंगा", "सेक्सी",
];

const PORN_PHRASES = [
  "sex video", "porn video", "nude pic", "nude photo", "sex chat",
  "video call sex", "sex call",
];

// --- Political ---------------------------------------------------------
// Party names, major politician names, political terms. "vote" and
// "sarkar" are deliberately NOT here — they are ordinary words in
// game / room contexts. "aap" is deliberately NOT here either — in
// Hinglish it is the everyday respectful "you" (आप), far more common
// than the party abbreviation.
const POLITICAL_WORDS = [
  "bjp", "congress", "bsp", "tmc", "dmk", "ncp", "rjd", "jdu",
  "cpi", "cpm", "modi", "kejriwal", "yogi", "mamata", "lalu",
  "politics", "politician", "rajneeti", "neta", "andolan", "dharna",
  "manifesto", "election", "chunav", "votebank",
  "राजनीति", "नेता", "चुनाव", "आंदोलन", "धरना", "बीजेपी", "कांग्रेस",
  "मोदी", "राहुल", "केजरीवाल", "योगी", "ममता", "लालू",
];

const POLITICAL_PHRASES = [
  "rahul gandhi", "amit shah", "narendra modi", "mamata banerjee",
  "lalu yadav", "aam aadmi party", "samajwadi party", "shiv sena",
  "trinamool", "vote bank", "aam aadmi",
];

// --- Other apps --------------------------------------------------------
// Competitor live / voice-chat apps and off-platform contact apps.
// Mentioning them in a message is blocked so users cannot be pulled
// off DarkVibeX. Deliberately NOT here: "yaha" (यहाँ = "here" in
// Hindi, far more common than the app name), "line" (an everyday
// English word), "imo" ("in my opinion"), "sakura" (cherry blossom).
const OTHER_APP_WORDS = [
  "bigo", "mico", "poppo", "tiktok", "yalla", "chamet", "likee",
  "tango", "oyaar", "livu", "hago", "liveme", "uplive",
  "nimo", "azar", "honeycam", "streamkar", "tinnistar",
  "whatsapp", "telegram", "instagram", "facebook", "snapchat",
  "viber", "wechat", "kakaotalk",
];

const OTHER_APP_PHRASES = [
  "bigo live", "mico live", "poppo live", "tiktok live", "yalla live",
  "tango live", "tinni star", "honey live", "live me", "up live",
  "nimo tv", "17 live",
];

// -----------------------------------------------------------------------

const LEET = {
  "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t",
  "@": "a", "$": "s", "!": "i",
};

function foldLeet(s) {
  return s.replace(/[013457@$!]/g, (c) => LEET[c] ?? c);
}

function collapseRepeats(s) {
  return s.replace(/(.)\1{2,}/gu, "$1");
}

/// Normalises one token (word) for comparison: lowercase, leet-fold,
/// 3+-letter runs collapsed.
function normalizeToken(token) {
  return collapseRepeats(foldLeet(String(token ?? "").toLowerCase()));
}

/// Splits text into letter tokens (Latin a-z + Devanagari) and
/// normalises each one. Leet digits are folded BEFORE splitting —
/// otherwise "p0rnhub" would split into "p" + "rnhub" and never match.
/// Numbers and punctuation are separators.
function tokenize(text) {
  const folded = foldLeet(String(text ?? "").toLowerCase());
  return folded
    .split(/[^a-z\u0900-\u097f]+/u)
    .filter(Boolean)
    .map(normalizeToken);
}

/// Normalised whole text with single spaces between tokens (for
/// phrase matching with word boundaries).
function normalizeText(text) {
  return tokenize(text).join(" ");
}

/// Fully squashed text: every separator removed, for catching
/// separator-obfuscated long words ("b.e.h.e.n.c.h.o.d").
function squashText(text) {
  return tokenize(text).join("");
}

const WORD_LISTS = {
  profanity: new Set(PROFANITY_WORDS.map(normalizeToken)),
  porn: new Set(PORN_WORDS.map(normalizeToken)),
  political: new Set(POLITICAL_WORDS.map(normalizeToken)),
  other_app: new Set(OTHER_APP_WORDS.map(normalizeToken)),
};

const PHRASE_LISTS = {
  profanity: [],
  porn: PORN_PHRASES.map(normalizeText),
  political: POLITICAL_PHRASES.map(normalizeText),
  other_app: OTHER_APP_PHRASES.map(normalizeText),
};

// Long severe words are also matched against the squashed text, so
// separator tricks ("b.e.h.e.n.c.h.o.d") still get caught. Only words
// of 4+ letters qualify, minus words that occur inside innocent
// words ("sex" in Essex/unisex, "cum" in document/cucumber, "rand"
// in random/brand, "gand" in Gandhi, "chut" in chutney, "lund" in
// blunder, "dick" in Dickens, "cock" in cocktail/peacock, "prick" in
// prickly, "modi" in modification, "yogi" in yogini). Those stay
// token-only, where they cannot false-positive.
const SQUASH_EXCLUDE = new Set([
  "sex", "cum", "rand", "gand", "chut", "lund", "dick", "cock",
  "prick", "modi", "yogi",
]);
const SQUASH_WORDS = {};
for (const category of CONTENT_CATEGORIES) {
  SQUASH_WORDS[category] = [...WORD_LISTS[category]].filter(
    (w) => w.length >= 4 && !SQUASH_EXCLUDE.has(w),
  );
}

/// Checks [text] against the banned lists.
/// Returns `{ blocked: false, category: null, matched: null }` when
/// clean, or `{ blocked: true, category, matched }` with the first
/// offending word/phrase found (category order: profanity, porn,
/// political, other_app).
export function checkContent(text) {
  const input = String(text ?? "");
  if (!input.trim()) return { blocked: false, category: null, matched: null };

  const tokens = tokenize(input);
  const normalized = tokens.join(" ");
  const squashed = tokens.join("");

  for (const category of CONTENT_CATEGORIES) {
    // 1. Whole-token match.
    for (const token of tokens) {
      if (WORD_LISTS[category].has(token)) {
        return { blocked: true, category, matched: token };
      }
    }
    // 2. Multi-word phrase match (word boundaries on both sides).
    // Every occurrence is checked — the first hit may sit inside a
    // token while a later one sits on a boundary.
    for (const phrase of PHRASE_LISTS[category]) {
      if (!phrase) continue;
      let from = 0;
      for (;;) {
        const idx = normalized.indexOf(phrase, from);
        if (idx === -1) break;
        const before = idx === 0 || normalized[idx - 1] === " ";
        const after = idx + phrase.length >= normalized.length || normalized[idx + phrase.length] === " ";
        if (before && after) {
          return { blocked: true, category, matched: phrase };
        }
        from = idx + 1;
      }
    }
    // 3. Squashed match for long words (separator obfuscation).
    for (const word of SQUASH_WORDS[category]) {
      if (squashed.includes(word)) {
        return { blocked: true, category, matched: word };
      }
    }
  }
  return { blocked: false, category: null, matched: null };
}
