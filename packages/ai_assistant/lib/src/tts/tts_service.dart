import 'dart:async';

/// Provider-neutral text-to-speech. Independent of the LLM: it only receives
/// final text. Swap by implementing this interface (e.g. a cloud ar-EG voice).
abstract class TextToSpeechService {
  /// Speaks [text]; the future completes when speech finishes or is stopped.
  Future<void> speak(String text);
  Future<void> stop();

  /// Returns false when the platform/provider can't pause.
  Future<bool> pause();
  Future<bool> resume();

  bool get isSpeaking;

  /// true when speech starts, false when it ends/stops.
  Stream<bool> get speakingChanges;

  void dispose();
}

class TtsException implements Exception {
  const TtsException(this.detail);
  final String detail;
  @override
  String toString() => 'TtsException($detail)';
}

/// Silent implementation (tests, text-only mode).
class NoopTextToSpeechService implements TextToSpeechService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> pause() async => false;
  @override
  Future<bool> resume() async => false;
  @override
  bool get isSpeaking => false;
  @override
  Stream<bool> get speakingChanges => const Stream<bool>.empty();
  @override
  void dispose() {}
}
