import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../infra/backend_api.dart';

class GiftMediaPreview extends StatefulWidget {
  const GiftMediaPreview({
    super.key,
    required this.backend,
    required this.videoKey,
    required this.assetKey,
    required this.emoji,
    this.fit = BoxFit.cover,
  });

  final BackendApi backend;
  final String videoKey;
  final String assetKey;
  final String emoji;
  final BoxFit fit;

  @override
  State<GiftMediaPreview> createState() => _GiftMediaPreviewState();
}

class _GiftMediaPreviewState extends State<GiftMediaPreview> {
  VideoPlayerController? _controller;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_configureVideo());
  }

  @override
  void didUpdateWidget(covariant GiftMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoKey != widget.videoKey) {
      unawaited(_configureVideo());
    }
  }

  Future<void> _configureVideo() async {
    final old = _controller;
    _controller = null;
    _videoReady = false;
    if (mounted) setState(() {});
    if (old != null) {
      await old.dispose();
    }

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
      setState(() => _videoReady = true);
    } catch (_) {
      if (_controller == controller) {
        await controller.dispose();
        _controller = null;
        if (mounted) setState(() => _videoReady = false);
      }
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_videoReady && controller != null && controller.value.isInitialized) {
      final size = controller.value.size;
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width <= 0 ? 1 : size.width,
              height: size.height <= 0 ? 1 : size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      );
    }

    final assetKey = widget.assetKey.trim();
    if (assetKey.isNotEmpty) {
      return Image.network(
        widget.backend.fileUrl(assetKey),
        headers: widget.backend.fileHeaders,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _emojiFallback(),
      );
    }
    return _emojiFallback();
  }

  Widget _emojiFallback() => Container(
        alignment: Alignment.center,
        color: const Color(0xFF21183F),
        child: Text(
          widget.emoji.isEmpty ? '🎁' : widget.emoji,
          style: const TextStyle(fontSize: 30),
        ),
      );
}
