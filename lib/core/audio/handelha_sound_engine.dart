import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'sound_engine_stub.dart'
    if (dart.library.io) 'sound_engine_io.dart';

enum AmbientSoundscape {
  silent,
  ocean,
  night,
  rain,
  forest,
  warmNoise,
}

extension AmbientSoundscapeExt on AmbientSoundscape {
  String get labelAr => switch (this) {
        AmbientSoundscape.silent => 'صامت',
        AmbientSoundscape.ocean => 'أمواج البحر',
        AmbientSoundscape.night => 'هدوء الليل',
        AmbientSoundscape.rain => 'مطر هادئ',
        AmbientSoundscape.forest => 'نسيم الغابة',
        AmbientSoundscape.warmNoise => 'ضوضاء دافئة',
      };

  String get labelEn => switch (this) {
        AmbientSoundscape.silent => 'Silent',
        AmbientSoundscape.ocean => 'Ocean Waves',
        AmbientSoundscape.night => 'Calm Night',
        AmbientSoundscape.rain => 'Gentle Rain',
        AmbientSoundscape.forest => 'Forest Breeze',
        AmbientSoundscape.warmNoise => 'Warm Focus',
      };

  String get subtitleAr => switch (this) {
        AmbientSoundscape.silent => 'تركيز بدون مؤثرات صوتية',
        AmbientSoundscape.ocean => 'صوت حركة الموج الهادئة على الشاطئ لصفاء الذهن',
        AmbientSoundscape.night => 'ترددات ليلية دافئة وهادئة تساعد على التركيز العميق',
        AmbientSoundscape.rain => 'قطرات مطر خفيفة تعزلك عن الضوضاء حولك',
        AmbientSoundscape.forest => 'نسيم الطبيعة مع نغمات هادئة مريحة للأعصاب',
        AmbientSoundscape.warmNoise => 'تردد بني دافئ يعزل الإلهاء ويريح الذهن أثناء المذاكرة',
      };

  String get subtitleEn => switch (this) {
        AmbientSoundscape.silent => 'Focus without background audio',
        AmbientSoundscape.ocean => 'Rhythmic ocean waves washing ashore for mental clarity',
        AmbientSoundscape.night => 'Warm nocturnal frequencies for deep evening focus',
        AmbientSoundscape.rain => 'Soft rainfall patter that masks surrounding noise',
        AmbientSoundscape.forest => 'Calm nature breeze with soothing harmonic tones',
        AmbientSoundscape.warmNoise => 'Warm brown noise that masks distractions during study',
      };
}

/// Synthesizes soothing ambient soundscapes (Ocean, Night, Rain, Forest) and
/// melodic alarm chimes entirely in memory (zero external network or asset files).
class HandelhaSoundEngine {
  HandelhaSoundEngine._();

  static final HandelhaSoundEngine instance = HandelhaSoundEngine._();

  final PlatformAudioPlayer _ambientPlayer = PlatformAudioPlayer();
  final PlatformAudioPlayer _alarmPlayer = PlatformAudioPlayer();
  final Map<String, String> _wavCache = {};

  AmbientSoundscape _currentAmbient = AmbientSoundscape.silent;
  double _volume = 0.65;

  AmbientSoundscape get currentAmbient => _currentAmbient;
  double get volume => _volume;

  void playAmbient(AmbientSoundscape soundscape, {double? volume}) {
    if (volume != null) {
      _volume = volume.clamp(0.05, 1.0);
    }
    _currentAmbient = soundscape;
    if (soundscape == AmbientSoundscape.silent) {
      _ambientPlayer.stop();
      return;
    }

    final key = 'ambient_${soundscape.name}';
    final b64 = _wavCache.putIfAbsent(key, () => _generateAmbientWav(soundscape));
    _ambientPlayer.playWavBase64(b64, key: key, loop: true, volume: _volume);
  }

  void setAmbientVolume(double volume) {
    _volume = volume.clamp(0.05, 1.0);
    _ambientPlayer.setVolume(_volume);
  }

  void stopAmbient() {
    _currentAmbient = AmbientSoundscape.silent;
    _ambientPlayer.stop();
  }

  void playAlarmChime({bool loop = true}) {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (_) {}
    final b64 = _wavCache.putIfAbsent('alarm_chime', _generateAlarmWav);
    _alarmPlayer.playWavBase64(
      b64,
      key: 'alarm_chime',
      loop: loop,
      volume: 0.9,
      isAlarm: true,
    );
  }

  void stopAlarmChime() {
    _alarmPlayer.stop();
  }

  String _generateAmbientWav(AmbientSoundscape type) {
    const sampleRate = 22050;
    const durationSeconds = 6; // 6-second seamless loop
    const numSamples = sampleRate * durationSeconds;
    final samples = Float64List(numSamples);
    final rng = math.Random(42 + type.index);

    double lp1 = 0.0;
    double lp2 = 0.0;

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Seamless loop fade at edges
      final loopPhase = (t / durationSeconds) * 2 * math.pi;
      final white = rng.nextDouble() * 2.0 - 1.0;
      lp1 = 0.96 * lp1 + 0.04 * white;
      lp2 = 0.92 * lp2 + 0.08 * lp1;

      double val = 0.0;
      switch (type) {
        case AmbientSoundscape.ocean:
          // Slow ocean wave swell (period = 6s) + deep warm harmonic
          final swell = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(loopPhase));
          final subWave = 0.12 * math.sin(2 * math.pi * 110.0 * t) +
              0.08 * math.sin(2 * math.pi * 165.0 * t);
          val = (lp2 * 2.2 * swell) + subWave * swell;
          break;
        case AmbientSoundscape.night:
          // Warm nocturnal pad (174 Hz + 261.6 Hz + 392 Hz) + soft cricket shimmer
          final pad = 0.18 * math.sin(2 * math.pi * 174.6 * t) +
              0.14 * math.sin(2 * math.pi * 261.6 * t) +
              0.09 * math.sin(2 * math.pi * 392.0 * t);
          final shimmerEnv =
              math.max(0.0, math.sin(2 * math.pi * 2.5 * t)) * 0.04;
          final cricket = shimmerEnv * math.sin(2 * math.pi * 3200.0 * t);
          val = pad + (lp2 * 0.4) + cricket;
          break;
        case AmbientSoundscape.rain:
          // Soft filtered rainfall patter + gentle low warmth
          final rainFilter = 0.80 * lp1 + 0.20 * white;
          final warmPad = 0.08 * math.sin(2 * math.pi * 196.0 * t);
          val = (rainFilter * 0.55) + warmPad;
          break;
        case AmbientSoundscape.forest:
          // Gentle breeze + peaceful pentatonic Zen harmonic bells
          final breeze = lp2 * 1.1 * (0.6 + 0.4 * math.cos(loopPhase));
          final noteFreq = (t < 2.0)
              ? 293.66 // D4
              : (t < 4.0 ? 329.63 : 392.00); // E4, G4
          final localT = t % 2.0;
          final bellEnv = math.exp(-localT * 2.2);
          final bell = 0.22 * bellEnv * math.sin(2 * math.pi * noteFreq * t);
          val = breeze + bell;
          break;
        case AmbientSoundscape.warmNoise:
          // Deep warm brown noise with soft 130 Hz study room warmth
          final brown = 0.72 * lp2 + 0.28 * lp1;
          final roomTone = 0.05 * math.sin(2 * math.pi * 130.81 * t);
          val = (brown * 2.4) + roomTone;
          break;
        case AmbientSoundscape.silent:
          val = 0.0;
          break;
      }
      samples[i] = val.clamp(-0.9, 0.9);
    }

    // Crossfade the final 40 ms back into the opening 40 ms for click-free loops.
    const fadeSamples = 882;
    if (numSamples > fadeSamples * 2) {
      for (var i = 0; i < fadeSamples; i++) {
        final alpha = i / fadeSamples;
        final tailIdx = numSamples - fadeSamples + i;
        final blended = samples[i] * alpha + samples[tailIdx] * (1.0 - alpha);
        samples[i] = blended;
      }
    }

    return base64Encode(_encodePcm16Wav(samples, sampleRate));
  }

  String _generateAlarmWav() {
    const sampleRate = 22050;
    const durationSeconds = 3;
    const numSamples = sampleRate * durationSeconds;
    final samples = Float64List(numSamples);

    // Cheerful melodic 4-note chime pattern (C5 -> E5 -> G5 -> C6) repeated twice
    const notes = <double>[523.25, 659.25, 783.99, 1046.50];

    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      if (t >= 2.2) {
        samples[i] = 0.0;
        continue;
      }
      final step = (t / 0.26).floor() % notes.length;
      final noteT = t % 0.26;
      final freq = notes[step];
      final env = math.exp(-noteT * 7.5);
      final tone = 0.45 * math.sin(2 * math.pi * freq * t) +
          0.20 * math.sin(2 * math.pi * (freq * 2) * t);
      samples[i] = (tone * env).clamp(-0.9, 0.9);
    }

    return base64Encode(_encodePcm16Wav(samples, sampleRate));
  }

  Uint8List _encodePcm16Wav(Float64List samples, int sampleRate) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final totalSize = 44 + dataSize;
    final bytes = ByteData(totalSize);

    // RIFF header
    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E

    // fmt subchunk
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6D); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // PCM chunk size
    bytes.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    bytes.setUint16(22, 1, Endian.little); // NumChannels = 1 (Mono)
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    bytes.setUint16(32, 2, Endian.little); // BlockAlign
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample = 16

    // data subchunk
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, dataSize, Endian.little);

    var offset = 44;
    for (var i = 0; i < numSamples; i++) {
      final pcm = (samples[i] * 32767.0).round().clamp(-32768, 32767);
      bytes.setInt16(offset, pcm, Endian.little);
      offset += 2;
    }

    return bytes.buffer.asUint8List();
  }
}
