export const BLOCKED_LEGACY_ROLES = new Set(["host", "agency", "bd"]);

export const ALLOWED_ROLES = new Set([
  "user",
  "room_owner",
  "room_admin",
  "moderator",
  "coin_seller",
  "merchant",
  "platform_owner",
]);

export function normalizeRole(value) {
  const role = String(value ?? "user").trim().toLowerCase();

  if (BLOCKED_LEGACY_ROLES.has(role)) {
    throw new Error("Legacy hierarchy role is not supported by DarkVibeX.");
  }

  return ALLOWED_ROLES.has(role) ? role : "user";
}
