import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../infra/backend_api.dart';
import '../infra/livekit_rtc.dart';
import '../ui/tinni_style.dart';

class DirectCallScreen extends StatefulWidget {
  const DirectCallScreen({
    super.key,
    required this.state,
    required this.callId,
    required this.peerName,
    required this.initialState,
  });

  final AppState state;
  final String callId;
  final String peerName;
  final String initialState;

  @override
  State<DirectCallScreen> createState() => _DirectCallScreenState();
}

class _DirectCallScreenState extends State<DirectCallScreen> {
  Timer? pollTimer;
  LiveKitRtcAdapter? rtc;
  String callState = 'ringing';
  String statusText = 'Ringing…';
  bool micMuted = false;
  bool ending = false;
  bool joining = false;

  @override
  void initState() {
    super.initState();
    callState = widget.initialState;
    statusText = callState == 'active' ? 'Connecting…' : 'Ringing…';
    if (callState == 'active') {
      unawaited(_joinVoice());
    }
    pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshStatus()),
    );
  }

  Future<void> _refreshStatus() async {
    if (!mounted || ending) return;
    final value = await widget.state.backend.directCallStatus(
      userId: widget.state.userId,
      callId: widget.callId,
    );
    final raw = value?['call'];
    if (raw is! Map || !mounted) return;
    final next = raw['state']?.toString() ?? callState;
    if (next != callState) {
      setState(() {
        callState = next;
        statusText = switch (next) {
          'active' => rtc == null ? 'Connecting…' : 'Connected',
          'declined' => 'Call declined',
          'missed' => 'No answer',
          'ended' => 'Call ended',
          _ => 'Ringing…',
        };
      });
    }
    if (next == 'active' && rtc == null && !joining) {
      await _joinVoice();
    } else if (const {'declined', 'missed', 'ended'}.contains(next)) {
      await _closeSoon();
    }
  }

  Future<void> _joinVoice() async {
    if (joining || rtc != null || !mounted) return;
    final token = widget.state.sessionToken;
    if (token == null || token.isEmpty || BackendApi.origin.isEmpty) {
      if (mounted) setState(() => statusText = 'Voice connection unavailable');
      return;
    }
    setState(() => joining = true);
    final adapter = LiveKitRtcAdapter(apiBase: Uri.parse(BackendApi.origin));
    try {
      await adapter.join(
        'call-${widget.callId}',
        widget.state.userId,
        authToken: token,
      );
      await adapter.setMicPublished(true);
      if (!mounted) {
        await adapter.leave();
        adapter.dispose();
        return;
      }
      setState(() {
        rtc = adapter;
        joining = false;
        micMuted = false;
        statusText = 'Connected';
      });
    } catch (_) {
      await adapter.leave();
      adapter.dispose();
      if (!mounted) return;
      setState(() {
        joining = false;
        statusText = 'Voice connection failed';
      });
    }
  }

  Future<void> _toggleMic() async {
    final adapter = rtc;
    if (adapter == null) return;
    final nextMuted = !micMuted;
    try {
      await adapter.setMicPublished(!nextMuted);
      if (mounted) setState(() => micMuted = nextMuted);
    } catch (_) {}
  }

  Future<void> _endCall() async {
    if (ending) return;
    setState(() => ending = true);
    pollTimer?.cancel();
    await widget.state.backend.endDirectCall(
      userId: widget.state.userId,
      callId: widget.callId,
    );
    await _leaveVoice();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _closeSoon() async {
    pollTimer?.cancel();
    await _leaveVoice();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _leaveVoice() async {
    final adapter = rtc;
    rtc = null;
    if (adapter != null) {
      try {
        await adapter.leave();
      } catch (_) {}
      adapter.dispose();
    }
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    final adapter = rtc;
    rtc = null;
    if (adapter != null) {
      unawaited(adapter.leave().whenComplete(adapter.dispose));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_endCall());
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: TinniBackground(
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(),
                  const TinniGlowIcon(
                    icon: Icons.person_rounded,
                    size: 48,
                    boxSize: 108,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.peerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: TinniPalette.cream,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: TinniPalette.muted,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: micMuted ? 'Unmute' : 'Mute',
                        onPressed: rtc == null ? null : _toggleMic,
                        icon: Icon(
                          micMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                        ),
                      ),
                      const SizedBox(width: 28),
                      SizedBox(
                        width: 66,
                        height: 66,
                        child: FilledButton(
                          onPressed: ending ? null : _endCall,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 46),
                ],
              ),
            ),
          ),
        ),
      );
}
