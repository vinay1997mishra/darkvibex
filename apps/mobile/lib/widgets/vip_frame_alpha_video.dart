import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

import 'transparent_artwork_image.dart';

/// Plays a Tencent VAP alpha-video frame over the avatar, with the
/// transparent PNG still as the fallback — never a black box.
///
/// The video is the level's VAP mp4 (vap/vip<N>-<animal>.mp4 on R2):
/// an H.264 MP4 whose frame carries the alpha mask on the LEFT half and
/// the RGB image on the RIGHT half (VAP v1, no `vapc` box), converted
/// from the transparent WebM by
/// ~/workspace/darkvibex-vip-section/alpha-video/webm_to_vap.py.
///
/// Behaviour (matches Vinay's frame rule: a single 5-second animation
/// that completes and ends calmly, not a loop):
/// - While the video downloads/initialises, the PNG still is shown
///   (the poster) — the frame is never an empty box.
/// - The video plays ONCE (repeatCount 0). On completion it swaps back
///   to the PNG still, so the frame stays visible at rest.
/// - On any video error (bad URL, download failure, decoder failure)
///   it swaps back to the PNG still. If the still also fails,
///   [fallback] (the painted ring) is shown by TransparentArtworkImage.
/// - When there is no video URL at all (custom/Owner frames have no VAP
///   video), the still is shown directly and no player is created.
///
/// The caller (VipAnimatedFrame) wraps this in the same Transform.scale
/// + ClipPath as the still, so the video is scaled and centre-clipped
/// exactly like the still image.
class VipFrameAlphaVideo extends StatefulWidget {
  const VipFrameAlphaVideo({
    super.key,
    required this.videoUrl,
    required this.stillUrl,
    this.headers,
    this.fit = BoxFit.contain,
    this.fallback = const SizedBox.shrink(),
  });

  /// Direct R2 URL of the VAP mp4. Empty/null = no video: the still is
  /// shown directly and no player is created.
  final String? videoUrl;

  /// Direct R2 URL of the transparent PNG still (poster while the video
  /// loads; image shown after the video ends or errors).
  final String stillUrl;

  /// Headers for the still image request (backend file headers). The VAP
  /// URL is a public R2 URL and needs no headers.
  final Map<String, String>? headers;

  final BoxFit fit;

  /// Shown if the still also fails to load (the painted ring).
  final Widget fallback;

  @override
  State<VipFrameAlphaVideo> createState() => _VipFrameAlphaVideoState();
}

class _VipFrameAlphaVideoState extends State<VipFrameAlphaVideo> {
  VapPlayerController? _controller;
  StreamSubscription<Object>? _events;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeStartVideo());
  }

  @override
  void didUpdateWidget(covariant VipFrameAlphaVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      unawaited(_disposeController());
      _showVideo = false;
      unawaited(_maybeStartVideo());
    }
  }

  Future<void> _maybeStartVideo() async {
    final String url = widget.videoUrl?.trim() ?? '';
    if (url.isEmpty) return; // No video: still only, no player created.
    final controller = VapPlayerController.networkUrl(
      Uri.parse(url),
      options: const VapPlayerOptions(
        // Texture view on Android (composites inside Flutter, so the
        // caller's ClipPath works); iOS falls back to a platform view.
        viewType: VapViewType.textureView,
        // 0 = play once. The 5 s frame animation completes and ends
        // calmly; on completion we swap back to the still.
        repeatCount: 0,
        scaleType: VapScaleType.fitCenter,
        // Our VAP files are v1 (plain alpha mp4, no vapc box): alpha
        // mask on the LEFT half of the frame, RGB on the RIGHT half.
        enableOldVersion: true,
      ),
    );
    _controller = controller;
    _events = controller.events.listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case VapCompletedEvent():
          case VapErrorEvent():
            // Finished, or failed: show the still. Never a black box.
            setState(() => _showVideo = false);
          default:
            break;
        }
      },
      onError: (_, __) {
        if (mounted) setState(() => _showVideo = false);
      },
    );
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _showVideo = true);
      await controller.play();
    } catch (_) {
      // Initialise/play failed (bad URL, download failure, no decoder):
      // fall back to the still.
      if (mounted) setState(() => _showVideo = false);
    }
  }

  Future<void> _disposeController() async {
    await _events?.cancel();
    _events = null;
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  Widget _still() {
    return TransparentArtworkImage(
      url: widget.stillUrl,
      headers: widget.headers,
      fit: widget.fit,
      requireTransparentCenter: true,
      fallback: widget.fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_showVideo || controller == null) return _still();
    return VapPlayer(controller);
  }
}
