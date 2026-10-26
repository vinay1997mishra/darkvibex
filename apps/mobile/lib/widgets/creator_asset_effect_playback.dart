import 'dart:async';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:video_player/video_player.dart';

import '../infra/backend_api.dart';

/// One-shot custom entry/vehicle effect. Video is preferred; GLB is used only
/// when no video render was uploaded. Built-in Flutter effect stays as fallback.
class CreatorAssetEffectPlayback extends StatefulWidget {
  const CreatorAssetEffectPlayback({
    super.key,
    required this.backend,
    required this.videoKey,
    required this.glbKey,
    required this.fallback,
  });

  final BackendApi backend;
  final String videoKey;
  final String glbKey;
  final Widget fallback;

  @override
  State<CreatorAssetEffectPlayback> createState() => _CreatorAssetEffectPlaybackState();
}

class _CreatorAssetEffectPlaybackState extends State<CreatorAssetEffectPlayback> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant CreatorAssetEffectPlayback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoKey != widget.videoKey) unawaited(_load());
  }

  Future<void> _load() async {
    final old = _controller;
    _controller = null;
    _ready = false;
    _failed = false;
    if (mounted) setState(() {});
    if (old != null) await old.dispose();
    final key = widget.videoKey.trim();
    if (key.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.backend.fileUrl(key)),
      httpHeaders: widget.backend.fileHeaders,
    );
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
      return ColoredBox(
        color: const Color(0xF5080611),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width > 0 ? size.width : 1,
              height: size.height > 0 ? size.height : 1,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      );
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
