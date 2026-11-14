import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'stt_models.dart';
import 'stt_service.dart';

/// Implementation on top of the `speech_to_text` plugin and the device/OS
/// recognizer. This selects ar_EG when available, but does not claim Offline
/// operation: the OS recognizer may use a network provider depending on the
/// Android device, settings, and installed language pack.
class SpeechToTextPackageService implements SpeechToTextService {
  SpeechToTextPackageService({
    stt.SpeechToText? engine,
    this.config = const SttConfig(),
    this.onPermissionDenied,
    this.localeCandidatesProvider,
  }) : _speech = engine ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  final SttConfig config;
  final Future<void> Function()? onPermissionDenied;
  final List<String> Function()? localeCandidatesProvider;

  final _partial = StreamController<String>.broadcast();
  final _final = StreamController<String>.broadcast();
  final _errors = StreamController<SttError>.broadcast();

  bool _initialized = false;
  bool _finalDelivered = false;
  bool _cancelled = false;
  String _lastWords = '';
  String? _locale;
  String _lastCandidatesKey = '';

  List<String> get _effectiveCandidates {
    final provided = localeCandidatesProvider?.call();
    if (provided != null && provided.isNotEmpty) return provided;
    return config.localeCandidates;
  }

  @override
  Stream<String> get partialTranscripts => _partial.stream;
  @override
  Stream<String> get finalTranscripts => _final.stream;
  @override
  Stream<SttError> get errors => _errors.stream;
  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(onError: _onError, onStatus: _onStatus);
    } catch (_) {
      _initialized = false;
    }
    if (_initialized) _locale = await _pickLocale();
    return _initialized;
  }

  Future<String?> _pickLocale() async {
    final candidates = _effectiveCandidates;
    _lastCandidatesKey = candidates.join(',');
    try {
      final locales = await _speech.locales();
      String norm(String s) => s.replaceAll('-', '_').toLowerCase();
      for (final c in candidates) {
        for (final l in locales) {
          if (norm(l.localeId) == norm(c)) return l.localeId;
        }
      }
      final prefixes = candidates
          .map((c) => norm(c).split('_').first)
          .where((p) => p.isNotEmpty)
          .toSet();
      for (final p in prefixes) {
        for (final l in locales) {
          if (norm(l.localeId).startsWith(p)) return l.localeId;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> startListening() async {
    if (!await initialize()) {
      final denied = !(await _speech.hasPermission);
      final err = SttError(denied ? SttErrorCode.permissionDenied : SttErrorCode.unavailable);
      if (denied) await handlePermissionError();
      throw SttException(err);
    }
    final candidatesKey = _effectiveCandidates.join(',');
    if (_locale == null || candidatesKey != _lastCandidatesKey) {
      _locale = await _pickLocale();
    }
    if (_locale == null) {
      throw SttException(
        SttError(
          SttErrorCode.unsupportedLanguage,
          'No matching locale for $_lastCandidatesKey',
        ),
      );
    }
    _finalDelivered = false;
    _cancelled = false;
    _lastWords = '';
    await _speech.listen(
      onResult: _onResult,
      listenOptions: stt.SpeechListenOptions(
        localeId: _locale,
        listenFor: config.listenFor,
        pauseFor: config.pauseFor,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    _lastWords = r.recognizedWords;
    if (r.finalResult) {
      _emitFinal(r.recognizedWords);
    } else if (!_partial.isClosed) {
      _partial.add(r.recognizedWords);
    }
  }

  void _emitFinal(String text) {
    if (_finalDelivered || _cancelled || _final.isClosed) return;
    _finalDelivered = true;
    _final.add(text);
  }

  void _onStatus(String status) {
    // Some Android versions end the session without finalResult=true.
    if ((status == 'done' || status == 'notListening') && !_finalDelivered && !_cancelled) {
      Timer(const Duration(milliseconds: 300), () {
        if (!_finalDelivered && !_cancelled && _lastWords.trim().isNotEmpty) {
          _emitFinal(_lastWords);
        }
      });
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (_finalDelivered || _cancelled || _errors.isClosed) return;
    final msg = e.errorMsg;
    // Android providers vary in error casing: ERROR_AUDIO, error_audio, etc.
    final normalized = msg.toLowerCase();
    SttErrorCode code;
    if (normalized.contains('permission')) {
      code = SttErrorCode.permissionDenied;
    } else if (normalized.contains('no_match') || normalized.contains('speech_timeout')) {
      if (_lastWords.trim().isNotEmpty) return; // we do have something
      code = SttErrorCode.noSpeech;
    } else if (normalized.contains('network')) {
      code = SttErrorCode.network;
    } else if (normalized.contains('audio') || normalized.contains('busy')) {
      code = SttErrorCode.unavailable;
    } else {
      code = SttErrorCode.failure;
    }
    _errors.add(SttError(code, msg));
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _speech.cancel();
  }

  @override
  Future<void> handlePermissionError() async {
    if (!_errors.isClosed) _errors.add(const SttError(SttErrorCode.permissionDenied));
    await onPermissionDenied?.call();
  }

  @override
  void dispose() {
    _partial.close();
    _final.close();
    _errors.close();
  }
}
