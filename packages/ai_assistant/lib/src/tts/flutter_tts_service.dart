import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../util/arabic_text.dart';
import 'tts_config.dart';
import 'tts_service.dart';

/// Implementation on top of `flutter_tts` (OS voices). Prefers an ar-EG voice.
///
/// Notes: pause/resume work on iOS only (Android returns false). English words
/// inside Arabic sentences may be pronounced with an Arabic accent by some
/// system voices; use a cloud TTS implementation if that matters.
class FlutterTtsService implements TextToSpeechService {
  FlutterTtsService({FlutterTts? engine, this.config = const TtsConfig()})
      : _tts = engine ?? FlutterTts();

  final FlutterTts _tts;
  final TtsConfig config;
  final _changes = StreamController<bool>.broadcast();
  bool _ready = false;
  bool _speaking = false;

  @override
  bool get isSpeaking => _speaking;
  @override
  Stream<bool> get speakingChanges => _changes.stream;

  Future<void> initialize() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    for (final l in config.languageCandidates) {
      final ok = await _tts.isLanguageAvailable(l);
      if (ok == true || ok == 1) {
        await _tts.setLanguage(l);
        break;
      }
    }
    await _pickEgyptianVoice();
    await _tts.setSpeechRate(config.speechRate);
    await _tts.setPitch(config.pitch);
    await _tts.setVolume(config.volume);
    _tts.setStartHandler(() => _set(true));
    _tts.setCompletionHandler(() => _set(false));
    _tts.setCancelHandler(() => _set(false));
    _tts.setErrorHandler((_) => _set(false));
    _ready = true;
  }

  Future<void> _pickEgyptianVoice() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      for (final v in voices) {
        if (v is Map) {
          final locale = (v['locale'] ?? '').toString().replaceAll('_', '-').toLowerCase();
          if (locale == 'ar-eg') {
            await _tts.setVoice({'name': v['name'].toString(), 'locale': v['locale'].toString()});
            return;
          }
        }
      }
    } catch (_) {}
  }

  void _set(bool v) {
    _speaking = v;
    if (!_changes.isClosed) _changes.add(v);
  }

  @override
  Future<void> speak(String text) async {
    final clean = ArabicText.cleanForTts(text);
    if (clean.isEmpty) return;
    try {
      await initialize();
      _set(true);
      await _tts.speak(clean); // completes at end of speech (awaitSpeakCompletion)
    } catch (e) {
      throw TtsException(e.toString());
    } finally {
      if (_speaking) _set(false);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } finally {
      _set(false);
    }
  }

  @override
  Future<bool> pause() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    return (await _tts.pause()) == 1;
  }

  @override
  Future<bool> resume() async {
    // flutter_tts has no resume; iOS continues by speaking again is not
    // supported, so report unsupported honestly.
    return false;
  }

  @override
  void dispose() => _changes.close();
}
