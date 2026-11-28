import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../vip/vip_visual_assets.dart';
import 'level_medal.dart';

/// Plays a VIP level badge video — the premium 3D animated shield
/// (animal + wings + gold "VIP N" banner on a pedestal) for one VIP
/// level — direct from R2 (vip-badges/vip<N>-<animal>.mp4).
///
/// Placement (Vinay, 2026-11-19): the badge video sits on the VIP
/// page hero card, on the RIGHT SIDE next to the "VIP N" text + EXP,
/// BIG (~140-160px, replacing the 86px LevelMedal slot) — NOT a
/// full-width background hero. Tapping a medal in the Medal Gallery
/// plays that level's badge video in a dialog.
///
/// Behaviour:
/// - The video plays ONCE (no loop) and ends calmly; on completion
///   the widget swaps back to the LevelMedal SVG, so the hero card
///   stays visible at rest.
/// - While the video downloads/initialises, the LevelMedal SVG is
///   shown (the poster) — the slot is never an empty box.
/// - On any video error (bad URL, download failure, decoder failure)
///   it swaps back to the LevelMedal SVG. Never a black box.
/// - When there is no video URL at all (out of range, or a custom/
///   Owner video key), the LevelMedal SVG is shown directly and no
///   player is created.
///
/// The badge videos are portrait (Vinay's, 720x1260/1080) or
/// landscape (Ghost's, 1280x720), so [fit] is BoxFit.contain by
/// default: the whole shield stays visible, never cropped.
class VipBadgeVideo extends StatefulWidget {
  const VipBadgeVideo({
    super.key,
    required this.videoUrl,
    required this.level,
    this.size = 150,
    this.fit = BoxFit.contain,
  });

  /// Badge video for a VIP level, resolved from the level: the URL
  /// from vip_visual_assets.dart. [videoKey] is the Worker's
  /// vip_badge video_key — only the level's own badge ever plays (a
  /// custom/Owner key resolves to null, LevelMedal only).
  factory VipBadgeVideo.forVipLevel({
    Key? key,
    required int level,
    String? videoKey,
    double size = 150,
    BoxFit fit = BoxFit.contain,
  }) {
    return VipBadgeVideo(
      key: key,
      videoUrl: vipBadgeVideoUrlForDisplay(videoKey, level),
      level: level,
      size: size,
      fit: fit,
    );
  }

  /// Direct R2 URL of the badge video MP4.
  /// Empty/null = no video: the LevelMedal SVG is shown directly.
  final String? videoUrl;

  /// VIP level of the badge (1-18). Also drives the fallback medal.
  final int level;

  /// Square size of the badge slot (width = height = [size]).
  final double size;

  final BoxFit fit;

  @override
  State<VipBadgeVideo> createState() => _VipBadgeVideoState();
}

class _VipBadgeVideoState extends State<VipBadgeVideo> {
  VideoPlayerController? _controller;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeStartVideo());
  }

  @override
  void didUpdateWidget(covariant VipBadgeVideo oldWidget) {
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
      // Finished, or failed: show the LevelMedal SVG. Never a black box.
      if (_showVideo) setState(() => _showVideo = false);
    }
  }

  Future<void> _maybeStartVideo() async {
    final String url = widget.videoUrl?.trim() ?? '';
    if (url.isEmpty) return; // No video: LevelMedal only, no player created.
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onVideoUpdate);
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      setState(() => _showVideo = true);
      await controller.play();
    } catch (_) {
      // Initialise/play failed (bad URL, download failure, no decoder):
      // fall back to the LevelMedal SVG.
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

  Widget _fallbackMedal() {
    return LevelMedal(
      series: MedalSeries.vip,
      level: widget.level,
      size: widget.size,
      animated: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final Widget content;
    if (_showVideo && controller != null && controller.value.isInitialized) {
      final Size size = controller.value.size;
      content = FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      );
    } else {
      content = _fallbackMedal();
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: content,
    );
  }
}
