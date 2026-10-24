# DarkVibeX

- Room identity/UI update: stable 7-digit Profile ID = Room ID, compact 36–42 seats, cleaned room DP menu and notice labels.

DarkVibeX is a clean-room social voice-room app base derived from the proven Tinni Star architecture, with a new app identity and no Agency, BD, or Host business hierarchy.

## Core direction
- Voice rooms, seats, chat, profiles, gifts, games, wallet, moderation and realtime transport.
- Cloudflare Worker + D1 + R2 backend.
- Owner-controlled configuration.
- No Agency / BD / Host role, payout, target, invite, hierarchy, or dashboard flows.
- No secrets committed to the repository.

Working Android package: `com.darkvibex.app`.

## Deployment
Cloudflare Workers Builds is connected to the `main` branch. Production Worker source lives in `apps/worker`.

- VIP system: VIP1–VIP18 with Coin Seller EXP progression and premium privileges.
- Latest main APK build must include the merged VIP1–VIP18 entrance nameplates and full profile-card cosmetics.

## Games
- Fruit Party: half-screen server-settled fruit game.
- Greedy Girl: half-screen 30-second food-multiplier game with server-authoritative bets, payouts, records, and room Game Center entry.

## Latest stability fix (2026-10-21)

- Persisted DarkVibeX accounts refresh expired access tokens without changing the user's ID.
- My Room is refreshed before the app offers room creation, preventing a stale local list from suggesting a duplicate room.
- Room exit remains separate from account sign-out.
