import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const ownerApi = await readFile(new URL("../src/owner_api.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const threeStage = await readFile(new URL("../../creator-studio/src/ThreeStage.tsx", import.meta.url), "utf8");
const creatorApp = await readFile(new URL("../../creator-studio/src/App.tsx", import.meta.url), "utf8");
const transparentArtwork = await readFile(new URL("../../mobile/lib/widgets/transparent_artwork_image.dart", import.meta.url), "utf8");
const panelHtml = await readFile(new URL("../../owner_panel/index.html", import.meta.url), "utf8");
const panelApp = await readFile(new URL("../../owner_panel/app.js", import.meta.url), "utf8");
const shop = await readFile(new URL("../../mobile/lib/screens/cosmetics_shop_screen.dart", import.meta.url), "utf8");
const room = await readFile(new URL("../../mobile/lib/screens/room_screen.dart", import.meta.url), "utf8");
const appState = await readFile(new URL("../../mobile/lib/app/app_state.dart", import.meta.url), "utf8");
const profile = await readFile(new URL("../../mobile/lib/screens/profile_screen.dart", import.meta.url), "utf8");
const mediaPreview = await readFile(new URL("../../mobile/lib/widgets/creator_asset_media_preview.dart", import.meta.url), "utf8");
const effectPlayback = await readFile(new URL("../../mobile/lib/widgets/creator_asset_effect_playback.dart", import.meta.url), "utf8");
const frameWidget = await readFile(new URL("../../mobile/lib/widgets/vip_animated_frame.dart", import.meta.url), "utf8");
const bubbleWidget = await readFile(new URL("../../mobile/lib/widgets/cosmetic_store_previews.dart", import.meta.url), "utf8");
const giftPreview = await readFile(new URL("../../mobile/lib/widgets/gift_media_preview.dart", import.meta.url), "utf8");
const giftScreen = await readFile(new URL("../../mobile/lib/screens/gifts_screen.dart", import.meta.url), "utf8");

test("Creator Studio HTML and nested bundles use the static-assets binding", () => {
  assert.ok(worker.includes('url.pathname === "/creator-studio" || url.pathname.startsWith("/creator-studio/")'));
  assert.ok(worker.includes('"https://assets.local"'));
  assert.ok(worker.includes("return env.ASSETS.fetch(studioAssetUrl)"));
});
test("creator uploads are permission-gated, capped and file-signature validated", () => {
  assert.match(ownerApi, /handleCreatorMediaUpload/);
  assert.match(ownerApi, /requirePermission\(actor, kind === "gift" \? "gifts\.save" : "assets\.save"\)/);
  assert.match(ownerApi, /creator-assets\//);
  assert.match(ownerApi, /11 \* 1024 \* 1024/);
  assert.match(ownerApi, /25 \* 1024 \* 1024/);
  assert.match(ownerApi, /ascii\(4, 8\) === "ftyp"/);
  assert.match(ownerApi, /bytes\[0\] === 0x1a && bytes\[1\] === 0x45 && bytes\[2\] === 0xdf && bytes\[3\] === 0xa3/);
  assert.match(ownerApi, /ascii\(0, 4\) === "glTF"/);
  assert.match(ownerApi, /env\.FILES\.put\(key, bytes/);
});

test("owner panel can upload and publish video, model and image assets", () => {
  assert.match(panelHtml, /id="creatorAssetFile"/);
  assert.match(panelHtml, /id="assetVideoKey"/);
  assert.match(panelHtml, /id="assetGlbKey"/);
  assert.match(panelHtml, /id="uploadCreatorAsset"/);
  assert.match(panelApp, /\/api\/owner\/creator-media/);
  assert.match(panelApp, /video_key:/);
  assert.match(panelApp, /glb_key:/);
  assert.match(panelApp, /media_type:/);
});

test("custom media metadata reaches room entry playback and R2 assets are publicly readable", () => {
  assert.match(worker, /creator-assets/);
  assert.match(worker, /active_vehicle_video_key/);
  assert.match(worker, /active_entry_video_key/);
  assert.match(worker, /active_vehicle_glb_key/);
  assert.match(worker, /active_entry_glb_key/);
  assert.match(worker, /active_frame_asset_key/);
  assert.match(worker, /active_bubble_asset_key/);
  assert.match(room, /CreatorAssetEffectPlayback/);
  assert.match(room, /assetUrl: activeFrameAssetKey/);
  assert.match(room, /assetImageUrl: bubbleAssetKey/);
  assert.match(frameWidget, /TransparentArtworkImage\(/);
  assert.match(frameWidget, /requireTransparentCenter: true/);
  assert.match(frameWidget, /_TransparentFrameFallbackPainter/);
  assert.match(bubbleWidget, /assetImageUrl/);
  assert.match(bubbleWidget, /TransparentArtworkImage\(/);
  assert.match(bubbleWidget, /_AnimatedBubbleEdgeEffect/);
  assert.match(transparentArtwork, /outsideClear/);
  assert.match(transparentArtwork, /alphaAt\(16, 16\)/);
  assert.match(room, /active_entry_video_key/);
  assert.match(effectPlayback, /VideoPlayerController\.networkUrl/);
  assert.match(effectPlayback, /ModelViewer\(/);
});

test("frame animation metadata reaches room seats, own profile and remote store previews", () => {
  assert.match(worker, /active_frame_animation_type/);
  assert.match(worker, /active_frame_animation_ms/);
  assert.match(worker, /BASE_FRAME_ANIMATION_METADATA/);
  assert.match(appState, /activeFrameAnimationType/);
  assert.match(appState, /activeFrameAnimationMs/);
  assert.match(appState, /catalogById\['frame:\$itemId'\]/);
  assert.match(room, /animationType: member\['active_frame_animation_type'\]/);
  assert.match(profile, /animationType: state\.activeFrameAnimationType/);
  assert.match(shop, /animationType: item\['animation_type'\]/);
  assert.match(shop, /assetUrl: widget\.state\.backend\.fileUrl\(assetImageKey\)/);
  assert.match(frameWidget, /final String\? animationType/);
  assert.match(frameWidget, /final int\? animationDurationMs/);
  assert.match(frameWidget, /_paintMetadataAnimation/);
  assert.match(frameWidget, /case 'dragon_wings'/);
});

test("frame and bubble publishing requires real alpha and frame-hole transparency", () => {
  assert.match(ownerApi, /imageFileDeclaresTransparency/);
  assert.match(ownerApi, /creator_asset_transparency_required/);
  assert.match(panelApp, /transparent PNG\/WebP|transparent PNG ya WebP/i);
  assert.match(creatorApp, /imageHasTransparentArtwork/);
  assert.match(creatorApp, /DP cut-out dono transparent/);
  assert.match(threeStage, /Transparent frame \/ bubble alpha/);
  assert.match(threeStage, /frameCentreClear/);
  assert.doesNotMatch(threeStage, /new THREE\.CircleGeometry\(0\.82, 96\)/);
  assert.match(transparentArtwork, /alphaValid = outsideClear && centreClear/);
  assert.match(frameWidget, /_TransparentFrameFallbackPainter/);
  assert.match(bubbleWidget, /_AnimatedBubbleEdgeEffect/);
});

test("Store previews uploaded MP4/WebM and GLB assets with a procedural fallback", () => {
  assert.match(shop, /CreatorAssetMediaPreview/);
  assert.match(shop, /ModelViewer\(/);
  assert.match(shop, /glb_key/);
  assert.match(shop, /video_key/);
  assert.match(mediaPreview, /setLooping\(false\)/);
  assert.match(mediaPreview, /setVolume\(0\)/);
  assert.match(giftPreview, /ModelViewer\(/);
  assert.match(giftPreview, /glbKey/);
  assert.match(giftScreen, /glbKey:/);
  assert.match(room, /_playGiftGlb/);
  assert.match(room, /glbKey: glbKey/);
  assert.match(room, /ModelViewer\(/);
});
