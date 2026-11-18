# Gift Ribbon — VIP Gift Banner (R2 wiring)

The gift ribbon is the banner shown in the room when a VIP sends a gift.
It was the one missing VIP cosmetic (no "ribbon" kind in `cosmetics.js`).
4 tiers, colour and premium quality increasing with the VIP level; every
VIP level 1-18 gets its OWN banner — the tier base design plus the VIP
level written BIG and bold at runtime ("VIP N" is the most prominent text
on the banner), plus sender -> receiver on one line with an arrow, and
the gift name below.

## Tiers and R2 keys

Bucket `darkvibex-files`, public base
`https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev`, Content-Type
`image/webp`. Full URL = public base + `/` + key.

| Tier | VIP levels | Design | R2 key |
|---|---|---|---|
| basic (Sleek Gold) | 1-4 | Gold-dominant, crown + purple gem | `gift-ribbons/ribbon-sleek-gold.webp` (131,072 bytes) |
| premium (Purple & Gold Ornate) | 5-10 | Ornate black/gold frame, purple flames + gems | `gift-ribbons/ribbon-purple-gold.webp` (601,106 bytes) |
| royal (Royal Gold) | 11-15 | Purple-dominant, big gold crown, many purple gems (v2) | `gift-ribbons/ribbon-royal-gold.webp` (636,974 bytes) |
| super_premium (Dragon Super Premium) | 16-18 | Golden dragon wings with purple fire | `gift-ribbons/ribbon-dragon-super.webp` (573,586 bytes) |

All 4 are on R2 (verified by prefix listing + public-URL spot checks
HTTP 200 `image/webp`). The banner is 2736x912 (aspect ratio 3.0) with
its own background — it does NOT need transparency; the black background
is part of the banner.

## Display path

- **Worker** — `apps/worker/src/gift_ribbon_catalog.js` (tiers, strict
  level->tier mapping, `giftRibbonForVipLevel()` payload with VIP0
  falling back to the basic tier). The gift flow attaches the ribbon
  for the SENDER's VIP level:
  - `POST /api/gifts/send` response: `gift_ribbon` { tier, id, name,
    asset_key, url, vip_level } + `sender_name`, `receiver_name`,
    `gift_name`, `sender_vip_level`. The sender sees the banner
    immediately from this response.
  - `GET /api/rooms/:id/gift-events`: each event carries
    `sender_vip_level` + `gift_ribbon` (+ `sender_name` /
    `receiver_name` / `gift_name`, already present). Other members learn
    the ribbon from this feed (polling + the Agora live-gift path,
    which re-verifies the event from this feed).
- **Dart** — `apps/mobile/lib/vip/vip_visual_assets.dart` (tier data,
  `giftRibbonUrlForVipLevel()` with the basic-tier fallback,
  `giftRibbonUrlFromEvent()` preferring the server URL,
  per-tier centre-panel colours) and
  `apps/mobile/lib/widgets/gift_ribbon_banner.dart` (`GiftRibbonBanner`).
  The widget mirrors the verified previews
  (`~/workspace/darkvibex-vip-section/gift-ribbons/make_previews.py`):
  centre panel x 0.315-0.685, y 0.40-0.72 of the image; VIP level BIG
  and bold (120pt at 2736px wide), sender -> receiver (72pt), gift name
  (52pt). Panel colours: tier 1 gold plaque + dark bronze text; tiers
  2 and 4 black + gold text; tier 3 deep purple + gold text.
- **Room screen** — `apps/mobile/lib/screens/room_screen.dart`:
  `_showGiftRibbon()` sets `activeGiftRibbon` (4 s timer) and the build
  renders `GiftRibbonBanner` above the existing gift-effect bar
  (`Key('room-gift-ribbon')`). Wired at all three gift display call
  sites — the gift-events poll (`_loadRoomGiftEvents`), the live Agora
  gift handler (`_handleLiveGiftEvent`), and the sender side
  (`_sendGiftByDefinition`, from the send response) — each time AFTER
  the gift video/GLB dialog, so the banner also shows for video gifts.
  The ribbon is an ADDITION to the existing gift display (emoji fly-in
  / video / GLB), never a replacement. `gift-ribbons/` is a direct-R2
  prefix (`kDirectR2AssetPrefixes`): never pass the key through
  `backend.fileUrl()` / `/api/files` (400 `invalid_file_key`).

## Tests

- Worker: `apps/worker/test/gift_ribbon.test.js` — 4-tier mapping and
  boundaries, R2 URLs, VIP0 -> basic fallback, and source assertions
  that the send response and the gift-events feed include the ribbon
  and the sender/receiver/gift names.
- Dart: `apps/mobile/test/vip_visual_assets_test.dart` (gift ribbon
  tests) — tier mapping, R2 URLs, VIP0 -> basic fallback, server-URL
  preference / local fallback, per-tier panel colours.

Dart was NOT compiled in the VM (no Flutter SDK); the Dart files were
checked for balanced braces/parens/brackets only.
