import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import 'backend_http.dart';
import 'realtime.dart';

class LiveKitRtcAdapter implements RtcAdapter {
  LiveKitRtcAdapter({
    required this.apiBase,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final HttpClient _httpClient;

  Room? _room;
  RtcConnectionState _state = RtcConnectionState.idle;
  bool _publishing = false;
  bool _remoteAudioEnabled = true;
  Timer? _speakingTimer;
  final Set<String> _disabledRemoteTrackSids = <String>{};
  final ValueNotifier<Map<String, double>> _speakingLevels =
      ValueNotifier<Map<String, double>>(const <String, double>{});

  @override
  RtcConnectionState get state {
    final current = _room;
    if (current == null) return _state;
    switch (current.connectionState.name) {
      case 'connected':
        return RtcConnectionState.joined;
      case 'reconnecting':
        return RtcConnectionState.reconnecting;
      case 'disconnected':
        return RtcConnectionState.failed;
      default:
        return _state;
    }
  }

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
    if (authToken == null || authToken.trim().isEmpty) {
      throw StateError('DarkVibeX session is required for voice');
    }
    await leave();
    _state = RtcConnectionState.joining;

    final credentials = await _fetchCredentials(
      roomId: roomId,
      authToken: authToken,
    );
    final serverUrl = credentials['server_url']?.toString() ?? '';
    final token = credentials['token']?.toString() ?? '';
    if (serverUrl.isEmpty || token.isEmpty) {
      _state = RtcConnectionState.failed;
      throw StateError('Voice credentials are incomplete');
    }

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    try {
      await room.prepareConnection(serverUrl, token).timeout(const Duration(seconds: 10));
      await room.connect(serverUrl, token).timeout(const Duration(seconds: 25));
      _room = room;
      _state = RtcConnectionState.joined;
      _publishing = false;
      _startSpeakingMonitor();
    } catch (_) {
      _state = RtcConnectionState.failed;
      try {
        await room.disconnect();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> leave() async {
    _speakingTimer?.cancel();
    _speakingTimer = null;
    final old = _room;
    _room = null;
    _publishing = false;
    _disabledRemoteTrackSids.clear();
    if (old != null) {
      try {
        await old.disconnect();
      } finally {
        try {
          await old.dispose();
        } catch (_) {}
      }
    }
    _state = RtcConnectionState.idle;
    if (_speakingLevels.value.isNotEmpty) {
      _speakingLevels.value = const <String, double>{};
    }
  }

  @override
  Future<void> setMicPublished(bool enabled) async {
    final participant = _room?.localParticipant;
    if (state != RtcConnectionState.joined || participant == null) {
      throw StateError('Voice room is not joined');
    }
    await participant.setMicrophoneEnabled(enabled);
    _publishing = enabled;
  }

  @override
  Future<void> setRemoteAudioEnabled(bool enabled) async {
    _remoteAudioEnabled = enabled;
    final room = _room;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        if (enabled) {
          if (_disabledRemoteTrackSids.remove(publication.sid)) {
            await publication.enable();
          }
        } else if (_disabledRemoteTrackSids.add(publication.sid)) {
          await publication.disable();
        }
      }
    }
  }

  void _startSpeakingMonitor() {
    _speakingTimer?.cancel();
    _speakingTimer = Timer.periodic(
      const Duration(milliseconds: 150),
      (_) => _sampleSpeakingLevels(),
    );
  }

  void _sampleSpeakingLevels() {
    final room = _room;
    if (room == null || state != RtcConnectionState.joined) return;
    final next = <String, double>{};
    for (final participant in room.activeSpeakers) {
      final identity = participant.identity.trim();
      if (identity.isEmpty || !participant.isSpeaking || participant.isMuted) continue;
      final level = participant.audioLevel.clamp(0.0, 1.0).toDouble();
      if (level >= 0.01) next[identity] = level;
    }
    _speakingLevels.value = Map<String, double>.unmodifiable(next);
  }

  Future<Map<String, dynamic>> _fetchCredentials({
    required String roomId,
    required String authToken,
  }) async {
    final request = await openBackendRequest(
      _httpClient,
      'POST',
      apiBase.replace(path: '/livekit/token'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    request.write(jsonEncode(<String, dynamic>{'room_id': roomId}));

    final response = await closeBackendRequest(request);
    final raw = await readBackendResponse(response);
    final decoded = raw.trim().isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map
        ? decoded.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to connect voice room');
    }
    return data;
  }

  void dispose() {
    _speakingTimer?.cancel();
    _speakingLevels.dispose();
    _httpClient.close(force: true);
  }
}
