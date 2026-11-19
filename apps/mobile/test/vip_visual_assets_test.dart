import 'package:darkvibex/vip/vip_visual_assets.dart';
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
}
