import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:video_player/video_player.dart';

import '../infra/backend_api.dart';

/// One-shot custom entry/vehicle effect. Video is preferred; GLB is used only
/// when no video render was uploaded. Built-in Flutter effect stays as fallback.
class CustomAssetEffectPlayback extends StatefulWidget {
  const CustomAssetEffectPlayback({
    super.key,
    required this.backend,
    required this.videoKey,
    required this.glbKey,
    required this.fallback,
    this.directVideoUrl,
  });

  final BackendApi backend;
  final String videoKey;
  final String glbKey;
  final Widget fallback;

  /// Direct public video URL (e.g. an R2 CDN URL for a VIP animal
  /// vehicle entry). When set, the video plays straight from that URL
  /// with VideoPlayerController.networkUrl — NO Worker /api/files
  /// lookup and NO httpHeaders. This is the path for the 14 animal
  /// vehicle videos (vehicles/vip<N>-<animal>.mp4 on the public R2
  /// bucket): the Worker's /api/files allowlist does not include
  /// vehicles/ keys, and routing through the Worker would only add
  /// delay at room entry. When empty, the existing fileUrl path runs.
  final String? directVideoUrl;

  /// Prefetched direct-video controllers, keyed by URL. Call
  /// [prefetchDirectVideoUrl] on room join (best-effort, unawaited)
  /// so the first frames are buffered before the entry plays; the
  /// widget takes ownership of a prefetched controller via
  /// [takePrefetched] and disposes it. A URL is prefetched at most
  /// once per app run.
  static final Map<String, VideoPlayerController> _prefetchedDirectVideos =
      <String, VideoPlayerController>{};

  static void prefetchDirectVideoUrl(String url) {
    if (url.isEmpty || _prefetchedDirectVideos.containsKey(url)) return;
    final VideoPlayerController controller =
        VideoPlayerController.networkUrl(Uri.parse(url));
    _prefetchedDirectVideos[url] = controller;
    // Best-effort: a failed prefetch must not break room entry.
    controller.initialize().catchError((_) => null);
  }

  static VideoPlayerController? takePrefetched(String url) =>
      _prefetchedDirectVideos.remove(url);

  @override
  State<CustomAssetEffectPlayback> createState() => _CustomAssetEffectPlaybackState();
}

class _CustomAssetEffectPlaybackState extends State<CustomAssetEffectPlayback> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant CustomAssetEffectPlayback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoKey != widget.videoKey ||
        oldWidget.directVideoUrl != widget.directVideoUrl) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final old = _controller;
    _controller = null;
    _ready = false;
    _failed = false;
    if (mounted) setState(() {});
    if (old != null) await old.dispose();
    final directUrl = widget.directVideoUrl?.trim() ?? '';
    if (directUrl.isNotEmpty) {
      // Direct R2 playback: use a prefetched controller when one is
      // waiting (room join prefetched it), otherwise create one. No
      // fileUrl, no httpHeaders — the URL is already public.
      final controller = CustomAssetEffectPlayback.takePrefetched(directUrl) ??
          VideoPlayerController.networkUrl(Uri.parse(directUrl));
      await _playController(controller);
      return;
    }
    final key = widget.videoKey.trim();
    if (key.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.backend.fileUrl(key)),
      httpHeaders: widget.backend.fileHeaders,
    );
    await _playController(controller);
  }

  Future<void> _playController(VideoPlayerController controller) async {
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted || _controller != controller) return;
      setState(() => _ready = true);
      controller.addListener(() {
        if (!mounted || _controller != controller || !controller.value.isInitialized) return;
        if (controller.value.hasError && !_failed) {
          setState(() { _failed = true; _ready = false; });
        }
      });
    } catch (_) {
      if (_controller == controller) {
        await controller.dispose();
        _controller = null;
        if (mounted) setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_ready && !_failed && controller != null && controller.value.isInitialized) {
      final size = controller.value.size;
      // Fill the room's allocated entry area while preserving the video's
      // aspect ratio. Cover intentionally crops excess edges instead of
      // shrinking a portrait clip into a small centered strip.
      return IgnorePointer(
        child: ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width > 0 ? size.width : 1,
                height: size.height > 0 ? size.height : 1,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
      );
    }
    // A configured video is the primary asset. Keep the overlay transparent
    // while it initializes so neither GLB nor the illustrated fallback flashes
    // before the uploaded animation starts. If video initialization fails, use
    // the GLB (when supplied) and then the standard fallback. A direct R2
    // video counts as a configured video here too.
    final hasDirectVideo = (widget.directVideoUrl?.trim().isNotEmpty ?? false);
    if ((widget.videoKey.trim().isNotEmpty || hasDirectVideo) && !_failed) {
      return const SizedBox.shrink();
    }
    final glb = widget.glbKey.trim();
    if (glb.isNotEmpty) {
      return Center(
        child: SizedBox(
          width: 420,
          height: 420,
          child: ModelViewer(
            src: widget.backend.fileUrl(glb),
            alt: 'DarkVibeX custom 3D entrance effect',
            backgroundColor: const Color(0x00000000),
            autoRotate: true,
            autoPlay: true,
            ar: false,
            cameraControls: false,
            disableZoom: true,
            shadowIntensity: 0.8,
          ),
        ),
      );
    }
    return widget.fallback;
  }
}
