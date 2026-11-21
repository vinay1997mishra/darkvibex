import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../vip/vip_visual_assets.dart';

/// Plays a VIP profile card FRAME as the BACKGROUND of the profile
/// card popup, with the reference layout overlaid in the foreground.
///
/// Layout rule (Vinay, 2026-11-19, approved): the popup shows the
/// reference layout in the FOREGROUND — DP top centre (in place of the
/// frame's blue diamond), name + badges, medals, ID/Fans, bio, 4
/// buttons (Send gifts, Follow, Chat, Mention) — and this frame
/// plays in the BACKGROUND behind all the text. This widget owns the
/// background only; the caller passes the foreground content as
/// [child] and lays it out exactly like the reference.
///
/// Behaviour (frame rule, Vinay, 2026-11-21 — all 18 frames added in
/// one pass, 5 s, loop):
/// - The video is the level's 5-second frame animation MP4, direct
///   from R2 (profile-card-frames/vip<N>-<animal>-anim.mp4, VIP5-18).
///   It LOOPS while the card is open; on any video error it swaps
///   back to the frame still, so the card stays visible at rest.
/// - While the video downloads/initialises, the frame still WebP is
///   shown (the poster) — the card is never an empty box.
/// - On any video error (bad URL, download failure, decoder failure)
///   it swaps back to the still. If the still also fails, [background]
///   is shown (default: a dark container).
/// - When there is no video URL at all (VIP1-4 have no frame
///   animation), the still is shown directly and no player is created.
///   When there is no still either, only [child] is shown.
///
/// The video is a full-bleed scene (opaque background), so
/// video_player CAN play it — unlike the transparent WebMs, which
/// show a black box through an opaque texture. [fit] is BoxFit.cover
/// by default: the 832x896 canvas is cropped to fill the card box.
class ProfileCardAnimBackground extends StatefulWidget {
  const ProfileCardAnimBackground({
    super.key,
    required this.videoUrl,
    required this.stillUrl,
    required this.child,
    this.fit = BoxFit.cover,
    this.background,
  });

  /// Background frame animation for a VIP level, resolved from the level:
  /// video + still URLs from vip_visual_assets.dart. VIP5-18 resolve to
  /// a looping 5-second frame animation + still; VIP1-4 resolve to a
  /// still pic only (no frame animation); out of range resolves to
  /// neither, so only [child] is shown. [videoKey] is the Worker's
  /// profile_card_anim video_key — only the level's own animation
  /// ever plays (a custom/Owner key resolves to null, still only).
  factory ProfileCardAnimBackground.forVipLevel({
    Key? key,
    required int level,
    String? videoKey,
    required Widget child,
    BoxFit fit = BoxFit.cover,
    Widget? background,
  }) {
    return ProfileCardAnimBackground(
      key: key,
      videoUrl: profileCardFrameAnimVideoUrlForDisplay(videoKey, level),
      stillUrl: profileCardFrameStillUrlForVipLevel(level),
      child: child,
      fit: fit,
      background: background,
    );
  }

  /// Direct R2 URL of the 5-second looping frame animation MP4.
  /// Empty/null = no video: the still is shown directly.
  final String? videoUrl;

  /// Direct R2 URL of the frame still WebP (poster while the video loads;
  /// image shown when the video errors).
  final String? stillUrl;

  /// Foreground content: the reference layout (DP, name, badges,
  /// medals, ID/Fans, bio, buttons), rendered over the animation.
  final Widget child;

  final BoxFit fit;

  /// Shown behind [child] when the still also fails to load.
  final Widget? background;

  @override
  State<ProfileCardAnimBackground> createState() =>
      _ProfileCardAnimBackgroundState();
}

class _ProfileCardAnimBackgroundState
    extends State<ProfileCardAnimBackground> {
  VideoPlayerController? _controller;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeStartVideo());
  }

  @override
  void didUpdateWidget(covariant ProfileCardAnimBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      unawaited(_disposeController());
      _showVideo = false;
      unawaited(_maybeStartVideo());
    }
  }

  void _onVideoUpdate() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (controller.value.hasError || controller.value.isCompleted) {
      // Failed (or finished, if looping is unavailable on the
      // platform): show the still. Never a black box.
      if (_showVideo) setState(() => _showVideo = false);
    }
  }

  Future<void> _maybeStartVideo() async {
    final String url = widget.videoUrl?.trim() ?? '';
    if (url.isEmpty) return; // No video: still only, no player created.
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onVideoUpdate);
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      setState(() => _showVideo = true);
      await controller.play();
    } catch (_) {
      // Initialise/play failed (bad URL, download failure, no decoder):
      // fall back to the still.
      if (mounted) setState(() => _showVideo = false);
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onVideoUpdate);
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  Widget _still() {
    final String? url = widget.stillUrl?.trim();
    if (url == null || url.isEmpty) return _fallbackBackground();
    return Image.network(
      url,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => _fallbackBackground(),
    );
  }

  Widget _fallbackBackground() {
    return widget.background ??
        Container(color: const Color(0xFF0D0D1A));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final Widget background;
    if (_showVideo && controller != null && controller.value.isInitialized) {
      final Size size = controller.value.size;
      background = FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      );
    } else {
      background = _still();
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(child: background),
        widget.child,
      ],
    );
  }
}
