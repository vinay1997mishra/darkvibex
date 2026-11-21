import 'package:darkvibex/vip/vip_visual_assets.dart';
import 'package:darkvibex/widgets/profile_card_anim_background.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frame animals cover VIP1-18 (Cat 1, Swan 2, Dolphin 3, Fox 4)', () {
    expect(vipFrameAnimals.length, 18);
    expect(vipFrameAnimals[1], 'cat');
    expect(vipFrameAnimals[2], 'swan');
    expect(vipFrameAnimals[3], 'dolphin');
    expect(vipFrameAnimals[4], 'fox');
    expect(vipFrameAnimals[5], 'deer');
    expect(vipFrameAnimals[13], 'gorilla');
    expect(vipFrameAnimals[17], 'phoenix');
    expect(vipFrameAnimals[18], 'dragon');
    expect(vipFrameAnimals[0], isNull);
    expect(vipFrameAnimals[19], isNull);
  });

  test('frame still URLs point at the R2 frames/ PNGs', () {
    expect(
      vipFrameStillUrlForVipLevel(13),
      '$kVipVisualR2PublicBaseUrl/frames/vip13-gorilla-transparent.png',
    );
    expect(
      vipFrameStillUrlForVipLevel(7),
      '$kVipVisualR2PublicBaseUrl/frames/vip7-eagle-transparent.png',
    );
    expect(
      vipFrameStillUrlForVipLevel(1),
      '$kVipVisualR2PublicBaseUrl/frames/vip1-cat-transparent.png',
    );
    expect(
      vipFrameStillUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/frames/vip4-fox-transparent.png',
    );
    expect(vipFrameStillUrlForVipLevel(0), isNull);
    expect(vipFrameStillUrlForVipLevel(19), isNull);
  });

  test('frame video URLs point at the R2 frames/ WebMs', () {
    expect(
      vipFrameVideoUrlForVipLevel(17),
      '$kVipVisualR2PublicBaseUrl/frames/vip17-phoenix-transparent.webm',
    );
    // VIP1-4 frames are static stills: no WebM.
    expect(vipFrameVideoUrlForVipLevel(1), isNull);
    expect(vipFrameVideoUrlForVipLevel(4), isNull);
  });

  test('frame VAP URLs point at the R2 vap/ mp4s', () {
    // Tencent VAP v1 (alpha mask LEFT, RGB RIGHT) — played by
    // VipFrameAlphaVideo via flutter_vap_player (enableOldVersion).
    expect(
      vipFrameVapUrlForVipLevel(13),
      '$kVipVisualR2PublicBaseUrl/vap/vip13-gorilla.mp4',
    );
    expect(
      vipFrameVapUrlForVipLevel(5),
      '$kVipVisualR2PublicBaseUrl/vap/vip5-deer.mp4',
    );
    // VIP1-4 frames are static stills: no VAP video.
    expect(vipFrameVapUrlForVipLevel(1), isNull);
    expect(vipFrameVapUrlForVipLevel(4), isNull);
    expect(vipFrameVapUrlForVipLevel(19), isNull);
    for (var level = 5; level <= 18; level++) {
      expect(
        vipFrameVapKeys[level],
        'vap/vip$level-${vipFrameAnimals[level]}.mp4',
      );
    }
  });

  test('vipFrameVapUrlForDisplay returns the VAP URL only for the animal frame',
      () {
    // The displayed frame IS the animal still (or no frame configured,
    // so the animal still is shown): the VAP video plays.
    expect(
      vipFrameVapUrlForDisplay('frames/vip13-gorilla-transparent.png', 13),
      '$kVipVisualR2PublicBaseUrl/vap/vip13-gorilla.mp4',
    );
    expect(
      vipFrameVapUrlForDisplay('', 13),
      '$kVipVisualR2PublicBaseUrl/vap/vip13-gorilla.mp4',
    );
    expect(
      vipFrameVapUrlForDisplay(null, 13),
      '$kVipVisualR2PublicBaseUrl/vap/vip13-gorilla.mp4',
    );
    // A custom/Owner frame has no VAP video: the still shows only.
    expect(
      vipFrameVapUrlForDisplay('custom-assets/frame-123.png', 13),
      isNull,
    );
    // VIP1-4 have no VAP video (static stills only).
    expect(vipFrameVapUrlForDisplay('', 1), isNull);
    expect(vipFrameVapUrlForDisplay('', 4), isNull);
  });

  test('vipFrameVapUrlForDisplay plays the VIP13 second frame VAP for its still',
      () {
    // Vinay's second VIP13 frame has its own VAP video: when the
    // displayed still IS the second-frame still, its VAP plays.
    expect(
      vipFrameVapUrlForDisplay(vip13SecondFrameStillKey, 13),
      vip13SecondFrameVapUrl,
    );
    expect(
      vip13SecondFrameStillUrl,
      '$kVipVisualR2PublicBaseUrl/frames/vip13-gorilla-second-frame-transparent.png',
    );
    expect(
      vip13SecondFrameVapUrl,
      '$kVipVisualR2PublicBaseUrl/vap/vip13-gorilla-second-frame.mp4',
    );
    // The original animal frame still plays its own VAP.
    expect(
      vipFrameVapUrlForDisplay('frames/vip13-gorilla-transparent.png', 13),
      '$kVipVisualR2PublicBaseUrl/vap/vip13-gorilla.mp4',
    );
    // The second-frame still on another level is not a VAP frame.
    expect(
      vipFrameVapUrlForDisplay(vip13SecondFrameStillKey, 12),
      isNull,
    );
  });

  test('entry effect URLs point at the R2 entry-effects/ PNGs', () {
    expect(
      vipEntryEffectUrlForVipLevel(10),
      '$kVipVisualR2PublicBaseUrl/entry-effects/vip10-entry.png',
    );
    expect(
      vipEntryEffectUrlForVipLevel(1),
      '$kVipVisualR2PublicBaseUrl/entry-effects/vip1-entry.png',
    );
    expect(
      vipEntryEffectUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/entry-effects/vip4-entry.png',
    );
    expect(vipEntryEffectUrlForVipLevel(0), isNull);
    expect(vipEntryEffectUrlForVipLevel(19), isNull);
  });

  test('entry effect circle geometry is present and in range for all levels',
      () {
    for (var level = 1; level <= 18; level++) {
      final circle = vipEntryEffectCircles[level];
      expect(circle, isNotNull, reason: 'VIP$level circle missing');
      expect(circle!.centerX, greaterThan(0));
      expect(circle.centerX, lessThan(0.5));
      expect(circle.centerY, greaterThan(0));
      expect(circle.centerY, lessThan(1));
      expect(circle.diameter, greaterThan(0.2));
      expect(circle.diameter, lessThan(1));
      final aspect = vipEntryEffectAspectRatios[level];
      expect(aspect, isNotNull, reason: 'VIP$level aspect missing');
      expect(aspect!, greaterThan(1.5));
      expect(aspect, lessThan(5));
    }
    // VIP4 is the thin bar: aspect 1.808, circle from the thin PNG.
    expect(vipEntryEffectAspectRatios[4], 1.808);
    expect(vipEntryEffectCircles[4]?.centerX, 0.150);
    expect(vipEntryEffectCircles[4]?.centerY, 0.550);
    expect(vipEntryEffectCircles[4]?.diameter, 0.240);
  });

  test('tag URLs point at the R2 vip-tags/ PNGs', () {
    expect(
      vipTagUrlForVipLevel(18),
      '$kVipVisualR2PublicBaseUrl/vip-tags/vip18-tag.png',
    );
    expect(
      vipTagUrlForVipLevel(5),
      '$kVipVisualR2PublicBaseUrl/vip-tags/vip5-tag.png',
    );
    expect(
      vipTagUrlForVipLevel(1),
      '$kVipVisualR2PublicBaseUrl/vip-tags/vip1-tag.png',
    );
    expect(
      vipTagUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/vip-tags/vip4-tag.png',
    );
    expect(vipTagUrlForVipLevel(0), isNull);
    expect(vipTagUrlForVipLevel(19), isNull);
  });

  test('medal URLs point at the R2 vip-medals/ PNGs (VIP1-4 only)', () {
    expect(
      vipMedalUrlForVipLevel(1),
      '$kVipVisualR2PublicBaseUrl/vip-medals/vip1-medal.png',
    );
    expect(
      vipMedalUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/vip-medals/vip4-medal.png',
    );
    expect(vipMedalUrlForVipLevel(5), isNull);
    expect(vipMedalUrlForVipLevel(0), isNull);
    expect(vipMedalKeys.length, 4);
  });

  test('scenic banner URLs point at the R2 profile-banners/ PNGs (VIP1-4)',
      () {
    expect(
      vipScenicBannerUrlForVipLevel(1),
      '$kVipVisualR2PublicBaseUrl/profile-banners/vip1-banner.png',
    );
    expect(
      vipScenicBannerUrlForVipLevel(2),
      '$kVipVisualR2PublicBaseUrl/profile-banners/vip2-scenic.png',
    );
    expect(
      vipScenicBannerUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/profile-banners/vip4-scenic.png',
    );
    expect(vipScenicBannerUrlForVipLevel(5), isNull);
    expect(vipScenicBannerUrlForVipLevel(0), isNull);
    expect(vipScenicBannerKeys.length, 4);
  });

  test('resolver sends R2 asset keys direct and other keys via fileUrl', () {
    String fileUrl(String key) => 'https://worker.example/api/files?key=$key';
    expect(
      resolveVipVisualAssetUrl(
          'frames/vip13-gorilla-transparent.png', fileUrl),
      '$kVipVisualR2PublicBaseUrl/frames/vip13-gorilla-transparent.png',
    );
    expect(
      resolveVipVisualAssetUrl('entry-effects/vip10-entry.png', fileUrl),
      '$kVipVisualR2PublicBaseUrl/entry-effects/vip10-entry.png',
    );
    expect(
      resolveVipVisualAssetUrl('vip-tags/vip18-tag.png', fileUrl),
      '$kVipVisualR2PublicBaseUrl/vip-tags/vip18-tag.png',
    );
    expect(
      resolveVipVisualAssetUrl('vip-medals/vip4-medal.png', fileUrl),
      '$kVipVisualR2PublicBaseUrl/vip-medals/vip4-medal.png',
    );
    expect(
      resolveVipVisualAssetUrl('profile-banners/vip4-scenic.png', fileUrl),
      '$kVipVisualR2PublicBaseUrl/profile-banners/vip4-scenic.png',
    );
    expect(
      resolveVipVisualAssetUrl('vehicles/vip5-deer.mp4', fileUrl),
      '$kVipVisualR2PublicBaseUrl/vehicles/vip5-deer.mp4',
    );
    expect(
      resolveVipVisualAssetUrl('vap/vip13-gorilla.mp4', fileUrl),
      '$kVipVisualR2PublicBaseUrl/vap/vip13-gorilla.mp4',
    );
    expect(
      resolveVipVisualAssetUrl(
          'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev/frames/vip13-gorilla-transparent.png',
          fileUrl),
      'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev/frames/vip13-gorilla-transparent.png',
    );
    expect(
      resolveVipVisualAssetUrl('users/abc/avatar-123.png', fileUrl),
      'https://worker.example/api/files?key=users/abc/avatar-123.png',
    );
    expect(resolveVipVisualAssetUrl('', fileUrl), '');
    expect(isDirectR2AssetKey('frames/vip5-deer-transparent.webm'), isTrue);
    expect(isDirectR2AssetKey('users/abc/avatar-1.png'), isFalse);
  });

  test('gift ribbon tiers cover VIP1-18: 4 tiers, boundaries at 1/5/11/16',
      () {
    expect(giftRibbonStyles.length, 4);
    expect(giftRibbonStyles[GiftRibbonTier.basic]?.asset,
        'gift-ribbons/ribbon-sleek-gold.webp');
    expect(giftRibbonStyles[GiftRibbonTier.premium]?.asset,
        'gift-ribbons/ribbon-purple-gold.webp');
    expect(giftRibbonStyles[GiftRibbonTier.royal]?.asset,
        'gift-ribbons/ribbon-royal-gold.webp');
    expect(giftRibbonStyles[GiftRibbonTier.superPremium]?.asset,
        'gift-ribbons/ribbon-dragon-super.webp');
    expect(giftRibbonTierForVipLevel(1), GiftRibbonTier.basic);
    expect(giftRibbonTierForVipLevel(4), GiftRibbonTier.basic);
    expect(giftRibbonTierForVipLevel(5), GiftRibbonTier.premium);
    expect(giftRibbonTierForVipLevel(10), GiftRibbonTier.premium);
    expect(giftRibbonTierForVipLevel(11), GiftRibbonTier.royal);
    expect(giftRibbonTierForVipLevel(15), GiftRibbonTier.royal);
    expect(giftRibbonTierForVipLevel(16), GiftRibbonTier.superPremium);
    expect(giftRibbonTierForVipLevel(18), GiftRibbonTier.superPremium);
    expect(giftRibbonTierForVipLevel(0), isNull);
    expect(giftRibbonTierForVipLevel(19), isNull);
    expect(giftRibbonForVipLevel(0), isNull);
    for (var level = 1; level <= 18; level++) {
      expect(giftRibbonForVipLevel(level), isNotNull);
    }
  });

  test('gift ribbon URLs point at the R2 gift-ribbons/ WebPs', () {
    String fileUrl(String key) => 'https://worker.example/api/files?key=$key';
    expect(
      giftRibbonUrlForVipLevel(2),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-sleek-gold.webp',
    );
    expect(
      giftRibbonUrlForVipLevel(7),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-purple-gold.webp',
    );
    expect(
      giftRibbonUrlForVipLevel(13),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-royal-gold.webp',
    );
    expect(
      giftRibbonUrlForVipLevel(17),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-dragon-super.webp',
    );
    expect(giftRibbonKeyForVipLevel(0), isNull);
    expect(giftRibbonKeyForVipLevel(19), isNull);
    // VIP0 / no-VIP falls back to the basic tier (mirrors the Worker).
    expect(
      giftRibbonUrlForVipLevel(0),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-sleek-gold.webp',
    );
    expect(
      giftRibbonUrlForVipLevel(19),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-sleek-gold.webp',
    );
    expect(kGiftRibbonAspectRatio, 3.0);
    expect(
      resolveVipVisualAssetUrl(
          'gift-ribbons/ribbon-royal-gold.webp', fileUrl),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-royal-gold.webp',
    );
    expect(isDirectR2AssetKey('gift-ribbons/ribbon-dragon-super.webp'),
        isTrue);
  });

  test('gift ribbon event resolution prefers the server ribbon URL', () {
    const serverUrl =
        'https://pub-0577c2bbe5f6499eb0dd9e44ec5cae8a.r2.dev/gift-ribbons/ribbon-royal-gold.webp';
    final event = <String, dynamic>{
      'gift_ribbon': <String, dynamic>{
        'tier': 'royal',
        'id': 'ribbon_royal_gold',
        'asset_key': 'gift-ribbons/ribbon-royal-gold.webp',
        'url': serverUrl,
        'vip_level': 13,
      },
      'sender_vip_level': 13,
    };
    expect(giftRibbonVipLevelFromEvent(event), 13);
    expect(giftRibbonUrlFromEvent(event), serverUrl);
    // No server ribbon: local mapping by sender VIP level.
    final localEvent = <String, dynamic>{'sender_vip_level': 7};
    expect(giftRibbonVipLevelFromEvent(localEvent), 7);
    expect(
      giftRibbonUrlFromEvent(localEvent),
      '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-purple-gold.webp',
    );
    // No VIP at all: basic tier.
    expect(giftRibbonUrlFromEvent(<String, dynamic>{}),
        '$kVipVisualR2PublicBaseUrl/gift-ribbons/ribbon-sleek-gold.webp');
  });

  test('gift ribbon panel colours match the preview tiers', () {
    // Tier 1: gold plaque + dark bronze text.
    final basic = giftRibbonPanelColorsForTier(GiftRibbonTier.basic);
    expect(basic.panel, 0xFFD09E48);
    expect(basic.vipText, 0xFF785514);
    // Tier 3: deep purple + gold text.
    final royal = giftRibbonPanelColorsForTier(GiftRibbonTier.royal);
    expect(royal.panel, 0xFF300873);
    expect(royal.vipText, 0xFFE8C882);
    // Tiers 2 and 4: black + gold text.
    final premium = giftRibbonPanelColorsForTier(GiftRibbonTier.premium);
    expect(premium.panel, 0xFF050508);
    expect(premium.vipText, 0xFFE8C882);
    final superPremium =
        giftRibbonPanelColorsForTier(GiftRibbonTier.superPremium);
    expect(superPremium.panel, 0xFF050508);
    // Level mapping: VIP13 is royal purple, VIP2 is the gold plaque.
    expect(giftRibbonPanelColorsForVipLevel(13).panel, 0xFF300873);
    expect(giftRibbonPanelColorsForVipLevel(2).panel, 0xFFD09E48);
    expect(giftRibbonPanelColorsForVipLevel(0).panel, 0xFFD09E48);
  });

  test('profile card animation URLs point at the R2 profile-card-anims/ mp4s (VIP5-18 only)',
      () {
    // v4 animations run from VIP5 onwards; VIP1-4 have none (VIP4's
    // old screenshot video was retired 2026-11-21 — still only, clean
    // frame).
    expect(vipProfileCardAnimAnimals.length, 14);
    expect(vipProfileCardAnimAnimals[4], isNull);
    expect(vipProfileCardAnimAnimals[5], 'deer');
    expect(vipProfileCardAnimAnimals[10], 'lion');
    expect(vipProfileCardAnimAnimals[16], 'leviathan');
    expect(vipProfileCardAnimAnimals[18], 'dragon');
    expect(vipProfileCardAnimAnimals[1], isNull);
    expect(vipProfileCardAnimAnimals[3], isNull);
    expect(profileCardAnimVideoUrlForVipLevel(4), isNull);
    expect(
      profileCardAnimVideoUrlForVipLevel(5),
      '$kVipVisualR2PublicBaseUrl/profile-card-anims/vip5-deer.mp4',
    );
    expect(
      profileCardAnimVideoUrlForVipLevel(18),
      '$kVipVisualR2PublicBaseUrl/profile-card-anims/vip18-dragon.mp4',
    );
    expect(profileCardAnimVideoUrlForVipLevel(1), isNull);
    expect(profileCardAnimVideoUrlForVipLevel(3), isNull);
    expect(profileCardAnimVideoUrlForVipLevel(0), isNull);
    expect(profileCardAnimVideoUrlForVipLevel(19), isNull);
    for (var level = 5; level <= 18; level++) {
      expect(
        vipProfileCardAnimVideoKeys[level],
        'profile-card-anims/vip$level-${vipProfileCardAnimAnimals[level]}.mp4',
      );
    }
    // VIP1-4 have a still pic only, no video.
    expect(vipProfileCardStillAnimals.length, 18);
    expect(vipProfileCardStillAnimals[1], 'cat');
    expect(vipProfileCardStillAnimals[2], 'swan');
    expect(vipProfileCardStillAnimals[3], 'dolphin');
    expect(vipProfileCardStillAnimals[4], 'fox');
    for (var level = 1; level <= 18; level++) {
      expect(
        vipProfileCardAnimStillKeys[level],
        level == 4
            ? 'profile-card-frames/vip4-fox.webp'
            : 'profile-card-stills/vip$level-${vipProfileCardStillAnimals[level]}.png',
      );
    }
  });

  test('profile card animation still URLs point at the R2 profile-card-stills/ PNGs',
      () {
    expect(
      profileCardAnimStillUrlForVipLevel(1),
      '$kVipVisualR2PublicBaseUrl/profile-card-stills/vip1-cat.png',
    );
    expect(
      profileCardAnimStillUrlForVipLevel(2),
      '$kVipVisualR2PublicBaseUrl/profile-card-stills/vip2-swan.png',
    );
    expect(
      profileCardAnimStillUrlForVipLevel(3),
      '$kVipVisualR2PublicBaseUrl/profile-card-stills/vip3-dolphin.png',
    );
    // VIP4's still is the new clean frame WebP, not the old
    // screenshot PNG.
    expect(
      profileCardAnimStillUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip4-fox.webp',
    );
    expect(
      profileCardAnimStillUrlForVipLevel(5),
      '$kVipVisualR2PublicBaseUrl/profile-card-stills/vip5-deer.png',
    );
    expect(
      profileCardAnimStillUrlForVipLevel(18),
      '$kVipVisualR2PublicBaseUrl/profile-card-stills/vip18-dragon.png',
    );
    expect(profileCardAnimStillUrlForVipLevel(0), isNull);
    expect(profileCardAnimStillUrlForVipLevel(19), isNull);
  });

  test('profileCardAnimVideoUrlForDisplay plays only the level own animation',
      () {
    // The displayed card IS the level's own animation (or no key
    // configured, so the level animation is used): the video plays.
    expect(
      profileCardAnimVideoUrlForDisplay(
          'profile-card-anims/vip13-gorilla.mp4', 13),
      '$kVipVisualR2PublicBaseUrl/profile-card-anims/vip13-gorilla.mp4',
    );
    expect(
      profileCardAnimVideoUrlForDisplay('', 13),
      '$kVipVisualR2PublicBaseUrl/profile-card-anims/vip13-gorilla.mp4',
    );
    expect(
      profileCardAnimVideoUrlForDisplay(null, 13),
      '$kVipVisualR2PublicBaseUrl/profile-card-anims/vip13-gorilla.mp4',
    );
    // A custom/Owner video key has no v4 animation: still only.
    expect(
      profileCardAnimVideoUrlForDisplay('custom-assets/card-123.mp4', 13),
      isNull,
    );
    // VIP1-4 have no animation (static cards only) — VIP4's old
    // screenshot video key resolves to nothing, not the old MP4.
    expect(profileCardAnimVideoUrlForDisplay('', 1), isNull);
    expect(profileCardAnimVideoUrlForDisplay('', 3), isNull);
    expect(profileCardAnimVideoUrlForDisplay('', 4), isNull);
    expect(
      profileCardAnimVideoUrlForDisplay(
          'profile-card-anims/vip4-fox.mp4', 4),
      isNull,
    );
  });

  test('VIP4 shows the new clean frame, never the screenshot assets',
      () {
    // VIP4 (fox) is still only: the clean frame WebP as its still,
    // no animation video from any helper, and the old screenshot keys
    // resolve from nowhere.
    expect(
      profileCardAnimStillUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip4-fox.webp',
    );
    expect(
      profileCardFrameStillUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip4-fox.webp',
    );
    expect(profileCardAnimVideoUrlForVipLevel(4), isNull);
    expect(profileCardFrameAnimVideoUrlForVipLevel(4), isNull);
    expect(
      profileCardAnimVideoUrlForDisplay(
          'profile-card-anims/vip4-fox.mp4', 4),
      isNull,
    );
    expect(profileCardFrameAnimVideoUrlForDisplay('', 4), isNull);
    expect(vipProfileCardAnimVideoKeys[4], isNull);
    expect(
      vipProfileCardAnimStillKeys[4],
      'profile-card-frames/vip4-fox.webp',
    );
    for (final String key in vipProfileCardAnimVideoKeys.values) {
      expect(key, isNot(contains('vip4-fox')));
    }
    for (final String key in vipProfileCardAnimStillKeys.values) {
      expect(key, isNot(contains('profile-card-stills/vip4-fox.png')));
    }
    for (final String key in vipProfileCardAnimStillKeys.values) {
      expect(key, isNot(contains('profile-card-anims/vip4-fox.mp4')));
    }
  });

  test('profile card frame still URLs point at the R2 profile-card-frames/ WebPs (VIP1-18)',
      () {
    // Every level 1-18 has a frame still; VIP1-3 use the v4 still,
    // VIP4 the new clean v3-style fox frame, VIP16 the clean wide
    // frame, the rest the v3 design.
    expect(vipProfileCardFrameStillKeys.length, 18);
    expect(
      profileCardFrameStillUrlForVipLevel(1),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip1-cat.webp',
    );
    expect(
      profileCardFrameStillUrlForVipLevel(2),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip2-swan.webp',
    );
    expect(
      profileCardFrameStillUrlForVipLevel(3),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip3-dolphin.webp',
    );
    expect(
      profileCardFrameStillUrlForVipLevel(4),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip4-fox.webp',
    );
    expect(
      profileCardFrameStillUrlForVipLevel(5),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip5-deer.webp',
    );
    expect(
      profileCardFrameStillUrlForVipLevel(16),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip16-leviathan.webp',
    );
    expect(
      profileCardFrameStillUrlForVipLevel(18),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip18-dragon.webp',
    );
    expect(profileCardFrameStillUrlForVipLevel(0), isNull);
    expect(profileCardFrameStillUrlForVipLevel(19), isNull);
    for (var level = 1; level <= 18; level++) {
      expect(
        vipProfileCardFrameStillKeys[level],
        'profile-card-frames/vip$level-${vipProfileCardStillAnimals[level]}.webp',
      );
    }
  });

  test('profile card frame animation URLs point at the R2 profile-card-frames/ mp4s (VIP5-18 only)',
      () {
    // Frame animations run from VIP5 onwards and loop; VIP1-4 have
    // a still only.
    expect(vipProfileCardFrameAnimAnimals.length, 14);
    expect(vipProfileCardFrameAnimAnimals[5], 'deer');
    expect(vipProfileCardFrameAnimAnimals[8], 'panther');
    expect(vipProfileCardFrameAnimAnimals[13], 'gorilla');
    expect(vipProfileCardFrameAnimAnimals[16], 'leviathan');
    expect(vipProfileCardFrameAnimAnimals[18], 'dragon');
    expect(vipProfileCardFrameAnimAnimals[1], isNull);
    expect(vipProfileCardFrameAnimAnimals[4], isNull);
    expect(
      profileCardFrameAnimVideoUrlForVipLevel(5),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip5-deer-anim.mp4',
    );
    expect(
      profileCardFrameAnimVideoUrlForVipLevel(13),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla-anim.mp4',
    );
    expect(
      profileCardFrameAnimVideoUrlForVipLevel(18),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip18-dragon-anim.mp4',
    );
    expect(profileCardFrameAnimVideoUrlForVipLevel(1), isNull);
    expect(profileCardFrameAnimVideoUrlForVipLevel(4), isNull);
    expect(profileCardFrameAnimVideoUrlForVipLevel(0), isNull);
    expect(profileCardFrameAnimVideoUrlForVipLevel(19), isNull);
    for (var level = 5; level <= 18; level++) {
      expect(
        vipProfileCardFrameAnimVideoKeys[level],
        'profile-card-frames/vip$level-${vipProfileCardFrameAnimAnimals[level]}-anim.mp4',
      );
    }
  });

  test('profileCardFrameAnimVideoUrlForDisplay plays only the level own frame animation',
      () {
    // The displayed card IS the level's own frame animation (or no key
    // configured, so the level animation is used): the frame video plays.
    expect(
      profileCardFrameAnimVideoUrlForDisplay(
          'profile-card-frames/vip13-gorilla-anim.mp4', 13),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla-anim.mp4',
    );
    // The Worker catalog still sends the level's old
    // profile-card-anims/ key: that also counts as the level's own
    // video and resolves to the frame animation.
    expect(
      profileCardFrameAnimVideoUrlForDisplay(
          'profile-card-anims/vip13-gorilla.mp4', 13),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla-anim.mp4',
    );
    expect(
      profileCardFrameAnimVideoUrlForDisplay('', 13),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla-anim.mp4',
    );
    expect(
      profileCardFrameAnimVideoUrlForDisplay(null, 13),
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla-anim.mp4',
    );
    // A custom/Owner video key has no frame animation: still only.
    expect(
      profileCardFrameAnimVideoUrlForDisplay(
          'custom-assets/card-123.mp4', 13),
      isNull,
    );
    // Another level's key is not this level's own video: still only.
    expect(
      profileCardFrameAnimVideoUrlForDisplay(
          'profile-card-frames/vip5-deer-anim.mp4', 13),
      isNull,
    );
    // VIP1-4 have no frame animation (still only).
    expect(profileCardFrameAnimVideoUrlForDisplay('', 1), isNull);
    expect(profileCardFrameAnimVideoUrlForDisplay('', 4), isNull);
    expect(
      profileCardFrameAnimVideoUrlForDisplay(
          'profile-card-anims/vip4-fox.mp4', 4),
      isNull,
    );
  });

  test('ProfileCardAnimBackground.forVipLevel resolves the frame video + still',
      () {
    // VIP5-18: looping frame animation + still (no pump: constructing
    // the widget does not start the video player).
    final Widget vip13 =
        ProfileCardAnimBackground.forVipLevel(level: 13, child: const SizedBox.shrink());
    expect(vip13, isA<ProfileCardAnimBackground>());
    expect(
      (vip13 as ProfileCardAnimBackground).videoUrl,
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla-anim.mp4',
    );
    expect(
      vip13.stillUrl,
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla.webp',
    );
    // VIP1-4: still only, no video.
    final Widget vip4 =
        ProfileCardAnimBackground.forVipLevel(level: 4, child: const SizedBox.shrink());
    expect((vip4 as ProfileCardAnimBackground).videoUrl, isNull);
    expect(
      vip4.stillUrl,
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip4-fox.webp',
    );
    // A custom video key resolves to still only.
    final Widget custom = ProfileCardAnimBackground.forVipLevel(
      level: 13,
      videoKey: 'custom-assets/card-123.mp4',
      child: const SizedBox.shrink(),
    );
    expect((custom as ProfileCardAnimBackground).videoUrl, isNull);
    expect(
      custom.stillUrl,
      '$kVipVisualR2PublicBaseUrl/profile-card-frames/vip13-gorilla.webp',
    );
  });

  test('resolver sends profile-card anim/still keys direct from R2', () {
    String fileUrl(String key) => 'https://worker.example/api/files?key=$key';
    expect(
      resolveVipVisualAssetUrl(
          'profile-card-anims/vip5-deer.mp4', fileUrl),
      '$kVipVisualR2PublicBaseUrl/profile-card-anims/vip5-deer.mp4',
    );
    expect(
      resolveVipVisualAssetUrl(
          'profile-card-stills/vip5-deer.png', fileUrl),
      '$kVipVisualR2PublicBaseUrl/profile-card-stills/vip5-deer.png',
    );
    expect(isDirectR2AssetKey('profile-card-anims/vip18-dragon.mp4'),
        isTrue);
    expect(isDirectR2AssetKey('profile-card-stills/vip4-fox.png'), isTrue);
  });

  test('badge video URLs point at the R2 vip-badges/ mp4s (VIP1-18)', () {
    const animals = <int, String>{
      1: 'cat',
      2: 'swan',
      3: 'dolphin',
      4: 'fox',
      5: 'deer',
      6: 'wolf',
      7: 'eagle',
      8: 'panther',
      9: 'cobra',
      10: 'lion',
      11: 'tiger',
      12: 'mammoth',
      13: 'gorilla',
      14: 'bear',
      15: 'kraken',
      16: 'leviathan',
      17: 'phoenix',
      18: 'dragon',
    };
    expect(vipBadgeAnimals, animals);
    for (final MapEntry<int, String> entry in animals.entries) {
      expect(
        vipBadgeVideoUrlForVipLevel(entry.key),
        '$kVipVisualR2PublicBaseUrl/vip-badges/vip${entry.key}-${entry.value}.mp4',
      );
      expect(vipBadgeVideoKeys[entry.key],
          'vip-badges/vip${entry.key}-${entry.value}.mp4');
    }
    expect(vipBadgeVideoUrlForVipLevel(0), isNull);
    expect(vipBadgeVideoUrlForVipLevel(19), isNull);
    // Durations: Vinay's portrait videos are 5.184 s, Ghost's
    // landscape videos are 10 s, VIP17 gold is 10.144 s.
    expect(vipBadgeAnimationMs[5], 5184);
    expect(vipBadgeAnimationMs[1], 10000);
    expect(vipBadgeAnimationMs[17], 10144);
    expect(vipBadgeAnimationMs.length, 18);
  });

  test('badge video plays only the level own badge', () {
    expect(
      vipBadgeVideoUrlForDisplay(null, 6),
      '$kVipVisualR2PublicBaseUrl/vip-badges/vip6-wolf.mp4',
    );
    expect(
      vipBadgeVideoUrlForDisplay('vip-badges/vip6-wolf.mp4', 6),
      '$kVipVisualR2PublicBaseUrl/vip-badges/vip6-wolf.mp4',
    );
    // A custom/Owner video key has no badge video: LevelMedal only.
    expect(
      vipBadgeVideoUrlForDisplay('custom-assets/badge-123.mp4', 6),
      isNull,
    );
    expect(vipBadgeVideoUrlForDisplay('', 0), isNull);
    expect(vipBadgeVideoUrlForDisplay('', 19), isNull);
  });

  test('VIP17 purple phoenix is a separate variant, gold stays default', () {
    expect(
      vipBadgeVariantVideoUrlForVipLevel(17),
      '$kVipVisualR2PublicBaseUrl/vip-badges/vip17-phoenix-purple.mp4',
    );
    expect(vipBadgeVariantVideoUrlForVipLevel(6), isNull);
    expect(vipBadgeVariantVideoUrlForVipLevel(18), isNull);
    // The default VIP17 badge URL is still the gold phoenix.
    expect(
      vipBadgeVideoUrlForVipLevel(17),
      '$kVipVisualR2PublicBaseUrl/vip-badges/vip17-phoenix.mp4',
    );
  });

  test('resolver sends vip-badges/ keys direct from R2', () {
    String fileUrl(String key) => 'https://worker.example/api/files?key=$key';
    expect(
      resolveVipVisualAssetUrl('vip-badges/vip6-wolf.mp4', fileUrl),
      '$kVipVisualR2PublicBaseUrl/vip-badges/vip6-wolf.mp4',
    );
    expect(isDirectR2AssetKey('vip-badges/vip18-dragon.mp4'), isTrue);
    expect(isDirectR2AssetKey('vip-badges/vip17-phoenix-purple.mp4'),
        isTrue);
  });

  test('panda emotes: exactly the 20 names, with labels', () {
    expect(kPandaEmoteNames.length, 20);
    expect(kPandaEmoteNames.toSet().length, 20);
    for (final name in <String>[
      'happy',
      'sad',
      'crying',
      'angry',
      'love',
      'laughing',
      'sleeping',
      'cool',
      'surprised',
      'winking',
      'kissing',
      'blushing',
      'hungry',
      'dancing',
      'waving',
      'clapping',
      'thinking',
      'scared',
      'silly',
      'party',
    ]) {
      expect(kPandaEmoteNames, contains(name));
      expect(kPandaEmoteLabels[name], isNotNull);
    }
  });

  test('panda emotes: VAP + thumbnail URLs point at the R2 seat-emotes keys',
      () {
    expect(
      pandaEmoteVapUrlForName('happy'),
      '$kVipVisualR2PublicBaseUrl/seat-emotes/panda/vap/panda-happy.mp4',
    );
    expect(
      pandaEmoteThumbUrlForName('party'),
      '$kVipVisualR2PublicBaseUrl/seat-emotes/panda/thumbs/panda-party.png',
    );
    expect(pandaEmoteVapUrlForName('dragon'), isNull);
    expect(pandaEmoteThumbUrlForName(''), isNull);
    expect(pandaEmoteVapUrlForName(null), isNull);
    expect(isPandaEmoteName('laughing'), isTrue);
    expect(isPandaEmoteName('Happy'), isFalse);
    expect(isPandaEmoteName(null), isFalse);
  });

  test('panda emotes: marker round-trips through the parser', () {
    expect(pandaEmoteMarkerForName('happy'), '[panda:happy]');
    expect(pandaEmoteMarkerForName('dragon'), isNull);
    expect(pandaEmoteNameFromMarker('[panda:happy]'), 'happy');
    expect(pandaEmoteNameFromMarker('  [panda:party]  '), 'party');
    expect(pandaEmoteNameFromMarker('[panda:dragon]'), isNull);
    expect(pandaEmoteNameFromMarker('😂'), isNull);
    expect(pandaEmoteNameFromMarker('[panda:]'), isNull);
    expect(pandaEmoteNameFromMarker('[Panda:happy]'), isNull);
    expect(pandaEmoteNameFromMarker('hello [panda:happy]'), isNull);
    expect(pandaEmoteNameFromMarker(null), isNull);
  });

  test('panda emotes: resolver sends seat-emotes keys direct from R2', () {
    String fileUrl(String key) => 'https://worker.example/api/files?key=$key';
    expect(
      resolveVipVisualAssetUrl(
        'seat-emotes/panda/vap/panda-happy.mp4',
        fileUrl,
      ),
      '$kVipVisualR2PublicBaseUrl/seat-emotes/panda/vap/panda-happy.mp4',
    );
    expect(
      isDirectR2AssetKey('seat-emotes/panda/vap/panda-party.mp4'),
      isTrue,
    );
    expect(
      isDirectR2AssetKey('seat-emotes/panda/thumbs/panda-sad.png'),
      isTrue,
    );
  });
}
