import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darkvibex/call/call_ringtone.dart';

class _RecordingBackend implements CallAudioBackend {
  final List<String> looped = <String>[];
  final List<String> playedOnce = <String>[];
  int stops = 0;
  int disposes = 0;

  @override
  Future<void> playLoop(String assetPath) async {
    looped.add(assetPath);
  }

  @override
  Future<void> playOnce(String assetPath) async {
    playedOnce.add(assetPath);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('call ringtone catalog', () {
    test('has four distinct tones and classic is the default', () {
      expect(callRingtones.length, 4);
      expect(
        callRingtones.map((tone) => tone.id).toSet().length,
        callRingtones.length,
      );
      expect(defaultCallRingtoneId, 'classic');
      expect(callRingtoneForId('classic').name, 'Classic Bell');
      expect(callRingtoneForId('melody').assetPath, 'assets/ringtones/melody.wav');
    });

    test('unknown tone ids fall back to the default tone', () {
      expect(callRingtoneForId('not-a-tone').id, 'classic');
      expect(callRingtoneForId('').id, 'classic');
    });

    test('every catalog tone is a bundled asset that loads', () async {
      for (final tone in callRingtones) {
        expect(tone.assetPath, startsWith('assets/ringtones/'));
        final data = await rootBundle.load(tone.assetPath);
        expect(data.lengthInBytes, greaterThan(0), reason: tone.id);
      }
    });
  });

  group('CallRingtonePlayer', () {
    test('start plays the selected tone on loop; stop silences it', () async {
      final backend = _RecordingBackend();
      final player = CallRingtonePlayer(backend: backend);

      await player.start('melody');
      expect(player.isPlaying, isTrue);
      expect(backend.looped, ['assets/ringtones/melody.wav']);

      await player.stop();
      expect(player.isPlaying, isFalse);
      expect(backend.stops, 1);

      await player.dispose();
      expect(backend.disposes, 1);
    });

    test('preview plays the selected tone once (ringtone picker)', () async {
      final backend = _RecordingBackend();
      final player = CallRingtonePlayer(backend: backend);

      await player.preview('gentle');
      expect(backend.playedOnce, ['assets/ringtones/gentle.wav']);
      expect(backend.looped, isEmpty);
    });

    test('an unknown selection still rings with the default tone', () async {
      final backend = _RecordingBackend();
      final player = CallRingtonePlayer(backend: backend);

      await player.start('no-such-tone');
      expect(backend.looped, ['assets/ringtones/classic.wav']);
    });
  });
}
