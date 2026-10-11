import 'dart:async';

import 'package:flutter/material.dart';

class GiftEffectEvent {
  const GiftEffectEvent({
    required this.id,
    required this.emoji,
    required this.name,
    required this.sender,
    required this.receiver,
    required this.tier,
    this.levelBefore,
    this.levelAfter,
  });

  final String id;
  final String emoji;
  final String name;
  final String sender;
  final String receiver;
  final String tier;
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
        ? const Duration(milliseconds: 4200)
        : event.tier == 'overlay'
            ? const Duration(milliseconds: 3000)
            : const Duration(milliseconds: 2100);
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

  @override
  Widget build(BuildContext context) {
    final cinematic = event.tier == 'cinematic';
    final overlay = event.tier == 'overlay' || cinematic;
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
                Text(event.emoji, style: TextStyle(fontSize: cinematic ? 96 : 66)),
                const SizedBox(height: 10),
                Text(
                  event.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: cinematic ? 26 : 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${event.sender}  →  ${event.receiver}',
                  textAlign: TextAlign.center,
                ),
                if (event.levelAfter != null &&
                    event.levelBefore != null &&
                    event.levelAfter! > event.levelBefore!) ...[
                  const SizedBox(height: 14),
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
          ),
        ),
      ),
    );
  }
}
