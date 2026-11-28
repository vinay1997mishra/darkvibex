import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_vap_player/flutter_vap_player.dart';

/// Plays one panda seat emote (a Tencent VAP alpha-video) ONCE on a mic
/// seat, above the sender's DP — then disappears.
///
/// The video is the emote's VAP mp4 (seat-emotes/panda/vap/panda-<name>
/// .mp4 on R2): an H.264 MP4 whose frame carries the alpha mask on the
/// LEFT half and the RGB image on the RIGHT half (VAP v1, no `vapc`
/// box), converted from the transparent WebM. Same layout as the VIP
/// frame VAPs (see VipFrameAlphaVideo).
///
/// Behaviour:
/// - While the video downloads/initialises, nothing is shown (the seat
///   is never an empty box — the emote simply appears when ready).
/// - The video plays ONCE (repeatCount 0). On completion it calls
///   [onDone] so the parent clears the seat reaction.
/// - On any video error (bad URL, download failure, decoder failure)
///   it calls [onDone] too — a failed emote vanishes instead of
///   showing a black box.
class SeatPandaEmote extends StatefulWidget {
  const SeatPandaEmote({
    super.key,
    required this.videoUrl,
    required this.onDone,
    this.width = 96,
    this.height = 170,
  });

  /// Direct R2 URL of the VAP mp4.
  final String videoUrl;

  /// Called once when the video finishes or fails. The parent uses it
  /// to clear the seat reaction.
  final VoidCallback onDone;

  /// Display size. The panda videos are vertical (720x1280), so the
  /// widget is taller than wide — full body, standing above the DP.
  final double width;
  final double height;

  @override
  State<SeatPandaEmote> createState() => _SeatPandaEmoteState();
}

class _SeatPandaEmoteState extends State<SeatPandaEmote> {
  VapPlayerController? _controller;
  StreamSubscription<Object>? _events;
  bool _showVideo = false;
  bool _doneCalled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeStartVideo());
  }

  void _finish() {
    if (_doneCalled) return;
    _doneCalled = true;
    widget.onDone();
  }

  Future<void> _maybeStartVideo() async {
    final String url = widget.videoUrl.trim();
    if (url.isEmpty) {
      _finish();
      return;
    }
    final controller = VapPlayerController.networkUrl(
      Uri.parse(url),
      options: const VapPlayerOptions(
        viewType: VapViewType.textureView,
        // 0 = play once. The emote plays once and ends; on completion
        // we tell the parent to clear the seat reaction.
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
            _finish();
          default:
            break;
        }
      },
      onError: (_, __) {
        if (mounted) _finish();
      },
    );
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _showVideo = true);
      await controller.play();
    } catch (_) {
      if (mounted) _finish();
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_showVideo || controller == null) return const SizedBox.shrink();
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: VapPlayer(controller),
    );
  }
}
