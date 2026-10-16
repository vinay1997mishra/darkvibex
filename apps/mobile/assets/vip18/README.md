# DarkVibeX VIP 1–18 Entrance and Full Profile Cards

This feature includes 36 separate SVG assets:
- `entrance_vip_01.svg` … `entrance_vip_18.svg`
- `profile_vip_01.svg` … `profile_vip_18.svg`

## Integration
- Store categories are separate: Entrance uses `kind: entry`; Profile uses `kind: profile_card`.
- Each catalog item has a stable ID, VIP 1–18 gate, 30-day ownership duration, and owner-configurable coin price (currently 0 under the existing catalog policy).
- The Store previews use the corresponding SVG asset with live name, ID, VIP badge and avatar rendered by Flutter.
- The equipped profile-card ID is returned by the user-profile endpoint and styles the public profile header with its matching SVG.
- The room seat label uses the equipped entrance SVG for users whose active entry cosmetic is one of the new VIP nameplates.

## Scope note
The SVGs are original scalable vector assets, not a flattened poster or a pixel-for-pixel trace of the supplied concept image. The room polls membership and plays the equipped VIP nameplate for two seconds when a newly arrived member has one equipped; the same nameplate remains visible by the seated user's name. Invisible-entry preference suppresses the arrival display.
