import 'package:darkvibex/vip/vip_visual_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frame animals cover VIP5-18 (Phoenix is VIP17, Dragon VIP18)', () {
    expect(vipFrameAnimals.length, 14);
    expect(vipFrameAnimals[5], 'deer');
    expect(vipFrameAnimals[13], 'gorilla');
    expect(vipFrameAnimals[17], 'phoenix');
    expect(vipFrameAnimals[18], 'dragon');
    expect(vipFrameAnimals[4], isNull);
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
    expect(vipFrameStillUrlForVipLevel(4), isNull);
    expect(vipFrameStillUrlForVipLevel(0), isNull);
  });

  test('frame video URLs point at the R2 frames/ WebMs', () {
    expect(
      vipFrameVideoUrlForVipLevel(17),
      '$kVipVisualR2PublicBaseUrl/frames/vip17-phoenix-transparent.webm',
    );
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
    // VIP1-4 have no animal frame at all.
    expect(vipFrameVapUrlForDisplay('', 4), isNull);
  });

  test('entry effect URLs point at the R2 entry-effects/ PNGs', () {
    expect(
      vipEntryEffectUrlForVipLevel(10),
      '$kVipVisualR2PublicBaseUrl/entry-effects/vip10-entry.png',
    );
    expect(vipEntryEffectUrlForVipLevel(4), isNull);
  });

  test('entry effect circle geometry is present and in range for all levels',
      () {
    for (var level = 5; level <= 18; level++) {
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
      expect(aspect!, greaterThan(2));
      expect(aspect, lessThan(5));
    }
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
    expect(vipTagUrlForVipLevel(4), isNull);
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
}
