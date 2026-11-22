import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const worker = await readFile(new URL("../src/index.js", import.meta.url), "utf8");
const catalog = await readFile(new URL("../src/gift_catalog.js", import.meta.url), "utf8");
const roomScreen = await readFile(
  new URL("../../mobile/lib/screens/room_screen.dart", import.meta.url),
  "utf8",
);
const pubspec = await readFile(
  new URL("../../mobile/pubspec.yaml", import.meta.url),
  "utf8",
);

test("SVGA gift: Rose catalog entry carries an svga_key on R2", () => {
  // The Rose SVGA lives at gifts/svga/rose.svga in the public R2 bucket.
  assert.match(catalog, /"id": "rose"/);
  assert.match(catalog, /"svga_key": "gifts\/svga\/rose\.svga"/);
});

test("SVGA gift: room gift-event feed carries svga_key to every viewer", () => {
  // The feed builds each event from the catalog gift, next to
  // video_key / glb_key, so receivers play the SVGA too.
  assert.match(worker, /svga_key:String\(gift\.svga_key \?\? gift\.svgaKey \?\? ""\)/);
});

test("SVGA gift: app plays SVGA full-screen for BIG gifts only", () => {
  // All three playback dispatch sites check svga_key first — but only
  // for big gifts (1,000,000+ coins). Small gifts fall through to the
  // centre-pause-fly effect instead.
  const sites = roomScreen.match(/if \(svgaKey\.isNotEmpty && _isBigGift\(/g) ?? [];
  assert.equal(sites.length, 3, `expected 3 SVGA dispatch sites, got ${sites.length}`);
  assert.match(roomScreen, /await _playGiftSvga\(/);
  assert.match(roomScreen, /Future<void> _playGiftSvga\(/);
  assert.match(roomScreen, /static const int _bigGiftCoinThreshold = 500000;/);
  assert.match(roomScreen, /bool _isBigGift\(Map<String, dynamic> gift\)/);
});

test("SVGA gift: small gifts pause at the screen centre before flying", () => {
  // The seat impact effect holds the gift at the centre first (hold
  // phase), then flies it to the receiver's DP. Dragons hold longer
  // (2s of 3s); other gifts hold 45% of the tween.
  const start = roomScreen.indexOf("Widget _buildSeatGiftImpactEffect(");
  assert.ok(start >= 0);
  const body = roomScreen.slice(start, start + 6000);
  assert.match(body, /final holdEnd = isDragon \? 0\.67 : 0\.45;/);
  assert.match(body, /final flight = value < holdEnd/);
});

test("Dragon gift: centre of the screen, wings flapping 2-3s, then to the DP", () => {
  // Vinay, 2026-11-22: the Dragon flies in the MIDDLE of the screen,
  // wings flapping, for 2-3 seconds, then flies to the receiver's DP.
  // It does NOT use the full-screen SVGA dialog.
  // (Golden Dragon was REMOVED from the catalog by Vinay, 2026-11-22,
  // so it is NOT in _dragonGiftIds anymore.)
  assert.match(roomScreen, /bool _isDragonGift\(Map<String, dynamic> gift\)/);
  assert.match(roomScreen, /'fire-dragon',/);
  assert.match(roomScreen, /'cosmic-dragon-palace',/);
  assert.doesNotMatch(roomScreen, /'golden-dragon',/);
  // All 3 dispatch sites exclude dragons from the full-screen dialog.
  const dragonExclusions =
    roomScreen.match(/_isBigGift\((gift|displayGift)\) && !_isDragonGift\(\1\)/g) ?? [];
  assert.equal(dragonExclusions.length, 3,
    `expected 3 dragon exclusions at the dispatch sites, got ${dragonExclusions.length}`);
  // Centre effect: dragon tween is 3s (2s hold + 1s flight) and the
  // clear timer is 3.2s; the dragon SVGA is BIG and loops so the wings
  // keep flapping while it flies to the DP; the dragon SHRINKS as it
  // flies to the DP (Vinay, 2026-11-22: "chota hoke chala jayega").
  const start = roomScreen.indexOf("Widget _buildSeatGiftImpactEffect(");
  assert.ok(start >= 0);
  const body = roomScreen.slice(start, start + 6000);
  assert.match(body, /duration: Duration\(milliseconds: isDragon \? 3000 : 1450\)/);
  assert.match(body, /MediaQuery\.of\(context\)\.size\.width \* \.85/);
  assert.match(body, /loops: isDragon,/);
  assert.match(body, /\(isDragon \? 1\.0 - flight \* 0\.8 : 1\.0\)/);
  assert.match(roomScreen, /Duration\(milliseconds: dragonEffect \? 3200 : 2200\)/);
});

test("Gift animation intensity: 20k+ gets full SVGA, below 20k gets 20% only", () => {
  // Vinay, 2026-11-22: gifts of 20,000 coins and above get the full
  // animation effect; gifts below 20,000 get only 20% animation.
  const start = roomScreen.indexOf("Widget _buildSeatGiftImpactEffect(");
  assert.ok(start >= 0);
  const body = roomScreen.slice(start, start + 6000);
  assert.match(body, /giftCost >= 20000/);
  assert.match(body, /final fullAnimation = giftCost >= 20000 && svgaKey\.isNotEmpty;/);
  // Judged on the UNIT price (coin_cost / count), not the combo total.
  assert.match(body, /giftCostTotal ~\/ giftCount/);
  // 20% animation = small pop only (0.8 -> 1.0), no SVGA.
  assert.match(body, /\? \.8 \+ Curves\.easeOutBack\.transform\(value \/ holdEnd\) \* \.2/);
});

test("SVGA gift: playback is transparent and respects the Gift Effects toggle", () => {
  const start = roomScreen.indexOf("Future<void> _playGiftSvga(");
  assert.ok(start >= 0);
  const body = roomScreen.slice(start, start + 6000);
  // Transparent dialog: the room shows through behind the gift.
  assert.match(body, /barrierColor: Colors\.transparent/);
  assert.match(body, /backgroundColor: Colors\.transparent/);
  // Gift Effects off => no SVGA animation for this user.
  assert.match(body, /if \(!mounted \|\| !effectsEnabled \|\| !giftEffectsEnabled\) return;/);
  // Plays once, closes when done; falls back to the simple effect.
  assert.match(body, /SVGAEasyPlayer\(/);
  assert.match(body, /loops: false/);
  assert.match(body, /onFinished:/);
  assert.match(body, /_playGiftEffect\(gift, receiverId: receiverId\)/);
  // Dragon flies at the TOP of the screen (Vinay, 2026-11-22:
  // "Screen ke uper udega ye") — SVGA is top-aligned, not centred.
  assert.match(body, /Alignment\.topCenter/);
});

test("SVGA gift: app depends on a Dart-3-compatible SVGA player", () => {
  // svgaplayer_flutter 2.2.0 needs Dart <3.0.0 and cannot be used here
  // (app sdk >=3.12.0). flutter_svga is its active replacement.
  // (The name may appear in a comment explaining this; only a real
  // dependency entry counts.)
  assert.match(pubspec, /flutter_svga: \^0\.0\.14/);
  assert.doesNotMatch(pubspec, /^\s*svgaplayer_flutter:/m);
});
