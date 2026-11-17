import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import 'backend_http.dart';
import 'realtime.dart';

/// Agora RTC adapter shared by Party Rooms, Game Rooms and Direct Calls.
class AgoraRtcAdapter implements RtcAdapter {
  AgoraRtcAdapter({
    required this.apiBase,
    this.channelType = 'party',
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final Uri apiBase;
  final String channelType;
  final HttpClient _httpClient;
  RtcEngine? _engine;
  String _channel = '';
  String _userAccount = '';
  String _authToken = '';
  int _localUid = 0;
  int? _giftStreamId;
  bool _publishing = false;
  bool _publishingCamera = false;
  bool _speakerphoneOn = true;
  bool _disposed = false;
  RtcConnectionState _state = RtcConnectionState.idle;
  Timer? _renewTimer;
  Completer<void>? _joinCompleter;

  final Map<int, String> _userAccounts = <int, String>{};
  final Set<int> _remoteVideoUids = <int>{};
  final ValueNotifier<Map<String, double>> _speakingLevels =
      ValueNotifier<Map<String, double>>(const <String, double>{});
  final ValueNotifier<int> _mediaRevision = ValueNotifier<int>(0);
  final StreamController<AgoraGiftEvent> _giftEvents =
      StreamController<AgoraGiftEvent>.broadcast();

  @override
  RtcConnectionState get state => _state;

  @override
  bool get publishingMic => _publishing;

  @override
  ValueListenable<Map<String, double>> get speakingLevelsListenable =>
      _speakingLevels;

  ValueListenable<int> get mediaRevisionListenable => _mediaRevision;
  Stream<AgoraGiftEvent> get giftEvents => _giftEvents.stream;
  RtcEngine? get engine => _engine;
  String get channelName => _channel;
  int get localUid => _localUid;
  bool get publishingCamera => _publishingCamera;
  bool get speakerphoneOn => _speakerphoneOn;
  Map<int, String> get remoteVideoUsers =>
      Map<int, String>.unmodifiable(_userAccounts);
  RtcConnection get connection =>
      RtcConnection(channelId: _channel, localUid: _localUid);

  @override
  Future<void> join(
    String roomId,
    String userId, {
    String? authToken,
  }) async {
    if (roomId.trim().isEmpty || userId.trim().isEmpty) {
      _state = RtcConnectionState.failed;
      throw StateError('roomId and userId are required');
    }
    if (authToken == null || authToken.trim().isEmpty) {
      _state = RtcConnectionState.failed;
      throw StateError('DarkVibeX session is required for voice');
    }
    await leave();
    _state = RtcConnectionState.joining;
    _authToken = authToken;
    _userAccount = userId.trim();

    try {
      final credentials = await _fetchCredentials(roomId: roomId);
      final appId = credentials['app_id']?.toString() ?? '';
      final channel = credentials['channel_name']?.toString() ?? '';
      final token = credentials['token']?.toString() ?? '';
      if (appId.isEmpty || channel.isEmpty || token.isEmpty) {
        throw StateError('Agora voice credentials are incomplete');
      }
      _channel = channel;

      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      engine.registerEventHandler(RtcEngineEventHandler(
        onError: (error, message) {
          _state = RtcConnectionState.failed;
          if (!(_joinCompleter?.isCompleted ?? true)) {
            _joinCompleter!.completeError(StateError(message));
          }
        },
        onJoinChannelSuccess: (connection, elapsed) {
          _localUid = connection.localUid ?? 0;
          _state = RtcConnectionState.joined;
          if (!(_joinCompleter?.isCompleted ?? true)) {
            _joinCompleter!.complete();
          }
          _notifyMediaChanged();
        },
        onRejoinChannelSuccess: (connection, elapsed) {
          _localUid = connection.localUid ?? 0;
          _state = RtcConnectionState.joined;
          _notifyMediaChanged();
        },
        onConnectionStateChanged: (connection, connectionState, reason) {
          final name = connectionState.name.toLowerCase();
          if (name.contains('reconnecting') || name.contains('recovering')) {
            _state = RtcConnectionState.reconnecting;
          } else if (name.contains('failed') || name.contains('disconnected')) {
            _state = RtcConnectionState.failed;
          } else if (name.contains('connected')) {
            _state = RtcConnectionState.joined;
          }
        },
        onLocalUserRegistered: (uid, account) {
          _localUid = uid;
        },
        onUserInfoUpdated: (uid, info) {
          final account = (info.userAccount ?? '').trim();
          if (account.isNotEmpty) {
            _userAccounts[uid] = account;
            _notifyMediaChanged();
          }
        },
        onUserAccountUpdated: (connection, remoteUid, account) {
          final normalized = account.trim();
          if (normalized.isNotEmpty) {
            _userAccounts[remoteUid] = normalized;
            _notifyMediaChanged();
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _notifyMediaChanged();
        },
        onUserOffline: (connection, remoteUid, reason) {
          final identity = _userAccounts.remove(remoteUid) ?? remoteUid.toString();
          _remoteVideoUids.remove(remoteUid);
          final next = Map<String, double>.from(_speakingLevels.value)
            ..remove(identity);
          _speakingLevels.value = Map<String, double>.unmodifiable(next);
          _notifyMediaChanged();
        },
        onUserMuteVideo: (connection, remoteUid, muted) {
          if (muted) {
            _remoteVideoUids.remove(remoteUid);
          } else {
            _remoteVideoUids.add(remoteUid);
          }
          _notifyMediaChanged();
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          final stateName = state.name.toLowerCase();
          if (stateName.contains('decoding') || stateName.contains('starting')) {
            _remoteVideoUids.add(remoteUid);
          } else if (stateName.contains('stopped') || stateName.contains('failed')) {
            _remoteVideoUids.remove(remoteUid);
          }
          _notifyMediaChanged();
        },
        onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
          final next = <String, double>{};
          for (final speaker in speakers) {
            final uid = speaker.uid ?? 0;
            if (uid == 0 || uid == _localUid) continue;
            final account = _userAccounts[uid] ?? uid.toString();
            final raw = ((speaker.volume ?? 0) / 255.0).clamp(0.0, 1.0).toDouble();
            if (raw > 0.01) {
              next[account] = raw < 0.18 ? 0.18 : raw;
            }
          }
          _speakingLevels.value = Map<String, double>.unmodifiable(next);
        },
        onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
          if (streamId != _giftStreamId || length <= 0) return;
          try {
            final decoded = jsonDecode(utf8.decode(data.sublist(0, length)));
            if (decoded is Map) {
              _giftEvents.add(AgoraGiftEvent(
                packet: Map<String, dynamic>.from(decoded),
                senderAccount: _userAccounts[remoteUid] ?? '',
              ));
            }
          } catch (_) {
            // Ignore malformed or unrelated RTC data packets.
          }
        },
        onTokenPrivilegeWillExpire: (connection, token) {
          unawaited(_renewToken());
        },
        onRequestToken: (connection) {
          unawaited(_renewToken());
        },
      ));

      await engine.enableAudio();
      await engine.setEnableSpeakerphone(true);
      _speakerphoneOn = true;
      await engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
      _joinCompleter = Completer<void>();
      await engine.joinChannelWithUserAccount(
        token: token,
        channelId: channel,
        userAccount: _userAccount,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      ).timeout(const Duration(seconds: 20));
      await _joinCompleter!.future.timeout(const Duration(seconds: 25));
      try {
        _giftStreamId = await engine.createDataStream(
          const DataStreamConfig(
            ordered: true,
            syncWithAudio: false,
          ),
        );
      } catch (_) {
        // Gift polling remains the recovery path if data streams are unavailable.
        _giftStreamId = null;
      }
      _scheduleRenewal(credentials['expires_at']);
    } catch (_) {
      _state = RtcConnectionState.failed;
      await _destroyEngine();
      rethrow;
    }
  }

  Future<void> _scheduleRenewal(dynamic expiresAt) async {
    _renewTimer?.cancel();
    final expiry = int.tryParse(expiresAt?.toString() ?? '') ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
    final delaySeconds = (expiry -
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) -
            90)
        .clamp(30, 3500)
        .toInt();
    _renewTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(_renewToken());
    });
  }

  Future<void> _renewToken() async {
    if (_state != RtcConnectionState.joined || _authToken.isEmpty) return;
    try {
      final credentials = await _fetchCredentials(roomId: _lastRoomId);
      final token = credentials['token']?.toString() ?? '';
      if (token.isEmpty) return;
      await _engine?.renewToken(token);
      _scheduleRenewal(credentials['expires_at']);
    } catch (error) {
      debugPrint('DarkVibeX Agora token renewal failed: $error');
    }
  }

  String _lastRoomId = '';

  Future<Map<String, dynamic>> _fetchCredentials({
    required String roomId,
  }) async {
    _lastRoomId = roomId;
    final request = await openBackendRequest(
      _httpClient,
      'POST',
      apiBase.replace(path: '/agora/token'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_authToken');
    request.write(jsonEncode(<String, dynamic>{
      'room_id': roomId,
      'room_type': channelType,
    }));
    final response = await closeBackendRequest(request);
    final raw = await readBackendResponse(response);
    final decoded = raw.trim().isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map
        ? decoded.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error']?.toString() ?? 'Unable to connect Agora voice');
    }
    return data;
  }

  @override
  Future<void> setMicPublished(bool enabled) async {
    if (_state != RtcConnectionState.joined || _engine == null) {
      throw StateError('Agora voice channel is not joined');
    }
    await _engine!.muteLocalAudioStream(!enabled);
    _publishing = enabled;
  }

  @override
  Future<void> setRemoteAudioEnabled(bool enabled) async {
    await _engine?.muteAllRemoteAudioStreams(!enabled);
  }

  Future<void> setSpeakerphoneOn(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
    _speakerphoneOn = enabled;
  }

  Future<void> setCameraPublished(bool enabled) async {
    final engine = _engine;
    if (_state != RtcConnectionState.joined || engine == null) {
      throw StateError('Agora RTC channel is not joined');
    }
    if (enabled) {
      await engine.enableVideo();
      await engine.startPreview();
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishCameraTrack: true),
      );
      _publishingCamera = true;
    } else {
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishCameraTrack: false),
      );
      await engine.stopPreview();
      await engine.disableVideo();
      _publishingCamera = false;
    }
    _notifyMediaChanged();
  }

  Future<void> publishGiftEvent(Map<String, dynamic> event) async {
    final engine = _engine;
    final streamId = _giftStreamId;
    if (_state != RtcConnectionState.joined || engine == null || streamId == null) {
      throw StateError('Agora gift data stream is unavailable');
    }
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(event)));
    if (bytes.length > 1024) {
      throw StateError('Gift event exceeds Agora data-stream packet limit');
    }
    await engine.sendStreamMessage(
      streamId: streamId,
      data: bytes,
      length: bytes.length,
    );
  }

  List<int> get remoteVideoUids =>
      List<int>.unmodifiable(_remoteVideoUids.toList()..sort());

  String accountForUid(int uid) => _userAccounts[uid] ?? uid.toString();

  void _notifyMediaChanged() {
    _mediaRevision.value = _mediaRevision.value + 1;
  }

  Future<void> leave() async {
    _renewTimer?.cancel();
    _renewTimer = null;
    _publishing = false;
    _publishingCamera = false;
    _giftStreamId = null;
    _userAccounts.clear();
    _remoteVideoUids.clear();
    _localUid = 0;
    await _destroyEngine();
    _state = RtcConnectionState.idle;
    if (_speakingLevels.value.isNotEmpty) {
      _speakingLevels.value = const <String, double>{};
    }
    _notifyMediaChanged();
  }

  Future<void> _destroyEngine() async {
    final engine = _engine;
    _engine = null;
    _joinCompleter = null;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
    } catch (_) {}
    try {
      engine.unregisterEventHandler(RtcEngineEventHandler());
    } catch (_) {}
    try {
      await engine.release();
    } catch (error) {
      debugPrint('DarkVibeX Agora engine cleanup failed: $error');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _renewTimer?.cancel();
    _speakingLevels.dispose();
    _mediaRevision.dispose();
    unawaited(_giftEvents.close());
    _httpClient.close(force: true);
  }
}

class AgoraGiftEvent {
  const AgoraGiftEvent({required this.packet, required this.senderAccount});

  final Map<String, dynamic> packet;
  final String senderAccount;
}
