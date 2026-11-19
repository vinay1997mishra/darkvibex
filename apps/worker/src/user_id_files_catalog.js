// DarkVibeX — Private User-ID Files Catalog
//
// ALL user info files live in the PRIVATE R2 bucket "darkvibex-id-info"
// (Vinay, 2026-11-19: "isme hi user ki saari info save hogi ... id no.
// Id dp sms and all", "Private wale"). The bucket has NO public access:
// no r2.dev URL, no public link. Files are reachable ONLY through the
// Worker routes PUT/GET /api/user-files, which require a session and
// only ever serve a user their OWN files (owner-only; no public URL
// exists to leak).
//
// This is separate from the public assets bucket "darkvibex-files"
// (FILES binding) which holds VIP frames, vehicles, medals, panda
// emotes and other assets that the app plays DIRECTLY from public R2
// URLs. User info must NEVER go there.
//
// Key layout (all under the owning user's id):
//   users/<userId>/id-number/<timestamp>.<ext>  — ID number documents
//   users/<userId>/dp/<timestamp>.<ext>         — ID DP (profile pic)
//   users/<userId>/sms/<timestamp>.<ext>        — SMS files/attachments
//   users/<userId>/misc/<timestamp>.<ext>       — everything else
//
// Categories are fixed so the Worker can authorise a key by its shape
// alone: a key is valid only when it is users/<actor>/<category>/... and
// the <actor> matches the session user. Nothing else is writable or
// readable in this bucket.

/// The 4 file categories in the private bucket.
export const USER_ID_FILE_CATEGORIES = ["id-number", "dp", "sms", "misc"];

/// Display label per category.
export const USER_ID_FILE_CATEGORY_LABELS = {
  "id-number": "ID Number",
  dp: "ID DP",
  sms: "SMS",
  misc: "Other",
};

/// True when [category] is one of the 4 categories.
export function isUserIdFileCategory(category) {
  return (
    typeof category === "string" &&
    USER_ID_FILE_CATEGORIES.includes(category)
  );
}

/// R2 key for a user-info file. [userId] is the owning user, [category]
/// is id-number/dp/sms/misc, [fileName] is the file name (timestamp +
/// extension, e.g. "1731936000000.jpg"). Returns null for a bad
/// category, empty user id, or an unsafe file name.
export function userIdFileKeyForCategory(userId, category, fileName) {
  const owner = String(userId ?? "").trim();
  const name = String(fileName ?? "").trim();
  if (!owner || !isUserIdFileCategory(category) || !name) return null;
  if (
    name.includes("..") ||
    name.startsWith("/") ||
    name.includes("/") ||
    !/^[a-zA-Z0-9._-]+$/.test(name)
  ) {
    return null;
  }
  return `users/${owner}/${category}/${name}`;
}

/// The category of a private-bucket key, or null when the key is not a
/// user-info file key.
export function userIdFileCategoryFromKey(key) {
  if (typeof key !== "string") return null;
  const match = /^users\/([^/]+)\/([^/]+)\/[^/]+$/.exec(key.trim());
  if (match == null) return null;
  const category = match[2];
  return isUserIdFileCategory(category) ? category : null;
}

/// The owning user id of a private-bucket key, or null when the key is
/// not a user-info file key.
export function userIdFileOwnerFromKey(key) {
  if (typeof key !== "string") return null;
  const match = /^users\/([^/]+)\/([^/]+)\/[^/]+$/.exec(key.trim());
  if (match == null) return null;
  return isUserIdFileCategory(match[2]) ? match[1] : null;
}

/// True when [key] is a valid user-info file key in the private bucket
/// (users/<userId>/<category>/<file> with a known category).
export function isUserIdFileKey(key) {
  return userIdFileCategoryFromKey(key) != null;
}

/// True when [key] belongs to [userId] (the owner check the Worker
/// routes use: a user may only read/write their own files).
export function userIdFileKeyBelongsTo(key, userId) {
  const owner = userIdFileOwnerFromKey(key);
  return owner != null && owner === String(userId ?? "").trim();
}
