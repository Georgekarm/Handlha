import 'stt_models.dart';

/// Provider-neutral speech-to-text. Output is plain text only: the rest of the
/// pipeline never sees audio. This interface does not promise that the OS
/// recognizer is Offline; the active Android provider and language pack must be
/// verified on target devices before making a privacy claim.
abstract class SpeechToTextService {
  /// Requests permission and prepares the engine. Returns false if the
  /// microphone is denied/unavailable.
  Future<bool> initialize();

  /// Starts listening. Throws [SttException] on permission/availability errors.
  Future<void> startListening();

  /// Stops capturing audio; a final transcript is still delivered.
  Future<void> stopListening();

  /// Aborts without delivering a transcript.
  Future<void> cancel();

  bool get isListening;

  Stream<String> get partialTranscripts;
  Stream<String> get finalTranscripts;
  Stream<SttError> get errors;

  /// Call after a permission denial; emits the error and runs the optional
  /// app hook (e.g. show a dialog / open app settings).
  Future<void> handlePermissionError();

  void dispose();
}
