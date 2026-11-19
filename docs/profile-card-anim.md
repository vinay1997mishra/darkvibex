# VIP Profile Card Animation (v4)

One animated profile card per VIP level 4–18. The animation plays as
the **background** of the profile card popup; the reference layout
(DP top centre, name + badges, medals, ID/Fans, bio, 4 buttons —
Send gifts, Follow, Chat, Mention) renders in the **foreground**
over it. (Vinay, 2026-11-19, approved.)

## Rules (Vinay, 2026-11-19)

- Animations run from **VIP4** onwards. **VIP1–3 have no profile
  card animation.**
- **No design has a bottom line** — every frame is open at the
  bottom, top and sides only.
- No design carries any text — no "VIP N", no "Profile Card". The
  VIP tag is already in the profile (it shows in the ID row).
- Each level's frame design is **different per VIP level** (v3
  designs: unique frame structure per level, not just animal/colour).
- The frame design stays exactly as in the starting still, camera
  completely static, **no zoom**, only the animal moves gently with
  its effect; the 5-second animation completes and ends calmly.
- The DP sits **in place of the frame's blue diamond** at the top
  centre (no diamond, the DP takes its position), and all the card
  text shows **above the deer**; the deer stays at the bottom.

## R2 keys (bucket `darkvibex-files`, direct public playback)

Videos play **direct from R2**, NOT via the Worker — same decision
as vehicle entry videos. Public base:
`https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev`

| Level | Animal | Video | Still (fallback) |
|------:|--------|-------|------------------|
| 4 | fox | `profile-card-anims/vip4-fox.mp4` | `profile-card-stills/vip4-fox.png` |
| 5 | deer | `profile-card-anims/vip5-deer.mp4` | `profile-card-stills/vip5-deer.png` |
| 6 | wolf | `profile-card-anims/vip6-wolf.mp4` | `profile-card-stills/vip6-wolf.png` |
| 7 | eagle | `profile-card-anims/vip7-eagle.mp4` | `profile-card-stills/vip7-eagle.png` |
| 8 | panther | `profile-card-anims/vip8-panther.mp4` | `profile-card-stills/vip8-panther.png` |
| 9 | cobra | `profile-card-anims/vip9-cobra.mp4` | `profile-card-stills/vip9-cobra.png` |
| 10 | lion | `profile-card-anims/vip10-lion.mp4` | `profile-card-stills/vip10-lion.png` |
| 11 | tiger | `profile-card-anims/vip11-tiger.mp4` | `profile-card-stills/vip11-tiger.png` |
| 12 | mammoth | `profile-card-anims/vip12-mammoth.mp4` | `profile-card-stills/vip12-mammoth.png` |
| 13 | gorilla | `profile-card-anims/vip13-gorilla.mp4` | `profile-card-stills/vip13-gorilla.png` |
| 14 | bear | `profile-card-anims/vip14-bear.mp4` | `profile-card-stills/vip14-bear.png` |
| 15 | kraken | `profile-card-anims/vip15-kraken.mp4` | `profile-card-stills/vip15-kraken.png` |
| 16 | leviathan | `profile-card-anims/vip16-leviathan.mp4` | `profile-card-stills/vip16-leviathan.png` |
| 17 | phoenix | `profile-card-anims/vip17-phoenix.mp4` | `profile-card-stills/vip17-phoenix.png` |
| 18 | dragon | `profile-card-anims/vip18-dragon.mp4` | `profile-card-stills/vip18-dragon.png` |

Videos are 5-second MP4s (832×896 canvas, wide horizontal frame
content inside). Stills are the v3 designs converted to PNG (VIP4:
its V1 clean frame); the app shows the still while the video loads,
after it finishes, and whenever the video cannot play — never a
black box.

## Code

- Worker: `apps/worker/src/vip_profile_card_anim_catalog.js`
  (`profileCardAnimForVipLevel`, `profileCardAnimVisualForVipLevel`,
  `profileCardAnimUrlForVipLevel`,
  `profileCardAnimStillUrlForVipLevel`). `vipVisualsForLevel()`
  exposes it as `profile_card_anim` (null for VIP1–3). The visual
  shape is the standard one: `asset_key` = still PNG (fallback),
  `video_key` = animation MP4, `media_type: "video"`,
  `animation_type: "play_once"`, `animation_ms: 5000`.
- Dart: `apps/mobile/lib/vip/vip_visual_assets.dart`
  (`vipProfileCardAnimAnimals`, `profileCardAnimVideoUrlForVipLevel`,
  `profileCardAnimStillUrlForVipLevel`,
  `profileCardAnimVideoUrlForDisplay`) and
  `apps/mobile/lib/widgets/profile_card_anim_background.dart`
  (`ProfileCardAnimBackground`, `ProfileCardAnimBackground.forVipLevel`)
  — `video_player`, plays once, no loop, falls back to the still.
  The caller passes the reference-layout foreground as `child`.
  Dart was NOT compiled in the VM (no Flutter SDK); real-device test
  is still needed before release.
- Tests: `apps/worker/test/vip_visual_assets.test.js` (3 new tests),
  `apps/mobile/test/vip_visual_assets_test.dart` (4 new tests).
