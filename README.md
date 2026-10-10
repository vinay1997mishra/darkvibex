# DarkVibeX

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
