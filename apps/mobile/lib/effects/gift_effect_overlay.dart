import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:pag/pag.dart';
import 'package:video_player/video_player.dart';

class GiftEffectEvent {
  const GiftEffectEvent({
    required this.id,
    required this.emoji,
    required this.name,
    required this.sender,
    required this.receiver,
    required this.tier,
    this.asset = '',
    this.levelBefore,
    this.levelAfter,
  });

  final String id;
  final String emoji;
  final String name;
  final String sender;
  final String receiver;
  final String tier;
  final String asset;
  final int? levelBefore;
  final int? levelAfter;
}

class GiftEffectController extends ChangeNotifier {
  GiftEffectEvent? current;
  Timer? _timer;
  int serial = 0;

  void play(GiftEffectEvent event) {
    _timer?.cancel();
    current = event;
    serial += 1;
    notifyListeners();
    final duration = event.tier == 'cinematic'
        ? const Duration(milliseconds: 5200)
        : event.tier == 'overlay'
            ? const Duration(milliseconds: 3600)
            : const Duration(milliseconds: 2400);
    _timer = Timer(duration, () {
      current = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class GiftEffectOverlay extends StatelessWidget {
  const GiftEffectOverlay({
    super.key,
    required this.controller,
  });

  final GiftEffectController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final event = controller.current;
          return IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: event == null
                  ? const SizedBox.shrink()
                  : _GiftScene(
                      key: ValueKey('${event.id}-${controller.serial}'),
                      event: event,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _GiftScene extends StatelessWidget {
  const _GiftScene({super.key, required this.event});

  final GiftEffectEvent event;

  bool get hasBinaryAsset {
    final lower = event.asset.toLowerCase();
    return lower.startsWith('https://') &&
        (lower.endsWith('.svga') ||
            lower.contains('.svga?') ||
            lower.endsWith('.pag') ||
            lower.contains('.pag?') ||
            lower.endsWith('.mp4') ||
            lower.contains('.mp4?') ||
            lower.endsWith('.gif') ||
            lower.contains('.gif?'));
  }

  @override
  Widget build(BuildContext context) {
    final cinematic = event.tier == 'cinematic';
    final overlay = event.tier == 'overlay' || cinematic;

    if (hasBinaryAsset) {
      return Container(
        color: cinematic ? const Color(0xCC000000) : const Color(0x88000000),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _BinaryEffectView(
                  key: ValueKey(event.asset),
                  asset: event.asset,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 28,
              child: _EffectCaption(event: event),
            ),
          ],
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      decoration: overlay
          ? BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0x99FFD36A),
                  const Color(0xAA401A72),
                  Colors.black.withValues(alpha: cinematic ? .86 : .62),
                ],
                stops: const [0, .45, 1],
              ),
            )
          : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .25, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.elasticOut,
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: EdgeInsets.symmetric(
            horizontal: cinematic ? 32 : 22,
            vertical: cinematic ? 30 : 18,
          ),
          decoration: BoxDecoration(
            color: const Color(0xDD111116),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFD36A), width: 1.4),
            boxShadow: const [
              BoxShadow(
                blurRadius: 34,
                spreadRadius: 7,
                color: Color(0x66FFD36A),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.emoji,
                style: TextStyle(fontSize: cinematic ? 96 : 66),
              ),
              const SizedBox(height: 10),
              _EffectCaption(event: event),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectCaption extends StatelessWidget {
  const _EffectCaption({required this.event});

  final GiftEffectEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xDD111116),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xAAFFD36A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${event.sender}  →  ${event.receiver}',
            textAlign: TextAlign.center,
          ),
          if (event.levelAfter != null &&
              event.levelBefore != null &&
              event.levelAfter! > event.levelBefore!) ...[
            const SizedBox(height: 10),
            Text(
              'LEVEL UP • LV.${event.levelAfter}',
              style: const TextStyle(
                color: Color(0xFFFFD36A),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BinaryEffectView extends StatefulWidget {
  const _BinaryEffectView({
    super.key,
    required this.asset,
  });

  final String asset;

  @override
  State<_BinaryEffectView> createState() => _BinaryEffectViewState();
}

class _BinaryEffectViewState extends State<_BinaryEffectView> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    final lower = widget.asset.toLowerCase();
    if (lower.endsWith('.mp4') || lower.contains('.mp4?')) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.asset),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _video = controller;
      controller.initialize().then((_) async {
        if (!mounted) return;
        await controller.setLooping(false);
        await controller.play();
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lower = widget.asset.toLowerCase();
    if (lower.endsWith('.gif') || lower.contains('.gif?')) {
      return Image.network(
        widget.asset,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    if (lower.endsWith('.svga') || lower.contains('.svga?')) {
      return SVGAEasyPlayer(
        resUrl: widget.asset,
        fit: BoxFit.contain,
      );
    }
    if (lower.endsWith('.pag') || lower.contains('.pag?')) {
      return PAGView.network(
        widget.asset,
        autoPlay: true,
        repeatCount: 1,
        defaultBuilder: (_) => const SizedBox.shrink(),
      );
    }

    final video = _video;
    if (video != null && video.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}
