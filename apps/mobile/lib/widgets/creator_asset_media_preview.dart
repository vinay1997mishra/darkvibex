import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../infra/backend_api.dart';

class CreatorAssetMediaPreview extends StatefulWidget {
  const CreatorAssetMediaPreview({
    super.key,
    required this.backend,
    required this.mediaKey,
    required this.fallback,
    this.height = 150,
    this.fit = BoxFit.contain,
  });

  final BackendApi backend;
  final String mediaKey;
  final Widget fallback;
  final double height;
  final BoxFit fit;

  @override
  State<CreatorAssetMediaPreview> createState() => _CreatorAssetMediaPreviewState();
}

class _CreatorAssetMediaPreviewState extends State<CreatorAssetMediaPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant CreatorAssetMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaKey != widget.mediaKey) unawaited(_load());
  }

  Future<void> _load() async {
    final previous = _controller;
    _controller = null;
    _ready = false;
    if (mounted) setState(() {});
    if (previous != null) await previous.dispose();
    final key = widget.mediaKey.trim();
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
    } catch (_) {
      if (_controller == controller) {
        await controller.dispose();
        _controller = null;
        if (mounted) setState(() => _ready = false);
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
    if (_ready && controller != null && controller.value.isInitialized) {
      final size = controller.value.size;
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ClipRect(
          child: FittedBox(
            fit: widget.fit,
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
    return SizedBox(height: widget.height, child: Center(child: widget.fallback));
  }
}
