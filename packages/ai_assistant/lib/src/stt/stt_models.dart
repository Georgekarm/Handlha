enum SttErrorCode { permissionDenied, unavailable, noSpeech, network, unsupportedLanguage, failure }

class SttError {
  const SttError(this.code, [this.detail]);
  final SttErrorCode code;
  final String? detail; // technical, for logs only
}

class SttException implements Exception {
  const SttException(this.error);
  final SttError error;
  @override
  String toString() => 'SttException(${error.code.name}: ${error.detail})';
}

class SttConfig {
  const SttConfig({
    this.localeCandidates = const ['ar_EG', 'ar-EG', 'ar_SA', 'ar-SA', 'ar'],
    this.listenFor = const Duration(seconds: 30),
    this.pauseFor = const Duration(seconds: 3),
  });

  /// Tried in order; Egyptian Arabic first, then any Arabic.
  final List<String> localeCandidates;
  final Duration listenFor;
  final Duration pauseFor;
}
