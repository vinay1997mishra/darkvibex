import 'package:flutter/foundation.dart';

enum RtcConnectionState { idle, joining, joined, reconnecting, failed }

abstract interface class RtcAdapter {
  RtcConnectionState get state;
  bool get publishingMic;
  ValueListenable<Map<String, double>> get speakingLevelsListenable;

  Future<void> join(
    String roomId,
    String userId, {
    String? authToken,
  });

  Future<void> leave();
  Future<void> setMicPublished(bool enabled);
  Future<void> setRemoteAudioEnabled(bool enabled);
}

class LocalRtcAdapter implements RtcAdapter {
  RtcConnectionState _state = RtcConnectionState.idle;
  bool _publishing = false;
  final ValueNotifier<Map<String, double>> _speakingLevels =
      ValueNotifier<Map<String, double>>(const <String, double>{});

  @override
  RtcConnectionState get state => _state;

  @override
  bool get publishingMic => _publishing;

  @override
  ValueListenable<Map<String, double>> get speakingLevelsListenable =>
      _speakingLevels;

  @override
  Future<void> join(
    String roomId,
    String userId, {
    String? authToken,
  }) async {
    if (roomId.isEmpty || userId.isEmpty) {
      _state = RtcConnectionState.failed;
      throw StateError('roomId and userId are required');
    }
    _state = RtcConnectionState.joined;
  }

  @override
  Future<void> leave() async {
    _publishing = false;
    _state = RtcConnectionState.idle;
  }

  @override
  Future<void> setMicPublished(bool enabled) async {
    if (_state != RtcConnectionState.joined) {
      throw StateError('RTC room is not joined');
    }
    _publishing = enabled;
  }

  @override
  Future<void> setRemoteAudioEnabled(bool enabled) async {}

  void dispose() => _speakingLevels.dispose();
}
