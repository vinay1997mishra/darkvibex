# DarkVibeX Safe Base Contract

## Identity
- App name: DarkVibeX
- Working Android application id: `com.darkvibex.app`
- Worker name: `darkvibex-api`
- D1 database: `darkvibex-db`
- R2 bucket: `darkvibex-files`

## Reused product areas
The migration may reuse the proven Tinni Star architecture for:
- voice rooms and seats
- realtime room presence
- direct messages
- user profiles and IDs
- gifts and effects
- games
- wallet / coin flows
- moderation
- owner configuration

## Permanently excluded legacy hierarchy
DarkVibeX must not contain the old Agency, BD, or Host business hierarchy.

Removal means:
- no role enum/value
- no signup or invitation flow
- no dashboard
- no target/commission rule
- no payout/withdrawal rule tied to those roles
- no API endpoint or permission
- no D1 table/column used only for that hierarchy
- no hidden fallback that defaults a sender/user into a removed role

If a migration introduces one of those legacy role values outside the explicit rejection policy files, CI must fail.

## Secrets
API keys, passwords, signing files, OAuth secrets and voice credentials must never be committed.
