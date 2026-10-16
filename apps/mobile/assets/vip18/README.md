# DarkVibeX VIP 1–18 Entrance and Full Profile Cards

This feature adds 18 independent `entry` cosmetics and 18 independent `profile_card` cosmetics to the worker catalog.

- Store categories remain separate: **Entrance** uses `kind: entry`; **Profile** uses `kind: profile_card`.
- Each item has a stable ID, its own VIP requirement (VIP1–VIP18), a 30-day duration, and an owner-configurable coin price (currently 0, matching the existing catalog policy).
- The Store uses a horizontal animated-style nameplate preview for entrance items and the full profile-card preview for profile items.
- Profile-card previews include live display name, public ID, VIP badge, and avatar placeholder/image rather than using a DP-only frame.

## Important implementation note

These are app-rendered scalable UI designs, not a flattened poster. This keeps text and user data dynamic and allows each of the 36 styles to be rendered independently. Actual production room-entry triggering and applying the selected full-card style to the public profile surface must use the equipped cosmetic state in those surfaces; this catalog/store PR does not claim that end-to-end room/profile wiring is finished.
