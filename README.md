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

## Games
- Fruit Party: half-screen server-settled fruit game.
- Greedy Girl: half-screen 30-second food-multiplier game with server-authoritative bets, payouts, records, room Game Center entry, and an adult 21+ anime-style center character.
