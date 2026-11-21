import 'package:just_audio/just_audio.dart';

/// Call ringtones (Vinay, 2026-11-21): the user picks one as the
/// caller tune — the tone that rings when a call comes in. Muted
/// calls never ring and never notify, so the tone only ever plays for
/// an incoming UNMUTED call.
///
/// The tone files are bundled twice: here as Flutter assets (played
/// in-app with just_audio) and in android/app/src/main/res/raw/ (so
/// the native FCM service can play the selected tone in the
/// notification while the app is closed). Keep both copies in sync.

class CallRingtone {
  const CallRingtone({
    required this.id,
    required this.name,
    required this.assetPath,
  });

  final String id;
  final String name;
  final String assetPath;
}

const List<CallRingtone> callRingtones = <CallRingtone>[
  CallRingtone(
    id: 'classic',
    name: 'Classic Bell',
    assetPath: 'assets/ringtones/classic.wav',
  ),
  CallRingtone(
    id: 'chime',
    name: 'Chime',
    assetPath: 'assets/ringtones/chime.wav',
  ),
  CallRingtone(
    id: 'melody',
    name: 'Melody',
    assetPath: 'assets/ringtones/melody.wav',
  ),
  CallRingtone(
    id: 'gentle',
    name: 'Gentle Tone',
    assetPath: 'assets/ringtones/gentle.wav',
  ),
];

const String defaultCallRingtoneId = 'classic';

CallRingtone callRingtoneForId(String id) {
  for (final tone in callRingtones) {
    if (tone.id == id) return tone;
  }
  return callRingtones.first;
}

/// Thin seam over just_audio so the player is unit-testable without a
/// platform audio channel: tests inject a fake backend, the app uses
/// [JustAudioCallBackend].
abstract class CallAudioBackend {
  Future<void> playLoop(String assetPath);
  Future<void> playOnce(String assetPath);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioCallBackend implements CallAudioBackend {
  JustAudioCallBackend({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _disposed = false;

  @override
  Future<void> playLoop(String assetPath) async {
    if (_disposed) return;
    try {
      await _player.stop();
      await _player.setLoopMode(LoopMode.one);
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (_) {
      // A missing/corrupt tone must never break the incoming-call
      // dialog; the call still shows, just silently.
    }
  }

  @override
  Future<void> playOnce(String assetPath) async {
    if (_disposed) return;
    try {
      await _player.stop();
      await _player.setLoopMode(LoopMode.off);
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    try {
      await _player.dispose();
    } catch (_) {}
  }
}

/// Plays the selected caller tune while an incoming call is ringing,
/// and stops it the moment the call is answered, refused or expires.
class CallRingtonePlayer {
  CallRingtonePlayer({CallAudioBackend? backend})
      : _backend = backend ?? JustAudioCallBackend();

  final CallAudioBackend _backend;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> start(String ringtoneId) async {
    final tone = callRingtoneForId(ringtoneId);
    _playing = true;
    await _backend.playLoop(tone.assetPath);
  }

  Future<void> preview(String ringtoneId) async {
    final tone = callRingtoneForId(ringtoneId);
    _playing = true;
    await _backend.playOnce(tone.assetPath);
  }

  Future<void> stop() async {
    _playing = false;
    await _backend.stop();
  }

  Future<void> dispose() async {
    _playing = false;
    await _backend.dispose();
  }
}
